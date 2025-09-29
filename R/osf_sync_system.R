# OSF Synchronization System
# Comprehensive system for syncing OSF.io structure with local cchs-osf-docs
# Author: CCHS Documentation Project
# Date: 2025-09-28

library(httr)
library(jsonlite)
library(yaml)

# ==============================================================================
# CONFIGURATION AND AUTHENTICATION
# ==============================================================================

#' Get OSF configuration from environment and config files
#' 
#' @param config_file Path to config.yml file
#' @return List with OSF configuration
get_osf_config <- function(config_file = "config.yml") {
  # Load environment variables if .env exists
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  # Load main configuration
  config <- config::get()
  
  list(
    token = Sys.getenv("OSF_PAT"),
    project_id = Sys.getenv("OSF_PROJECT_ID"),
    docs_component_id = config$osf$documentation_component_id
  )
}

#' Test OSF authentication
#' 
#' @param component_id OSF component ID (default from config)
#' @return TRUE if authentication successful, FALSE otherwise
test_osf_authentication <- function(component_id = NULL) {
  
  cat("=== TESTING OSF AUTHENTICATION ===\n")
  
  osf_config <- get_osf_config()
  
  if (osf_config$token == "") {
    cat("❌ OSF_PAT environment variable not set\n")
    cat("Please set your OSF Personal Access Token:\n")
    cat("Sys.setenv(OSF_PAT = 'your_token_here')\n")
    return(FALSE)
  }
  
  if (is.null(component_id)) {
    component_id <- osf_config$docs_component_id
  }
  
  url <- paste0("https://api.osf.io/v2/nodes/", component_id, "/files/osfstorage/")
  
  headers <- add_headers(
    "Authorization" = paste("Bearer", osf_config$token),
    "Content-Type" = "application/vnd.api+json"
  )
  
  tryCatch({
    response <- GET(url, headers)
    
    if (status_code(response) == 200) {
      cat("✅ OSF authentication successful\n")
      cat("Component ID:", component_id, "\n")
      cat("Token length:", nchar(osf_config$token), "characters\n")
      return(TRUE)
    } else if (status_code(response) == 401) {
      cat("❌ Authentication failed - invalid token\n")
      return(FALSE)
    } else if (status_code(response) == 404) {
      cat("❌ Component not found:", component_id, "\n")
      return(FALSE)
    } else {
      cat("❌ Request failed with status:", status_code(response), "\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("❌ Authentication test error:", e$message, "\n")
    return(FALSE)
  })
}

# ==============================================================================
# OSF API FUNCTIONS
# ==============================================================================

#' Get all top-level folders from OSF with pagination
#' 
#' @param component_id OSF component ID (default from config)
#' @return Data frame with folder information
get_all_osf_folders <- function(component_id = NULL) {
  
  osf_config <- get_osf_config()
  
  if (is.null(component_id)) {
    component_id <- osf_config$docs_component_id
  }
  
  # OSF API v2 endpoint for files in a component
  base_url <- paste0("https://api.osf.io/v2/nodes/", component_id, "/files/osfstorage/")
  
  # Set up headers with authorization
  headers <- add_headers(
    "Authorization" = paste("Bearer", osf_config$token),
    "Content-Type" = "application/vnd.api+json"
  )
  
  cat("=== GETTING ALL OSF FOLDERS WITH PAGINATION ===\n")
  
  all_folders <- data.frame()
  page <- 1
  total_pages <- NULL
  
  repeat {
    # Build URL with pagination parameters
    url <- paste0(base_url, "?page[size]=100&page=", page)
    cat("Fetching page", page, "...\n")
    
    tryCatch({
      response <- GET(url, headers)
      
      if (status_code(response) == 200) {
        response_text <- content(response, "text", encoding = "UTF-8")
        data <- fromJSON(response_text)
        
        # Extract pagination info on first page
        if (page == 1 && !is.null(data$links$meta$total)) {
          total_items <- data$links$meta$total
          page_size <- data$links$meta$per_page
          total_pages <- ceiling(total_items / page_size)
          cat("Found", total_items, "total items across", total_pages, "pages\n")
        }
        
        # Process current page data
        if (!is.null(data$data) && length(data$data) > 0) {
          # Handle data.frame structure from OSF API
          if (is.data.frame(data$data)) {
            page_folders <- data$data[data$data$attributes$kind == "folder", ]
            
            if (nrow(page_folders) > 0) {
              folders_data <- data.frame(
                id = page_folders$id,
                name = page_folders$attributes$name,
                kind = page_folders$attributes$kind,
                path = page_folders$attributes$materialized_path,
                stringsAsFactors = FALSE
              )
              
              all_folders <- rbind(all_folders, folders_data)
              cat("  Page", page, ":", nrow(folders_data), "folders\n")
            }
          }
        }
        
        # Check for next page
        if (!is.null(data$links[["next"]]) && !is.na(data$links[["next"]])) {
          page <- page + 1
        } else {
          cat("No more pages\n")
          break
        }
        
      } else {
        cat("❌ Request failed with status:", status_code(response), "\n")
        break
      }
      
    }, error = function(e) {
      cat("❌ Error on page", page, ":", e$message, "\n")
      break
    })
  }
  
  cat("\nTotal folders collected:", nrow(all_folders), "\n")
  
  if (nrow(all_folders) > 0) {
    cat("Folder names found:\n")
    for (name in sort(all_folders$name)) {
      cat("  ", name, "\n")
    }
  }
  
  return(all_folders)
}

#' Get contents of a specific OSF folder with pagination
#' 
#' @param folder_id OSF folder ID
#' @param folder_name Folder name for logging
#' @param component_id OSF component ID (default "jm8bx")
#' @return List of folder contents
get_osf_folder_contents <- function(folder_id, folder_name = "folder", component_id = "jm8bx") {
  
  osf_config <- get_osf_config()
  
  # OSF API endpoint for folder contents with pagination
  base_url <- paste0("https://api.osf.io/v2/nodes/", component_id, "/files/osfstorage/", folder_id, "/")
  
  # Set up headers with authorization
  headers <- add_headers(
    "Authorization" = paste("Bearer", osf_config$token),
    "Content-Type" = "application/vnd.api+json"
  )
  
  all_contents <- list()
  page <- 1
  
  repeat {
    # Build URL with pagination
    url <- paste0(base_url, "?page[size]=100&page=", page)
    
    tryCatch({
      response <- GET(url, headers)
      
      if (status_code(response) == 200) {
        response_text <- content(response, "text", encoding = "UTF-8")
        data <- fromJSON(response_text)
        
        if (!is.null(data$data) && length(data$data) > 0) {
          # Handle data.frame structure (which is what OSF API returns)
          if (is.data.frame(data$data)) {
            for (i in 1:nrow(data$data)) {
              item_name <- data$data$attributes$name[i]
              item_kind <- data$data$attributes$kind[i]
              item_id <- data$data$id[i]
              item_size <- if (!is.null(data$data$attributes$size[i])) data$data$attributes$size[i] else 0
              
              cat("  Found", item_kind, ":", item_name, "\n")
              
              all_contents[[length(all_contents) + 1]] <- list(
                id = item_id,
                name = item_name,
                kind = item_kind,
                size = item_size
              )
            }
          }
        }
        
        # Check if there are more pages
        next_page <- data$links[["next"]]
        if (!is.null(next_page) && !is.na(next_page)) {
          page <- page + 1
        } else {
          break
        }
        
      } else {
        cat("❌ Failed to get contents for", folder_name, "- status:", status_code(response), "\n")
        break
      }
      
    }, error = function(e) {
      cat("❌ Error getting contents for", folder_name, ":", e$message, "\n")
      break
    })
  }
  
  return(all_contents)
}

# ==============================================================================
# RECURSIVE STRUCTURE FUNCTIONS
# ==============================================================================

#' Recursively get complete OSF folder structure
#' 
#' @param folder_id OSF folder ID
#' @param folder_path Current folder path for logging
#' @param max_depth Maximum recursion depth (safety limit)
#' @param current_depth Current recursion depth
#' @param component_id OSF component ID
#' @return Complete nested structure
get_recursive_osf_structure <- function(folder_id, folder_path = "", max_depth = 10, 
                                       current_depth = 0, component_id = "jm8bx") {
  
  if (current_depth >= max_depth) {
    cat("⚠️ Max depth reached for:", folder_path, "\n")
    return(list())
  }
  
  indent <- paste(rep("  ", current_depth), collapse = "")
  cat(indent, "📁 Exploring:", folder_path, "\n")
  
  # Get contents of this folder
  contents <- get_osf_folder_contents(folder_id, folder_path, component_id)
  
  if (length(contents) == 0) {
    cat(indent, "  (empty folder)\n")
    return(list())
  }
  
  structure <- list()
  
  for (item in contents) {
    item_path <- if (folder_path == "") item$name else file.path(folder_path, item$name)
    
    if (item$kind == "folder") {
      cat(indent, "  📁", item$name, "/\n")
      
      # Recursively get subfolder structure
      substructure <- get_recursive_osf_structure(
        folder_id = item$id,
        folder_path = item_path,
        max_depth = max_depth,
        current_depth = current_depth + 1,
        component_id = component_id
      )
      
      structure[[length(structure) + 1]] <- list(
        id = item$id,
        name = item$name,
        path = item_path,
        kind = "folder",
        children = substructure
      )
      
    } else if (item$kind == "file") {
      cat(indent, "  📄", item$name, "(", item$size, "bytes)\n")
      
      structure[[length(structure) + 1]] <- list(
        id = item$id,
        name = item$name,
        path = item_path,
        kind = "file",
        size = item$size
      )
    }
  }
  
  return(structure)
}

#' Get complete OSF structure for a specific year
#' 
#' @param year Year to process (e.g., 2023, 2001)
#' @param max_depth Maximum recursion depth
#' @return Complete year structure
get_year_osf_structure <- function(year, max_depth = 10) {
  
  cat("=== GETTING COMPLETE OSF STRUCTURE FOR YEAR", year, "===\n")
  
  # Get all top-level folders
  all_folders <- get_all_osf_folders()
  
  if (is.null(all_folders) || nrow(all_folders) == 0) {
    cat("❌ No folders found\n")
    return(NULL)
  }
  
  # Find the specific year folder
  year_folder <- all_folders[all_folders$name == as.character(year), ]
  
  if (nrow(year_folder) == 0) {
    cat("❌ Year folder not found:", year, "\n")
    return(NULL)
  }
  
  folder_id <- year_folder$id[1]
  cat("✅ Found year folder:", year, "with ID:", folder_id, "\n\n")
  
  # Get complete recursive structure
  cat("Building complete folder tree for", year, "...\n")
  complete_structure <- get_recursive_osf_structure(folder_id, as.character(year), max_depth)
  
  return(list(
    year = year,
    folder_id = folder_id,
    structure = complete_structure
  ))
}

# ==============================================================================
# LOCAL STRUCTURE CREATION
# ==============================================================================

#' Create local folder structure from OSF structure
#' 
#' @param osf_structure OSF structure from get_year_osf_structure
#' @param base_dir Base directory (default "cchs-osf-docs")
#' @param dry_run If TRUE, only show what would be created
#' @return Number of folders created
create_local_structure_from_osf <- function(osf_structure, base_dir = "cchs-osf-docs", dry_run = FALSE) {
  
  if (is.null(osf_structure) || is.null(osf_structure$structure)) {
    cat("❌ No OSF structure provided\n")
    return(0)
  }
  
  year <- osf_structure$year
  cat("=== CREATING LOCAL STRUCTURE FOR YEAR", year, "===\n")
  
  if (dry_run) {
    cat("DRY RUN MODE - No folders will be created\n")
  }
  
  year_path <- file.path(base_dir, as.character(year))
  
  if (!dir.exists(year_path)) {
    if (!dry_run) {
      dir.create(year_path, showWarnings = FALSE, recursive = TRUE)
    }
    cat("Created base year directory:", year_path, "\n")
  }
  
  folders_created <- 0
  files_mapped <- 0
  
  # Recursive function to create folders
  create_recursive_folders <- function(items, current_path) {
    for (item in items) {
      if (item$kind == "folder") {
        folder_path <- file.path(current_path, item$name)
        
        if (dry_run) {
          cat("WOULD CREATE:", folder_path, "\n")
          folders_created <<- folders_created + 1
        } else {
          dir.create(folder_path, showWarnings = FALSE, recursive = TRUE)
          folders_created <<- folders_created + 1
          cat("✅ Created:", folder_path, "\n")
        }
        
        # Recursively create subfolders
        if ("children" %in% names(item) && length(item$children) > 0) {
          create_recursive_folders(item$children, folder_path)
        }
        
      } else if (item$kind == "file") {
        file_path <- file.path(current_path, item$name)
        files_mapped <<- files_mapped + 1
        
        if (dry_run) {
          cat("WOULD MAP FILE:", file_path, "\n")
        } else {
          cat("📄 File mapped:", file_path, "\n")
        }
      }
    }
  }
  
  cat("\nCreating folder structure...\n")
  create_recursive_folders(osf_structure$structure, year_path)
  
  if (!dry_run) {
    cat("\n✅ Created", folders_created, "folders for year", year, "\n")
    cat("📄 Mapped", files_mapped, "files for future download\n")
    
    # Save structure reference
    save_osf_structure_reference(osf_structure, base_dir)
  } else {
    cat("\nDRY RUN: Would create", folders_created, "folders for year", year, "\n")
    cat("DRY RUN: Would map", files_mapped, "files\n")
  }
  
  return(folders_created)
}

#' Save OSF structure reference documentation
#' 
#' @param osf_structure OSF structure data
#' @param base_dir Base directory
save_osf_structure_reference <- function(osf_structure, base_dir) {
  
  year <- osf_structure$year
  
  # Count items in structure
  count_structure_items <- function(items) {
    count <- 0
    for (item in items) {
      count <- count + 1
      if (item$kind == "folder" && "children" %in% names(item)) {
        count <- count + count_structure_items(item$children)
      }
    }
    return(count)
  }
  
  total_items <- count_structure_items(osf_structure$structure)
  
  reference_doc <- list(
    created = Sys.time(),
    year = year,
    source = "OSF.io API (recursive)",
    purpose = paste("Complete OSF structure for year", year),
    base_directory = base_dir,
    folder_id = osf_structure$folder_id,
    total_items = total_items,
    structure = osf_structure$structure
  )
  
  # Save as YAML
  reference_file <- file.path(base_dir, paste0("osf_structure_", year, ".yaml"))
  yaml::write_yaml(reference_doc, reference_file)
  
  # Create readable summary
  summary_lines <- c(
    paste("# Complete OSF Structure for Year", year),
    "",
    paste("Created:", format(Sys.time())),
    paste("Source: OSF.io API (recursive traversal)"),
    paste("Base directory:", base_dir),
    paste("OSF Folder ID:", osf_structure$folder_id),
    paste("Total items:", total_items),
    "",
    "## Folder Tree",
    ""
  )
  
  # Recursive function to add structure lines
  add_structure_lines <- function(items, indent = 0) {
    for (item in items) {
      indent_str <- paste(rep("  ", indent), collapse = "")
      
      if (item$kind == "folder") {
        summary_lines <<- c(summary_lines, paste0(indent_str, "📁 ", item$name, "/"))
        
        if ("children" %in% names(item) && length(item$children) > 0) {
          add_structure_lines(item$children, indent + 1)
        }
      } else if (item$kind == "file") {
        size_str <- if (!is.na(item$size)) paste0(" (", item$size, " bytes)") else ""
        summary_lines <<- c(summary_lines, paste0(indent_str, "📄 ", item$name, size_str))
      }
    }
  }
  
  add_structure_lines(osf_structure$structure)
  
  summary_file <- file.path(base_dir, paste0("OSF_STRUCTURE_", year, ".md"))
  writeLines(paste(summary_lines, collapse = "\n"), summary_file)
  
  cat("📄 Structure reference saved for year", year, "\n")
}

# ==============================================================================
# SYNC VERIFICATION FUNCTIONS
# ==============================================================================

#' Get local folder structure
#' 
#' @param base_dir Base directory to scan
#' @param year Specific year to scan (optional)
#' @return Local structure data
get_local_structure <- function(base_dir = "cchs-osf-docs", year = NULL) {
  
  if (!dir.exists(base_dir)) {
    cat("❌ Local directory does not exist:", base_dir, "\n")
    return(NULL)
  }
  
  if (!is.null(year)) {
    year_path <- file.path(base_dir, as.character(year))
    if (!dir.exists(year_path)) {
      cat("❌ Year directory does not exist:", year_path, "\n")
      return(NULL)
    }
    scan_path <- year_path
  } else {
    scan_path <- base_dir
  }
  
  # Recursive function to scan local structure
  scan_directory <- function(dir_path, relative_path = "") {
    items <- list()
    
    if (!dir.exists(dir_path)) {
      return(items)
    }
    
    all_items <- list.files(dir_path, full.names = TRUE, include.dirs = TRUE)
    
    for (item_path in all_items) {
      item_name <- basename(item_path)
      item_relative_path <- if (relative_path == "") item_name else file.path(relative_path, item_name)
      
      if (dir.exists(item_path)) {
        # It's a directory
        children <- scan_directory(item_path, item_relative_path)
        
        items[[length(items) + 1]] <- list(
          name = item_name,
          path = item_relative_path,
          kind = "folder",
          children = children
        )
        
      } else {
        # It's a file
        file_info <- file.info(item_path)
        
        items[[length(items) + 1]] <- list(
          name = item_name,
          path = item_relative_path,
          kind = "file",
          size = file_info$size
        )
      }
    }
    
    return(items)
  }
  
  local_structure <- scan_directory(scan_path)
  
  return(list(
    base_dir = base_dir,
    year = year,
    scanned_path = scan_path,
    structure = local_structure
  ))
}

#' Compare OSF and local structures
#' 
#' @param year Year to compare
#' @param base_dir Local base directory
#' @param max_depth OSF recursion depth
#' @return Comparison results
compare_osf_local_structure <- function(year, base_dir = "cchs-osf-docs", max_depth = 10) {
  
  cat("=== COMPARING OSF AND LOCAL STRUCTURES FOR YEAR", year, "===\n")
  
  # Get OSF structure
  cat("Step 1: Getting OSF structure...\n")
  osf_structure <- get_year_osf_structure(year, max_depth)
  
  if (is.null(osf_structure)) {
    cat("❌ Failed to get OSF structure\n")
    return(NULL)
  }
  
  # Get local structure
  cat("\nStep 2: Getting local structure...\n")
  local_structure <- get_local_structure(base_dir, year)
  
  if (is.null(local_structure)) {
    cat("❌ Failed to get local structure\n")
    return(NULL)
  }
  
  # Compare structures
  cat("\nStep 3: Comparing structures...\n")
  comparison <- compare_structures(osf_structure$structure, local_structure$structure)
  
  # Generate comparison report
  cat("\n=== COMPARISON RESULTS ===\n")
  cat("Year:", year, "\n")
  cat("OSF folders:", comparison$osf_folders, "\n")
  cat("OSF files:", comparison$osf_files, "\n")
  cat("Local folders:", comparison$local_folders, "\n")
  cat("Local files:", comparison$local_files, "\n")
  cat("Missing in local:", length(comparison$missing_in_local), "\n")
  cat("Extra in local:", length(comparison$extra_in_local), "\n")
  cat("Structures match:", comparison$structures_match, "\n")
  
  if (length(comparison$missing_in_local) > 0) {
    cat("\n❌ Missing in local:\n")
    for (item in comparison$missing_in_local) {
      cat("  ", item$kind, ":", item$path, "\n")
    }
  }
  
  if (length(comparison$extra_in_local) > 0) {
    cat("\n⚠️ Extra in local:\n")
    for (item in comparison$extra_in_local) {
      cat("  ", item$kind, ":", item$path, "\n")
    }
  }
  
  if (comparison$structures_match) {
    cat("\n✅ Structures are in sync!\n")
  } else {
    cat("\n❌ Structures are out of sync\n")
  }
  
  return(list(
    year = year,
    osf_structure = osf_structure,
    local_structure = local_structure,
    comparison = comparison
  ))
}

#' Helper function to compare two structure lists
#' 
#' @param osf_items OSF structure items
#' @param local_items Local structure items
#' @return Comparison statistics
compare_structures <- function(osf_items, local_items) {
  
  # Flatten structures for comparison
  flatten_structure <- function(items, prefix = "") {
    flat <- list()
    
    for (item in items) {
      item_path <- if (prefix == "") item$name else file.path(prefix, item$name)
      
      flat[[length(flat) + 1]] <- list(
        path = item_path,
        kind = item$kind,
        size = if ("size" %in% names(item)) item$size else NA
      )
      
      if (item$kind == "folder" && "children" %in% names(item)) {
        sub_flat <- flatten_structure(item$children, item_path)
        flat <- c(flat, sub_flat)
      }
    }
    
    return(flat)
  }
  
  osf_flat <- flatten_structure(osf_items)
  local_flat <- flatten_structure(local_items)
  
  # Extract paths for comparison
  osf_paths <- sapply(osf_flat, function(x) x$path)
  local_paths <- sapply(local_flat, function(x) x$path)
  
  # Find differences
  missing_in_local <- osf_flat[!osf_paths %in% local_paths]
  extra_in_local <- local_flat[!local_paths %in% osf_paths]
  
  # Count items by type
  count_by_kind <- function(flat_list, kind) {
    sum(sapply(flat_list, function(x) x$kind == kind))
  }
  
  return(list(
    osf_folders = count_by_kind(osf_flat, "folder"),
    osf_files = count_by_kind(osf_flat, "file"),
    local_folders = count_by_kind(local_flat, "folder"),
    local_files = count_by_kind(local_flat, "file"),
    missing_in_local = missing_in_local,
    extra_in_local = extra_in_local,
    structures_match = length(missing_in_local) == 0 && length(extra_in_local) == 0
  ))
}

# ==============================================================================
# HIGH-LEVEL SYNC FUNCTIONS
# ==============================================================================

#' Sync a specific year from OSF to local
#' 
#' @param year Year to sync
#' @param base_dir Local base directory
#' @param dry_run If TRUE, only show what would be done
#' @param force If TRUE, recreate structure even if it exists
sync_year_from_osf <- function(year, base_dir = "cchs-osf-docs", dry_run = FALSE, force = FALSE) {
  
  cat("=== SYNCING YEAR", year, "FROM OSF ===\n")
  
  # Test authentication first
  if (!test_osf_authentication()) {
    cat("❌ OSF authentication failed\n")
    return(NULL)
  }
  
  # Check if year already exists locally
  year_path <- file.path(base_dir, as.character(year))
  
  if (dir.exists(year_path) && !force) {
    cat("ℹ️ Year", year, "already exists locally. Use force=TRUE to recreate.\n")
    cat("Running comparison instead...\n")
    return(compare_osf_local_structure(year, base_dir))
  }
  
  # Get OSF structure
  osf_structure <- get_year_osf_structure(year)
  
  if (is.null(osf_structure)) {
    cat("❌ Failed to get OSF structure for year", year, "\n")
    return(NULL)
  }
  
  # Create local structure
  folders_created <- create_local_structure_from_osf(osf_structure, base_dir, dry_run)
  
  cat("\n=== SYNC COMPLETE ===\n")
  cat("Year:", year, "\n")
  cat("Folders created:", folders_created, "\n")
  
  return(osf_structure)
}

#' Sync all years from OSF to local
#' 
#' @param base_dir Local base directory
#' @param dry_run If TRUE, only show what would be done
#' @param force If TRUE, recreate structures even if they exist
#' @param years_to_sync Specific years to sync (optional)
sync_all_years_from_osf <- function(base_dir = "cchs-osf-docs", dry_run = FALSE, 
                                   force = FALSE, years_to_sync = NULL) {
  
  cat("=== SYNCING ALL YEARS FROM OSF ===\n")
  
  # Test authentication first
  if (!test_osf_authentication()) {
    cat("❌ OSF authentication failed\n")
    return(NULL)
  }
  
  # Get all available years from OSF
  if (is.null(years_to_sync)) {
    all_folders <- get_all_osf_folders()
    
    if (is.null(all_folders) || nrow(all_folders) == 0) {
      cat("❌ No folders found on OSF\n")
      return(NULL)
    }
    
    # Filter for year folders (numeric names)
    year_folders <- all_folders[grepl("^\\d{4}$", all_folders$name), ]
    years_to_sync <- sort(as.numeric(year_folders$name))
  }
  
  cat("Years to sync:", paste(years_to_sync, collapse = ", "), "\n\n")
  
  results <- list()
  
  for (year in years_to_sync) {
    cat("\n", rep("=", 80), "\n")
    result <- sync_year_from_osf(year, base_dir, dry_run, force)
    results[[as.character(year)]] <- result
  }
  
  cat("\n=== ALL YEARS SYNC SUMMARY ===\n")
  for (year in years_to_sync) {
    result <- results[[as.character(year)]]
    if (!is.null(result)) {
      cat("Year", year, ": ✅ Synced\n")
    } else {
      cat("Year", year, ": ❌ Failed\n")
    }
  }
  
  return(results)
}

#' Check sync status for all years
#' 
#' @param base_dir Local base directory
#' @param years_to_check Specific years to check (optional)
check_sync_status <- function(base_dir = "cchs-osf-docs", years_to_check = NULL) {
  
  cat("=== CHECKING SYNC STATUS ===\n")
  
  # Test authentication first
  if (!test_osf_authentication()) {
    cat("❌ OSF authentication failed\n")
    return(NULL)
  }
  
  # Get all available years from OSF if not specified
  if (is.null(years_to_check)) {
    all_folders <- get_all_osf_folders()
    
    if (is.null(all_folders) || nrow(all_folders) == 0) {
      cat("❌ No folders found on OSF\n")
      return(NULL)
    }
    
    # Filter for year folders (numeric names)
    year_folders <- all_folders[grepl("^\\d{4}$", all_folders$name), ]
    years_to_check <- sort(as.numeric(year_folders$name))
  }
  
  cat("Checking years:", paste(years_to_check, collapse = ", "), "\n\n")
  
  sync_status <- list()
  
  for (year in years_to_check) {
    cat("Checking year", year, "...\n")
    
    comparison <- compare_osf_local_structure(year, base_dir)
    
    if (!is.null(comparison)) {
      sync_status[[as.character(year)]] <- list(
        year = year,
        in_sync = comparison$comparison$structures_match,
        osf_items = comparison$comparison$osf_folders + comparison$comparison$osf_files,
        local_items = comparison$comparison$local_folders + comparison$comparison$local_files,
        missing_count = length(comparison$comparison$missing_in_local),
        extra_count = length(comparison$comparison$extra_in_local)
      )
    } else {
      sync_status[[as.character(year)]] <- list(
        year = year,
        in_sync = FALSE,
        error = "Failed to compare"
      )
    }
  }
  
  # Summary report
  cat("\n=== SYNC STATUS SUMMARY ===\n")
  cat("Year  | Status | OSF Items | Local Items | Missing | Extra\n")
  cat("------|--------|-----------|-------------|---------|------\n")
  
  for (year in years_to_check) {
    status <- sync_status[[as.character(year)]]
    
    if ("error" %in% names(status)) {
      cat(sprintf("%-5s | ❌ ERROR | -         | -           | -       | -\n", year))
    } else {
      status_icon <- if (status$in_sync) "✅ SYNC" else "❌ OUT"
      cat(sprintf("%-5s | %-8s | %-9d | %-11d | %-7d | %-5d\n", 
                  year, status_icon, status$osf_items, status$local_items, 
                  status$missing_count, status$extra_count))
    }
  }
  
  return(sync_status)
}

# ==============================================================================
# FILE DOWNLOAD FUNCTIONS
# ==============================================================================

#' Download a single file from OSF
#' 
#' @param file_id OSF file ID
#' @param local_path Local file path to save to
#' @param file_name File name for logging
#' @param component_id OSF component ID
#' @return TRUE if successful, FALSE otherwise
download_osf_file <- function(file_id, local_path, file_name = "file", component_id = "jm8bx") {
  
  osf_config <- get_osf_config()
  
  # OSF API endpoint for file download
  download_url <- paste0("https://files.osf.io/v1/resources/", component_id, "/providers/osfstorage/", file_id)
  
  # Set up headers with authorization
  headers <- add_headers(
    "Authorization" = paste("Bearer", osf_config$token)
  )
  
  tryCatch({
    # Ensure directory exists
    dir.create(dirname(local_path), showWarnings = FALSE, recursive = TRUE)
    
    # Download file
    response <- GET(download_url, headers, write_disk(local_path, overwrite = TRUE))
    
    if (status_code(response) == 200) {
      file_info <- file.info(local_path)
      cat("✅ Downloaded:", basename(local_path), "(", file_info$size, "bytes)\n")
      return(TRUE)
    } else {
      cat("❌ Download failed for", basename(local_path), "- status:", status_code(response), "\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("❌ Download error for", file_name, ":", e$message, "\n")
    return(FALSE)
  })
}

#' Download all files from OSF structure
#' 
#' @param osf_structure OSF structure from get_year_osf_structure
#' @param base_dir Local base directory
#' @param component_id OSF component ID
#' @return Download statistics
download_files_from_structure <- function(osf_structure, base_dir = "cchs-osf-docs", component_id = "jm8bx") {
  
  if (is.null(osf_structure) || is.null(osf_structure$structure)) {
    cat("❌ No OSF structure provided\n")
    return(list(success = 0, failed = 0))
  }
  
  year <- osf_structure$year
  cat("=== DOWNLOADING FILES FOR YEAR", year, "===\n")
  
  year_path <- file.path(base_dir, as.character(year))
  
  success_count <- 0
  failed_count <- 0
  total_size <- 0
  
  # Recursive function to download files
  download_recursive_files <- function(items, current_path) {
    for (item in items) {
      if (item$kind == "file") {
        file_path <- file.path(current_path, item$name)
        
        if (download_osf_file(item$id, file_path, item$name, component_id)) {
          success_count <<- success_count + 1
          total_size <<- total_size + item$size
        } else {
          failed_count <<- failed_count + 1
        }
        
      } else if (item$kind == "folder" && "children" %in% names(item)) {
        folder_path <- file.path(current_path, item$name)
        download_recursive_files(item$children, folder_path)
      }
    }
  }
  
  cat("Starting file downloads...\n")
  download_recursive_files(osf_structure$structure, year_path)
  
  cat("\n=== DOWNLOAD SUMMARY ===\n")
  cat("Year:", year, "\n")
  cat("Files downloaded:", success_count, "\n")
  cat("Files failed:", failed_count, "\n")
  cat("Total size:", round(total_size / 1024 / 1024, 2), "MB\n")
  
  return(list(
    year = year,
    success = success_count,
    failed = failed_count,
    total_size = total_size
  ))
}

#' Download files for a specific year
#' 
#' @param year Year to download
#' @param base_dir Local base directory
#' @param force If TRUE, re-download existing files
#' @return Download results
download_year_files <- function(year, base_dir = "cchs-osf-docs", force = FALSE) {
  
  cat("=== DOWNLOADING YEAR", year, "FILES ===\n")
  
  # Test authentication first
  if (!test_osf_authentication()) {
    cat("❌ OSF authentication failed\n")
    return(NULL)
  }
  
  # Check if files already exist
  year_path <- file.path(base_dir, as.character(year))
  
  if (!force && dir.exists(year_path)) {
    existing_files <- list.files(year_path, recursive = TRUE, full.names = FALSE)
    if (length(existing_files) > 0) {
      cat("ℹ️ Year", year, "already has", length(existing_files), "files. Use force=TRUE to re-download.\n")
      
      # Ask user if they want to continue
      response <- readline(prompt = "Continue with download? (y/n): ")
      if (tolower(response) != "y") {
        return(NULL)
      }
    }
  }
  
  # Get OSF structure
  osf_structure <- get_year_osf_structure(year)
  
  if (is.null(osf_structure)) {
    cat("❌ Failed to get OSF structure for year", year, "\n")
    return(NULL)
  }
  
  # Download files
  results <- download_files_from_structure(osf_structure, base_dir)
  
  return(results)
}

# ==============================================================================
# OSF CHANGE DETECTION FUNCTIONS
# ==============================================================================

#' Compare current OSF structure with stored metadata
#' 
#' @param year Year to compare
#' @param metadata_dir Directory containing YAML metadata files
#' @return List with changes detected
detect_osf_changes <- function(year, metadata_dir = "cchs-osf-docs/osf-metadata") {
  
  cat("=== DETECTING CHANGES FOR YEAR", year, "===\n")
  
  # Load stored metadata
  yaml_file <- file.path(metadata_dir, paste0("osf_structure_", year, ".yaml"))
  
  if (!file.exists(yaml_file)) {
    cat("❌ No baseline metadata found for year", year, "\n")
    return(NULL)
  }
  
  stored_metadata <- yaml::read_yaml(yaml_file)
  cat("📄 Loaded baseline from:", format(as.POSIXct(stored_metadata$created, origin="1970-01-01"), "%Y-%m-%d %H:%M"), "\n")
  
  # Get current OSF structure
  current_structure <- get_year_osf_structure(year)
  
  if (is.null(current_structure)) {
    cat("❌ Failed to get current OSF structure\n")
    return(NULL)
  }
  
  # Flatten both structures for comparison
  flatten_for_comparison <- function(items, prefix = "") {
    flat <- list()
    
    for (item in items) {
      item_path <- if (prefix == "") item$name else file.path(prefix, item$name)
      
      flat[[item_path]] <- list(
        id = item$id,
        name = item$name,
        path = item_path,
        kind = item$kind,
        size = if ("size" %in% names(item)) item$size else NA
      )
      
      if (item$kind == "folder" && "children" %in% names(item)) {
        sub_flat <- flatten_for_comparison(item$children, item_path)
        flat <- c(flat, sub_flat)
      }
    }
    
    return(flat)
  }
  
  stored_flat <- flatten_for_comparison(stored_metadata$structure)
  current_flat <- flatten_for_comparison(current_structure$structure)
  
  stored_paths <- names(stored_flat)
  current_paths <- names(current_flat)
  
  # Detect changes
  added_files <- setdiff(current_paths, stored_paths)
  removed_files <- setdiff(stored_paths, current_paths)
  
  # Check for modified files (size changes)
  common_files <- intersect(stored_paths, current_paths)
  modified_files <- c()
  
  for (path in common_files) {
    stored_item <- stored_flat[[path]]
    current_item <- current_flat[[path]]
    
    if (stored_item$kind == "file" && current_item$kind == "file") {
      if (!is.na(stored_item$size) && !is.na(current_item$size)) {
        if (stored_item$size != current_item$size) {
          modified_files <- c(modified_files, path)
        }
      }
    }
  }
  
  # Create change summary
  changes <- list(
    year = year,
    baseline_date = as.POSIXct(stored_metadata$created, origin="1970-01-01"),
    current_date = Sys.time(),
    baseline_count = length(stored_flat),
    current_count = length(current_flat),
    added = added_files,
    removed = removed_files,
    modified = modified_files,
    added_details = current_flat[added_files],
    removed_details = stored_flat[removed_files],
    modified_details = list(
      stored = stored_flat[modified_files],
      current = current_flat[modified_files]
    )
  )
  
  # Print summary
  cat("\n=== CHANGE SUMMARY ===\n")
  cat("Baseline files:", length(stored_flat), "\n")
  cat("Current files:", length(current_flat), "\n")
  cat("Added:", length(added_files), "\n")
  cat("Removed:", length(removed_files), "\n")
  cat("Modified:", length(modified_files), "\n")
  
  if (length(added_files) > 0) {
    cat("\n📁 ADDED FILES:\n")
    for (file in added_files) {
      item <- current_flat[[file]]
      size_str <- if (!is.na(item$size)) paste0(" (", item$size, " bytes)") else ""
      cat("  + ", item$kind, ":", file, size_str, "\n")
    }
  }
  
  if (length(removed_files) > 0) {
    cat("\n📁 REMOVED FILES:\n")
    for (file in removed_files) {
      item <- stored_flat[[file]]
      size_str <- if (!is.na(item$size)) paste0(" (", item$size, " bytes)") else ""
      cat("  - ", item$kind, ":", file, size_str, "\n")
    }
  }
  
  if (length(modified_files) > 0) {
    cat("\n📁 MODIFIED FILES:\n")
    for (file in modified_files) {
      stored_item <- stored_flat[[file]]
      current_item <- current_flat[[file]]
      cat("  ~ ", current_item$kind, ":", file, "\n")
      cat("    Old size:", stored_item$size, "bytes\n")
      cat("    New size:", current_item$size, "bytes\n")
    }
  }
  
  return(changes)
}

#' Detect changes across all years
#' 
#' @param years Years to check (default: all available)
#' @param metadata_dir Directory containing YAML metadata files
#' @return List of all changes by year
detect_all_osf_changes <- function(years = NULL, metadata_dir = "cchs-osf-docs/osf-metadata") {
  
  cat("=== DETECTING CHANGES ACROSS ALL YEARS ===\n")
  
  if (is.null(years)) {
    # Find all available YAML files
    yaml_files <- list.files(metadata_dir, pattern = "^osf_structure_\\d{4}\\.yaml$", full.names = FALSE)
    years <- as.numeric(sub("osf_structure_(\\d{4})\\.yaml", "\\1", yaml_files))
    years <- sort(years)
  }
  
  cat("Checking years:", paste(years, collapse = ", "), "\n\n")
  
  all_changes <- list()
  total_added <- 0
  total_removed <- 0
  total_modified <- 0
  
  for (year in years) {
    changes <- detect_osf_changes(year, metadata_dir)
    if (!is.null(changes)) {
      all_changes[[as.character(year)]] <- changes
      total_added <- total_added + length(changes$added)
      total_removed <- total_removed + length(changes$removed)
      total_modified <- total_modified + length(changes$modified)
    }
    cat("\n", rep("-", 60), "\n")
  }
  
  cat("\n=== OVERALL CHANGE SUMMARY ===\n")
  cat("Years checked:", length(years), "\n")
  cat("Total files added:", total_added, "\n")
  cat("Total files removed:", total_removed, "\n")
  cat("Total files modified:", total_modified, "\n")
  
  return(all_changes)
}

#' Update metadata files with current OSF structure
#' 
#' @param year Year to update
#' @param metadata_dir Directory containing YAML metadata files
#' @param backup_old If TRUE, backup old metadata file
update_osf_metadata <- function(year, metadata_dir = "cchs-osf-docs/osf-metadata", backup_old = TRUE) {
  
  cat("=== UPDATING METADATA FOR YEAR", year, "===\n")
  
  yaml_file <- file.path(metadata_dir, paste0("osf_structure_", year, ".yaml"))
  
  # Backup old file if requested
  if (backup_old && file.exists(yaml_file)) {
    backup_file <- paste0(yaml_file, ".backup.", format(Sys.time(), "%Y%m%d_%H%M%S"))
    file.copy(yaml_file, backup_file)
    cat("📄 Backed up old metadata to:", basename(backup_file), "\n")
  }
  
  # Get current OSF structure
  current_structure <- get_year_osf_structure(year)
  
  if (is.null(current_structure)) {
    cat("❌ Failed to get current OSF structure\n")
    return(FALSE)
  }
  
  # Save updated structure
  save_osf_structure_reference(current_structure, dirname(metadata_dir))
  
  # Move the generated file to the metadata directory
  generated_file <- file.path(dirname(metadata_dir), paste0("osf_structure_", year, ".yaml"))
  if (file.exists(generated_file) && generated_file != yaml_file) {
    file.rename(generated_file, yaml_file)
  }
  
  cat("✅ Updated metadata for year", year, "\n")
  return(TRUE)
}

# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

cat("=== OSF SYNCHRONIZATION SYSTEM LOADED ===\n")
cat("Main functions:\n")
cat("1. test_osf_authentication()                    # Test OSF connection\n")
cat("2. sync_year_from_osf(year, dry_run=TRUE)       # Sync specific year\n")
cat("3. sync_all_years_from_osf(dry_run=TRUE)        # Sync all years\n")
cat("4. check_sync_status()                          # Check sync status\n")
cat("5. compare_osf_local_structure(year)            # Compare specific year\n")
cat("6. download_year_files(year)                    # Download files for year\n")
cat("\nExample workflow:\n")
cat("- test_osf_authentication()\n")
cat("- sync_year_from_osf(2023, dry_run=TRUE)        # Test first\n")
cat("- sync_year_from_osf(2023, dry_run=FALSE)       # Create structure\n")
cat("- download_year_files(2023)                     # Download files\n")
cat("- check_sync_status()                           # Verify all years\n")