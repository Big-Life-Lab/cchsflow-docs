# scrape_ices_variables.R
# Scrape variable details from ICES Data Dictionary Variables.aspx endpoint
#
# Prerequisites:
#   - Variable names list from parse_ices_variable_list.R
#   - OR provide variable names directly
#
# Output:
#   - data/catalog/ices_cchs_variables.yaml
#   - data/catalog/ices_cchs_availability_matrix.csv

library(httr)
library(rvest)
library(dplyr)
library(stringr)
library(yaml)
library(purrr)
library(tidyr)
library(readr)

# Configuration
BASE_URL <- "https://datadictionary.ices.on.ca/Applications/DataDictionary/"
DELAY_SECONDS <- 1.5  # Respectful rate limiting
OUTPUT_YAML <- "data/catalog/ices_cchs_variables.yaml"
OUTPUT_CSV <- "data/catalog/ices_cchs_availability_matrix.csv"

#' Scrape a single variable from Variables.aspx
#' @param variable_name ICES variable name (e.g., "ADMA_IMP")
#' @return List with variable metadata, or NULL if not found
scrape_ices_variable <- function(variable_name) {

  url <- paste0(BASE_URL, "Variables.aspx?LibName=CCHS&MemName=&Variable=",
                URLencode(variable_name, reserved = TRUE))

  resp <- tryCatch(
    GET(url, config(ssl_verifypeer = FALSE)),
    error = function(e) NULL
  )

  if (is.null(resp) || status_code(resp) != 200) {
    return(NULL)
  }

  html <- read_html(content(resp, as = "text", encoding = "UTF-8"))

  # Extract fields using CSS selectors
  label <- html %>%
    html_element("#MainContent_lbLabel") %>%
    html_text(trim = TRUE)

  type <- html %>%
    html_element("#MainContent_lbTypeLength") %>%
    html_text(trim = TRUE)

  available_in_raw <- html %>%
    html_element("#MainContent_lbAvailableIn") %>%
    html_text(trim = TRUE)

  format_code <- html %>%
    html_element("#MainContent_lbFormat") %>%
    html_text(trim = TRUE)

  # Get values as inner HTML (preserves <br/> tags for splitting)
  values_element <- html %>% html_element("#MainContent_lbvalue")
  values_html <- if (!is.na(values_element)) {
    as.character(values_element) %>%
      str_extract("(?<=>).*(?=</span>)")
  } else {
    NA
  }

  # Check if variable was found
  if (is.na(label) || label == "" || is.na(available_in_raw)) {
    return(NULL)
  }

  # Parse available_in (comma-separated, may have newlines)
  available_in <- available_in_raw %>%
    str_split(",\\s*|\n") %>%
    .[[1]] %>%
    str_trim() %>%
    .[nchar(.) > 0]

  # Parse values (format: "1 = YES<br/>2 = NO<br/>...")
  values <- NULL
  if (!is.na(values_html) && values_html != "") {
    value_lines <- str_split(values_html, "<br/>|<br>")[[1]]
    values <- map(value_lines, function(line) {
      line <- str_trim(line)
      match <- str_match(line, "^\\s*(\\S+)\\s*=\\s*(.+)$")
      if (!is.na(match[1, 1])) {
        list(code = match[1, 2], label = str_trim(match[1, 3]))
      }
    }) %>%
      compact()
  }

  list(
    variable_name = variable_name,
    label = label,
    type = type,
    format = format_code,
    values_raw = if (!is.na(values_html) && values_html != "") values_html else NA_character_,
    available_in_raw = available_in_raw,
    available_in = available_in,
    available_in_count = length(available_in),
    values = values
  )
}

#' Batch scrape variables with progress reporting
#' @param variable_names Character vector of variable names
#' @param delay Seconds between requests (default 1.5)
#' @return List of variable metadata
scrape_ices_variables_batch <- function(variable_names, delay = DELAY_SECONDS) {

  total <- length(variable_names)
  message("Scraping ", total, " variables from ICES...")
  message("Estimated time: ", round(total * delay / 60, 1), " minutes")

  results <- list()
  not_found <- character(0)

  for (i in seq_along(variable_names)) {
    var_name <- variable_names[i]

    if (i %% 50 == 0 || i == 1) {
      message(sprintf("[%d/%d] Scraping %s...", i, total, var_name))
    }

    result <- scrape_ices_variable(var_name)

    if (!is.null(result)) {
      results[[var_name]] <- result
    } else {
      not_found <- c(not_found, var_name)
    }

    if (i < total) {
      Sys.sleep(delay)
    }
  }

  message("\nComplete!")
  message("Found: ", length(results), " variables")
  message("Not found: ", length(not_found), " variables")

  if (length(not_found) > 0 && length(not_found) <= 20) {
    message("Not found: ", paste(not_found, collapse = ", "))
  }

  list(
    variables = results,
    not_found = not_found
  )
}

#' Build availability matrix (variable × dataset)
#' @param results Result from scrape_ices_variables_batch()
#' @return Data frame with variable names as rows, datasets as columns
build_availability_matrix <- function(results) {

  # Get all unique datasets
  all_datasets <- results$variables %>%
    map("available_in") %>%
    unlist() %>%
    unique() %>%
    sort()

  # Build matrix
  matrix_df <- map_dfr(results$variables, function(v) {
    row <- tibble(variable = v$variable_name)
    for (ds in all_datasets) {
      row[[ds]] <- ds %in% v$available_in
    }
    row
  })

  matrix_df
}

#' Save results to YAML and CSV
#' @param results Result from scrape_ices_variables_batch()
#' @param yaml_file Output YAML path
#' @param csv_file Output CSV path
save_ices_results <- function(results,
                               yaml_file = OUTPUT_YAML,
                               csv_file = OUTPUT_CSV) {

  # Build catalog structure
  catalog <- list(
    catalog_metadata = list(
      version = "v1.0.0",
      created_date = format(Sys.Date(), "%Y-%m-%d"),
      last_updated = format(Sys.Date(), "%Y-%m-%d"),
      source = "ICES Data Dictionary",
      source_url = paste0(BASE_URL, "Library.aspx?Library=CCHS"),
      total_variables = length(results$variables),
      variables_not_found = length(results$not_found),
      ices_library = "CCHS"
    ),
    variables = results$variables
  )

  # Save YAML
  dir.create(dirname(yaml_file), showWarnings = FALSE, recursive = TRUE)
  write_yaml(catalog, yaml_file)
  message("Saved YAML to: ", yaml_file)

  # Build and save availability matrix
  matrix_df <- build_availability_matrix(results)
  write_csv(matrix_df, csv_file)
  message("Saved availability matrix to: ", csv_file)

  invisible(list(yaml = yaml_file, csv = csv_file))
}

#' Quick test with a few known variables
#' @return List of test results
test_ices_scraper <- function() {
  test_vars <- c("ADMA_IMP", "ALCA_1", "GEOAGPRV", "SMKA_202", "WTSAM")
  message("Testing with ", length(test_vars), " variables...")

  results <- scrape_ices_variables_batch(test_vars, delay = 0.5)

  message("\nTest results:")
  for (v in results$variables) {
    message(sprintf("  %s: %d datasets", v$variable_name, v$available_in_count))
  }

  results
}

# ============================================================================
# Main entry point
# ============================================================================

#' Run full ICES variable scraping pipeline
#' @param variable_names_file File with variable names (one per line)
#' @export
scrape_ices_cchs_variables <- function(variable_names_file = "development/ices-dictionary/ices_variable_names.txt") {

  if (!file.exists(variable_names_file)) {
    stop("Variable names file not found: ", variable_names_file,
         "\nRun parse_ices_variable_list.R first to create it.")
  }

  variable_names <- read_lines(variable_names_file)
  variable_names <- variable_names[nchar(str_trim(variable_names)) > 0]

  message("Loaded ", length(variable_names), " variable names")

  results <- scrape_ices_variables_batch(variable_names)
  save_ices_results(results)

  invisible(results)
}

# Usage when sourced interactively
if (interactive()) {
  message("ICES Variable Scraper")
  message("=====================")
  message("")
  message("Functions:")
  message("  test_ices_scraper()            - Test with 5 known variables")
  message("  scrape_ices_variable('ALCA_1') - Scrape single variable")
  message("  scrape_ices_cchs_variables()   - Full pipeline (needs variable list)")
  message("")
  message("Output files:")
  message("  ", OUTPUT_YAML)
  message("  ", OUTPUT_CSV)
}
