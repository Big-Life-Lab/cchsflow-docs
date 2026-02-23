# build_db.R
# Master build script for the unified CCHS metadata database v2.
#
# Three-tier architecture:
#   CSV (source of truth) → DuckDB (queryable) → MCP server (tools)
#
# Phase 0: Create fresh DuckDB, apply schema, load CSVs
# Phase 1: Ingest PUMF RData
# Phase 2: Ingest DDI XML
# Phase 2.5: Ingest Master PDF Data Dictionary (2022, 2023)
# Phase 3: Ingest 613apps Master + PUMF data
# Phase 4: Validate merge (future)
#
# Usage: Rscript --vanilla database/build_db.R

library(DBI)
library(duckdb)

db_path <- "database/cchs_metadata.duckdb"
schema_path <- "database/schema.sql"
version <- trimws(readLines("VERSION", n = 1, warn = FALSE))

cat(sprintf("=== Building CCHS Unified Metadata Database v%s ===\n\n", version))

# ------------------------------------------------------------------
# Phase 0: Fresh database from schema + CSVs
# ------------------------------------------------------------------
cat("Phase 0: Create database and load CSVs\n")

# Remove old database
if (file.exists(db_path)) {
  file.remove(db_path)
  cat("  Removed existing database\n")
}

con <- dbConnect(duckdb(), db_path)

# Apply schema (DuckDB handles multi-statement SQL)
cat("  Applying schema...\n")
schema_sql <- paste(readLines(schema_path, warn = FALSE), collapse = "\n")
invisible(dbExecute(con, schema_sql))
cat("  Schema applied\n")

# Load CSVs into tables
load_csv <- function(con, csv_path, table_name) {
  df <- read.csv(csv_path, stringsAsFactors = FALSE, na.strings = "")

  # Get target table column names and types
  table_cols <- dbGetQuery(con, paste0(
    "SELECT column_name, data_type FROM information_schema.columns ",
    "WHERE table_name = '", table_name, "' ORDER BY ordinal_position"
  ))

  # Only keep CSV columns that exist in the table
  common_cols <- intersect(names(df), table_cols$column_name)
  df <- df[, common_cols, drop = FALSE]

  # Coerce types to match schema
  for (col in common_cols) {
    col_type <- table_cols$data_type[table_cols$column_name == col]
    if (grepl("INTEGER", col_type, ignore.case = TRUE)) {
      df[[col]] <- as.integer(df[[col]])
    } else if (grepl("DATE", col_type, ignore.case = TRUE)) {
      df[[col]] <- as.Date(df[[col]])
    }
  }

  dbWriteTable(con, table_name, df, append = TRUE)
  n <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", table_name))$n
  cat("  Loaded", csv_path, "→", table_name, "(", n, "rows )\n")
}

load_csv(con, "data/sources.csv", "sources")
load_csv(con, "data/datasets.csv", "datasets")
load_csv(con, "data/variables.csv", "variables")

# Seed dataset_sources from what we know
cat("\n  Seeding dataset_sources...\n")

# ICES-sourced datasets
n_ices <- dbExecute(con, "
  INSERT INTO dataset_sources (dataset_id, source_id, source_detail, first_seen, last_verified)
  SELECT dataset_id, 'ices_scrape', 'ices_cchs_dictionary.duckdb',
         CURRENT_DATE, CURRENT_DATE
  FROM datasets
  WHERE ices_id IS NOT NULL AND ices_id != ''
")
cat("    ICES scrape:", n_ices, "datasets\n")

# PUMF RData datasets (the 8 we added with no ices_id, plus any with matching RData files)
# For now, seed the 8 new ones
n_pumf <- dbExecute(con, "
  INSERT INTO dataset_sources (dataset_id, source_id, source_detail, first_seen, last_verified)
  SELECT dataset_id, 'pumf_rdata', 'pending_ingestion',
         CURRENT_DATE, CURRENT_DATE
  FROM datasets
  WHERE (ices_id IS NULL OR ices_id = '')
    AND release = 'pumf'
")
cat("    PUMF RData:", n_pumf, "datasets\n")

# Seed dataset_aliases from ices_id
n_aliases <- dbExecute(con, "
  INSERT INTO dataset_aliases (alias, dataset_id, source_id)
  SELECT ices_id, dataset_id, 'ices_scrape'
  FROM datasets
  WHERE ices_id IS NOT NULL AND ices_id != ''
")
cat("    ICES aliases:", n_aliases, "\n")

# Seed dataset_aliases for 613apps (cycle-survey aliases)
# 613apps uses cycle identifiers: version IDs for pre-2009 (1.1, 2.1, 3.1, 4.1)
# and year ranges for post-2009 (2009-2010, 2015-2016, 2023)
# Master cycles map to the main Master dataset for that cycle;
# PUMF cycles map to the main PUMF dataset.
apps_alias_sql <- "
  INSERT INTO dataset_aliases (alias, dataset_id, source_id) VALUES
  -- PUMF aliases (613apps pumf scrapes -> canonical PUMF datasets)
  ('pumf_1.1',       'cchs-2001d-p-can', '613apps'),
  ('pumf_2.1',       'cchs-2003d-p-can', '613apps'),
  ('pumf_3.1',       'cchs-2005d-p-can', '613apps'),
  ('pumf_4.1',       'cchs-2007d-p-can', '613apps'),
  ('pumf_2009-2010', 'cchs-2009d-p-can', '613apps'),
  ('pumf_2011-2012', 'cchs-2011d-p-can', '613apps'),
  ('pumf_2013-2014', 'cchs-2013d-p-can', '613apps'),
  ('pumf_2015-2016', 'cchs-2015d-p-can', '613apps'),
  ('pumf_2017-2018', 'cchs-2017d-p-can', '613apps'),
  -- Master aliases (613apps master scrapes -> canonical Master datasets)
  ('master_1.1',       'cchs-2001d-m-can', '613apps'),
  ('master_2.1',       'cchs-2003d-m-can', '613apps'),
  ('master_3.1',       'cchs-2005d-m-can', '613apps'),
  ('master_4.1',       'cchs-2007d-m-can', '613apps'),
  ('master_2009-2010', 'cchs-2009d-m-can', '613apps'),
  ('master_2011-2012', 'cchs-2011d-m-can', '613apps'),
  ('master_2013-2014', 'cchs-2013d-m-can', '613apps'),
  ('master_2015-2016', 'cchs-2015d-m-can', '613apps'),
  ('master_2017-2018', 'cchs-2017d-m-can', '613apps'),
  ('master_2019-2020', 'cchs-2019d-m-can', '613apps'),
  ('master_2021',      'cchs-2021s-m-can', '613apps'),
  ('master_2022',      'cchs-2022s-m-can', '613apps'),
  ('master_2023',      'cchs-2023s-m-can', '613apps')
"
n_apps_aliases <- dbExecute(con, apps_alias_sql)
cat("    613apps aliases:", n_apps_aliases, "\n")

# Seed dataset_sources for 613apps (which datasets have 613apps scrape data)
apps_sources_sql <- "
  INSERT INTO dataset_sources (dataset_id, source_id, source_detail, first_seen, last_verified)
  SELECT dataset_id, '613apps', alias || '.csv', CURRENT_DATE, CURRENT_DATE
  FROM dataset_aliases
  WHERE source_id = '613apps'
"
n_apps_sources <- dbExecute(con, apps_sources_sql)
cat("    613apps dataset_sources:", n_apps_sources, "\n")

# Write build metadata
invisible(dbExecute(con, "INSERT INTO catalog_metadata VALUES ('schema_version', '2.0.0')"))
invisible(dbExecute(con, paste0("INSERT INTO catalog_metadata VALUES ('version', '", version, "')")))
invisible(dbExecute(con, paste0("INSERT INTO catalog_metadata VALUES ('build_date', '",
                                 Sys.Date(), "')")))
invisible(dbExecute(con, paste0("INSERT INTO catalog_metadata VALUES ('build_r_version', '",
                                 R.version.string, "')")))

# Summary
cat("\n  === Phase 0 Summary ===\n")
tables <- dbGetQuery(con, "
  SELECT table_name,
         (SELECT COUNT(*) FROM information_schema.columns c
          WHERE c.table_name = t.table_name) AS n_cols
  FROM information_schema.tables t
  WHERE table_schema = 'main' AND table_type = 'BASE TABLE'
  ORDER BY table_name
")

for (i in seq_len(nrow(tables))) {
  tbl <- tables$table_name[i]
  n <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
  cat(sprintf("    %-25s %6d rows  (%d cols)\n", tbl, n, tables$n_cols[i]))
}

# ------------------------------------------------------------------
# Phase 1: PUMF RData ingestion
# ------------------------------------------------------------------
rdata_dir <- "../cchsflow-data/data/sources/rdata/"

if (dir.exists(rdata_dir)) {
  cat("\n\nPhase 1: PUMF RData ingestion\n")
  source("ingestion/ingest_pumf_rdata.R")
  ingest_pumf_rdata(con, rdata_dir)
} else {
  cat("\n\nPhase 1: SKIPPED (RData directory not found:", rdata_dir, ")\n")
}

# ------------------------------------------------------------------
# Phase 2: DDI XML ingestion
# ------------------------------------------------------------------
ddi_dir <- "../cchsflow-data/ddi/"

if (dir.exists(ddi_dir)) {
  cat("\n\nPhase 2: DDI XML ingestion\n")
  source("ingestion/ingest_ddi_xml.R")
  ingest_ddi_xml(con, ddi_dir)
} else {
  cat("\n\nPhase 2: SKIPPED (DDI directory not found:", ddi_dir, ")\n")
}

# ------------------------------------------------------------------
# Phase 2.5: Master PDF Data Dictionary ingestion
# ------------------------------------------------------------------
master_dd_dir <- "data/sources/master-pdf-dd/"

if (dir.exists(master_dd_dir) &&
    length(list.files(master_dd_dir, pattern = "_master_dd\\.csv$")) > 0) {
  cat("\n\nPhase 2.5: Master PDF Data Dictionary ingestion\n")
  source("ingestion/ingest_master_pdf_dd.R")
  ingest_master_pdf_dd(con, master_dd_dir)
} else {
  cat("\n\nPhase 2.5: SKIPPED (Master DD CSVs not found in:", master_dd_dir, ")\n")
}

# ------------------------------------------------------------------
# Phase 3: 613apps Master + PUMF ingestion
# ------------------------------------------------------------------
apps_dir <- "data/sources/613apps/parsed/"

if (dir.exists(apps_dir) &&
    file.exists(file.path(apps_dir, "613apps_variables.csv"))) {
  cat("\n\nPhase 3: 613apps Master + PUMF ingestion\n")
  source("ingestion/ingest_613apps.R")
  ingest_613apps(con, apps_dir)
} else {
  cat("\n\nPhase 3: SKIPPED (613apps parsed CSVs not found in:", apps_dir, ")\n")
}

# ------------------------------------------------------------------
# Update status based on source attestation
# ------------------------------------------------------------------
cat("\n\nUpdating variable status...\n")

# Variables with at least one primary source → active
n_active <- dbExecute(con, "
  UPDATE variables SET status = 'active'
  WHERE n_primary_sources > 0 AND status = 'temp'
")
cat("  Variables → active (primary source):", n_active, "\n")

# Variables with only secondary sources → temp (unchanged)
n_temp <- dbGetQuery(con, "
  SELECT COUNT(*) AS n FROM variables
  WHERE n_primary_sources = 0 AND status = 'temp'
")$n
cat("  Variables remaining temp (secondary only):", n_temp, "\n")

# ------------------------------------------------------------------
# Final summary
# ------------------------------------------------------------------
cat("\n\n=== Final Summary ===\n")
tables <- dbGetQuery(con, "
  SELECT table_name,
         (SELECT COUNT(*) FROM information_schema.columns c
          WHERE c.table_name = t.table_name) AS n_cols
  FROM information_schema.tables t
  WHERE table_schema = 'main' AND table_type = 'BASE TABLE'
  ORDER BY table_name
")

for (i in seq_len(nrow(tables))) {
  tbl <- tables$table_name[i]
  n <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
  cat(sprintf("    %-25s %6d rows  (%d cols)\n", tbl, n, tables$n_cols[i]))
}

dbDisconnect(con, shutdown = TRUE)

cat("\n=== Build complete ===\n")
cat("Database:", db_path, "\n")
cat("\nNext phases (not yet implemented):\n")
cat("  Phase 4: Validate merge\n")
