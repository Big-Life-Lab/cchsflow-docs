# Simple PUMF Download using Public Access
#
# This script attempts to download PUMF documentation using public access
# For public folders, we can list contents without auth but may need different
# approach for downloads

library(googledrive)
library(httr)

# Google Drive folder ID
folder_id <- "1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW"
dest_dir <- "cchs-pumf-docs"

# Create destination
if (!dir.exists(dest_dir)) {
  dir.create(dest_dir, recursive = TRUE)
}

# Try without authentication first (for public folders)
drive_deauth()

cat("Fetching folder structure...\n")
all_items <- drive_ls(as_id(folder_id))
print(all_items)

# Manual download function using direct Google Drive download links
download_file_direct <- function(file_id, local_path) {
  # Google Drive direct download URL
  url <- paste0("https://drive.google.com/uc?export=download&id=", file_id)

  cat("Downloading:", local_path, "\n")

  tryCatch({
    # Try direct download
    response <- GET(url, write_disk(local_path, overwrite = TRUE))

    if (status_code(response) == 200) {
      cat("  ✓ Success\n")
      return(TRUE)
    } else {
      cat("  ✗ Failed (status:", status_code(response), ")\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("  ✗ Error:", e$message, "\n")
    return(FALSE)
  })
}

# Recursive folder download using direct links
download_folder_direct <- function(folder_id, local_path) {
  items <- drive_ls(as_id(folder_id))

  if (nrow(items) == 0) {
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(items))) {
    item <- items[i, ]
    item_name <- item$name
    item_id <- as.character(item$id)
    item_type <- item$drive_resource[[1]]$mimeType

    local_item_path <- file.path(local_path, item_name)

    if (item_type == "application/vnd.google-apps.folder") {
      # Folder - create and recurse
      if (!dir.exists(local_item_path)) {
        dir.create(local_item_path, recursive = TRUE)
      }
      download_folder_direct(item_id, local_item_path)
    } else {
      # File - try direct download
      if (!file.exists(local_item_path)) {
        download_file_direct(item_id, local_item_path)
      } else {
        cat("Skipping (exists):", local_item_path, "\n")
      }
    }
  }

  invisible(NULL)
}

cat("\nStarting download...\n")
download_folder_direct(folder_id, dest_dir)

cat("\n✓ Download complete!\n")
cat("Files saved to:", dest_dir, "\n")

# Count files
file_count <- length(list.files(dest_dir, recursive = TRUE))
cat("Total files:", file_count, "\n")
