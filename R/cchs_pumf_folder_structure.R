# CCHS PUMF Folder Structure Definition
#
# This script defines the folder structure for CCHS PUMF data files
# organized by year/cycle on Google Drive.
#
# Structure:
#   Year/
#     ├── Data/
#     │   ├── .Rdata files
#     │   ├── STATA (.dta) files
#     │   ├── CSV files
#     │   └── TXT (fixed-width) files
#     ├── Bootstrap/
#     │   └── Bootstrap data files (same formats)
#     └── Code/
#         └── Program code files (SAS, SPSS, R, etc.)

library(dplyr)

# CCHS PUMF Data Structure
# Three main categories: Data, Bootstrap, Code
cchs_pumf_data_structure <- list(
  "Data" = list(),        # Main data files: .Rdata, .dta, .csv, .txt
  "Bootstrap" = list(),   # Bootstrap weight files (same formats)
  "Code" = list()         # Program code: .sas, .sps, .R, etc.
)

# File format categories
# We'll keep these specific formats for PUMF data
pumf_data_formats <- c("Rdata", "dta", "csv", "txt")
pumf_code_formats <- c("sas", "sps", "do", "R", "r")

# CCHS Year/Cycle mapping
cchs_pumf_years <- list(
  # Early cycles (biannual)
  early_cycles = list(
    "2001" = list(
      cycle_name = "1.1",
      period = "2001-2002",
      type = "cycle"
    ),
    "2003" = list(
      cycle_name = "2.1",
      period = "2003-2004",
      type = "cycle"
    ),
    "2005" = list(
      cycle_name = "3.1",
      period = "2005-2006",
      type = "cycle"
    )
  ),

  # Annual years (2007 onwards)
  annual_years = 2007:2023
)

#' Get all CCHS PUMF years
#'
#' @return Vector of all CCHS years (numeric)
get_all_pumf_years <- function() {
  early_years <- as.numeric(names(cchs_pumf_years$early_cycles))
  annual_years <- cchs_pumf_years$annual_years
  return(sort(c(early_years, annual_years)))
}

#' Get year information
#'
#' @param year Year (numeric or character)
#' @return List with year metadata
get_year_info <- function(year) {
  year_str <- as.character(year)

  # Check if it's an early cycle
  if (year_str %in% names(cchs_pumf_years$early_cycles)) {
    info <- cchs_pumf_years$early_cycles[[year_str]]
    return(list(
      year = year_str,
      cycle = info$cycle_name,
      period = info$period,
      type = info$type,
      temporal_code = "d"  # dual-year for early cycles
    ))
  }

  # Check if it's an annual year
  if (as.numeric(year) %in% cchs_pumf_years$annual_years) {
    return(list(
      year = year_str,
      cycle = NULL,
      period = year_str,
      type = "annual",
      temporal_code = "s"  # single-year for annual
    ))
  }

  # Year not found
  return(NULL)
}

#' Get folder structure for a specific year
#'
#' @param year Year (numeric or character)
#' @return List representing the folder structure
get_pumf_structure_for_year <- function(year) {
  return(cchs_pumf_data_structure)
}

#' Create PUMF folder structure on OSF/Google Drive
#'
#' This function creates the folder structure for a single year
#'
#' @param parent_node OSF node or folder reference
#' @param year Year to create structure for
#' @param verbose Print progress messages
#' @return Created year folder node
create_pumf_year_structure <- function(parent_node, year, verbose = TRUE) {
  year_str <- as.character(year)
  year_info <- get_year_info(year)

  if (is.null(year_info)) {
    stop("Year ", year_str, " not found in CCHS PUMF years")
  }

  if (verbose) {
    cat("\n=== Creating PUMF structure for", year_str, "===\n")
    if (!is.null(year_info$cycle)) {
      cat("Cycle:", year_info$cycle, "\n")
    }
    cat("Period:", year_info$period, "\n")
    cat("Type:", year_info$type, "\n\n")
  }

  # Create year folder
  if (verbose) cat("Creating year folder:", year_str, "\n")
  year_folder <- create_or_get_folder(parent_node, year_str, verbose)

  # Create subfolders: Data, Bootstrap, Code
  structure <- get_pumf_structure_for_year(year)

  for (folder_name in names(structure)) {
    if (verbose) cat("  Creating subfolder:", folder_name, "\n")
    create_or_get_folder(year_folder, folder_name, verbose = FALSE)
  }

  if (verbose) cat("✓ Structure created for", year_str, "\n")

  return(year_folder)
}

#' Helper: Create folder or get existing
#'
#' @param parent_node Parent folder/node
#' @param folder_name Name of folder to create
#' @param verbose Print messages
#' @return Folder node
create_or_get_folder <- function(parent_node, folder_name, verbose = TRUE) {
  # Check if using OSF or Google Drive
  # This is a generic implementation - adapt based on your API

  if (inherits(parent_node, "osf_tbl_file")) {
    # OSF implementation
    library(osfr)
    existing_files <- osf_ls_files(parent_node)

    if (nrow(existing_files) > 0 && folder_name %in% existing_files$name) {
      if (verbose) cat("    ✓ Folder '", folder_name, "' already exists\n", sep = "")
      folder <- existing_files %>%
        filter(name == folder_name) %>%
        pull(id) %>%
        osf_retrieve_file()
    } else {
      folder <- osf_mkdir(parent_node, folder_name)
      if (verbose) cat("    ✓ Created: ", folder_name, "\n", sep = "")
    }

    return(folder)
  } else {
    # Google Drive implementation (future)
    stop("Google Drive implementation not yet available. Use OSF.")
  }
}

#' Create PUMF structure for multiple years
#'
#' @param parent_node Parent folder/node
#' @param years Vector of years to create
#' @param verbose Print progress
#' @return List of created year folders
create_pumf_structure_batch <- function(parent_node, years = NULL, verbose = TRUE) {
  if (is.null(years)) {
    years <- get_all_pumf_years()
  }

  if (verbose) {
    cat("\n")
    cat("═══════════════════════════════════════════════════════════\n")
    cat("CCHS PUMF Folder Structure Creation\n")
    cat("═══════════════════════════════════════════════════════════\n\n")
    cat("Years to create:", length(years), "\n")
    cat("Years:", paste(years, collapse = ", "), "\n")
  }

  year_folders <- list()

  for (year in years) {
    year_folder <- create_pumf_year_structure(parent_node, year, verbose)
    year_folders[[as.character(year)]] <- year_folder
  }

  if (verbose) {
    cat("\n")
    cat("═══════════════════════════════════════════════════════════\n")
    cat("✓ All PUMF structures created successfully!\n")
    cat("═══════════════════════════════════════════════════════════\n\n")
    cat("Total years created:", length(year_folders), "\n")
    cat("Structure per year:\n")
    cat("  - Data/       (Main data files: .Rdata, .dta, .csv, .txt)\n")
    cat("  - Bootstrap/  (Bootstrap weight files)\n")
    cat("  - Code/       (Program code: .sas, .sps, .R, etc.)\n\n")
  }

  return(year_folders)
}

#' Categorize file into appropriate folder
#'
#' Determines whether a file belongs in Data, Bootstrap, or Code folder
#'
#' @param filename Name of the file
#' @return Folder name ("Data", "Bootstrap", or "Code")
categorize_pumf_file <- function(filename) {
  # Get file extension
  ext <- tolower(tools::file_ext(filename))
  filename_lower <- tolower(filename)

  # Bootstrap files
  if (grepl("bootstrap|bsw|boot", filename_lower, ignore.case = TRUE)) {
    return("Bootstrap")
  }

  # Code files
  if (ext %in% pumf_code_formats ||
      grepl("\\.(sas|sps|spss|do|syntax|r)$", filename_lower)) {
    return("Code")
  }

  # Data files (default)
  if (ext %in% c("rdata", "dta", "csv", "txt", "dat")) {
    return("Data")
  }

  # Documentation files - might need special handling
  if (ext %in% c("pdf", "doc", "docx", "html", "xml")) {
    # These should probably go in the documentation catalog, not data folders
    return("Documentation")  # Special marker
  }

  # Default to Data
  return("Data")
}

#' Get expected path for a PUMF file
#'
#' @param filename Name of the file
#' @param year Year of the data
#' @return Expected relative path (e.g., "2015/Data/cchs_2015.Rdata")
get_expected_pumf_path <- function(filename, year) {
  category <- categorize_pumf_file(filename)

  if (category == "Documentation") {
    # Documentation shouldn't be in data folders
    return(NULL)
  }

  return(file.path(year, category, filename))
}

#' Validate PUMF file belongs to correct year
#'
#' Extracts year from filename and checks if it matches expected year
#'
#' @param filename Name of the file
#' @param expected_year Expected year
#' @return TRUE if match, FALSE otherwise
validate_file_year <- function(filename, expected_year) {
  # Extract years from filename
  year_pattern <- "20[0-9]{2}"
  years_found <- stringr::str_extract_all(filename, year_pattern)[[1]]

  if (length(years_found) == 0) {
    warning("No year found in filename: ", filename)
    return(FALSE)
  }

  # Check if expected year is in the filename
  return(as.character(expected_year) %in% years_found)
}

#' Print structure summary
print_pumf_structure_summary <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("CCHS PUMF Folder Structure Definition\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  cat("Years covered:\n")
  cat("  Early cycles (biannual): 2001, 2003, 2005\n")
  cat("  Annual: 2007-2023\n\n")

  cat("Folder structure per year:\n")
  cat("  <YEAR>/\n")
  cat("    ├── Data/\n")
  cat("    │   ├── .Rdata files\n")
  cat("    │   ├── .dta (STATA) files\n")
  cat("    │   ├── .csv files\n")
  cat("    │   └── .txt (fixed-width) files\n")
  cat("    ├── Bootstrap/\n")
  cat("    │   └── Bootstrap weight files (same formats)\n")
  cat("    └── Code/\n")
  cat("        └── Program files (.sas, .sps, .R, etc.)\n\n")

  cat("Early cycle mapping:\n")
  for (year_str in names(cchs_pumf_years$early_cycles)) {
    info <- cchs_pumf_years$early_cycles[[year_str]]
    cat(sprintf("  %s → Cycle %s (%s)\n", year_str, info$cycle_name, info$period))
  }

  cat("\n")
  cat("File format categories:\n")
  cat("  Data formats:  ", paste(pumf_data_formats, collapse = ", "), "\n")
  cat("  Code formats:  ", paste(pumf_code_formats, collapse = ", "), "\n")

  cat("\n")
  cat("Total years: ", length(get_all_pumf_years()), "\n")
  cat("═══════════════════════════════════════════════════════════\n\n")
}

# Export for use in other scripts
.pumf_structure <- list(
  structure = cchs_pumf_data_structure,
  years = cchs_pumf_years,
  data_formats = pumf_data_formats,
  code_formats = pumf_code_formats
)

# Print summary if run interactively
if (interactive()) {
  print_pumf_structure_summary()
  cat("Available functions:\n")
  cat("  get_all_pumf_years()              - Get list of all CCHS years\n")
  cat("  get_year_info(year)               - Get metadata for a year\n")
  cat("  get_pumf_structure_for_year(year) - Get folder structure for year\n")
  cat("  categorize_pumf_file(filename)    - Determine folder for a file\n")
  cat("  get_expected_pumf_path(file, yr)  - Get expected path for file\n")
  cat("  create_pumf_year_structure(...)   - Create structure for one year\n")
  cat("  create_pumf_structure_batch(...)  - Create structure for all years\n\n")
}
