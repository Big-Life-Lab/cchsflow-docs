#!/usr/bin/env Rscript
# deep_validate_catalog.R
# Comprehensive validation of merged PUMF+OSF catalog

library(yaml)
library(dplyr)
library(readr)
library(stringr)

cat("🔍 Deep Catalog Validation\n")
cat("==========================\n\n")

# Load catalog
catalog <- read_yaml("data/catalog/cchs_catalog.yaml")
files_df <- bind_rows(catalog$files)

cat("📊 Loading catalog...\n")
cat("  Total entries:", nrow(files_df), "\n\n")

# ============================================================================
# 1. UID VALIDATION
# ============================================================================
cat("1️⃣  UID VALIDATION\n")
cat("─────────────────\n")

# Check uniqueness
dup_uids <- files_df %>%
  count(cchs_uid) %>%
  filter(n > 1)

if (nrow(dup_uids) > 0) {
  cat("❌ FAIL: Found", nrow(dup_uids), "duplicate UIDs\n")
  print(dup_uids)
} else {
  cat("✅ PASS: All", nrow(files_df), "UIDs are unique\n")
}

# Check UID pattern compliance
uid_pattern <- "^cchs-\\d{4}[sdm]-[msp]-[a-z0-9-]+-[ef]-[a-z0-9]+-\\d{2}$"
invalid_uids <- files_df %>%
  filter(!str_detect(cchs_uid, uid_pattern)) %>%
  select(cchs_uid, year, category)

if (nrow(invalid_uids) > 0) {
  cat("❌ FAIL: Found", nrow(invalid_uids), "UIDs with invalid format\n")
  print(head(invalid_uids, 10))
} else {
  cat("✅ PASS: All UIDs match expected pattern\n")
}

# Check UID consistency with metadata
uid_check <- files_df %>%
  mutate(
    uid_year = str_extract(cchs_uid, "^cchs-(\\d{4})", group = 1),
    uid_temporal = str_extract(cchs_uid, "^cchs-\\d{4}([sdm])", group = 1),
    uid_doctype = str_extract(cchs_uid, "^cchs-\\d{4}[sdm]-([msp])", group = 1),
    uid_lang = str_extract(cchs_uid, "-([ef])-[a-z0-9]+-\\d{2}$", group = 1),

    # Expected values
    expected_temporal = case_when(
      temporal_type == "single" ~ "s",
      temporal_type == "dual" ~ "d",
      temporal_type == "multi" ~ "m"
    ),
    expected_doctype = case_when(
      doc_type == "master" ~ "m",
      doc_type == "share" ~ "s",
      doc_type == "pumf" ~ "p"
    ),
    expected_lang = tolower(substr(language, 1, 1)),

    # Validation
    year_match = uid_year == year,
    temporal_match = uid_temporal == expected_temporal,
    doctype_match = uid_doctype == expected_doctype,
    lang_match = uid_lang == expected_lang
  )

mismatches <- uid_check %>%
  filter(!year_match | !temporal_match | !doctype_match | !lang_match) %>%
  select(cchs_uid, year, uid_year, temporal_type, uid_temporal,
         doc_type, uid_doctype, language, uid_lang)

if (nrow(mismatches) > 0) {
  cat("❌ FAIL: Found", nrow(mismatches), "UIDs inconsistent with metadata\n")
  print(head(mismatches, 10))
} else {
  cat("✅ PASS: All UIDs consistent with metadata fields\n")
}

cat("\n")

# ============================================================================
# 2. REQUIRED FIELDS VALIDATION
# ============================================================================
cat("2️⃣  REQUIRED FIELDS VALIDATION\n")
cat("──────────────────────────────\n")

required_fields <- c("cchs_uid", "year", "temporal_type", "doc_type", "category",
                     "language", "version", "sequence", "filename", "canonical_filename",
                     "source", "source_namespace", "source_filepath", "file_extension")

all_pass <- TRUE
for (field in required_fields) {
  missing <- sum(is.na(files_df[[field]]))
  empty <- sum(files_df[[field]] == "", na.rm = TRUE)
  total_issues <- missing + empty

  if (total_issues > 0) {
    cat("❌", field, ":", total_issues, "missing/empty\n")
    all_pass <- FALSE
  } else {
    cat("✅", field, ": complete\n")
  }
}

cat("\n")

# ============================================================================
# 3. ENUM/CATEGORY VALIDATION
# ============================================================================
cat("3️⃣  ENUM/CATEGORY VALIDATION\n")
cat("────────────────────────────\n")

# Temporal type
valid_temporal <- c("single", "dual", "multi")
invalid_temporal <- files_df %>%
  filter(!temporal_type %in% valid_temporal)
if (nrow(invalid_temporal) > 0) {
  cat("❌ temporal_type:", nrow(invalid_temporal), "invalid values\n")
} else {
  cat("✅ temporal_type: all valid\n")
}

# Doc type
valid_doctype <- c("master", "share", "pumf")
invalid_doctype <- files_df %>%
  filter(!doc_type %in% valid_doctype)
if (nrow(invalid_doctype) > 0) {
  cat("❌ doc_type:", nrow(invalid_doctype), "invalid values\n")
} else {
  cat("✅ doc_type: all valid\n")
}

# Language
valid_lang <- c("EN", "FR")
invalid_lang <- files_df %>%
  filter(!language %in% valid_lang)
if (nrow(invalid_lang) > 0) {
  cat("❌ language:", nrow(invalid_lang), "invalid values\n")
} else {
  cat("✅ language: all valid\n")
}

# Source
valid_source <- c("osf", "pumf")
invalid_source <- files_df %>%
  filter(!source %in% valid_source)
if (nrow(invalid_source) > 0) {
  cat("❌ source:", nrow(invalid_source), "invalid values\n")
} else {
  cat("✅ source: all valid\n")
}

cat("\n")

# ============================================================================
# 4. NAMESPACE VALIDATION
# ============================================================================
cat("4️⃣  NAMESPACE VALIDATION\n")
cat("────────────────────────\n")

valid_namespaces <- names(catalog$catalog_metadata$namespaces)
cat("Valid namespaces:", paste(valid_namespaces, collapse = ", "), "\n")

invalid_ns <- files_df %>%
  filter(!source_namespace %in% valid_namespaces) %>%
  count(source_namespace)

if (nrow(invalid_ns) > 0) {
  cat("❌ FAIL: Found", nrow(invalid_ns), "invalid namespaces\n")
  print(invalid_ns)
} else {
  cat("✅ PASS: All source_namespace values valid\n")
}

# Check namespace consistency with source
ns_source_check <- files_df %>%
  mutate(
    expected_ns = case_when(
      source == "osf" ~ source_namespace %in% c("osf_cchs_docs", "local_osf_mirror"),
      source == "pumf" ~ source_namespace %in% c("gdrive_pumf_collection", "local_pumf_mirror"),
      TRUE ~ FALSE
    )
  ) %>%
  filter(!expected_ns) %>%
  count(source, source_namespace)

if (nrow(ns_source_check) > 0) {
  cat("❌ FAIL: Namespace-source mismatch\n")
  print(ns_source_check)
} else {
  cat("✅ PASS: Namespace consistent with source\n")
}

cat("\n")

# ============================================================================
# 5. DATA INTEGRITY
# ============================================================================
cat("5️⃣  DATA INTEGRITY\n")
cat("──────────────────\n")

# Year range
year_range <- range(as.numeric(files_df$year))
cat("Year range:", year_range[1], "-", year_range[2], "\n")
if (year_range[1] < 2000 || year_range[2] > 2024) {
  cat("⚠️  WARNING: Unusual year range\n")
} else {
  cat("✅ Year range reasonable\n")
}

# Sequence numbers
invalid_seq <- files_df %>%
  filter(sequence < 1 | sequence > 99)
if (nrow(invalid_seq) > 0) {
  cat("❌ sequence:", nrow(invalid_seq), "out of range (1-99)\n")
} else {
  cat("✅ sequence: all in valid range\n")
}

# File extensions
ext_summary <- files_df %>%
  count(file_extension, sort = TRUE)
cat("File extensions found:", n_distinct(files_df$file_extension), "\n")
cat("  Top 5:", paste(head(ext_summary$file_extension, 5), collapse = ", "), "\n")

# Check for suspicious extensions
suspicious_ext <- files_df %>%
  filter(str_detect(file_extension, "[^a-z0-9]") | nchar(file_extension) > 10)
if (nrow(suspicious_ext) > 0) {
  cat("⚠️  WARNING:", nrow(suspicious_ext), "suspicious file extensions\n")
  print(head(suspicious_ext$file_extension, 10))
} else {
  cat("✅ All file extensions look valid\n")
}

cat("\n")

# ============================================================================
# 6. CANONICAL FILENAME VALIDATION
# ============================================================================
cat("6️⃣  CANONICAL FILENAME VALIDATION\n")
cat("──────────────────────────────────\n")

# Check canonical filename format
# Format: cchs_{year}{temporal}_{category}[_{subcategory}]_{doctype}_{lang}_{seq}_v{ver}.{ext}
# Pattern allows optional subcategory (one extra underscore-separated component)
canonical_pattern <- "^cchs_\\d{4}[sdm]_([a-z0-9-]+_){1,2}[msp]_[a-z]+_\\d+_v\\d+\\.[a-z0-9]+$"
invalid_canonical <- files_df %>%
  filter(!str_detect(canonical_filename, canonical_pattern)) %>%
  select(cchs_uid, canonical_filename)

if (nrow(invalid_canonical) > 0) {
  cat("❌ FAIL:", nrow(invalid_canonical), "canonical filenames don't match pattern\n")
  print(head(invalid_canonical, 10))
} else {
  cat("✅ PASS: All canonical filenames match pattern\n")
}

# Check for canonical filename duplicates
dup_canonical <- files_df %>%
  count(canonical_filename) %>%
  filter(n > 1)

if (nrow(dup_canonical) > 0) {
  cat("❌ FAIL:", nrow(dup_canonical), "duplicate canonical filenames\n")
  print(head(dup_canonical, 10))
} else {
  cat("✅ PASS: All canonical filenames unique\n")
}

cat("\n")

# ============================================================================
# 7. CROSS-REFERENCE VALIDATION
# ============================================================================
cat("7️⃣  CROSS-REFERENCE VALIDATION\n")
cat("───────────────────────────────\n")

# Check OSF files against inventory
osf_files <- files_df %>% filter(source == "osf")
cat("OSF files in catalog:", nrow(osf_files), "\n")

# Check PUMF files against inventory
pumf_files <- files_df %>% filter(source == "pumf")
cat("PUMF files in catalog:", nrow(pumf_files), "\n")

if (file.exists("data/pumf_raw_inventory.csv")) {
  pumf_inventory <- read_csv("data/pumf_raw_inventory.csv", show_col_types = FALSE)
  cat("PUMF inventory entries:", nrow(pumf_inventory), "\n")

  # Note: After deduplication, catalog should have fewer files
  if (nrow(pumf_files) > nrow(pumf_inventory)) {
    cat("⚠️  WARNING: Catalog has more PUMF files than inventory\n")
  } else {
    cat("✅ PUMF catalog entries <= inventory (expected after dedup)\n")
  }
}

cat("\n")

# ============================================================================
# 8. METADATA VALIDATION
# ============================================================================
cat("8️⃣  CATALOG METADATA VALIDATION\n")
cat("────────────────────────────────\n")

meta <- catalog$catalog_metadata

# Check required metadata fields
required_meta <- c("version", "created_date", "last_updated", "total_files",
                   "years_covered", "uid_system_version", "namespaces")

for (field in required_meta) {
  if (is.null(meta[[field]])) {
    cat("❌", field, ": missing\n")
  } else {
    cat("✅", field, ":",
        if (is.list(meta[[field]])) paste(length(meta[[field]]), "items") else meta[[field]],
        "\n")
  }
}

# Verify total_files matches actual count
if (meta$total_files != nrow(files_df)) {
  cat("❌ FAIL: total_files (", meta$total_files, ") != actual (", nrow(files_df), ")\n", sep = "")
} else {
  cat("✅ total_files matches actual count\n")
}

cat("\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("═══════════════════════════════════════════\n")
cat("📋 VALIDATION SUMMARY\n")
cat("═══════════════════════════════════════════\n\n")

cat("Total files validated:", nrow(files_df), "\n")
cat("Sources: OSF (", nrow(osf_files), "), PUMF (", nrow(pumf_files), ")\n", sep = "")
cat("Years covered:", min(files_df$year), "-", max(files_df$year), "\n")
cat("Namespaces:", length(valid_namespaces), "\n")
cat("Categories:", n_distinct(files_df$category), "\n")
cat("Languages:", paste(unique(files_df$language), collapse = ", "), "\n\n")

# Overall assessment
critical_issues <- nrow(dup_uids) + nrow(invalid_uids) + nrow(mismatches) +
                   nrow(invalid_canonical) + nrow(dup_canonical)

if (critical_issues > 0) {
  cat("❌ VALIDATION FAILED:", critical_issues, "critical issues found\n")
  cat("   Please review and fix issues before committing\n")
} else {
  cat("✅ VALIDATION PASSED\n")
  cat("   Catalog is ready for production\n")
}

cat("\n")
