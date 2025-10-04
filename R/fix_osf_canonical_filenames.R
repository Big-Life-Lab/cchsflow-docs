#!/usr/bin/env Rscript
# Fix OSF Canonical Filenames
#
# Problem: OSF files in catalog have canonical filenames using category abbreviations (dd, ot, etc.)
# which causes duplicates when different categories map to the same abbreviation (e.g., "other" and
# "data-dictionary" both becoming "ot").
#
# Solution: Regenerate canonical filenames using full category names (matching v3.0 spec)
# Format: cchs_{year}{temporal}_{category}[_{subcategory}]_{doc_type}_{language}_{sequence}_{version}.{ext}

library(yaml)
library(dplyr)

cat("════════════════════════════════════════════════════════════\n")
cat("FIXING OSF CANONICAL FILENAMES\n")
cat("════════════════════════════════════════════════════════════\n\n")

# Load catalog
catalog_file <- "data/catalog/cchs_catalog.yaml"
cat("📖 Loading catalog:", catalog_file, "\n")
catalog <- yaml::read_yaml(catalog_file)
cat(sprintf("   Total files: %d\n\n", length(catalog$files)))

# Function to generate canonical filename (v3.0 format)
generate_canonical_filename <- function(year, temporal_type, category, doc_type, language, sequence, version, extension, subcategory = NULL) {
  temporal_abbrev <- substr(temporal_type, 1, 1)  # s, d, m
  doc_type_abbrev <- substr(doc_type, 1, 1)       # m, s, p
  lang_code <- tolower(language)                  # en, fr

  year_temporal <- paste0(year, temporal_abbrev)

  # Build canonical parts with optional subcategory
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    canonical_parts <- c(
      "cchs",
      year_temporal,
      category,
      subcategory,
      doc_type_abbrev,
      lang_code,
      sequence,
      version
    )
  } else {
    canonical_parts <- c(
      "cchs",
      year_temporal,
      category,
      doc_type_abbrev,
      lang_code,
      sequence,
      version
    )
  }

  canonical_base <- paste(canonical_parts, collapse = "_")
  return(paste0(canonical_base, ".", extension))
}

# Regenerate canonical filenames
cat("🔄 Regenerating canonical filenames...\n")

osf_updated <- 0
pumf_updated <- 0
unchanged <- 0

for (i in seq_along(catalog$files)) {
  entry <- catalog$files[[i]]

  # Generate new canonical filename
  new_canonical <- generate_canonical_filename(
    year = entry$year,
    temporal_type = entry$temporal_type,
    category = entry$category,
    doc_type = entry$doc_type,
    language = entry$language,
    sequence = entry$sequence,
    version = entry$version,
    extension = entry$file_extension,
    subcategory = entry$subcategory
  )

  # Check if it changed
  if (entry$canonical_filename != new_canonical) {
    catalog$files[[i]]$canonical_filename <- new_canonical

    if (entry$source == "osf") {
      osf_updated <- osf_updated + 1
    } else if (entry$source == "pumf") {
      pumf_updated <- pumf_updated + 1
    }
  } else {
    unchanged <- unchanged + 1
  }
}

cat(sprintf("   OSF files updated: %d\n", osf_updated))
cat(sprintf("   PUMF files updated: %d\n", pumf_updated))
cat(sprintf("   Files unchanged: %d\n\n", unchanged))

# Create backup
backup_file <- "data/catalog/cchs_catalog_pre_canonical_fix.yaml"
cat(sprintf("💾 Creating backup: %s\n", backup_file))
file.copy(catalog_file, backup_file, overwrite = TRUE)

# Write updated catalog
cat(sprintf("💾 Writing updated catalog to %s...\n\n", catalog_file))
yaml::write_yaml(catalog, catalog_file)

# Summary
cat("════════════════════════════════════════════════════════════\n")
cat("FIX COMPLETE\n")
cat("════════════════════════════════════════════════════════════\n\n")

cat("📊 Summary:\n")
cat(sprintf("   Total files: %d\n", length(catalog$files)))
cat(sprintf("   OSF canonical filenames updated: %d\n", osf_updated))
cat(sprintf("   PUMF canonical filenames updated: %d\n", pumf_updated))
cat(sprintf("   Unchanged: %d\n\n", unchanged))

cat("✅ Canonical filenames successfully regenerated\n\n")

cat("Next steps:\n")
cat("1. Run deep validation:\n")
cat("   R --vanilla --quiet -f R/deep_validate_catalog.R\n\n")
cat("2. If validation passes, commit changes\n\n")

cat("Backup saved to:", backup_file, "\n")
