# CCHS OSF.io Versioning and Sync System
# ==============================================
# A git-based versioning system for tracking OSF.io changes and automating sync operations
# Uses git commits to track metadata changes and automated QMD report generation

library(httr)
library(jsonlite)
library(yaml)
library(here)
library(git2r)

# Global Configuration
OSF_METADATA_DIR <- "cchs-osf-docs/osf-metadata"
REPORTS_DIR <- "reports"
OSF_BASE_URL <- "https://api.osf.io/v2"
OSF_NODE_ID <- "jm8bx"

#' Initialize Git Repository for OSF Versioning
#' 
#' Sets up git tracking for the OSF metadata directory
#' @param force_init Force re-initialization if repo already exists
#' @export
init_osf_versioning <- function(force_init = FALSE) {
  cat("=== INITIALIZING OSF VERSIONING SYSTEM ===\n")
  
  # Check if cchs-osf-docs is already a git repo
  repo_path <- here("cchs-osf-docs")
  
  if (!dir.exists(repo_path)) {
    stop("cchs-osf-docs directory not found. Please ensure OSF sync has been run.")
  }
  
  # Initialize git repo if needed
  if (!dir.exists(file.path(repo_path, ".git")) || force_init) {
    cat("🔧 Initializing git repository in cchs-osf-docs/\n")
    
    # Initialize repo
    repo <- init(repo_path)
    
    # Create .gitignore for large data files but track metadata
    gitignore_content <- "# Ignore large data files but track structure
*.pdf
*.doc
*.docx
*.mdb
*.sas
*.sps
*.do
*.dct
*.log

# Keep metadata and documentation
!osf-metadata/
!README.md
!CHANGELOG.md
"
    writeLines(gitignore_content, file.path(repo_path, ".gitignore"))
    
    # Add initial files
    add(repo, "osf-metadata/")
    add(repo, ".gitignore")
    
    # Initial commit
    commit(repo, message = "Initial OSF metadata tracking setup

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>")
    
    cat("✅ Git repository initialized\n")
  } else {
    repo <- repository(repo_path)
    cat("✅ Using existing git repository\n")
  }
  
  return(repo)
}

#' Create Baseline Commit for Current OSF State
#' 
#' Commits current metadata state as baseline for comparison
#' @param commit_message Custom commit message
#' @export
create_baseline_commit <- function(commit_message = NULL) {
  cat("=== CREATING BASELINE COMMIT ===\n")
  
  repo <- repository(here("cchs-osf-docs"))
  
  # Update all metadata files first
  cat("📡 Updating metadata for all years...\n")
  source(here("R/osf_sync_system.R"))
  
  for (year in 2001:2023) {
    cat(sprintf("  Updating %d...", year))
    tryCatch({
      update_osf_metadata(year, metadata_dir = OSF_METADATA_DIR, backup_old = FALSE)
      cat(" ✅\n")
    }, error = function(e) {
      cat(sprintf(" ❌ Error: %s\n", e$message))
    })
  }
  
  # Stage all metadata changes
  add(repo, "osf-metadata/")
  
  # Create timestamp
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC")
  
  if (is.null(commit_message)) {
    commit_message <- sprintf("Baseline OSF metadata snapshot - %s

Complete metadata update for all years (2001-2023)
- Updated YAML structure files
- Captured file counts and sizes
- Ready for change detection workflows

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>", timestamp)
  }
  
  # Commit changes
  commit_obj <- commit(repo, message = commit_message)
  commit_sha <- commit_obj$sha
  
  cat(sprintf("✅ Baseline commit created: %s\n", substr(commit_sha, 1, 8)))
  return(commit_sha)
}

#' Detect Changes Using Git Diff
#' 
#' Compare current OSF state with previous git commit to detect changes
#' @param base_commit Git commit SHA to compare against (default: HEAD~1)
#' @param target_years Specific years to check (default: all)
#' @export
detect_changes_with_git <- function(base_commit = "HEAD~1", target_years = 2001:2023) {
  cat("=== GIT-BASED CHANGE DETECTION ===\n")
  
  repo <- repository(here("cchs-osf-docs"))
  
  # Update current metadata
  cat("📡 Updating current OSF metadata...\n")
  source(here("R/osf_sync_system.R"))
  
  changes_detected <- list()
  
  for (year in target_years) {
    cat(sprintf("🔍 Checking %d...\n", year))
    
    # Update current metadata
    update_osf_metadata(year, metadata_dir = OSF_METADATA_DIR, backup_old = FALSE)
    
    # Get git diff for this year's metadata file
    metadata_file <- sprintf("osf-metadata/osf_structure_%d.yaml", year)
    
    tryCatch({
      # Get diff between commits
      diff_output <- system2("git", 
                             args = c("diff", base_commit, "HEAD", "--", metadata_file),
                             cwd = here("cchs-osf-docs"),
                             stdout = TRUE,
                             stderr = TRUE)
      
      if (length(diff_output) > 0 && !all(diff_output == "")) {
        # Parse changes from diff
        added_files <- grep("^\\+.*name:", diff_output, value = TRUE)
        removed_files <- grep("^\\-.*name:", diff_output, value = TRUE)
        
        changes_detected[[as.character(year)]] <- list(
          year = year,
          has_changes = TRUE,
          added_count = length(added_files),
          removed_count = length(removed_files),
          diff_output = diff_output
        )
        
        cat(sprintf("  ⚠️  Changes detected: +%d, -%d\n", 
                   length(added_files), length(removed_files)))
      } else {
        changes_detected[[as.character(year)]] <- list(
          year = year,
          has_changes = FALSE,
          added_count = 0,
          removed_count = 0
        )
        cat("  ✅ No changes\n")
      }
      
    }, error = function(e) {
      cat(sprintf("  ❌ Error checking %d: %s\n", year, e$message))
      changes_detected[[as.character(year)]] <- list(
        year = year,
        has_changes = NA,
        error = e$message
      )
    })
  }
  
  return(changes_detected)
}

#' Automated Sync Validation Workflow
#' 
#' Complete workflow to validate sync status and pull missing files
#' @param auto_download Automatically download missing files
#' @param commit_changes Commit any new files to git
#' @export
automated_sync_validation <- function(auto_download = TRUE, commit_changes = TRUE) {
  cat("=== AUTOMATED SYNC VALIDATION WORKFLOW ===\n")
  
  # Initialize git if needed
  repo <- init_osf_versioning()
  
  # Detect changes
  changes <- detect_changes_with_git()
  
  # Analyze changes
  years_with_changes <- sapply(changes, function(x) x$has_changes %in% TRUE)
  total_changes <- sum(years_with_changes, na.rm = TRUE)
  
  if (total_changes > 0) {
    cat(sprintf("⚠️  %d years have detected changes\n", total_changes))
    
    if (auto_download) {
      cat("🔄 Auto-downloading missing files...\n")
      source(here("R/osf_sync_system.R"))
      
      for (year_str in names(changes)[years_with_changes]) {
        year <- as.numeric(year_str)
        cat(sprintf("  📥 Updating %d...\n", year))
        
        tryCatch({
          download_year_files(year, force = TRUE)
          cat(sprintf("  ✅ %d updated\n", year))
        }, error = function(e) {
          cat(sprintf("  ❌ Failed to update %d: %s\n", year, e$message))
        })
      }
      
      # Update metadata after downloads
      for (year_str in names(changes)[years_with_changes]) {
        year <- as.numeric(year_str)
        update_osf_metadata(year, metadata_dir = OSF_METADATA_DIR, backup_old = FALSE)
      }
      
      if (commit_changes) {
        # Stage and commit new files
        add(repo, ".")
        
        commit_message <- sprintf("Automated sync update - %s

Updated %d years with OSF.io changes:
%s

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>", 
                                format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                                total_changes,
                                paste(names(changes)[years_with_changes], collapse = ", "))
        
        commit(repo, message = commit_message)
        cat("✅ Changes committed to git\n")
      }
    }
  } else {
    cat("✅ All years are synchronized with OSF.io\n")
  }
  
  # Generate updated report
  generate_sync_report(changes)
  
  return(changes)
}

#' Generate Parameterized QMD Sync Report
#' 
#' Creates a standardized report from current sync status
#' @param changes_data Change detection results
#' @param output_file Output filename
#' @export
generate_sync_report <- function(changes_data = NULL, output_file = NULL) {
  cat("=== GENERATING SYNC REPORT ===\n")
  
  if (is.null(output_file)) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    output_file <- file.path(REPORTS_DIR, sprintf("osf_sync_report_%s.qmd", timestamp))
  }
  
  # Ensure reports directory exists
  if (!dir.exists(REPORTS_DIR)) {
    dir.create(REPORTS_DIR, recursive = TRUE)
  }
  
  # Get current sync status if not provided
  if (is.null(changes_data)) {
    source(here("R/osf_sync_system.R"))
    changes_data <- detect_all_osf_changes(years = 2001:2023, metadata_dir = OSF_METADATA_DIR)
  }
  
  # Create parameterized QMD template
  qmd_template <- '---
title: "CCHS OSF.io Sync Report"
subtitle: "Automated Synchronization Status and Change Detection"
author: "CCHS Documentation System"
date: "`r Sys.Date()`"
format:
  html:
    toc: true
    toc-depth: 3
    number-sections: true
    theme: cosmo
    code-fold: true
    code-summary: "Show R Code"
execute:
  echo: false
  warning: false
  message: false
params:
  report_timestamp: "`r Sys.time()`"
  metadata_dir: "cchs-osf-docs/osf-metadata"
---

```{r setup}
#| include: false
library(gt)
library(dplyr)
library(yaml)
library(stringr)

# Load sync functions
source(here::here("R/osf_sync_system.R"))
source(here::here("R/osf_versioning_system.R"))
```

```{r load-data}
#| include: false

# Get current sync status
cat("Loading current sync status...\\n")
sync_status <- detect_all_osf_changes(years = 2001:2023, 
                                     metadata_dir = params$metadata_dir)

# Calculate summary statistics
total_years <- length(sync_status)
years_with_changes <- sum(sapply(sync_status, function(x) {
  length(x$added) + length(x$removed) + length(x$modified) > 0
}), na.rm = TRUE)

total_added <- sum(sapply(sync_status, function(x) length(x$added)), na.rm = TRUE)
total_removed <- sum(sapply(sync_status, function(x) length(x$removed)), na.rm = TRUE)
total_modified <- sum(sapply(sync_status, function(x) length(x$modified)), na.rm = TRUE)

# Create summary table
sync_summary <- data.frame()
for(year in 2001:2023) {
  year_str <- as.character(year)
  if(year_str %in% names(sync_status)) {
    result <- sync_status[[year_str]]
    sync_summary <- rbind(sync_summary, data.frame(
      year = year,
      baseline_files = result$baseline_count %||% 0,
      current_files = result$current_count %||% 0,
      added = length(result$added %||% character(0)),
      removed = length(result$removed %||% character(0)),
      modified = length(result$modified %||% character(0)),
      status = ifelse(length(result$added) + length(result$removed) + length(result$modified) == 0,
                     "✅ Synced", "⚠️ Changes Detected"),
      stringsAsFactors = FALSE
    ))
  }
}
```

# Executive Summary

This report provides an automated analysis of the CCHS OSF.io synchronization status as of **`r params$report_timestamp`**.

## Key Metrics

- **Total Years Monitored**: `r total_years`
- **Years with Changes**: `r years_with_changes`
- **Files Added**: `r total_added`
- **Files Removed**: `r total_removed`
- **Files Modified**: `r total_modified`

```{r sync-status-table}
sync_summary %>%
  mutate(
    total_changes = added + removed + modified,
    change_indicator = case_when(
      total_changes == 0 ~ "✅ No Changes",
      added > 0 ~ sprintf("🆕 +%d files", added),
      removed > 0 ~ sprintf("🗑️ -%d files", removed),
      modified > 0 ~ sprintf("📝 %d modified", modified),
      TRUE ~ "❓ Unknown"
    )
  ) %>%
  select(year, baseline_files, current_files, change_indicator, status) %>%
  gt() %>%
  tab_header(
    title = "OSF.io Synchronization Status",
    subtitle = sprintf("Change detection results as of %s", params$report_timestamp)
  ) %>%
  cols_label(
    year = "Year",
    baseline_files = "Baseline Files",
    current_files = "Current Files",
    change_indicator = "Changes",
    status = "Sync Status"
  ) %>%
  tab_style(
    style = cell_fill(color = "#f8d7da"),
    locations = cells_body(
      rows = status == "⚠️ Changes Detected"
    )
  ) %>%
  tab_style(
    style = cell_fill(color = "#d1ecf1"),
    locations = cells_body(
      rows = status == "✅ Synced"
    )
  ) %>%
  tab_options(
    table.font.size = px(12)
  )
```

```{r detailed-changes}
#| eval: !expr years_with_changes > 0

if(years_with_changes > 0) {
  cat("# Detailed Changes\\n\\n")
  
  for(year in 2001:2023) {
    year_str <- as.character(year)
    if(year_str %in% names(sync_status)) {
      result <- sync_status[[year_str]]
      total_changes <- length(result$added) + length(result$removed) + length(result$modified)
      
      if(total_changes > 0) {
        cat(sprintf("## %d Changes\\n\\n", year))
        
        if(length(result$added) > 0) {
          cat("**Added Files:**\\n")
          for(file in result$added) {
            cat(sprintf("- 🆕 %s\\n", file))
          }
        }
        
        if(length(result$removed) > 0) {
          cat("**Removed Files:**\\n")
          for(file in result$removed) {
            cat(sprintf("- 🗑️ %s\\n", file))
          }
        }
        
        if(length(result$modified) > 0) {
          cat("**Modified Files:**\\n")
          for(file in result$modified) {
            cat(sprintf("- 📝 %s\\n", file))
          }
        }
        cat("\\n")
      }
    }
  }
}
```

```{r recommendations}
if(years_with_changes > 0) {
  cat("# Recommended Actions\\n\\n")
  cat("```r\\n")
  cat("# Update changed years\\n")
  for(year in 2001:2023) {
    year_str <- as.character(year)
    if(year_str %in% names(sync_status)) {
      result <- sync_status[[year_str]]
      if(length(result$added) + length(result$removed) + length(result$modified) > 0) {
        cat(sprintf("download_year_files(%d, force = TRUE)\\n", year))
      }
    }
  }
  cat("\\n# Commit changes\\n")
  cat("create_baseline_commit(\\"Sync update after change detection\\")\\n")
  cat("```\\n")
} else {
  cat("# System Status\\n\\n")
  cat(":::{.callout-tip}\\n")
  cat("## Perfect Synchronization\\n")
  cat("All years are perfectly synchronized with OSF.io. No action required.\\n")
  cat(":::...\\n")
}
```

---

**Report Generated**: `r Sys.time()`  
**System**: CCHS OSF.io Versioning System  
**Status**: Automated Pipeline Active
'

  # Write QMD file
  writeLines(qmd_template, output_file)
  
  cat(sprintf("✅ Report generated: %s\n", output_file))
  return(output_file)
}

#' Complete Sync and Report Workflow
#' 
#' End-to-end workflow for checking, syncing, and reporting
#' @export
run_complete_workflow <- function() {
  cat("=== COMPLETE OSF SYNC WORKFLOW ===\n")
  
  # 1. Initialize versioning
  init_osf_versioning()
  
  # 2. Run automated validation
  changes <- automated_sync_validation(auto_download = TRUE, commit_changes = TRUE)
  
  # 3. Generate report
  report_file <- generate_sync_report(changes)
  
  # 4. Summary
  years_changed <- sum(sapply(changes, function(x) x$has_changes %in% TRUE), na.rm = TRUE)
  
  cat("\n=== WORKFLOW COMPLETE ===\n")
  cat(sprintf("📊 Years checked: %d\n", length(changes)))
  cat(sprintf("⚠️  Years with changes: %d\n", years_changed))
  cat(sprintf("📄 Report: %s\n", report_file))
  cat("✅ All operations completed successfully\n")
  
  return(list(
    changes = changes,
    report_file = report_file,
    years_changed = years_changed
  ))
}

# Helper function for null coalescing
`%||%` <- function(x, y) if(is.null(x)) y else x

cat("=== OSF VERSIONING SYSTEM LOADED ===\n")
cat("Main functions:\n")
cat("1. init_osf_versioning()                    # Initialize git tracking\n")
cat("2. create_baseline_commit()                 # Create metadata baseline\n") 
cat("3. detect_changes_with_git()                # Git-based change detection\n")
cat("4. automated_sync_validation()              # Complete sync validation\n")
cat("5. generate_sync_report()                   # Generate QMD report\n")
cat("6. run_complete_workflow()                  # End-to-end workflow\n")
cat("\n")
cat("Example workflow:\n")
cat("- init_osf_versioning()                     # Setup git tracking\n")
cat("- create_baseline_commit()                  # Create baseline\n")
cat("- automated_sync_validation()               # Check and sync\n")
cat("- generate_sync_report()                    # Generate report\n")
cat("=== READY FOR AUTOMATED OSF MANAGEMENT ===\n")