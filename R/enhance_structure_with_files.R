# Enhance CCHS Structure Data with Actual File Listings
# This script adds actual file names and counts to our structure data

library(dplyr)
source("R/setup_osf.R")

# Function to get detailed file listing for a folder
get_detailed_file_listing <- function(folder_id, max_depth = 10) {
  get_files_recursive <- function(current_id, current_path = "", depth = 0) {
    if (depth >= max_depth) {
      return(data.frame(path = character(0), name = character(0), 
                       type = character(0), id = character(0), 
                       stringsAsFactors = FALSE))
    }
    
    tryCatch({
      folder <- osf_retrieve_file(current_id)
      files <- osf_ls_files(folder)
      
      if (nrow(files) == 0) {
        return(data.frame(path = current_path, name = "empty", 
                         type = "empty", id = NA_character_))
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
          TRUE  # If we can list files, it's a folder
        }, error = function(e) {
          FALSE  # If we can't list files, it's probably a file
        })
        
        # Add current item
        current_result <- data.frame(
          path = file_path,
          name = file_name,
          type = if (is_folder) "folder" else "file",
          id = file_id,
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
                       error_msg = as.character(e)))
    })
  }
  
  return(get_files_recursive(folder_id))
}

# Function to get file listings for all CCHS years
get_all_cchs_file_listings <- function() {
  # Load environment and connect
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  config <- config::get()
  project <- init_osf()
  doc_node <- osf_retrieve_node(config$osf$documentation_component_id)
  
  # Get all year folders
  all_folders <- osf_ls_files(doc_node)
  year_folders <- all_folders %>% 
    filter(!is.na(as.numeric(name))) %>%
    arrange(as.numeric(name))
  
  cat("Getting file listings for", nrow(year_folders), "year folders...\n")
  
  all_file_listings <- list()
  
  for (i in 1:nrow(year_folders)) {
    year <- year_folders$name[i]
    year_id <- year_folders$id[i]
    
    cat("Processing year", year, "...\n")
    
    file_listing <- get_detailed_file_listing(year_id)
    all_file_listings[[year]] <- list(
      year = year,
      folder_id = year_id,
      files = file_listing,
      file_count = nrow(file_listing),
      folder_count = sum(file_listing$type == "folder", na.rm = TRUE),
      actual_file_count = sum(file_listing$type == "file", na.rm = TRUE),
      last_scanned = Sys.time()
    )
    
    cat("  Found", nrow(file_listing), "items (", 
        sum(file_listing$type == "folder", na.rm = TRUE), "folders,",
        sum(file_listing$type == "file", na.rm = TRUE), "files)\n")
  }
  
  return(all_file_listings)
}

# Function to enhance existing structure data with file listings
enhance_structure_with_files <- function() {
  cat("=== Enhancing CCHS Structure with File Listings ===\n")
  
  # Load environment first
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  # Load existing structure data
  load("data/cchs_structure.RData")
  
  # Get file listings
  file_listings <- get_all_cchs_file_listings()
  
  # Add file listings to structure data
  cchs_structure_data$file_listings <- file_listings
  cchs_structure_data$metadata$enhanced_with_files <- TRUE
  cchs_structure_data$metadata$files_last_scanned <- Sys.time()
  
  # Update actual structure summary
  years_with_files <- names(file_listings)
  total_files <- sum(sapply(file_listings, function(x) x$actual_file_count))
  total_folders <- sum(sapply(file_listings, function(x) x$folder_count))
  
  cchs_structure_data$actual_structure$years_with_file_data <- years_with_files
  cchs_structure_data$actual_structure$total_files <- total_files
  cchs_structure_data$actual_structure$total_folders <- total_folders
  
  # Save enhanced data
  save(cchs_structure_data, file = "data/cchs_structure_enhanced.RData")
  cat("✅ Saved enhanced structure to data/cchs_structure_enhanced.RData\n")
  
  # Create summary report
  create_file_summary_report(cchs_structure_data)
  
  return(cchs_structure_data)
}

# Function to create a summary report of files
create_file_summary_report <- function(structure_data) {
  cat("\n=== File Summary Report ===\n")
  
  file_listings <- structure_data$file_listings
  
  for (year in names(file_listings)) {
    year_data <- file_listings[[year]]
    cat("\n📁 Year", year, "\n")
    cat("  Total items:", year_data$file_count, "\n")
    cat("  Folders:", year_data$folder_count, "\n")
    cat("  Files:", year_data$actual_file_count, "\n")
    
    # Show folder structure
    folders <- year_data$files[year_data$files$type == "folder", ]
    if (nrow(folders) > 0) {
      cat("  Folder structure:\n")
      for (i in 1:nrow(folders)) {
        cat("    📁", folders$path[i], "\n")
      }
    }
    
    # Show files in main directories
    files <- year_data$files[year_data$files$type == "file", ]
    if (nrow(files) > 0) {
      cat("  Files found:\n")
      for (i in 1:min(10, nrow(files))) {  # Show max 10 files
        cat("    📄", files$path[i], "\n")
      }
      if (nrow(files) > 10) {
        cat("    ... and", nrow(files) - 10, "more files\n")
      }
    }
  }
  
  # Overall summary
  total_files <- structure_data$actual_structure$total_files
  total_folders <- structure_data$actual_structure$total_folders
  cat("\n=== Overall Summary ===\n")
  cat("Total folders across all years:", total_folders, "\n")
  cat("Total files across all years:", total_files, "\n")
  cat("Years with data:", length(file_listings), "\n")
}

# Function to search for specific files across all years
search_files_across_years <- function(pattern, structure_data = NULL) {
  if (is.null(structure_data)) {
    load("data/cchs_structure_enhanced.RData")
  }
  
  matches <- data.frame()
  
  for (year in names(structure_data$file_listings)) {
    year_files <- structure_data$file_listings[[year]]$files
    matching_files <- year_files[grepl(pattern, year_files$name, ignore.case = TRUE), ]
    
    if (nrow(matching_files) > 0) {
      matching_files$year <- year
      matches <- rbind(matches, matching_files)
    }
  }
  
  return(matches)
}