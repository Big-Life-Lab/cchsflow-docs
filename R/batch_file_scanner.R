# Batch File Scanner for Updated CCHS OSF Data
# Robust scanning strategy to handle large datasets and avoid timeouts

library(dplyr)
source("R/setup_osf.R")

# Batch scanning with timeout protection
scan_files_batch <- function(years_to_scan = NULL, 
                            batch_size = 3,
                            delay_between_batches = 2,
                            save_progress = TRUE) {
  
  # Load environment and connect
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  # Ensure environment variables are loaded
  if (Sys.getenv("OSF_PAT") == "" || Sys.getenv("OSF_PROJECT_ID") == "") {
    stop("OSF environment variables not set. Please check your .env file.")
  }
  
  config <- config::get()
  project <- init_osf()
  doc_node <- osf_retrieve_node(config$osf$documentation_component_id)
  
  # Get available years if not specified
  if (is.null(years_to_scan)) {
    all_folders <- osf_ls_files(doc_node)
    years_to_scan <- sort(as.numeric(all_folders$name[!is.na(as.numeric(all_folders$name))]))
  }
  
  cat("=== Batch File Scanning ===\n")
  cat("Years to scan:", length(years_to_scan), "(", min(years_to_scan), "-", max(years_to_scan), ")\n")
  cat("Batch size:", batch_size, "years\n\n")
  
  # Initialize results storage
  all_scan_results <- list()
  
  # Process in batches
  year_batches <- split(years_to_scan, ceiling(seq_along(years_to_scan) / batch_size))
  
  for (batch_num in seq_along(year_batches)) {
    batch_years <- year_batches[[batch_num]]
    
    cat("=== Batch", batch_num, "of", length(year_batches), "===\n")
    cat("Processing years:", paste(batch_years, collapse = ", "), "\n")
    
    batch_results <- list()
    
    for (year in batch_years) {
      cat("  Scanning year", year, "... ")
      
      tryCatch({
        year_result <- scan_single_year(doc_node, year)
        batch_results[[as.character(year)]] <- year_result
        cat("✓ Found", year_result$file_count, "items\n")
        
        # Small delay between years
        Sys.sleep(0.5)
        
      }, error = function(e) {
        cat("✗ Error:", e$message, "\n")
        batch_results[[as.character(year)]] <- list(
          year = year,
          error = e$message,
          file_count = 0,
          files = data.frame()
        )
      })
    }
    
    # Add batch results to overall results
    all_scan_results <- c(all_scan_results, batch_results)
    
    # Save progress after each batch
    if (save_progress) {
      save_scan_progress(all_scan_results, batch_num)
    }
    
    # Delay between batches to avoid overwhelming API
    if (batch_num < length(year_batches)) {
      cat("  Waiting", delay_between_batches, "seconds before next batch...\n\n")
      Sys.sleep(delay_between_batches)
    }
  }
  
  cat("\n=== Scan Complete ===\n")
  cat("Total years processed:", length(all_scan_results), "\n")
  
  # Save final results
  save_final_scan_results(all_scan_results)
  
  return(all_scan_results)
}

# Scan a single year with enhanced error handling
scan_single_year <- function(doc_node, year) {
  all_folders <- osf_ls_files(doc_node)
  year_folder_row <- all_folders %>% filter(name == as.character(year))
  
  if (nrow(year_folder_row) == 0) {
    return(list(
      year = year,
      file_count = 0,
      files = data.frame(),
      error = "Year folder not found"
    ))
  }
  
  # Enhanced file listing with recursive scanning
  year_files <- get_detailed_file_listing_enhanced(year_folder_row$id[1])
  
  return(list(
    year = year,
    file_count = nrow(year_files),
    files = year_files,
    scan_time = Sys.time()
  ))
}

# Enhanced file listing that handles new subfolder structures
get_detailed_file_listing_enhanced <- function(folder_id, max_depth = 5) {
  get_files_recursive <- function(current_id, current_path = "", depth = 0) {
    if (depth >= max_depth) {
      return(data.frame(path = character(0), name = character(0), 
                       type = character(0), id = character(0), 
                       depth = integer(0), parent_folder = character(0),
                       stringsAsFactors = FALSE))
    }
    
    tryCatch({
      folder <- osf_retrieve_file(current_id)
      files <- osf_ls_files(folder)
      
      if (nrow(files) == 0) {
        return(data.frame(path = current_path, name = "empty", 
                         type = "empty", id = NA_character_,
                         depth = depth, parent_folder = current_path,
                         stringsAsFactors = FALSE))
      }
      
      results <- data.frame()
      
      for (i in 1:nrow(files)) {
        file_name <- files$name[i]
        file_id <- files$id[i]
        file_path <- if (current_path == "") file_name else paste(current_path, file_name, sep = "/")
        
        # Try to determine if it's a folder or file
        is_folder <- tryCatch({
          subfolder <- osf_retrieve_file(file_id)
          subfiles <- osf_ls_files(subfolder)
          TRUE
        }, error = function(e) {
          FALSE
        })
        
        # Add current item with enhanced metadata
        current_result <- data.frame(
          path = file_path,
          name = file_name,
          type = if (is_folder) "folder" else "file",
          id = file_id,
          depth = depth,
          parent_folder = current_path,
          stringsAsFactors = FALSE
        )
        results <- rbind(results, current_result)
        
        # If it's a folder, recurse
        if (is_folder) {
          sub_results <- get_files_recursive(file_id, file_path, depth + 1)
          results <- rbind(results, sub_results)
        }
      }
      
      return(results)
    }, error = function(e) {
      return(data.frame(path = current_path, name = "error", 
                       type = "error", id = NA_character_,
                       depth = depth, parent_folder = current_path,
                       error_msg = as.character(e),
                       stringsAsFactors = FALSE))
    })
  }
  
  return(get_files_recursive(folder_id))
}

# Save progress after each batch
save_scan_progress <- function(results, batch_num) {
  if (!dir.exists("data/scan_progress")) {
    dir.create("data/scan_progress", recursive = TRUE)
  }
  
  filename <- paste0("data/scan_progress/batch_", sprintf("%02d", batch_num), "_", Sys.Date(), ".RData")
  save(results, file = filename)
  cat("  Progress saved to", filename, "\n")
}

# Save final comprehensive results
save_final_scan_results <- function(all_results) {
  # Save raw results
  scan_results <- all_results
  save(scan_results, file = "data/cchs_comprehensive_scan.RData")
  
  # Create summary statistics
  scan_summary <- list(
    scan_date = Sys.time(),
    total_years = length(all_results),
    years_scanned = names(all_results),
    total_files = sum(sapply(all_results, function(x) x$file_count)),
    successful_scans = sum(sapply(all_results, function(x) is.null(x$error))),
    failed_scans = sum(sapply(all_results, function(x) !is.null(x$error)))
  )
  
  save(scan_summary, file = "data/cchs_scan_summary.RData")
  
  cat("✅ Final results saved to data/cchs_comprehensive_scan.RData\n")
  cat("✅ Summary saved to data/cchs_scan_summary.RData\n")
  
  # Print summary
  cat("\nScan Summary:\n")
  cat("Years scanned:", scan_summary$total_years, "\n")
  cat("Total files found:", scan_summary$total_files, "\n")
  cat("Successful scans:", scan_summary$successful_scans, "\n")
  cat("Failed scans:", scan_summary$failed_scans, "\n")
}

# Resume scanning from where we left off
resume_scan <- function(start_year = NULL) {
  # Find latest progress file
  progress_files <- list.files("data/scan_progress", pattern = "batch_.*\\.RData", full.names = TRUE)
  
  if (length(progress_files) > 0) {
    latest_file <- progress_files[which.max(file.mtime(progress_files))]
    load(latest_file)
    
    completed_years <- as.numeric(names(results))
    
    if (is.null(start_year)) {
      start_year <- max(completed_years) + 1
    }
    
    cat("Resuming scan from year", start_year, "\n")
    cat("Previous progress:", length(completed_years), "years completed\n")
    
    # Continue with remaining years
    remaining_years <- start_year:2023
    scan_files_batch(remaining_years)
    
  } else {
    cat("No previous progress found. Starting fresh scan.\n")
    scan_files_batch()
  }
}

# Quick analysis of scan results
analyze_scan_results <- function() {
  if (!file.exists("data/cchs_comprehensive_scan.RData")) {
    cat("No scan results found. Run scan_files_batch() first.\n")
    return()
  }
  
  load("data/cchs_comprehensive_scan.RData")
  load("data/cchs_scan_summary.RData")
  
  cat("=== CCHS File Scan Analysis ===\n")
  cat("Scan date:", as.character(scan_summary$scan_date), "\n")
  cat("Years:", paste(range(as.numeric(scan_summary$years_scanned)), collapse = "-"), "\n")
  cat("Total files:", scan_summary$total_files, "\n\n")
  
  # Files per year
  files_per_year <- sapply(scan_results, function(x) x$file_count)
  cat("Files per year:\n")
  for (year in names(files_per_year)) {
    cat("  ", year, ":", files_per_year[year], "files\n")
  }
  
  # Identify years with most/least files
  cat("\nYears with most files:", names(sort(files_per_year, decreasing = TRUE))[1:3], "\n")
  cat("Years with fewest files:", names(sort(files_per_year))[1:3], "\n")
  
  # Look for potential issues
  empty_years <- names(files_per_year[files_per_year == 0])
  if (length(empty_years) > 0) {
    cat("\n⚠️ Years with no files:", paste(empty_years, collapse = ", "), "\n")
  }
  
  return(scan_results)
}