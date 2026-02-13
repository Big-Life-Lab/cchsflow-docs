# ingest_ddi_xml.R
# Parse DDI XML files and load into ddi_variables table of unified database.

library(DBI)
library(duckdb)
library(xml2)
library(jsonlite)

db_path <- "database/cchs_metadata.duckdb"
ddi_dir <- "ddi-xml"

# --- DDI XML filename to dataset mapping ---
# Maps each DDI file to a dataset_id and cycle.
# Where a PUMF dataset already exists in the ICES data, we use that ID.
# Otherwise we create a new dataset_id following the same convention.
ddi_file_map <- data.frame(
  filename = c(
    "cchs-82M0013-E-2001-c1-1-general-file.xml",
    "cchs-82M0013-E-2003-c2-1-GeneralFile.xml",
    "cchs-82M0013-E-2005-c3-1-main-file.xml",
    "cchs-82M0013-E-2005-ss1.xml",
    "cchs-E-2007-2008-AnnualComponent.xml",
    "cchs-5146-E-2008-2009-HealthyAging.xml",
    "CCHS-82M0013-E-2009-2010-Annualcomponent.xml",
    "CCHS_2010_DDI.xml",
    "cchs-82M0013-E-2011-2012-Annual-component.xml",
    "CCHS_2012_DDI.xml",
    "CCHS-82M0013-E-2013-2014-Annual.xml",
    "CCHS_2014_DDI.xml",
    "cchs-82M0013-E-2015-2016-Annual-component.xml",
    "cchs-82M0013-E-2017-2018-Annual-component.xml"
  ),
  dataset_id = c(
    "CCHS2001_PUBLIC_11",
    "CCHS2003_PUMF_21",
    "CCHS2005_PUMF_31",
    "CCHS2005_PUMF_SS1",
    "CCHS200708_PUMF",
    "CCHS200809_HA_PUMF",
    "CCHS200910_PUMF",
    "CCHS2010_PUMF",
    "CCHS201112_CCHS_PUMF",
    "CCHS2012_CCHS_PUMF",
    "CCHS201314_CCHS_PUMF",
    "CCHS2014_CCHS_PUMF",
    "CCHS201516_PUMF",
    "CCHS201718_PUMF"
  ),
  cycle = c(
    "2001", "2003", "2005", "2005",
    "2007-2008", "2008-2009", "2009-2010", "2010",
    "2011-2012", "2012", "2013-2014", "2014",
    "2015-2016", "2017-2018"
  ),
  stringsAsFactors = FALSE
)

# --- Parse one DDI XML file ---
parse_ddi_file <- function(filepath, dataset_id) {
  doc <- read_xml(filepath)
  ns <- xml_ns(doc)

  vars <- xml_find_all(doc, ".//d1:var", ns)
  cat("  Parsing", basename(filepath), ":", length(vars), "variables\n")

  records <- lapply(vars, function(v) {
    vname <- xml_attr(v, "name")
    labl_node <- xml_find_first(v, ".//d1:labl", ns)
    label_en <- if (!is.na(labl_node)) trimws(xml_text(labl_node)) else NA_character_

    # Question text
    qstn_node <- xml_find_first(v, ".//d1:qstn/d1:qstnLit", ns)
    question_text <- if (!is.na(qstn_node)) trimws(xml_text(qstn_node)) else NA_character_

    # Universe
    univ_node <- xml_find_first(v, ".//d1:universe", ns)
    universe_logic <- if (!is.na(univ_node)) trimws(xml_text(univ_node)) else NA_character_

    # Notes
    notes_nodes <- xml_find_all(v, ".//d1:notes", ns)
    notes <- if (length(notes_nodes) > 0) {
      trimws(paste(xml_text(notes_nodes), collapse = " | "))
    } else {
      NA_character_
    }

    # Categories as JSON
    cats <- xml_find_all(v, ".//d1:catgry", ns)
    if (length(cats) > 0) {
      cat_list <- lapply(cats, function(cat) {
        code <- xml_text(xml_find_first(cat, ".//d1:catValu", ns))
        lbl <- xml_text(xml_find_first(cat, ".//d1:labl", ns))
        list(code = trimws(code), label = trimws(lbl))
      })
      categories_json <- toJSON(cat_list, auto_unbox = TRUE)
    } else {
      categories_json <- NA_character_
    }

    data.frame(
      variable_name = vname,
      dataset_id = dataset_id,
      label_en = label_en,
      question_text = question_text,
      universe_logic = universe_logic,
      notes = notes,
      categories_json = categories_json,
      source_filename = basename(filepath),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, records)
}

# --- Main ---
con <- dbConnect(duckdb(), db_path)

# Get existing datasets for matching
existing_ds <- dbGetQuery(con, "SELECT dataset_id FROM datasets")$dataset_id

cat("Parsing", nrow(ddi_file_map), "DDI XML files...\n\n")

all_ddi <- list()
new_datasets <- list()

for (i in seq_len(nrow(ddi_file_map))) {
  filepath <- file.path(ddi_dir, ddi_file_map$filename[i])
  dsid <- ddi_file_map$dataset_id[i]
  cycle <- ddi_file_map$cycle[i]

  if (!file.exists(filepath)) {
    cat("  MISSING:", filepath, "\n")
    next
  }

  # Skip files that aren't valid XML (some are GitHub HTML pages)
  parsed <- tryCatch(
    parse_ddi_file(filepath, dsid),
    error = function(e) {
      cat("  SKIPPING (invalid XML):", basename(filepath), "-", e$message, "\n")
      NULL
    }
  )
  if (is.null(parsed)) next
  all_ddi[[i]] <- parsed

  # Track new datasets not in ICES data
  if (!(dsid %in% existing_ds)) {
    new_datasets[[dsid]] <- data.frame(
      dataset_id = dsid,
      cycle = cycle,
      file_type = "PUMF",
      variable_count = nrow(parsed),
      stringsAsFactors = FALSE
    )
  }
}

ddi_df <- do.call(rbind, all_ddi)

cat("\nTotal DDI records:", nrow(ddi_df), "\n")
cat("Unique variables:", length(unique(ddi_df$variable_name)), "\n")
cat("With question text:", sum(!is.na(ddi_df$question_text)), "\n")
cat("With universe logic:", sum(!is.na(ddi_df$universe_logic)), "\n")
cat("With categories:", sum(!is.na(ddi_df$categories_json)), "\n")

# --- Insert new PUMF datasets not already in ICES data ---
if (length(new_datasets) > 0) {
  new_ds_df <- do.call(rbind, new_datasets)
  cat("\nAdding", nrow(new_ds_df), "new PUMF datasets:\n")
  print(new_ds_df)

  for (j in seq_len(nrow(new_ds_df))) {
    dbExecute(con, "INSERT INTO datasets VALUES (?, ?, ?, ?)",
              params = list(new_ds_df$dataset_id[j], new_ds_df$cycle[j],
                           new_ds_df$file_type[j], new_ds_df$variable_count[j]))
  }
}

# --- Load into ddi_variables ---
dbExecute(con, "DELETE FROM ddi_variables")  # Clear any previous data
dbWriteTable(con, "ddi_variables", ddi_df, append = TRUE)

# --- Match report ---
ices_vars <- dbGetQuery(con, "SELECT DISTINCT variable_name FROM variables")$variable_name
ddi_vars <- unique(ddi_df$variable_name)

matched <- sum(ddi_vars %in% ices_vars)
unmatched <- sum(!(ddi_vars %in% ices_vars))

cat("\nMatch report:\n")
cat("  DDI variables:", length(ddi_vars), "\n")
cat("  Matched to ICES:", matched, "(", round(100 * matched / length(ddi_vars), 1), "%)\n")
cat("  DDI-only (not in ICES):", unmatched, "\n")

if (unmatched > 0) {
  ddi_only <- ddi_vars[!(ddi_vars %in% ices_vars)]
  cat("  Sample unmatched:", paste(head(ddi_only, 10), collapse = ", "), "\n")
}

# --- Verify ---
cat("\nVerification:\n")
n <- dbGetQuery(con, "SELECT COUNT(*) as n FROM ddi_variables")$n
cat("  ddi_variables rows:", n, "\n")

# Test enriched view
cat("\n  Enriched SMKDSTY sample:\n")
sample <- dbGetQuery(con, "
  SELECT variable_name, cycle, file_type, question_text, dataset_id
  FROM v_variable_detail
  WHERE variable_name = 'SMKDSTY' AND question_text IS NOT NULL
  LIMIT 3
")
print(sample)

dbDisconnect(con)
cat("\nDone.\n")
