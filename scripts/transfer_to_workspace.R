#!/usr/bin/env Rscript
# transfer_to_workspace.R
# Transfer CCHS_PUMF_Archive from personal Google Drive to shared
# Workspace folder, and move the uploaded cchs-osf-docs into it.
#
# Shared Workspace folder (cchsflow):
#   https://drive.google.com/drive/u/1/folders/0AMZr2JC1NGt7Uk9PVA
#
# Prerequisites:
#   - Run scripts/setup_workspace_gdrive.R first (auth as dmanuel@biglifelab.ca)
#
# Usage:
#   source("scripts/transfer_to_workspace.R")

library(googledrive)

# --- Configuration ---
WORKSPACE_EMAIL  <- "dmanuel@biglifelab.ca"
SHARED_FOLDER_ID <- "0AMZr2JC1NGt7Uk9PVA"  # cchsflow shared folder

# --- Authenticate with Workspace ---
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)
drive_auth(email = WORKSPACE_EMAIL, cache = ".secrets")
cat("Authenticated as:", drive_user()$emailAddress, "\n\n")

# --- Verify access to shared folder ---
cat("Checking access to shared cchsflow folder...\n")
shared_folder <- tryCatch(
  drive_get(as_id(SHARED_FOLDER_ID)),
  error = function(e) {
    stop("Cannot access shared folder. Check permissions for ", WORKSPACE_EMAIL)
  }
)
cat("Found shared folder:", shared_folder$name, "\n\n")

# --- List existing contents ---
cat("Current contents of shared folder:\n")
existing_items <- drive_ls(as_id(SHARED_FOLDER_ID))
if (nrow(existing_items) > 0) {
  for (i in seq_len(nrow(existing_items))) {
    cat("  ", existing_items$name[i], "\n")
  }
} else {
  cat("  (empty)\n")
}
cat("\n")

# --- Create documentation subfolder ---
DOC_FOLDER_NAME <- "cchs-documentation"

existing_doc <- drive_ls(
  as_id(SHARED_FOLDER_ID),
  pattern = paste0("^", DOC_FOLDER_NAME, "$"),
  type = "folder"
)

if (nrow(existing_doc) > 0) {
  doc_folder_id <- existing_doc$id[1]
  cat("Found existing folder:", DOC_FOLDER_NAME, "\n")
} else {
  doc_folder <- drive_mkdir(DOC_FOLDER_NAME, path = as_id(SHARED_FOLDER_ID))
  doc_folder_id <- doc_folder$id
  cat("Created folder:", DOC_FOLDER_NAME, "\n")
}

# --- Create subfolders ---
subfolders <- c(
  "cchs-osf-docs",      # OSF documentation mirror
  "cchs-pumf-archive",  # PUMF data dictionaries, DDI XML
  "ices-dictionary",     # ICES scrape artefacts
  "chms-osf-docs"       # CHMS documentation
)

subfolder_ids <- list()
for (folder_name in subfolders) {
  existing_sub <- drive_ls(
    as_id(doc_folder_id),
    pattern = paste0("^", folder_name, "$"),
    type = "folder"
  )

  if (nrow(existing_sub) > 0) {
    subfolder_ids[[folder_name]] <- existing_sub$id[1]
    cat("  Exists:", folder_name, "\n")
  } else {
    new_sub <- drive_mkdir(folder_name, path = as_id(doc_folder_id))
    subfolder_ids[[folder_name]] <- new_sub$id
    cat("  Created:", folder_name, "\n")
  }
}

cat("\n=================================================\n")
cat("Shared folder structure ready\n")
cat("=================================================\n")
cat("https://drive.google.com/drive/folders/", doc_folder_id, "\n\n", sep = "")

# --- Check for CCHS_PUMF_Archive on personal Drive ---
cat("Looking for CCHS_PUMF_Archive on personal Drive...\n")
cat("(You may need to authenticate with doug.manuel@gmail.com)\n\n")

# Switch to personal account to find the archive
drive_auth(email = "doug.manuel@gmail.com", cache = ".secrets")

archive <- drive_find(
  pattern = "^CCHS_PUMF_Archive$",
  type = "folder",
  n_max = 1
)

if (nrow(archive) == 0) {
  cat("CCHS_PUMF_Archive not found on personal Drive.\n")
  cat("You may need to move it manually via the Drive web UI.\n")
} else {
  archive_id <- archive$id[1]
  cat("Found CCHS_PUMF_Archive (ID:", archive_id, ")\n\n")

  cat("To transfer this to Workspace, you have two options:\n\n")
  cat("Option A: Move via Drive web UI (recommended for large folders)\n")
  cat("  1. Open: https://drive.google.com/drive/folders/", archive_id, "\n", sep = "")
  cat("  2. Right-click > Organise > Move\n")
  cat("  3. Navigate to: Shared drives > cchsflow > cchs-documentation > cchs-pumf-archive\n\n")

  cat("Option B: Copy files programmatically (slower but automated)\n")
  cat("  This copies files one by one. For 254 files / 10.8 GB, this will take time.\n")
  cat("  Uncomment the code block below and re-run to proceed.\n\n")
}

# --- Programmatic copy (uncomment to use) ---
# NOTE: Google Drive API copies are server-side (no download/upload),
# but each file requires a separate API call.
#
# if (exists("archive_id")) {
#   # Switch back to Workspace for writing
#   drive_auth(email = WORKSPACE_EMAIL, cache = ".secrets")
#   target_id <- subfolder_ids[["cchs-pumf-archive"]]
#
#   # Get all files recursively from the archive
#   # This is a simplified version — for nested folders you'd need recursion
#   archive_items <- drive_ls(as_id(archive_id))
#   cat("Copying", nrow(archive_items), "items...\n")
#
#   for (i in seq_len(nrow(archive_items))) {
#     item <- archive_items[i, ]
#     cat(sprintf("[%d/%d] %s... ", i, nrow(archive_items), item$name))
#     tryCatch({
#       drive_cp(as_id(item$id), path = as_id(target_id), name = item$name)
#       cat("copied\n")
#     }, error = function(e) {
#       cat("FAILED:", e$message, "\n")
#     })
#   }
# }

cat("\n=================================================\n")
cat("Next steps\n")
cat("=================================================\n")
cat("1. Move CCHS_PUMF_Archive to Workspace (Option A or B above)\n")
cat("2. Once upload_to_workspace.R finishes, move CCHS-Documentation\n")
cat("   folder into the shared cchsflow folder\n")
cat("3. Update download scripts to point to shared folder\n")
cat("4. Verify all files accessible, then remove local mirrors\n")
