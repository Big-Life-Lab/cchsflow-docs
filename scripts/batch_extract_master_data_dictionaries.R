#!/usr/bin/env Rscript
# Batch extract structured data from master CCHS data dictionary PDFs
#
# This script reads from the master data dictionary catalog and extracts
# English data dictionaries to YAML format.
#
# Usage:
#   Rscript batch_extract_master_data_dictionaries.R [base_dir]
#
# Output: YAML files in cchs-extracted/data-dictionary/{year}/

suppressPackageStartupMessages({
  library(yaml)
  library(digest)
})

# Define paths - accept base_dir as argument or use default
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  base_dir <- normalizePath(args[1])
} else {
  base_dir <- Sys.getenv("CCHSFLOW_DOCS", getwd())
}

extract_script <- file.path(base_dir, "scripts", "extract_data_dictionary.R")
output_base <- file.path(base_dir, "cchs-extracted", "data-dictionary")
catalog_file <- file.path(base_dir, "data", "manifests", "cchs-master-dd-list.csv")

cat("=== Batch Master Data Dictionary Extraction ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Catalog file:", catalog_file, "\n")
cat("Output base:", output_base, "\n\n")

# Check catalog exists
if (!file.exists(catalog_file)) {
  stop("Catalog file not found. Run generate_master_pdf_catalog.R first.")
}

# Read catalog
catalog <- read.csv(catalog_file, stringsAsFactors = FALSE)

cat("Total entries in catalog:", nrow(catalog), "\n")

# Filter to English, non-subsample files for initial extraction
# (The extraction script was designed for English PDFs)
dd_to_extract <- catalog[
  catalog$language == "EN" &
  catalog$is_subsample == FALSE,
]

cat("English non-subsample files:", nrow(dd_to_extract), "\n\n")

# Source the extraction script functions
source(extract_script)

# Track results
results <- data.frame(
  year = character(),
  cchs_uid = character(),
  canonical = character(),
  variables = integer(),
  checksum = character(),
  status = character(),
  stringsAsFactors = FALSE
)

# Process each data dictionary
for (i in seq_len(nrow(dd_to_extract))) {
  src <- dd_to_extract[i, ]
  pdf_path <- file.path(base_dir, src$local_path)

  # Generate canonical filename (without .pdf extension, replace with .yaml)
  canonical <- sub("_v1\\.pdf$", "", src$canonical_filename)

  cat("---\n")
  cat("Processing:", src$cchs_uid, "\n")
  cat("  Source:", src$local_path, "\n")

  # Check if PDF exists
  if (!file.exists(pdf_path)) {
    cat("  Status: SKIPPED (file not found)\n")
    results <- rbind(results, data.frame(
      year = src$year,
      cchs_uid = src$cchs_uid,
      canonical = canonical,
      variables = NA,
      checksum = NA,
      status = "not_found",
      stringsAsFactors = FALSE
    ))
    next
  }

  # Create output directory
  output_dir <- file.path(output_base, src$year)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  output_file <- file.path(output_dir, paste0(canonical, "_v1.yaml"))

  # Run extraction
  tryCatch({
    # Extract text from PDF
    text <- system2("pdftotext", c("-layout", shQuote(pdf_path), "-"), stdout = TRUE)
    text <- paste(text, collapse = "\n")
    lines <- strsplit(text, "\n")[[1]]

    # Parse variables
    variables <- parse_variables(lines)

    # Compute source PDF checksum
    pdf_checksum <- digest(file = pdf_path, algo = "sha256")
    pdf_size <- file.info(pdf_path)$size

    # Generate extracted file UID
    # Source: cchs-2015s-m-dd-en-pdf-01 -> cchs-2015s-m-dd-e-yaml-01
    uid_parts <- strsplit(src$cchs_uid, "-")[[1]]
    extracted_uid <- paste(
      uid_parts[1],  # cchs
      uid_parts[2],  # year+temporal
      uid_parts[3],  # doc_type (m for master)
      uid_parts[4],  # category (dd)
      "e",           # language simplified
      "yaml",        # extension
      uid_parts[7],  # sequence
      sep = "-"
    )

    # Build comprehensive output structure with full catalog metadata
    output <- list(
      # Document identification
      cchs_uid = extracted_uid,
      derived_from = src$cchs_uid,

      # Survey identification
      survey = "CCHS",
      year = src$year,
      temporal_type = src$temporal_type,

      # Document classification
      category = "data-dictionary",
      doc_type = "master",
      language = src$language,

      # File identification
      canonical_filename = paste0(canonical, "_v1.yaml"),

      # Source provenance
      source = list(
        filename = src$filename,
        path = src$local_path,
        checksum_sha256 = pdf_checksum,
        file_size_bytes = pdf_size
      ),

      # Extraction metadata
      extraction = list(
        date = format(Sys.Date(), "%Y-%m-%d"),
        script = "extract_data_dictionary.R",
        script_version = "1.1.0",
        output_format = "yaml",
        variables_count = length(variables)
      ),

      # Content
      variables = variables
    )

    # Write YAML
    yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
    writeLines(yaml_text, output_file)

    cat("  Output:", output_file, "\n")
    cat("  Variables:", length(variables), "\n")
    cat("  Checksum:", substr(pdf_checksum, 1, 16), "...\n")
    cat("  Status: SUCCESS\n")

    results <- rbind(results, data.frame(
      year = src$year,
      cchs_uid = src$cchs_uid,
      canonical = canonical,
      variables = length(variables),
      checksum = pdf_checksum,
      status = "success",
      stringsAsFactors = FALSE
    ))

  }, error = function(e) {
    cat("  Status: ERROR -", conditionMessage(e), "\n")
    results <<- rbind(results, data.frame(
      year = src$year,
      cchs_uid = src$cchs_uid,
      canonical = canonical,
      variables = NA,
      checksum = NA,
      status = paste("error:", conditionMessage(e)),
      stringsAsFactors = FALSE
    ))
  })
}

cat("\n=== Summary ===\n")
cat("Processed:", nrow(results), "files\n")
cat("Successful:", sum(results$status == "success"), "\n")
cat("Failed:", sum(results$status != "success"), "\n")
cat("Total variables extracted:", sum(results$variables, na.rm = TRUE), "\n")

# Write summary
summary_file <- file.path(output_base, "master_extraction_summary.yaml")
summary_output <- list(
  extraction_date = format(Sys.Date(), "%Y-%m-%d"),
  extraction_script_version = "1.1.0",
  source_type = "master",
  total_files = nrow(results),
  successful = sum(results$status == "success"),
  failed = sum(results$status != "success"),
  total_variables = sum(results$variables, na.rm = TRUE),
  files = lapply(seq_len(nrow(results)), function(i) {
    list(
      cchs_uid = results$cchs_uid[i],
      year = results$year[i],
      canonical_filename = paste0(results$canonical[i], "_v1.yaml"),
      variables_count = if (is.na(results$variables[i])) NULL else results$variables[i],
      source_checksum = if (is.na(results$checksum[i])) NULL else results$checksum[i],
      status = results$status[i]
    )
  })
)

yaml_text <- as.yaml(summary_output, indent.mapping.sequence = TRUE)
writeLines(yaml_text, summary_file)
cat("\nSummary written to:", summary_file, "\n")

# Also write a CSV manifest for easy catalog integration
manifest_file <- file.path(output_base, "master_extraction_manifest.csv")
write.csv(results, manifest_file, row.names = FALSE)
cat("Manifest written to:", manifest_file, "\n")
