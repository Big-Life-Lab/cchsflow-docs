# Clean CCHS Catalog Structure
# Remove unnecessary fields, fix formats, implement clean IDs

library(yaml)
library(dplyr)

# Function to generate 6-digit alphanumeric ID
generate_short_id <- function(n = 1) {
  # Generate 6-character alphanumeric IDs (base36: 0-9, A-Z)
  replicate(n, {
    paste(sample(c(0:9, LETTERS), 6, replace = TRUE), collapse = "")
  })
}

# Function to convert scientific notation timestamp to ISO8601 date
convert_timestamp <- function(timestamp) {
  if (is.numeric(timestamp)) {
    # Handle both large timestamps and small numbers
    if (timestamp > 1000000000) {  # Unix timestamp
      format(as.Date(as.POSIXct(timestamp, origin = "1970-01-01")), "%Y-%m-%d")
    } else {  # Already converted or other format
      format(Sys.Date(), "%Y-%m-%d")  # Use current date as fallback
    }
  } else {
    timestamp
  }
}

# Function to clean language detection
clean_language <- function(filename, current_language) {
  filename_lower <- tolower(filename)
  
  # French indicators - should return ISO code
  if (grepl("francais|français|_f\\.|_f_|french|escc|questfrancais", filename_lower)) {
    return("FR")
  }
  
  # English indicators - should return ISO code
  if (grepl("english|_e\\.|_e_|cchs|questenglish", filename_lower)) {
    return("EN")
  }
  
  # Default to current if unclear
  if (!is.null(current_language) && current_language %in% c("EN", "FR", "english", "french")) {
    if (current_language %in% c("french", "FR")) return("FR")
    return("EN")
  }
  
  return("EN")  # Default fallback
}

# Function to map document categories (full names for id_category)
map_document_category <- function(filename, current_category = NULL) {
  filename_lower <- tolower(filename)
  
  # Layout/Syntax files
  if (grepl("\\.sas$", filename_lower)) {
    if (grepl("fmt|format", filename_lower)) return("format-file")
    if (grepl("frq|freq", filename_lower)) return("frequency-file")
    if (grepl("lbe|label.*e", filename_lower)) return("label-file-english")
    if (grepl("lbf|label.*f", filename_lower)) return("label-file-french")
    if (grepl("pfe|print.*e", filename_lower)) return("print-format-english")
    if (grepl("pff|print.*f", filename_lower)) return("print-format-french")
    if (grepl("hhwt|weight", filename_lower)) return("weights-file")
    if (grepl("readmstr|read.*master", filename_lower)) return("read-master")
    if (grepl("readshr|read.*share", filename_lower)) return("read-share")
    return("syntax-sas")
  }
  
  if (grepl("\\.sps$|\\.spss$", filename_lower)) {
    if (grepl("miss|missing", filename_lower)) return("missing-values")
    if (grepl("val.*e|value.*e", filename_lower)) return("value-labels-english")
    if (grepl("val.*f|value.*f", filename_lower)) return("value-labels-french")
    if (grepl("var.*e|variable.*e", filename_lower)) return("variable-labels-english")
    if (grepl("var.*f|variable.*f", filename_lower)) return("variable-labels-french")
    if (grepl("hhwt|weight", filename_lower)) return("weights-file")
    return("syntax-spss")
  }
  
  if (grepl("\\.do$|\\.dct$", filename_lower)) {
    if (grepl("infmt", filename_lower)) return("input-format")
    if (grepl("lbe|label.*e", filename_lower)) return("label-file-english")
    if (grepl("lbf|label.*f", filename_lower)) return("label-file-french")
    if (grepl("val.*e", filename_lower)) return("value-labels-english")
    if (grepl("val.*f", filename_lower)) return("value-labels-french")
    return("syntax-stata")
  }
  
  # Documentation files  
  if (grepl("user.*guide|guide.*util", filename_lower)) return("user-guide")
  if (grepl("data.*dict|dict.*data", filename_lower)) return("data-dictionary")
  if (grepl("questionnaire|quest", filename_lower)) return("questionnaire")
  if (grepl("record.*layout|layout.*record|cliché.*enreg", filename_lower)) return("record-layout")
  if (grepl("derived.*var|var.*deriv|variables.*dér", filename_lower)) return("derived-variables")
  if (grepl("content.*overview|aperçu.*contenu", filename_lower)) return("content-overview")
  if (grepl("optional.*content|contenu.*option", filename_lower)) return("optional-content")
  if (grepl("interpret.*estim|interprét.*estim", filename_lower)) return("interpreting-estimates")
  if (grepl("weight.*house|poids.*mén", filename_lower)) return("household-weights")
  if (grepl("cv.*table|table.*cv", filename_lower)) return("cv-tables")
  if (grepl("alpha.*index|table.*alphabet", filename_lower)) return("alpha-index")
  if (grepl("topic.*index|table.*sujet", filename_lower)) return("topical-index")
  if (grepl("income.*imput|imput.*revenu", filename_lower)) return("income-imputation")
  if (grepl("errata", filename_lower)) return("errata")
  if (grepl("readme|read.*me", filename_lower)) return("readme")
  
  # Default to current category or 'other'
  if (!is.null(current_category) && current_category != "" && current_category != "other") {
    # Standardize category format (replace underscores with hyphens)
    standardized <- gsub("_", "-", current_category)
    
    # Handle special cases and consolidations
    if (standardized == "income-file") return("weights-file")  # Consolidate income_file -> weights-file
    if (standardized == "weights") return("weights-file")      # Consolidate weights -> weights-file
    
    return(standardized)
  }
  
  return("other")
}

# Function to get category code for UID (enhanced with 2-character codes)
get_category_code <- function(category_name) {
  category_map <- list(
    # Documentation categories
    "questionnaire" = "qu",
    "user-guide" = "ug", 
    "data-dictionary" = "dd",
    "record-layout" = "rl",
    "derived-variables" = "dv",
    "content-overview" = "co",
    "optional-content" = "oc",
    "interpreting-estimates" = "ie",
    "household-weights" = "hw",
    "cv-tables" = "cv",
    "alpha-index" = "ai",
    "topical-index" = "ti",
    "income-imputation" = "ii",
    "errata" = "er",
    "readme" = "rm",
    
    # Layout/Syntax file categories
    "format-file" = "ff",
    "frequency-file" = "fq",
    "label-file-english" = "le",
    "label-file-french" = "lf",
    "print-format-english" = "pe",
    "print-format-french" = "pf",
    "weights-file" = "wf",
    "read-master" = "rm",
    "read-share" = "rs",
    "syntax-sas" = "ss",
    "syntax-spss" = "sp",
    "syntax-stata" = "st",
    "missing-values" = "mv",
    "value-labels-english" = "ve",
    "value-labels-french" = "vf",
    "variable-labels-english" = "xe",
    "variable-labels-french" = "xf",
    "input-format" = "if",
    "other" = "ot"
  )
  
  code <- category_map[[category_name]]
  if (is.null(code)) return("ot")  # Default to 'ot' for other
  return(code)
}

# Function to determine temporal type from year (full names)
get_temporal_type <- function(year) {
  year_num <- as.numeric(year)
  
  # Dual-year cycles
  if (year_num %in% c(2007, 2008, 2009, 2010, 2013, 2014)) {
    return("dual")
  }
  
  # Multi-year periods (if any special cases)
  # Add specific multi-year cases here if needed
  
  # Default to Single year
  return("single")
}

# Function to convert doc type to full name
get_doc_type_name <- function(type_code) {
  type_code_lower <- tolower(type_code)
  if (type_code_lower == "m") return("master")
  if (type_code_lower == "s") return("share")
  return(type_code_lower)  # Return as-is if unknown
}

# Function to convert language code to ISO 639-1 standard
get_language_iso <- function(lang_code) {
  lang_code_lower <- tolower(lang_code)
  if (lang_code_lower == "e") return("EN")
  if (lang_code_lower == "f") return("FR")
  # Drop bilingual - no ISO code, treat as unknown
  return("EN")  # Default to English
}

# Function to clean tags - remove derivable tags, ensure list format
clean_tags <- function(tags, language, is_core) {
  if (is.null(tags)) return(NULL)
  
  # Ensure tags is a list/vector
  if (is.character(tags) && length(tags) == 1) {
    # Convert single tag to list
    tags <- list(tags)
  } else if (is.character(tags)) {
    # Convert character vector to list
    tags <- as.list(tags)
  }
  
  # Remove derivable tags
  tags_to_remove <- c("early_period", "bilingual", "early-period", 
                      "english", "french", "core")
  cleaned <- tags[!tags %in% tags_to_remove]
  
  if (length(cleaned) == 0) return(NULL)
  return(as.list(cleaned))  # Ensure output is a list
}

# Function to split version field
split_version <- function(version_string) {
  if (is.null(version_string) || is.na(version_string) || version_string == "") {
    return(list(sequence = 1L, version = "v1"))  # Default values
  }
  
  sequence_num <- as.integer(gsub("^0+", "", version_string))  # Remove leading zeros
  if (is.na(sequence_num) || sequence_num < 1) {
    sequence_num <- 1L  # Default to 1 if parsing fails
  }
  
  list(
    sequence = sequence_num,
    version = "v1"  # All OSF downloads are version 1 (first version)
  )
}

# Function to reorder fields with essential ID fields first
reorder_file_fields <- function(file_entry) {
  # Define field order: essential ID fields first, then other metadata
  field_order <- c(
    # Essential identifiers
    "cchs_uid", "catalog_id",
    # Core components  
    "year", "temporal_type", "doc_type", "category", "language",
    "version", "sequence",
    # File information
    "filename", "canonical_filename", "local_path", "osf_path", "file_extension",
    # Metadata
    "file_size", "checksum", "created_date", "last_modified", "tags"
  )
  
  # Reorder existing fields, add any missing fields at end
  existing_fields <- names(file_entry)
  ordered_fields <- field_order[field_order %in% existing_fields]
  remaining_fields <- existing_fields[!existing_fields %in% field_order]
  
  final_order <- c(ordered_fields, remaining_fields)
  return(file_entry[final_order])
}

clean_catalog <- function(input_file, output_file = NULL) {
  cat("Loading catalog:", input_file, "\n")
  catalog <- yaml::read_yaml(input_file)
  
  # Update catalog metadata with namespaces
  catalog$catalog_metadata$version <- "v1"
  catalog$catalog_metadata$created_date <- format(Sys.Date(), "%Y-%m-%d")
  catalog$catalog_metadata$last_updated <- format(Sys.Date(), "%Y-%m-%d")
  
  # Add namespace definitions
  catalog$catalog_metadata$namespaces <- list(
    local = "cchs-osf-docs/",
    osf = "https://osf.io/project-id/",
    github = "https://github.com/user/repo/blob/main/"
  )
  
  # Add field descriptions for documentation
  catalog$catalog_metadata$field_descriptions <- list(
    cchs_uid = "Unique identifier with temporal and document type information",
    catalog_id = "6-character alphanumeric unique identifier for referencing",
    year = "Survey year as string",
    temporal_type = "Temporal scope: single, dual, or multi-year survey",
    doc_type = "Document type: master or share file",
    category = "Full document category name",
    language = "ISO 639-1 language code: EN or FR",
    version = "Document version: v1, v2, v3, etc.",
    sequence = "Integer sequence for multiple versions",
    canonical_filename = "Standardized filename following Jenny Bryan conventions"
  )
  
  # Add generation formulas for LinkML reference
  catalog$catalog_metadata$generation_formulas <- list(
    catalog_id = "6-character random alphanumeric: sample(c(0:9, LETTERS), 6, replace=TRUE)",
    cchs_uid = "cchs-{year}{temporal_code}-{doc_type_code}-{category_code}-{lang_code}-{ext_code}-{sequence:02d}",
    canonical_filename = "cchs_{year}{temporal_abbrev}_{category}_{doc_type_abbrev}_{lang_abbrev}_{sequence}_{version}.{ext}"
  )
  
  cat("Cleaning", length(catalog$files), "file entries...\n")
  
  # Generate unique short IDs
  short_ids <- generate_short_id(length(catalog$files))
  
  # Track UID base patterns for sequence assignment
  uid_sequence_tracker <- list()
  
  # Clean each file entry
  for (i in seq_along(catalog$files)) {
    file_entry <- catalog$files[[i]]
    
    # 1. Remove redundant fields
    file_entry$nominal_year <- NULL
    file_entry$filename_consistent <- NULL
    file_entry$has_year_in_filename <- NULL
    file_entry$survey_years <- NULL
    file_entry$survey_type <- NULL
    file_entry$file_type <- NULL
    file_entry$statcan_folder <- NULL
    file_entry$statcan_section <- NULL
    
    # 2. Convert timestamps to ISO8601
    file_entry$created_date <- convert_timestamp(file_entry$created_date)
    file_entry$last_modified <- convert_timestamp(file_entry$last_modified)
    
    # 3. Fix language detection (now returns ISO codes directly)  
    detected_language <- clean_language(file_entry$filename, file_entry$language)
    
    # 4. Update document category and flatten UID components
    category_name <- map_document_category(file_entry$filename, file_entry$document_category)
    
    # Remove uid_components wrapper - flatten to clean field names
    if (!is.null(file_entry$uid_components)) {
      file_entry$year <- file_entry$uid_components$id_year
      file_entry$temporal_type <- get_temporal_type(file_entry$uid_components$id_year)
      file_entry$doc_type <- get_doc_type_name(file_entry$uid_components$id_type)
      file_entry$category <- category_name  # Full category name
      # Use filename-based detection first, fallback to UID component conversion
      filename_lang <- detected_language
      uid_lang <- get_language_iso(file_entry$uid_components$id_language)
      file_entry$language <- filename_lang  # Prioritize filename detection
      
      # Set version to v1 for all OSF downloads (first version)
      file_entry$version <- "v1"
      file_entry$sequence <- if (is.null(file_entry$uid_components$sequence)) 1L else as.integer(file_entry$uid_components$sequence)
      
      # Update cchs_uid with enhanced format including file extension
      category_code <- get_category_code(category_name)
      temporal_code <- if (file_entry$temporal_type == "dual") "d" else if (file_entry$temporal_type == "multi") "m" else "s"
      doc_type_code <- if (file_entry$doc_type == "master") "m" else "s"
      lang_code <- if (file_entry$language == "EN") "e" else if (file_entry$language == "FR") "f" else "e"
      
      # Add file extension for differentiation
      ext_code <- tolower(substr(file_entry$file_extension %||% "unk", 1, 3))
      
      year_temporal <- paste0(file_entry$year, temporal_code)
      cchs_base <- paste("cchs", year_temporal, 
                        doc_type_code, 
                        category_code,
                        lang_code,
                        ext_code,
                        sep = "-")
      
      # Smart sequence assignment - track by base pattern
      if (is.null(uid_sequence_tracker[[cchs_base]])) {
        uid_sequence_tracker[[cchs_base]] <- 1
      } else {
        uid_sequence_tracker[[cchs_base]] <- uid_sequence_tracker[[cchs_base]] + 1
      }
      
      file_entry$sequence <- as.integer(uid_sequence_tracker[[cchs_base]])
      file_entry$cchs_uid <- paste0(cchs_base, "-", sprintf("%02d", file_entry$sequence))
      
      # Remove old uid_components
      file_entry$uid_components <- NULL
    }
    
    # Remove redundant and old fields
    file_entry$document_category <- NULL
    file_entry$is_core_document <- NULL  # Remove is_core_document field
    
    # Remove any old field names that might conflict
    file_entry$id_type <- NULL  # Replace with doc_type
    
    # FORCE all files to version v1 (OSF downloads are first version)
    file_entry$version <- "v1"
    
    # Apply namespace approach - strip local namespace prefix from local_path
    if (!is.null(file_entry$local_path)) {
      local_namespace <- "cchs-osf-docs/"
      if (startsWith(file_entry$local_path, local_namespace)) {
        file_entry$local_path <- substring(file_entry$local_path, nchar(local_namespace) + 1)
      }
    }
    
    # 6. Clean tags (remove derivable ones) and ensure integer file_size
    file_entry$tags <- clean_tags(file_entry$tags, file_entry$language, NULL)
    
    # 7. Convert file_size to integer (fix float serialization)
    if (!is.null(file_entry$file_size)) {
      file_entry$file_size <- as.integer(file_entry$file_size)
    }
    
    # 8. Replace catalog_id with short UUID-style ID
    file_entry$catalog_id <- short_ids[i]
    
    # 9. Remove redundant base_id field (now redundant with cchs_uid)
    file_entry$base_id <- NULL
    
    # 10. Add lowercase Jenny Bryan style canonical_filename with 2-character codes
    if (!is.null(file_entry$cchs_uid) && !is.null(file_entry$file_extension)) {
      # cchs_{year}{temporal}_{category_code}_{doc_type}_{language_code}_{sequence}_{version}.{ext}
      temporal_abbrev <- substr(file_entry$temporal_type, 1, 1)  # s, d, m
      doc_type_abbrev <- substr(file_entry$doc_type, 1, 1)       # m, s  
      category_code <- get_category_code(category_name)          # 2-char codes: qu, ot, etc.
      lang_code <- tolower(file_entry$language)                 # en, fr
      
      year_temporal <- paste0(file_entry$year, temporal_abbrev)
      canonical_parts <- c(
        "cchs",
        year_temporal,
        category_code,
        doc_type_abbrev,
        lang_code,
        file_entry$sequence,
        file_entry$version  # Now properly v1, v2, v3
      )
      canonical_base <- paste(canonical_parts, collapse = "_")
      file_entry$canonical_filename <- paste0(canonical_base, ".", file_entry$file_extension)
    }
    
    # 11. Reorder fields for optimal structure (essential ID fields first)
    file_entry <- reorder_file_fields(file_entry)
    
    catalog$files[[i]] <- file_entry
  }
  
  # Generate output filename if not provided
  if (is.null(output_file)) {
    output_file <- "data/catalog/cchs_catalog.yaml"
  }
  
  cat("Writing cleaned catalog to:", output_file, "\n")
  yaml::write_yaml(catalog, output_file)
  
  cat("✅ Catalog cleaning complete!\n")
  cat("📊 Cleaned", length(catalog$files), "file entries\n")
  cat("📁 Output:", output_file, "\n")
  
  return(catalog)
}

# Clean the original catalog with uid_components
if (file.exists("metadata/legacy/cchs_catalog_20250928_204614.yaml")) {
  cleaned_catalog <- clean_catalog("metadata/legacy/cchs_catalog_20250928_204614.yaml")
} else {
  cat("❌ No original catalog file found\n")
}