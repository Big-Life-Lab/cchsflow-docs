#!/usr/bin/env Rscript
# upload_ices_to_gdrive.R
# Upload ICES CCHS Dictionary data to Google Drive for permanent storage
#
# Prerequisites:
#   - Run R/setup_gdrive_auth.R first to authenticate
#   - Data files must exist in data/ directory
#
# Usage:
#   Rscript scripts/upload_ices_to_gdrive.R

library(googledrive)

# Configure authentication
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)

# Authenticate (uses cached credentials)
drive_auth(cache = ".secrets")

cat("=================================================\n")
cat("Upload ICES CCHS Dictionary to Google Drive\n")
cat("=================================================\n\n")

# Files to upload
files_to_upload <- c(

"data/ices_cchs_dictionary.duckdb",
  "data/catalog/ices_cchs_availability_matrix.csv",
  "data/manifests/ices_cchs_dictionary_v1.0.0.yaml"
)

# Check files exist
missing <- files_to_upload[!file.exists(files_to_upload)]
if (length(missing) > 0) {
  stop("Missing files: ", paste(missing, collapse = ", "))
}

# Target folder in Google Drive
# Update this to your desired folder path or ID
GDRIVE_FOLDER <- "cchsflow-docs/ices-dictionary"

cat("Target folder:", GDRIVE_FOLDER, "\n\n")

# Create folder if needed (or find existing)
folder_parts <- strsplit(GDRIVE_FOLDER, "/")[[1]]
parent_id <- NULL

for (part in folder_parts) {
  if (is.null(parent_id)) {
    existing <- drive_find(pattern = paste0("^", part, "$"), type = "folder", n_max = 1)
  } else {
    existing <- drive_ls(as_id(parent_id), pattern = paste0("^", part, "$"), type = "folder")
  }

  if (nrow(existing) == 0) {
    cat("Creating folder:", part, "\n")
    if (is.null(parent_id)) {
      new_folder <- drive_mkdir(part)
    } else {
      new_folder <- drive_mkdir(part, path = as_id(parent_id))
    }
    parent_id <- new_folder$id
  } else {
    parent_id <- existing$id[1]
    cat("Found folder:", part, "\n")
  }
}

cat("\nUploading files...\n\n")

# Upload each file
for (file_path in files_to_upload) {
  file_name <- basename(file_path)
  file_size <- file.info(file_path)$size / 1024 / 1024

  cat(sprintf("  %s (%.1f MiB)... ", file_name, file_size))

  # Check if file already exists
  existing <- drive_ls(as_id(parent_id), pattern = paste0("^", file_name, "$"))

  if (nrow(existing) > 0) {
    # Update existing file
    drive_update(as_id(existing$id[1]), media = file_path)
    cat("updated\n")
  } else {
    # Upload new file
    drive_upload(file_path, path = as_id(parent_id), name = file_name)
    cat("uploaded\n")
  }
}

cat("\n=================================================\n")
cat("Upload complete!\n")
cat("=================================================\n")

# Show folder link
folder_meta <- drive_get(as_id(parent_id))
cat("\nGoogle Drive folder:\n")
cat("  https://drive.google.com/drive/folders/", parent_id, "\n", sep = "")
