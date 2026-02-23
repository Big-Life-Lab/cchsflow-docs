# ingest_pumf_rdata.R
# Phase 1: Ingest PUMF RData files into variable_datasets and value_codes.
#
# Ground truth source: actual variable names, R types, factor levels.
# Expects Phase 0 (build_db.R) to have already loaded CSVs into DuckDB.
#
# For each of 11 RData files:
#   1. Load into new.env(), extract column metadata
#   2. Insert new variables into variables table (PUMF-only vars not in ICES)
#   3. Insert into variable_datasets (source_id = 'pumf_rdata')
#   4. Insert factor levels into value_codes (source_id = 'pumf_rdata')
#   5. Update dataset_sources with actual filename
#   6. Insert RData filename as dataset_alias
#
# Usage: Called from database/build_db.R, or standalone:
#   Rscript --vanilla ingestion/ingest_pumf_rdata.R

library(DBI)
library(duckdb)

source("ingestion/normalise_text.R")

# RData filename → canonical dataset_id mapping
RDATA_DATASET_MAP <- list(
  "CCHS_2001.RData"      = "cchs-2001d-p-can",
  "CCHS_2003.RData"      = "cchs-2003d-p-can",
  "CCHS_2005.RData"      = "cchs-2005d-p-can",
  "CCHS_2007_2008.RData" = "cchs-2007d-p-can",
  "CCHS_2009_2010.RData" = "cchs-2009d-p-can",
  "CCHS_2011_2012.RData" = "cchs-2011d-p-can",
  "CCHS_2013_2014.RData" = "cchs-2013d-p-can",
  "CCHS_2015_2016.RData" = "cchs-2015d-p-can",
  "CCHS_2017_2018.RData" = "cchs-2017d-p-can",
  "CCHS_2019_2020.RData" = "cchs-2019d-p-can",
  "CCHS_2022.RData"      = "cchs-2022s-p-can"
)

ingest_pumf_rdata <- function(con, rdata_dir) {
  rdata_files <- list.files(rdata_dir, pattern = "[.]RData$", full.names = TRUE)
  cat("  Found", length(rdata_files), "RData files\n")

  total_vars_inserted <- 0
  total_vd_inserted <- 0
  total_vc_inserted <- 0
  new_variables <- character(0)

  for (fpath in sort(rdata_files)) {
    fname <- basename(fpath)
    dataset_id <- RDATA_DATASET_MAP[[fname]]

    if (is.null(dataset_id)) {
      cat("  WARNING: No dataset mapping for", fname, "- skipping\n")
      next
    }

    cat(sprintf("\n  %s → %s\n", fname, dataset_id))

    # Verify dataset exists in DB
    exists <- dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM datasets WHERE dataset_id = '", dataset_id, "'"
    ))$n
    if (exists == 0) {
      cat("    WARNING: dataset_id not found in datasets table - skipping\n")
      next
    }

    # Load RData into isolated environment
    env <- new.env()
    load(fpath, envir = env)
    obj_name <- ls(env)[1]
    df <- get(obj_name, envir = env)

    n_vars <- ncol(df)
    n_rows <- nrow(df)
    cat(sprintf("    %d variables, %d respondents\n", n_vars, n_rows))

    # Update dataset_sources with actual filename
    invisible(dbExecute(con, paste0(
      "DELETE FROM dataset_sources ",
      "WHERE dataset_id = '", dataset_id, "' ",
      "AND source_id = 'pumf_rdata' AND source_detail = 'pending_ingestion'"
    )))
    invisible(dbExecute(con, paste0(
      "INSERT OR IGNORE INTO dataset_sources ",
      "(dataset_id, source_id, source_detail, first_seen, last_verified) ",
      "VALUES ('", dataset_id, "', 'pumf_rdata', '", fname, "', ",
      "CURRENT_DATE, CURRENT_DATE)"
    )))

    # Insert RData filename as alias
    invisible(dbExecute(con, paste0(
      "INSERT OR IGNORE INTO dataset_aliases (alias, dataset_id, source_id) ",
      "VALUES ('", gsub(".RData$", "", fname), "', '", dataset_id, "', 'pumf_rdata')"
    )))

    # Process each column
    col_names <- names(df)
    for (i in seq_along(col_names)) {
      var_name <- col_names[i]
      col <- df[[i]]
      r_class <- class(col)[1]  # 'haven_labelled', 'numeric', 'character', etc.

      # Extract haven_labelled attributes
      var_label <- attr(col, "label")     # variable label (e.g., "Province - (G)")
      if (!is.null(var_label)) var_label <- normalise_label(var_label)
      value_labels <- attr(col, "labels") # named numeric vector (label = code)
      if (!is.null(value_labels)) names(value_labels) <- normalise_label(names(value_labels))

      # Insert variable if not already in variables table
      var_exists <- dbGetQuery(con, paste0(
        "SELECT COUNT(*) AS n FROM variables WHERE variable_name = '",
        gsub("'", "''", var_name), "'"
      ))$n

      if (var_exists == 0) {
        label_sql <- if (is.null(var_label) || is.na(var_label)) "NULL" else
          paste0("'", gsub("'", "''", var_label), "'")
        invisible(dbExecute(con, paste0(
          "INSERT INTO variables (variable_name, label_statcan, type, ",
          "n_datasets, n_primary_sources, n_secondary_sources, ",
          "version, status, last_updated) ",
          "VALUES ('", gsub("'", "''", var_name), "', ", label_sql, ", '",
          r_class, "', 0, 0, 0, 1, 'temp', CURRENT_DATE)"
        )))
        total_vars_inserted <- total_vars_inserted + 1
        new_variables <- c(new_variables, var_name)
      }

      # Insert into variable_datasets with the variable label from this file
      label_sql <- if (is.null(var_label) || is.na(var_label)) "NULL" else
        paste0("'", gsub("'", "''", var_label), "'")
      invisible(dbExecute(con, paste0(
        "INSERT OR IGNORE INTO variable_datasets ",
        "(variable_name, dataset_id, source_id, label, type) ",
        "VALUES ('", gsub("'", "''", var_name), "', '", dataset_id, "', 'pumf_rdata', ",
        label_sql, ", '", r_class, "')"
      )))
      total_vd_inserted <- total_vd_inserted + 1

      # Insert value_codes from haven value labels
      if (!is.null(value_labels) && length(value_labels) > 0) {
        # value_labels is a named vector: names are labels, values are codes
        # e.g., c("NEWFOUNDLAND" = 10, "PEI" = 11, ...)
        # Get frequency counts
        freq_table <- table(col, useNA = "no")

        for (j in seq_along(value_labels)) {
          code <- as.character(value_labels[j])
          label <- names(value_labels)[j]
          freq <- as.integer(freq_table[code])
          if (is.na(freq)) freq <- 0

          invisible(dbExecute(con, paste0(
            "INSERT OR IGNORE INTO value_codes ",
            "(variable_name, dataset_id, code, label, frequency, source_id) ",
            "VALUES ('", gsub("'", "''", var_name), "', '", dataset_id, "', ",
            "'", gsub("'", "''", code), "', '", gsub("'", "''", label), "', ",
            freq, ", 'pumf_rdata')"
          )))
          total_vc_inserted <- total_vc_inserted + 1
        }
      }
    }

    # Update n_respondents on dataset (if column exists)
    # The schema doesn't have n_respondents but we could add to notes
    cat(sprintf("    Inserted %d variable-dataset links\n", n_vars))

    # Clean up
    rm(env, df)
  }

  # Update n_datasets counts on variables table
  cat("\n  Updating variable counts...\n")
  invisible(dbExecute(con, "
    UPDATE variables SET n_datasets = sub.n
    FROM (
      SELECT variable_name, COUNT(DISTINCT dataset_id) AS n
      FROM variable_datasets
      GROUP BY variable_name
    ) AS sub
    WHERE variables.variable_name = sub.variable_name
  "))

  # Update n_primary_sources for variables that appear in pumf_rdata
  invisible(dbExecute(con, "
    UPDATE variables SET n_primary_sources = sub.n
    FROM (
      SELECT vd.variable_name, COUNT(DISTINCT vd.source_id) AS n
      FROM variable_datasets vd
      JOIN sources s ON vd.source_id = s.source_id
      WHERE s.authority = 'primary'
      GROUP BY vd.variable_name
    ) AS sub
    WHERE variables.variable_name = sub.variable_name
  "))

  # Update dataset n_primary_sources
  invisible(dbExecute(con, "
    UPDATE datasets SET n_primary_sources = sub.n
    FROM (
      SELECT ds.dataset_id, COUNT(DISTINCT ds.source_id) AS n
      FROM dataset_sources ds
      JOIN sources s ON ds.source_id = s.source_id
      WHERE s.authority = 'primary'
      GROUP BY ds.dataset_id
    ) AS sub
    WHERE datasets.dataset_id = sub.dataset_id
  "))

  cat(sprintf("\n  === Phase 1 Summary ===\n"))
  cat(sprintf("    New variables (PUMF-only):  %d\n", total_vars_inserted))
  cat(sprintf("    Variable-dataset links:     %d\n", total_vd_inserted))
  cat(sprintf("    Value codes:                %d\n", total_vc_inserted))

  if (length(new_variables) > 0 && length(new_variables) <= 20) {
    cat("    New variable names:", paste(head(new_variables, 20), collapse = ", "), "\n")
  } else if (length(new_variables) > 20) {
    cat("    New variable names (first 20):", paste(head(new_variables, 20), collapse = ", "), "...\n")
  }
}

# If run standalone
if (!exists("con") || !dbIsValid(con)) {
  db_path <- "database/cchs_metadata.duckdb"
  rdata_dir <- "../cchsflow-data/data/sources/rdata/"

  if (!file.exists(db_path)) {
    stop("Database not found. Run database/build_db.R first.")
  }
  if (!dir.exists(rdata_dir)) {
    stop("RData directory not found: ", rdata_dir)
  }

  con <- dbConnect(duckdb(), db_path)
  on.exit(dbDisconnect(con, shutdown = TRUE))

  cat("Phase 1: PUMF RData ingestion\n")
  ingest_pumf_rdata(con, rdata_dir)
}
