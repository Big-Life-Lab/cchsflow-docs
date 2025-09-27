# Load CCHS Structure Data into Global Environment
# Simple function to load the enhanced structure data for easy access

# Load CCHS structure data into global environment
load_cchs_structure <- function(enhanced = TRUE) {
  if (enhanced && file.exists("data/cchs_structure_enhanced.RData")) {
    load("data/cchs_structure_enhanced.RData", envir = .GlobalEnv)
    cat("✅ Loaded enhanced CCHS structure data\n")
    cat("Available as: cchs_structure_data\n")
    return(invisible(cchs_structure_data))
  } else if (file.exists("data/cchs_structure.RData")) {
    load("data/cchs_structure.RData", envir = .GlobalEnv)
    cat("✅ Loaded basic CCHS structure data\n")
    cat("Available as: cchs_structure_data\n")
    return(invisible(cchs_structure_data))
  } else {
    stop("No CCHS structure data files found. Run save_cchs_structure_data() first.")
  }
}

# Quick access functions
get_expected_years <- function() {
  if (!exists("cchs_structure_data")) load_cchs_structure()
  early_years <- as.numeric(names(cchs_structure_data$expected_structure$early_cycles))
  annual_years <- cchs_structure_data$expected_structure$annual_years
  return(sort(c(early_years, annual_years)))
}

get_files_for_year <- function(year) {
  if (!exists("cchs_structure_data")) load_cchs_structure()
  
  year_str <- as.character(year)
  if (year_str %in% names(cchs_structure_data$file_listings)) {
    return(cchs_structure_data$file_listings[[year_str]]$files)
  } else {
    return(data.frame())
  }
}

search_files <- function(pattern) {
  if (!exists("cchs_structure_data")) load_cchs_structure()
  
  matches <- data.frame()
  for (year in names(cchs_structure_data$file_listings)) {
    year_files <- cchs_structure_data$file_listings[[year]]$files
    matching_files <- year_files[grepl(pattern, year_files$name, ignore.case = TRUE), ]
    
    if (nrow(matching_files) > 0) {
      matching_files$year <- year
      matches <- rbind(matches, matching_files)
    }
  }
  return(matches)
}

# Summary function
cchs_summary <- function() {
  if (!exists("cchs_structure_data")) load_cchs_structure()
  
  cat("=== CCHS Structure Summary ===\n")
  
  # Years info
  expected_years <- get_expected_years()
  actual_years <- cchs_structure_data$actual_structure$years_found
  
  cat("Expected years:", length(expected_years), "(", min(expected_years), "-", max(expected_years), ")\n")
  cat("Years found on OSF:", length(actual_years), "\n")
  
  # File info
  if ("file_listings" %in% names(cchs_structure_data)) {
    total_files <- cchs_structure_data$actual_structure$total_files
    total_folders <- cchs_structure_data$actual_structure$total_folders
    cat("Total files:", total_files, "\n")
    cat("Total folders:", total_folders, "\n")
    
    # Years with files
    years_with_files <- names(cchs_structure_data$file_listings)[
      sapply(cchs_structure_data$file_listings, function(x) x$actual_file_count > 0)
    ]
    if (length(years_with_files) > 0) {
      cat("Years with files:", paste(years_with_files, collapse = ", "), "\n")
    }
  }
  
  cat("Last updated:", cchs_structure_data$metadata$created_date, "\n")
}

# Auto-load on source
cat("CCHS Structure functions loaded. Use:\n")
cat("  load_cchs_structure()  - Load structure data\n")
cat("  cchs_summary()         - Show structure summary\n")
cat("  get_expected_years()   - List all expected years\n")
cat("  get_files_for_year(X)  - Get files for year X\n")
cat("  search_files('pattern') - Search files by name\n")