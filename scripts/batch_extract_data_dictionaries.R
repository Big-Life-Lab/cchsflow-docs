#!/usr/bin/env Rscript
# Batch extract structured data from all CCHS data dictionary PDFs
#
# Usage:
#   Rscript batch_extract_data_dictionaries.R [base_dir]
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
  # Try to find cchsflow-docs relative to script location
  script_dir <- getSrcDirectory(function(x) x)
  if (nchar(script_dir) > 0) {
    base_dir <- dirname(script_dir)
  } else {
    # Fallback to environment or current directory
    base_dir <- Sys.getenv("CCHSFLOW_DOCS", getwd())
  }
}

extract_script <- file.path(base_dir, "scripts", "extract_data_dictionary.R")
output_base <- file.path(base_dir, "cchs-extracted", "data-dictionary")

# Data dictionary PDF sources with full catalog metadata
# Format mirrors the catalog schema for self-documenting extracted files
dd_sources <- list(
  # PUMF data dictionaries (doc_type = "pumf" / "p")
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2015_2016PUMFDataDictionary.pdf",
    year = "2015-2016",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2015d-p-dd-en-pdf-01",
    canonical = "cchs_2015d_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2017-2018PUMFDataDictionary.pdf",
    year = "2017-2018",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2017d-p-dd-en-pdf-01",
    canonical = "cchs_2017d_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2014datadictionary.pdf",
    year = "2014",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2014s-p-dd-en-pdf-01",
    canonical = "cchs_2014s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2012datadictionary.pdf",
    year = "2012",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2012s-p-dd-en-pdf-01",
    canonical = "cchs_2012s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2010datadictionary.pdf",
    year = "2010",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2010s-p-dd-en-pdf-01",
    canonical = "cchs_2010s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2009-2010datadictionary.pdf",
    year = "2009-2010",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2009d-p-dd-en-pdf-01",
    canonical = "cchs_2009d_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2007-2008datadictionary.pdf",
    year = "2007-2008",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2007d-p-dd-en-pdf-01",
    canonical = "cchs_2007d_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2005cchsdictionary.pdf",
    year = "2005",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2005s-p-dd-en-pdf-01",
    canonical = "cchs_2005s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2003cchsdictionary.pdf",
    year = "2003",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2003s-p-dd-en-pdf-01",
    canonical = "cchs_2003s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2001cchsdictionary.pdf",
    year = "2001",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2001s-p-dd-en-pdf-01",
    canonical = "cchs_2001s_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2011-2012cchsdictionary.pdf",
    year = "2011-2012",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2011d-p-dd-en-pdf-01",
    canonical = "cchs_2011d_dd_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_data_dictionary/2013-2014dictionary.pdf",
    year = "2013-2014",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2013d-p-dd-en-pdf-01",
    canonical = "cchs_2013d_dd_p_en_1_v1"
  ),
  # SHARE data dictionaries (doc_type = "share" / "s")
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_DataDictionary/CCHS_2010_DataDictionary_Freqs.pdf",
    year = "2010",
    temporal_type = "single",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2010s-s-dd-en-pdf-01",
    canonical = "cchs_2010s_dd_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_DataDictionary/CCHS_2012_Data_Dictionary(rounded_frequencies).pdf",
    year = "2012",
    temporal_type = "single",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2012s-s-dd-en-pdf-01",
    canonical = "cchs_2012s_dd_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_DataDictionary/CCHS-share_1.1_2000_01_Data_Dictionary_Freqs.pdf",
    year = "2000-2001",
    temporal_type = "dual",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2001d-s-dd-en-pdf-01",
    canonical = "cchs_2001d_dd_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_DataDictionary/CCHS-share_2009_ DataDictionary_Freq.pdf",
    year = "2009",
    temporal_type = "single",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2009s-s-dd-en-pdf-01",
    canonical = "cchs_2009s_dd_s_en_1_v1"
  )
)

cat("=== Batch Data Dictionary Extraction ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Output base:", output_base, "\n")
cat("Total sources:", length(dd_sources), "\n\n")

# Track results
results <- data.frame(
  year = character(),
  canonical = character(),
  cchs_uid = character(),
  variables = integer(),
  checksum = character(),
  status = character(),
  stringsAsFactors = FALSE
)

# Process each data dictionary
for (src in dd_sources) {
  pdf_path <- file.path(base_dir, src$pdf)

  cat("---\n")
  cat("Processing:", src$canonical, "\n")
  cat("  Source:", src$pdf, "\n")

  # Check if PDF exists

if (!file.exists(pdf_path)) {
    cat("  Status: SKIPPED (file not found)\n")
    results <- rbind(results, data.frame(
      year = src$year,
      canonical = src$canonical,
      variables = NA,
      status = "not_found"
    ))
    next
  }

  # Create output directory
  output_dir <- file.path(output_base, src$year)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  output_file <- file.path(output_dir, paste0(src$canonical, ".yaml"))

  # Run extraction
  tryCatch({
    # Source the extraction script functions (for parse_variables, etc.)
    source(extract_script)

    # Extract text from PDF
    text <- system2("pdftotext", c("-layout", shQuote(pdf_path), "-"), stdout = TRUE)
    text <- paste(text, collapse = "\n")
    lines <- strsplit(text, "\n")[[1]]

    # Parse variables
    variables <- parse_variables(lines)

    # Compute source PDF checksum
    pdf_checksum <- digest(file = pdf_path, algo = "sha256")
    pdf_size <- file.info(pdf_path)$size

    # Build comprehensive output structure with full catalog metadata
    output <- list(
      # Document identification (mirrors catalog schema)
      cchs_uid = src$cchs_uid,

      # Survey identification
      survey = "CCHS",
      year = src$year,
      temporal_type = src$temporal_type,

      # Document classification
      category = "data-dictionary",
      doc_type = src$doc_type,
      language = src$language,

      # File identification
      canonical_filename = paste0(src$canonical, ".yaml"),

      # Source provenance
      source = list(
        filename = basename(pdf_path),
        path = src$pdf,
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
      canonical = src$canonical,
      cchs_uid = src$cchs_uid,
      variables = length(variables),
      checksum = pdf_checksum,
      status = "success",
      stringsAsFactors = FALSE
    ))

  }, error = function(e) {
    cat("  Status: ERROR -", conditionMessage(e), "\n")
    results <<- rbind(results, data.frame(
      year = src$year,
      canonical = src$canonical,
      cchs_uid = src$cchs_uid,
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
summary_file <- file.path(output_base, "extraction_summary.yaml")
summary_output <- list(
  extraction_date = format(Sys.Date(), "%Y-%m-%d"),
  extraction_script_version = "1.1.0",
  total_files = nrow(results),
  successful = sum(results$status == "success"),
  failed = sum(results$status != "success"),
  total_variables = sum(results$variables, na.rm = TRUE),
  files = lapply(seq_len(nrow(results)), function(i) {
    list(
      cchs_uid = results$cchs_uid[i],
      year = results$year[i],
      canonical_filename = paste0(results$canonical[i], ".yaml"),
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
manifest_file <- file.path(output_base, "extraction_manifest.csv")
write.csv(results, manifest_file, row.names = FALSE)
cat("Manifest written to:", manifest_file, "\n")
