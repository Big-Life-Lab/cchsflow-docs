# CHMS OSF Sync System
# Downloads and maintains a complete mirror of CHMS documentation from OSF.io
#
# Unlike CCHS with its nested year/cycle/master-share structure,
# CHMS uses a flat component-based structure:
# - 6 cycle components (Cycle1-6)
# - Files directly in each component (no nested folders)

library(httr)
library(jsonlite)

source("R/osf_api_client.R")

#' Sync all CHMS files from OSF
#' @param target_dir Base directory for CHMS mirror (default: "chms-osf-docs")
#' @param dry_run If TRUE, show what would be downloaded without downloading
#' @param overwrite If TRUE, re-download existing files
#' @return list with sync results
sync_chms_structure <- function(target_dir = "chms-osf-docs",
                                 dry_run = FALSE,
                                 overwrite = FALSE) {

  cat("=== CHMS OSF SYNC ===\n")
  cat("Target directory:", target_dir, "\n")
  cat("Dry run:", dry_run, "\n")
  cat("Overwrite existing:", overwrite, "\n\n")

  # Get all cycles
  cycles <- get_chms_cycles()
  cat("Found", nrow(cycles), "CHMS cycles\n\n")

  # Track results
  results <- list(
    total_files = 0,
    new_files = 0,
    existing_files = 0,
    failed_files = 0,
    cycles = list()
  )

  # Process each cycle
  for (i in 1:nrow(cycles)) {
    cycle_name <- paste0("Cycle", cycles$cycle_num[i])
    cat("Processing", cycle_name, "...\n")

    cycle_result <- sync_chms_cycle(
      cycle_num = cycles$cycle_num[i],
      target_dir = target_dir,
      dry_run = dry_run,
      overwrite = overwrite
    )

    results$cycles[[cycle_name]] <- cycle_result
    results$total_files <- results$total_files + cycle_result$total_files
    results$new_files <- results$new_files + cycle_result$new_files
    results$existing_files <- results$existing_files + cycle_result$existing_files
    results$failed_files <- results$failed_files + cycle_result$failed_files

    cat("\n")
    Sys.sleep(0.5)
  }

  # Summary
  cat("=== SYNC SUMMARY ===\n")
  cat("Total files:", results$total_files, "\n")
  cat("New downloads:", results$new_files, "\n")
  cat("Already existed:", results$existing_files, "\n")
  cat("Failed:", results$failed_files, "\n")

  return(invisible(results))
}

#' Sync a single CHMS cycle
#' @param cycle_num Cycle number (1-6)
#' @param target_dir Base directory for mirror
#' @param dry_run If TRUE, don't actually download
#' @param overwrite If TRUE, re-download existing files
#' @return list with cycle sync results
sync_chms_cycle <- function(cycle_num,
                             target_dir = "chms-osf-docs",
                             dry_run = FALSE,
                             overwrite = FALSE) {

  # Get cycle files from OSF
  cycle_files <- get_chms_cycle_files(cycle_num)

  # Filter for files only (exclude any folders)
  files <- cycle_files[cycle_files$kind == "file", ]

  cycle_name <- paste0("Cycle", cycle_num)
  cycle_dir <- file.path(target_dir, cycle_name)

  # Get component ID for waterbutler downloads
  cycles <- get_chms_cycles()
  cycle_info <- cycles[cycles$cycle_num == as.character(cycle_num), ]
  component_id <- cycle_info$component_id[1]

  # Create cycle directory
  if (!dry_run) {
    dir.create(cycle_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Track results
  result <- list(
    cycle = cycle_name,
    total_files = nrow(files),
    new_files = 0,
    existing_files = 0,
    failed_files = 0,
    files = data.frame()
  )

  if (nrow(files) == 0) {
    cat("  No files found\n")
    return(result)
  }

  # Process each file
  for (i in 1:nrow(files)) {
    file_path <- file.path(cycle_dir, files$name[i])
    file_exists <- file.exists(file_path)

    status <- if (file_exists && !overwrite) {
      "exists"
    } else if (file_exists && overwrite) {
      "redownload"
    } else {
      "new"
    }

    cat("  [", status, "]", files$name[i])

    # Download if needed
    if (status %in% c("new", "redownload")) {
      if (dry_run) {
        cat(" (would download)\n")
        result$new_files <- result$new_files + 1
      } else {
        if (osf_download_file(files$id[i], file_path, overwrite = overwrite, component_id = component_id)) {
          cat(" ✓\n")
          result$new_files <- result$new_files + 1
        } else {
          cat(" ✗ FAILED\n")
          result$failed_files <- result$failed_files + 1
        }
      }
    } else {
      cat("\n")
      result$existing_files <- result$existing_files + 1
    }

    Sys.sleep(0.2)  # Rate limiting
  }

  # Add file inventory to result
  result$files <- files[, c("name", "size", "modified")]

  return(result)
}

#' Download all CHMS files (convenience wrapper)
#' @param target_dir Target directory
#' @param overwrite Whether to overwrite existing files
download_all_chms <- function(target_dir = "chms-osf-docs", overwrite = FALSE) {
  sync_chms_structure(
    target_dir = target_dir,
    dry_run = FALSE,
    overwrite = overwrite
  )
}

#' Check CHMS sync status
#' @param target_dir CHMS mirror directory
#' @return data.frame with sync status
check_chms_sync_status <- function(target_dir = "chms-osf-docs") {

  if (!dir.exists(target_dir)) {
    cat("CHMS mirror not found at:", target_dir, "\n")
    cat("Run sync_chms_structure() to create it.\n")
    return(invisible(NULL))
  }

  cat("=== CHMS SYNC STATUS ===\n\n")

  cycles <- get_chms_cycles()
  status_list <- list()

  for (i in 1:nrow(cycles)) {
    cycle_name <- paste0("Cycle", cycles$cycle_num[i])
    cycle_dir <- file.path(target_dir, cycle_name)

    # Get expected files from OSF
    osf_files <- get_chms_cycle_files(cycles$cycle_num[i])
    osf_files <- osf_files[osf_files$kind == "file", ]

    # Check local files
    if (dir.exists(cycle_dir)) {
      local_files <- list.files(cycle_dir)
      n_local <- length(local_files)
    } else {
      local_files <- character(0)
      n_local <- 0
    }

    n_expected <- nrow(osf_files)
    n_missing <- n_expected - n_local

    status <- if (n_local == n_expected) {
      "complete"
    } else if (n_local == 0) {
      "not synced"
    } else {
      "partial"
    }

    cat(sprintf("%-8s | %8s | %2d/%2d files | %s\n",
                cycle_name, status, n_local, n_expected,
                if (n_missing > 0) paste(n_missing, "missing") else ""))

    status_list[[cycle_name]] <- list(
      cycle = cycle_name,
      status = status,
      local_files = n_local,
      expected_files = n_expected,
      missing_files = n_missing
    )
  }

  return(invisible(status_list))
}

cat("\nCHMS Sync System loaded.\n")
cat("Available functions:\n")
cat("- sync_chms_structure(): Sync all CHMS files from OSF\n")
cat("- sync_chms_cycle(cycle_num): Sync a specific cycle\n")
cat("- download_all_chms(): Download all CHMS files\n")
cat("- check_chms_sync_status(): Check local sync status\n")
