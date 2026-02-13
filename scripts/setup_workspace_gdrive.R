#!/usr/bin/env Rscript
# setup_workspace_gdrive.R
# Authenticate with Google Workspace (biglifelab.ca) and create
# the CCHS documentation folder structure.
#
# Run interactively:
#   source("scripts/setup_workspace_gdrive.R")

library(googledrive)

cat("=================================================\n")
cat("Google Workspace authentication (biglifelab.ca)\n")
cat("=================================================\n\n")

# Cache credentials alongside existing personal tokens
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)

# Authenticate with the Workspace account
cat("This will open your browser.\n")
cat("Sign in with: dmanuel@biglifelab.ca\n\n")

drive_auth(
  email = "dmanuel@biglifelab.ca",
  cache = ".secrets"
)

# Verify
user_info <- drive_user()
cat("\nAuthenticated as:", user_info$displayName, "\n")
cat("Email:", user_info$emailAddress, "\n")

# --- Create folder structure ---
cat("\n=================================================\n")
cat("Creating CCHS documentation folder structure\n")
cat("=================================================\n\n")

# Top-level folder for all CCHS documentation
WORKSPACE_ROOT <- "CCHS-Documentation"

# Check if root folder already exists
existing <- drive_find(
  pattern = paste0("^", WORKSPACE_ROOT, "$"),
  type = "folder",
  n_max = 1
)

if (nrow(existing) > 0) {
  root_id <- existing$id[1]
  cat("Found existing folder:", WORKSPACE_ROOT, "\n")
} else {
  root_folder <- drive_mkdir(WORKSPACE_ROOT)
  root_id <- root_folder$id
  cat("Created folder:", WORKSPACE_ROOT, "\n")
}

# Create subfolders
subfolders <- c(
  "cchs-osf-docs",     # Mirror of OSF documentation (1,262 files)
  "cchs-pumf-archive", # DDI XML, PUMF data dictionaries (from personal Drive)
  "ices-dictionary",   # ICES scrape artefacts
  "chms-osf-docs"      # CHMS documentation (52 files)
)

for (folder_name in subfolders) {
  existing_sub <- drive_ls(
    as_id(root_id),
    pattern = paste0("^", folder_name, "$"),
    type = "folder"
  )

  if (nrow(existing_sub) > 0) {
    cat("  Exists:", folder_name, "\n")
  } else {
    drive_mkdir(folder_name, path = as_id(root_id))
    cat("  Created:", folder_name, "\n")
  }
}

cat("\n=================================================\n")
cat("Folder structure ready\n")
cat("=================================================\n\n")

# Show folder link
cat("Google Drive folder:\n")
cat("  https://drive.google.com/drive/folders/", root_id, "\n", sep = "")
cat("\nNext steps:\n")
cat("1. Run scripts/upload_to_workspace.R to upload files\n")
cat("2. Transfer CCHS_PUMF_Archive from personal Drive\n")
cat("3. Share folder with collaborators\n")
