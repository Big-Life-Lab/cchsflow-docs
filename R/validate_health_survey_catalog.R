# Health Survey Catalog Validator
# Validates catalog structure for both CCHS and CHMS against business rules
#
# Schema Version: 4.0.0
# Updated: 2025-10-19
# Changes: Added CHMS support, survey-specific validation

library(yaml)

# CCHS-specific validation
validate_cchs_uid <- function(uid, file_entry) {
  errors <- c()

  # CCHS UID format: cchs-{year}{temporal}-{doc_type}-{category}-[{subcategory}-]{language}-{ext}-{sequence:02d}
  pattern <- "^cchs-[0-9]{4}[sdm]-[msp]-[a-z-]+(-[a-z]{4})?-(e|f)-(pdf|doc|docx|sas|sps|do|dct|txt|csv|xlsx|mdb|log|xml|webarchive|html)-[0-9]{2}$"
  if (!grepl(pattern, uid)) {
    errors <- c(errors, paste("Invalid CCHS UID format:", uid))
  }

  # Validate CCHS-specific fields present
  if (is.null(file_entry$year)) {
    errors <- c(errors, "CCHS file missing year field")
  }
  if (is.null(file_entry$temporal_type)) {
    errors <- c(errors, "CCHS file missing temporal_type field")
  }
  if (is.null(file_entry$doc_type)) {
    errors <- c(errors, "CCHS file missing doc_type field")
  }

  return(errors)
}

# CHMS-specific validation
validate_chms_uid <- function(uid, file_entry) {
  errors <- c()

  # CHMS UID format: chms-c{cycle}-{component}-{doc_type}-{language}-{extension}-{seq:02d}
  pattern <- "^chms-c[1-6]-[a-z]{3,4}-(ug|qu|dd|dv)-(e|f)-(pdf|doc|docx)-[0-9]{2}$"
  if (!grepl(pattern, uid)) {
    errors <- c(errors, paste("Invalid CHMS UID format:", uid))
  }

  # Extract and validate components
  if (grepl(pattern, uid)) {
    parts <- strsplit(uid, "-")[[1]]
    if (length(parts) >= 7) {
      cycle <- parts[2]  # c1, c2, etc
      component <- parts[3]
      doc_type <- parts[4]
      language <- parts[5]
      extension <- parts[6]
      sequence <- parts[7]

      # Validate cycle matches (normalize comparison: c1 vs cycle1)
      expected_cycle <- file_entry$chms_cycle
      if (!is.null(expected_cycle)) {
        # Normalize both to c{N} format for comparison
        expected_cycle_normalized <- gsub("^cycle", "c", expected_cycle)
        if (cycle != expected_cycle_normalized) {
          errors <- c(errors, paste("Cycle mismatch in UID:", uid, "expected:", expected_cycle_normalized))
        }
      }

      # Validate component matches
      expected_component <- file_entry$chms_component
      if (!is.null(expected_component) && component != expected_component) {
        errors <- c(errors, paste("Component mismatch in UID:", uid, "expected:", expected_component))
      }

      # Validate language
      expected_lang <- tolower(substr(file_entry$language, 1, 1))
      if (language != expected_lang) {
        errors <- c(errors, paste("Language mismatch in UID:", uid, "expected:", expected_lang))
      }

      # Validate extension
      expected_ext <- tolower(file_entry$extension %||% "pdf")
      if (extension != expected_ext) {
        errors <- c(errors, paste("Extension mismatch in UID:", uid, "expected:", expected_ext))
      }
    }
  }

  # Validate CHMS-specific fields present
  if (is.null(file_entry$chms_cycle)) {
    errors <- c(errors, "CHMS file missing chms_cycle field")
  }
  if (is.null(file_entry$chms_component)) {
    errors <- c(errors, "CHMS file missing chms_component field")
  }

  return(errors)
}

# Survey-aware UID validation
validate_uid <- function(file_entry) {
  errors <- c()

  uid <- file_entry$uid
  survey <- file_entry$survey

  if (is.null(uid) || uid == "") {
    return(c("Missing UID"))
  }

  if (is.null(survey) || survey == "") {
    return(c("Missing survey field"))
  }

  # Route to survey-specific validation
  if (survey == "CCHS") {
    errors <- c(errors, validate_cchs_uid(uid, file_entry))
  } else if (survey == "CHMS") {
    errors <- c(errors, validate_chms_uid(uid, file_entry))
  } else {
    errors <- c(errors, paste("Unknown survey type:", survey))
  }

  return(errors)
}

# Validate required fields (survey-aware)
validate_required_fields <- function(file_entry) {
  errors <- c()

  # Common required fields
  common_fields <- c("uid", "survey", "category", "language")

  for (field in common_fields) {
    if (is.null(file_entry[[field]]) || is.na(file_entry[[field]]) || file_entry[[field]] == "") {
      errors <- c(errors, paste("Missing required field:", field))
    }
  }

  # Survey-specific required fields
  survey <- file_entry$survey

  if (!is.null(survey) && survey == "CCHS") {
    cchs_fields <- c("year", "temporal_type", "doc_type")
    for (field in cchs_fields) {
      if (is.null(file_entry[[field]]) || is.na(file_entry[[field]]) || file_entry[[field]] == "") {
        errors <- c(errors, paste("Missing CCHS required field:", field))
      }
    }
  } else if (!is.null(survey) && survey == "CHMS") {
    chms_fields <- c("chms_cycle", "chms_component")
    for (field in chms_fields) {
      if (is.null(file_entry[[field]]) || is.na(file_entry[[field]]) || file_entry[[field]] == "") {
        errors <- c(errors, paste("Missing CHMS required field:", field))
      }
    }
  }

  return(errors)
}

# Validate enum values (survey-aware)
validate_enum_values <- function(file_entry) {
  errors <- c()

  survey <- file_entry$survey

  # Validate survey
  valid_surveys <- c("CCHS", "CHMS")
  if (!is.null(survey) && !survey %in% valid_surveys) {
    errors <- c(errors, paste("Invalid survey:", survey))
  }

  # Validate language
  valid_languages <- c("e", "f", "EN", "FR")
  if (!is.null(file_entry$language) && !file_entry$language %in% valid_languages) {
    errors <- c(errors, paste("Invalid language:", file_entry$language))
  }

  # CCHS-specific enums
  if (!is.null(survey) && survey == "CCHS") {
    valid_temporal <- c("single", "dual", "multi")
    if (!is.null(file_entry$temporal_type) && !file_entry$temporal_type %in% valid_temporal) {
      errors <- c(errors, paste("Invalid temporal_type:", file_entry$temporal_type))
    }

    valid_doc_type <- c("master", "share", "pumf")
    if (!is.null(file_entry$doc_type) && !file_entry$doc_type %in% valid_doc_type) {
      errors <- c(errors, paste("Invalid doc_type:", file_entry$doc_type))
    }
  }

  # CHMS-specific enums
  if (!is.null(survey) && survey == "CHMS") {
    valid_cycles <- paste0("cycle", 1:6)
    if (!is.null(file_entry$chms_cycle) && !file_entry$chms_cycle %in% valid_cycles) {
      errors <- c(errors, paste("Invalid chms_cycle:", file_entry$chms_cycle))
    }

    valid_components <- c("gen", "hhd", "clc", "ams", "fast", "nel", "med", "inc", "hcl")
    if (!is.null(file_entry$chms_component) && !file_entry$chms_component %in% valid_components) {
      errors <- c(errors, paste("Invalid chms_component:", file_entry$chms_component))
    }
  }

  return(errors)
}

# Validate UID uniqueness
validate_uid_uniqueness <- function(files) {
  errors <- c()

  uids <- sapply(files, function(f) f$uid)
  duplicates <- uids[duplicated(uids)]

  if (length(duplicates) > 0) {
    for (dup in unique(duplicates)) {
      errors <- c(errors, paste("Duplicate UID:", dup))
    }
  }

  return(errors)
}

# Main validation function
validate_catalog <- function(catalog_file, verbose = TRUE) {
  if (verbose) cat("🔍 Validating catalog:", catalog_file, "\n")

  # Load catalog
  tryCatch({
    catalog <- yaml::read_yaml(catalog_file)
  }, error = function(e) {
    stop("❌ Failed to load catalog file: ", e$message)
  })

  all_errors <- list()
  files <- catalog$files

  if (is.null(files) || length(files) == 0) {
    stop("❌ Catalog has no files")
  }

  if (verbose) cat("📊 Validating", length(files), "files...\n\n")

  # Validate each file entry
  for (i in seq_along(files)) {
    file_entry <- files[[i]]
    file_errors <- c()

    # Run validations
    file_errors <- c(file_errors, validate_uid(file_entry))
    file_errors <- c(file_errors, validate_required_fields(file_entry))
    file_errors <- c(file_errors, validate_enum_values(file_entry))

    if (length(file_errors) > 0) {
      all_errors[[i]] <- list(
        uid = file_entry$uid %||% paste("file", i),
        errors = file_errors
      )
    }
  }

  # Check UID uniqueness
  uniqueness_errors <- validate_uid_uniqueness(files)
  if (length(uniqueness_errors) > 0) {
    all_errors[["_uniqueness"]] <- list(
      uid = "CATALOG",
      errors = uniqueness_errors
    )
  }

  # Report results
  if (length(all_errors) == 0) {
    if (verbose) {
      cat("✅ Catalog validation PASSED\n")
      cat("   Total files:", length(files), "\n")
      cat("   UID uniqueness: 100%\n")
    }
    return(invisible(TRUE))
  } else {
    if (verbose) {
      cat("❌ Catalog validation FAILED\n")
      cat("   Total files:", length(files), "\n")
      cat("   Files with errors:", length(all_errors) - ifelse("_uniqueness" %in% names(all_errors), 1, 0), "\n\n")

      for (entry in all_errors) {
        cat("File:", entry$uid, "\n")
        for (error in entry$errors) {
          cat("  -", error, "\n")
        }
        cat("\n")
      }
    }
    return(invisible(FALSE))
  }
}

# Convenience function to validate both catalogs
validate_all_catalogs <- function() {
  cat("=== VALIDATING ALL CATALOGS ===\n\n")

  results <- list()

  # CCHS catalog
  if (file.exists("data/catalog/cchs_catalog.yaml")) {
    cat("## CCHS Catalog ##\n")
    results$cchs <- validate_catalog("data/catalog/cchs_catalog.yaml")
    cat("\n")
  } else {
    cat("⚠️  CCHS catalog not found\n\n")
  }

  # CHMS catalog
  if (file.exists("data/catalog/chms_catalog.yaml")) {
    cat("## CHMS Catalog ##\n")
    results$chms <- validate_catalog("data/catalog/chms_catalog.yaml")
    cat("\n")
  } else {
    cat("⚠️  CHMS catalog not found\n\n")
  }

  # Summary
  cat("=== SUMMARY ===\n")
  all_passed <- all(unlist(results))
  if (all_passed) {
    cat("✅ All catalogs PASSED validation\n")
  } else {
    cat("❌ Some catalogs FAILED validation\n")
  }

  return(invisible(all_passed))
}

cat("Health Survey Catalog Validator loaded.\n")
cat("Available functions:\n")
cat("- validate_catalog(file): Validate a single catalog\n")
cat("- validate_all_catalogs(): Validate all catalogs (CCHS + CHMS)\n")
