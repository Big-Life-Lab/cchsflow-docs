#!/usr/bin/env Rscript
# Generate catalog of master file PDFs from cchs-osf-docs
#
# This script inventories all master file documentation and creates:
# 1. A CSV manifest for catalog integration
# 2. Input data for batch extraction scripts
#
# Usage:
#   Rscript generate_master_pdf_catalog.R [base_dir]
#
# Output: data/manifests/cchs-master-pdf-catalog.csv

suppressPackageStartupMessages({
  library(digest)
})

# Define paths
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 1) {
  base_dir <- normalizePath(args[1])
} else {
  base_dir <- Sys.getenv("CCHSFLOW_DOCS", getwd())
}

osf_docs_dir <- file.path(base_dir, "cchs-osf-docs")
output_file <- file.path(base_dir, "data", "manifests", "cchs-master-pdf-catalog.csv")

cat("=== Generating Master File PDF Catalog ===\n\n")
cat("Base directory:", base_dir, "\n")
cat("OSF docs directory:", osf_docs_dir, "\n")
cat("Output:", output_file, "\n\n")

# Find all master file PDFs
pdf_files <- list.files(
  osf_docs_dir,
  pattern = "\\.pdf$",
  recursive = TRUE,
  full.names = TRUE
)

# Filter to only Master directories
pdf_files <- pdf_files[grepl("/Master/", pdf_files)]

cat("Found", length(pdf_files), "master file PDFs\n\n")

# Helper function to extract metadata from path and filename
parse_pdf_metadata <- function(pdf_path) {
  # Get relative path from osf_docs_dir
  rel_path <- sub(paste0(osf_docs_dir, "/"), "", pdf_path)

  # Parse year from path (first component)
  parts <- strsplit(rel_path, "/")[[1]]
  year <- parts[1]

  # Parse cycle type (e.g., "12-Month", "24-Month", "1.1", "2.1", "3.1")
  cycle <- parts[2]

  # Determine temporal type
  temporal_type <- if (grepl("^\\d+\\.\\d+$", cycle)) {
    "single"  # Old format like 1.1, 2.1, 3.1
  } else if (cycle == "24-Month") {
    "dual"
  } else {
    "single"
  }

  # Determine sub-sample status
  is_subsample <- grepl("Sub-sample|Sub_sample", rel_path, ignore.case = TRUE)
  subsample <- if (is_subsample) {
    # Extract sub-sample number
    ss_match <- regmatches(rel_path, regexpr("Sub-sample\\s*(\\d+|SS\\d+)", rel_path, ignore.case = TRUE))
    if (length(ss_match) > 0) ss_match else "SS"
  } else {
    NA
  }

  # Get filename
  filename <- basename(pdf_path)

  # Determine language
  # Order matters: Check for French indicators first (ESCC is French abbreviation)
  # Then check for English indicators
  # Files starting with CCHS_ (underscore) are typically bilingual English versions
  language <- if (grepl("^French|_Fr\\.|_f\\.|français|Français|^ESCC_", filename, ignore.case = TRUE)) {
    "FR"
  } else if (grepl("^English|_Eng\\.|_e\\.|^CCHS_|^CCHS ", filename, ignore.case = TRUE)) {
    "EN"
  } else if (grepl("/French |_Fr\\.", rel_path, ignore.case = TRUE)) {
    "FR"
  } else {
    "EN"  # Default to English
  }

  # Determine category - be more specific to avoid false matches
  # "DD" alone matches too broadly (Alpha Index, Topical Index also have "DD" in name)
  category <- if (grepl("DataDictionary.*Freq|Data Dictionary \\(Freq", filename, ignore.case = TRUE)) {
    "data-dictionary"
  } else if (grepl("DD Alpha Index|Table.*Alphabé|Alpha.*Index", filename, ignore.case = TRUE)) {
    "alpha-index"
  } else if (grepl("DD Topical Index|Table.*Sujet|Topic.*Index", filename, ignore.case = TRUE)) {
    "topical-index"
  } else if (grepl("Derived|DV|DVDOC", filename, ignore.case = TRUE)) {
    "derived-variables"
  } else if (grepl("User.*Guide|Guide.*[uU]tilis", filename, ignore.case = TRUE)) {
    "user-guide"
  } else if (grepl("Questionnaire", filename, ignore.case = TRUE)) {
    "questionnaire"
  } else if (grepl("Record.*Layout|Cliché|Enregistrement", filename, ignore.case = TRUE)) {
    "record-layout"
  } else if (grepl("Alpha.*Index|Table.*Alphabé", filename, ignore.case = TRUE)) {
    "alpha-index"
  } else if (grepl("Topic.*Index|Table.*Sujet", filename, ignore.case = TRUE)) {
    "topical-index"
  } else if (grepl("Content.*Overview|Aperçu.*Contenu", filename, ignore.case = TRUE)) {
    "content-overview"
  } else if (grepl("Optional.*Content|Contenu.*Option", filename, ignore.case = TRUE)) {
    "optional-content"
  } else if (grepl("Household.*Weight|Poids.*Ménages", filename, ignore.case = TRUE)) {
    "household-weights"
  } else if (grepl("Income|Revenu", filename, ignore.case = TRUE)) {
    "income-variables"
  } else if (grepl("Errata", filename, ignore.case = TRUE)) {
    "errata"
  } else if (grepl("Interpret|Estimation", filename, ignore.case = TRUE)) {
    "interpreting-estimates"
  } else if (grepl("CV.*Table|Tableaux.*CV", filename, ignore.case = TRUE)) {
    "cv-tables"
  } else {
    "other"
  }

  # Category abbreviation for UID
  cat_abbrev <- switch(category,
    "data-dictionary" = "dd",
    "derived-variables" = "dv",
    "user-guide" = "ug",
    "questionnaire" = "qu",
    "record-layout" = "rl",
    "alpha-index" = "ai",
    "topical-index" = "ti",
    "content-overview" = "co",
    "optional-content" = "oc",
    "household-weights" = "hw",
    "income-variables" = "iv",
    "errata" = "er",
    "interpreting-estimates" = "ie",
    "cv-tables" = "cv",
    "xx"  # other
  )

  # Language abbreviation
  lang_abbrev <- tolower(language)

  # Temporal abbreviation
  temp_abbrev <- switch(temporal_type,
    "single" = "s",
    "dual" = "d",
    "multi" = "m",
    "s"
  )

  # Build cchs_uid
  # Format: cchs-{year}{temporal}-{doc_type}-{category}-{language}-{extension}-{sequence}
  year_normalized <- gsub("-", "", year)  # e.g., 2015 stays 2015

  # Base UID without sequence (will add sequence later if needed)
  uid_base <- paste0("cchs-", year_normalized, temp_abbrev, "-m-", cat_abbrev, "-", lang_abbrev, "-pdf")

  # Build canonical filename base
  canonical_base <- paste0("cchs_", year_normalized, temp_abbrev, "_", cat_abbrev, "_m_", lang_abbrev, "_1")

  # Get file info
  finfo <- file.info(pdf_path)

  list(
    year = year,
    cycle = cycle,
    temporal_type = temporal_type,
    doc_type = "master",
    category = category,
    language = language,
    is_subsample = is_subsample,
    subsample = subsample,
    filename = filename,
    local_path = paste0("cchs-osf-docs/", rel_path),
    uid_base = uid_base,
    canonical_base = canonical_base,
    file_size = finfo$size,
    full_path = pdf_path
  )
}

# Parse all PDFs
cat("Parsing PDF metadata...\n")
entries <- lapply(pdf_files, function(f) {
  tryCatch(
    parse_pdf_metadata(f),
    error = function(e) {
      cat("Error parsing:", f, "-", conditionMessage(e), "\n")
      NULL
    }
  )
})

# Remove NULLs
entries <- Filter(Negate(is.null), entries)

cat("Parsed", length(entries), "entries\n\n")

# Assign sequence numbers to make UIDs unique
# Group by uid_base and assign sequence
uid_counts <- list()
for (i in seq_along(entries)) {
  base <- entries[[i]]$uid_base
  if (is.null(uid_counts[[base]])) {
    uid_counts[[base]] <- 1
  } else {
    uid_counts[[base]] <- uid_counts[[base]] + 1
  }
  entries[[i]]$sequence <- sprintf("%02d", uid_counts[[base]])
  entries[[i]]$cchs_uid <- paste0(base, "-", entries[[i]]$sequence)
  entries[[i]]$canonical_filename <- paste0(entries[[i]]$canonical_base, "_v1.pdf")
}

# Convert to data frame
df <- do.call(rbind, lapply(entries, function(e) {
  data.frame(
    cchs_uid = e$cchs_uid,
    year = e$year,
    cycle = e$cycle,
    temporal_type = e$temporal_type,
    doc_type = e$doc_type,
    category = e$category,
    language = e$language,
    is_subsample = e$is_subsample,
    subsample = if (is.na(e$subsample)) "" else e$subsample,
    filename = e$filename,
    canonical_filename = e$canonical_filename,
    local_path = e$local_path,
    file_size = e$file_size,
    stringsAsFactors = FALSE
  )
}))

# Ensure output directory exists
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# Write catalog
write.csv(df, output_file, row.names = FALSE, na = "")

cat("=== Summary ===\n")
cat("Total PDFs cataloged:", nrow(df), "\n\n")

cat("By category:\n")
print(table(df$category))

cat("\nBy language:\n")
print(table(df$language))

cat("\nBy year:\n")
print(table(df$year))

cat("\n\nCatalog written to:", output_file, "\n")

# Also generate a focused list of data dictionaries for extraction
dd_df <- df[df$category == "data-dictionary", ]
cat("\n=== Data Dictionaries for Extraction ===\n")
cat("Total:", nrow(dd_df), "\n")
cat("English:", sum(dd_df$language == "EN"), "\n")
cat("French:", sum(dd_df$language == "FR"), "\n")

# Write data dictionary list
dd_file <- file.path(base_dir, "data", "manifests", "cchs-master-dd-list.csv")
write.csv(dd_df, dd_file, row.names = FALSE, na = "")
cat("\nData dictionary list written to:", dd_file, "\n")
