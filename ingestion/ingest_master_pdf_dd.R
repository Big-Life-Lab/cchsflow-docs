# ingest_master_pdf_dd.R
# Phase 2.5: Ingest Master PDF Data Dictionary CSVs into DuckDB.
#
# Source: StatCan Master File Data Dictionary PDFs (2022, 2023), extracted
# to YAML via scripts/extract_data_dictionary.R, then converted to CSV
# via scripts/yaml_dd_to_csv.py.
#
# For each year (2022, 2023):
#   1. Read variable metadata and value codes CSVs
#   2. Insert new variables into variables table (Master-only vars not in ICES/PUMF)
#   3. Insert into variable_datasets (source_id = 'master_pdf_dd')
#   4. Insert value codes into value_codes (source_id = 'master_pdf_dd')
#   5. Update dataset_sources with actual filenames
#   6. Update aggregate counts on variables and datasets tables
#
# Usage: Called from database/build_db.R, or standalone:
#   Rscript --vanilla ingestion/ingest_master_pdf_dd.R

library(DBI)
library(duckdb)

source("ingestion/normalise_text.R")

# CSV filename prefix → canonical dataset_id mapping
MASTER_DD_MAP <- list(
  list(year = 2022, dataset_id = "cchs-2022s-m-can",
       var_csv = "cchs_2022_master_dd.csv",
       cat_csv = "cchs_2022_master_dd_categories.csv"),
  list(year = 2023, dataset_id = "cchs-2023s-m-can",
       var_csv = "cchs_2023_master_dd.csv",
       cat_csv = "cchs_2023_master_dd_categories.csv")
)

ingest_master_pdf_dd <- function(con, data_dir) {
  total_vars_inserted <- 0
  total_vd_inserted <- 0
  total_vc_inserted <- 0
  new_variables <- character(0)

  for (entry in MASTER_DD_MAP) {
    year <- entry$year
    dataset_id <- entry$dataset_id
    var_csv_path <- file.path(data_dir, entry$var_csv)
    cat_csv_path <- file.path(data_dir, entry$cat_csv)

    cat(sprintf("\n  %d → %s\n", year, dataset_id))

    # Check files exist
    if (!file.exists(var_csv_path)) {
      cat("    WARNING:", var_csv_path, "not found - skipping\n")
      next
    }
    if (!file.exists(cat_csv_path)) {
      cat("    WARNING:", cat_csv_path, "not found - skipping\n")
      next
    }

    # Verify dataset exists in DB
    exists <- dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM datasets WHERE dataset_id = '", dataset_id, "'"
    ))$n
    if (exists == 0) {
      cat("    WARNING: dataset_id not found in datasets table - skipping\n")
      next
    }

    # Read CSVs
    vars_df <- read.csv(var_csv_path, stringsAsFactors = FALSE, na.strings = "")
    cats_df <- read.csv(cat_csv_path, stringsAsFactors = FALSE, na.strings = "")

    cat(sprintf("    %d variables, %d value codes from CSVs\n",
                nrow(vars_df), nrow(cats_df)))

    # Normalise text fields
    vars_df$label <- normalise_label(vars_df$label)
    vars_df$question_text <- normalise_label(vars_df$question_text)
    vars_df$universe <- normalise_label(vars_df$universe)
    cats_df$label <- normalise_label(cats_df$label)

    # Update dataset_sources
    invisible(dbExecute(con, paste0(
      "INSERT OR IGNORE INTO dataset_sources ",
      "(dataset_id, source_id, source_detail, first_seen, last_verified) ",
      "VALUES ('", dataset_id, "', 'master_pdf_dd', '", entry$var_csv, "', ",
      "CURRENT_DATE, CURRENT_DATE)"
    )))

    # Process each variable
    for (i in seq_len(nrow(vars_df))) {
      var_name <- vars_df$variable_name[i]
      label <- vars_df$label[i]
      question_text <- vars_df$question_text[i]
      universe <- vars_df$universe[i]
      note <- vars_df$note[i]
      position <- vars_df$position[i]
      length_val <- vars_df$length[i]

      # SQL-safe strings
      var_name_sql <- gsub("'", "''", var_name)

      # Insert variable if not already in variables table
      var_exists <- dbGetQuery(con, paste0(
        "SELECT COUNT(*) AS n FROM variables WHERE variable_name = '",
        var_name_sql, "'"
      ))$n

      if (var_exists == 0) {
        label_sql <- if (is.na(label)) "NULL" else
          paste0("'", gsub("'", "''", label), "'")
        invisible(dbExecute(con, paste0(
          "INSERT INTO variables (variable_name, label_statcan, ",
          "n_datasets, n_primary_sources, n_secondary_sources, ",
          "version, status, last_updated) ",
          "VALUES ('", var_name_sql, "', ", label_sql, ", ",
          "0, 0, 0, 1, 'temp', CURRENT_DATE)"
        )))
        total_vars_inserted <- total_vars_inserted + 1
        new_variables <- c(new_variables, var_name)
      }

      # Build SQL values for variable_datasets columns
      label_sql <- if (is.na(label)) "NULL" else
        paste0("'", gsub("'", "''", label), "'")
      qt_sql <- if (is.na(question_text)) "NULL" else
        paste0("'", gsub("'", "''", question_text), "'")
      univ_sql <- if (is.na(universe)) "NULL" else
        paste0("'", gsub("'", "''", universe), "'")
      notes_sql <- if (is.na(note)) "NULL" else
        paste0("'", gsub("'", "''", note), "'")

      # Position and length: parse as integer (they may be "8.0" strings)
      pos_int <- if (is.na(position)) "NULL" else {
        p <- suppressWarnings(as.integer(as.numeric(position)))
        if (is.na(p)) "NULL" else as.character(p)
      }
      len_int <- if (is.na(length_val)) "NULL" else {
        l <- suppressWarnings(as.integer(as.numeric(length_val)))
        if (is.na(l)) "NULL" else as.character(l)
      }

      # Insert into variable_datasets
      invisible(dbExecute(con, paste0(
        "INSERT OR IGNORE INTO variable_datasets ",
        "(variable_name, dataset_id, source_id, label, position, length, ",
        "question_text, universe, notes) ",
        "VALUES ('", var_name_sql, "', '", dataset_id, "', 'master_pdf_dd', ",
        label_sql, ", ", pos_int, ", ", len_int, ", ",
        qt_sql, ", ", univ_sql, ", ", notes_sql, ")"
      )))
      total_vd_inserted <- total_vd_inserted + 1
    }

    # Insert value codes (no frequencies — Master frequencies are restricted)
    for (j in seq_len(nrow(cats_df))) {
      var_name <- cats_df$variable_name[j]
      code <- cats_df$code[j]
      label <- cats_df$label[j]

      var_name_sql <- gsub("'", "''", var_name)
      code_str <- as.character(code)
      code_sql <- gsub("'", "''", code_str)
      label_sql <- if (is.na(label)) "NULL" else
        paste0("'", gsub("'", "''", label), "'")

      # Detect range codes: "NNN-NNN" or "N.N-N.N"
      range_match <- regmatches(code_str, regexec("^(\\d+\\.?\\d*)\\s*-\\s*(\\d+\\.?\\d*)$", code_str))[[1]]
      if (length(range_match) == 3) {
        is_range_sql <- "TRUE"
        range_low_sql <- range_match[2]
        range_high_sql <- range_match[3]
      } else {
        is_range_sql <- "FALSE"
        range_low_sql <- "NULL"
        range_high_sql <- "NULL"
      }

      invisible(dbExecute(con, paste0(
        "INSERT OR IGNORE INTO value_codes ",
        "(variable_name, dataset_id, code, label, ",
        "is_range, range_low, range_high, source_id) ",
        "VALUES ('", var_name_sql, "', '", dataset_id, "', ",
        "'", code_sql, "', ", label_sql, ", ",
        is_range_sql, ", ", range_low_sql, ", ", range_high_sql, ", ",
        "'master_pdf_dd')"
      )))
      total_vc_inserted <- total_vc_inserted + 1
    }

    cat(sprintf("    Inserted %d variable-dataset links, %d value codes\n",
                nrow(vars_df), nrow(cats_df)))
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

  # Update n_primary_sources for variables
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

  cat(sprintf("\n  === Phase 2.5 Summary ===\n"))
  cat(sprintf("    New variables (Master-only):   %d\n", total_vars_inserted))
  cat(sprintf("    Variable-dataset links:        %d\n", total_vd_inserted))
  cat(sprintf("    Value codes:                   %d\n", total_vc_inserted))

  if (length(new_variables) > 0 && length(new_variables) <= 20) {
    cat("    New variable names:", paste(new_variables, collapse = ", "), "\n")
  } else if (length(new_variables) > 20) {
    cat("    New variable names (first 20):", paste(head(new_variables, 20), collapse = ", "), "...\n")
  }
}

# If run standalone
if (!exists("con") || !dbIsValid(con)) {
  db_path <- "database/cchs_metadata.duckdb"
  data_dir <- "data/sources/master-pdf-dd/"

  if (!file.exists(db_path)) {
    stop("Database not found. Run database/build_db.R first.")
  }
  if (!dir.exists(data_dir)) {
    stop("Master PDF DD directory not found: ", data_dir)
  }

  con <- dbConnect(duckdb(), db_path)
  on.exit(dbDisconnect(con, shutdown = TRUE))

  cat("Phase 2.5: Master PDF Data Dictionary ingestion\n")
  ingest_master_pdf_dd(con, data_dir)
}
