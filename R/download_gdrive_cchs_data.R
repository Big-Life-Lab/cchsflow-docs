# CCHS Data Download from Google Workspace
#
# Downloads CCHS documentation files from shared Google Workspace folder.
# Shared folder: https://drive.google.com/drive/folders/0AMZr2JC1NGt7Uk9PVA
#
# Subfolder structure:
#   CCHS-Documentation/
#     cchs-osf-docs/       - OSF documentation mirror (1,313 files)
#     cchs-pumf-archive/   - PUMF data dictionaries, DDI XML
#     ices-dictionary/     - ICES scrape artefacts
#     chms-osf-docs/       - CHMS documentation
#
# Prerequisites:
#   Run scripts/setup_workspace_gdrive.R to authenticate with Workspace
#
# Usage:
#   source("R/download_gdrive_cchs_data.R")
#   download_cchs_docs()                    # Download cchs-osf-docs
#   download_cchs_docs("cchs-pumf-archive") # Download PUMF archive

library(googledrive)

# --- Configuration ---
WORKSPACE_EMAIL <- "dmanuel@biglifelab.ca"
SHARED_FOLDER_ID <- "0AMZr2JC1NGt7Uk9PVA"  # cchsflow shared folder
DOC_FOLDER_ID <- "1WDpaCUXB7hQRrONyegTZ5-ewUyDh9rDj"  # CCHS-Documentation

# Subfolder IDs (from shared folder)
SUBFOLDER_IDS <- list(
  "cchs-osf-docs"     = "1Sw_-HMFYQVYi_dUSFgaGUSvoS1H3xPHO",
  "cchs-pumf-archive" = "1R_9Y0IkSAG__yMXVZ7S-4u5MNHYzto4e",
  "ices-dictionary"   = "1p-gON3WAUMRIdHndjPDJgvGjX7cKhPZn",
  "chms-osf-docs"     = "14P666MpgTzNyMen9TLQAjFCQdB48k06_"
)

# --- Recursive download ---
download_folder <- function(folder_id, local_path, depth = 0) {
  indent <- paste(rep("  ", depth), collapse = "")

  items <- drive_ls(as_id(folder_id))

  if (nrow(items) == 0) {
    cat(indent, "(empty folder)\n", sep = "")
    return(invisible(NULL))
  }

  cat(indent, "Processing ", nrow(items), " items...\n", sep = "")

  for (i in seq_len(nrow(items))) {
    item <- items[i, ]
    item_name <- item$name
    item_id <- as.character(item$id)
    item_type <- item$drive_resource[[1]]$mimeType

    local_item_path <- file.path(local_path, item_name)

    if (item_type == "application/vnd.google-apps.folder") {
      cat(indent, "  [folder] ", item_name, "\n", sep = "")
      if (!dir.exists(local_item_path)) {
        dir.create(local_item_path, recursive = TRUE)
      }
      download_folder(item_id, local_item_path, depth + 1)
    } else {
      if (!file.exists(local_item_path)) {
        cat(indent, "  ", item_name, "... ", sep = "")
        tryCatch({
          drive_download(as_id(item_id), path = local_item_path, overwrite = FALSE)
          file_size <- file.info(local_item_path)$size
          cat(sprintf("done (%s bytes)\n", format(file_size, big.mark = ",")))
        }, error = function(e) {
          cat("FAILED:", e$message, "\n")
        })
      } else {
        cat(indent, "  (exists) ", item_name, "\n", sep = "")
      }
    }
  }

  invisible(NULL)
}

#' Download CCHS documentation from shared Workspace
#'
#' @param subfolder Which subfolder to download. One of: "cchs-osf-docs",
#'   "cchs-pumf-archive", "ices-dictionary", "chms-osf-docs"
#' @param dest_dir Local destination directory. Defaults to subfolder name.
download_cchs_docs <- function(subfolder = "cchs-osf-docs", dest_dir = subfolder) {
  if (!subfolder %in% names(SUBFOLDER_IDS)) {
    stop(
      "Unknown subfolder: ", subfolder,
      "\nChoose from: ", paste(names(SUBFOLDER_IDS), collapse = ", ")
    )
  }

  # Authenticate
  options(gargle_oauth_cache = ".secrets", gargle_oauth_email = TRUE)
  drive_auth(email = WORKSPACE_EMAIL, cache = ".secrets")
  cat("Authenticated as:", drive_user()$emailAddress, "\n\n")

  # Create destination
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
    cat("Created directory:", dest_dir, "\n")
  }

  folder_id <- SUBFOLDER_IDS[[subfolder]]

  cat("=================================================\n")
  cat("Downloading:", subfolder, "\n")
  cat("Destination:", dest_dir, "\n")
  cat("=================================================\n\n")

  start_time <- Sys.time()
  download_folder(folder_id, dest_dir)
  end_time <- Sys.time()

  # Summary
  file_count <- length(list.files(dest_dir, recursive = TRUE))
  total_size <- sum(
    file.info(list.files(dest_dir, recursive = TRUE, full.names = TRUE))$size,
    na.rm = TRUE
  )

  cat("\n=================================================\n")
  cat("Download complete\n")
  cat("=================================================\n")
  cat("Files:    ", file_count, "\n")
  cat("Size:     ", format(total_size / 1024^2, digits = 2), "MB\n")
  cat("Duration: ", format(end_time - start_time), "\n")

  invisible(list(files = file_count, size_mb = total_size / 1024^2))
}
