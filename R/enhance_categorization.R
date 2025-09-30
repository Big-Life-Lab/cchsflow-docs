# Enhanced CCHS Categorization System
# Adds secondary categories and content-based tagging for better semantic classification

library(yaml)
library(dplyr)

#' Enhance catalog with secondary categories and content tags
#' 
#' @param catalog_file Path to existing catalog
#' @param output_file Path for enhanced catalog
enhance_categorization <- function(catalog_file = "data/catalog/cchs_catalog.yaml",
                                  output_file = "data/catalog/cchs_catalog_enhanced.yaml") {
  
  cat("=== ENHANCING CCHS CATEGORIZATION SYSTEM ===\n")
  cat("Input:", catalog_file, "\n")
  cat("Output:", output_file, "\n\n")
  
  # Load existing catalog
  catalog <- yaml::read_yaml(catalog_file)
  
  # Add metadata about enhancement
  catalog$catalog_metadata$categorization_version <- "2.0"
  catalog$catalog_metadata$enhancement_date <- format(Sys.Date(), "%Y-%m-%d")
  catalog$catalog_metadata$categorization_features <- list(
    "secondary_categories" = "Multiple content categories per document",
    "content_tags" = "Semantic content classification",
    "derived_variables_detection" = "Automatic identification of derived variables content"
  )
  
  enhanced_count <- 0
  
  # Process each file
  for (i in seq_along(catalog$files)) {
    file_entry <- catalog$files[[i]]
    
    # Initialize new fields
    file_entry$secondary_categories <- NULL
    file_entry$content_tags <- NULL
    
    # Analyze content for secondary categorization
    secondary_cats <- detect_secondary_categories(file_entry)
    content_tags <- detect_content_tags(file_entry)
    
    if (length(secondary_cats) > 0) {
      file_entry$secondary_categories <- secondary_cats
      enhanced_count <- enhanced_count + 1
    }
    
    if (length(content_tags) > 0) {
      file_entry$content_tags <- content_tags
    }
    
    catalog$files[[i]] <- file_entry
  }
  
  # Write enhanced catalog
  yaml::write_yaml(catalog, output_file)
  
  cat("✅ Enhanced categorization complete!\n")
  cat("📊 Files with secondary categories:", enhanced_count, "\n")
  cat("📁 Output:", output_file, "\n")
  
  return(catalog)
}

#' Detect secondary categories based on filename and current category
detect_secondary_categories <- function(file_entry) {
  filename_lower <- tolower(file_entry$filename)
  current_category <- file_entry$category
  secondary <- c()
  
  # Derived variables detection
  derived_keywords <- c("dv_doc", "derived", "income_variables", "new_income", "revised_dv")
  if (any(sapply(derived_keywords, function(kw) grepl(kw, filename_lower)))) {
    if (current_category != "derived-variables") {
      secondary <- c(secondary, "derived-variables")
    }
  }
  
  # Variable labels that contain derived info
  if (current_category == "variable-labels-english" || current_category == "variable-labels-french") {
    # SPSS files often contain derived variable definitions
    if (grepl("\\.sps$", filename_lower)) {
      secondary <- c(secondary, "derived-variables")
    }
  }
  
  # Data dictionaries that are actually user guides
  if (current_category == "data-dictionary" && grepl("guide|user", filename_lower)) {
    secondary <- c(secondary, "user-guide")
  }
  
  # Questionnaires that contain methodology
  if (current_category == "questionnaire" && grepl("method|guide", filename_lower)) {
    secondary <- c(secondary, "user-guide")
  }
  
  return(secondary)
}

#' Detect content-based tags for semantic classification
detect_content_tags <- function(file_entry) {
  filename_lower <- tolower(file_entry$filename)
  tags <- c()
  
  # Income-specific content
  if (grepl("income", filename_lower)) {
    tags <- c(tags, "income-variables")
  }
  
  # Frequency content
  if (grepl("freq", filename_lower)) {
    tags <- c(tags, "frequency-tables")
  }
  
  # Methodology content
  if (grepl("method|approach", filename_lower)) {
    tags <- c(tags, "methodology")
  }
  
  # Weights content
  if (grepl("weight|wt", filename_lower)) {
    tags <- c(tags, "survey-weights")
  }
  
  # Health-specific content
  if (grepl("health|hs[sv]", filename_lower)) {
    tags <- c(tags, "health-variables")
  }
  
  # Geographic content
  if (grepl("province|geographic|geo", filename_lower)) {
    tags <- c(tags, "geographic-variables")
  }
  
  # Supplement content
  if (grepl("supplement|supp", filename_lower)) {
    tags <- c(tags, "supplement-module")
  }
  
  return(tags)
}

#' Generate categorization report
generate_categorization_report <- function(enhanced_catalog) {
  files <- enhanced_catalog$files
  
  cat("\n=== CATEGORIZATION ENHANCEMENT REPORT ===\n")
  
  # Count files with secondary categories
  files_with_secondary <- files[sapply(files, function(x) !is.null(x$secondary_categories))]
  cat("Files with secondary categories:", length(files_with_secondary), "\n\n")
  
  # Show examples
  cat("Examples of enhanced categorization:\n")
  for (i in 1:min(5, length(files_with_secondary))) {
    file <- files_with_secondary[[i]]
    cat("  ", file$cchs_uid, "\n")
    cat("    Primary:", file$category, "\n")
    cat("    Secondary:", paste(file$secondary_categories, collapse = ", "), "\n")
    if (!is.null(file$content_tags)) {
      cat("    Tags:", paste(file$content_tags, collapse = ", "), "\n")
    }
    cat("\n")
  }
  
  # Count by secondary category
  all_secondary <- unlist(lapply(files_with_secondary, function(x) x$secondary_categories))
  if (length(all_secondary) > 0) {
    cat("Secondary categories distribution:\n")
    secondary_counts <- table(all_secondary)
    for (cat in names(secondary_counts)) {
      cat("  ", cat, ":", secondary_counts[cat], "files\n")
    }
  }
}

# Function to update LinkML schema for enhanced categorization
update_schema_for_categorization <- function(schema_file = "metadata/cchs_schema_linkml.yaml") {
  cat("\n=== SCHEMA UPDATE NEEDED ===\n")
  cat("The LinkML schema should be updated to include:\n\n")
  
  cat("1. Secondary categories slot:\n")
  cat("   secondary_categories:\n")
  cat("     description: Additional content categories for multi-purpose documents\n") 
  cat("     multivalued: true\n")
  cat("     range: DocumentCategoryEnum\n\n")
  
  cat("2. Content tags slot:\n")
  cat("   content_tags:\n")
  cat("     description: Semantic content classification tags\n")
  cat("     multivalued: true\n")
  cat("     examples:\n")
  cat("       - income-variables\n")
  cat("       - health-variables\n")
  cat("       - survey-weights\n\n")
  
  cat("3. Updated canonical filename to reflect primary category only\n")
  cat("4. Enhanced UID system documentation\n\n")
  
  cat("This maintains backward compatibility while adding semantic richness.\n")
}

cat("Enhanced categorization system loaded.\n")
cat("Usage: enhance_categorization()\n")