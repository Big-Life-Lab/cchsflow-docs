# parse_ices_variable_list.R
# Parse copy-pasted variable lists from ICES Data Dictionary
#
# Usage:
#   1. Copy variable table from ICES site (Ctrl+A on the table)
#   2. Save to text file: development/ices-dictionary/raw/group_01.txt
#   3. Run: parse_ices_variable_lists()
#
# Expected input format:
#   Variable Name	Description	Type
#   ADMA_IMP	Imputation flag	Num8
#   ALCA_1	Drank alcohol in past 12 months	Num8
#   ...
#   Number of variables: 614

library(dplyr)
library(stringr)
library(readr)
library(purrr)

#' Parse a single copy-pasted variable list
#' @param file_path Path to text file with copied content
#' @param group_name Dataset group name (e.g., "01. CCHS 2000-2001")
#' @return Tibble with variable_name, description, type, group
parse_single_list <- function(file_path, group_name = NA) {

  lines <- read_lines(file_path)

  # Find header line
  header_idx <- which(str_detect(lines, "^Variable Name\\s+Description\\s+Type"))

  if (length(header_idx) == 0) {
    # Try alternate format (tab-separated)
    header_idx <- which(str_detect(lines, "Variable Name"))
  }

  if (length(header_idx) == 0) {
    warning("Could not find header in: ", file_path)
    return(tibble())
  }

  # Find "Number of variables" line (marks end of data)
  end_idx <- which(str_detect(lines, "^Number of variables:"))

  if (length(end_idx) == 0) {
    end_idx <- length(lines) + 1
  }

  # Extract data lines (between header and end)
  data_lines <- lines[(header_idx[1] + 1):(end_idx[1] - 1)]
  data_lines <- data_lines[!str_detect(data_lines, "^\\s*$")]  # Remove empty

  # Parse each line (tab-separated)
  parsed <- map_dfr(data_lines, function(line) {
    parts <- str_split(line, "\\t")[[1]]
    if (length(parts) >= 3) {
      tibble(
        variable_name = str_trim(parts[1]),
        description = str_trim(parts[2]),
        type = str_trim(parts[3])
      )
    } else {
      # Try space-separated (fallback)
      match <- str_match(line, "^(\\S+)\\s+(.+)\\s+(\\S+)$")
      if (!is.na(match[1, 1])) {
        tibble(
          variable_name = match[1, 2],
          description = str_trim(match[1, 3]),
          type = match[1, 4]
        )
      } else {
        tibble()
      }
    }
  })

  parsed %>%
    mutate(group = group_name) %>%
    filter(nchar(variable_name) > 0)
}

#' Parse all variable lists from raw files
#' @param raw_dir Directory containing group_*.txt files
#' @return Tibble with all variables from all groups
parse_all_variable_lists <- function(raw_dir = "development/ices-dictionary/raw") {

  files <- list.files(raw_dir, pattern = "\\.txt$", full.names = TRUE)

  if (length(files) == 0) {
    stop("No .txt files found in: ", raw_dir)
  }

  message("Parsing ", length(files), " files...")

  all_vars <- map_dfr(files, function(f) {
    group_name <- str_extract(basename(f), "group_\\d+")
    parse_single_list(f, group_name)
  })

  message("Found ", nrow(all_vars), " total variable entries")
  message("Unique variable names: ", n_distinct(all_vars$variable_name))

  all_vars
}

#' Get unique variable names for ICES querying
#' @param all_vars Result from parse_all_variable_lists()
#' @return Character vector of unique variable names
get_unique_variables <- function(all_vars) {
  sort(unique(all_vars$variable_name))
}

#' Save variable list for subsequent ICES scraping
#' @param vars Character vector of variable names
#' @param output_file Path to save
save_variable_list <- function(vars, output_file = "development/ices-dictionary/ices_variable_names.txt") {
  write_lines(vars, output_file)
  message("Saved ", length(vars), " variable names to: ", output_file)
}

# ============================================================================
# Main workflow
# ============================================================================

if (interactive()) {
  message("ICES Variable List Parser")
  message("=========================")
  message("")
  message("Workflow:")
  message("1. Copy variable tables from ICES site to text files:")
  message("   development/ices-dictionary/raw/group_01.txt")
  message("   development/ices-dictionary/raw/group_02.txt")
  message("   etc.")
  message("")
  message("2. Run: all_vars <- parse_all_variable_lists()")
  message("3. Run: unique_vars <- get_unique_variables(all_vars)")
  message("4. Run: save_variable_list(unique_vars)")
  message("")
  message("Output: development/ices-dictionary/ices_variable_names.txt")
}
