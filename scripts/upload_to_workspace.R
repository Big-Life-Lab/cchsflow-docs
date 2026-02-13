#!/usr/bin/env Rscript
# upload_to_workspace.R
# Upload local CCHS documentation to Google Workspace Drive.
#
# Prerequisites:
#   - Run scripts/setup_workspace_gdrive.R first to authenticate and create folders
#
# Usage:
#   Rscript scripts/upload_to_workspace.R [--dry-run]
#   source("scripts/upload_to_workspace.R")  # interactive

library(googledrive)

# --- Configuration ---
WORKSPACE_EMAIL <- "dmanuel@biglifelab.ca"
WORKSPACE_ROOT  <- "CCHS-Documentation"
LOCAL_SOURCE    <- "cchs-osf-docs"
REMOTE_SUBFOLDER <- "cchs-osf-docs"

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)

if (dry_run) {
  cat("*** DRY RUN — no files will be uploaded ***\n\n")
}

# --- Authenticate ---
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)
drive_auth(email = WORKSPACE_EMAIL, cache = ".secrets")

cat("Authenticated as:", drive_user()$emailAddress, "\n\n")

# --- Find target folder ---
root <- drive_find(
  pattern = paste0("^", WORKSPACE_ROOT, "$"),
  type = "folder",
  n_max = 1
)
if (nrow(root) == 0) {
  stop("Root folder '", WORKSPACE_ROOT, "' not found. Run setup_workspace_gdrive.R first.")
}
root_id <- root$id[1]

# Find the cchs-osf-docs subfolder
target <- drive_ls(as_id(root_id), pattern = paste0("^", REMOTE_SUBFOLDER, "$"), type = "folder")
if (nrow(target) == 0) {
  stop("Subfolder '", REMOTE_SUBFOLDER, "' not found under ", WORKSPACE_ROOT)
}
target_id <- target$id[1]

# --- Gather local files ---
local_files <- list.files(LOCAL_SOURCE, recursive = TRUE, full.names = FALSE)
cat("Local files to upload:", length(local_files), "\n")

# --- Helper: ensure folder path exists on Drive, return folder ID ---
folder_cache <- list()
folder_cache[[""]] <- target_id

ensure_remote_folder <- function(rel_dir) {
  if (rel_dir %in% names(folder_cache)) {
    return(folder_cache[[rel_dir]])
  }

  parts <- strsplit(rel_dir, "/")[[1]]
  current_path <- ""
  parent_id <- target_id

  for (part in parts) {
    current_path <- if (current_path == "") part else paste(current_path, part, sep = "/")

    if (current_path %in% names(folder_cache)) {
      parent_id <- folder_cache[[current_path]]
      next
    }

    existing <- drive_ls(as_id(parent_id), pattern = paste0("^", part, "$"), type = "folder")

    if (nrow(existing) > 0) {
      parent_id <- existing$id[1]
    } else {
      if (!dry_run) {
        new_folder <- drive_mkdir(part, path = as_id(parent_id))
        parent_id <- new_folder$id
      } else {
        parent_id <- paste0("dry-run-", current_path)
      }
      cat("  Created folder:", current_path, "\n")
    }

    folder_cache[[current_path]] <<- parent_id
  }

  return(parent_id)
}

# --- Upload files ---
cat("\nUploading files...\n\n")

uploaded <- 0
skipped <- 0
failed <- 0

for (i in seq_along(local_files)) {
  rel_path <- local_files[i]
  local_path <- file.path(LOCAL_SOURCE, rel_path)
  file_name <- basename(rel_path)
  rel_dir <- dirname(rel_path)
  if (rel_dir == ".") rel_dir <- ""

  file_size <- file.info(local_path)$size / 1024 / 1024

  cat(sprintf("[%d/%d] %s (%.1f MiB)... ",
              i, length(local_files), rel_path, file_size))

  tryCatch({
    # Ensure parent folder exists
    parent_id <- ensure_remote_folder(rel_dir)

    if (!dry_run) {
      # Check if file already exists
      existing_file <- drive_ls(
        as_id(parent_id),
        pattern = paste0("^", gsub("([.\\\\|()\\[{}^$*+?])", "\\\\\\1", file_name), "$")
      )

      if (nrow(existing_file) > 0) {
        cat("exists, skipping\n")
        skipped <- skipped + 1
      } else {
        drive_upload(local_path, path = as_id(parent_id), name = file_name)
        cat("uploaded\n")
        uploaded <- uploaded + 1
      }
    } else {
      cat("(dry run)\n")
      uploaded <- uploaded + 1
    }
  }, error = function(e) {
    cat("FAILED:", e$message, "\n")
    failed <<- failed + 1
  })
}

# --- Summary ---
cat("\n=================================================\n")
cat("Upload summary\n")
cat("=================================================\n")
cat("Total files:  ", length(local_files), "\n")
cat("Uploaded:     ", uploaded, "\n")
cat("Skipped:      ", skipped, "(already exist)\n")
cat("Failed:       ", failed, "\n")

if (dry_run) {
  cat("\n*** This was a dry run. Re-run without --dry-run to upload. ***\n")
}
