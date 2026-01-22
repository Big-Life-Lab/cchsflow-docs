# CCHS PUMF Catalog Schema v4.0
#
# This schema extends the existing catalog system to support:
# 1. Data files (.Rdata, .dta, .csv, .txt)
# 2. Bootstrap files
# 3. Program code files (.sas, .sps, .R)
# 4. Documentation files (existing)
#
# The schema uses the same UID system but adds new categories and file types.

library(yaml)
library(digest)
library(dplyr)
library(stringr)
library(tools)

# Schema version
CATALOG_SCHEMA_VERSION <- "4.0.0"
UID_SYSTEM_VERSION <- "4.0"

# File categories for PUMF catalog
PUMF_FILE_CATEGORIES <- list(
  # Data categories
  data = list(
    name = "data",
    description = "Main PUMF data files",
    formats = c("Rdata", "dta", "csv", "txt", "dat"),
    folder = "Data"
  ),
  bootstrap = list(
    name = "bootstrap",
    description = "Bootstrap weight files",
    formats = c("Rdata", "dta", "csv", "txt", "dat"),
    folder = "Bootstrap"
  ),
  code = list(
    name = "code",
    description = "Program code and syntax files",
    formats = c("sas", "sps", "do", "R", "r", "syntax"),
    folder = "Code"
  ),

  # Documentation categories (existing system)
  "user-guide" = list(
    name = "user-guide",
    description = "User guides and methodology documentation",
    formats = c("pdf", "doc", "docx", "html"),
    folder = "Docs"
  ),
  "data-dictionary" = list(
    name = "data-dictionary",
    description = "Data dictionaries and variable lists",
    formats = c("pdf", "doc", "docx", "html", "txt"),
    folder = "Docs"
  ),
  "record-layout" = list(
    name = "record-layout",
    description = "Record layouts and file specifications",
    formats = c("pdf", "doc", "docx", "txt"),
    folder = "Layout"
  ),
  "derived-variables" = list(
    name = "derived-variables",
    description = "Derived variable documentation",
    formats = c("pdf", "doc", "docx", "html"),
    folder = "Docs"
  ),
  "questionnaire" = list(
    name = "questionnaire",
    description = "Survey questionnaires",
    formats = c("pdf", "doc", "docx", "html"),
    folder = "Docs"
  ),
  "ddi-metadata" = list(
    name = "ddi-metadata",
    description = "DDI metadata files",
    formats = c("xml"),
    folder = "Docs"
  ),
  "cv-tables" = list(
    name = "cv-tables",
    description = "Coefficient of variation tables",
    formats = c("pdf", "xls", "xlsx", "csv"),
    folder = "Docs"
  ),
  "quality-assurance" = list(
    name = "quality-assurance",
    description = "Quality assurance documentation",
    formats = c("pdf", "doc", "docx"),
    folder = "Docs"
  ),
  "study-documentation" = list(
    name = "study-documentation",
    description = "General study documentation",
    formats = c("pdf", "doc", "docx", "html"),
    folder = "Docs"
  ),
  errata = list(
    name = "errata",
    description = "Errata and corrections",
    formats = c("pdf", "doc", "docx", "txt"),
    folder = "Docs"
  ),
  readme = list(
    name = "readme",
    description = "README files",
    formats = c("txt", "pdf", "doc", "html"),
    folder = "Docs"
  ),
  other = list(
    name = "other",
    description = "Other documentation",
    formats = c("pdf", "doc", "docx", "txt", "html", "xml"),
    folder = "Docs"
  )
)

# Document types
PUMF_DOC_TYPES <- c(
  "pumf-data",    # PUMF data files
  "pumf-doc",     # PUMF documentation
  "pumf-code"     # PUMF code files
)

#' Generate UID for PUMF file (v4.0)
#'
#' Format: cchs-<year><temporal>-<doctype>-<category>[-<subcategory>]-<lang>-<ext>-<seq>
#' Examples:
#'   - cchs-2015s-data-data-e-rdata-01
#'   - cchs-2015s-data-bootstrap-e-dta-01
#'   - cchs-2015s-code-code-na-sas-01
#'   - cchs-2015s-doc-user-guide-e-pdf-01
#'
#' @param year Year (e.g., "2015")
#' @param temporal Temporal type: "single", "dual", "multi"
#' @param doc_type Document type: "pumf-data", "pumf-doc", "pumf-code"
#' @param category Category (e.g., "data", "bootstrap", "user-guide")
#' @param language Language: "EN", "FR", "NA" (for code/data files)
#' @param extension File extension
#' @param sequence Sequence number (default: 1)
#' @param subcategory Optional subcategory
#' @return UID string
generate_pumf_uid <- function(year, temporal, doc_type, category,
                              language, extension, sequence = 1,
                              subcategory = NULL) {

  temporal_code <- substr(temporal, 1, 1)  # s, d, m

  # Doc type codes
  doc_code <- switch(doc_type,
    "pumf-data" = "data",
    "pumf-doc" = "doc",
    "pumf-code" = "code",
    doc_type  # fallback
  )

  # Language code (NA for non-linguistic files like data/code)
  lang_code <- tolower(substr(language, 1, 1))  # e, f, or n (for NA)

  # Build UID with optional subcategory
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    uid <- sprintf("cchs-%s%s-%s-%s-%s-%s-%s-%02d",
                   year, temporal_code, doc_code,
                   category, subcategory, lang_code, extension, sequence)
  } else {
    uid <- sprintf("cchs-%s%s-%s-%s-%s-%s-%02d",
                   year, temporal_code, doc_code,
                   category, lang_code, extension, sequence)
  }

  return(uid)
}

#' Generate canonical filename for PUMF file (v4.0)
#'
#' Format: cchs_<year><temporal>_<category>[_<subcategory>]_<doctype>_<lang>_<seq>_v1.<ext>
#' Examples:
#'   - cchs_2015s_data_data_na_1_v1.Rdata
#'   - cchs_2015s_bootstrap_data_na_1_v1.dta
#'   - cchs_2015s_code_code_na_1_v1.sas
#'   - cchs_2015s_user-guide_doc_en_1_v1.pdf
#'
#' @param year Year
#' @param temporal Temporal type
#' @param category Category
#' @param doc_type Document type
#' @param language Language
#' @param sequence Sequence number
#' @param extension File extension
#' @param subcategory Optional subcategory
#' @return Canonical filename
generate_pumf_canonical_filename <- function(year, temporal, category, doc_type,
                                            language, sequence, extension,
                                            subcategory = NULL) {

  temporal_code <- substr(temporal, 1, 1)

  # Doc type code
  doc_code <- switch(doc_type,
    "pumf-data" = "data",
    "pumf-doc" = "doc",
    "pumf-code" = "code",
    doc_type
  )

  # Language abbreviation
  lang_abbrev <- tolower(substr(language, 1, 2))  # en, fr, or na

  # Build filename with optional subcategory
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    canonical <- sprintf("cchs_%s%s_%s_%s_%s_%s_%d_v1.%s",
                         year, temporal_code, category, subcategory, doc_code,
                         lang_abbrev, sequence, extension)
  } else {
    canonical <- sprintf("cchs_%s%s_%s_%s_%s_%d_v1.%s",
                         year, temporal_code, category, doc_code,
                         lang_abbrev, sequence, extension)
  }

  return(canonical)
}

#' Determine document type from file
#'
#' @param filename Filename
#' @param category Category
#' @return Document type: "pumf-data", "pumf-doc", or "pumf-code"
determine_doc_type <- function(filename, category) {
  ext <- tolower(tools::file_ext(filename))

  # Check category
  if (category %in% c("data", "bootstrap")) {
    return("pumf-data")
  } else if (category == "code") {
    return("pumf-code")
  } else {
    # Everything else is documentation
    return("pumf-doc")
  }
}

#' Determine language from filename
#'
#' For data and code files, language is "NA" (not applicable)
#' For documentation, detect EN/FR
#'
#' @param filename Filename
#' @param doc_type Document type
#' @return Language: "EN", "FR", or "NA"
determine_language <- function(filename, doc_type) {
  # Data and code files are not language-specific
  if (doc_type %in% c("pumf-data", "pumf-code")) {
    return("NA")
  }

  # Documentation files - detect language
  if (grepl("_[EF]\\.", filename) || grepl("_[EF]_", filename)) {
    if (grepl("_E\\.", filename) || grepl("_E_", filename)) {
      return("EN")
    } else {
      return("FR")
    }
  }

  if (grepl("-eng|english", filename, ignore.case = TRUE)) return("EN")
  if (grepl("-fra|-fre|french|français", filename, ignore.case = TRUE)) return("FR")

  # Default to EN for docs
  return("EN")
}

#' Create catalog entry for PUMF file
#'
#' @param filepath Full path to file
#' @param year Year
#' @param category Category
#' @param sequence Sequence number
#' @param subcategory Optional subcategory
#' @param checksum File checksum
#' @param source_name Source identifier (e.g., "gdrive", "osf")
#' @return List representing catalog entry
create_pumf_catalog_entry <- function(filepath, year, category, sequence = 1,
                                      subcategory = NULL, checksum = NULL,
                                      source_name = "gdrive") {

  filename <- basename(filepath)
  extension <- tolower(tools::file_ext(filename))

  # Determine year info
  year_info <- get_year_info(year)  # From cchs_pumf_folder_structure.R
  if (is.null(year_info)) {
    stop("Invalid year: ", year)
  }

  temporal_type <- switch(year_info$temporal_code,
    "s" = "single",
    "d" = "dual",
    "m" = "multi",
    "single"
  )

  # Determine doc type and language
  doc_type <- determine_doc_type(filename, category)
  language <- determine_language(filename, doc_type)

  # Generate UID and canonical filename
  uid <- generate_pumf_uid(year, temporal_type, doc_type, category,
                          language, extension, sequence, subcategory)

  canonical_filename <- generate_pumf_canonical_filename(
    year, temporal_type, category, doc_type,
    language, sequence, extension, subcategory
  )

  # Calculate checksum if not provided
  if (is.null(checksum) && file.exists(filepath)) {
    checksum <- digest::digest(filepath, algo = "sha256", file = TRUE)
  }

  # Create entry
  entry <- list(
    cchs_uid = uid,
    year = year_info$year,
    temporal_type = temporal_type,
    doc_type = doc_type,
    category = category,
    language = language,
    version = "v1",
    sequence = as.integer(sequence),
    filename = filename,
    canonical_filename = canonical_filename,
    file_extension = extension,
    checksum = checksum,
    created_date = as.character(Sys.Date()),
    last_modified = as.character(Sys.Date())
  )

  # Add optional fields
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    entry$subcategory <- subcategory
  }

  if (!is.null(year_info$cycle)) {
    entry$cycle = year_info$cycle
  }

  # Add file size if file exists
  if (file.exists(filepath)) {
    entry$file_size <- as.integer(file.info(filepath)$size)
  }

  # Add source-specific path
  if (source_name == "gdrive") {
    entry$gdrive_path <- filepath
  } else if (source_name == "osf") {
    entry$osf_path <- filepath
  } else {
    entry$local_path <- filepath
  }

  return(entry)
}

#' Print schema information
print_catalog_schema_info <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("CCHS PUMF Catalog Schema v", CATALOG_SCHEMA_VERSION, "\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  cat("Schema version:", CATALOG_SCHEMA_VERSION, "\n")
  cat("UID system version:", UID_SYSTEM_VERSION, "\n\n")

  cat("Document types:\n")
  for (dt in PUMF_DOC_TYPES) {
    cat("  -", dt, "\n")
  }
  cat("\n")

  cat("File categories:\n")
  for (cat_name in names(PUMF_FILE_CATEGORIES)) {
    cat_info <- PUMF_FILE_CATEGORIES[[cat_name]]
    cat(sprintf("  - %-20s: %s\n", cat_name, cat_info$description))
    cat(sprintf("    Formats: %s\n", paste(cat_info$formats, collapse = ", ")))
    cat(sprintf("    Folder: %s\n", cat_info$folder))
  }

  cat("\n")
  cat("UID Format:\n")
  cat("  cchs-<year><temporal>-<doctype>-<category>[-<subcategory>]-<lang>-<ext>-<seq>\n\n")

  cat("Examples:\n")
  cat("  Data file:        cchs-2015s-data-data-na-rdata-01\n")
  cat("  Bootstrap file:   cchs-2015s-data-bootstrap-na-dta-01\n")
  cat("  Code file:        cchs-2015s-code-code-na-sas-01\n")
  cat("  Documentation:    cchs-2015s-doc-user-guide-e-pdf-01\n\n")

  cat("Canonical Filename Format:\n")
  cat("  cchs_<year><temporal>_<category>[_<subcategory>]_<doctype>_<lang>_<seq>_v1.<ext>\n\n")

  cat("Examples:\n")
  cat("  Data file:        cchs_2015s_data_data_na_1_v1.Rdata\n")
  cat("  Bootstrap file:   cchs_2015s_bootstrap_data_na_1_v1.dta\n")
  cat("  Code file:        cchs_2015s_code_code_na_1_v1.sas\n")
  cat("  Documentation:    cchs_2015s_user-guide_doc_en_1_v1.pdf\n\n")

  cat("═══════════════════════════════════════════════════════════\n\n")
}

# Export schema definition
.pumf_catalog_schema <- list(
  version = CATALOG_SCHEMA_VERSION,
  uid_version = UID_SYSTEM_VERSION,
  categories = PUMF_FILE_CATEGORIES,
  doc_types = PUMF_DOC_TYPES
)

# Print info if run interactively
if (interactive()) {
  print_catalog_schema_info()
  cat("Available functions:\n")
  cat("  generate_pumf_uid(...)                - Generate UID for file\n")
  cat("  generate_pumf_canonical_filename(...) - Generate canonical filename\n")
  cat("  determine_doc_type(file, category)    - Determine document type\n")
  cat("  determine_language(file, doctype)     - Determine language\n")
  cat("  create_pumf_catalog_entry(...)        - Create catalog entry\n")
  cat("  print_catalog_schema_info()           - Print schema information\n\n")
}
