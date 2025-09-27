# Verify Complete CCHS Folder Structure on OSF
# This script reads the actual structure to confirm everything was created correctly

library(dplyr)
source("R/setup_osf.R")

# Load environment and connect
if (file.exists(".env")) {
  readRenviron(".env")
}

config <- config::get()
project <- init_osf()
doc_node <- osf_retrieve_node(config$osf$documentation_component_id)

# Get all year folders
all_folders <- osf_ls_files(doc_node)
year_folders <- all_folders %>% arrange(name)

cat("=== Complete CCHS Documentation Structure ===\n")
cat("Found", nrow(year_folders), "year folders:\n")

# Function to display structure for each year
show_year_structure <- function(year_name, year_id) {
  cat("\n📁", year_name, "\n")
  
  year_folder <- osf_retrieve_file(year_id)
  level1 <- osf_ls_files(year_folder)
  
  for (i in 1:nrow(level1)) {
    cat("  📁", level1$name[i], "\n")
    
    # Get level 2 (Master)
    level1_folder <- osf_retrieve_file(level1$id[i])
    level2 <- osf_ls_files(level1_folder)
    
    for (j in 1:nrow(level2)) {
      cat("    📁", level2$name[j], "\n")
      
      # Get level 3 (Docs, Layout)
      level2_folder <- osf_retrieve_file(level2$id[j])
      level3 <- osf_ls_files(level2_folder)
      
      for (k in 1:nrow(level3)) {
        cat("      📁", level3$name[k], "\n")
      }
    }
  }
}

# Show structure for all years
for (i in 1:nrow(year_folders)) {
  show_year_structure(year_folders$name[i], year_folders$id[i])
}

# Summary check
cat("\n=== Summary Check ===\n")
years_found <- sort(as.numeric(year_folders$name))
cat("Years found:", paste(years_found, collapse = ", "), "\n")

expected_early <- c(2001, 2003, 2005)
expected_annual <- 2006:2023
expected_all <- c(expected_early, expected_annual)

missing_years <- setdiff(expected_all, years_found)
extra_years <- setdiff(years_found, expected_all)

if (length(missing_years) == 0) {
  cat("✅ All expected years present\n")
} else {
  cat("❌ Missing years:", paste(missing_years, collapse = ", "), "\n")
}

if (length(extra_years) == 0) {
  cat("✅ No unexpected years found\n")
} else {
  cat("ℹ️ Extra years found:", paste(extra_years, collapse = ", "), "\n")
}

cat("\n✅ Structure verification complete!")