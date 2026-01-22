# CCHS Data Download from Google Drive
#
# Downloads CCHS data files from Google Drive folder
# Folder: https://drive.google.com/drive/folders/1M8C8KV88fHtgzZleRatlInf0c8Cwv8ZR
#
# This script attempts to download using public access first.
# For private folders, run setup_gdrive_auth.R first to authenticate.

library(googledrive)
library(httr)

# Google Drive folder ID for CCHS-data
folder_id <- "1M8C8KV88fHtgzZleRatlInf0c8Cwv8ZR"
dest_dir <- "cchs-data-docs"

# Create destination directory
if (!dir.exists(dest_dir)) {
  dir.create(dest_dir, recursive = TRUE)
  cat("Created directory:", dest_dir, "\n")
}

# Try without authentication first (for public folders)
# If this fails, you'll need to run setup_gdrive_auth.R
cat("Attempting to access Google Drive folder...\n")
cat("Folder ID:", folder_id, "\n")
cat("Destination:", dest_dir, "\n\n")

# Check if authentication is needed
auth_needed <- tryCatch({
  drive_deauth()
  test_items <- drive_ls(as_id(folder_id), page_size = 1)
  FALSE  # No auth needed
}, error = function(e) {
  cat("Public access failed. Authentication required.\n")
  cat("Please run: source('R/setup_gdrive_auth.R')\n\n")
  TRUE  # Auth needed
})

if (auth_needed) {
  # Try to use cached authentication
  if (dir.exists(".secrets")) {
    cat("Using cached authentication from .secrets/\n")
    options(
      gargle_oauth_cache = ".secrets",
      gargle_oauth_email = TRUE
    )
  } else {
    stop("Authentication required. Please run setup_gdrive_auth.R first.")
  }
}

cat("Fetching folder structure...\n")
all_items <- drive_ls(as_id(folder_id))
cat("Found", nrow(all_items), "items in root folder\n\n")

# Manual download function using direct Google Drive download links
download_file_direct <- function(file_id, local_path) {
  # Google Drive direct download URL
  url <- paste0("https://drive.google.com/uc?export=download&id=", file_id)

  cat("Downloading:", basename(local_path), "\n")

  tryCatch({
    # Try direct download
    response <- GET(url, write_disk(local_path, overwrite = TRUE))

    if (status_code(response) == 200) {
      file_size <- file.info(local_path)$size
      cat(sprintf("  ✓ Success (%s bytes)\n", format(file_size, big.mark = ",")))
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
download_folder_direct <- function(folder_id, local_path, depth = 0) {
  indent <- paste(rep("  ", depth), collapse = "")

  items <- drive_ls(as_id(folder_id))

  if (nrow(items) == 0) {
    cat(indent, "(empty folder)\n", sep = "")
    return(invisible(NULL))
  }

  cat(indent, "Processing", nrow(items), "items...\n", sep = "")

  for (i in seq_len(nrow(items))) {
    item <- items[i, ]
    item_name <- item$name
    item_id <- as.character(item$id)
    item_type <- item$drive_resource[[1]]$mimeType

    local_item_path <- file.path(local_path, item_name)

    if (item_type == "application/vnd.google-apps.folder") {
      # Folder - create and recurse
      cat(indent, "📁 ", item_name, "\n", sep = "")
      if (!dir.exists(local_item_path)) {
        dir.create(local_item_path, recursive = TRUE)
      }
      download_folder_direct(item_id, local_item_path, depth + 1)
    } else {
      # File - try direct download
      if (!file.exists(local_item_path)) {
        cat(indent, "📄 ", sep = "")
        download_file_direct(item_id, local_item_path)
      } else {
        cat(indent, "⊘  Skipping (exists): ", item_name, "\n", sep = "")
      }
    }
  }

  invisible(NULL)
}

# Main download function
download_all_cchs_data <- function() {
  cat("\n═══════════════════════════════════════════════════════════\n")
  cat("Starting CCHS Data Download from Google Drive\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  start_time <- Sys.time()
  download_folder_direct(folder_id, dest_dir)
  end_time <- Sys.time()

  # Summary statistics
  cat("\n═══════════════════════════════════════════════════════════\n")
  cat("✓ Download Complete!\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  file_count <- length(list.files(dest_dir, recursive = TRUE))
  total_size <- sum(file.info(list.files(dest_dir, recursive = TRUE, full.names = TRUE))$size, na.rm = TRUE)

  cat("Destination:  ", dest_dir, "\n")
  cat("Total files:  ", file_count, "\n")
  cat("Total size:   ", format(total_size / 1024^2, digits = 2), "MB\n")
  cat("Duration:     ", format(end_time - start_time), "\n\n")

  cat("Next steps:\n")
  cat("1. Review downloaded files in", dest_dir, "\n")
  cat("2. Run cataloging script to generate metadata\n")
  cat("3. Add to catalog configuration\n\n")

  invisible(list(
    files = file_count,
    size_mb = total_size / 1024^2,
    duration = end_time - start_time
  ))
}

# Run if sourced directly
if (!interactive()) {
  download_all_cchs_data()
}
