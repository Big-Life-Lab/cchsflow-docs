# parse_dataset_names.R
# Parse CCHS dataset names to extract filterable metadata
#
# Dataset naming patterns from ICES:
#   CCHS{year}_{region}_{type}_{cycle}_{modifiers}
#
# Examples:
#   CCHS2001_ONT_SHARE_11        → 2001, Ontario, Share, Cycle 1.1, Main
#   CCHS2004_CAN_SHARE_22_FDC    → 2004, Canada, Share, Cycle 2.2, Supplement (FDC)
#   CCHS200708_ONT_SHARE         → 2007-2008, Ontario, Share, Annual, Main
#   CCHS2012_CCHS_PUMF           → 2012, National, PUMF, Annual, Main
#   CCHS2001_PUBLIC_11           → 2001, National, Public, Cycle 1.1, Main

library(stringr)
library(dplyr)

#' Parse a single dataset name into metadata components
#'
#' @param dataset_id Dataset identifier (e.g., "CCHS2001_ONT_SHARE_11")
#' @return Named list with: year_start, year_end, region, file_type, cycle,
#'         cycle_label, is_supplement, supplement_type, is_bootstrap
parse_dataset_name <- function(dataset_id) {

  result <- list(
    dataset_id = dataset_id,
    year_start = NA_integer_,
    year_end = NA_integer_,
    year_label = NA_character_,
    region = "National",
    file_type = "Other",
    cycle = NA_character_,
    cycle_label = NA_character_,
    is_supplement = FALSE,
    supplement_type = NA_character_,
    is_bootstrap = FALSE
  )

  # Extract year(s) - patterns: CCHS2001, CCHS200708, CCHS201112
  year_match <- str_match(dataset_id, "^CCHS(\\d{4})(\\d{2})?")
  if (!is.na(year_match[1, 2])) {
    result$year_start <- as.integer(year_match[1, 2])
    if (!is.na(year_match[1, 3])) {
      # Two-digit second year (e.g., 200708 → 2007, 2008)
      second_year <- as.integer(year_match[1, 3])
      # Determine century: if second < 50 assume 2000s, else same century as first
      if (second_year < 50) {
        result$year_end <- 2000L + second_year
      } else {
        result$year_end <- 1900L + second_year
      }
      result$year_label <- paste0(result$year_start, "-", result$year_end)
    } else {
      result$year_end <- result$year_start
      result$year_label <- as.character(result$year_start)
    }
  }

  # Extract region
  if (str_detect(dataset_id, "_ONT_")) {
    result$region <- "Ontario"
  } else if (str_detect(dataset_id, "_CAN_")) {
    result$region <- "Canada"
  } else if (str_detect(dataset_id, "_HA_|_HA$")) {
    result$region <- "Health Authority"
  }
  # Default remains "National" for datasets without explicit region

  # Extract file type
  if (str_detect(dataset_id, "_SHARE")) {
    result$file_type <- "Share"
  } else if (str_detect(dataset_id, "_LINK")) {
    result$file_type <- "Linked"
  } else if (str_detect(dataset_id, "_PUMF|CCHS_PUMF")) {
    result$file_type <- "PUMF"
  } else if (str_detect(dataset_id, "_PUBLIC_")) {
    result$file_type <- "Public"
  } else if (str_detect(dataset_id, "_MH_|_MH$")) {
    result$file_type <- "Mental Health"
  } else if (str_detect(dataset_id, "_INC_")) {
    result$file_type <- "Income"
  }

  # Extract cycle (for pre-annual surveys: 11=1.1, 12=1.2, 21=2.1, 22=2.2, 31=3.1)
  cycle_match <- str_match(dataset_id, "_(11|12|21|22|31)(?:_|$)")
  if (!is.na(cycle_match[1, 2])) {
    result$cycle <- cycle_match[1, 2]
    cycle_map <- c(
      "11" = "Cycle 1.1 (2001)",
      "12" = "Cycle 1.2 (2002)",
      "21" = "Cycle 2.1 (2003)",
      "22" = "Cycle 2.2 (2004)",
      "31" = "Cycle 3.1 (2005)"
    )
    result$cycle_label <- cycle_map[result$cycle]
  } else if (!is.na(result$year_start) && result$year_start >= 2007) {
    result$cycle <- "annual"
    result$cycle_label <- "Annual"
  }

  # Check for bootstrap files
  if (str_detect(dataset_id, "_BOOT")) {
    result$is_bootstrap <- TRUE
  }

  # Check for supplement/special files
  supplement_patterns <- c(
    "LEVEL1" = "Level 1 geography",
    "LHIN" = "LHIN geography",
    "PB" = "Postal code",
    "PSTLCODE" = "Postal code",
    "HH" = "Household weights",
    "HHWT" = "Household weights",
    "FDC" = "Food description codes",
    "FID" = "Food identification",
    "FRL" = "Food recipe links",
    "R24" = "24-hour recall",
    "VDC" = "Variable description codes",
    "VMD" = "Variable metadata",
    "VSD" = "Variable summary data",
    "CFG" = "Configuration",
    "SIDE" = "Side dish",
    "COG" = "Cognition module",
    "SUB1" = "Sub-sample 1",
    "SUB3" = "Sub-sample 3",
    "LVL1" = "Level 1 geography",
    "IKN" = "IKN linkage",
    "RFH" = "Rapid Response"
  )

  for (pattern in names(supplement_patterns)) {
    if (str_detect(dataset_id, paste0("_", pattern, "(?:_|$)"))) {
      result$is_supplement <- TRUE
      if (is.na(result$supplement_type)) {
        result$supplement_type <- supplement_patterns[pattern]
      } else {
        result$supplement_type <- paste(result$supplement_type,
                                        supplement_patterns[pattern],
                                        sep = "; ")
      }
    }
  }

  result
}

#' Parse all dataset names and return a data frame
#'
#' @param dataset_ids Character vector of dataset IDs
#' @return Data frame with parsed metadata columns
parse_all_datasets <- function(dataset_ids) {

  parsed_list <- lapply(dataset_ids, parse_dataset_name)

  # Convert to data frame
  df <- bind_rows(lapply(parsed_list, as.data.frame, stringsAsFactors = FALSE))

  # Clean up for display
  df <- df |>
    mutate(
      year_label = ifelse(is.na(year_label), "Unknown", year_label),
      cycle_label = ifelse(is.na(cycle_label), "Unknown", cycle_label),
      supplement_type = ifelse(is.na(supplement_type), "-", supplement_type)
    )

  df
}

#' Get variables with parsed dataset metadata for filtering
#'
#' This joins variable availability with parsed dataset metadata to enable

' filtering variables by year, region, file type, etc.
#'
#' @param con DuckDB connection
#' @return Data frame with variables and their dataset metadata
get_variables_with_dataset_metadata <- function(con) {

  # Get variable availability
  availability <- dbGetQuery(con, "
    SELECT variable_name, dataset_id
    FROM variable_availability
  ")

  # Parse dataset names
  unique_datasets <- unique(availability$dataset_id)
  parsed_datasets <- parse_all_datasets(unique_datasets)

  # Join with availability
  availability_enriched <- availability |>
    left_join(parsed_datasets, by = "dataset_id")

  availability_enriched
}

#' Summarize dataset metadata per variable
#'
#' Creates aggregated columns showing which years, regions, file types each
#' variable appears in.
#'
#' @param con DuckDB connection
#' @return Data frame with variable summaries
summarize_variable_datasets <- function(con) {

  enriched <- get_variables_with_dataset_metadata(con)

  # Aggregate per variable
  summary <- enriched |>
    group_by(variable_name) |>
    summarize(
      # Year range
      min_year = min(year_start, na.rm = TRUE),
      max_year = max(year_end, na.rm = TRUE),
      years = paste(sort(unique(na.omit(year_label))), collapse = "; "),

      # Regions present
      regions = paste(sort(unique(region)), collapse = "; "),
      has_ontario = any(region == "Ontario"),
      has_national = any(region == "National"),
      has_canada = any(region == "Canada"),

      # File types present
      file_types = paste(sort(unique(file_type)), collapse = "; "),
      has_share = any(file_type == "Share"),
      has_linked = any(file_type == "Linked"),
      has_pumf = any(file_type == "PUMF"),

      # Cycles
      cycles = paste(sort(unique(na.omit(cycle_label))), collapse = "; "),

      # Main vs supplement
      in_main_files = any(!is_supplement & !is_bootstrap),
      in_supplement_files = any(is_supplement),
      in_bootstrap_files = any(is_bootstrap),

      # Dataset count by type
      n_share_datasets = sum(file_type == "Share" & !is_bootstrap),
      n_linked_datasets = sum(file_type == "Linked" & !is_bootstrap),
      n_pumf_datasets = sum(file_type == "PUMF"),
      n_ontario_datasets = sum(region == "Ontario" & !is_bootstrap),

      .groups = "drop"
    ) |>
    mutate(
      year_range = ifelse(
        is.infinite(min_year) | is.infinite(max_year),
        "Unknown",
        ifelse(min_year == max_year,
               as.character(min_year),
               paste0(min_year, "-", max_year))
      )
    )

  summary
}

# =============================================================================
# Testing
# =============================================================================

if (interactive()) {
  message("Testing parse_dataset_name()...")

  test_cases <- c(
    "CCHS2001_ONT_SHARE_11",
    "CCHS2002_ONT_SHARE_12_LEVEL1",
    "CCHS200708_ONT_SHARE",
    "CCHS2012_CCHS_PUMF",
    "CCHS2004_CAN_SHARE_22_FDC",
    "CCHS2001_PUBLIC_11",
    "CCHS200809_HA_COG_BOOT",
    "CCHS2015_RFH_ONT_SHARE_LEVEL1",
    "CCHS2021_ONT_SHARE_BOOT_HH"
  )

  for (tc in test_cases) {
    result <- parse_dataset_name(tc)
    message(sprintf("\n%s:", tc))
    message(sprintf("  Year: %s, Region: %s, Type: %s, Cycle: %s",
                    result$year_label, result$region, result$file_type,
                    result$cycle_label))
    message(sprintf("  Bootstrap: %s, Supplement: %s (%s)",
                    result$is_bootstrap, result$is_supplement,
                    result$supplement_type))
  }
}
