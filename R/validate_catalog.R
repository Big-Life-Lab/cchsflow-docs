# CCHS Catalog Validator
# Validates catalog structure against business rules and format requirements

library(yaml)

# Validation functions
validate_cchs_uid <- function(uid, file_entry) {
  errors <- c()
  
  # Check format: cchs-{year}{temporal}-{doc_type}-{category}-{language}-{ext}-{sequence:02d}
  pattern <- "^cchs-[0-9]{4}[sdm]-[ms]-[a-z]{2}-[ef]-[a-z]{1,3}-[0-9]{2}$"
  if (!grepl(pattern, uid)) {
    errors <- c(errors, paste("Invalid UID format:", uid))
  }
  
  # Extract components and validate consistency
  if (grepl(pattern, uid)) {
    parts <- strsplit(uid, "-")[[1]]
    if (length(parts) == 7) {
      year_temporal <- parts[2]
      doc_type <- parts[3]
      category <- parts[4]
      language <- parts[5]
      ext_code <- parts[6]
      sequence <- parts[7]
      
      # Validate year matches year
      expected_year <- paste0(file_entry$year, 
                             substr(file_entry$temporal_type, 1, 1))
      if (year_temporal != expected_year) {
        errors <- c(errors, paste("Year mismatch in UID:", uid, "expected:", expected_year))
      }
      
      # Validate doc_type matches doc_type
      expected_doc_type <- substr(file_entry$doc_type, 1, 1)
      if (doc_type != expected_doc_type) {
        errors <- c(errors, paste("Doc type mismatch in UID:", uid, "expected:", expected_doc_type))
      }
      
      # Validate language matches language
      expected_lang <- tolower(substr(file_entry$language, 1, 1))
      if (language != expected_lang) {
        errors <- c(errors, paste("Language mismatch in UID:", uid, "expected:", expected_lang))
      }
      
      # Validate file extension matches
      expected_ext <- tolower(substr(file_entry$file_extension %||% "unk", 1, 3))
      if (ext_code != expected_ext) {
        errors <- c(errors, paste("Extension mismatch in UID:", uid, "expected:", expected_ext))
      }
      
      # Validate sequence format
      if (!grepl("^[0-9]{2}$", sequence)) {
        errors <- c(errors, paste("Invalid sequence format in UID:", uid))
      }
    }
  }
  
  return(errors)
}

validate_canonical_filename <- function(filename, file_entry) {
  errors <- c()
  
  # Check Jenny Bryan format: cchs_{year}{temporal}_{category}_{doc_type}_{language}_{sequence}_{version}.{ext}
  pattern <- "^cchs_[0-9]{4}[sdm]_[a-z-]+_[ms]_[a-z]{2}_[0-9]+_v[0-9]+\\.[a-z]+$"
  if (!grepl(pattern, filename)) {
    errors <- c(errors, paste("Invalid canonical filename format:", filename))
  }
  
  return(errors)
}

validate_required_fields <- function(file_entry) {
  errors <- c()
  
  required_fields <- c(
    "cchs_uid", "catalog_id", "year", "temporal_type", 
    "doc_type", "category", "language", "version", 
    "sequence", "filename", "canonical_filename"
  )
  
  for (field in required_fields) {
    if (is.null(file_entry[[field]]) || is.na(file_entry[[field]]) || file_entry[[field]] == "") {
      errors <- c(errors, paste("Missing required field:", field))
    }
  }
  
  return(errors)
}

validate_enum_values <- function(file_entry) {
  errors <- c()
  
  # Validate temporal_type
  valid_temporal <- c("single", "dual", "multi")
  if (!file_entry$temporal_type %in% valid_temporal) {
    errors <- c(errors, paste("Invalid temporal_type:", file_entry$temporal_type))
  }
  
  # Validate doc_type
  valid_doc_type <- c("master", "share")
  if (!file_entry$doc_type %in% valid_doc_type) {
    errors <- c(errors, paste("Invalid doc_type:", file_entry$doc_type))
  }
  
  # Validate language
  valid_languages <- c("EN", "FR")
  if (!file_entry$language %in% valid_languages) {
    errors <- c(errors, paste("Invalid language:", file_entry$language))
  }
  
  # Validate version format
  if (!grepl("^v[0-9]+$", file_entry$version)) {
    errors <- c(errors, paste("Invalid version format:", file_entry$version))
  }
  
  return(errors)
}

validate_catalog_id <- function(catalog_id) {
  errors <- c()
  
  # Check 6-character alphanumeric format
  if (!grepl("^[0-9A-Z]{6}$", catalog_id)) {
    errors <- c(errors, paste("Invalid catalog_id format:", catalog_id))
  }
  
  return(errors)
}

# Main validation function
validate_catalog <- function(catalog_file) {
  cat("🔍 Validating catalog:", catalog_file, "\n")
  
  # Load catalog
  tryCatch({
    catalog <- yaml::read_yaml(catalog_file)
  }, error = function(e) {
    stop("❌ Failed to load catalog file: ", e$message)
  })
  
  all_errors <- list()
  warnings <- c()
  
  # Validate catalog metadata
  if (is.null(catalog$catalog_metadata)) {
    all_errors[["metadata"]] <- "Missing catalog_metadata section"
  } else {
    # Check required metadata fields
    required_meta <- c("version", "created_date", "total_files", "years_covered")
    for (field in required_meta) {
      if (is.null(catalog$catalog_metadata[[field]])) {
        warnings <- c(warnings, paste("Missing metadata field:", field))
      }
    }
    
    # Check namespaces
    if (is.null(catalog$catalog_metadata$namespaces)) {
      warnings <- c(warnings, "Missing namespaces configuration")
    }
  }
  
  # Validate files
  if (is.null(catalog$files) || length(catalog$files) == 0) {
    all_errors[["files"]] <- "No files found in catalog"
  } else {
    cat("📊 Validating", length(catalog$files), "file entries...\n")
    
    # Track duplicates
    seen_uids <- c()
    seen_catalog_ids <- c()
    
    for (i in seq_along(catalog$files)) {
      file_entry <- catalog$files[[i]]
      file_errors <- c()
      
      # Basic required fields
      file_errors <- c(file_errors, validate_required_fields(file_entry))
      
      # Skip further validation if missing required fields
      if (length(file_errors) > 0) {
        all_errors[[paste0("file_", i)]] <- file_errors
        next
      }
      
      # UID validation
      file_errors <- c(file_errors, validate_cchs_uid(file_entry$cchs_uid, file_entry))
      
      # Catalog ID validation
      file_errors <- c(file_errors, validate_catalog_id(file_entry$catalog_id))
      
      # Canonical filename validation
      file_errors <- c(file_errors, validate_canonical_filename(file_entry$canonical_filename, file_entry))
      
      # Enum validation
      file_errors <- c(file_errors, validate_enum_values(file_entry))
      
      # Duplicate checking
      if (file_entry$cchs_uid %in% seen_uids) {
        file_errors <- c(file_errors, paste("Duplicate UID:", file_entry$cchs_uid))
      } else {
        seen_uids <- c(seen_uids, file_entry$cchs_uid)
      }
      
      if (file_entry$catalog_id %in% seen_catalog_ids) {
        file_errors <- c(file_errors, paste("Duplicate catalog_id:", file_entry$catalog_id))
      } else {
        seen_catalog_ids <- c(seen_catalog_ids, file_entry$catalog_id)
      }
      
      # Store errors if any
      if (length(file_errors) > 0) {
        all_errors[[paste0("file_", i, "_", file_entry$cchs_uid)]] <- file_errors
      }
    }
  }
  
  # Report results
  cat("\n📋 Validation Results:\n")
  
  if (length(warnings) > 0) {
    cat("⚠️  Warnings (", length(warnings), "):\n")
    for (warning in warnings) {
      cat("  ", warning, "\n")
    }
    cat("\n")
  }
  
  if (length(all_errors) == 0) {
    cat("✅ Catalog validation passed!\n")
    cat("📊 Files validated:", length(catalog$files), "\n")
    cat("🔢 Unique UIDs:", length(seen_uids), "\n")
    cat("🆔 Unique catalog IDs:", length(seen_catalog_ids), "\n")
    return(TRUE)
  } else {
    cat("❌ Validation failed with", length(all_errors), "error groups:\n\n")
    
    for (error_group in names(all_errors)) {
      cat("🔴", error_group, ":\n")
      for (error in all_errors[[error_group]]) {
        cat("  -", error, "\n")
      }
      cat("\n")
    }
    return(FALSE)
  }
}

# Example usage and validation
if (file.exists("data/catalog/cchs_catalog.yaml")) {
  validation_result <- validate_catalog("data/catalog/cchs_catalog.yaml")
  
  if (validation_result) {
    cat("🎉 Catalog is ready for production use!\n")
  } else {
    cat("🔧 Please fix validation errors before proceeding.\n")
  }
} else {
  cat("❌ Catalog file not found. Please run catalog generation first.\n")
}