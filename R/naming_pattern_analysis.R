# CCHS File Naming Pattern Analysis
# Real-world inconsistencies discovered through comprehensive OSF scan

library(dplyr)

# Analysis of actual naming SNAFUs found in CCHS files (2009-2023)
analyze_naming_patterns <- function() {
  
  cat("=== CCHS NAMING PATTERN ANALYSIS ===\n")
  cat("Based on comprehensive scan of OSF files\n\n")
  
  # 1. INCONSISTENT SPACING PATTERNS
  cat("1. SPACING INCONSISTENCIES:\n")
  cat("   • Underscores vs Spaces in similar contexts:\n")
  cat("     - 'CCHS_2022_Income_Master File.pdf' (mixed _ and space)\n")
  cat("     - 'CCHS_2023_Income_Master_File.pdf' (all underscores)\n")
  cat("     - 'CCHS 2023 Data Dictionary (rounded frequencies).pdf' (all spaces)\n\n")
  
  # 2. CASE INCONSISTENCIES  
  cat("2. CASE INCONSISTENCIES:\n")
  cat("   • SAS file extensions:\n")
  cat("     - 'HS_HHWT_i.sas' (lowercase .sas)\n")
  cat("     - 'hs_i.SAS' (uppercase .SAS)\n")
  cat("     - 'hs_fmt.SAS' vs 'HS_fmt.sas'\n")
  cat("   • Variable name casing:\n")
  cat("     - 'HS_HHWT_i.sas' (uppercase prefix)\n")
  cat("     - 'hs_i.SAS' (lowercase prefix)\n\n")
  
  # 3. CONTENT DESCRIPTION VARIATIONS
  cat("3. CONTENT DESCRIPTION VARIATIONS:\n")
  cat("   • Data Dictionary naming:\n")
  cat("     - 'CCHS_2009_DataDictionary_Freq.pdf'\n")
  cat("     - 'CCHS_2010_DataDictionary_Freqs.pdf' (Freqs vs Freq)\n")
  cat("     - 'CCHS_2022_DataDictionary_Freqs.pdf'\n")
  cat("     - 'CCHS 2023 Data Dictionary (rounded frequencies).pdf' (completely different format)\n\n")
  
  # 4. YEAR FORMAT INCONSISTENCIES
  cat("4. YEAR FORMAT INCONSISTENCIES:\n")
  cat("   • Multi-year vs single year indicators:\n")
  cat("     - 'CCHS_2009-2010_Content_Overview.pdf' (spans multiple years)\n")
  cat("     - 'CCHS_2010_2009-2010_User_Guide.pdf' (redundant year info)\n")
  cat("     - 'CCHS_2000-2014_Errata.pdf' (long range)\n\n")
  
  # 5. SPECIAL CHARACTER USAGE
  cat("5. SPECIAL CHARACTER USAGE:\n")
  cat("   • Parentheses and spaces:\n")
  cat("     - 'CCHS 2023 Data Dictionary (rounded frequencies).pdf'\n")
  cat("     - 'CCHS_2010_Alpha Index.pdf' (space instead of underscore)\n")
  cat("   • Mixed separators in same year:\n")
  cat("     - 2023 has both 'CCHS_2023_' and 'CCHS 2023 ' patterns\n\n")
  
  # 6. LANGUAGE VARIATIONS
  cat("6. BILINGUAL INCONSISTENCIES:\n")
  cat("   • French files appear inconsistently:\n")
  cat("     - 2022: 'ESCC_2022_CV_Tables_Partagé.pdf'\n")
  cat("     - 2022: 'ESCC_2022_DictionnaireDonnées_Fréq.pdf'\n")
  cat("     - Some years have French versions, others don't\n\n")
  
  # Return categorized patterns for metadata system
  return(list(
    spacing_patterns = c("underscore_separated", "space_separated", "mixed_separators"),
    case_patterns = c("uppercase_extensions", "lowercase_extensions", "mixed_case"),
    content_variations = c("freq_vs_freqs", "abbreviated_vs_full", "parenthetical_descriptions"),
    year_formats = c("single_year", "year_range", "redundant_year"),
    special_chars = c("parentheses", "hyphens", "spaces_in_compound"),
    language_patterns = c("english_only", "bilingual_present", "french_variations")
  ))
}

# Function to categorize file types based on naming patterns
categorize_file_type <- function(filename) {
  filename_lower <- tolower(filename)
  
  # Enhanced categorization based on real patterns found
  if (grepl("(data.?dictionary|dictionary|dict)", filename_lower)) {
    return("data_dictionary")
  } else if (grepl("(questionnaire|quest)", filename_lower)) {
    return("questionnaire") 
  } else if (grepl("(derived.?var|derived)", filename_lower)) {
    return("derived_variables")
  } else if (grepl("(user.?guide|guide)", filename_lower)) {
    return("user_guide")
  } else if (grepl("(cv.?table|coeff.?var)", filename_lower)) {
    return("cv_tables")
  } else if (grepl("(weight|hhwt)", filename_lower)) {
    return("weights")
  } else if (grepl("(income|master.?file)", filename_lower)) {
    return("income_master")
  } else if (grepl("(record.?layout|layout)", filename_lower)) {
    return("record_layout")
  } else if (grepl("(alpha.?index|index)", filename_lower)) {
    return("alpha_index")
  } else if (grepl("(content.?overview|overview)", filename_lower)) {
    return("content_overview")
  } else if (grepl("(optional.?content|optional)", filename_lower)) {
    return("optional_content")
  } else if (grepl("(interpret|estimates)", filename_lower)) {
    return("interpreting_estimates")
  } else if (grepl("errata", filename_lower)) {
    return("errata")
  } else if (grepl("\\.(sas|sps)$", filename_lower)) {
    return("syntax_file")
  } else {
    return("other")
  }
}

# Function to identify language from filename
identify_language <- function(filename) {
  filename_lower <- tolower(filename)
  
  # French indicators
  if (grepl("^escc_", filename_lower) || 
      grepl("(partagé|partage|dictionnaire|données|fréq|utilisateur)", filename_lower)) {
    return("french")
  } else {
    return("english")
  }
}

# Function to normalize naming inconsistencies
normalize_filename <- function(filename) {
  # Remove common inconsistencies while preserving meaning
  normalized <- filename
  
  # Standardize spacing
  normalized <- gsub("_([A-Z])", "_\\L\\1", normalized, perl = TRUE)
  
  # Standardize extensions to lowercase
  normalized <- gsub("\\.(SAS|SPS|PDF)$", ".\\L\\1", normalized, perl = TRUE)
  
  # Standardize common terms
  normalized <- gsub("DataDictionary", "Data_Dictionary", normalized)
  normalized <- gsub("Freqs?", "Frequencies", normalized)
  normalized <- gsub("CV_Tables", "Coefficient_Variation_Tables", normalized)
  
  return(normalized)
}

# Main analysis function
cat("Running naming pattern analysis...\n")
patterns <- analyze_naming_patterns()
cat("Analysis complete. Patterns identified for metadata enhancement system.\n")