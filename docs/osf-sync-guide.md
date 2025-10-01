# OSF.io Synchronization Guide

Complete guide to synchronizing CCHS documentation from OSF.io.

## 🎯 Overview

The OSF sync system maintains a read-only mirror of CCHS documentation from OSF.io, providing:
- **Complete file downloads** from OSF project 6p3n9
- **Metadata tracking** for all years 2001-2023
- **Change detection** via git-based comparison
- **Incremental updates** to minimize bandwidth

## 🔧 Setup

### 1. OSF Authentication

Create a `.env` file in the project root:

```bash
# .env
OSF_PAT=your_personal_access_token_here
OSF_PROJECT_ID=6p3n9
```

**Getting an OSF Personal Access Token**:
1. Log in to OSF.io
2. Go to Settings → Personal Access Tokens
3. Create new token with read permissions
4. Copy token to `.env` file

**Security**: Never commit `.env` to Git (already in `.gitignore`)

### 2. Configuration

The `config.yml` file contains OSF project details:

```yaml
default:
  osf:
    project_id: "6p3n9"
    documentation_component_id: "jm8bx"
    base_url: "https://api.osf.io/v2"
```

### 3. R Dependencies

```r
install.packages(c("httr", "jsonlite", "yaml", "dplyr", "config"))
```

## 📥 Sync Workflows

### Full Synchronization

Download all files from OSF.io:

```r
# Load sync system
source("R/osf_sync_system.R")

# Full sync (all years)
sync_results <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  years = 2001:2023,
  dry_run = FALSE  # Set TRUE to preview without downloading
)

# Review results
print(sync_results$summary)
```

**Duration**: ~10-15 minutes for full sync
**Bandwidth**: ~166 MB total

### Incremental Sync

Update only changed years:

```r
# Detect changes first
source("R/osf_versioning_system.R")
changes <- detect_changes_with_git()

# Sync only years with changes
changed_years <- names(changes)[sapply(changes, function(x) x$has_changes)]

if (length(changed_years) > 0) {
  sync_results <- sync_osf_structure(
    target_dir = "cchs-osf-docs",
    years = as.numeric(changed_years),
    dry_run = FALSE
  )
}
```

**Duration**: ~1-2 minutes typically
**Bandwidth**: Only changed files

### Single Year Sync

Download or update specific year:

```r
# Download 2023 files
source("R/osf_sync_system.R")

sync_results <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  years = 2023,
  dry_run = FALSE
)
```

## 🔍 Change Detection

### Git-Based Change Detection

```r
# Initialize git tracking (first time only)
source("R/osf_versioning_system.R")
repo <- init_osf_versioning()

# Create baseline commit
baseline_sha <- create_baseline_commit()

# Detect changes since last commit
changes <- detect_changes_with_git(base_commit = "HEAD~1")

# Review changes
for (year in names(changes)) {
  if (changes[[year]]$has_changes) {
    cat(sprintf("\n%s Changes:\n", year))
    cat("Added:", length(changes[[year]]$added), "\n")
    cat("Removed:", length(changes[[year]]$removed), "\n")
    cat("Modified:", length(changes[[year]]$modified), "\n")
  }
}
```

### Metadata Comparison

```r
# Compare metadata without git
source("R/osf_sync_system.R")

# Get current OSF metadata
current_metadata <- get_osf_year_metadata(2023)

# Load baseline metadata
baseline_metadata <- yaml::read_yaml("cchs-osf-docs/osf-metadata/OSF_STRUCTURE_2023.yaml")

# Compare
new_files <- setdiff(names(current_metadata$files), names(baseline_metadata$files))
removed_files <- setdiff(names(baseline_metadata$files), names(current_metadata$files))

cat("New files:", length(new_files), "\n")
cat("Removed files:", length(removed_files), "\n")
```

## 🔄 Automated Workflows

### Complete Sync Workflow

```r
# End-to-end workflow with reporting
source("R/osf_versioning_system.R")

results <- run_complete_workflow()

# This automatically:
# 1. Detects changes
# 2. Downloads updated files
# 3. Updates metadata
# 4. Commits changes to git
# 5. Generates report
```

### Scheduled Sync

```r
# Weekly sync script (cron job example)
# Save as: scripts/weekly_sync.R

library(here)
setwd(here())

source("R/osf_versioning_system.R")

# Run complete workflow
results <- run_complete_workflow()

# Save log
log_file <- sprintf("logs/sync_%s.log", Sys.Date())
writeLines(capture.output(print(results)), log_file)
```

**Cron entry** (Sunday 6 AM):
```bash
0 6 * * 0 cd /path/to/cchsflow-docs && Rscript scripts/weekly_sync.R
```

## 📊 Monitoring & Reporting

### Generate Sync Report

```r
# Render Quarto report
library(quarto)

quarto_render("cchs_osf_download_report.qmd")
quarto_render("sync_workflow.qmd")
```

### Check Sync Status

```r
# Quick status check
source("R/osf_sync_system.R")

# Get file counts
local_files <- list.files("cchs-osf-docs", recursive = TRUE)
cat("Local files:", length(local_files), "\n")

# Check specific year
year_files <- list.files("cchs-osf-docs/2023", recursive = TRUE)
cat("2023 files:", length(year_files), "\n")

# Load metadata
metadata_2023 <- yaml::read_yaml("cchs-osf-docs/osf-metadata/OSF_STRUCTURE_2023.yaml")
cat("Expected 2023 files:", length(metadata_2023$files), "\n")
```

## 🛠️ Troubleshooting

### Authentication Errors

```r
# Test OSF authentication
source("R/osf_api_client.R")

response <- test_osf_authentication()

if (response$status_code == 200) {
  cat("✅ Authentication successful\n")
} else {
  cat("❌ Authentication failed\n")
  cat("Status:", response$status_code, "\n")
  cat("Check your OSF_PAT in .env file\n")
}
```

### Missing Files

```r
# Verify all expected files exist
source("R/osf_sync_system.R")

# For specific year
year <- 2023
metadata <- yaml::read_yaml(sprintf("cchs-osf-docs/osf-metadata/OSF_STRUCTURE_%d.yaml", year))

# Check each file
missing <- c()
for (file_id in names(metadata$files)) {
  file_path <- metadata$files[[file_id]]$path
  full_path <- file.path("cchs-osf-docs", file_path)

  if (!file.exists(full_path)) {
    missing <- c(missing, full_path)
  }
}

if (length(missing) > 0) {
  cat("Missing files:\n")
  cat(paste("-", missing, collapse = "\n"), "\n")

  # Re-download missing files
  sync_results <- sync_osf_structure(
    target_dir = "cchs-osf-docs",
    years = year,
    dry_run = FALSE
  )
}
```

### Pagination Issues

The custom OSF API client handles pagination correctly (unlike `osfr` which had limitations):

```r
# Test pagination handling
source("R/osf_api_client.R")

# Get all files (handles pagination automatically)
files <- get_osf_folder_contents(
  folder_id = "your_folder_id",
  recursive = TRUE
)

cat("Total files retrieved:", length(files), "\n")
# Should get ALL files, not just first 10
```

### Slow Downloads

```r
# Download with progress tracking
source("R/osf_sync_system.R")

# Enable verbose output
options(osf_sync_verbose = TRUE)

sync_results <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  years = 2023,
  dry_run = FALSE
)

# Progress shown in console
```

## 📁 Directory Structure

After sync, your directory structure will be:

```
cchs-osf-docs/
├── osf-metadata/
│   ├── OSF_STRUCTURE_2001.yaml
│   ├── OSF_STRUCTURE_2003.yaml
│   ├── ...
│   └── OSF_STRUCTURE_2023.yaml
├── 2001/
│   └── 1.1/
│       └── Master/
│           ├── Docs/
│           └── Layout/
├── 2003/
│   └── 2.1/
│       ├── Master/
│       └── Share/
├── ...
└── 2023/
    └── 12-Month/
        └── Master/
            ├── Docs/
            └── Layout/
```

## 🔐 Security Best Practices

1. **Never commit** `.env` file
2. **Use read-only** OSF tokens when possible
3. **Rotate tokens** periodically
4. **Restrict** token permissions to minimum needed
5. **Keep** tokens out of code and logs

## 📊 Sync Statistics

### Current Repository State

- **Total files**: 1,262 files
- **Years**: 19 (2001-2023)
- **Total size**: ~166 MB
- **Metadata files**: 19 YAML files

### Typical Sync Times

| Operation | Duration | Bandwidth |
|-----------|----------|-----------|
| Full sync (all years) | 10-15 min | ~166 MB |
| Single year | 1-2 min | ~5-10 MB |
| Incremental (1-2 years) | 1-3 min | ~10-20 MB |
| Change detection | <10 sec | <1 MB |
| Metadata update only | <1 min | <1 MB |

## 🚀 Advanced Usage

### Custom Sync Function

```r
# Sync with custom filters
custom_sync <- function(years, file_pattern = NULL) {
  source("R/osf_sync_system.R")

  for (year in years) {
    cat(sprintf("Syncing %d...\n", year))

    # Get metadata
    metadata <- get_osf_year_metadata(year)

    # Filter files if pattern provided
    if (!is.null(file_pattern)) {
      metadata$files <- metadata$files[
        grepl(file_pattern, names(metadata$files), ignore.case = TRUE)
      ]
    }

    # Download filtered files
    download_year_files(year, force = TRUE)
  }
}

# Example: Sync only questionnaires for recent years
custom_sync(2020:2023, file_pattern = "questionnaire")
```

### Parallel Downloads

```r
# Download multiple years in parallel
library(parallel)

source("R/osf_sync_system.R")

years <- 2020:2023

# Setup cluster
cl <- makeCluster(detectCores() - 1)

# Export functions to cluster
clusterEvalQ(cl, {
  source("R/osf_sync_system.R")
})

# Parallel sync
results <- parLapply(cl, years, function(year) {
  sync_osf_structure(
    target_dir = "cchs-osf-docs",
    years = year,
    dry_run = FALSE
  )
})

# Cleanup
stopCluster(cl)
```

## 📚 Related Documentation

- [Architecture](architecture.md) - System design
- [Collections Guide](collections-guide.md) - Creating collections from synced files
- [Glossary](glossary.md) - CCHS terminology

## 📧 Getting Help

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/cchsflow-docs/issues)
- **Bug Reports**: Use [Bug Report template](../.github/ISSUE_TEMPLATE/bug_report.md)
- **Documentation**: Use [Documentation template](../.github/ISSUE_TEMPLATE/documentation.md)

---

**Next Steps**: After syncing, see [Collections Guide](collections-guide.md) to create themed collections.
