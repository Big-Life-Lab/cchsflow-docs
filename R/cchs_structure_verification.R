# CCHS Structure Verification Tests
# Systematic verification against expected structure

library(dplyr)
source("R/setup_osf.R")
source("R/cchs_expected_structure.R")

# Verification test results storage
verification_results <- list()

# Test 1: Check if all expected years exist
test_expected_years_exist <- function(doc_node) {
  cat("=== Test 1: Expected Years Exist ===\n")
  
  # Get actual years from OSF (handle pagination)
  actual_folders <- osf_ls_files(doc_node)
  actual_years <- sort(as.numeric(actual_folders$name[!is.na(as.numeric(actual_folders$name))]))
  
  expected_years <- get_expected_years()
  
  missing_years <- setdiff(expected_years, actual_years)
  extra_years <- setdiff(actual_years, expected_years)
  
  result <- list(
    test_name = "expected_years_exist",
    expected_count = length(expected_years),
    actual_count = length(actual_years),
    expected_years = expected_years,
    actual_years = actual_years,
    missing_years = missing_years,
    extra_years = extra_years,
    pass = length(missing_years) == 0
  )
  
  cat("Expected years:", length(expected_years), "\n")
  cat("Actual years found:", length(actual_years), "\n")
  
  if (length(missing_years) == 0) {
    cat("✅ All expected years found\n")
  } else {
    cat("❌ Missing years:", paste(missing_years, collapse = ", "), "\n")
  }
  
  if (length(extra_years) > 0) {
    cat("ℹ️ Extra years found:", paste(extra_years, collapse = ", "), "\n")
  }
  
  return(result)
}

# Test 2: Check structure for specific year
test_year_structure <- function(doc_node, year) {
  cat("\n=== Test 2: Year", year, "Structure ===\n")
  
  expected_paths <- get_expected_paths_for_year(year)
  if (is.null(expected_paths)) {
    return(list(test_name = paste0("year_", year, "_structure"), 
                pass = FALSE, error = "Year not in expected structure"))
  }
  
  # Get actual structure for this year
  all_folders <- osf_ls_files(doc_node)
  year_folder_row <- all_folders %>% filter(name == as.character(year))
  
  if (nrow(year_folder_row) == 0) {
    result <- list(
      test_name = paste0("year_", year, "_structure"),
      year = year,
      expected_paths = expected_paths,
      actual_paths = character(0),
      missing_paths = expected_paths,
      pass = FALSE,
      error = "Year folder not found"
    )
    cat("❌ Year folder", year, "not found\n")
    return(result)
  }
  
  # Recursively get actual paths
  actual_paths <- get_actual_paths_for_year(year_folder_row$id[1])
  
  missing_paths <- setdiff(expected_paths, actual_paths)
  extra_paths <- setdiff(actual_paths, expected_paths)
  
  result <- list(
    test_name = paste0("year_", year, "_structure"),
    year = year,
    expected_paths = expected_paths,
    actual_paths = actual_paths,
    missing_paths = missing_paths,
    extra_paths = extra_paths,
    pass = length(missing_paths) == 0
  )
  
  cat("Expected paths:", length(expected_paths), "\n")
  cat("Actual paths:", length(actual_paths), "\n")
  
  if (length(missing_paths) == 0) {
    cat("✅ All expected paths found for year", year, "\n")
  } else {
    cat("❌ Missing paths for year", year, ":", paste(missing_paths, collapse = ", "), "\n")
  }
  
  if (length(extra_paths) > 0) {
    cat("ℹ️ Extra paths for year", year, ":", paste(extra_paths, collapse = ", "), "\n")
  }
  
  return(result)
}

# Helper function to get actual paths for a year folder
get_actual_paths_for_year <- function(year_folder_id) {
  get_paths_recursive <- function(folder_id, prefix = "") {
    tryCatch({
      folder <- osf_retrieve_file(folder_id)
      files <- osf_ls_files(folder)
      
      if (nrow(files) == 0) return(character(0))
      
      paths <- character(0)
      for (i in 1:nrow(files)) {
        current_path <- if (prefix == "") files$name[i] else paste(prefix, files$name[i], sep = "/")
        paths <- c(paths, current_path)
        
        # Recursively get subpaths
        sub_paths <- get_paths_recursive(files$id[i], current_path)
        paths <- c(paths, sub_paths)
      }
      
      return(paths)
    }, error = function(e) {
      return(character(0))
    })
  }
  
  return(get_paths_recursive(year_folder_id))
}

# Run complete verification
run_complete_verification <- function() {
  cat("Starting CCHS Structure Verification...\n\n")
  
  # Load environment and connect
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  
  config <- config::get()
  project <- init_osf()
  doc_node <- osf_retrieve_node(config$osf$documentation_component_id)
  
  results <- list()
  
  # Test 1: Expected years exist
  results$years_test <- test_expected_years_exist(doc_node)
  
  # Test 2: Structure for each expected year
  expected_years <- get_expected_years()
  results$year_structure_tests <- list()
  
  for (year in expected_years) {
    results$year_structure_tests[[as.character(year)]] <- test_year_structure(doc_node, year)
  }
  
  # Summary
  cat("\n=== Verification Summary ===\n")
  all_tests_pass <- results$years_test$pass && 
                   all(sapply(results$year_structure_tests, function(x) x$pass))
  
  if (all_tests_pass) {
    cat("🎉 All verification tests PASSED!\n")
  } else {
    cat("❌ Some verification tests FAILED\n")
    
    if (!results$years_test$pass) {
      cat("  - Years test failed\n")
    }
    
    failed_year_tests <- results$year_structure_tests[!sapply(results$year_structure_tests, function(x) x$pass)]
    if (length(failed_year_tests) > 0) {
      cat("  - Failed year structure tests:", paste(names(failed_year_tests), collapse = ", "), "\n")
    }
  }
  
  return(results)
}