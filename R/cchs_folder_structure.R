# CCHS Folder Structure Templates
# This script defines the folder structure templates for different CCHS survey periods

library(dplyr)

# Standard annual structure (2007 onwards)
cchs_annual_structure <- list(
  "12-Month" = list(
    "Master" = list(
      "Docs" = list(),
      "Layout" = list()
    )
  )
)

# CCHS Cycle naming mapping for early years
cchs_cycle_mapping <- list(
  "2001" = "1.1",
  "2003" = "2.1", 
  "2005" = "3.1"
)

# Biannual structure (2001, 2003, 2005)
# Early CCHS cycles: 1.1 (2001-2002), 2.1 (2003-2004), 3.1 (2005-2006)
create_cycle_structure <- function(cycle_name) {
  structure <- list()
  structure[[cycle_name]] <- list(
    "Master" = list(
      "Docs" = list(),
      "Layout" = list()
    )
  )
  return(structure)
}

# Function to extract actual structure from existing folder
extract_folder_structure <- function(node, max_depth = 5) {
  extract_recursive <- function(current_node, depth = 0) {
    if (depth >= max_depth) return(list())
    
    files <- osf_ls_files(current_node)
    if (nrow(files) == 0) return(list())
    
    structure <- list()
    for (i in 1:nrow(files)) {
      folder_name <- files$name[i]
      tryCatch({
        subfolder <- osf_retrieve_file(files$id[i])
        structure[[folder_name]] <- extract_recursive(subfolder, depth + 1)
      }, error = function(e) {
        # If it's a file or inaccessible, store as empty list
        structure[[folder_name]] <- list()
      })
    }
    return(structure)
  }
  
  return(extract_recursive(node))
}

# Function to create folder structure from template
create_folders_from_structure <- function(parent_node, structure, path = "") {
  for (folder_name in names(structure)) {
    current_path <- if (path == "") folder_name else paste(path, folder_name, sep = "/")
    
    # Check if folder already exists
    existing_files <- osf_ls_files(parent_node)
    if (nrow(existing_files) > 0 && folder_name %in% existing_files$name) {
      message("  ✓ Folder '", folder_name, "' already exists")
      existing_folder <- existing_files %>%
        filter(name == folder_name) %>%
        pull(id) %>%
        osf_retrieve_file()
    } else {
      # Create new folder
      existing_folder <- osf_mkdir(parent_node, folder_name)
      message("  ✓ Created: ", current_path)
    }
    
    # Recursively create subfolders
    if (length(structure[[folder_name]]) > 0) {
      create_folders_from_structure(existing_folder, structure[[folder_name]], current_path)
    }
  }
}

# Function to create CCHS year folder with appropriate structure
create_cchs_year_folder <- function(doc_node, year, structure_type = "annual") {
  year_str <- as.character(year)
  
  # Determine which structure to use
  if (structure_type == "annual") {
    folder_structure <- cchs_annual_structure
  } else if (structure_type == "cycle") {
    # For early CCHS cycles, use the cycle naming
    if (year_str %in% names(cchs_cycle_mapping)) {
      cycle_name <- cchs_cycle_mapping[[year_str]]
      folder_structure <- create_cycle_structure(cycle_name)
      message("Using cycle name '", cycle_name, "' for year ", year_str)
    } else {
      stop("Year ", year_str, " not found in cycle mapping")
    }
  } else {
    stop("Invalid structure_type. Use 'annual' or 'cycle'")
  }
  
  # Create year folder
  existing_files <- osf_ls_files(doc_node)
  if (nrow(existing_files) > 0 && year_str %in% existing_files$name) {
    message("Year folder '", year_str, "' already exists")
    year_folder <- existing_files %>%
      filter(name == year_str) %>%
      pull(id) %>%
      osf_retrieve_file()
  } else {
    year_folder <- osf_mkdir(doc_node, year_str)
    message("✓ Created year folder: ", year_str)
  }
  
  # Create the structure within the year folder
  message("Creating ", structure_type, " structure for ", year_str, ":")
  create_folders_from_structure(year_folder, folder_structure)
  
  return(year_folder)
}

# Main function to create multiple CCHS year folders
create_cchs_years <- function(years, structure_type = "annual") {
  # Load environment variables
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  source("R/setup_osf.R")
  
  # Initialize OSF connection
  project <- init_osf()
  config <- config::get()
  doc_node <- osf_retrieve_node(config$osf$documentation_component_id)
  
  message("Creating CCHS folders for years: ", paste(years, collapse = ", "))
  message("Using structure type: ", structure_type)
  
  for (year in years) {
    message("\n=== Processing Year ", year, " ===")
    create_cchs_year_folder(doc_node, year, structure_type)
  }
  
  message("\n✓ All CCHS year folders created successfully!")
}

# Save structures for inspection
save_cchs_structures <- function() {
  structures <- list(
    annual = cchs_annual_structure,
    cycle_mapping = cchs_cycle_mapping
  )
  
  cat("=== CCHS Annual Structure (2007+) ===\n")
  str(structures$annual)
  
  cat("\n=== CCHS Cycle Mapping (Early Years) ===\n") 
  str(structures$cycle_mapping)
  
  cat("\n=== Example Cycle Structure for 2001 (1.1) ===\n")
  str(create_cycle_structure("1.1"))
  
  return(structures)
}