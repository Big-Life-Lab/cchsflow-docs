#!/usr/bin/env Rscript
# export_enriched_variables.R
# Regenerate variables CSV with parsed dataset metadata for filtering
#
# Adds columns: year_range, regions, file_types, has_ontario, has_share, etc.
# These enable the CCHS Variable Browser to filter by year, region, and file type.

library(duckdb)
library(DBI)
library(dplyr)
library(stringr)

# Load parsing functions
source("R/parse_dataset_names.R")

# Configuration
DB_PATH <- "data/ices_cchs_dictionary.duckdb"
VARIABLES_OUTPUT <- "data/exports/ices_cchs_variables_for_sheets.csv"
DATASETS_OUTPUT <- "data/exports/ices_cchs_datasets_for_sheets.csv"

message("=== Exporting enriched CCHS variables ===")
message("Database: ", DB_PATH)

# Connect to database
con <- dbConnect(duckdb::duckdb(), DB_PATH)

# Get all variables
variables <- dbGetQuery(con, "
  SELECT
    v.variable_name,
    SUBSTR(v.variable_name, 1, 4) as module,
    v.label,
    v.type,
    v.format,
    v.available_in_count as n_datasets
  FROM variables v
  ORDER BY v.variable_name
")
message("Loaded ", nrow(variables), " variables")

# Get all availability with dataset info
availability <- dbGetQuery(con, "
  SELECT variable_name, dataset_id
  FROM variable_availability
")
message("Loaded ", nrow(availability), " availability records")

# Parse all unique datasets
unique_datasets <- unique(availability$dataset_id)
message("Parsing ", length(unique_datasets), " dataset names...")
parsed_datasets <- parse_all_datasets(unique_datasets)

# Enrich availability with parsed metadata
availability_enriched <- availability |>
  left_join(parsed_datasets, by = "dataset_id")

# Aggregate per variable: get filterable metadata
message("Aggregating dataset metadata per variable...")
variable_summary <- availability_enriched |>
  group_by(variable_name) |>
  summarize(
    # Year range
    min_year = min(year_start, na.rm = TRUE),
    max_year = max(year_end, na.rm = TRUE),

    # Regions present (for filtering)
    has_ontario = any(region == "Ontario"),
    has_national = any(region == "National" | region == "Canada"),

    # File types present (for filtering)
    has_share = any(file_type == "Share"),
    has_linked = any(file_type == "Linked"),
    has_pumf = any(file_type == "PUMF"),

    # Main vs supplement (for filtering)
    in_main_files = any(!is_supplement & !is_bootstrap),

    # Sample datasets (truncated list for display)
    sample_datasets = paste(head(sort(unique(dataset_id)), 3), collapse = "; "),

    .groups = "drop"
  ) |>
  mutate(
    # Create display columns
    year_range = case_when(
      is.infinite(min_year) | is.infinite(max_year) ~ "Unknown",
      min_year == max_year ~ as.character(min_year),
      TRUE ~ paste0(min_year, "-", max_year)
    ),
    # Regions for display
    regions = case_when(
      has_ontario & has_national ~ "Ontario, National",
      has_ontario ~ "Ontario",
      has_national ~ "National",
      TRUE ~ "Unknown"
    ),
    # File types for display
    file_types = paste0(
      ifelse(has_share, "Share", ""),
      ifelse(has_share & (has_linked | has_pumf), ", ", ""),
      ifelse(has_linked, "Linked", ""),
      ifelse(has_linked & has_pumf, ", ", ""),
      ifelse(has_pumf, "PUMF", "")
    ) |> str_replace("^, |, $", "") |> str_replace(", , ", ", ")
  ) |>
  # Clean up empty strings
  mutate(
    file_types = ifelse(file_types == "", "Other", file_types)
  )

# Join with main variables table
variables_enriched <- variables |>
  left_join(variable_summary, by = "variable_name") |>
  select(
    variable_name,
    module,
    label,
    type,
    format,
    n_datasets,
    year_range,
    min_year,
    max_year,
    regions,
    has_ontario,
    has_national,
    file_types,
    has_share,
    has_linked,
    has_pumf,
    in_main_files,
    sample_datasets
  )

# Export variables
message("Exporting to: ", VARIABLES_OUTPUT)
write.csv(variables_enriched, VARIABLES_OUTPUT, row.names = FALSE)
message("Exported ", nrow(variables_enriched), " variables with enriched metadata")

# Export datasets with parsed metadata
message("\nExporting datasets to: ", DATASETS_OUTPUT)
datasets_enriched <- parsed_datasets |>
  left_join(
    dbGetQuery(con, "SELECT dataset_id, variable_count FROM datasets"),
    by = "dataset_id"
  ) |>
  select(
    dataset_id,
    variable_count,
    year_label,
    year_start,
    year_end,
    region,
    file_type,
    cycle_label,
    is_supplement,
    supplement_type,
    is_bootstrap
  ) |>
  rename(
    dataset_type = file_type
  ) |>
  arrange(dataset_id)

write.csv(datasets_enriched, DATASETS_OUTPUT, row.names = FALSE)
message("Exported ", nrow(datasets_enriched), " datasets")

# Disconnect
dbDisconnect(con)

message("\n=== Export complete ===")
message("Variables: ", VARIABLES_OUTPUT)
message("Datasets: ", DATASETS_OUTPUT)
