#!/usr/bin/env Rscript
# Update extracted file metadata with proper cross-references
#
# This script updates all extracted YAML files to:
# 1. Add their own cchs_uid (with yaml extension)
# 2. Add derived_from field pointing to source PDF's UID
# 3. Rename source cchs_uid to source_cchs_uid for clarity
#
# Usage:
#   Rscript update_extracted_metadata.R [base_dir]

suppressPackageStartupMessages({
  library(yaml)
})

# Define paths
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  base_dir <- normalizePath(args[1])
} else {
  base_dir <- Sys.getenv("CCHSFLOW_DOCS", getwd())
}

extracted_dir <- file.path(base_dir, "cchs-extracted")

cat("=== Updating Extracted File Metadata ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Extracted directory:", extracted_dir, "\n\n")

# Find all YAML files (excluding summary files)
yaml_files <- list.files(
  extracted_dir,
  pattern = "\\.yaml$",
  recursive = TRUE,
  full.names = TRUE
)

# Exclude summary files
yaml_files <- yaml_files[!grepl("extraction_summary\\.yaml$", yaml_files)]

cat("Found", length(yaml_files), "extracted YAML files to update\n\n")

# Helper function to generate extracted file UID from source PDF UID
generate_extracted_uid <- function(source_uid) {
  # Source format: cchs-2015d-p-dd-en-pdf-01
  # Target format: cchs-2015d-p-dd-e-yaml-01

  # Replace language code position and extension
  # Pattern: cchs-{year}{temp}-{doc_type}-{category}-{lang}-{ext}-{seq}
  parts <- strsplit(source_uid, "-")[[1]]

  if (length(parts) < 7) {
    warning("Unexpected UID format: ", source_uid)
    return(NULL)
  }

  # Rebuild with yaml extension
  # Keep: cchs-{year}{temp}-{doc_type}-{category}
  # Change: {lang} to just 'e' (English), {ext} to 'yaml'
  new_uid <- paste(
    parts[1],  # cchs
    parts[2],  # year+temporal (e.g., 2015d)
    parts[3],  # doc_type (e.g., p for pumf)
    parts[4],  # category (e.g., dd for data-dictionary)
    "e",       # language (simplified to e)
    "yaml",    # extension
    parts[7],  # sequence
    sep = "-"
  )

  return(new_uid)
}

# Track results
updated_count <- 0
skipped_count <- 0
error_count <- 0

for (yaml_file in yaml_files) {
  rel_path <- sub(paste0(base_dir, "/"), "", yaml_file)
  cat("Processing:", rel_path, "\n")

  tryCatch({
    # Read current YAML
    data <- yaml.load_file(yaml_file)

    # Check if already updated (has derived_from field)
    if (!is.null(data$derived_from)) {
      cat("  Already updated, skipping\n")
      skipped_count <- skipped_count + 1
      next
    }

    # Get source PDF UID
    source_pdf_uid <- data$cchs_uid
    if (is.null(source_pdf_uid)) {
      cat("  No cchs_uid found, skipping\n")
      skipped_count <- skipped_count + 1
      next
    }

    # Generate extracted file's own UID
    extracted_uid <- generate_extracted_uid(source_pdf_uid)
    if (is.null(extracted_uid)) {
      cat("  Could not generate extracted UID, skipping\n")
      error_count <- error_count + 1
      next
    }

    # Update metadata structure
    # 1. Set own cchs_uid
    data$cchs_uid <- extracted_uid

    # 2. Add derived_from pointing to source PDF
    data$derived_from <- source_pdf_uid

    cat("  Own UID:", extracted_uid, "\n")
    cat("  Derived from:", source_pdf_uid, "\n")

    # Write back
    yaml_text <- as.yaml(data, indent.mapping.sequence = TRUE)
    writeLines(yaml_text, yaml_file)

    updated_count <- updated_count + 1

  }, error = function(e) {
    cat("  ERROR:", conditionMessage(e), "\n")
    error_count <<- error_count + 1
  })
}

cat("\n=== Summary ===\n")
cat("Updated:", updated_count, "\n")
cat("Skipped:", skipped_count, "\n")
cat("Errors:", error_count, "\n")
