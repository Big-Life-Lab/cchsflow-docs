#!/usr/bin/env Rscript
# Batch extract CCHS user guide PDFs to QMD
#
# Usage:
#   Rscript batch_extract_user_guides.R [base_dir]
#
# Output: QMD files in cchs-extracted/user-guide/{year}/

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

extract_script <- file.path(base_dir, "scripts", "extract_user_guide.R")
output_base <- file.path(base_dir, "cchs-extracted", "user-guide")

# User guide PDF sources with full catalog metadata
ug_sources <- list(
  # PUMF user guides
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_user_guide/CCHS PUMF User Guide 2015-2016.pdf",
    year = "2015-2016",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2015d-p-ug-en-pdf-01",
    canonical = "cchs_2015d_ug_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_user_guide/CCHS PUMF User Guide 2013-2014 & 2014.pdf",
    year = "2013-2014",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2013d-p-ug-en-pdf-01",
    canonical = "cchs_2013d_ug_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_user_guide/CCHS PUMF User Guide 2011-2012 & 2012.pdf",
    year = "2011-2012",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2011d-p-ug-en-pdf-01",
    canonical = "cchs_2011d_ug_p_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-PUMF/CCHS_user_guide/CCHS PUMF User Guide 2009-2010 & 2010.pdf",
    year = "2009-2010",
    temporal_type = "dual",
    doc_type = "pumf",
    language = "EN",
    cchs_uid = "cchs-2009d-p-ug-en-pdf-01",
    canonical = "cchs_2009d_ug_p_en_1_v1"
  ),
  # SHARE user guides
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_UserGuide/CCHS_2012_2011-2012_User_Guide.pdf",
    year = "2011-2012",
    temporal_type = "dual",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2011d-s-ug-en-pdf-01",
    canonical = "cchs_2011d_ug_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_UserGuide/CCHS 2010 and 2009-10 user file/CCHS_2010_2009-2010_User_Guide.pdf",
    year = "2009-2010",
    temporal_type = "dual",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2009d-s-ug-en-pdf-01",
    canonical = "cchs_2009d_ug_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_UserGuide/CCHS 2.1 User Guide.pdf",
    year = "2003",
    temporal_type = "single",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2003s-s-ug-en-pdf-01",
    canonical = "cchs_2003s_ug_s_en_1_v1"
  ),
  list(
    pdf = "cchs-pumf-docs/CCHS-share/CCHS_UserGuide/CCHS 1.1 User Guide.pdf",
    year = "2000-2001",
    temporal_type = "dual",
    doc_type = "share",
    language = "EN",
    cchs_uid = "cchs-2001d-s-ug-en-pdf-01",
    canonical = "cchs_2001d_ug_s_en_1_v1"
  )
)

cat("=== Batch User Guide Extraction ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("Output base:", output_base, "\n")
cat("Total sources:", length(ug_sources), "\n\n")

# Source the extraction script functions
source(extract_script)

# Track results
results <- data.frame(
  year = character(),
  canonical = character(),
  cchs_uid = character(),
  sections = integer(),
  checksum = character(),
  status = character(),
  stringsAsFactors = FALSE
)

# Process each user guide
for (src in ug_sources) {
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

  output_file <- file.path(output_dir, paste0(src$canonical, ".qmd"))

  # Run extraction
  tryCatch({
    # Compute source PDF checksum
    pdf_checksum <- digest(file = pdf_path, algo = "sha256")
    pdf_size <- file.info(pdf_path)$size

    # Extract text from PDF
    text <- system2("pdftotext", c("-layout", shQuote(pdf_path), "-"), stdout = TRUE)

    # Parse sections
    sections <- parse_user_guide(text)

    # Build QMD content
    body <- sections_to_qmd(sections)

    # Build YAML frontmatter with catalog metadata
    frontmatter <- list(
      title = paste("CCHS User Guide", src$year),
      cchs_uid = src$cchs_uid,
      survey = "CCHS",
      year = src$year,
      temporal_type = src$temporal_type,
      category = "user-guide",
      doc_type = src$doc_type,
      language = src$language,
      canonical_filename = paste0(src$canonical, ".qmd"),
      source = list(
        filename = basename(pdf_path),
        path = src$pdf,
        checksum_sha256 = pdf_checksum,
        file_size_bytes = pdf_size
      ),
      extraction = list(
        date = format(Sys.Date(), "%Y-%m-%d"),
        script = "extract_user_guide.R",
        script_version = "1.0.0",
        output_format = "qmd",
        sections_count = length(sections)
      )
    )

    # Write QMD file
    yaml_header <- as.yaml(frontmatter, indent.mapping.sequence = TRUE)
    qmd_content <- paste0(
      "---\n",
      yaml_header,
      "---\n\n",
      body
    )
    writeLines(qmd_content, output_file)

    cat("  Output:", output_file, "\n")
    cat("  Sections:", length(sections), "\n")
    cat("  Checksum:", substr(pdf_checksum, 1, 16), "...\n")
    cat("  Status: SUCCESS\n")

    results <- rbind(results, data.frame(
      year = src$year,
      canonical = src$canonical,
      cchs_uid = src$cchs_uid,
      sections = length(sections),
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
cat("Total sections extracted:", sum(results$sections, na.rm = TRUE), "\n")

# Write summary
summary_file <- file.path(output_base, "extraction_summary.yaml")
summary_output <- list(
  extraction_date = format(Sys.Date(), "%Y-%m-%d"),
  extraction_script_version = "1.0.0",
  total_files = nrow(results),
  successful = sum(results$status == "success"),
  failed = sum(results$status != "success"),
  total_sections = sum(results$sections, na.rm = TRUE),
  files = lapply(seq_len(nrow(results)), function(i) {
    list(
      cchs_uid = results$cchs_uid[i],
      year = results$year[i],
      canonical_filename = paste0(results$canonical[i], ".qmd"),
      sections_count = if (is.na(results$sections[i])) NULL else results$sections[i],
      source_checksum = if (is.na(results$checksum[i])) NULL else results$checksum[i],
      status = results$status[i]
    )
  })
)

yaml_text <- as.yaml(summary_output, indent.mapping.sequence = TRUE)
writeLines(yaml_text, summary_file)
cat("\nSummary written to:", summary_file, "\n")

# Write CSV manifest
manifest_file <- file.path(output_base, "extraction_manifest.csv")
write.csv(results, manifest_file, row.names = FALSE)
cat("Manifest written to:", manifest_file, "\n")
