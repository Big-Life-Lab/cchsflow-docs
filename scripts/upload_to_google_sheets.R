#!/usr/bin/env Rscript
# upload_to_google_sheets.R
# Upload CCHS variable dictionary to Google Sheets
#
# Usage:
#   Rscript scripts/upload_to_google_sheets.R              # Create new sheet
#   Rscript scripts/upload_to_google_sheets.R <sheet_id>   # Update existing sheet
#
# Requires: googlesheets4 package and Google authentication

library(googlesheets4)
library(dplyr)

# Configuration
VARIABLES_CSV <- "data/exports/ices_cchs_variables_for_sheets.csv"
DATASETS_CSV <- "data/exports/ices_cchs_datasets_for_sheets.csv"
SHEET_NAME <- "CCHS Variable Dictionary"

# Parse command line args
args <- commandArgs(trailingOnly = TRUE)
sheet_id <- if (length(args) > 0) args[1] else NULL

message("=== Upload CCHS Variable Dictionary to Google Sheets ===")

# Load data
message("Loading data...")
variables <- read.csv(VARIABLES_CSV, stringsAsFactors = FALSE)
datasets <- read.csv(DATASETS_CSV, stringsAsFactors = FALSE)

message(sprintf("  Variables: %d rows", nrow(variables)))
message(sprintf("  Datasets: %d rows", nrow(datasets)))

# Prepare variables sheet - reorder columns for usability
variables_sheet <- variables |>
  select(
    variable_name,
    label,
    module,
    type,
    format,
    year_range,
    min_year,
    max_year,
    regions,
    file_types,
    has_ontario,
    has_share,
    has_linked,
    has_pumf,
    n_datasets,
    sample_datasets
  ) |>
  rename(
    `Variable` = variable_name,
    `Label` = label,
    `Module` = module,
    `Type` = type,
    `Format` = format,
    `Years` = year_range,
    `Min Year` = min_year,
    `Max Year` = max_year,
    `Regions` = regions,
    `File Types` = file_types,
    `Has Ontario` = has_ontario,
    `Has Share` = has_share,
    `Has Linked` = has_linked,
    `Has PUMF` = has_pumf,
    `Dataset Count` = n_datasets,
    `Sample Datasets` = sample_datasets
  )

# Prepare datasets sheet
datasets_sheet <- datasets |>
  select(
    dataset_id,
    variable_count,
    year_label,
    year_start,
    year_end,
    region,
    dataset_type,
    cycle_label,
    is_supplement,
    supplement_type,
    is_bootstrap
  ) |>
  rename(
    `Dataset ID` = dataset_id,
    `Variables` = variable_count,
    `Year` = year_label,
    `Start Year` = year_start,
    `End Year` = year_end,
    `Region` = region,
    `Type` = dataset_type,
    `Cycle` = cycle_label,
    `Is Supplement` = is_supplement,
    `Supplement Type` = supplement_type,
    `Is Bootstrap` = is_bootstrap
  )

# Authenticate (will open browser if needed)
message("\nAuthenticating with Google...")
gs4_auth()

if (is.null(sheet_id)) {
  # Create new spreadsheet
  message("\nCreating new Google Sheet...")
  ss <- gs4_create(
    SHEET_NAME,
    sheets = list(
      Variables = variables_sheet,
      Datasets = datasets_sheet
    )
  )
  message(sprintf("\nCreated: %s", ss))
  message(sprintf("URL: https://docs.google.com/spreadsheets/d/%s", ss))

} else {
  # Update existing spreadsheet
  message(sprintf("\nUpdating existing sheet: %s", sheet_id))

  # Clear and write Variables sheet
  message("  Writing Variables sheet...")
  tryCatch({
    sheet_write(variables_sheet, ss = sheet_id, sheet = "Variables")
  }, error = function(e) {
    # Sheet might not exist, try creating it
    sheet_add(sheet_id, sheet = "Variables")
    sheet_write(variables_sheet, ss = sheet_id, sheet = "Variables")
  })

  # Clear and write Datasets sheet
  message("  Writing Datasets sheet...")
  tryCatch({
    sheet_write(datasets_sheet, ss = sheet_id, sheet = "Datasets")
  }, error = function(e) {
    sheet_add(sheet_id, sheet = "Datasets")
    sheet_write(datasets_sheet, ss = sheet_id, sheet = "Datasets")
  })

  message(sprintf("\nUpdated: https://docs.google.com/spreadsheets/d/%s", sheet_id))
}

message("\n=== Upload complete ===")
message("Tip: Use Data > Create a filter in Google Sheets for dropdown filtering")
