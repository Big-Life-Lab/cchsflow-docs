#!/usr/bin/env Rscript
# migrate_catalog_to_v3.R
# Migrate catalog from v3.0.0 (old structure) to v3.0.0 (new namespace structure)
# Adds source_namespace and source_filepath fields to all entries

library(yaml)
library(dplyr)
library(purrr)

# Read current catalog
catalog_path <- "data/catalog/cchs_catalog.yaml"
cat("Reading catalog:", catalog_path, "\n")
catalog <- yaml::read_yaml(catalog_path)

# Migration function for each file entry
migrate_file_entry <- function(file_entry) {
  # Add new fields based on existing osf_path
  file_entry$source_namespace <- "osf_cchs_docs"
  file_entry$source_filepath <- file_entry$osf_path

  # Remove deprecated fields (breaking change, but project is new)
  file_entry$local_path <- NULL
  file_entry$osf_path <- NULL
  file_entry$pumf_path <- NULL

  return(file_entry)
}

# Migrate all file entries
cat("Migrating", length(catalog$files), "file entries...\n")
catalog$files <- map(catalog$files, migrate_file_entry)

# Update metadata
catalog$catalog_metadata$last_updated <- as.character(Sys.Date())
catalog$catalog_metadata$migration_note <- "Added source_namespace and source_filepath fields for v3.0.0 namespace system"

# Write updated catalog
cat("Writing updated catalog...\n")
yaml::write_yaml(
  catalog,
  catalog_path,
  handlers = list(
    logical = function(x) {
      result <- ifelse(x, "true", "false")
      class(result) <- "verbatim"
      return(result)
    }
  )
)

cat("✓ Migration complete!\n")
cat("  - Updated", length(catalog$files), "file entries\n")
cat("  - Added source_namespace field (all set to 'osf_cchs_docs')\n")
cat("  - Added source_filepath field (copied from osf_path)\n")
cat("  - Removed deprecated fields (local_path, osf_path, pumf_path)\n")
