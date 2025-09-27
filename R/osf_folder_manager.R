# OSF.io Folder Management for CCHS Documentation
# Script to create and manage folder structures for different CCHS cycles

source("R/setup_osf.R")

# Create folder structure for a specific CCHS cycle
create_cycle_folders <- function(project, cycle_year, base_container = NULL) {
  
  # If base_container is specified, work within that container
  if (!is.null(base_container)) {
    container <- osf_ls_nodes(project) %>%
      filter(name == base_container) %>%
      pull(id) %>%
      osf_retrieve_node()
  } else {
    container <- project
  }
  
  # Create main cycle folder
  cycle_folder_name <- paste0("CCHS_", cycle_year)
  
  # Check if folder already exists
  existing_folders <- osf_ls_files(container)
  if (nrow(existing_folders) > 0 && cycle_folder_name %in% existing_folders$name) {
    message("Folder '", cycle_folder_name, "' already exists")
    cycle_folder <- existing_folders %>%
      filter(name == cycle_folder_name) %>%
      pull(id) %>%
      osf_retrieve_file()
  } else {
    cycle_folder <- osf_mkdir(container, cycle_folder_name)
    message("✓ Created folder: ", cycle_folder_name)
  }
  
  return(cycle_folder)
}

# Replicate folder structure from existing cycle to new cycles
replicate_folder_structure <- function(project, source_cycle, target_cycles, 
                                     base_container = NULL) {
  
  # Get source folder structure
  source_folder <- create_cycle_folders(project, source_cycle, base_container)
  
  # Function to recursively get folder structure
  get_folder_structure <- function(folder, path = "") {
    files <- osf_ls_files(folder)
    if (nrow(files) == 0) return(character(0))
    
    folders <- files %>% filter(meta.kind == "folder")
    if (nrow(folders) == 0) return(character(0))
    
    folder_paths <- character(0)
    for (i in 1:nrow(folders)) {
      folder_name <- folders$name[i]
      current_path <- if (path == "") folder_name else paste(path, folder_name, sep = "/")
      folder_paths <- c(folder_paths, current_path)
      
      # Recursively get subfolders
      subfolder <- osf_retrieve_file(folders$id[i])
      sub_paths <- get_folder_structure(subfolder, current_path)
      folder_paths <- c(folder_paths, sub_paths)
    }
    
    return(folder_paths)
  }
  
  # Get source structure
  source_structure <- get_folder_structure(source_folder)
  message("Source folder structure found: ", length(source_structure), " folders")
  
  # Create structure for each target cycle
  for (target_cycle in target_cycles) {
    message("Creating structure for cycle: ", target_cycle)
    target_folder <- create_cycle_folders(project, target_cycle, base_container)
    
    # Create each folder in the structure
    for (folder_path in source_structure) {
      create_nested_folders(target_folder, folder_path)
    }
  }
}

# Helper function to create nested folder structure
create_nested_folders <- function(parent_folder, folder_path) {
  path_parts <- strsplit(folder_path, "/")[[1]]
  current_folder <- parent_folder
  
  for (part in path_parts) {
    existing_files <- osf_ls_files(current_folder)
    if (nrow(existing_files) > 0 && part %in% existing_files$name) {
      # Folder exists, navigate to it
      current_folder <- existing_files %>%
        filter(name == part) %>%
        pull(id) %>%
        osf_retrieve_file()
    } else {
      # Create new folder
      current_folder <- osf_mkdir(current_folder, part)
      message("  ✓ Created: ", folder_path)
    }
  }
}

# Main function to set up CCHS documentation folders
setup_cchs_folders <- function(source_cycle, target_cycles, base_container = NULL) {
  # Initialize OSF connection
  project <- init_osf()
  
  # Replicate folder structure
  replicate_folder_structure(project, source_cycle, target_cycles, base_container)
  
  message("✓ CCHS folder setup complete!")
}