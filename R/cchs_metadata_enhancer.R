# CCHS Metadata Enhancement System
# Handles real-world naming inconsistencies discovered in OSF scan

library(dplyr)
library(stringr)
source("R/naming_pattern_analysis.R")

# Enhanced metadata system for CCHS files based on actual scan findings
enhance_file_metadata <- function(file_data) {
  
  if (nrow(file_data) == 0) {
    return(file_data)
  }
  
  # Add enhanced metadata columns
  enhanced_data <- file_data %>%
    mutate(
      # Core categorization
      file_type_category = sapply(name, categorize_file_type),
      language = sapply(name, identify_language),
      normalized_name = sapply(name, normalize_filename),
      
      # Year extraction (handles various year formats)
      extracted_year = extract_year_from_filename(name),
      year_format_type = classify_year_format(name),
      
      # Naming pattern analysis
      spacing_pattern = classify_spacing_pattern(name),
      case_pattern = classify_case_pattern(name),
      
      # Content classification
      content_type = classify_content_type(name),
      file_extension = tolower(tools::file_ext(name)),
      
      # Quality indicators
      naming_consistency_score = calculate_consistency_score(name),
      potential_issues = identify_potential_issues(name),
      
      # Enhanced searchability
      search_keywords = generate_search_keywords(name),
      standardized_description = generate_standardized_description(name)
    )
  
  return(enhanced_data)
}

# Extract year from various filename formats (vectorized)
extract_year_from_filename <- function(filename) {
  sapply(filename, function(fn) {
    # Handle various year patterns found in real data
    year_patterns <- c(
      "CCHS[_\\s]+(\\d{4})[_\\s-]",           # CCHS_2023_ or CCHS 2023 
      "ESCC[_\\s]+(\\d{4})[_\\s-]",           # ESCC_2022_
      "(\\d{4})-(\\d{4})",                     # 2009-2010 ranges
      "CCHS[_\\s]+(\\d{4})[_\\s]+(\\d{4}-\\d{4})", # CCHS_2010_2009-2010
      "^HS[_\\s].*",                           # HS files (need context)
      "(\\d{4})"                               # Fallback: any 4-digit number
    )
    
    for (pattern in year_patterns) {
      match <- str_extract(fn, pattern)
      if (!is.na(match)) {
        # Extract the first 4-digit year found
        year <- str_extract(match, "\\d{4}")
        if (!is.na(year) && as.numeric(year) >= 2000 && as.numeric(year) <= 2030) {
          return(as.numeric(year))
        }
      }
    }
    
    return(NA)
  }, USE.NAMES = FALSE)
}

# Classify year format type (vectorized)
classify_year_format <- function(filename) {
  sapply(filename, function(fn) {
    if (grepl("\\d{4}-\\d{4}", fn)) {
      return("year_range")
    } else if (grepl("CCHS_\\d{4}_\\d{4}-\\d{4}", fn)) {
      return("redundant_year")
    } else if (grepl("(CCHS|ESCC)[_\\s]+\\d{4}", fn)) {
      return("single_year")
    } else {
      return("no_year_pattern")
    }
  }, USE.NAMES = FALSE)
}

# Classify spacing patterns based on real findings (vectorized)
classify_spacing_pattern <- function(filename) {
  sapply(filename, function(fn) {
    if (grepl("^[A-Z]+_[0-9]+_.*_[A-Za-z]", fn)) {
      return("consistent_underscores")
    } else if (grepl("^[A-Z]+ [0-9]+ .* \\(.*\\)", fn)) {
      return("consistent_spaces")
    } else if (grepl("_.*\\s.*_", fn) || grepl("_.*\\s[A-Z]", fn)) {
      return("mixed_separators")
    } else if (grepl("^[A-Za-z_]+\\.(sas|sps|SAS|SPS)$", fn)) {
      return("syntax_file_pattern")
    } else {
      return("irregular_pattern")
    }
  }, USE.NAMES = FALSE)
}

# Classify case patterns (vectorized)
classify_case_pattern <- function(filename) {
  sapply(filename, function(fn) {
    extension <- tools::file_ext(fn)
    basename_part <- tools::file_path_sans_ext(fn)
    
    case_type <- c()
    
    # Extension case
    if (extension %in% c("SAS", "SPS", "PDF")) {
      case_type <- c(case_type, "uppercase_extension")
    } else if (extension %in% c("sas", "sps", "pdf")) {
      case_type <- c(case_type, "lowercase_extension")
    }
    
    # Basename case patterns
    if (grepl("^[A-Z]", basename_part)) {
      case_type <- c(case_type, "uppercase_start")
    } else if (grepl("^[a-z]", basename_part)) {
      case_type <- c(case_type, "lowercase_start")
    }
    
    # Mixed case within name
    if (grepl("[a-z][A-Z]|[A-Z][a-z]", basename_part)) {
      case_type <- c(case_type, "mixed_case")
    }
    
    return(paste(case_type, collapse = "|"))
  }, USE.NAMES = FALSE)
}

# Enhanced content type classification based on real patterns (vectorized)
classify_content_type <- function(filename) {
  sapply(filename, function(fn) {
    filename_lower <- tolower(fn)
    
    # Enhanced patterns based on actual file discovery
    content_types <- list(
      "data_dictionary" = c("data.?dictionary", "dictionary", "dictionnaire", "données"),
      "questionnaire" = c("questionnaire", "quest"),
      "derived_variables" = c("derived.?var", "derived"),
      "user_guide" = c("user.?guide", "guide", "utilisateur"),
      "cv_tables" = c("cv.?table", "coeff.?var", "partagé"),
      "weights" = c("weight", "hhwt", "household.?weight"),
      "income_master" = c("income", "master.?file"),
      "record_layout" = c("record.?layout", "layout"),
      "interpreting" = c("interpret", "estimates"),
      "content_overview" = c("content.?overview", "overview"),
      "optional_content" = c("optional.?content", "optional"),
      "alpha_index" = c("alpha.?index", "index"),
      "errata" = c("errata"),
      "syntax" = c("\\.(sas|sps)$", "fmt", "frq", "lbe", "lbf", "pfe", "pff", "miss")
    )
    
    for (type in names(content_types)) {
      if (any(sapply(content_types[[type]], function(pattern) grepl(pattern, filename_lower)))) {
        return(type)
      }
    }
    
    return("other")
  }, USE.NAMES = FALSE)
}

# Calculate consistency score based on naming conventions (vectorized)
calculate_consistency_score <- function(filename) {
  sapply(filename, function(fn) {
    score <- 100
    
    # Penalty for mixed separators
    if (classify_spacing_pattern(fn) == "mixed_separators") {
      score <- score - 25
    }
    
    # Penalty for case inconsistencies
    case_pattern <- classify_case_pattern(fn)
    if (grepl("uppercase_extension.*lowercase_start|lowercase_extension.*uppercase_start", case_pattern)) {
      score <- score - 15
    }
    
    # Penalty for special characters in basic names
    if (grepl("[()\\[\\]]", fn)) {
      score <- score - 10
    }
    
    # Penalty for extremely long or short names
    if (nchar(fn) > 60) {
      score <- score - 10
    } else if (nchar(fn) < 10) {
      score <- score - 5
    }
    
    return(max(0, score))
  }, USE.NAMES = FALSE)
}

# Identify potential naming issues (vectorized)
identify_potential_issues <- function(filename) {
  sapply(filename, function(fn) {
    issues <- c()
    
    if (classify_spacing_pattern(fn) == "mixed_separators") {
      issues <- c(issues, "mixed_separators")
    }
    
    if (grepl("\\s+", fn)) {
      issues <- c(issues, "contains_spaces")
    }
    
    if (grepl("[()\\[\\]]", fn)) {
      issues <- c(issues, "special_characters")
    }
    
    case_pattern <- classify_case_pattern(fn)
    if (grepl("uppercase_extension.*lowercase_start", case_pattern)) {
      issues <- c(issues, "case_inconsistency")
    }
    
    if (is.na(extract_year_from_filename(fn))) {
      issues <- c(issues, "no_year_detected")
    }
    
    if (length(issues) == 0) {
      return("none")
    } else {
      return(paste(issues, collapse = "|"))
    }
  }, USE.NAMES = FALSE)
}

# Generate search keywords for enhanced discoverability (vectorized)
generate_search_keywords <- function(filename) {
  sapply(filename, function(fn) {
    content_type <- classify_content_type(fn)
    language <- identify_language(fn)
    year <- extract_year_from_filename(fn)
    
    # Base keywords
    keywords <- c("cchs", "canadian_community_health_survey")
    
    # Add content-specific keywords
    content_keywords <- list(
      "data_dictionary" = c("dictionary", "variables", "codes", "frequencies"),
      "questionnaire" = c("questions", "survey", "instruments"),
      "derived_variables" = c("derived", "calculated", "variables"),
      "user_guide" = c("guide", "documentation", "instructions"),
      "cv_tables" = c("coefficient_variation", "quality", "tables"),
      "weights" = c("weights", "household", "sampling"),
      "syntax" = c("sas", "spss", "syntax", "programming")
    )
    
    if (content_type %in% names(content_keywords)) {
      keywords <- c(keywords, content_keywords[[content_type]])
    }
    
    # Add year
    if (!is.na(year)) {
      keywords <- c(keywords, as.character(year))
    }
    
    # Add language
    keywords <- c(keywords, language)
    
    return(paste(unique(keywords), collapse = " "))
  }, USE.NAMES = FALSE)
}

# Generate standardized description (vectorized)
generate_standardized_description <- function(filename) {
  sapply(filename, function(fn) {
    content_type <- classify_content_type(fn)
    language <- identify_language(fn)
    year <- extract_year_from_filename(fn)
    
    # Content type descriptions
    type_descriptions <- list(
      "data_dictionary" = "Data Dictionary with variable definitions and frequencies",
      "questionnaire" = "Survey questionnaire and instruments",
      "derived_variables" = "Derived variables documentation",
      "user_guide" = "User guide and documentation",
      "cv_tables" = "Coefficient of variation tables",
      "weights" = "Sampling weights documentation",
      "income_master" = "Income master file documentation",
      "record_layout" = "Record layout and data structure",
      "syntax" = "Statistical software syntax file",
      "other" = "CCHS documentation file"
    )
    
    description <- if (content_type %in% names(type_descriptions)) {
      type_descriptions[[content_type]]
    } else {
      "CCHS documentation file"
    }
    
    # Add year if available
    if (!is.na(year)) {
      description <- paste("CCHS", year, description)
    } else {
      description <- paste("CCHS", description)
    }
    
    # Add language indicator
    if (language == "french") {
      description <- paste(description, "(French)")
    }
    
    return(description)
  }, USE.NAMES = FALSE)
}

# Apply metadata enhancement to scan results
enhance_scan_results <- function(scan_results_file = "data/cchs_comprehensive_scan.RData") {
  
  if (!file.exists(scan_results_file)) {
    stop("Scan results file not found. Run comprehensive scan first.")
  }
  
  load(scan_results_file)
  
  cat("=== ENHANCING METADATA FOR CCHS FILES ===\n")
  
  enhanced_results <- list()
  total_files <- 0
  
  for (year in names(scan_results)) {
    cat("Processing year", year, "... ")
    
    year_data <- scan_results[[year]]
    if ("files" %in% names(year_data) && nrow(year_data$files) > 0) {
      # Filter to actual files (not folders or empty entries)
      actual_files <- year_data$files %>% 
        filter(type == "file" & name != "empty" & name != "error")
      
      if (nrow(actual_files) > 0) {
        # Apply metadata enhancement
        enhanced_files <- enhance_file_metadata(actual_files)
        
        # Update year data
        enhanced_results[[year]] <- list(
          year = year_data$year,
          file_count = nrow(enhanced_files),
          files = enhanced_files,
          scan_time = year_data$scan_time,
          enhanced_time = Sys.time()
        )
        
        total_files <- total_files + nrow(enhanced_files)
        cat("✓", nrow(enhanced_files), "files enhanced\n")
      } else {
        enhanced_results[[year]] <- year_data
        cat("(no files)\n")
      }
    } else {
      enhanced_results[[year]] <- year_data
      cat("(no data)\n")
    }
  }
  
  # Save enhanced results
  enhanced_scan_results <- enhanced_results
  save(enhanced_scan_results, file = "data/cchs_enhanced_metadata.RData")
  
  cat("\n✅ Enhanced metadata saved to data/cchs_enhanced_metadata.RData\n")
  cat("Total files processed:", total_files, "\n")
  
  return(enhanced_results)
}

cat("CCHS Metadata Enhancement System loaded.\n")
cat("Run enhance_scan_results() to process comprehensive scan data.\n")