#!/usr/bin/env Rscript
# Generate catalog entries for extracted files
#
# Creates a CSV manifest of all extracted YAML files with full metadata
# for integration into the main CCHS catalog.
#
# Usage:
#   Rscript generate_extracted_catalog.R [base_dir]

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
output_file <- file.path(base_dir, "data", "manifests", "cchs-extracted-files-manifest.csv")

cat("=== Generating Extracted Files Catalog ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Extracted directory:", extracted_dir, "\n")
cat("Output:", output_file, "\n\n")

# Find all extracted files (YAML and QMD, excluding summaries)
yaml_files <- list.files(
extracted_dir,
pattern = "\\.yaml$",
recursive = TRUE,
full.names = TRUE
)
yaml_files <- yaml_files[!grepl("extraction_summary|extraction_manifest|master_extraction", yaml_files)]

qmd_files <- list.files(
extracted_dir,
pattern = "\\.qmd$",
recursive = TRUE,
full.names = TRUE
)

all_files <- c(yaml_files, qmd_files)

cat("Found", length(yaml_files), "YAML files\n")
cat("Found", length(qmd_files), "QMD files\n")
cat("Total:", length(all_files), "extracted files\n\n")

# Helper function to extract YAML front matter from QMD files
extract_qmd_yaml <- function(filepath) {
  lines <- readLines(filepath, warn = FALSE)
  # Find YAML delimiters
  yaml_start <- which(lines == "---")[1]
  yaml_end <- which(lines == "---")[2]
  if (is.na(yaml_start) || is.na(yaml_end) || yaml_end <= yaml_start) {
    return(NULL)
  }
  yaml_text <- paste(lines[(yaml_start + 1):(yaml_end - 1)], collapse = "\n")
  yaml.load(yaml_text)
}

# Build catalog entries for all files
entries <- lapply(all_files, function(f) {
tryCatch({
  # Determine file type and load accordingly
  file_ext <- tools::file_ext(f)
  if (file_ext == "yaml") {
    data <- yaml.load_file(f)
  } else if (file_ext == "qmd") {
    data <- extract_qmd_yaml(f)
  } else {
    return(NULL)
  }

  if (is.null(data)) return(NULL)

  # Calculate relative path from repo root
  rel_path <- sub(paste0(base_dir, "/"), "", f)

  # Get file info
  finfo <- file.info(f)

  list(
    cchs_uid = data$cchs_uid,
    derived_from = data$derived_from,
    canonical_filename = if (!is.null(data$canonical_filename)) data$canonical_filename else basename(f),
    category = data$category,
    year = data$year,
    temporal_type = data$temporal_type,
    doc_type = data$doc_type,
    language = data$language,
    file_extension = file_ext,
    local_path = rel_path,
    source_pdf_path = data$source$path,
    source_pdf_checksum = data$source$checksum_sha256,
    extraction_date = data$extraction$date,
    extraction_script = data$extraction$script,
    extraction_version = data$extraction$script_version,
    variables_count = if (!is.null(data$extraction$variables_count)) data$extraction$variables_count else NA,
    modules_count = if (!is.null(data$extraction$modules_count)) data$extraction$modules_count else NA,
    questions_count = if (!is.null(data$extraction$questions_count)) data$extraction$questions_count else NA,
    sections_count = if (!is.null(data$extraction$sections_count)) data$extraction$sections_count else NA,
    tables_count = if (!is.null(data$extraction$tables_count)) data$extraction$tables_count else NA,
    file_size = finfo$size,
    status = "extracted"
  )
}, error = function(e) {
  cat("Error processing", f, ":", conditionMessage(e), "\n")
  NULL
})
})

# Remove NULLs
entries <- Filter(Negate(is.null), entries)

# Define expected columns
expected_cols <- c(
  "cchs_uid", "derived_from", "canonical_filename", "category", "year",
  "temporal_type", "doc_type", "language", "file_extension", "local_path",
  "source_pdf_path", "source_pdf_checksum", "extraction_date", "extraction_script",
  "extraction_version", "variables_count", "modules_count", "questions_count",
  "sections_count", "tables_count", "file_size", "status"
)

# Ensure all entries have all columns (fill with NA if missing)
entries <- lapply(entries, function(e) {
  for (col in expected_cols) {
    if (is.null(e[[col]])) {
      e[[col]] <- NA
    }
  }
  e[expected_cols]  # Reorder to consistent column order
})

# Convert to data frame
df <- do.call(rbind, lapply(entries, function(e) {
  as.data.frame(e, stringsAsFactors = FALSE)
}))

cat("Generated", nrow(df), "catalog entries\n\n")

# Ensure output directory exists
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# Write CSV
write.csv(df, output_file, row.names = FALSE, na = "")

cat("Catalog written to:", output_file, "\n")

# Summary by category
cat("\n=== Summary by Category ===\n")
print(table(df$category))

cat("\n=== Summary by Doc Type ===\n")
print(table(df$doc_type))

# Print first few entries
cat("\n=== Sample Entries ===\n")
print(df[1:min(3, nrow(df)), c("cchs_uid", "derived_from", "category", "year")])
