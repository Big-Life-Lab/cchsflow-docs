# backup_to_gdrive.R
# Back up source CSVs and DuckDB to Google Drive before changes.
#
# Uploads to shared drive: cchsflow (0AMZr2JC1NGt7Uk9PVA)
# Folder structure: backups/v{VERSION}/{date}/
#
# Usage:
#   Rscript --vanilla scripts/backup_to_gdrive.R           # back up everything
#   Rscript --vanilla scripts/backup_to_gdrive.R --dry-run  # show what would upload

library(googledrive)

# --- Configuration ---
SHARED_DRIVE_ID <- "0AMZr2JC1NGt7Uk9PVA"
AUTH_EMAIL <- "dmanuel@biglifelab.org"

# Files to back up (relative to repo root)
BACKUP_FILES <- c(
  "data/sources.csv",
  "data/datasets.csv",
  "data/variables.csv",
  "data/sources/613apps/parsed/613apps_variables.csv",
  "data/sources/613apps/parsed/613apps_value_codes.csv",
  "data/sources/master-pdf-dd/cchs_2022_master_dd.csv",
  "data/sources/master-pdf-dd/cchs_2022_master_dd_categories.csv",
  "data/sources/master-pdf-dd/cchs_2023_master_dd.csv",
  "data/sources/master-pdf-dd/cchs_2023_master_dd_categories.csv",
  "database/cchs_metadata.duckdb"
)

# --- Parse arguments ---
args <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args

# --- Read version ---
version <- trimws(readLines("VERSION", n = 1, warn = FALSE))
date_stamp <- format(Sys.Date(), "%Y-%m-%d")
backup_folder_name <- sprintf("v%s/%s", version, date_stamp)

cat(sprintf("=== Google Drive Backup v%s (%s) ===\n\n", version, date_stamp))

if (dry_run) {
  cat("DRY RUN: No files will be uploaded.\n\n")
}

# --- Authenticate ---
if (!dry_run) {
  drive_auth(email = AUTH_EMAIL)
  cat("Authenticated as:", AUTH_EMAIL, "\n\n")
}

# --- Find or create backup folder ---
find_or_create_folder <- function(folder_path, parent_id) {
  parts <- strsplit(folder_path, "/")[[1]]
  current_parent <- parent_id

  for (part in parts) {
    existing <- drive_find(
      pattern = paste0("^", part, "$"),
      type = "folder",
      q = sprintf("'%s' in parents and trashed = false", current_parent)
    )

    if (nrow(existing) > 0) {
      current_parent <- existing$id[1]
    } else {
      new_folder <- drive_mkdir(
        name = part,
        path = as_id(current_parent)
      )
      current_parent <- new_folder$id
      cat(sprintf("  Created folder: %s\n", part))
    }
  }

  current_parent
}

# --- Upload files ---
uploaded <- 0
skipped <- 0

for (fpath in BACKUP_FILES) {
  if (!file.exists(fpath)) {
    cat(sprintf("  SKIP (not found): %s\n", fpath))
    skipped <- skipped + 1
    next
  }

  size_mb <- file.info(fpath)$size / 1024 / 1024
  cat(sprintf("  %s (%.1f MB)", fpath, size_mb))

  if (dry_run) {
    cat(" -> would upload\n")
    uploaded <- uploaded + 1
    next
  }

  # Ensure folder exists
  folder_id <- find_or_create_folder(
    paste0("backups/", backup_folder_name),
    SHARED_DRIVE_ID
  )

  # Upload with overwrite
  drive_upload(
    media = fpath,
    path = as_id(folder_id),
    name = basename(fpath),
    overwrite = TRUE
  )

  cat(" -> uploaded\n")
  uploaded <- uploaded + 1
}

cat(sprintf("\n=== Done: %d uploaded, %d skipped ===\n", uploaded, skipped))
