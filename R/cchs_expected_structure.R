# CCHS Expected Folder Structure Definition
# This creates the definitive expected structure for verification

library(dplyr)

# Define expected CCHS structure
cchs_expected_structure <- list(
  # Early cycle years (biannual)
  early_cycles = list(
    "2001" = list(
      cycle_name = "1.1",
      structure = list(
        "1.1" = list(
          "Master" = list(
            "Docs" = list(),
            "Layout" = list()
          )
        )
      )
    ),
    "2003" = list(
      cycle_name = "2.1", 
      structure = list(
        "2.1" = list(
          "Master" = list(
            "Docs" = list(),
            "Layout" = list()
          )
        )
      )
    ),
    "2005" = list(
      cycle_name = "3.1",
      structure = list(
        "3.1" = list(
          "Master" = list(
            "Docs" = list(),
            "Layout" = list()
          )
        )
      )
    )
  ),
  
  # Annual years (2006 onwards)
  annual_years = 2006:2023,
  annual_structure = list(
    "12-Month" = list(
      "Master" = list(
        "Docs" = list(),
        "Layout" = list()
      )
    )
  )
)

# Create complete expected years list
get_expected_years <- function() {
  early_years <- as.numeric(names(cchs_expected_structure$early_cycles))
  annual_years <- cchs_expected_structure$annual_years
  return(sort(c(early_years, annual_years)))
}

# Get expected structure for a specific year
get_expected_structure_for_year <- function(year) {
  year_str <- as.character(year)
  
  # Check if it's an early cycle year
  if (year_str %in% names(cchs_expected_structure$early_cycles)) {
    return(cchs_expected_structure$early_cycles[[year_str]]$structure)
  }
  
  # Check if it's an annual year
  if (year %in% cchs_expected_structure$annual_years) {
    return(cchs_expected_structure$annual_structure)
  }
  
  # Year not found
  return(NULL)
}

# Convert structure to flat path list for easier comparison
structure_to_paths <- function(structure, prefix = "") {
  paths <- character(0)
  
  for (name in names(structure)) {
    current_path <- if (prefix == "") name else paste(prefix, name, sep = "/")
    paths <- c(paths, current_path)
    
    if (length(structure[[name]]) > 0) {
      sub_paths <- structure_to_paths(structure[[name]], current_path)
      paths <- c(paths, sub_paths)
    }
  }
  
  return(paths)
}

# Get all expected paths for a year
get_expected_paths_for_year <- function(year) {
  structure <- get_expected_structure_for_year(year)
  if (is.null(structure)) return(NULL)
  return(structure_to_paths(structure))
}

# Summary function
summarize_expected_structure <- function() {
  expected_years <- get_expected_years()
  
  cat("=== CCHS Expected Structure Summary ===\n")
  cat("Total expected years:", length(expected_years), "\n")
  cat("Years:", paste(expected_years, collapse = ", "), "\n\n")
  
  cat("Early cycle years (with cycle names):\n")
  for (year_str in names(cchs_expected_structure$early_cycles)) {
    cycle_info <- cchs_expected_structure$early_cycles[[year_str]]
    cat(" ", year_str, "→", cycle_info$cycle_name, "\n")
    paths <- get_expected_paths_for_year(as.numeric(year_str))
    for (path in paths) {
      cat("    ", path, "\n")
    }
  }
  
  cat("\nAnnual years structure:\n")
  annual_paths <- structure_to_paths(cchs_expected_structure$annual_structure)
  for (path in annual_paths) {
    cat("  ", path, "\n")
  }
  
  cat("\nAnnual years:", paste(cchs_expected_structure$annual_years, collapse = ", "), "\n")
}

# Export the structure definition
cchs_structure_definition <- cchs_expected_structure