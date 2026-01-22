# ices_duckdb.R
# DuckDB storage for ICES Data Dictionary
#
# Provides a relational database for efficient querying of:
# - Variable metadata (14,006 variables)
# - Dataset availability (which variables in which datasets)
# - Value formats (normalized code/label mappings)
#
# Database: data/ices_cchs_dictionary.duckdb

library(duckdb)
library(DBI)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)

# Configuration
ICES_DB_PATH <- "data/ices_cchs_dictionary.duckdb"

# =============================================================================
# Database setup
# =============================================================================

#' Create ICES DuckDB database with schema
#' @param db_path Path to database file
#' @param overwrite If TRUE, delete existing database
#' @return DuckDB connection
create_ices_database <- function(db_path = ICES_DB_PATH, overwrite = FALSE) {

  if (overwrite && file.exists(db_path)) {
    file.remove(db_path)
    message("Removed existing database: ", db_path)
  }

  # Ensure directory exists
  dir.create(dirname(db_path), showWarnings = FALSE, recursive = TRUE)

  con <- dbConnect(duckdb::duckdb(), db_path)

  # Create tables
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS catalog_metadata (
      key VARCHAR PRIMARY KEY,
      value VARCHAR
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS variables (
      variable_name VARCHAR PRIMARY KEY,
      label VARCHAR NOT NULL,
      type VARCHAR NOT NULL,
      format VARCHAR,
      values_raw VARCHAR,
      available_in_raw VARCHAR,
      available_in_count INTEGER
    )
  ")

  # Datasets table stores only the raw dataset_id from ICES "Available In" field

  # No interpretation of naming conventions - that's done post-scrape
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS datasets (
      dataset_id VARCHAR PRIMARY KEY,
      variable_count INTEGER
    )
  ")

  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS variable_availability (
      variable_name VARCHAR NOT NULL,
      dataset_id VARCHAR NOT NULL,
      PRIMARY KEY (variable_name, dataset_id),
      FOREIGN KEY (variable_name) REFERENCES variables(variable_name),
      FOREIGN KEY (dataset_id) REFERENCES datasets(dataset_id)
    )
  ")

  # Value codes table stores parsed code/label pairs
  # format_name is the ICES format code (e.g., "CCHS_YESNOFM") when available,

  # or the variable_name prefixed with "_var_" when format is missing
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS value_formats (
      format_name VARCHAR NOT NULL,
      code VARCHAR NOT NULL,
      label VARCHAR NOT NULL,
      PRIMARY KEY (format_name, code)
    )
  ")

  # Create indexes for common queries
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_va_variable ON variable_availability(variable_name)")
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_va_dataset ON variable_availability(dataset_id)")
  dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_var_format ON variables(format)")

  message("Created ICES database: ", db_path)

  con
}

#' Get connection to existing ICES database
#' @param db_path Path to database file
#' @return DuckDB connection
get_ices_connection <- function(db_path = ICES_DB_PATH) {
  if (!file.exists(db_path)) {
    stop("Database not found: ", db_path, "\nRun create_ices_database() first.")
  }
  dbConnect(duckdb::duckdb(), db_path)
}

# =============================================================================
# Data insertion
# =============================================================================

#' Insert scraped variable data into database
#' @param con DuckDB connection
#' @param variable_data List from scrape_ices_variable()
#' @return TRUE if successful
insert_variable <- function(con, variable_data) {

  # Insert variable (including raw HTML/text for verbatim storage)
  dbExecute(con, "
    INSERT OR REPLACE INTO variables (variable_name, label, type, format, values_raw, available_in_raw, available_in_count)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  ", params = list(
    variable_data$variable_name,
    variable_data$label,
    variable_data$type,
    variable_data$format,
    variable_data$values_raw,
    variable_data$available_in_raw,
    variable_data$available_in_count
  ))

  # Insert availability records
  for (dataset_id in variable_data$available_in) {
    # Ensure dataset exists (insert stub if not)
    dbExecute(con, "
      INSERT OR IGNORE INTO datasets (dataset_id) VALUES (?)
    ", params = list(dataset_id))

    # Insert availability
    dbExecute(con, "
      INSERT OR IGNORE INTO variable_availability (variable_name, dataset_id)
      VALUES (?, ?)
    ", params = list(variable_data$variable_name, dataset_id))
  }

  # Insert value format codes (parsed from values_raw)
  # Use format name if available, otherwise use "_var_{variable_name}" as key
  if (!is.null(variable_data$values) && length(variable_data$values) > 0) {
    format_key <- if (!is.null(variable_data$format) && variable_data$format != "") {
      variable_data$format
    } else {
      paste0("_var_", variable_data$variable_name)
    }
    for (v in variable_data$values) {
      dbExecute(con, "
        INSERT OR IGNORE INTO value_formats (format_name, code, label)
        VALUES (?, ?, ?)
      ", params = list(format_key, v$code, v$label))
    }
  }

  TRUE
}

#' Batch insert variables with progress
#' @param con DuckDB connection
#' @param results Results from scrape_ices_variables_batch()
#' @return Number of variables inserted
batch_insert_variables <- function(con, results) {

  n <- length(results$variables)
  message("Inserting ", n, " variables into database...")

  # Start transaction for performance
  dbExecute(con, "BEGIN TRANSACTION")

  tryCatch({
    for (i in seq_along(results$variables)) {
      insert_variable(con, results$variables[[i]])

      if (i %% 500 == 0) {
        message(sprintf("  [%d/%d] inserted...", i, n))
      }
    }

    dbExecute(con, "COMMIT")
    message("Inserted ", n, " variables successfully")

  }, error = function(e) {
    dbExecute(con, "ROLLBACK")
    stop("Insert failed: ", e$message)
  })

  n
}

#' Update variable counts per dataset
#' @param con DuckDB connection
#' @description Updates variable_count in datasets table based on variable_availability
update_dataset_counts <- function(con) {
  dbExecute(con, "
    UPDATE datasets SET variable_count = (
      SELECT COUNT(*)
      FROM variable_availability va
      WHERE va.dataset_id = datasets.dataset_id
    )
  ")
  message("Updated variable counts for all datasets")
}

#' Set catalog metadata
#' @param con DuckDB connection
#' @param metadata Named list of metadata key-value pairs
set_catalog_metadata <- function(con, metadata) {
  for (key in names(metadata)) {
    dbExecute(con, "
      INSERT OR REPLACE INTO catalog_metadata (key, value) VALUES (?, ?)
    ", params = list(key, as.character(metadata[[key]])))
  }
}

# =============================================================================
# Query functions
# =============================================================================

#' Get variable info
#' @param con DuckDB connection
#' @param variable_name Variable name
#' @return Data frame with variable info
get_variable <- function(con, variable_name) {
  dbGetQuery(con, "
    SELECT v.variable_name, v.label, v.type, v.format, v.available_in_count,
           STRING_AGG(va.dataset_id, ', ') as datasets
    FROM variables v
    LEFT JOIN variable_availability va ON v.variable_name = va.variable_name
    WHERE v.variable_name = ?
    GROUP BY v.variable_name, v.label, v.type, v.format, v.available_in_count
  ", params = list(variable_name))
}

#' Get all variables in a dataset
#' @param con DuckDB connection
#' @param dataset_id Dataset ID
#' @return Data frame with variables
get_dataset_variables <- function(con, dataset_id) {
  dbGetQuery(con, "
    SELECT v.*
    FROM variables v
    JOIN variable_availability va ON v.variable_name = va.variable_name
    WHERE va.dataset_id = ?
    ORDER BY v.variable_name
  ", params = list(dataset_id))
}

#' Get value codes for a format
#' @param con DuckDB connection
#' @param format_name Format name
#' @return Data frame with codes and labels
get_format_codes <- function(con, format_name) {
  dbGetQuery(con, "
    SELECT code, label
    FROM value_formats
    WHERE format_name = ?
    ORDER BY code
  ", params = list(format_name))
}

#' Find variables by pattern
#' @param con DuckDB connection
#' @param pattern SQL LIKE pattern
#' @return Data frame with matching variables
search_variables <- function(con, pattern) {
  dbGetQuery(con, "
    SELECT variable_name, label, type, format, available_in_count
    FROM variables
    WHERE variable_name LIKE ? OR label LIKE ?
    ORDER BY variable_name
  ", params = list(pattern, pattern))
}

#' Get variables common to multiple datasets
#' @param con DuckDB connection
#' @param dataset_ids Character vector of dataset IDs
#' @return Data frame with variables present in ALL specified datasets
get_common_variables <- function(con, dataset_ids) {
  n_datasets <- length(dataset_ids)
  placeholders <- paste(rep("?", n_datasets), collapse = ", ")

  query <- sprintf("
    SELECT v.variable_name, v.label, v.type, v.format,
           COUNT(DISTINCT va.dataset_id) as n_datasets
    FROM variables v
    JOIN variable_availability va ON v.variable_name = va.variable_name
    WHERE va.dataset_id IN (%s)
    GROUP BY v.variable_name, v.label, v.type, v.format
    HAVING COUNT(DISTINCT va.dataset_id) = %d
    ORDER BY v.variable_name
  ", placeholders, n_datasets)

  dbGetQuery(con, query, params = as.list(dataset_ids))
}

#' Get availability matrix (wide format)
#' @param con DuckDB connection
#' @param variables Optional character vector of variable names to include
#' @param datasets Optional character vector of dataset IDs to include
#' @return Data frame with variables as rows, datasets as columns
get_availability_matrix <- function(con, variables = NULL, datasets = NULL) {

  # Build query with optional filters
  query <- "SELECT variable_name, dataset_id FROM variable_availability"
  params <- list()

  conditions <- c()
  if (!is.null(variables)) {
    placeholders <- paste(rep("?", length(variables)), collapse = ", ")
    conditions <- c(conditions, sprintf("variable_name IN (%s)", placeholders))
    params <- c(params, as.list(variables))
  }
  if (!is.null(datasets)) {
    placeholders <- paste(rep("?", length(datasets)), collapse = ", ")
    conditions <- c(conditions, sprintf("dataset_id IN (%s)", placeholders))
    params <- c(params, as.list(datasets))
  }

  if (length(conditions) > 0) {
    query <- paste(query, "WHERE", paste(conditions, collapse = " AND "))
  }

  # Get long format data
  long_data <- dbGetQuery(con, query, params = params)

  if (nrow(long_data) == 0) {
    return(data.frame())
  }

  # Pivot to wide format
  long_data %>%
    mutate(available = TRUE) %>%
    pivot_wider(
      names_from = dataset_id,
      values_from = available,
      values_fill = FALSE
    ) %>%
    arrange(variable_name)
}

#' Get database statistics
#' @param con DuckDB connection
#' @return Named list with counts
get_database_stats <- function(con) {
  list(
    variables = dbGetQuery(con, "SELECT COUNT(*) as n FROM variables")$n,
    datasets = dbGetQuery(con, "SELECT COUNT(*) as n FROM datasets")$n,
    availability_records = dbGetQuery(con, "SELECT COUNT(*) as n FROM variable_availability")$n,
    formats = dbGetQuery(con, "SELECT COUNT(DISTINCT format_name) as n FROM value_formats")$n,
    format_codes = dbGetQuery(con, "SELECT COUNT(*) as n FROM value_formats")$n
  )
}

# =============================================================================
# Export functions
# =============================================================================

#' Export availability matrix to CSV
#' @param con DuckDB connection
#' @param output_path Output CSV path
export_availability_csv <- function(con, output_path = "data/catalog/ices_cchs_availability_matrix.csv") {
  matrix <- get_availability_matrix(con)
  readr::write_csv(matrix, output_path)
  message("Exported availability matrix to: ", output_path)
}

#' Export to Parquet (for interoperability)
#' @param con DuckDB connection
#' @param output_dir Output directory
export_to_parquet <- function(con, output_dir = "data/ices_parquet") {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  dbExecute(con, sprintf("COPY variables TO '%s/variables.parquet' (FORMAT PARQUET)", output_dir))
  dbExecute(con, sprintf("COPY datasets TO '%s/datasets.parquet' (FORMAT PARQUET)", output_dir))
  dbExecute(con, sprintf("COPY variable_availability TO '%s/variable_availability.parquet' (FORMAT PARQUET)", output_dir))
  dbExecute(con, sprintf("COPY value_formats TO '%s/value_formats.parquet' (FORMAT PARQUET)", output_dir))

  message("Exported Parquet files to: ", output_dir)
}

# =============================================================================
# Interactive usage
# =============================================================================

if (interactive()) {
  message("ICES DuckDB Storage")
  message("===================")
  message("")
  message("Setup:")
  message("  con <- create_ices_database()       # Create new database")
  message("  con <- get_ices_connection()        # Connect to existing")
  message("")
  message("Insert data:")
  message("  insert_variable(con, variable_data)")
  message("  batch_insert_variables(con, results)")
  message("")
  message("Query:")
  message("  get_variable(con, 'ACC_10')")
  message("  get_dataset_variables(con, 'CCHS2009_ONT_SHARE')")
  message("  get_common_variables(con, c('CCHS2007_ONT_SHARE', 'CCHS2009_ONT_SHARE'))")
  message("  search_variables(con, 'SMKA%')")
  message("")
  message("Export:")
  message("  export_availability_csv(con)")
  message("  export_to_parquet(con)")
  message("")
  message("Don't forget: dbDisconnect(con) when done")
}
