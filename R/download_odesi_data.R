# ODESI Data Download
#
# Downloads data files from ODESI (Ontario Data Documentation, Extraction Service
# and Infrastructure) using the Dataverse API.
# ODESI is integrated with Borealis, the Canadian Dataverse Repository.
#
# Example usage:
#   # Single dataset download
#   download_odesi_dataset(
#     doi = "doi:10.5683/SP3/ZVCGBK",
#     dest_dir = "odesi-data"
#   )
#
#   # Multiple datasets
#   dois <- c("doi:10.5683/SP3/ZVCGBK", "doi:10.5683/SP3/ANOTHER")
#   download_multiple_odesi_datasets(dois, dest_dir = "odesi-data")
#
# For restricted datasets, you'll need an API key from:
# https://borealisdata.ca/ (login and go to API Token in account settings)
#
# Set your API key as an environment variable:
#   Sys.setenv(DATAVERSE_KEY = "your-api-key-here")
# Or create a .Renviron file with: DATAVERSE_KEY=your-api-key-here

library(httr)
library(jsonlite)
library(xml2)

# ODESI/Borealis base URL
BOREALIS_SERVER <- "https://borealisdata.ca"

#' Extract DOI from ODESI URL
#'
#' @param url ODESI URL (e.g., "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml")
#' @return DOI string (e.g., "doi:10.5683/SP3/ZVCGBK")
extract_doi_from_odesi_url <- function(url) {
  # Extract the DOI pattern from the URL
  # Pattern: doi__XX-XXXX_SPXX_XXXXXX.xml
  pattern <- "doi__([0-9]{2})-([0-9]{4})_([^.]+)\\.xml"
  matches <- regmatches(url, regexec(pattern, url))

  if (length(matches[[1]]) > 0) {
    # Convert doi__10-5683_SP3_ZVCGBK to doi:10.5683/SP3/ZVCGBK
    doi <- paste0("doi:", matches[[1]][2], ".", matches[[1]][3], "/", matches[[1]][4])
    return(doi)
  } else {
    stop("Could not extract DOI from URL: ", url)
  }
}

#' Get dataset metadata from Dataverse API
#'
#' @param doi Persistent identifier (DOI)
#' @param server Dataverse server URL
#' @param key API key (optional, needed for restricted datasets)
#' @return List with dataset metadata
get_dataset_metadata <- function(doi, server = BOREALIS_SERVER, key = NULL) {
  url <- paste0(server, "/api/datasets/:persistentId/?persistentId=", doi)

  headers <- c()
  if (!is.null(key)) {
    headers <- c(headers, "X-Dataverse-key" = key)
  }

  response <- GET(url, add_headers(.headers = headers))

  if (status_code(response) != 200) {
    stop(sprintf("Failed to get dataset metadata (status %d): %s",
                 status_code(response), content(response, "text")))
  }

  content(response, "parsed")
}

#' Get list of files in a dataset
#'
#' @param doi Persistent identifier (DOI)
#' @param server Dataverse server URL
#' @param key API key (optional)
#' @return Data frame with file information
get_dataset_files <- function(doi, server = BOREALIS_SERVER, key = NULL) {
  metadata <- get_dataset_metadata(doi, server, key)

  if (!"data" %in% names(metadata) ||
      !"latestVersion" %in% names(metadata$data) ||
      !"files" %in% names(metadata$data$latestVersion)) {
    warning("No files found in dataset")
    return(data.frame())
  }

  files <- metadata$data$latestVersion$files

  # Extract relevant information
  file_info <- data.frame(
    file_id = sapply(files, function(f) f$dataFile$id),
    filename = sapply(files, function(f) f$dataFile$filename),
    contentType = sapply(files, function(f) f$dataFile$contentType),
    filesize = sapply(files, function(f) f$dataFile$filesize),
    description = sapply(files, function(f) {
      if (!is.null(f$dataFile$description)) f$dataFile$description else ""
    }),
    restricted = sapply(files, function(f) {
      if (!is.null(f$restricted)) f$restricted else FALSE
    }),
    stringsAsFactors = FALSE
  )

  return(file_info)
}

#' Download a single file from Dataverse
#'
#' @param file_id File ID
#' @param local_path Local path to save file
#' @param server Dataverse server URL
#' @param key API key (optional, needed for restricted files)
#' @return TRUE if successful, FALSE otherwise
download_dataverse_file <- function(file_id, local_path, server = BOREALIS_SERVER, key = NULL) {
  url <- paste0(server, "/api/access/datafile/", file_id)

  cat("Downloading:", basename(local_path), "\n")

  headers <- c()
  if (!is.null(key)) {
    headers <- c(headers, "X-Dataverse-key" = key)
  }

  tryCatch({
    response <- GET(url, add_headers(.headers = headers),
                   write_disk(local_path, overwrite = TRUE),
                   progress())

    if (status_code(response) == 200) {
      file_size <- file.info(local_path)$size
      cat(sprintf("  ✓ Success (%s bytes)\n", format(file_size, big.mark = ",")))
      return(TRUE)
    } else if (status_code(response) == 403) {
      cat("  ✗ Failed: Access forbidden (authentication required)\n")
      if (is.null(key)) {
        cat("    Hint: Set DATAVERSE_KEY environment variable for restricted files\n")
      }
      return(FALSE)
    } else {
      cat("  ✗ Failed (status:", status_code(response), ")\n")
      return(FALSE)
    }
  }, error = function(e) {
    cat("  ✗ Error:", e$message, "\n")
    return(FALSE)
  })
}

#' Download entire dataset from ODESI
#'
#' @param doi Persistent identifier (DOI) or ODESI URL
#' @param dest_dir Destination directory
#' @param server Dataverse server URL
#' @param key API key (optional, can also be set via DATAVERSE_KEY env variable)
#' @param create_subdir Create subdirectory for dataset (default: TRUE)
#' @return List with download statistics
download_odesi_dataset <- function(doi,
                                   dest_dir = "odesi-data",
                                   server = BOREALIS_SERVER,
                                   key = NULL,
                                   create_subdir = TRUE) {

  # Check if input is a URL and extract DOI
  if (grepl("^https?://", doi)) {
    cat("Extracting DOI from URL...\n")
    doi <- extract_doi_from_odesi_url(doi)
    cat("DOI:", doi, "\n\n")
  }

  # Get API key from environment if not provided
  if (is.null(key)) {
    key <- Sys.getenv("DATAVERSE_KEY", unset = NA)
    if (is.na(key)) {
      key <- NULL
    } else {
      cat("Using API key from DATAVERSE_KEY environment variable\n")
    }
  }

  cat("═══════════════════════════════════════════════════════════\n")
  cat("ODESI Dataset Download\n")
  cat("═══════════════════════════════════════════════════════════\n\n")
  cat("DOI:    ", doi, "\n")
  cat("Server: ", server, "\n\n")

  # Get dataset metadata
  cat("Fetching dataset metadata...\n")
  metadata <- get_dataset_metadata(doi, server, key)

  dataset_title <- metadata$data$latestVersion$metadataBlocks$citation$fields[[1]]$value
  cat("Dataset:", dataset_title, "\n\n")

  # Get file list
  cat("Fetching file list...\n")
  files <- get_dataset_files(doi, server, key)

  if (nrow(files) == 0) {
    cat("No files found in dataset.\n")
    return(invisible(list(files = 0, size_mb = 0, success = 0, failed = 0)))
  }

  cat("Found", nrow(files), "file(s)\n\n")

  # Create destination directory
  if (create_subdir) {
    # Use DOI as subdirectory name (sanitized)
    subdir_name <- gsub("[:/]", "_", doi)
    dest_dir <- file.path(dest_dir, subdir_name)
  }

  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE)
    cat("Created directory:", dest_dir, "\n\n")
  }

  # Save dataset metadata
  metadata_file <- file.path(dest_dir, "dataset_metadata.json")
  write(toJSON(metadata, pretty = TRUE, auto_unbox = TRUE), metadata_file)
  cat("Saved metadata to:", metadata_file, "\n\n")

  # Save file list
  file_list <- file.path(dest_dir, "file_list.csv")
  write.csv(files, file_list, row.names = FALSE)
  cat("Saved file list to:", file_list, "\n\n")

  # Download files
  cat("Downloading files...\n")
  cat("─────────────────────────────────────────────────────────\n\n")

  start_time <- Sys.time()
  success_count <- 0
  failed_count <- 0

  for (i in seq_len(nrow(files))) {
    file_row <- files[i, ]
    local_path <- file.path(dest_dir, file_row$filename)

    # Check if file already exists
    if (file.exists(local_path)) {
      cat("⊘  Skipping (exists):", file_row$filename, "\n")
      success_count <- success_count + 1
      next
    }

    # Show file info
    if (file_row$restricted) {
      cat("🔒 Restricted file\n")
    }
    cat(sprintf("   Size: %s bytes\n", format(file_row$filesize, big.mark = ",")))

    # Download file
    success <- download_dataverse_file(file_row$file_id, local_path, server, key)

    if (success) {
      success_count <- success_count + 1
    } else {
      failed_count <- failed_count + 1
    }

    cat("\n")
  }

  end_time <- Sys.time()

  # Summary
  cat("═══════════════════════════════════════════════════════════\n")
  cat("✓ Download Complete!\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  total_files <- list.files(dest_dir, recursive = TRUE)
  total_size <- sum(file.info(file.path(dest_dir, total_files))$size, na.rm = TRUE)

  cat("Dataset:      ", dataset_title, "\n")
  cat("DOI:          ", doi, "\n")
  cat("Destination:  ", dest_dir, "\n")
  cat("Total files:  ", length(total_files), "\n")
  cat("Downloaded:   ", success_count, "\n")
  cat("Failed:       ", failed_count, "\n")
  cat("Total size:   ", format(total_size / 1024^2, digits = 2), "MB\n")
  cat("Duration:     ", format(end_time - start_time), "\n\n")

  invisible(list(
    doi = doi,
    title = dataset_title,
    files = length(total_files),
    size_mb = total_size / 1024^2,
    success = success_count,
    failed = failed_count,
    duration = end_time - start_time,
    dest_dir = dest_dir
  ))
}

#' Download multiple datasets from ODESI
#'
#' @param dois Vector of DOIs or ODESI URLs
#' @param dest_dir Base destination directory
#' @param server Dataverse server URL
#' @param key API key (optional)
#' @return List with summary statistics
download_multiple_odesi_datasets <- function(dois,
                                             dest_dir = "odesi-data",
                                             server = BOREALIS_SERVER,
                                             key = NULL) {

  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("ODESI Multi-Dataset Download\n")
  cat("═══════════════════════════════════════════════════════════\n\n")
  cat("Number of datasets:", length(dois), "\n")
  cat("Destination:       ", dest_dir, "\n\n")

  results <- list()

  for (i in seq_along(dois)) {
    cat("\n")
    cat("───────────────────────────────────────────────────────────\n")
    cat(sprintf("Dataset %d of %d\n", i, length(dois)))
    cat("───────────────────────────────────────────────────────────\n\n")

    result <- tryCatch({
      download_odesi_dataset(dois[i], dest_dir, server, key, create_subdir = TRUE)
    }, error = function(e) {
      cat("✗ Error downloading dataset:", dois[i], "\n")
      cat("  ", e$message, "\n\n")
      list(doi = dois[i], success = 0, failed = 1)
    })

    results[[i]] <- result
  }

  # Overall summary
  cat("\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat("✓ All Downloads Complete!\n")
  cat("═══════════════════════════════════════════════════════════\n\n")

  total_success <- sum(sapply(results, function(x) x$success))
  total_failed <- sum(sapply(results, function(x) x$failed))
  total_size_mb <- sum(sapply(results, function(x) x$size_mb), na.rm = TRUE)

  cat("Datasets processed:", length(dois), "\n")
  cat("Files downloaded:  ", total_success, "\n")
  cat("Files failed:      ", total_failed, "\n")
  cat("Total size:        ", format(total_size_mb, digits = 2), "MB\n\n")

  invisible(list(
    datasets = length(dois),
    total_success = total_success,
    total_failed = total_failed,
    total_size_mb = total_size_mb,
    results = results
  ))
}

# Example usage (commented out)
#
# # Download the dataset from the URL you provided
# download_odesi_dataset(
#   doi = "https://odesi.ca/en/details?id=/odesi/doi__10-5683_SP3_ZVCGBK.xml",
#   dest_dir = "odesi-data"
# )
#
# # Or use the DOI directly
# download_odesi_dataset(
#   doi = "doi:10.5683/SP3/ZVCGBK",
#   dest_dir = "odesi-data"
# )
#
# # For restricted datasets, set your API key:
# # Sys.setenv(DATAVERSE_KEY = "your-api-key-here")
# # Then run the download
#
# # Download multiple datasets
# dois <- c(
#   "doi:10.5683/SP3/ZVCGBK",
#   "doi:10.5683/SP3/ANOTHER"
# )
# download_multiple_odesi_datasets(dois, dest_dir = "odesi-data")
