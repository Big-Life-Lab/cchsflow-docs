#!/usr/bin/env Rscript
# Batch extract structured data from master CCHS questionnaire PDFs
#
# This script reads from the master PDF catalog and extracts
# English questionnaires to YAML format.
#
# Usage:
#   Rscript batch_extract_master_questionnaires.R [base_dir]
#
# Output: YAML files in cchs-extracted/questionnaire/{year}/

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

extract_script <- file.path(base_dir, "scripts", "extract_questionnaire.R")
output_base <- file.path(base_dir, "cchs-extracted", "questionnaire")
catalog_file <- file.path(base_dir, "data", "manifests", "cchs-master-pdf-catalog.csv")

cat("=== Batch Master Questionnaire Extraction ===\n\n")
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

# Filter to English questionnaire files
quest_to_extract <- catalog[
  catalog$category == "questionnaire" &
  catalog$language == "EN",
]

cat("English questionnaire files:", nrow(quest_to_extract), "\n\n")

# Source the extraction script functions
source(extract_script)

# Track results
results <- data.frame(
  year = character(),
  cchs_uid = character(),
  canonical = character(),
  questions = integer(),
  sections = integer(),
  checksum = character(),
  status = character(),
  stringsAsFactors = FALSE
)

# Process each questionnaire
for (i in seq_len(nrow(quest_to_extract))) {
  src <- quest_to_extract[i, ]
  pdf_path <- file.path(base_dir, src$local_path)

  # Generate canonical filename (replace pdf with yaml)
  canonical <- sub("_v1\\.pdf$", "", src$canonical_filename)
  canonical <- sub("\\.pdf$", "", canonical)

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
      questions = NA,
      sections = NA,
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

    # Parse questionnaire
    result <- parse_questionnaire(lines)

    # Compute source PDF checksum
    pdf_checksum <- digest(file = pdf_path, algo = "sha256")
    pdf_size <- file.info(pdf_path)$size

    # Generate extracted file UID
    # Source: cchs-2015s-m-qu-en-pdf-01 -> cchs-2015s-m-qu-e-yaml-01
    uid_parts <- strsplit(src$cchs_uid, "-")[[1]]
    extracted_uid <- paste(
      uid_parts[1],  # cchs
      uid_parts[2],  # year+temporal
      uid_parts[3],  # doc_type (m for master)
      uid_parts[4],  # category (qu)
      "e",           # language simplified
      "yaml",        # extension
      uid_parts[7],  # sequence
      sep = "-"
    )

    # Build comprehensive output structure
    output <- list(
      # Document identification
      cchs_uid = extracted_uid,
      derived_from = src$cchs_uid,

      # Survey identification
      survey = "CCHS",
      year = src$year,
      temporal_type = src$temporal_type,

      # Document classification
      category = "questionnaire",
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
        script = "extract_questionnaire.R",
        script_version = "1.0.0",
        output_format = "yaml",
        questions_count = length(result$questions),
        sections_count = length(result$sections)
      ),

      # Content
      sections = result$sections,
      questions = result$questions
    )

    # Write YAML
    yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
    writeLines(yaml_text, output_file)

    cat("  Output:", output_file, "\n")
    cat("  Questions:", length(result$questions), "\n")
    cat("  Sections:", length(result$sections), "\n")
    cat("  Checksum:", substr(pdf_checksum, 1, 16), "...\n")
    cat("  Status: SUCCESS\n")

    results <- rbind(results, data.frame(
      year = src$year,
      cchs_uid = src$cchs_uid,
      canonical = canonical,
      questions = length(result$questions),
      sections = length(result$sections),
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
      questions = NA,
      sections = NA,
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
cat("Total questions extracted:", sum(results$questions, na.rm = TRUE), "\n")
cat("Total sections extracted:", sum(results$sections, na.rm = TRUE), "\n")

# Write summary
summary_file <- file.path(output_base, "extraction_summary.yaml")
summary_output <- list(
  extraction_date = format(Sys.Date(), "%Y-%m-%d"),
  extraction_script_version = "1.0.0",
  source_type = "master",
  category = "questionnaire",
  total_files = nrow(results),
  successful = sum(results$status == "success"),
  failed = sum(results$status != "success"),
  total_questions = sum(results$questions, na.rm = TRUE),
  total_sections = sum(results$sections, na.rm = TRUE),
  files = lapply(seq_len(nrow(results)), function(i) {
    list(
      cchs_uid = results$cchs_uid[i],
      year = results$year[i],
      canonical_filename = paste0(results$canonical[i], "_v1.yaml"),
      questions_count = if (is.na(results$questions[i])) NULL else results$questions[i],
      sections_count = if (is.na(results$sections[i])) NULL else results$sections[i],
      source_checksum = if (is.na(results$checksum[i])) NULL else results$checksum[i],
      status = results$status[i]
    )
  })
)

yaml_text <- as.yaml(summary_output, indent.mapping.sequence = TRUE)
writeLines(yaml_text, summary_file)
cat("\nSummary written to:", summary_file, "\n")

# Also write a CSV manifest
manifest_file <- file.path(output_base, "extraction_manifest.csv")
write.csv(results, manifest_file, row.names = FALSE)
cat("Manifest written to:", manifest_file, "\n")
