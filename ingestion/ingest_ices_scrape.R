# ingest_ices_scrape.R
# Migrate ICES Data Dictionary DuckDB into the unified metadata database.
# Parses dataset_id into cycle and file_type columns.

library(DBI)
library(duckdb)

source_db_path <- "data/ices_cchs_dictionary.duckdb"
target_db_path <- "database/cchs_metadata.duckdb"
schema_path <- "database/schema.sql"

# --- Helper: parse dataset_id into cycle and file_type ---
parse_dataset_id <- function(dataset_id) {
  # Extract cycle years from the leading CCHS prefix
  # Patterns: CCHS2001_, CCHS200708_, CCHS201516_, CCHS2000_
  cycle_raw <- sub("^CCHS(\\d{4,6})_.*", "\\1", dataset_id)

  # Convert to human-readable cycle
  cycle <- vapply(cycle_raw, function(x) {
    if (nchar(x) == 4) {
      x  # Single year: "2001"
    } else if (nchar(x) == 6) {
      # Dual year: "200708" -> "2007-2008"
      paste0(substr(x, 1, 4), "-", "20", substr(x, 5, 6))
    } else {
      x
    }
  }, character(1), USE.NAMES = FALSE)

  # Classify file type from the rest of the dataset_id
  file_type <- vapply(dataset_id, function(id) {
    id_upper <- toupper(id)
    if (grepl("PUBLIC|PUMF", id_upper)) {
      "PUMF"
    } else if (grepl("LINKED|LINK_IKN|_LINK", id_upper) && !grepl("INC_IMP_LINK", id_upper)) {
      "Linked"
    } else if (grepl("SHARE", id_upper)) {
      "Share"
    } else if (grepl("BOOT", id_upper)) {
      "Bootstrap"
    } else if (grepl("INC_", id_upper)) {
      "Income"
    } else if (grepl("_HA$|_HA_|_MH$|_MH_|_RFH_", id_upper)) {
      "Focused"
    } else {
      "Other"
    }
  }, character(1), USE.NAMES = FALSE)

  data.frame(cycle = cycle, file_type = file_type, stringsAsFactors = FALSE)
}

# --- Connect to source ---
cat("Reading from:", source_db_path, "\n")
src_con <- dbConnect(duckdb(), source_db_path, read_only = TRUE)

datasets <- dbGetQuery(src_con, "SELECT * FROM datasets")
variables <- dbGetQuery(src_con, "SELECT * FROM variables")
variable_availability <- dbGetQuery(src_con, "SELECT * FROM variable_availability")
value_formats <- dbGetQuery(src_con, "SELECT * FROM value_formats")
catalog_metadata <- dbGetQuery(src_con, "SELECT * FROM catalog_metadata")

dbDisconnect(src_con)

cat("Source tables read:\n")
cat("  datasets:", nrow(datasets), "\n")
cat("  variables:", nrow(variables), "\n")
cat("  variable_availability:", nrow(variable_availability), "\n")
cat("  value_formats:", nrow(value_formats), "\n")
cat("  catalog_metadata:", nrow(catalog_metadata), "\n\n")

# --- Parse cycle and file_type ---
parsed <- parse_dataset_id(datasets$dataset_id)
datasets$cycle <- parsed$cycle
datasets$file_type <- parsed$file_type

cat("File type distribution:\n")
print(table(datasets$file_type))
cat("\nCycle distribution:\n")
print(table(datasets$cycle))

# --- Rename variables columns to match unified schema ---
names(variables)[names(variables) == "available_in_count"] <- "dataset_count"
# Drop raw columns not in unified schema
variables$values_raw <- NULL
variables$available_in_raw <- NULL

# --- Write to target ---
if (file.exists(target_db_path)) {
  file.remove(target_db_path)
}

cat("\nWriting to:", target_db_path, "\n")
tgt_con <- dbConnect(duckdb(), target_db_path)

# Apply schema
schema_sql <- readLines(schema_path)
schema_sql <- paste(schema_sql, collapse = "\n")
# Split on semicolons and execute each statement
statements <- strsplit(schema_sql, ";")[[1]]
statements <- trimws(statements)
statements <- statements[nchar(statements) > 0]
# Filter out comment-only statements
statements <- statements[!grepl("^\\s*--", statements)]
for (stmt in statements) {
  # Skip if only whitespace/comments remain after removing comment lines
  clean <- gsub("--[^\n]*", "", stmt)
  clean <- trimws(clean)
  if (nchar(clean) > 0) {
    tryCatch(
      dbExecute(tgt_con, paste0(stmt, ";")),
      error = function(e) cat("Warning on statement:", substr(stmt, 1, 60), "\n  ", e$message, "\n")
    )
  }
}

# Write data
dbWriteTable(tgt_con, "datasets", datasets[, c("dataset_id", "cycle", "file_type", "variable_count")],
             overwrite = TRUE)
dbWriteTable(tgt_con, "variables", variables[, c("variable_name", "label", "type", "format", "dataset_count")],
             overwrite = TRUE)
dbWriteTable(tgt_con, "variable_availability", variable_availability, overwrite = TRUE)
dbWriteTable(tgt_con, "value_formats", value_formats, overwrite = TRUE)
dbWriteTable(tgt_con, "catalog_metadata", catalog_metadata, overwrite = TRUE)

# Re-create tables that dbWriteTable didn't touch (they were dropped by schema re-init)
dbExecute(tgt_con, "
CREATE TABLE IF NOT EXISTS ddi_variables (
    variable_name VARCHAR,
    dataset_id VARCHAR,
    label_en VARCHAR,
    question_text VARCHAR,
    universe_logic VARCHAR,
    notes VARCHAR,
    categories_json VARCHAR,
    source_filename VARCHAR,
    PRIMARY KEY (variable_name, dataset_id)
);")

dbExecute(tgt_con, "
CREATE TABLE IF NOT EXISTS ontology_concepts (
    concept_id VARCHAR PRIMARY KEY,
    preferred_label VARCHAR,
    description VARCHAR
);")

dbExecute(tgt_con, "
CREATE TABLE IF NOT EXISTS variable_concepts (
    variable_name VARCHAR,
    concept_id VARCHAR,
    match_confidence FLOAT DEFAULT 1.0,
    match_source VARCHAR,
    PRIMARY KEY (variable_name, concept_id)
);")

# Create views
dbExecute(tgt_con, "
CREATE OR REPLACE VIEW v_variable_detail AS
SELECT
    v.variable_name, v.label, v.type, v.format,
    d.question_text, d.universe_logic, d.categories_json,
    ds.cycle, ds.file_type,
    va.dataset_id
FROM variables v
JOIN variable_availability va ON v.variable_name = va.variable_name
JOIN datasets ds ON va.dataset_id = ds.dataset_id
LEFT JOIN ddi_variables d
    ON v.variable_name = d.variable_name
    AND va.dataset_id = d.dataset_id;
")

dbExecute(tgt_con, "
CREATE OR REPLACE VIEW v_variable_history AS
SELECT
    v.variable_name, v.label,
    ds.cycle, ds.file_type, ds.dataset_id,
    d.question_text
FROM variables v
JOIN variable_availability va ON v.variable_name = va.variable_name
JOIN datasets ds ON va.dataset_id = ds.dataset_id
LEFT JOIN ddi_variables d
    ON v.variable_name = d.variable_name
    AND va.dataset_id = d.dataset_id
ORDER BY v.variable_name, ds.cycle;
")

# --- Verify ---
cat("\nVerification:\n")
for (tbl in c("datasets", "variables", "variable_availability", "value_formats", "catalog_metadata")) {
  n <- dbGetQuery(tgt_con, paste0("SELECT COUNT(*) as n FROM ", tbl))$n
  cat("  ", tbl, ":", n, "\n")
}

# Test a view query
cat("\n  v_variable_detail sample:\n")
sample <- dbGetQuery(tgt_con, "SELECT * FROM v_variable_detail WHERE variable_name = 'SMKDSTY' LIMIT 3")
print(sample)

# Test cycle parsing
cat("\n  Cycle parsing sample:\n")
sample_ds <- dbGetQuery(tgt_con, "SELECT dataset_id, cycle, file_type FROM datasets WHERE dataset_id LIKE '%201516%'")
print(sample_ds)

dbDisconnect(tgt_con)
cat("\nDone.\n")
