# ingest_613apps.R
# Phase 3: Ingest 613apps Master + PUMF variable data into DuckDB.
#
# Source: 613apps.ca CCHS Data Dictionary Builder (Playwright scrape),
# parsed via scraping/613apps/parse_613apps.py into two CSVs:
#   - 613apps_variables.csv  (56,104 rows)
#   - 613apps_value_codes.csv (379,327 rows)
#
# This script:
#   1. Reads parsed CSVs and maps survey+cycle to canonical dataset_ids
#   2. Strips surrounding single-quote wrapping from pre-2015 labels
#   3. Inserts new variables (Master-only) into variables table
#   4. Batch inserts variable_datasets (source_id = '613apps')
#   5. Batch inserts value_codes (source_id = '613apps')
#   6. Updates aggregate counts (n_datasets, n_primary/secondary_sources)
#
# Usage: Called from database/build_db.R, or standalone:
#   Rscript --vanilla ingestion/ingest_613apps.R

library(DBI)
library(duckdb)

# Alias map: survey_cycle → canonical dataset_id
# Must match the aliases seeded in build_db.R
ALIAS_MAP <- c(
  "pumf_1.1"       = "cchs-2001d-p-can",
  "pumf_2.1"       = "cchs-2003d-p-can",
  "pumf_3.1"       = "cchs-2005d-p-can",
  "pumf_4.1"       = "cchs-2007d-p-can",
  "pumf_2009-2010" = "cchs-2009d-p-can",
  "pumf_2011-2012" = "cchs-2011d-p-can",
  "pumf_2013-2014" = "cchs-2013d-p-can",
  "pumf_2015-2016" = "cchs-2015d-p-can",
  "pumf_2017-2018" = "cchs-2017d-p-can",
  "master_1.1"       = "cchs-2001d-m-can",
  "master_2.1"       = "cchs-2003d-m-can",
  "master_3.1"       = "cchs-2005d-m-can",
  "master_4.1"       = "cchs-2007d-m-can",
  "master_2009-2010" = "cchs-2009d-m-can",
  "master_2011-2012" = "cchs-2011d-m-can",
  "master_2013-2014" = "cchs-2013d-m-can",
  "master_2015-2016" = "cchs-2015d-m-can",
  "master_2017-2018" = "cchs-2017d-m-can",
  "master_2019-2020" = "cchs-2019d-m-can",
  "master_2021"      = "cchs-2021s-m-can",
  "master_2022"      = "cchs-2022s-m-can",
  "master_2023"      = "cchs-2023s-m-can"
)

# Strip surrounding single quotes and unescape doubled quotes.
# Pre-2015 613apps labels are wrapped: 'DON''T KNOW' → DON'T KNOW
# Post-2015 labels have no wrapping (this is a no-op for them).
strip_quotes <- function(x) {
  out <- x
  has_quotes <- !is.na(out) & nchar(out) >= 2 &
    startsWith(out, "'") & endsWith(out, "'")
  out[has_quotes] <- substr(out[has_quotes], 2, nchar(out[has_quotes]) - 1)
  out[has_quotes] <- gsub("''", "'", out[has_quotes], fixed = TRUE)
  out
}

ingest_613apps <- function(con, data_dir) {

  var_csv <- file.path(data_dir, "613apps_variables.csv")
  codes_csv <- file.path(data_dir, "613apps_value_codes.csv")

  if (!file.exists(var_csv)) stop("Not found: ", var_csv)
  if (!file.exists(codes_csv)) stop("Not found: ", codes_csv)

  # ------------------------------------------------------------------
  # Step 1: Read CSVs and map to canonical dataset_ids
  # ------------------------------------------------------------------
  cat("  Reading CSVs...\n")
  vars_df <- read.csv(var_csv, stringsAsFactors = FALSE, na.strings = "")
  codes_df <- read.csv(codes_csv, stringsAsFactors = FALSE, na.strings = "")

  cat(sprintf("    Variables CSV:   %d rows\n", nrow(vars_df)))
  cat(sprintf("    Value codes CSV: %d rows\n", nrow(codes_df)))

  # Build alias key and map to dataset_id
  vars_df$alias_key <- paste0(vars_df$survey, "_", vars_df$file_cycle)
  vars_df$dataset_id <- ALIAS_MAP[vars_df$alias_key]

  codes_df$alias_key <- paste0(codes_df$survey, "_", codes_df$file_cycle)
  codes_df$dataset_id <- ALIAS_MAP[codes_df$alias_key]

  # Filter out unmapped rows
  n_unmapped_vars <- sum(is.na(vars_df$dataset_id))
  n_unmapped_codes <- sum(is.na(codes_df$dataset_id))
  if (n_unmapped_vars > 0) {
    unmapped <- unique(vars_df$alias_key[is.na(vars_df$dataset_id)])
    cat(sprintf("    WARNING: %d variable rows unmapped: %s\n",
                n_unmapped_vars, paste(unmapped, collapse = ", ")))
    vars_df <- vars_df[!is.na(vars_df$dataset_id), ]
  }
  if (n_unmapped_codes > 0) {
    codes_df <- codes_df[!is.na(codes_df$dataset_id), ]
  }

  # ------------------------------------------------------------------
  # Step 2: Clean labels (strip quote wrapping)
  # ------------------------------------------------------------------
  cat("  Cleaning labels...\n")
  vars_df$label <- strip_quotes(vars_df$label)
  codes_df$code_label <- strip_quotes(codes_df$code_label)

  # ------------------------------------------------------------------
  # Step 3: Insert new variables into variables table
  # ------------------------------------------------------------------
  cat("  Checking for new variables...\n")
  existing_vars <- dbGetQuery(con,
    "SELECT variable_name FROM variables"
  )$variable_name

  new_var_names <- setdiff(unique(vars_df$variable_name), existing_vars)
  cat(sprintf("    %d new variables to insert\n", length(new_var_names)))

  if (length(new_var_names) > 0) {
    # Get the best label for each new variable (first non-NA)
    new_vars_data <- do.call(rbind, lapply(new_var_names, function(vn) {
      rows <- vars_df[vars_df$variable_name == vn, ]
      label <- rows$label[!is.na(rows$label)][1]
      data.frame(
        variable_name = vn,
        label_statcan = if (is.na(label)) NA_character_ else label,
        n_datasets = 0L,
        n_primary_sources = 0L,
        n_secondary_sources = 0L,
        version = 1L,
        status = "temp",
        last_updated = as.character(Sys.Date()),
        stringsAsFactors = FALSE
      )
    }))

    dbWriteTable(con, "stg_new_vars", new_vars_data, overwrite = TRUE)
    n_inserted <- dbExecute(con, "
      INSERT INTO variables
        (variable_name, label_statcan, n_datasets, n_primary_sources,
         n_secondary_sources, version, status, last_updated)
      SELECT variable_name, label_statcan, n_datasets, n_primary_sources,
             n_secondary_sources, version, status, CAST(last_updated AS DATE)
      FROM stg_new_vars
    ")
    dbExecute(con, "DROP TABLE stg_new_vars")
    cat(sprintf("    Inserted %d new variables\n", n_inserted))
  }

  # ------------------------------------------------------------------
  # Step 4: Batch insert variable_datasets
  # ------------------------------------------------------------------
  cat("  Inserting variable_datasets...\n")

  # Build notes column: file_code + format_code metadata
  notes_parts <- character(nrow(vars_df))
  for (i in seq_len(nrow(vars_df))) {
    parts <- c()
    if (!is.na(vars_df$file_code[i]) && vars_df$file_code[i] != "") {
      parts <- c(parts, paste0("file_code=", vars_df$file_code[i]))
    }
    if (!is.na(vars_df$format_code[i]) && vars_df$format_code[i] != "") {
      parts <- c(parts, paste0("format_code=", vars_df$format_code[i]))
    }
    notes_parts[i] <- if (length(parts) > 0) paste(parts, collapse = "; ") else NA_character_
  }

  vd_df <- data.frame(
    variable_name = vars_df$variable_name,
    dataset_id    = vars_df$dataset_id,
    source_id     = "613apps",
    label         = vars_df$label,
    notes         = notes_parts,
    stringsAsFactors = FALSE
  )

  dbWriteTable(con, "stg_vd", vd_df, overwrite = TRUE)
  n_vd <- dbExecute(con, "
    INSERT OR IGNORE INTO variable_datasets
      (variable_name, dataset_id, source_id, label, notes)
    SELECT variable_name, dataset_id, source_id, label, notes
    FROM stg_vd
  ")
  dbExecute(con, "DROP TABLE stg_vd")
  cat(sprintf("    Inserted %d variable_datasets rows\n", n_vd))

  # Per-dataset breakdown
  vd_counts <- dbGetQuery(con, "
    SELECT dataset_id, COUNT(*) AS n
    FROM variable_datasets
    WHERE source_id = '613apps'
    GROUP BY dataset_id
    ORDER BY dataset_id
  ")
  for (i in seq_len(nrow(vd_counts))) {
    cat(sprintf("      %-25s %5d\n", vd_counts$dataset_id[i], vd_counts$n[i]))
  }

  # ------------------------------------------------------------------
  # Step 5: Batch insert value_codes
  # ------------------------------------------------------------------
  cat("  Inserting value_codes...\n")

  vc_df <- data.frame(
    variable_name = codes_df$variable_name,
    dataset_id    = codes_df$dataset_id,
    code          = as.character(codes_df$code),
    label         = codes_df$code_label,
    source_id     = "613apps",
    stringsAsFactors = FALSE
  )

  dbWriteTable(con, "stg_vc", vc_df, overwrite = TRUE)
  n_vc <- dbExecute(con, "
    INSERT OR IGNORE INTO value_codes
      (variable_name, dataset_id, code, label, source_id)
    SELECT variable_name, dataset_id, code, label, source_id
    FROM stg_vc
  ")
  dbExecute(con, "DROP TABLE stg_vc")
  cat(sprintf("    Inserted %d value_codes rows\n", n_vc))

  # ------------------------------------------------------------------
  # Step 6: Update aggregate counts
  # ------------------------------------------------------------------
  cat("  Updating aggregate counts...\n")

  # variables.n_datasets
  dbExecute(con, "
    UPDATE variables SET n_datasets = sub.n
    FROM (
      SELECT variable_name, COUNT(DISTINCT dataset_id) AS n
      FROM variable_datasets
      GROUP BY variable_name
    ) AS sub
    WHERE variables.variable_name = sub.variable_name
  ")

  # variables.n_primary_sources
  dbExecute(con, "
    UPDATE variables SET n_primary_sources = sub.n
    FROM (
      SELECT vd.variable_name, COUNT(DISTINCT vd.source_id) AS n
      FROM variable_datasets vd
      JOIN sources s ON vd.source_id = s.source_id
      WHERE s.authority = 'primary'
      GROUP BY vd.variable_name
    ) AS sub
    WHERE variables.variable_name = sub.variable_name
  ")

  # variables.n_secondary_sources
  dbExecute(con, "
    UPDATE variables SET n_secondary_sources = sub.n
    FROM (
      SELECT vd.variable_name, COUNT(DISTINCT vd.source_id) AS n
      FROM variable_datasets vd
      JOIN sources s ON vd.source_id = s.source_id
      WHERE s.authority = 'secondary'
      GROUP BY vd.variable_name
    ) AS sub
    WHERE variables.variable_name = sub.variable_name
  ")

  # datasets.n_primary_sources
  dbExecute(con, "
    UPDATE datasets SET n_primary_sources = sub.n
    FROM (
      SELECT ds.dataset_id, COUNT(DISTINCT ds.source_id) AS n
      FROM dataset_sources ds
      JOIN sources s ON ds.source_id = s.source_id
      WHERE s.authority = 'primary'
      GROUP BY ds.dataset_id
    ) AS sub
    WHERE datasets.dataset_id = sub.dataset_id
  ")

  # datasets.n_secondary_sources
  dbExecute(con, "
    UPDATE datasets SET n_secondary_sources = sub.n
    FROM (
      SELECT ds.dataset_id, COUNT(DISTINCT ds.source_id) AS n
      FROM dataset_sources ds
      JOIN sources s ON ds.source_id = s.source_id
      WHERE s.authority = 'secondary'
      GROUP BY ds.dataset_id
    ) AS sub
    WHERE datasets.dataset_id = sub.dataset_id
  ")

  cat("  Counts updated\n")

  # ------------------------------------------------------------------
  # Summary
  # ------------------------------------------------------------------
  cat(sprintf("\n  === Phase 3 Summary ===\n"))
  cat(sprintf("    New variables:          %d\n", length(new_var_names)))
  cat(sprintf("    variable_datasets:      %d\n", n_vd))
  cat(sprintf("    value_codes:            %d\n", n_vc))

  # Overlap analysis: how many PUMF variables have 3 sources now?
  overlap <- dbGetQuery(con, "
    SELECT vd.dataset_id,
           COUNT(DISTINCT vd.variable_name) AS n_vars,
           COUNT(DISTINCT vd.source_id) AS n_sources
    FROM variable_datasets vd
    JOIN datasets d ON vd.dataset_id = d.dataset_id
    WHERE d.release = 'pumf'
    GROUP BY vd.dataset_id
    ORDER BY vd.dataset_id
  ")
  cat("\n    PUMF datasets with multi-source coverage:\n")
  for (i in seq_len(nrow(overlap))) {
    cat(sprintf("      %-25s %5d vars, %d sources\n",
                overlap$dataset_id[i], overlap$n_vars[i], overlap$n_sources[i]))
  }
}

# If run standalone
if (!exists("con") || !dbIsValid(con)) {
  db_path <- "database/cchs_metadata.duckdb"
  data_dir <- "data/sources/613apps/parsed/"

  if (!file.exists(db_path)) {
    stop("Database not found. Run database/build_db.R first.")
  }
  if (!dir.exists(data_dir)) {
    stop("613apps parsed directory not found: ", data_dir)
  }

  con <- dbConnect(duckdb(), db_path)
  on.exit(dbDisconnect(con, shutdown = TRUE))

  cat("Phase 3: 613apps Master + PUMF ingestion\n")
  ingest_613apps(con, data_dir)
}
