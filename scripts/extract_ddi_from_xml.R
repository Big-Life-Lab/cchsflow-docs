#!/usr/bin/env Rscript
# Extract structured data from Dataverse DDI XML files
#
# Usage:
#   Rscript extract_ddi_from_xml.R <ddi_xml> [output_yaml] [--metadata key=value ...]
#
# This script parses DDI 2.x XML files from Borealis/Dataverse and converts them
# to YAML format compatible with cchsflow-docs data dictionary structure.
#
# IMPORTANT: DDI XML from Dataverse contains actual PUMF variable names, which may
# differ from PDF data dictionaries that document Master file variables.
#
# Example:
#   Rscript extract_ddi_from_xml.R \
#     ~/github/cchsflow-data/data/archive/cchs_odessi_archive/2019-2020/ddi/cchs_2019-2020_ddi.xml \
#     cchs-extracted/data-dictionary/2019-2020/cchs_2019d_dd_p_en_1_v1.yaml \
#     --metadata year=2019-2020 temporal_type=dual doc_type=pumf
#
# VERSION: 1.0.0
# ==============================================================================

suppressPackageStartupMessages({
  library(xml2)
  library(yaml)
  library(digest)
})

#==============================================================================
# XML PARSING FUNCTIONS
#==============================================================================

#' Parse DDI XML file and extract variable definitions
#'
#' @param xml_path Path to DDI XML file
#' @return List with metadata and variables
parse_ddi_xml <- function(xml_path) {
  if (!file.exists(xml_path)) {
    stop("DDI XML file not found: ", xml_path)
  }

  doc <- read_xml(xml_path)

  # DDI 2.5 uses namespace "ddi:codebook:2_5"
  # We need to register this namespace with a prefix to query it
  ns <- xml_ns(doc)

  # Check if there's a default namespace (DDI 2.5 pattern)
  default_ns <- ns[names(ns) == "d1"]
  if (length(default_ns) > 0) {
    # Register default namespace with prefix "d"
    ns <- c(d = as.character(default_ns))
    vars <- xml_find_all(doc, "//d:var", ns)
  } else {
    # Try without namespace
    vars <- xml_find_all(doc, "//var")
    if (length(vars) == 0) {
      # Try dataDscr path
      vars <- xml_find_all(doc, "//dataDscr/var")
    }
  }

  message("Found ", length(vars), " variables in DDI XML")

  variables <- list()
  for (v in vars) {
    var_info <- parse_variable_element(v, ns)
    if (!is.null(var_info)) {
      variables[[var_info$name]] <- var_info
    }
  }

  # Extract study metadata
  study_info <- extract_study_info(doc, ns)

  list(
    study_info = study_info,
    variables = variables
  )
}

#' Parse a single variable element from DDI XML
#'
#' @param var_node XML node for a variable
#' @param ns XML namespaces
#' @return List with variable information
parse_variable_element <- function(var_node, ns) {
  name <- xml_attr(var_node, "name")
  if (is.na(name) || name == "") return(NULL)

  # Determine xpath prefix based on namespace
  has_ns <- length(ns) > 0 && "d" %in% names(ns)
  prefix <- if (has_ns) "d:" else ""

  # Get label
  label_node <- xml_find_first(var_node, paste0(".//", prefix, "labl"), ns)
  label <- if (!is.na(label_node)) xml_text(label_node) else NA

  # Get variable format/type
  format_node <- xml_find_first(var_node, paste0(".//", prefix, "varFormat"), ns)
  var_type <- if (!is.na(format_node)) xml_attr(format_node, "type") else NA

  # Get categories
  cat_nodes <- xml_find_all(var_node, paste0(".//", prefix, "catgry"), ns)
  categories <- list()

  for (cat in cat_nodes) {
    cat_val_node <- xml_find_first(cat, paste0(".//", prefix, "catValu"), ns)
    cat_lab_node <- xml_find_first(cat, paste0(".//", prefix, "labl"), ns)

    if (!is.na(cat_val_node)) {
      val <- xml_text(cat_val_node)
      lab <- if (!is.na(cat_lab_node)) xml_text(cat_lab_node) else val
      categories[[val]] <- lab
    }
  }

  # Get summary statistics if available
  sum_stats <- list()
  stat_nodes <- xml_find_all(var_node, paste0(".//", prefix, "sumStat"), ns)
  for (stat in stat_nodes) {
    stat_type <- xml_attr(stat, "type")
    stat_val <- xml_text(stat)
    if (!is.na(stat_type) && !is.na(stat_val)) {
      sum_stats[[stat_type]] <- as.numeric(stat_val)
    }
  }

  # Build variable entry
  var_entry <- list(
    name = name
  )

  if (!is.na(label)) var_entry$label <- label
  if (!is.na(var_type)) var_entry$type <- var_type
  if (length(categories) > 0) var_entry$categories <- categories
  if (length(sum_stats) > 0) var_entry$summary_stats <- sum_stats

  var_entry
}

#' Extract study-level information from DDI XML
#'
#' @param doc XML document
#' @param ns XML namespaces
#' @return List with study metadata
extract_study_info <- function(doc, ns) {
  info <- list()

  # Determine xpath prefix based on namespace
  has_ns <- length(ns) > 0 && "d" %in% names(ns)
  prefix <- if (has_ns) "d:" else ""

  # Try to get title
  title_node <- xml_find_first(doc, paste0("//", prefix, "titl"), ns)
  if (!is.na(title_node)) {
    info$title <- xml_text(title_node)
  }

  # Try to get file info
  file_node <- xml_find_first(doc, paste0("//", prefix, "fileName"), ns)
  if (!is.na(file_node)) {
    info$data_file <- xml_text(file_node)
  }

  # Try to get dimensions
  case_qty <- xml_find_first(doc, paste0("//", prefix, "caseQnty"), ns)
  var_qty <- xml_find_first(doc, paste0("//", prefix, "varQnty"), ns)
  if (!is.na(case_qty)) info$n_cases <- as.numeric(xml_text(case_qty))
  if (!is.na(var_qty)) info$n_variables <- as.numeric(xml_text(var_qty))

  info
}

#==============================================================================
# YAML OUTPUT FUNCTIONS
#==============================================================================

#' Convert parsed DDI to cchsflow-docs YAML format
#'
#' @param parsed_ddi Output from parse_ddi_xml()
#' @param metadata List of metadata to include in header
#' @param xml_path Original XML file path
#' @return List ready for YAML output
format_for_yaml <- function(parsed_ddi, metadata, xml_path) {
  # Build header
  header <- list(
    cchs_uid = metadata$cchs_uid %||% generate_cchs_uid(metadata),
    survey = "CCHS",
    year = metadata$year %||% "unknown",
    temporal_type = metadata$temporal_type %||% "unknown",
    category = "data-dictionary",
    doc_type = metadata$doc_type %||% "pumf",
    language = metadata$language %||% "EN",
    source = list(
      filename = basename(xml_path),
      path = xml_path,
      checksum_sha256 = digest(file = xml_path, algo = "sha256"),
      file_size_bytes = file.info(xml_path)$size,
      extraction_method = "ddi_xml"
    ),
    extraction = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_ddi_from_xml.R",
      script_version = "1.0.0",
      output_format = "yaml",
      variables_count = length(parsed_ddi$variables)
    )
  )

  # Add study info if available
  if (length(parsed_ddi$study_info) > 0) {
    header$study_info <- parsed_ddi$study_info
  }

  # Combine header with variables
  c(header, list(variables = parsed_ddi$variables))
}

#' Generate CCHS UID from metadata
#'
#' @param metadata List with year, temporal_type, doc_type
#' @return Character string UID
generate_cchs_uid <- function(metadata) {
  year <- gsub("-", "", metadata$year %||% "0000")
  temporal <- substr(metadata$temporal_type %||% "s", 1, 1)
  doc <- substr(metadata$doc_type %||% "p", 1, 1)


  paste0("cchs-", year, temporal, "-", doc, "-dd-xml-01")
}

#' Null coalescing operator
`%||%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

#==============================================================================
# MAIN SCRIPT
#==============================================================================

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 1) {
    cat("Usage: Rscript extract_ddi_from_xml.R <ddi_xml> [output_yaml] [--metadata key=value ...]\n")
    cat("\nExtracts variable definitions from Dataverse DDI XML to YAML format.\n")
    cat("\nOptions:\n")
    cat("  --metadata key=value   Add metadata (year, temporal_type, doc_type, language)\n")
    cat("\nExample:\n")
    cat("  Rscript extract_ddi_from_xml.R input.xml output.yaml --metadata year=2019-2020\n")
    quit(status = 1)
  }

  xml_path <- args[1]

  # Determine output path
  if (length(args) >= 2 && !startsWith(args[2], "--")) {
    output_path <- args[2]
    metadata_start <- 3
  } else {
    output_path <- sub("\\.xml$", ".yaml", xml_path)
    metadata_start <- 2
  }

  # Parse metadata arguments
  metadata <- list()
  if (length(args) >= metadata_start) {
    for (i in metadata_start:length(args)) {
      arg <- args[i]
      if (arg == "--metadata" && i + 1 <= length(args)) {
        # Next arg should be key=value
        next
      } else if (grepl("=", arg)) {
        parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
        if (length(parts) == 2) {
          metadata[[parts[1]]] <- parts[2]
        }
      }
    }
  }

  # Parse DDI XML
  message("Parsing DDI XML: ", xml_path)
  parsed <- parse_ddi_xml(xml_path)

  # Format for YAML output
  yaml_data <- format_for_yaml(parsed, metadata, xml_path)

  # Create output directory if needed
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message("Created directory: ", output_dir)
  }

  # Write YAML
  message("Writing YAML: ", output_path)
  write_yaml(yaml_data, output_path)

  # Summary
  message("\nExtraction complete:")
  message("  Variables: ", length(parsed$variables))
  message("  Output: ", output_path)

  invisible(yaml_data)
}

# Run if executed as script
if (!interactive()) {
  main()
}
