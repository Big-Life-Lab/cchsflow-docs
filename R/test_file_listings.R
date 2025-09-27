# Test File Listings for a Single Year
# Start with one year to test the approach

library(dplyr)

# Load environment
if (file.exists(".env")) {
  readRenviron(".env")
}

source("R/setup_osf.R")
config <- config::get()
project <- init_osf()
doc_node <- osf_retrieve_node(config$osf$documentation_component_id)

# Test with 2021 (which we know exists and has files)
cat("=== Testing File Listing for Year 2021 ===\n")
all_folders <- osf_ls_files(doc_node)
year_2021 <- all_folders %>% filter(name == "2021")

if (nrow(year_2021) > 0) {
  year_folder <- osf_retrieve_file(year_2021$id[1])
  
  # Get level 1 (should be "12-Month")
  level1 <- osf_ls_files(year_folder)
  cat("Level 1 in 2021:\n")
  print(level1$name)
  
  if (nrow(level1) > 0) {
    # Get level 2 (should be "Master")
    level1_folder <- osf_retrieve_file(level1$id[1])
    level2 <- osf_ls_files(level1_folder)
    cat("\nLevel 2 in", level1$name[1], ":\n")
    print(level2$name)
    
    if (nrow(level2) > 0) {
      # Get level 3 (should be "Docs" and "Layout")
      for (i in 1:nrow(level2)) {
        level2_folder <- osf_retrieve_file(level2$id[i])
        level3 <- osf_ls_files(level2_folder)
        cat("\nLevel 3 in", level2$name[i], ":\n")
        if (nrow(level3) > 0) {
          print(level3$name)
          cat("Found", nrow(level3), "items in", level2$name[i], "\n")
        } else {
          cat("No files found in", level2$name[i], "\n")
        }
      }
    }
  }
} else {
  cat("2021 folder not found\n")
}

cat("\n=== Summary ===\n")
cat("This test shows the file structure and any actual files within the folders.\n")