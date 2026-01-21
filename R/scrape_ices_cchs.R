# scrape_ices_cchs.R
# Scrape CCHS dataset and variable availability from ICES Data Dictionary
# https://datadictionary.ices.on.ca/Applications/DataDictionary/Library.aspx?Library=CCHS
#
# Approach: Dataset-centric (matches repo structure)
# - Level 1: Extract 231 dataset IDs (done via VIEWSTATE decode)
# - Level 2: For each dataset, extract variable list (requires browser automation)
# - Level 3: Optional variable details

library(httr)
library(rvest)
library(dplyr)
library(stringr)
library(yaml)
library(purrr)
library(base64enc)

# Configuration
BASE_URL <- "https://datadictionary.ices.on.ca/Applications/DataDictionary/"
DELAY_SECONDS <- 1.5  # Be respectful of the server
OUTPUT_FILE <- "data/catalog/ices_cchs_datasets.yaml"

#' Extract form data from ASP.NET page
#' @param html_content The HTML content of the page
#' @return Named list with VIEWSTATE, EVENTVALIDATION, etc.
extract_aspnet_form_data <- function(html_content) {
  page <- read_html(html_content)

  list(
    viewstate = page %>%
      html_element("#__VIEWSTATE") %>%
      html_attr("value"),
    viewstate_gen = page %>%
      html_element("#__VIEWSTATEGENERATOR") %>%
      html_attr("value"),
    event_validation = page %>%
      html_element("#__EVENTVALIDATION") %>%
      html_attr("value")
  )
}

#' Get list of CCHS datasets from library page
#' @return Data frame with dataset information
get_cchs_datasets <- function() {

  url <- paste0(BASE_URL, "Library.aspx?Library=CCHS")

  message("Fetching CCHS library page...")
  resp <- GET(url, config(ssl_verifypeer = FALSE))

  if (status_code(resp) != 200) {
    stop("Failed to fetch library page: ", status_code(resp))
  }

  html_content <- content(resp, as = "text", encoding = "UTF-8")

  # The datasets are encoded in the VIEWSTATE (ASP.NET stores form state there)
  viewstate_match <- str_match(html_content, '__VIEWSTATE"\\s+value="([^"]+)"')

  if (is.na(viewstate_match[1, 2])) {
    stop("Could not find VIEWSTATE in page")
  }


  # Decode base64 VIEWSTATE (contains binary data with embedded NULs)
  viewstate_value <- viewstate_match[1, 2]
  decoded_raw <- base64decode(viewstate_value)


  # Convert each byte to character, filtering out NUL bytes
  decoded_chars <- sapply(decoded_raw, function(b) {
    if (b == 0) return("")
    rawToChar(as.raw(b))
  })
  decoded <- paste(decoded_chars, collapse = "")

  # Extract CCHS dataset names (pattern: CCHS followed by year and suffixes)
  datasets <- str_extract_all(decoded, "CCHS\\d{4,6}[_A-Z0-9]*")[[1]]
  datasets <- unique(datasets)

  message("Found ", length(datasets), " unique datasets")

  # Parse dataset IDs into structured components
  tibble(dataset_id = datasets) %>%
    mutate(
      # Extract year (handles both CCHS2009 and CCHS200910 patterns)
      year_raw = str_extract(dataset_id, "(?<=CCHS)\\d{4,6}"),
      year = case_when(
        nchar(year_raw) == 6 ~ paste0(substr(year_raw, 1, 4), "-", substr(year_raw, 1, 2), substr(year_raw, 5, 6)),
        nchar(year_raw) == 4 ~ year_raw,
        TRUE ~ year_raw
      ),

      # Determine dataset type
      type = case_when(
        str_detect(dataset_id, "_BOOT") ~ "BOOT",
        str_detect(dataset_id, "_SHARE") ~ "SHARE",
        str_detect(dataset_id, "_LINK") ~ "LINK",
        str_detect(dataset_id, "_PUMF|_PUBLIC") ~ "PUMF",
        str_detect(dataset_id, "_INC") ~ "INC",
        TRUE ~ "OTHER"
      ),

      # Determine region
      region = case_when(
        str_detect(dataset_id, "_ONT_") ~ "Ontario",
        str_detect(dataset_id, "_CAN_") ~ "Canada",
        TRUE ~ "Unknown"
      ),

      # Is it a linked file?
      linkage = str_detect(dataset_id, "_LINK"),

      # Extract cycle if present (e.g., _11, _21, _31)
      cycle_code = str_extract(dataset_id, "_\\d{2}$"),
      cycle = case_when(
        cycle_code == "_11" ~ "1.1",
        cycle_code == "_12" ~ "1.2",
        cycle_code == "_21" ~ "2.1",
        cycle_code == "_22" ~ "2.2",
        cycle_code == "_31" ~ "3.1",
        TRUE ~ NA_character_
      ),

      # Additional flags
      has_household = str_detect(dataset_id, "_HH"),
      has_lhin = str_detect(dataset_id, "_LHIN"),
      is_level1 = str_detect(dataset_id, "_LEVEL1")
    ) %>%
    select(-year_raw, -cycle_code)
}

#' Build initial ICES dataset catalog (Level 1 only - no variables yet)
#' @param output_file Path to save YAML catalog
#' @return Tibble of datasets
build_ices_dataset_catalog <- function(output_file = OUTPUT_FILE) {


  message("Building ICES CCHS Dataset Catalog...")
  message("Source: ", BASE_URL, "Library.aspx?Library=CCHS")


  # Get dataset list from VIEWSTATE
  datasets <- get_cchs_datasets()

  message("\n", nrow(datasets), " datasets extracted")

  # Summary
  cat("\nDataset Summary by Type:\n")
  print(datasets %>% count(type, sort = TRUE))

  cat("\nDataset Summary by Region:\n
")
  print(datasets %>% count(region, sort = TRUE))

  # Build YAML structure
  catalog <- list(
    catalog_metadata = list(
      version = "v1.0.0",
      created_date = format(Sys.Date(), "%Y-%m-%d"),
      last_updated = format(Sys.Date(), "%Y-%m-%d"),
      source = "ICES Data Dictionary",
      source_url = paste0(BASE_URL, "Library.aspx?Library=CCHS"),
      total_datasets = nrow(datasets),
      years_covered = paste(
        min(substr(datasets$year, 1, 4)),
        max(substr(datasets$year, 1, 4)),
        sep = "-"
      ),
      ices_library = "CCHS",
      scrape_status = "datasets_only",
      note = "Variables not yet scraped - requires browser automation"
    ),

    datasets = datasets %>%
      rowwise() %>%
      mutate(
        variables = list(list())  # Empty placeholder for variables
      ) %>%
      ungroup() %>%
      split(seq_len(nrow(.))) %>%
      map(~ as.list(.x))
  )

  # Ensure output directory exists
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Write YAML

  write_yaml(catalog, output_file)
  message("\nCatalog saved to: ", output_file)

  invisible(datasets)
}

#' Scrape variables for a single dataset (requires browser automation)
#' This is a placeholder - actual implementation needs chromote/RSelenium
#' @param dataset_id ICES dataset ID (e.g., "CCHS2009_ONT_SHARE")
#' @return Tibble of variables
scrape_dataset_variables <- function(dataset_id) {
  # TODO: Implement with chromote browser automation
  # Steps needed:
  # 1. Navigate to Library.aspx?Library=CCHS

  # 2. Click the dataset link (triggers __doPostBack)
  # 3. Extract variable table from resulting page
  # 4. For each variable, optionally click to get details

  message("Variable scraping not yet implemented for: ", dataset_id)
  message("Requires browser automation (chromote or RSelenium)")

  tibble(
    variable_name = character(0),
    variable_label = character(0)
  )
}

# ============================================================================
# Main entry points
# ============================================================================

#' Quick start: Build dataset catalog (Level 1)
#' @export
scrape_ices_cchs <- function() {
  build_ices_dataset_catalog()
}

# Usage when sourced interactively
if (interactive()) {
  message("ICES CCHS Data Dictionary Scraper")
  message("==================================")
  message("")
  message("Available functions:")
  message("  scrape_ices_cchs()          - Build dataset catalog (Level 1)")
  message("  get_cchs_datasets()         - Get dataset list as tibble")
  message("  scrape_dataset_variables()  - [TODO] Scrape variables for one dataset")
  message("")
  message("Output: ", OUTPUT_FILE)
}
