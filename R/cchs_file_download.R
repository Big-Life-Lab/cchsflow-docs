# CCHS File Download and Categorization System
# Functions for bulk downloading and categorizing CCHS documentation files

library(dplyr)
source("R/load_cchs_structure.R")

# File type classification rules
file_type_rules <- list(
  data_dictionary = c(
    "DataDictionary", "DictionnaireDonnées", "Data_Dictionary", 
    "Dictionary", "Freqs", "frequencies"
  ),
  questionnaire = c(
    "Questionnaire", "Survey_Instrument", "Questions"
  ),
  user_guide = c(
    "User_Guide", "Guide_Utilisateur", "UserGuide", "User Guide"
  ),
  derived_variables = c(
    "Derived_Variables", "Derived", "Variables_Dérivées"
  ),
  cv_tables = c(
    "CV_Tables", "CV", "Coefficient_Variation"
  ),
  household_weights = c(
    "Household_Weights", "HHD", "Weights", "Pondération"
  ),
  income_file = c(
    "Income", "Revenu", "Master_File"
  ),
  layout_files = c(
    ".sas", ".sps", ".do", "fmt", "frq", "lbe", "lbf", "pfe", "miss"
  ),
  record_layout = c(
    "Record_Layout", "Layout", "Format"
  )
)

# Language detection rules
language_rules <- list(
  english = c(
    "CCHS_", "User_Guide", "DataDictionary", "Questionnaire", 
    "Derived_Variables", "CV_Tables", "Household_Weights", 
    "Income_Master", "Record_Layout"
  ),
  french = c(
    "ESCC_", "Guide_Utilisateur", "DictionnaireDonnées", 
    "Variables_Dérivées", "Partagé", "Pondération"
  )
)

# Categorize a single file based on its name
categorize_file <- function(filename) {
  filename_clean <- gsub("\\s+", "_", filename)  # Normalize spaces
  
  # Detect file type
  file_type <- "unknown"
  for (type in names(file_type_rules)) {
    patterns <- file_type_rules[[type]]
    if (any(sapply(patterns, function(p) grepl(p, filename_clean, ignore.case = TRUE)))) {
      file_type <- type
      break
    }
  }
  
  # Detect language
  language <- "unknown"
  for (lang in names(language_rules)) {
    patterns <- language_rules[[lang]]
    if (any(sapply(patterns, function(p) grepl(p, filename_clean, ignore.case = TRUE)))) {
      language <- lang
      break
    }
  }
  
  # Extract year from filename
  year_match <- regmatches(filename, regexpr("20\\d{2}", filename))
  year <- if (length(year_match) > 0) as.numeric(year_match[1]) else NA
  
  return(list(
    filename = filename,
    file_type = file_type,
    language = language,
    year = year,
    extension = tools::file_ext(filename)
  ))
}

# Categorize all files in the structure data
categorize_all_files <- function() {
  if (!exists("cchs_structure_data")) load_cchs_structure()
  
  all_categorized <- list()
  
  for (year in names(cchs_structure_data$file_listings)) {
    year_files <- cchs_structure_data$file_listings[[year]]$files
    
    # Only categorize actual files (not folders)
    files_only <- year_files[year_files$type == "file", ]
    
    if (nrow(files_only) > 0) {
      year_categorized <- list()
      
      for (i in 1:nrow(files_only)) {
        file_info <- categorize_file(files_only$name[i])
        file_info$path <- files_only$path[i]
        file_info$osf_id <- files_only$id[i]
        file_info$survey_year <- as.numeric(year)
        
        year_categorized[[files_only$name[i]]] <- file_info
      }
      
      all_categorized[[year]] <- year_categorized
    }
  }
  
  return(all_categorized)
}

# Filter files by criteria
filter_files <- function(categorized_files, 
                         file_types = NULL, 
                         languages = c("english"), 
                         years = NULL,
                         exclude_unknown = TRUE) {
  
  matches <- list()
  
  for (year in names(categorized_files)) {
    year_files <- categorized_files[[year]]
    
    for (filename in names(year_files)) {
      file_info <- year_files[[filename]]
      
      # Apply filters
      type_match <- is.null(file_types) || file_info$file_type %in% file_types
      lang_match <- is.null(languages) || file_info$language %in% languages
      year_match <- is.null(years) || file_info$survey_year %in% years
      unknown_filter <- !exclude_unknown || 
                       (file_info$file_type != "unknown" && file_info$language != "unknown")
      
      if (type_match && lang_match && year_match && unknown_filter) {
        matches[[paste(year, filename, sep = "_")]] <- file_info
      }
    }
  }
  
  return(matches)
}

# Download files from OSF based on criteria
download_files_by_criteria <- function(file_types = NULL,
                                     languages = c("english"),
                                     years = NULL,
                                     local_dir = "downloads",
                                     categorized_files = NULL,
                                     dry_run = FALSE) {
  
  # Load categorized files if not provided
  if (is.null(categorized_files)) {
    cat("Categorizing files...\n")
    categorized_files <- categorize_all_files()
  }
  
  # Filter files
  files_to_download <- filter_files(categorized_files, file_types, languages, years)
  
  if (length(files_to_download) == 0) {
    cat("No files match the specified criteria.\n")
    return(invisible(NULL))
  }
  
  cat("Found", length(files_to_download), "files matching criteria:\n")
  
  # Show what would be downloaded
  for (i in 1:min(10, length(files_to_download))) {
    file_info <- files_to_download[[i]]
    cat("  ", file_info$survey_year, "-", file_info$file_type, "-", file_info$filename, "\n")
  }
  
  if (length(files_to_download) > 10) {
    cat("  ... and", length(files_to_download) - 10, "more files\n")
  }
  
  if (dry_run) {
    cat("\nDry run - no files downloaded.\n")
    return(files_to_download)
  }
  
  # Create download directory
  if (!dir.exists(local_dir)) {
    dir.create(local_dir, recursive = TRUE)
    cat("Created directory:", local_dir, "\n")
  }
  
  # Connect to OSF
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  source("R/setup_osf.R")
  project <- init_osf()
  
  downloaded_files <- list()
  failed_downloads <- list()
  
  cat("\nStarting downloads...\n")
  
  for (i in seq_along(files_to_download)) {
    file_info <- files_to_download[[i]]
    
    tryCatch({
      # Create subdirectory by file type
      type_dir <- file.path(local_dir, file_info$file_type)
      if (!dir.exists(type_dir)) {
        dir.create(type_dir, recursive = TRUE)
      }
      
      # Create filename with year prefix for organization
      local_filename <- paste0(file_info$survey_year, "_", file_info$filename)
      local_path <- file.path(type_dir, local_filename)
      
      # Download file from OSF
      osf_file <- osf_retrieve_file(file_info$osf_id)
      osf_download(osf_file, path = local_path, conflicts = "overwrite")
      
      cat("✓ Downloaded:", local_filename, "\n")
      downloaded_files[[length(downloaded_files) + 1]] <- list(
        file_info = file_info,
        local_path = local_path
      )
      
    }, error = function(e) {
      cat("✗ Failed:", file_info$filename, "-", e$message, "\n")
      failed_downloads[[length(failed_downloads) + 1]] <- list(
        file_info = file_info,
        error = e$message
      )
    })
  }
  
  cat("\nDownload Summary:\n")
  cat("Successfully downloaded:", length(downloaded_files), "files\n")
  cat("Failed downloads:", length(failed_downloads), "files\n")
  cat("Files saved to:", local_dir, "\n")
  
  return(list(
    downloaded = downloaded_files,
    failed = failed_downloads,
    local_dir = local_dir
  ))
}

# Quick function to get all data dictionaries
download_data_dictionaries <- function(years = NULL, local_dir = "downloads/data_dictionaries", dry_run = FALSE) {
  return(download_files_by_criteria(
    file_types = "data_dictionary",
    languages = "english",
    years = years,
    local_dir = local_dir,
    dry_run = dry_run
  ))
}

# Quick function to get all questionnaires
download_questionnaires <- function(years = NULL, local_dir = "downloads/questionnaires") {
  return(download_files_by_criteria(
    file_types = "questionnaire", 
    languages = "english",
    years = years,
    local_dir = local_dir
  ))
}

# Summary function for file analysis
summarize_file_catalog <- function() {
  cat("=== CCHS File Categorization Summary ===\n")
  
  categorized <- categorize_all_files()
  
  # Count by file type
  type_counts <- table(sapply(unlist(categorized, recursive = FALSE), function(x) x$file_type))
  cat("\nFiles by Type:\n")
  print(type_counts)
  
  # Count by language  
  lang_counts <- table(sapply(unlist(categorized, recursive = FALSE), function(x) x$language))
  cat("\nFiles by Language:\n")
  print(lang_counts)
  
  # English data dictionaries by year
  english_dicts <- filter_files(categorized, 
                               file_types = "data_dictionary", 
                               languages = "english")
  
  dict_years <- sapply(english_dicts, function(x) x$survey_year)
  cat("\nEnglish Data Dictionaries Available for Years:\n")
  cat(paste(sort(unique(dict_years)), collapse = ", "), "\n")
  
  return(categorized)
}