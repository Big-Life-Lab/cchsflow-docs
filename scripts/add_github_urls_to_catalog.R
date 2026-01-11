#!/usr/bin/env Rscript
# Add GitHub raw URLs to catalog entries
#
# This script adds a `github_url` field to each file entry in the catalog,
# enabling direct links to files from any interface (README, Quarto site, etc.)
#
# Usage:
#   Rscript --vanilla scripts/add_github_urls_to_catalog.R
#
# Note: Use --vanilla to avoid renv activation issues
#
# VERSION: 1.1.0
# ==============================================================================

library(yaml)

# Configuration
GITHUB_BASE_URL <- "https://github.com/Big-Life-Lab/cchsflow-docs/raw/main"

# Mapping from source_namespace to local directory (for CCHS)
NAMESPACE_TO_DIR <- list(
  osf_cchs_docs = "cchs-osf-docs",
  local_osf_mirror = "cchs-osf-docs",
  gdrive_pumf_collection = "cchs-pumf-docs",
  local_pumf_mirror = "cchs-pumf-docs"
)

#' Generate GitHub raw URL for a CCHS file entry
#'
#' @param entry A file entry from the catalog
#' @return GitHub raw URL string
generate_github_url_cchs <- function(entry) {
  namespace <- entry$source_namespace
  filepath <- entry$source_filepath

  if (is.null(namespace) || is.null(filepath)) {
    return(NA_character_)
  }

  dir <- NAMESPACE_TO_DIR[[namespace]]
  if (is.null(dir)) {
    message("Unknown namespace: ", namespace)
    return(NA_character_)
  }

  encoded_path <- URLencode(filepath, reserved = FALSE)
  paste0(GITHUB_BASE_URL, "/", dir, "/", encoded_path)
}

#' Generate GitHub raw URL for a CHMS file entry
#'
#' @param entry A file entry from the catalog
#' @return GitHub raw URL string
generate_github_url_chms <- function(entry) {
  filepath <- entry$source_filepath

  if (is.null(filepath)) {
    return(NA_character_)
  }

  encoded_path <- URLencode(filepath, reserved = FALSE)
  paste0(GITHUB_BASE_URL, "/chms-osf-docs/", encoded_path)
}

#' Add GitHub URLs to all files in a catalog
#'
#' @param catalog_path Path to the YAML catalog file
#' @param survey "CCHS" or "CHMS"
#' @param output_path Path to write updated catalog (defaults to overwrite)
#' @return Updated catalog object
add_urls_to_catalog <- function(catalog_path, survey = "CCHS", output_path = catalog_path) {
  message("Reading catalog: ", catalog_path)
  catalog <- yaml::read_yaml(catalog_path)

  n_files <- length(catalog$files)
  message("Processing ", n_files, " files...")

  # Select URL generator based on survey

  url_generator <- if (survey == "CHMS") generate_github_url_chms else generate_github_url_cchs

  # Add github_url to each file entry
  for (i in seq_along(catalog$files)) {
    url <- url_generator(catalog$files[[i]])
    catalog$files[[i]]$github_url <- url
  }

  # Count successful URLs
  n_urls <- sum(sapply(catalog$files, function(x) !is.na(x$github_url)))
  message("Added URLs to ", n_urls, " of ", n_files, " files")

  # Update catalog metadata
  catalog$catalog_metadata$github_urls_added <- format(Sys.Date(), "%Y-%m-%d")

  # Write updated catalog
  message("Writing updated catalog: ", output_path)
  yaml::write_yaml(catalog, output_path)

  invisible(catalog)
}

# Main execution
if (!interactive()) {
  # Process CCHS catalog
  message("\n=== Processing CCHS catalog ===")
  add_urls_to_catalog("data/catalog/cchs_catalog.yaml", survey = "CCHS")

  # Process CHMS catalog if it exists
  chms_path <- "data/catalog/chms_catalog.yaml"
  if (file.exists(chms_path)) {
    message("\n=== Processing CHMS catalog ===")
    add_urls_to_catalog(chms_path, survey = "CHMS")
  }

  message("\nDone!")
}
