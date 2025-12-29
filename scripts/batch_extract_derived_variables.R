#!/usr/bin/env Rscript
# Batch extract derived variable specifications from all CCHS PDFs
#
# Usage:
#   Rscript batch_extract_derived_variables.R [base_dir]
#
# Output: YAML files in cchs-extracted/derived-variables/{year}/

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

extract_script <- file.path(base_dir, "scripts", "extract_derived_variables.R")
output_base <- file.path(base_dir, "cchs-extracted", "derived-variables")

# Derived variables PDF sources with full catalog metadata
dv_sources <- list(
  # Dual-year PUMF
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2015_2016derivedvariables.pdf",
    year = "2015-2016",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2015d-p-dv-en-pdf-01",
    canonical = "cchs_2015d_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2017-2018derivedvariables.pdf",
    year = "2017-2018",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2017d-p-dv-en-pdf-01",
    canonical = "cchs_2017d_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2013-2014derivedvariables.pdf",
    year = "2013-2014",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2013d-p-dv-en-pdf-01",
    canonical = "cchs_2013d_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2011-2012derivedvariables.pdf",
    year = "2011-2012",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2011d-p-dv-en-pdf-01",
    canonical = "cchs_2011d_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2009-2010derivedvariables.pdf",
    year = "2009-2010",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2009d-p-dv-en-pdf-01",
    canonical = "cchs_2009d_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2007-2008derivedvariables.pdf",
    year = "2007-2008",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2007d-p-dv-en-pdf-01",
    canonical = "cchs_2007d_dv_p_en_1_v1"
  ),
  # Single-year PUMF
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2014derivedvariables.pdf",
    year = "2014",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2014s-p-dv-en-pdf-01",
    canonical = "cchs_2014s_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2012derivedvariables.pdf",
    year = "2012",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2012s-p-dv-en-pdf-01",
    canonical = "cchs_2012s_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2010derivedvariables.pdf",
    year = "2010",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2010s-p-dv-en-pdf-01",
    canonical = "cchs_2010s_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2005derivedvariables.pdf",
    year = "2005",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2005s-p-dv-en-pdf-01",
    canonical = "cchs_2005s_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2003cchsderivedvariables.pdf",
    year = "2003",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2003s-p-dv-en-pdf-01",
    canonical = "cchs_2003s_dv_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_derived_variables/2001derivedvariables.pdf",
    year = "2001",
    temporal_type = "single",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2001s-p-dv-en-pdf-01",
    canonical = "cchs_2001s_dv_p_en_1_v1"
  )
)

cat("=== Batch Derived Variables Extraction ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Output base:", output_base, "\n")
cat("Total sources:", length(dv_sources), "\n\n")

# Track results
results <- data.frame(
  year = character(),
  canonical = character(),
  cchs_uid = character(),
  modules = integer(),
  variables = integer(),
  checksum = character(),
  status = character(),
  stringsAsFactors = FALSE
)

# Process each derived variables file
for (src in dv_sources) {
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
      cchs_uid = src$cchs_uid,
      modules = NA,
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

  output_file <- file.path(output_dir, paste0(src$canonical, ".yaml"))

  # Run extraction
  tryCatch({
    # Source the extraction script functions
    source(extract_script)

    # Extract text from PDF
    text <- system2("pdftotext", c("-layout", shQuote(pdf_path), "-"), stdout = TRUE)

    # Parse derived variables
    result <- parse_derived_variables(text)

    # Compute source PDF checksum
    pdf_checksum <- digest(file = pdf_path, algo = "sha256")
    pdf_size <- file.info(pdf_path)$size

    # Build comprehensive output structure
    output <- list(
      # Document identification
      cchs_uid = src$cchs_uid,

      # Survey identification
      survey = "CCHS",
      year = src$year,
      temporal_type = src$temporal_type,

      # Document classification
      category = "derived-variables",
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
        script = "extract_derived_variables.R",
        script_version = "1.0.0",
        output_format = "yaml",
        modules_count = length(result$modules),
        variables_count = length(result$variables)
      ),

      # Content
      modules = lapply(result$modules, function(m) {
        list(code = m$code, name = m$name, dv_count = m$count)
      }),
      variables = lapply(result$variables, function(v) {
        list(
          name = v$name,
          module = v$module,
          based_on = v$based_on,
          description = v$description,
          note = if (nchar(v$note) > 0) v$note else NULL,
          specifications = v$specifications
        )
      })
    )

    # Write YAML
    yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
    writeLines(yaml_text, output_file)

    cat("  Output:", output_file, "\n")
    cat("  Modules:", length(result$modules), "\n")
    cat("  Variables:", length(result$variables), "\n")
    cat("  Checksum:", substr(pdf_checksum, 1, 16), "...\n")
    cat("  Status: SUCCESS\n")

    results <- rbind(results, data.frame(
      year = src$year,
      canonical = src$canonical,
      cchs_uid = src$cchs_uid,
      modules = length(result$modules),
      variables = length(result$variables),
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
      modules = NA,
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
cat("Total modules extracted:", sum(results$modules, na.rm = TRUE), "\n")
cat("Total variables extracted:", sum(results$variables, na.rm = TRUE), "\n")

# Write summary
summary_file <- file.path(output_base, "extraction_summary.yaml")
summary_output <- list(
  extraction_date = format(Sys.Date(), "%Y-%m-%d"),
  extraction_script_version = "1.0.0",
  total_files = nrow(results),
  successful = sum(results$status == "success"),
  failed = sum(results$status != "success"),
  total_modules = sum(results$modules, na.rm = TRUE),
  total_variables = sum(results$variables, na.rm = TRUE),
  files = lapply(seq_len(nrow(results)), function(i) {
    list(
      cchs_uid = results$cchs_uid[i],
      year = results$year[i],
      canonical_filename = paste0(results$canonical[i], ".yaml"),
      modules_count = if (is.na(results$modules[i])) NULL else results$modules[i],
      variables_count = if (is.na(results$variables[i])) NULL else results$variables[i],
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
