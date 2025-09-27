# Clean up nested 2020 folder and create annual years 2008-2019

library(dplyr)
source("R/cchs_folder_structure.R")

# Load environment and connect
if (file.exists(".env")) {
  readRenviron(".env")
}

source("R/setup_osf.R")
project <- init_osf()
config <- config::get()
doc_node <- osf_retrieve_node(config$osf$documentation_component_id)

# 1. Remove nested 2020 folder from 2023 directory
cat("=== Removing nested 2020 folder from 2023 ===\n")
files_2023 <- osf_ls_files(doc_node) %>% filter(name == "2023")
if (nrow(files_2023) > 0) {
  folder_2023 <- osf_retrieve_file(files_2023$id[1])
  
  # Check contents of 2023 folder
  contents_2023 <- osf_ls_files(folder_2023)
  nested_2020 <- contents_2023 %>% filter(name == "2020")
  
  if (nrow(nested_2020) > 0) {
    # Delete the nested 2020 folder
    nested_2020_file <- osf_retrieve_file(nested_2020$id[1])
    osf_rm(nested_2020_file, check = FALSE)
    message("✓ Removed nested 2020 folder from 2023 directory")
  } else {
    message("No nested 2020 folder found in 2023 directory")
  }
} else {
  message("2023 folder not found")
}

# 2. Create annual folder structure for years 2008-2019
cat("\n=== Creating annual folders for 2008-2019 ===\n")
annual_years <- 2008:2019
create_cchs_years(annual_years, "annual")

cat("\n✓ Cleanup and annual folder creation complete!")