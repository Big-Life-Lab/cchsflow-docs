# Save CCHS Structure Data
# Create permanent record of folder structure in both RData and YAML formats

library(dplyr)
library(yaml)
source("R/cchs_expected_structure.R")
source("R/cchs_structure_verification.R")

# Create comprehensive structure data for saving
create_cchs_structure_data <- function() {
  # Load environment and connect to get actual structure
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  source("R/setup_osf.R")
  config <- config::get()
  project <- init_osf()
  doc_node <- osf_retrieve_node(config$osf$documentation_component_id)
  
  # Get actual structure from OSF
  actual_folders <- osf_ls_files(doc_node)
  actual_years <- sort(as.numeric(actual_folders$name[!is.na(as.numeric(actual_folders$name))]))
  
  # Build comprehensive data object
  cchs_structure_data <- list(
    metadata = list(
      created_date = Sys.Date(),
      created_by = "CCHS Documentation Setup Script",
      osf_project_id = config$osf$project_id,
      osf_documentation_component_id = config$osf$documentation_component_id,
      description = "Complete CCHS folder structure for years 2001-2023"
    ),
    
    expected_structure = cchs_expected_structure,
    
    actual_structure = list(
      years_found = actual_years,
      folder_count = length(actual_years),
      last_verified = Sys.time()
    ),
    
    structure_definitions = list(
      early_cycles = list(
        years = as.numeric(names(cchs_expected_structure$early_cycles)),
        description = "Biannual CCHS cycles with custom naming (1.1, 2.1, 3.1)",
        pattern = "YEAR/CYCLE.1/Master/[Docs|Layout]"
      ),
      annual_surveys = list(
        years = cchs_expected_structure$annual_years,
        description = "Annual CCHS surveys with standard structure",
        pattern = "YEAR/12-Month/Master/[Docs|Layout]"
      )
    ),
    
    verification_functions = list(
      test_expected_years_exist = "Check if all expected year folders exist",
      test_year_structure = "Verify folder structure for specific year",
      run_complete_verification = "Run all verification tests"
    )
  )
  
  return(cchs_structure_data)
}

# Save as RData file
save_as_rdata <- function() {
  cat("Creating CCHS structure data...\n")
  cchs_structure_data <- create_cchs_structure_data()
  
  # Save to data directory
  if (!dir.exists("data")) {
    dir.create("data")
  }
  
  save(cchs_structure_data, file = "data/cchs_structure.RData")
  cat("✅ Saved CCHS structure to data/cchs_structure.RData\n")
  
  # Also save just the expected structure for easier loading
  cchs_expected <- cchs_structure_data$expected_structure
  save(cchs_expected, file = "data/cchs_expected_structure.RData")
  cat("✅ Saved expected structure to data/cchs_expected_structure.RData\n")
  
  return(cchs_structure_data)
}

# Convert structure to YAML-friendly format
structure_to_yaml_format <- function(structure_data) {
  # Convert dates to character for YAML compatibility
  yaml_data <- structure_data
  yaml_data$metadata$created_date <- as.character(yaml_data$metadata$created_date)
  yaml_data$actual_structure$last_verified <- as.character(yaml_data$actual_structure$last_verified)
  
  return(yaml_data)
}

# Save as YAML file
save_as_yaml <- function() {
  cat("Converting structure data to YAML format...\n")
  cchs_structure_data <- create_cchs_structure_data()
  yaml_data <- structure_to_yaml_format(cchs_structure_data)
  
  if (!dir.exists("data")) {
    dir.create("data")
  }
  
  write_yaml(yaml_data, "data/cchs_structure.yml")
  cat("✅ Saved CCHS structure to data/cchs_structure.yml\n")
  
  # Also save a simplified version for easier reading
  simplified_yaml <- list(
    metadata = yaml_data$metadata,
    expected_years = list(
      early_cycles = names(yaml_data$expected_structure$early_cycles),
      annual_years = yaml_data$expected_structure$annual_years
    ),
    structure_patterns = yaml_data$structure_definitions
  )
  
  write_yaml(simplified_yaml, "data/cchs_structure_simple.yml")
  cat("✅ Saved simplified structure to data/cchs_structure_simple.yml\n")
}

# Main function to save both formats
save_cchs_structure_data <- function() {
  cat("=== Saving CCHS Structure Data ===\n")
  
  # Save RData format
  structure_data <- save_as_rdata()
  
  # Save YAML format  
  save_as_yaml()
  
  # Print summary
  cat("\n=== Files Created ===\n")
  cat("📁 data/cchs_structure.RData - Complete structure data\n")
  cat("📁 data/cchs_expected_structure.RData - Expected structure only\n")
  cat("📁 data/cchs_structure.yml - Complete structure in YAML\n")
  cat("📁 data/cchs_structure_simple.yml - Simplified YAML version\n")
  
  cat("\n=== Usage Examples ===\n")
  cat("# Load in R:\n")
  cat("load('data/cchs_structure.RData')\n")
  cat("load('data/cchs_expected_structure.RData')\n\n")
  cat("# Load YAML in R:\n")
  cat("library(yaml)\n")
  cat("structure <- read_yaml('data/cchs_structure.yml')\n")
  
  return(structure_data)
}