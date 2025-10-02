# Download missing PUMF folders from Google Drive

library(googledrive)

# Deauth for public folder
drive_deauth()

# Missing folder IDs
missing_folders <- tibble::tribble(
  ~name,                     ~id,
  "CCHS_derived_variables",  "1iGg-DF3AiEwCa2FpBXoh4P9rvIfyqlkt",
  "CCHS_study_documentation", "1-v49qnwQ8dPzofUgq9RE3tjWl0K2k2qE",
  "CCHS_data_dictionary",    "1F2SRBbFJSiHdvg3Xweto1iLzcEgxvpzK",
  "CCHS-questionnnaire",     "1IFb3KelgETJAVG8K5VKez1NNFg0hMLg8"
)

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
      # It's a file - download it (skip if exists)
      if (file.exists(local_item_path)) {
        cat("Skipping (exists):", local_item_path, "\n")
      } else {
        cat("Downloading:", local_item_path, "\n")
        tryCatch({
          drive_download(
            file = as_id(item_id),
            path = local_item_path,
            overwrite = FALSE
          )
        }, error = function(e) {
          cat("ERROR downloading", local_item_path, ":", e$message, "\n")
        })
      }
    }
  }

  invisible(NULL)
}

# Download each missing folder
for (i in seq_len(nrow(missing_folders))) {
  folder <- missing_folders[i, ]
  cat("\n=== Downloading:", folder$name, "===\n")

  local_path <- file.path("cchs-pumf-docs", folder$name)
  if (!dir.exists(local_path)) {
    dir.create(local_path, recursive = TRUE)
  }

  download_folder_recursive(folder$id, local_path)
}

cat("\n✓ Download complete!\n")
