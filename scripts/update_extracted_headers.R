#!/usr/bin/env Rscript
# Update extracted file headers with full catalog-aligned metadata
#
# This script updates the YAML and QMD headers in cchs-extracted/data-dictionary/
# to include all catalog metadata fields for bidirectional traceability.
#
# Usage: Rscript update_extracted_headers.R [repo_dir]

library(yaml)

# Configuration - get repo dir from args or use current working directory
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  REPO_DIR <- normalizePath(args[1])
} else {
  REPO_DIR <- getwd()
}

DD_DIR <- file.path(REPO_DIR, "cchs-extracted", "data-dictionary")
OSF_DIR <- file.path(REPO_DIR, "cchs-osf-docs")

# Source PDF catalog for looking up source metadata
PDF_CATALOG_PATH <- file.path(REPO_DIR, "data", "manifests", "cchs-master-pdf-catalog.csv")

cat("=== Update Extracted File Headers ===\n\n")
cat("Repository:", REPO_DIR, "\n")
cat("Data dictionary dir:", DD_DIR, "\n\n")

# Load PDF catalog
if (file.exists(PDF_CATALOG_PATH)) {
  pdf_catalog <- read.csv(PDF_CATALOG_PATH, stringsAsFactors = FALSE)
  cat("Loaded PDF catalog:", nrow(pdf_catalog), "entries\n\n")
} else {
  cat("WARNING: PDF catalog not found at", PDF_CATALOG_PATH, "\n")
  pdf_catalog <- NULL
}

# Function to generate cchs_uid for extracted file
generate_extracted_uid <- function(year, temporal, doc_type, category_abbrev, language, extension, sequence = 1) {
  sprintf("cchs-%s%s-%s-%s-%s-%s-%02d",
          year, temporal, doc_type, category_abbrev, tolower(language), extension, sequence)
}

# Function to generate canonical filename
generate_canonical_filename <- function(year, temporal, category_abbrev, doc_type, language, sequence, version, extension) {
  sprintf("cchs_%s%s_%s_%s_%s_%d_v%d.%s",
          year, temporal, category_abbrev, doc_type, tolower(language), sequence, version, extension)
}

# Function to get source PDF info from catalog
get_source_pdf_info <- function(year, temporal, pdf_catalog) {
  if (is.null(pdf_catalog)) return(NULL)

  # Build expected cchs_uid pattern for source PDF
  source_uid_pattern <- sprintf("cchs-%s%s-m-dd-en-pdf-01", year, temporal)

  match_idx <- which(pdf_catalog$cchs_uid == source_uid_pattern)
  if (length(match_idx) == 0) {
    # Try alternate pattern
    source_uid_pattern <- sprintf("cchs-%s%s-m-data-dictionary-en-pdf-01", year, temporal)
    match_idx <- which(pdf_catalog$cchs_uid == source_uid_pattern)
  }

  if (length(match_idx) > 0) {
    return(pdf_catalog[match_idx[1], ])
  }
  return(NULL)
}

# Function to get source PDF checksum
get_source_checksum <- function(pdf_path) {
  if (file.exists(pdf_path)) {
    return(digest::digest(file = pdf_path, algo = "sha256"))
  }
  return(NULL)
}

# Function to build enhanced metadata header
build_enhanced_header <- function(year, temporal, existing_content, pdf_info, source_pdf_path) {

  # Determine temporal type name
  temporal_name <- switch(temporal,
    "s" = "single",
    "d" = "dual",
    "m" = "multi",
    "single"
  )

  # Generate UIDs and filenames
  extracted_uid_yaml <- generate_extracted_uid(year, temporal, "m", "dd", "en", "yaml", 1)
  extracted_uid_qmd <- generate_extracted_uid(year, temporal, "m", "dd", "en", "qmd", 1)
  source_uid <- generate_extracted_uid(year, temporal, "m", "dd", "en", "pdf", 1)

  canonical_yaml <- generate_canonical_filename(year, temporal, "dd", "m", "en", 1, 1, "yaml")
  canonical_qmd <- generate_canonical_filename(year, temporal, "dd", "m", "en", 1, 1, "qmd")
  canonical_pdf <- generate_canonical_filename(year, temporal, "dd", "m", "en", 1, 1, "pdf")

  # Get source info
  source_filename <- if (!is.null(pdf_info)) pdf_info$filename else basename(source_pdf_path)
  source_filepath <- if (!is.null(pdf_info)) pdf_info$local_path else NULL
  source_checksum <- get_source_checksum(source_pdf_path)
  source_size <- if (file.exists(source_pdf_path)) file.info(source_pdf_path)$size else NULL

  # Preserve existing extraction metadata and variables
  existing_vars <- existing_content$variables
  existing_extraction <- existing_content$extraction

  # Build new header structure
  header <- list(
    # Identity
    cchs_uid = extracted_uid_yaml,
    derived_from = source_uid,

    # Classification
    survey = "CCHS",
    year = as.character(year),
    temporal_type = temporal_name,
    doc_type = "master",
    category = "data-dictionary",
    language = "EN",
    version = "v1",
    sequence = 1L,

    # File info
    canonical_filename = canonical_yaml,

    # Source provenance
    source = list(
      cchs_uid = source_uid,
      filename = source_filename,
      canonical_filename = canonical_pdf,
      source_namespace = "local_osf_mirror",
      source_filepath = source_filepath,
      checksum = source_checksum,
      file_size = source_size
    ),

    # Extraction metadata (preserve existing)
    extraction = list(
      date = if (!is.null(existing_extraction$date)) existing_extraction$date else format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_data_dictionary.R",
      script_version = if (!is.null(existing_extraction$script_version)) existing_extraction$script_version else "1.1.0",
      variables_count = length(existing_vars),
      source_checksum = source_checksum
    ),

    # Content
    variables = existing_vars
  )

  return(header)
}

# Function to build QMD YAML frontmatter
build_qmd_frontmatter <- function(year, temporal, variables_count, source_uid, source_filename) {
  temporal_name <- switch(temporal,
    "s" = "single",
    "d" = "dual",
    "m" = "multi",
    "single"
  )

  extracted_uid <- generate_extracted_uid(year, temporal, "m", "dd", "en", "qmd", 1)
  canonical_qmd <- generate_canonical_filename(year, temporal, "dd", "m", "en", 1, 1, "qmd")

  frontmatter <- list(
    title = sprintf("CCHS %s Data Dictionary - Raw Text Extract", year),
    subtitle = sprintf("Master file - %s-year survey", temporal_name),

    # Identity
    cchs_uid = extracted_uid,
    derived_from = source_uid,

    # Classification
    survey = "CCHS",
    year = as.character(year),
    temporal_type = temporal_name,
    doc_type = "master",
    category = "data-dictionary",
    language = "EN",
    version = "v1",
    sequence = 1L,

    # File info
    canonical_filename = canonical_qmd,

    # Source
    source_filename = source_filename,

    # Extraction
    extraction_date = format(Sys.Date(), "%Y-%m-%d"),
    variables_count = variables_count,

    # Quarto format
    format = "html"
  )

  return(frontmatter)
}

# Process each year
process_years <- function() {
  # Define years and their temporal types
  years_config <- list(
    list(year = 2001, temporal = "s", folder = "2001"),
    list(year = 2003, temporal = "s", folder = "2003"),
    list(year = 2005, temporal = "s", folder = "2005"),
    list(year = 2007, temporal = "d", folder = "2007"),
    list(year = 2009, temporal = "s", folder = "2009"),
    list(year = 2010, temporal = "s", folder = "2010"),
    list(year = 2011, temporal = "s", folder = "2011"),
    list(year = 2012, temporal = "s", folder = "2012"),
    list(year = 2013, temporal = "s", folder = "2013"),
    list(year = 2014, temporal = "s", folder = "2014"),
    list(year = 2015, temporal = "s", folder = "2015"),
    list(year = 2016, temporal = "s", folder = "2016"),
    list(year = 2017, temporal = "s", folder = "2017"),
    list(year = 2018, temporal = "s", folder = "2018"),
    list(year = 2019, temporal = "s", folder = "2019"),
    list(year = 2020, temporal = "s", folder = "2020"),
    list(year = 2021, temporal = "s", folder = "2021"),
    list(year = 2022, temporal = "s", folder = "2022"),
    list(year = 2023, temporal = "s", folder = "2023")
  )

  # Source PDF paths (from batch extraction script)
  pdf_paths <- list(
    "2001" = "cchs-osf-docs/2001/1.1/Master/Docs/English Data Dictionary (Freqs).pdf",
    "2003" = "cchs-osf-docs/2003/2.1/Master/Docs/June 2004/English Data Dictionary (Freqs).pdf",
    "2005" = "cchs-osf-docs/2005/3.1/Master/Docs/English Data Dictionary (Freqs).pdf",
    "2007" = "cchs-osf-docs/2007/24-Month/Master/Docs/CCHS_2007-2008_DataDictionary_Freq.pdf",
    "2009" = "cchs-osf-docs/2009/12-Month/Master/Docs/CCHS_2009_DataDictionary_Freq.pdf",
    "2010" = "cchs-osf-docs/2010/12-Month/Master/Docs/CCHS_2010_DataDictionary_Freqs.pdf",
    "2011" = "cchs-osf-docs/2011/12-Month/Master/Docs/CCHS_2011_DataDictionary_Freqs.pdf",
    "2012" = "cchs-osf-docs/2012/12-Month/Master/Docs/CCHS_2012_DataDictionary_Freqs.pdf",
    "2013" = "cchs-osf-docs/2013/12-Month/Master/Docs/CCHS_2013_DataDictionary_Freqs.pdf",
    "2014" = "cchs-osf-docs/2014/12-Month/Master/Docs/CCHS_2014_DataDictionary_Freqs.pdf",
    "2015" = "cchs-osf-docs/2015/12-Month/Master/Docs/CCHS_2015_DataDictionary_Freqs.pdf",
    "2016" = "cchs-osf-docs/2016/12-Month/Master/Docs/CCHS_2016_DataDictionary_Freqs.pdf",
    "2017" = "cchs-osf-docs/2017/12-Month/Master/Docs/CCHS_2017_DataDictionary_Freqs.pdf",
    "2018" = "cchs-osf-docs/2018/12-Month/Master/Docs/CCHS_2018_DataDictionary_Freqs.pdf",
    "2019" = "cchs-osf-docs/2019/12-Month/Master/Docs/CCHS_2019_DataDictionary_Freqs.pdf",
    "2020" = "cchs-osf-docs/2020/12-Month/Master/Docs/CCHS_2020_DataDictionary_Freqs.pdf",
    "2021" = "cchs-osf-docs/2021/12-Month/Master/Docs/CCHS_2021_DataDictionary_Freqs.pdf",
    "2022" = "cchs-osf-docs/2022/12-Month/Master/Docs/CCHS_2022_DataDictionary_Freqs.pdf",
    "2023" = "cchs-osf-docs/2023/12-Month/Master/Docs/CCHS_2023_DataDictionary_Freqs.pdf"
  )

  updated_yaml <- 0
  updated_qmd <- 0

  for (cfg in years_config) {
    year <- cfg$year
    temporal <- cfg$temporal
    folder <- cfg$folder

    # Build file paths
    canonical_base <- sprintf("cchs_%s%s_dd_m_en_1_v1", year, temporal)
    yaml_path <- file.path(DD_DIR, folder, paste0(canonical_base, ".yaml"))
    qmd_path <- file.path(DD_DIR, folder, paste0(canonical_base, ".qmd"))

    # Source PDF path
    pdf_rel_path <- pdf_paths[[as.character(year)]]
    pdf_full_path <- if (!is.null(pdf_rel_path)) file.path(REPO_DIR, pdf_rel_path) else NULL

    # Get PDF catalog info
    pdf_info <- get_source_pdf_info(year, temporal, pdf_catalog)

    cat(sprintf("[%s] Processing...\n", year))

    # Update YAML file
    if (file.exists(yaml_path)) {
      tryCatch({
        existing <- yaml::read_yaml(yaml_path)
        updated <- build_enhanced_header(year, temporal, existing, pdf_info, pdf_full_path)
        yaml::write_yaml(updated, yaml_path)
        updated_yaml <- updated_yaml + 1
        cat(sprintf("  YAML: Updated with %d variables\n", length(updated$variables)))
      }, error = function(e) {
        cat(sprintf("  YAML: ERROR - %s\n", e$message))
      })
    } else {
      cat(sprintf("  YAML: Not found at %s\n", yaml_path))
    }

    # Update QMD file
    if (file.exists(qmd_path)) {
      tryCatch({
        # Read existing QMD
        qmd_lines <- readLines(qmd_path)

        # Find YAML frontmatter boundaries
        yaml_start <- which(qmd_lines == "---")[1]
        yaml_end <- which(qmd_lines == "---")[2]

        if (!is.na(yaml_start) && !is.na(yaml_end)) {
          # Parse existing frontmatter to get variables_count if present
          existing_fm <- yaml::yaml.load(paste(qmd_lines[(yaml_start+1):(yaml_end-1)], collapse = "\n"))
          vars_count <- existing_fm$variables_count
          if (is.null(vars_count)) vars_count <- existing_fm$`Variables extracted`
          if (is.null(vars_count)) vars_count <- 0

          # Build source UID
          source_uid <- generate_extracted_uid(year, temporal, "m", "dd", "en", "pdf", 1)
          source_filename <- if (!is.null(pdf_info)) pdf_info$filename else basename(pdf_full_path)

          # Build new frontmatter
          new_fm <- build_qmd_frontmatter(year, temporal, vars_count, source_uid, source_filename)
          new_fm_yaml <- yaml::as.yaml(new_fm)

          # Reconstruct file
          new_qmd <- c(
            "---",
            strsplit(new_fm_yaml, "\n")[[1]],
            "---",
            qmd_lines[(yaml_end+1):length(qmd_lines)]
          )

          writeLines(new_qmd, qmd_path)
          updated_qmd <- updated_qmd + 1
          cat(sprintf("  QMD: Updated frontmatter\n"))
        }
      }, error = function(e) {
        cat(sprintf("  QMD: ERROR - %s\n", e$message))
      })
    } else {
      cat(sprintf("  QMD: Not found (OK for 2001-2005)\n"))
    }

    cat("\n")
  }

  cat("=== Summary ===\n")
  cat(sprintf("YAML files updated: %d\n", updated_yaml))
  cat(sprintf("QMD files updated: %d\n", updated_qmd))
}

# Run
process_years()
