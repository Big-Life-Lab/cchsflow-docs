# ingest_ddi_xml.R
# Phase 2: Ingest DDI XML files into variable_datasets, value_codes,
# variable_summary_stats, variable_groups, and variable_group_members.
#
# Documentation enrichment: labels, question text, universe, response
# categories with frequencies, summary statistics, measurement level,
# weight variable references, derivation notes, and module groups.
#
# DDI XML and PUMF RData are 1:1 aligned by cycle — same variable names.
# DDI rows are inserted as separate source_id='ddi_xml' entries alongside
# existing 'pumf_rdata' entries, preserving full provenance.
#
# For each of 11 DDI XML files:
#   1. Parse with xml2, namespace-aware XPath
#   2. Build ID-to-name lookup (DDI uses element IDs for cross-references)
#   3. Match to canonical dataset_id
#   4. Insert into variable_datasets with intrvl, wgt_var, notes
#   5. Insert categories into value_codes with weighted frequencies
#   6. Insert summary statistics into variable_summary_stats
#   7. Insert variable groups and memberships
#   8. Update variables table with DDI label and question_text
#   9. Record dataset_sources and dataset_aliases
#
# Usage: Called from database/build_db.R, or standalone:
#   Rscript --vanilla ingestion/ingest_ddi_xml.R

library(DBI)
library(duckdb)
library(xml2)

source("ingestion/normalise_text.R")

# DDI XML filename → canonical dataset_id mapping
DDI_DATASET_MAP <- list(
  "CCHS_2001_DDI.xml"      = "cchs-2001d-p-can",
  "CCHS_2003_DDI.xml"      = "cchs-2003d-p-can",
  "CCHS_2005_DDI.xml"      = "cchs-2005d-p-can",
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

# Safely parse a numeric value, returning NA on failure
safe_as_numeric <- function(x) {
  if (is.null(x) || is.na(x) || x == "" || x == ".") return(NA_real_)
  suppressWarnings(as.numeric(x))
}

safe_as_integer <- function(x) {
  if (is.null(x) || is.na(x) || x == "" || x == ".") return(NA_integer_)
  suppressWarnings(as.integer(x))
}

# Format a numeric for SQL (NULL if NA)
sql_num <- function(x) {
  if (is.na(x)) return("NULL")
  as.character(x)
}

ingest_ddi_xml <- function(con, ddi_dir) {
  ddi_files <- list.files(ddi_dir, pattern = "_DDI[.]xml$", full.names = TRUE)
  cat("  Found", length(ddi_files), "DDI XML files\n")

  total_vd_inserted <- 0
  total_vc_inserted <- 0
  total_vars_updated <- 0
  total_new_vars <- 0
  total_ss_inserted <- 0
  total_groups <- 0
  total_group_members <- 0

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

    # Build ID-to-name lookup (DDI uses element IDs for wgt-var and varGrp refs)
    id_to_name <- character(0)
    for (v in vars) {
      vid <- xml_attr(v, "ID")
      vname <- xml_attr(v, "name")
      if (!is.na(vid) && !is.na(vname)) {
        id_to_name[vid] <- vname
      }
    }

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
    file_ss <- 0

    for (v in vars) {
      var_name <- xml_attr(v, "name")
      if (is.na(var_name) || var_name == "") next

      # --- Extract core metadata ---
      labl_node <- xml_find_first(v, ".//d1:labl", ns)
      label_en <- if (!is.na(labl_node)) normalise_label(xml_text(labl_node)) else NA_character_

      qstn_node <- xml_find_first(v, ".//d1:qstn/d1:qstnLit", ns)
      question_text <- if (!is.na(qstn_node)) normalise_label(xml_text(qstn_node)) else NA_character_

      univ_node <- xml_find_first(v, ".//d1:universe", ns)
      universe <- if (!is.na(univ_node)) normalise_label(xml_text(univ_node)) else NA_character_

      # --- Extract new fields ---
      intrvl <- xml_attr(v, "intrvl")  # 'discrete' or 'contin'
      if (is.na(intrvl)) intrvl <- NA_character_

      # Weight variable: DDI stores as element ID reference, resolve to name
      wgt_var_id <- xml_attr(v, "wgt-var")
      wgt_var <- NA_character_
      if (!is.na(wgt_var_id) && wgt_var_id %in% names(id_to_name)) {
        wgt_var <- id_to_name[wgt_var_id]
      }

      # Notes: extract non-UNF notes (derivation info)
      note_nodes <- xml_find_all(v, ".//d1:notes", ns)
      var_notes <- NA_character_
      for (nn in note_nodes) {
        subj <- xml_attr(nn, "subject")
        if (is.na(subj) || subj != "Universal Numeric Fingerprint") {
          note_text <- trimws(xml_text(nn))
          if (!is.na(note_text) && note_text != "") {
            var_notes <- note_text
            break  # Take first non-UNF note
          }
        }
      }

      # varFormat type (numeric/character)
      fmt_node <- xml_find_first(v, ".//d1:varFormat", ns)
      var_format_type <- if (!is.na(fmt_node)) xml_attr(fmt_node, "type") else NA_character_

      # --- Upsert variable ---
      var_exists <- dbGetQuery(con, paste0(
        "SELECT COUNT(*) AS n FROM variables WHERE variable_name = '",
        gsub("'", "''", var_name), "'"
      ))$n

      if (var_exists == 0) {
        invisible(dbExecute(con, paste0(
          "INSERT INTO variables (variable_name, label_statcan, question_text, ",
          "universe, type, n_datasets, n_primary_sources, n_secondary_sources, ",
          "version, status, last_updated) ",
          "VALUES (", sql_escape(var_name), ", ", sql_escape(label_en), ", ",
          sql_escape(question_text), ", ", sql_escape(universe), ", ",
          sql_escape(var_format_type), ", 0, 0, 0, 1, 'temp', CURRENT_DATE)"
        )))
        total_new_vars <- total_new_vars + 1
      } else {
        updates <- character(0)
        if (!is.na(question_text) && question_text != "") {
          updates <- c(updates, paste0("question_text = ", sql_escape(question_text)))
        }
        if (!is.na(universe) && universe != "") {
          updates <- c(updates, paste0("universe = ", sql_escape(universe)))
        }
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

      # --- Insert into variable_datasets (with new columns) ---
      invisible(dbExecute(con, paste0(
        "INSERT OR IGNORE INTO variable_datasets ",
        "(variable_name, dataset_id, source_id, label, type, ",
        "question_text, universe, intrvl, wgt_var, notes) ",
        "VALUES (", sql_escape(var_name), ", '", dataset_id, "', 'ddi_xml', ",
        sql_escape(label_en), ", ", sql_escape(var_format_type), ", ",
        sql_escape(question_text), ", ", sql_escape(universe), ", ",
        sql_escape(intrvl), ", ", sql_escape(wgt_var), ", ",
        sql_escape(var_notes), ")"
      )))
      file_vd <- file_vd + 1

      # --- Insert value_codes with weighted frequencies ---
      cats <- xml_find_all(v, ".//d1:catgry", ns)
      if (length(cats) > 0) {
        for (cat_node in cats) {
          code_node <- xml_find_first(cat_node, ".//d1:catValu", ns)
          lbl_node <- xml_find_first(cat_node, ".//d1:labl", ns)

          code <- if (!is.na(code_node)) trimws(xml_text(code_node)) else NA_character_
          lbl <- if (!is.na(lbl_node)) normalise_label(xml_text(lbl_node)) else NA_character_

          if (!is.na(code) && code != "") {
            # Unweighted frequency
            freq_node <- xml_find_first(cat_node, ".//d1:catStat[@type='freq'][not(@wgtd)]", ns)
            freq <- NA_integer_
            if (!is.na(freq_node)) {
              freq <- safe_as_integer(xml_text(freq_node))
            }

            # Weighted frequency
            freq_wgt_node <- xml_find_first(cat_node, ".//d1:catStat[@wgtd='wgtd']", ns)
            freq_wgt <- NA_real_
            if (!is.na(freq_wgt_node)) {
              freq_wgt <- safe_as_numeric(xml_text(freq_wgt_node))
            }

            invisible(dbExecute(con, paste0(
              "INSERT OR IGNORE INTO value_codes ",
              "(variable_name, dataset_id, code, label, frequency, ",
              "frequency_weighted, source_id) ",
              "VALUES (", sql_escape(var_name), ", '", dataset_id, "', ",
              sql_escape(code), ", ", sql_escape(lbl), ", ",
              sql_num(freq), ", ", sql_num(freq_wgt), ", 'ddi_xml')"
            )))
            file_vc <- file_vc + 1
          }
        }
      }

      # --- Insert summary statistics ---
      sum_stats <- xml_find_all(v, ".//d1:sumStat", ns)
      if (length(sum_stats) > 0) {
        stat_vals <- list(
          mean = NA_real_, medn = NA_real_, mode = NA_character_,
          stdev = NA_real_, min = NA_real_, max = NA_real_,
          vald = NA_integer_, invd = NA_integer_
        )

        for (ss in sum_stats) {
          stat_type <- xml_attr(ss, "type")
          stat_text <- trimws(xml_text(ss))
          if (!is.na(stat_type) && !is.na(stat_text) && stat_text != "") {
            if (stat_type == "mode") {
              stat_vals[["mode"]] <- stat_text
            } else if (stat_type %in% c("vald", "invd")) {
              stat_vals[[stat_type]] <- safe_as_integer(stat_text)
            } else if (stat_type %in% names(stat_vals)) {
              stat_vals[[stat_type]] <- safe_as_numeric(stat_text)
            }
          }
        }

        # Only insert if we have at least one non-NA stat
        has_data <- !is.na(stat_vals$mean) || !is.na(stat_vals$medn) ||
                    !is.na(stat_vals$stdev) || !is.na(stat_vals$vald)
        if (has_data) {
          invisible(dbExecute(con, paste0(
            "INSERT OR IGNORE INTO variable_summary_stats ",
            "(variable_name, dataset_id, stat_mean, stat_median, stat_mode, ",
            "stat_stdev, stat_min, stat_max, n_valid, n_invalid, source_id) ",
            "VALUES (", sql_escape(var_name), ", '", dataset_id, "', ",
            sql_num(stat_vals$mean), ", ", sql_num(stat_vals$medn), ", ",
            sql_escape(stat_vals$mode), ", ",
            sql_num(stat_vals$stdev), ", ", sql_num(stat_vals$min), ", ",
            sql_num(stat_vals$max), ", ",
            sql_num(stat_vals$vald), ", ", sql_num(stat_vals$invd), ", ",
            "'ddi_xml')"
          )))
          file_ss <- file_ss + 1
        }
      }
    }

    total_vd_inserted <- total_vd_inserted + file_vd
    total_vc_inserted <- total_vc_inserted + file_vc
    total_ss_inserted <- total_ss_inserted + file_ss
    cat(sprintf("    %d variable-dataset links, %d value codes, %d summary stats\n",
                file_vd, file_vc, file_ss))

    # --- Insert variable groups ---
    var_groups <- xml_find_all(doc, ".//d1:varGrp", ns)
    if (length(var_groups) > 0) {
      file_groups <- 0
      file_members <- 0

      for (grp in var_groups) {
        grp_labl_node <- xml_find_first(grp, ".//d1:labl", ns)
        grp_label_raw <- if (!is.na(grp_labl_node)) trimws(xml_text(grp_labl_node)) else NA_character_
        if (is.na(grp_label_raw) || grp_label_raw == "") next

        # Parse "CODE: Label" format
        if (grepl("^[A-Z0-9]+:", grp_label_raw)) {
          parts <- regmatches(grp_label_raw,
                              regexec("^([A-Z0-9]+):\\s*(.+)$", grp_label_raw))[[1]]
          grp_code <- parts[2]
          grp_label <- trimws(parts[3])
        } else {
          grp_code <- gsub("[^A-Z0-9]", "", toupper(substr(grp_label_raw, 1, 3)))
          grp_label <- grp_label_raw
        }

        group_id <- paste0(dataset_id, "::", grp_code)

        invisible(dbExecute(con, paste0(
          "INSERT OR IGNORE INTO variable_groups ",
          "(group_id, dataset_id, group_code, group_label, source_id) ",
          "VALUES (", sql_escape(group_id), ", '", dataset_id, "', ",
          sql_escape(grp_code), ", ", sql_escape(grp_label), ", 'ddi_xml')"
        )))
        file_groups <- file_groups + 1

        # Resolve var ID references to names and insert members
        var_refs <- xml_attr(grp, "var")
        if (!is.na(var_refs) && var_refs != "") {
          ref_ids <- strsplit(var_refs, "\\s+")[[1]]
          for (ref_id in ref_ids) {
            member_name <- id_to_name[ref_id]
            if (!is.na(member_name)) {
              invisible(dbExecute(con, paste0(
                "INSERT OR IGNORE INTO variable_group_members ",
                "(group_id, variable_name) ",
                "VALUES (", sql_escape(group_id), ", ",
                sql_escape(member_name), ")"
              )))
              file_members <- file_members + 1
            }
          }
        }
      }

      total_groups <- total_groups + file_groups
      total_group_members <- total_group_members + file_members
      cat(sprintf("    %d groups, %d group memberships\n", file_groups, file_members))
    }
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
  cat(sprintf("    Summary statistics:         %d\n", total_ss_inserted))
  cat(sprintf("    Variable groups:            %d\n", total_groups))
  cat(sprintf("    Group memberships:          %d\n", total_group_members))
  cat(sprintf("    Variables updated (DDI):     %d\n", total_vars_updated))
  cat(sprintf("    New variables (DDI-only):    %d\n", total_new_vars))

  # Overlap analysis
  cat("\n  === RData vs DDI overlap ===\n")

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
