# ingest_ddi_xml.R
# Phase 2: Ingest DDI XML files into variable_datasets and value_codes.
#
# Documentation enrichment: labels, question text, universe, response categories.
# DDI XML and PUMF RData are 1:1 aligned by cycle — same variable names.
# DDI rows are inserted as separate source_id='ddi_xml' entries alongside
# existing 'pumf_rdata' entries, preserving full provenance.
#
# For each of 11 DDI XML files:
#   1. Parse with xml2, namespace-aware XPath
#   2. Match to canonical dataset_id
#   3. Insert into variable_datasets (source_id = 'ddi_xml')
#   4. Insert categories into value_codes (source_id = 'ddi_xml')
#   5. Update variables table with DDI label and question_text
#   6. Record dataset_sources and dataset_aliases
#
# Usage: Called from database/build_db.R, or standalone:
#   Rscript --vanilla ingestion/ingest_ddi_xml.R

library(DBI)
library(duckdb)
library(xml2)

# DDI XML filename → canonical dataset_id mapping
DDI_DATASET_MAP <- list(
  "CCHS_2001_DDI.xml"      = "cchs-2001s-p-can",
  "CCHS_2003_DDI.xml"      = "cchs-2003s-p-can",
  "CCHS_2005_DDI.xml"      = "cchs-2005s-p-can",
  "CCHS_2007_2008_DDI.xml" = "cchs-2007d-p-can",
  "CCHS_2009_2010_DDI.xml" = "cchs-2009d-p-can",
  "CCHS_2011_2012_DDI.xml" = "cchs-2011d-p-can",
  "CCHS_2013_2014_DDI.xml" = "cchs-2013d-p-can",
  "CCHS_2015_2016_DDI.xml" = "cchs-2015d-p-can",
  "CCHS_2017_2018_DDI.xml" = "cchs-2017d-p-can",
  "CCHS_2019_2020_DDI.xml" = "cchs-2019d-p-can",
  "CCHS_2022_DDI.xml"      = "cchs-2022s-p-can"
)

# Escape single quotes for SQL
sql_escape <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return("NULL")
  paste0("'", gsub("'", "''", x), "'")
}

ingest_ddi_xml <- function(con, ddi_dir) {
  ddi_files <- list.files(ddi_dir, pattern = "_DDI[.]xml$", full.names = TRUE)
  cat("  Found", length(ddi_files), "DDI XML files\n")

  total_vd_inserted <- 0
  total_vc_inserted <- 0
  total_vars_updated <- 0
  total_new_vars <- 0

  for (fpath in sort(ddi_files)) {
    fname <- basename(fpath)
    dataset_id <- DDI_DATASET_MAP[[fname]]

    if (is.null(dataset_id)) {
      cat("  WARNING: No dataset mapping for", fname, "- skipping\n")
      next
    }

    cat(sprintf("\n  %s → %s\n", fname, dataset_id))

    # Verify dataset exists
    exists <- dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM datasets WHERE dataset_id = '", dataset_id, "'"
    ))$n
    if (exists == 0) {
      cat("    WARNING: dataset_id not found in datasets table - skipping\n")
      next
    }

    # Parse DDI XML
    doc <- tryCatch(read_xml(fpath), error = function(e) {
      cat("    ERROR: Invalid XML -", e$message, "\n")
      return(NULL)
    })
    if (is.null(doc)) next

    ns <- xml_ns(doc)
    vars <- xml_find_all(doc, ".//d1:var", ns)
    cat(sprintf("    %d variables in DDI\n", length(vars)))

    # Record dataset_sources
    invisible(dbExecute(con, paste0(
      "INSERT OR IGNORE INTO dataset_sources ",
      "(dataset_id, source_id, source_detail, first_seen, last_verified) ",
      "VALUES ('", dataset_id, "', 'ddi_xml', '", fname, "', ",
      "CURRENT_DATE, CURRENT_DATE)"
    )))

    # Record dataset alias (without _DDI.xml suffix)
    alias <- gsub("_DDI[.]xml$", "", fname)
    invisible(dbExecute(con, paste0(
      "INSERT OR IGNORE INTO dataset_aliases (alias, dataset_id, source_id) ",
      "VALUES ('", alias, "', '", dataset_id, "', 'ddi_xml')"
    )))

    file_vd <- 0
    file_vc <- 0

    for (v in vars) {
      var_name <- xml_attr(v, "name")
      if (is.na(var_name) || var_name == "") next

      # Extract metadata
      labl_node <- xml_find_first(v, ".//d1:labl", ns)
      label_en <- if (!is.na(labl_node)) trimws(xml_text(labl_node)) else NA_character_

      qstn_node <- xml_find_first(v, ".//d1:qstn/d1:qstnLit", ns)
      question_text <- if (!is.na(qstn_node)) trimws(xml_text(qstn_node)) else NA_character_

      univ_node <- xml_find_first(v, ".//d1:universe", ns)
      universe <- if (!is.na(univ_node)) trimws(xml_text(univ_node)) else NA_character_

      # Check if variable exists
      var_exists <- dbGetQuery(con, paste0(
        "SELECT COUNT(*) AS n FROM variables WHERE variable_name = '",
        gsub("'", "''", var_name), "'"
      ))$n

      if (var_exists == 0) {
        # DDI-only variable (not in ICES or RData)
        invisible(dbExecute(con, paste0(
          "INSERT INTO variables (variable_name, label_statcan, question_text, ",
          "universe, type, n_datasets, n_primary_sources, n_secondary_sources, ",
          "version, status, last_updated) ",
          "VALUES (", sql_escape(var_name), ", ", sql_escape(label_en), ", ",
          sql_escape(question_text), ", ", sql_escape(universe), ", ",
          "'ddi_variable', 0, 0, 0, 1, 'temp', CURRENT_DATE)"
        )))
        total_new_vars <- total_new_vars + 1
      } else {
        # Update existing variable with DDI metadata (DDI labels are richer)
        # Only update if DDI has data and existing field is empty
        updates <- character(0)
        if (!is.na(question_text) && question_text != "") {
          updates <- c(updates, paste0("question_text = ", sql_escape(question_text)))
        }
        if (!is.na(universe) && universe != "") {
          updates <- c(updates, paste0("universe = ", sql_escape(universe)))
        }
        # Update label_long with DDI label if not already set
        if (!is.na(label_en) && label_en != "") {
          updates <- c(updates, paste0(
            "label_long = CASE WHEN label_long IS NULL OR label_long = '' THEN ",
            sql_escape(label_en), " ELSE label_long END"
          ))
        }

        if (length(updates) > 0) {
          invisible(dbExecute(con, paste0(
            "UPDATE variables SET ", paste(updates, collapse = ", "),
            " WHERE variable_name = ", sql_escape(var_name)
          )))
          total_vars_updated <- total_vars_updated + 1
        }
      }

      # Insert into variable_datasets
      invisible(dbExecute(con, paste0(
        "INSERT OR IGNORE INTO variable_datasets ",
        "(variable_name, dataset_id, source_id, label, type, question_text, universe) ",
        "VALUES (", sql_escape(var_name), ", '", dataset_id, "', 'ddi_xml', ",
        sql_escape(label_en), ", 'ddi_variable', ",
        sql_escape(question_text), ", ", sql_escape(universe), ")"
      )))
      file_vd <- file_vd + 1

      # Insert value_codes from DDI categories
      cats <- xml_find_all(v, ".//d1:catgry", ns)
      if (length(cats) > 0) {
        for (cat in cats) {
          code_node <- xml_find_first(cat, ".//d1:catValu", ns)
          lbl_node <- xml_find_first(cat, ".//d1:labl", ns)

          code <- if (!is.na(code_node)) trimws(xml_text(code_node)) else NA_character_
          lbl <- if (!is.na(lbl_node)) trimws(xml_text(lbl_node)) else NA_character_

          if (!is.na(code) && code != "") {
            invisible(dbExecute(con, paste0(
              "INSERT OR IGNORE INTO value_codes ",
              "(variable_name, dataset_id, code, label, frequency, source_id) ",
              "VALUES (", sql_escape(var_name), ", '", dataset_id, "', ",
              sql_escape(code), ", ", sql_escape(lbl), ", NULL, 'ddi_xml')"
            )))
            file_vc <- file_vc + 1
          }
        }
      }
    }

    total_vd_inserted <- total_vd_inserted + file_vd
    total_vc_inserted <- total_vc_inserted + file_vc
    cat(sprintf("    %d variable-dataset links, %d value codes\n", file_vd, file_vc))
  }

  # Update n_datasets and n_primary_sources on variables
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

  # Compare RData vs DDI overlap
  cat("\n  === Phase 2 Summary ===\n")
  cat(sprintf("    Variable-dataset links:     %d\n", total_vd_inserted))
  cat(sprintf("    Value codes:                %d\n", total_vc_inserted))
  cat(sprintf("    Variables updated (DDI):     %d\n", total_vars_updated))
  cat(sprintf("    New variables (DDI-only):    %d\n", total_new_vars))

  # Overlap analysis
  cat("\n  === RData vs DDI overlap ===\n")
  overlap <- dbGetQuery(con, "
    SELECT
      COUNT(DISTINCT CASE WHEN source_id = 'pumf_rdata' THEN variable_name END) AS rdata_only_vars,
      COUNT(DISTINCT CASE WHEN source_id = 'ddi_xml' THEN variable_name END) AS ddi_only_vars,
      COUNT(DISTINCT variable_name) AS total_vars
    FROM variable_datasets
  ")

  both <- dbGetQuery(con, "
    SELECT COUNT(*) AS n FROM (
      SELECT variable_name, dataset_id
      FROM variable_datasets WHERE source_id = 'pumf_rdata'
      INTERSECT
      SELECT variable_name, dataset_id
      FROM variable_datasets WHERE source_id = 'ddi_xml'
    )
  ")$n

  rdata_total <- dbGetQuery(con, "
    SELECT COUNT(DISTINCT variable_name || '|' || dataset_id) AS n
    FROM variable_datasets WHERE source_id = 'pumf_rdata'
  ")$n

  ddi_total <- dbGetQuery(con, "
    SELECT COUNT(DISTINCT variable_name || '|' || dataset_id) AS n
    FROM variable_datasets WHERE source_id = 'ddi_xml'
  ")$n

  cat(sprintf("    RData variable-dataset pairs: %d\n", rdata_total))
  cat(sprintf("    DDI variable-dataset pairs:   %d\n", ddi_total))
  cat(sprintf("    In both (exact match):        %d\n", both))
  cat(sprintf("    RData-only:                   %d\n", rdata_total - both))
  cat(sprintf("    DDI-only:                     %d\n", ddi_total - both))

  if (rdata_total > 0) {
    cat(sprintf("    Match rate:                   %.1f%%\n",
                100 * both / max(rdata_total, ddi_total)))
  }
}

# If run standalone
if (!exists("con") || !dbIsValid(con)) {
  db_path <- "database/cchs_metadata.duckdb"
  ddi_dir <- "../cchsflow-data/ddi/"

  if (!file.exists(db_path)) {
    stop("Database not found. Run database/build_db.R first.")
  }
  if (!dir.exists(ddi_dir)) {
    stop("DDI directory not found: ", ddi_dir)
  }

  con <- dbConnect(duckdb(), db_path)
  on.exit(dbDisconnect(con, shutdown = TRUE))

  cat("Phase 2: DDI XML ingestion\n")
  ingest_ddi_xml(con, ddi_dir)
}
