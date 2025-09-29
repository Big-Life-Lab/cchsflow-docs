# Production OSF API Client
# A clean, reliable replacement for the osfr package that handles pagination properly
# 
# Key advantages over osfr:
# - No pagination limitations (osfr only shows first 10 items)
# - Direct HTTP control with proper error handling  
# - Consistent JSON:API parsing
# - Lighter dependencies (only httr, jsonlite, config)

library(httr)
library(jsonlite)

# OSF API Configuration ----

get_osf_credentials <- function() {
  # Load environment variables
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  config <- config::get()
  
  # Validate required credentials
  token <- Sys.getenv("OSF_PAT")
  project_id <- Sys.getenv("OSF_PROJECT_ID")
  
  if (token == "" || project_id == "") {
    stop("Missing OSF credentials. Please set OSF_PAT and OSF_PROJECT_ID in .env file")
  }
  
  list(
    token = token,
    project_id = project_id,
    docs_component_id = config$osf$documentation_component_id %||% project_id
  )
}

# Core API Functions ----

#' Make authenticated request to OSF API
#' @param url API endpoint URL
#' @param token OSF personal access token
#' @return httr response object
osf_api_request <- function(url, token) {
  headers <- add_headers(
    "Authorization" = paste("Bearer", token),
    "Content-Type" = "application/vnd.api+json"
  )
  
  response <- GET(url, headers)
  
  if (status_code(response) != 200) {
    stop("OSF API error: ", status_code(response), " - ", content(response, "text"))
  }
  
  # Parse JSON response
  response_text <- content(response, "text", encoding = "UTF-8")
  fromJSON(response_text)
}

#' Get all files/folders from OSF component with proper pagination
#' @param component_id OSF component ID (defaults to docs component from config)
#' @param page_size Number of items per page (max 100)
#' @return data.frame with id, name, kind columns
osf_list_files <- function(component_id = NULL, page_size = 100) {
  
  creds <- get_osf_credentials()
  
  if (is.null(component_id)) {
    component_id <- creds$docs_component_id
  }
  
  base_url <- paste0("https://api.osf.io/v2/nodes/", component_id, "/files/osfstorage/")
  all_items <- data.frame()
  page <- 1
  
  repeat {
    url <- paste0(base_url, "?page[size]=", page_size, "&page=", page)
    
    tryCatch({
      data <- osf_api_request(url, creds$token)
      
      if (is.null(data$data) || nrow(data$data) == 0) {
        break
      }
      
      # Extract file information
      page_items <- data.frame(
        id = data$data$id,
        name = data$data$attributes$name,
        kind = data$data$attributes$kind,
        size = ifelse(is.null(data$data$attributes$size), NA, data$data$attributes$size),
        modified = ifelse(is.null(data$data$attributes$date_modified), NA, data$data$attributes$date_modified),
        stringsAsFactors = FALSE
      )
      
      all_items <- rbind(all_items, page_items)
      
      # Check for next page
      if (is.null(data$links) || is.null(data$links$`next`)) {
        break
      }
      
      page <- page + 1
      Sys.sleep(0.2)  # Rate limiting
      
    }, error = function(e) {
      warning("Error on page ", page, ": ", e$message)
      break
    })
  }
  
  return(all_items)
}

#' Get contents of a specific folder
#' @param folder_id OSF file/folder ID  
#' @param page_size Number of items per page
#' @return data.frame with folder contents
osf_folder_contents <- function(folder_id, page_size = 100) {
  
  creds <- get_osf_credentials()
  base_url <- paste0("https://api.osf.io/v2/files/", folder_id, "/")
  all_items <- data.frame()
  page <- 1
  
  repeat {
    url <- paste0(base_url, "?page[size]=", page_size, "&page=", page)
    
    tryCatch({
      data <- osf_api_request(url, creds$token)
      
      if (is.null(data$data) || nrow(data$data) == 0) {
        break
      }
      
      page_items <- data.frame(
        id = data$data$id,
        name = data$data$attributes$name,
        kind = data$data$attributes$kind,
        size = ifelse(is.null(data$data$attributes$size), NA, data$data$attributes$size),
        download_url = ifelse(is.null(data$data$links$download), NA, data$data$links$download),
        stringsAsFactors = FALSE
      )
      
      all_items <- rbind(all_items, page_items)
      
      if (is.null(data$links) || is.null(data$links$`next`)) {
        break
      }
      
      page <- page + 1
      Sys.sleep(0.2)
      
    }, error = function(e) {
      warning("Error accessing folder ", folder_id, " page ", page, ": ", e$message)
      break
    })
  }
  
  return(all_items)
}

#' Download a file from OSF
#' @param file_id OSF file ID
#' @param output_path Local file path to save
#' @param overwrite Whether to overwrite existing files
#' @return logical indicating success
osf_download_file <- function(file_id, output_path, overwrite = TRUE) {
  
  creds <- get_osf_credentials()
  
  # Get file metadata first
  url <- paste0("https://api.osf.io/v2/files/", file_id, "/")
  
  tryCatch({
    data <- osf_api_request(url, creds$token)
    download_url <- data$data$links$download
    
    if (is.null(download_url)) {
      warning("No download URL found for file ", file_id)
      return(FALSE)
    }
    
    # Create directory if needed
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
    
    # Download file
    headers <- add_headers("Authorization" = paste("Bearer", creds$token))
    response <- GET(download_url, headers, write_disk(output_path, overwrite = overwrite))
    
    if (status_code(response) == 200) {
      return(TRUE)
    } else {
      warning("Download failed: ", status_code(response))
      return(FALSE)
    }
    
  }, error = function(e) {
    warning("Error downloading file ", file_id, ": ", e$message)
    return(FALSE)
  })
}

# High-level Functions ----

#' Get all CCHS year folders 
#' @return data.frame with year folder information
get_cchs_years <- function() {
  folders <- osf_list_files()
  
  # Filter for year folders (4-digit numbers)
  year_pattern <- "^(19|20)[0-9]{2}$"
  year_folders <- folders[grepl(year_pattern, folders$name) & folders$kind == "folder", ]
  
  # Add numeric year column for sorting
  year_folders$year <- as.numeric(year_folders$name)
  year_folders <- year_folders[order(year_folders$year), ]
  
  return(year_folders)
}

#' Download all files from a CCHS year
#' @param year Numeric year (e.g., 2020)
#' @param output_dir Base output directory
#' @param structure_type "auto", "nested", or "flat"
#' @return list with download results
download_cchs_year <- function(year, output_dir = "temp_releases", structure_type = "auto") {
  
  year_str <- as.character(year)
  year_folders <- get_cchs_years()
  
  target_folder <- year_folders[year_folders$name == year_str, ]
  
  if (nrow(target_folder) == 0) {
    return(list(
      success = FALSE,
      error = paste("Year", year, "not found"),
      files_downloaded = 0
    ))
  }
  
  year_output_dir <- file.path(output_dir, year_str)
  
  # Get year folder contents
  contents <- osf_folder_contents(target_folder$id[1])
  
  if (nrow(contents) == 0) {
    return(list(
      success = FALSE,
      error = "Year folder is empty",
      files_downloaded = 0
    ))
  }
  
  cat("Year", year, "contents:", paste(contents$name, collapse = ", "), "\n")
  
  # Determine structure
  has_12_month <- "12-Month" %in% contents$name
  
  if (structure_type == "auto") {
    structure_type <- if (has_12_month) "nested" else "flat"
  }
  
  if (structure_type == "nested" && has_12_month) {
    return(download_nested_cchs_year(target_folder$id[1], year_output_dir))
  } else {
    return(download_flat_cchs_year(target_folder$id[1], year_output_dir))
  }
}

#' Download nested structure (12-Month/Master/Docs+Layout)
download_nested_cchs_year <- function(year_folder_id, output_dir) {
  
  total_downloaded <- 0
  
  tryCatch({
    # Navigate: year -> 12-Month -> Master
    contents <- osf_folder_contents(year_folder_id)
    month_folder <- contents[contents$name == "12-Month", ]
    
    if (nrow(month_folder) == 0) {
      return(list(success = FALSE, error = "No 12-Month folder", files_downloaded = 0))
    }
    
    month_contents <- osf_folder_contents(month_folder$id[1])
    master_folder <- month_contents[month_contents$name == "Master", ]
    
    if (nrow(master_folder) == 0) {
      return(list(success = FALSE, error = "No Master folder", files_downloaded = 0))
    }
    
    master_contents <- osf_folder_contents(master_folder$id[1])
    
    # Download from Docs and Layout folders
    for (folder_type in c("Docs", "Layout")) {
      target_folder <- master_contents[master_contents$name == folder_type, ]
      
      if (nrow(target_folder) == 0) next
      
      folder_contents <- osf_folder_contents(target_folder$id[1])
      target_dir <- file.path(output_dir, tolower(folder_type))
      
      for (i in 1:nrow(folder_contents)) {
        if (folder_contents$kind[i] == "file") {
          file_path <- file.path(target_dir, folder_contents$name[i])
          
          if (osf_download_file(folder_contents$id[i], file_path)) {
            total_downloaded <- total_downloaded + 1
          }
          
          Sys.sleep(0.2)
        }
      }
    }
    
    return(list(
      success = TRUE,
      files_downloaded = total_downloaded,
      structure = "nested"
    ))
    
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = paste("Nested download error:", e$message),
      files_downloaded = total_downloaded
    ))
  })
}

#' Download flat structure (files directly in year folder)
download_flat_cchs_year <- function(year_folder_id, output_dir) {
  
  total_downloaded <- 0
  
  tryCatch({
    contents <- osf_folder_contents(year_folder_id)
    
    for (i in 1:nrow(contents)) {
      if (contents$kind[i] == "file") {
        file_path <- file.path(output_dir, contents$name[i])
        
        if (osf_download_file(contents$id[i], file_path)) {
          total_downloaded <- total_downloaded + 1
        }
        
        Sys.sleep(0.2)
      }
    }
    
    return(list(
      success = TRUE,
      files_downloaded = total_downloaded,
      structure = "flat"
    ))
    
  }, error = function(e) {
    return(list(
      success = FALSE,
      error = paste("Flat download error:", e$message),
      files_downloaded = total_downloaded
    ))
  })
}

# Utility Functions ----

#' Test OSF API connection
test_osf_connection <- function() {
  cat("=== TESTING OSF API CONNECTION ===\n")
  
  tryCatch({
    creds <- get_osf_credentials()
    cat("✓ Credentials loaded\n")
    
    years <- get_cchs_years()
    cat("✓ API connection successful\n")
    cat("✓ Found", nrow(years), "CCHS years:", paste(sort(years$year), collapse = ", "), "\n")
    
    return(TRUE)
    
  }, error = function(e) {
    cat("✗ Connection failed:", e$message, "\n")
    return(FALSE)
  })
}

cat("OSF API Client loaded.\n")
cat("Available functions:\n")
cat("- test_osf_connection(): Test API connection\n")
cat("- get_cchs_years(): List all available years\n") 
cat("- download_cchs_year(year): Download specific year\n")
cat("- osf_list_files(): List files in component\n")