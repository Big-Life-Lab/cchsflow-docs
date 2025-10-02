# Download CCHS PUMF Documentation from Google Drive
#
# This script downloads the PUMF documentation from a public Google Drive folder
# and organizes it in cchs-pumf-docs/
#
# Prerequisites:
# 1. Run R/setup_gdrive.R first to authenticate with Google Drive
# 2. Ensure .secrets/ is in .gitignore (for credential security)

library(googledrive)

# Google Drive folder URL
folder_url <- "https://drive.google.com/drive/folders/1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW"
folder_id <- "1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW"

# Local destination
dest_dir <- "cchs-pumf-docs"

# Create destination directory
if (!dir.exists(dest_dir)) {
  dir.create(dest_dir, recursive = TRUE)
}

# Configure authentication
options(
  gargle_oauth_cache = ".secrets",
  gargle_oauth_email = TRUE
)

# Use cached authentication (set up via setup_gdrive.R)
# If not authenticated, this will prompt for login
drive_auth(cache = ".secrets", email = TRUE)

# List contents of the folder
cat("Fetching folder contents...\n")
folder_contents <- drive_ls(as_id(folder_id))

print(folder_contents)

# Recursive download function
download_folder_recursive <- function(folder_id, local_path) {
  # Get folder contents
  items <- drive_ls(as_id(folder_id))

  if (nrow(items) == 0) {
    cat("Empty folder\n")
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(items))) {
    item <- items[i, ]
    item_name <- item$name
    item_id <- item$id
    item_type <- item$drive_resource[[1]]$mimeType

    local_item_path <- file.path(local_path, item_name)

    if (item_type == "application/vnd.google-apps.folder") {
      # It's a folder - create locally and recurse
      cat("Creating folder:", local_item_path, "\n")
      if (!dir.exists(local_item_path)) {
        dir.create(local_item_path, recursive = TRUE)
      }
      download_folder_recursive(item_id, local_item_path)
    } else {
      # It's a file - download it
      cat("Downloading:", local_item_path, "\n")
      drive_download(
        file = as_id(item_id),
        path = local_item_path,
        overwrite = TRUE
      )
    }
  }

  invisible(NULL)
}

# Download the entire folder
cat("Starting download to", dest_dir, "\n")
download_folder_recursive(folder_id, dest_dir)

cat("\nDownload complete!\n")
cat("Files saved to:", dest_dir, "\n")
