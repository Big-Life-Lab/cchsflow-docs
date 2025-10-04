#!/usr/bin/env Rscript
# deduplicate_osf_catalog.R
# Fix pre-existing duplicates in OSF catalog before merging with PUMF

library(yaml)
library(dplyr)
library(readr)

cat("🧹 Deduplicating OSF Catalog\n")
cat("============================\n\n")

# Load OSF catalog
catalog <- read_yaml("data/catalog/cchs_catalog.yaml")
files_df <- bind_rows(catalog$files)

cat("Original OSF catalog files:", nrow(files_df), "\n")

# Find duplicates
duplicates <- files_df %>%
  group_by(cchs_uid) %>%
  filter(n() > 1) %>%
  ungroup()

cat("Duplicate UIDs:", n_distinct(duplicates$cchs_uid), "\n")
cat("Total duplicate files:", nrow(duplicates), "\n\n")

# Deduplication strategy: Keep first occurrence (usually Master/Docs)
# These are errata files that appear in multiple folders but are identical
files_dedup <- files_df %>%
  group_by(cchs_uid) %>%
  arrange(source_filepath) %>%
  slice(1) %>%  # Keep first occurrence
  ungroup()

cat("After deduplication:\n")
cat("  Unique files:", nrow(files_dedup), "\n")
cat("  Files removed:", nrow(files_df) - nrow(files_dedup), "\n")

# Verify uniqueness
uid_check <- files_dedup %>%
  count(cchs_uid) %>%
  filter(n > 1)

if (nrow(uid_check) > 0) {
  cat("\n⚠️  WARNING: Still have duplicates!\n")
  print(uid_check)
  stop("Deduplication failed")
} else {
  cat("✅ All UIDs are now unique\n")
}

# Convert back to list format for YAML
catalog_list <- list()
for (i in 1:nrow(files_dedup)) {
  entry <- as.list(files_dedup[i, ])
  # Convert numeric to appropriate types
  entry$sequence <- as.integer(entry$sequence)
  entry$file_size <- as.numeric(entry$file_size)
  # Remove NA values
  entry <- entry[!is.na(entry)]
  catalog_list[[i]] <- entry
}

# Update catalog
catalog$files <- catalog_list
catalog$catalog_metadata$total_files <- length(catalog_list)
catalog$catalog_metadata$last_updated <- as.character(Sys.Date())

# Backup original catalog
backup_file <- "data/catalog/cchs_catalog_pre_dedup.yaml"
cat("\nBacking up original catalog to", backup_file, "...\n")
file.copy("data/catalog/cchs_catalog.yaml", backup_file, overwrite = TRUE)

# Write deduplicated catalog
output_file <- "data/catalog/cchs_catalog.yaml"
cat("Writing deduplicated catalog to", output_file, "...\n")
write_yaml(catalog, output_file)

cat("\n✅ OSF catalog deduplication complete!\n")
cat("✅ Ready to merge with PUMF catalog\n")
