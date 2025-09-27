# Extract Template Structure from Existing CCHS Folder
# This script extracts the actual folder structure from an existing year

library(dplyr)
source("R/setup_osf.R")
source("R/cchs_folder_structure.R")

# Load environment and connect
if (file.exists(".env")) {
  readRenviron(".env")
}

config <- config::get()
project <- init_osf()
doc_node <- osf_retrieve_node(config$osf$documentation_component_id)

# Extract structure from 2021 (which has complete Docs and Layout folders)
cat("=== Extracting structure from 2021 folder ===\n")
files <- osf_ls_files(doc_node)
year_2021 <- files %>% filter(name == "2021") %>% pull(id) %>% osf_retrieve_file()

actual_structure_2021 <- extract_folder_structure(year_2021)
cat("Actual 2021 structure:\n")
str(actual_structure_2021)

# Compare with our template
cat("\n=== Comparing with our annual template ===\n")
cat("Our template:\n")
str(cchs_annual_structure)

# Extract structure from 2022 for verification
cat("\n=== Extracting structure from 2022 folder for verification ===\n")
year_2022 <- files %>% filter(name == "2022") %>% pull(id) %>% osf_retrieve_file()
actual_structure_2022 <- extract_folder_structure(year_2022)
cat("Actual 2022 structure:\n")
str(actual_structure_2022)

# Check if structures match
structures_match <- identical(actual_structure_2021, actual_structure_2022)
cat("\n2021 and 2022 structures match:", structures_match, "\n")

if (structures_match) {
  cat("✓ Confirmed: 2021 and 2022 have identical folder structures\n")
  cat("✓ We can use this as our template for creating new years\n")
} else {
  cat("⚠ Warning: 2021 and 2022 have different folder structures\n")
  cat("Manual review needed before proceeding\n")
}