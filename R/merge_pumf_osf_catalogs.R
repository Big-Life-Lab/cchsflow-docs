#!/usr/bin/env Rscript
# merge_pumf_osf_catalogs.R
# Phase 4: Merge PUMF catalog with OSF catalog

library(yaml)
library(dplyr)
library(readr)

cat("🔗 Merging PUMF and OSF Catalogs\n")
cat("=================================\n\n")

# Load OSF catalog
cat("Loading OSF catalog...\n")
osf_catalog <- read_yaml("data/catalog/cchs_catalog.yaml")
osf_files <- bind_rows(osf_catalog$files)
cat("  OSF files:", nrow(osf_files), "\n")

# Load PUMF catalog
cat("Loading PUMF catalog...\n")
pumf_catalog <- read_yaml("data/catalog/cchs_catalog_pumf.yaml")
pumf_files <- bind_rows(pumf_catalog$files)
cat("  PUMF files:", nrow(pumf_files), "\n")

# Check for UID conflicts
cat("\n🔍 Checking for UID conflicts...\n")
osf_uids <- osf_files$cchs_uid
pumf_uids <- pumf_files$cchs_uid
conflicts <- intersect(osf_uids, pumf_uids)

if (length(conflicts) > 0) {
  cat("⚠️  WARNING: Found", length(conflicts), "conflicting UIDs!\n")
  cat("\nConflicts:\n")
  print(conflicts)
  stop("Cannot merge: UID conflicts detected")
} else {
  cat("✅ No UID conflicts detected\n")
}

# Merge files
cat("\n📦 Merging file lists...\n")
merged_files <- bind_rows(osf_files, pumf_files)
cat("  Total merged files:", nrow(merged_files), "\n")

# Verify uniqueness
cat("\n🔍 Verifying UID uniqueness...\n")
uid_counts <- merged_files %>%
  count(cchs_uid) %>%
  filter(n > 1)

if (nrow(uid_counts) > 0) {
  cat("⚠️  WARNING: Found", nrow(uid_counts), "duplicate UIDs after merge!\n")
  print(uid_counts)
  stop("Merge failed: duplicate UIDs detected")
} else {
  cat("✅ All UIDs are unique\n")
}

# Summary statistics
cat("\n📊 Merged Catalog Summary:\n")
cat("  Total files:", nrow(merged_files), "\n")
cat("  Unique UIDs:", n_distinct(merged_files$cchs_uid), "\n")
cat("  Years covered:", min(merged_files$year), "-", max(merged_files$year), "\n")

cat("\n📋 Files by Source:\n")
source_summary <- merged_files %>%
  count(source, sort = TRUE)
print(source_summary)

cat("\n📋 Files by Doc Type:\n")
doc_type_summary <- merged_files %>%
  count(doc_type, sort = TRUE)
print(doc_type_summary)

cat("\n📋 Files by Category (top 10):\n")
category_summary <- merged_files %>%
  count(category, sort = TRUE)
print(category_summary, n = 10)

# Convert back to list format for YAML
catalog_list <- list()
for (i in 1:nrow(merged_files)) {
  entry <- as.list(merged_files[i, ])
  # Convert numeric to appropriate types
  entry$sequence <- as.integer(entry$sequence)
  entry$file_size <- as.numeric(entry$file_size)
  # Remove NA values
  entry <- entry[!is.na(entry)]
  catalog_list[[i]] <- entry
}

# Create merged catalog metadata
merged_metadata <- list(
  version = "v3.0.0",
  created_date = as.character(Sys.Date()),
  last_updated = as.character(Sys.Date()),
  total_files = length(catalog_list),
  years_covered = paste0(min(merged_files$year), "-", max(merged_files$year)),
  uid_system_version = "3.0.0",
  data_sources = list("osf", "pumf"),
  namespaces = osf_catalog$catalog_metadata$namespaces,
  field_descriptions = osf_catalog$catalog_metadata$field_descriptions,
  generation_formulas = osf_catalog$catalog_metadata$generation_formulas
)

# Create final catalog
final_catalog <- list(
  catalog_metadata = merged_metadata,
  files = catalog_list
)

# Write merged catalog
output_file <- "data/catalog/cchs_catalog_merged.yaml"
cat("\nWriting merged catalog to", output_file, "...\n")
write_yaml(final_catalog, output_file)

cat("\n✅ Phase 4 complete!\n")
cat("✅ Merged catalog created successfully\n")
cat("\nNext: Validate merged catalog and backup cchs_catalog.yaml\n")
