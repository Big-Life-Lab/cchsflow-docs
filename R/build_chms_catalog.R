# Build CHMS Catalog
# Creates YAML catalog for all CHMS documentation files
# Uses CHMS UID system defined in metadata/chms_uid_design.md

library(yaml)
library(dplyr)

source("R/osf_api_client.R")

#' Detect CHMS component from filename
#' @param filename File name
#' @return Component code
detect_chms_component <- function(filename) {
  filename_lower <- tolower(filename)

  # User guides
  if (grepl("user_guide|^ug_", filename_lower)) return("gen")

  # Household
  if (grepl("hhld|hhd|household", filename_lower)) return("hhd")

  # Clinic
  if (grepl("clinic|clc", filename_lower)) return("clc")

  # Activity Monitor
  if (grepl("^am_|_am_|ams|activity", filename_lower)) return("ams")

  # Fasting
  if (grepl("fast", filename_lower)) return("fast")

  # Medication
  if (grepl("med", filename_lower)) return("med")

  # Nutrition/Environmental
  if (grepl("nel|nutrition|environmental", filename_lower)) return("nel")

  # Income
  if (grepl("inc|income", filename_lower)) return("inc")

  # Health Claims
  if (grepl("hcl", filename_lower)) return("hcl")

  return("unknown")
}

#' Detect CHMS document type from filename
#' @param filename File name
#' @return Document type code
detect_chms_doc_type <- function(filename) {
  filename_lower <- tolower(filename)

  # User guide
  if (grepl("user_guide|^ug_", filename_lower)) return("ug")

  # Questionnaire
  if (grepl("quest|questionnaire", filename_lower)) return("qu")

  # Derived variables
  if (grepl("^dv_|derived", filename_lower)) return("dv")

  # Data dictionary (default for dd_, rounded_dd_, etc.)
  if (grepl("_dd_|data.*dict", filename_lower)) return("dd")

  # Fallback based on component detection
  component <- detect_chms_component(filename)
  if (component == "gen") return("ug")
  if (grepl("cycle.*_e\\.pdf|cycle.*_f\\.pdf", filename_lower)) return("qu")

  return("dd")  # Default to data dictionary
}

#' Detect language from filename
#' @param filename File name
#' @return Language code (e or f)
detect_language <- function(filename) {
  filename_lower <- tolower(filename)

  # Explicit markers
  if (grepl("_e\\.", filename_lower)) return("e")
  if (grepl("_f\\.", filename_lower)) return("f")

  # Default to English (CHMS appears to be English-only)
  return("e")
}

#' Extract file extension without dot
#' @param filename File name
#' @return Extension
get_extension <- function(filename) {
  tolower(tools::file_ext(filename))
}

#' Generate CHMS UID
#' @param cycle_num Cycle number (1-6)
#' @param component Component code
#' @param doc_type Document type code
#' @param language Language code
#' @param extension File extension
#' @param sequence Sequence number
#' @return UID string
generate_chms_uid <- function(cycle_num, component, doc_type, language, extension, sequence = 1) {
  sprintf("chms-c%s-%s-%s-%s-%s-%02d",
          cycle_num, component, doc_type, language, extension, sequence)
}

#' Build catalog entry for a CHMS file
#' @param file_info Row from file listing
#' @param cycle_num Cycle number
#' @param local_path Local file path
#' @return List with catalog entry
build_chms_catalog_entry <- function(file_info, cycle_num, local_path) {

  filename <- file_info$name
  component <- detect_chms_component(filename)
  doc_type <- detect_chms_doc_type(filename)
  language <- detect_language(filename)
  extension <- get_extension(filename)

  # Determine category based on doc_type
  category <- switch(doc_type,
    "ug" = "user-guide",
    "qu" = "questionnaire",
    "dd" = "data-dictionary",
    "dv" = "derived-variables",
    "unknown"
  )

  # Detect if unrounded/rounded
  is_rounded <- grepl("rounded", tolower(filename))
  is_unrounded <- grepl("unrounded", tolower(filename))

  secondary_category <- if (is_unrounded) {
    "unrounded"
  } else if (is_rounded) {
    "rounded"
  } else {
    NA
  }

  # Generate UID (sequence handling comes later for duplicates)
  uid <- generate_chms_uid(cycle_num, component, doc_type, language, extension, 1)

  list(
    uid = uid,
    survey = "CHMS",
    chms_cycle = paste0("cycle", cycle_num),
    chms_component = component,
    category = category,
    secondary_category = secondary_category,
    language = language,
    filename_original = filename,
    filename_canonical = paste0(uid, ".", extension),
    extension = extension,
    osf_file_id = file_info$id,
    osf_component_id = file_info$component_id,
    file_size = file_info$size,
    date_modified = file_info$modified,
    local_path = local_path
  )
}

#' Build complete CHMS catalog
#' @param mirror_dir CHMS mirror directory
#' @return List of catalog entries
build_chms_catalog <- function(mirror_dir = "chms-osf-docs") {

  cat("=== BUILDING CHMS CATALOG ===\n\n")

  # Get all CHMS files from OSF
  cycles <- get_chms_cycles()
  all_entries <- list()
  entry_count <- 0

  for (i in 1:nrow(cycles)) {
    cycle_num <- cycles$cycle_num[i]
    cycle_name <- paste0("Cycle", cycle_num)
    component_id <- cycles$component_id[i]

    cat("Processing", cycle_name, "...\n")

    # Get files from OSF
    cycle_files <- get_chms_cycle_files(cycle_num)
    files <- cycle_files[cycle_files$kind == "file", ]

    # Add component_id for catalog
    files$component_id <- component_id

    if (nrow(files) == 0) next

    # Build catalog entries
    for (j in 1:nrow(files)) {
      local_path <- file.path(mirror_dir, cycle_name, files$name[j])

      entry <- build_chms_catalog_entry(files[j, ], cycle_num, local_path)

      entry_count <- entry_count + 1
      all_entries[[entry_count]] <- entry
    }

    cat("  Added", nrow(files), "files\n")
  }

  cat("\nTotal entries:", length(all_entries), "\n")

  # Handle UID duplicates by incrementing sequence numbers
  cat("Checking for duplicate UIDs...\n")
  all_entries <- assign_unique_uids(all_entries)

  # Verify uniqueness
  uids <- sapply(all_entries, function(x) x$uid)
  n_unique <- length(unique(uids))
  n_total <- length(uids)

  cat("UID uniqueness: ", n_unique, "/", n_total,
      " (", round(100 * n_unique / n_total, 1), "%)\n", sep = "")

  if (n_unique < n_total) {
    warning("Duplicate UIDs detected!")
    dups <- uids[duplicated(uids)]
    cat("Duplicates:", paste(unique(dups), collapse = ", "), "\n")
  }

  return(all_entries)
}

#' Assign unique UIDs by incrementing sequence for duplicates
#' @param entries List of catalog entries
#' @return Updated entries with unique UIDs
assign_unique_uids <- function(entries) {

  # Extract base UIDs (without sequence number)
  extract_base <- function(entry) {
    parts <- strsplit(entry$uid, "-")[[1]]
    paste(parts[1:6], collapse = "-")  # chms-c{N}-{comp}-{type}-{lang}-{ext}
  }

  # Group by base UID
  base_uids <- sapply(entries, extract_base)
  dup_bases <- base_uids[duplicated(base_uids) | duplicated(base_uids, fromLast = TRUE)]

  # Assign sequence numbers for duplicates
  for (base in unique(dup_bases)) {
    indices <- which(base_uids == base)

    for (seq_num in seq_along(indices)) {
      idx <- indices[seq_num]
      entry <- entries[[idx]]

      # Rebuild UID with correct sequence
      new_uid <- gsub("-\\d{2}$", sprintf("-%02d", seq_num), entry$uid)
      entries[[idx]]$uid <- new_uid
      entries[[idx]]$filename_canonical <- paste0(new_uid, ".", entry$extension)
    }
  }

  return(entries)
}

#' Write CHMS catalog to YAML file
#' @param catalog List of catalog entries
#' @param output_path Output file path
write_chms_catalog <- function(catalog, output_path = "data/catalog/chms_catalog.yaml") {

  cat("\nWriting catalog to:", output_path, "\n")

  # Create directory if needed
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

  # Prepare catalog structure
  catalog_data <- list(
    metadata = list(
      survey = "CHMS",
      title = "Canadian Health Measures Survey Documentation Catalog",
      version = "1.0.0",
      generated = Sys.time(),
      total_files = length(catalog),
      cycles = 6,
      date_range = "Cycle 1 - Cycle 6"
    ),
    files = catalog
  )

  # Write YAML
  write_yaml(catalog_data, output_path)

  cat("✓ Catalog written:", length(catalog), "files\n")
  cat("✓ File size:", round(file.info(output_path)$size / 1024, 1), "KB\n")
}

# Main execution
if (!interactive()) {
  catalog <- build_chms_catalog()
  write_chms_catalog(catalog)

  cat("\n=== CHMS CATALOG BUILD COMPLETE ===\n")
}
