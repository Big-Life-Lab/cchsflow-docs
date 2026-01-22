#!/usr/bin/env Rscript
# run_ices_full_scrape_duckdb.R
# Run the complete ICES CCHS variable scrape with DuckDB storage
#
# Estimated time: ~6 hours at 1.5s rate limit
# Output: data/ices_cchs_dictionary.duckdb
#
# Usage:
#   Rscript --vanilla scripts/run_ices_full_scrape_duckdb.R          # Fresh start
#   Rscript --vanilla scripts/run_ices_full_scrape_duckdb.R --resume # Resume from checkpoint
#
# Features:
# - Checkpoint commits every 500 variables (data saved to disk)
# - Resume capability: skips already-scraped variables
# - Progress tracking with ETA
#
# This script:
# 1. Creates DuckDB database (or connects to existing for resume)
# 2. Scrapes variables from ICES (skipping already-scraped on resume)
# 3. Inserts data into normalized tables
# 4. Updates dataset variable counts
# 5. Exports availability matrix to CSV

# Get script directory and set working directory
# Handle both interactive and Rscript modes
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    # Rscript mode
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  } else if (interactive()) {
    # Interactive mode - try sys.frame
    return(dirname(sys.frame(1)$ofile))
  } else {
    # Fallback
    return(getwd())
  }
}
script_dir <- get_script_dir()
setwd(normalizePath(file.path(script_dir, "..")))

source("R/scrape_ices_variables.R")
source("R/ices_duckdb.R")

# Check for --resume flag
args <- commandArgs(trailingOnly = TRUE)
resume_mode <- "--resume" %in% args

cat("=================================================\n")
cat("ICES CCHS Full Variable Scrape (DuckDB)\n")
if (resume_mode) cat("*** RESUME MODE ***\n")
cat("=================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# -----------------------------------------------------------------------------
# Step 1: Load variable names
# -----------------------------------------------------------------------------

var_file <- "development/ices-dictionary/ices_variable_names.txt"
if (!file.exists(var_file)) {
  stop("Variable names file not found: ", var_file)
}

variable_names <- readr::read_lines(var_file)
variable_names <- variable_names[nchar(trimws(variable_names)) > 0]

cat("Variables to scrape:", length(variable_names), "\n")
cat("Rate limit: 1.5 seconds\n")
cat("Estimated time:", round(length(variable_names) * 1.5 / 3600, 1), "hours\n\n")

# -----------------------------------------------------------------------------
# Step 2: Create or connect to database
# -----------------------------------------------------------------------------

already_scraped <- character(0)

if (resume_mode && file.exists(ICES_DB_PATH)) {
  cat("Connecting to existing database for resume...\n")
  con <- get_ices_connection()

  # Get list of already-scraped variables
  already_scraped <- dbGetQuery(con, "SELECT variable_name FROM variables")$variable_name
  cat("Found", length(already_scraped), "already-scraped variables\n")

  # Filter to only variables we still need
  variable_names <- setdiff(variable_names, already_scraped)
  cat("Remaining to scrape:", length(variable_names), "\n\n")

  if (length(variable_names) == 0) {
    cat("All variables already scraped! Skipping to post-processing...\n\n")
  }
} else {
  cat("Creating fresh DuckDB database...\n")
  con <- create_ices_database(overwrite = TRUE)

  # Set metadata
  set_catalog_metadata(con, list(
    version = "1.0.0",
    source = "ICES Data Dictionary",
    source_url = "https://datadictionary.ices.on.ca/Applications/DataDictionary/Library.aspx?Library=CCHS",
    scrape_start = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    ices_library = "CCHS"
  ))
}

# -----------------------------------------------------------------------------
# Step 3: Scrape and insert variables
# -----------------------------------------------------------------------------

total <- length(variable_names)
successful <- 0
failed <- character(0)
start_time <- Sys.time()

if (total > 0) {
  cat("\nStarting scrape...\n")
  cat("Progress will be reported every 100 variables.\n\n")

  # Begin transaction for bulk insert performance
  dbExecute(con, "BEGIN TRANSACTION")

  tryCatch({

    for (i in seq_along(variable_names)) {
      var_name <- variable_names[i]

      # Progress report
      if (i %% 100 == 0 || i == 1) {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
        rate <- if (elapsed > 0) i / elapsed else 1
        remaining <- (total - i) / rate
        cat(sprintf("[%d/%d] (%.1f%%) Scraping %s... ETA: %.1f min\n",
                    i, total, 100 * i / total, var_name, remaining))
      }

      # Scrape variable
      result <- scrape_ices_variable(var_name)

      if (!is.null(result)) {
        insert_variable(con, result)
        successful <- successful + 1
      } else {
        failed <- c(failed, var_name)
      }

      # Rate limiting
      if (i < total) {
        Sys.sleep(1.0)
      }

      # Checkpoint commit every 100 variables (data persisted to disk)
      if (i %% 100 == 0) {
        dbExecute(con, "COMMIT")
        dbExecute(con, "BEGIN TRANSACTION")
        cat("  [Checkpoint: committed ", i, " variables to disk]\n")
      }
    }

    dbExecute(con, "COMMIT")

  }, error = function(e) {
    # Try to commit what we have before failing
    tryCatch(dbExecute(con, "COMMIT"), error = function(e2) NULL)
    cat("\nERROR during scrape: ", e$message, "\n")
    cat("Variables scraped this session: ", successful, "\n")
    cat("Run with --resume to continue from checkpoint.\n")
  })
} else {
  cat("\nNo variables to scrape.\n")
}

# -----------------------------------------------------------------------------
# Step 4: Update dataset variable counts
# -----------------------------------------------------------------------------

cat("\nUpdating dataset variable counts...\n")
update_dataset_counts(con)

# Update final metadata
total_in_db <- dbGetQuery(con, "SELECT COUNT(*) as n FROM variables")$n
set_catalog_metadata(con, list(
  scrape_end = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  total_variables = total_in_db,
  failed_variables = length(failed),
  scraped_this_session = successful
))

# -----------------------------------------------------------------------------
# Step 5: Export and report
# -----------------------------------------------------------------------------

cat("\nExporting availability matrix...\n")
export_availability_csv(con)

# Final statistics
stats <- get_database_stats(con)

cat("\n")
cat("=================================================\n")
cat("Scrape Complete!\n")
cat("=================================================\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Duration:", round(as.numeric(difftime(Sys.time(), start_time, units = "hours")), 2), "hours\n")
cat("\n")
cat("Database: data/ices_cchs_dictionary.duckdb\n")
cat("  Variables:            ", stats$variables, "\n")
cat("  Datasets:             ", stats$datasets, "\n")
cat("  Availability records: ", stats$availability_records, "\n")
cat("  Value formats:        ", stats$formats, "\n")
cat("  Format codes:         ", stats$format_codes, "\n")
cat("\n")
cat("Failed variables:", length(failed), "\n")
if (length(failed) > 0 && length(failed) <= 50) {
  cat("  ", paste(failed, collapse = ", "), "\n")
} else if (length(failed) > 50) {
  cat("  (too many to list - see logs)\n")
  writeLines(failed, "logs/failed_variables.txt")
}
cat("\n")
cat("Exports:\n")
cat("  data/catalog/ices_cchs_availability_matrix.csv\n")
cat("=================================================\n")

# Disconnect
dbDisconnect(con)
