# PUMF Documentation Cataloging Script
# Generates catalog with deduplication and high-quality metadata
#
# Strategy: See docs/pumf-cleanup-strategy.md
# - Deduplicates exact copies (keeps primary, tracks alternates)
# - Handles filename conflicts (same name, different content)
# - Generates canonical UIDs and filenames
# - Preserves original filenames and paths for traceability

library(yaml)
library(digest)
library(dplyr)
library(stringr)
library(tools)
library(readr)

cat("📚 CCHS PUMF Documentation Cataloging\n")
cat("═══════════════════════════════════════════════════════════\n\n")

# Configuration
PUMF_DIR <- "cchs-pumf-docs"
OUTPUT_FILE <- "data/catalog/cchs_catalog_pumf.yaml"
SUBCAT_MAPPING_FILE <- "data/pumf_subcategory_mapping.csv"

# Load subcategory mapping
cat("📖 Loading subcategory mapping...\n")
if (file.exists(SUBCAT_MAPPING_FILE)) {
  subcat_mapping <- read_csv(SUBCAT_MAPPING_FILE, show_col_types = FALSE)
  cat(sprintf("   Loaded %d subcategory assignments\n\n", nrow(subcat_mapping)))
} else {
  subcat_mapping <- NULL
  cat("   No subcategory mapping file found - proceeding without subcategories\n\n")
}

# Helper function: Calculate SHA-256 checksum
calculate_checksum <- function(filepath) {
  tryCatch({
    digest::digest(filepath, algo = "sha256", file = TRUE)
  }, error = function(e) {
    return(NA)
  })
}

# Helper function: Generate 6-character alphanumeric catalog ID
generate_catalog_id <- function() {
  chars <- c(0:9, LETTERS)
  paste(sample(chars, 6, replace = TRUE), collapse = "")
}

# Helper function: Extract category from folder path
extract_category_from_path <- function(filepath) {
  # Category mapping from folder structure
  folder_mapping <- list(
    "Bootstrap" = "bootstrap",
    "CCHS_DDI" = "ddi-metadata",
    "CCHS_data_dictionary" = "data-dictionary",
    "CCHS_derived_variables" = "derived-variables",
    "CCHS_study_documentation" = "study-documentation",
    "CCHS_user_guide" = "user-guide",
    "CV-tables" = "cv-tables",
    "Quality assurance" = "quality-assurance",
    "Record-layout" = "record-layout",
    "CCHS-questionnnaire" = "questionnaire",
    "CCHS-Errata" = "errata",
    "AlphabeticIndex" = "alpha-index",
    "ReadMe" = "readme",
    "TopicalIndex" = "topical-index",
    "RecordLayout" = "record-layout",
    "DataDictionary" = "data-dictionary",
    "DerivedVariablesDocumentation" = "derived-variables",
    "StudyDocumentation" = "study-documentation",
    "UserGuide" = "user-guide"
  )

  for (folder in names(folder_mapping)) {
    if (grepl(folder, filepath, fixed = TRUE)) {
      return(folder_mapping[[folder]])
    }
  }

  return("other")
}

# Helper function: Extract year(s) from filename
extract_year_from_filename <- function(filename) {
  # Try dual-year format first: 2015-2016, 2009-2010
  dual_match <- str_extract(filename, "20[0-9]{2}[-_]20[0-9]{2}")
  if (!is.na(dual_match)) {
    year <- str_extract(dual_match, "^20[0-9]{2}")
    return(list(year = year, is_dual = TRUE))
  }

  # Try single year: 2015, 2009
  single_match <- str_extract(filename, "20[0-9]{2}")
  if (!is.na(single_match)) {
    return(list(year = single_match, is_dual = FALSE))
  }

  # Special cases
  if (grepl("Bootstrap", filename, ignore.case = TRUE)) {
    return(list(year = "2015", is_dual = TRUE))  # Default for bootstrap
  }

  # Default fallback
  return(list(year = "2001", is_dual = FALSE))
}

# Helper function: Determine temporal type
determine_temporal_type <- function(year_info) {
  if (year_info$is_dual) {
    return("dual")
  } else {
    return("single")
  }
}

# Helper function: Extract language from filename
extract_language <- function(filename) {
  # Check for explicit language markers
  if (grepl("_[EF]\\.", filename) || grepl("_[EF]_", filename)) {
    if (grepl("_E\\.", filename) || grepl("_E_", filename)) {
      return("EN")
    } else {
      return("FR")
    }
  }

  if (grepl("-eng", filename, ignore.case = TRUE)) return("EN")
  if (grepl("-fra|french", filename, ignore.case = TRUE)) return("FR")
  if (grepl("English", filename)) return("EN")
  if (grepl("French", filename)) return("FR")

  # Default to English for DDI, webarchive, HTML
  ext <- tolower(tools::file_ext(filename))
  if (ext %in% c("xml", "webarchive", "html")) {
    return("EN")
  }

  # Default
  return("EN")
}

# Helper function: Generate UID (v3.0.0 with optional subcategory)
generate_uid <- function(year, temporal, doc_type, category, language, extension, sequence = 1, subcategory = NULL) {
  temporal_code <- substr(temporal, 1, 1)  # s, d, m
  doc_code <- substr(doc_type, 1, 1)       # p for pumf
  lang_code <- tolower(substr(language, 1, 1))  # e or f

  # Handle multi-word categories (e.g., "ddi-metadata")
  category_code <- category

  # Build UID with optional subcategory
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    uid <- sprintf("cchs-%s%s-%s-%s-%s-%s-%s-%02d",
                   year, temporal_code, doc_code,
                   category_code, subcategory, lang_code, extension, sequence)
  } else {
    uid <- sprintf("cchs-%s%s-%s-%s-%s-%s-%02d",
                   year, temporal_code, doc_code,
                   category_code, lang_code, extension, sequence)
  }
  return(uid)
}

# Helper function: Generate canonical filename (v3.0.0 with optional subcategory)
generate_canonical_filename <- function(year, temporal, category, doc_type, language, sequence, extension, subcategory = NULL) {
  temporal_code <- substr(temporal, 1, 1)
  doc_code <- substr(doc_type, 1, 1)  # p for pumf
  lang_abbrev <- tolower(substr(language, 1, 2))  # en or fr

  # Build filename with optional subcategory
  if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
    canonical <- sprintf("cchs_%s%s_%s_%s_%s_%s_%d_v1.%s",
                         year, temporal_code, category, subcategory, doc_code,
                         lang_abbrev, sequence, extension)
  } else {
    canonical <- sprintf("cchs_%s%s_%s_%s_%s_%d_v1.%s",
                         year, temporal_code, category, doc_code,
                         lang_abbrev, sequence, extension)
  }
  return(canonical)
}

# Helper function: Select primary file from duplicate group
# REVISED PRIORITY: Prefer parent-level files to deprecate CCHS-PUMF folder
select_primary_file <- function(duplicate_group) {
  # Priority 1: Prefer parent-level folders (NOT CCHS-PUMF subfolder)
  # Goal: Eventually delete CCHS-PUMF folder
  parent_level <- duplicate_group %>%
    filter(!grepl("CCHS-PUMF/", filepath, fixed = TRUE))

  if (nrow(parent_level) > 0) {
    # Among parent-level files, prefer CCHS-share/ for share docs
    share_folder <- parent_level %>%
      filter(grepl("CCHS-share/", filepath, fixed = TRUE))
    if (nrow(share_folder) > 0) {
      return(share_folder %>%
               mutate(path_length = nchar(filepath)) %>%
               arrange(path_length) %>%
               slice(1))
    }
    # Otherwise return shortest parent-level path
    return(parent_level %>%
             mutate(path_length = nchar(filepath)) %>%
             arrange(path_length) %>%
             slice(1))
  }

  # Priority 2: If ONLY in CCHS-PUMF (21 unique files), keep those
  # These will need to be moved to parent level before folder deletion
  return(duplicate_group %>%
           mutate(path_length = nchar(filepath)) %>%
           arrange(path_length) %>%
           slice(1))
}

# Main cataloging function
catalog_pumf_files <- function() {
  cat("🔍 Step 1: Scanning PUMF files...\n")

  # Get all files
  all_files <- list.files(PUMF_DIR,
                          recursive = TRUE,
                          full.names = TRUE,
                          include.dirs = FALSE)

  # Filter out .DS_Store and hidden files
  all_files <- all_files[!grepl("\\.DS_Store$", all_files)]
  all_files <- all_files[!grepl("/\\.[^/]+$", all_files)]

  cat(sprintf("   Found %d files\n", length(all_files)))

  # Create file data frame
  cat("\n⏳ Step 2: Calculating checksums...\n")
  file_data <- data.frame(
    filepath = all_files,
    filename = basename(all_files),
    size = file.info(all_files)$size,
    stringsAsFactors = FALSE
  )

  file_data$checksum <- sapply(file_data$filepath, calculate_checksum)
  file_data <- file_data[!is.na(file_data$checksum), ]

  cat(sprintf("   Calculated %d checksums\n", nrow(file_data)))

  # Deduplication
  cat("\n🔄 Step 3: Deduplicating files...\n")

  catalog_entries <- list()
  seen_checksums <- c()
  dup_count <- 0

  # Group by checksum
  checksum_groups <- file_data %>%
    group_by(checksum) %>%
    group_split()

  for (group_df in checksum_groups) {
    if (nrow(group_df) == 1) {
      # Unique file
      primary <- group_df[1, ]
      alternates <- NULL
    } else {
      # Duplicates - select primary
      primary <- select_primary_file(group_df)
      alternates <- group_df %>%
        filter(filepath != primary$filepath) %>%
        pull(filepath)
      dup_count <- dup_count + length(alternates)
    }

    # Extract metadata
    year_info <- extract_year_from_filename(primary$filename)
    category <- extract_category_from_path(primary$filepath)
    language <- extract_language(primary$filename)
    temporal_type <- determine_temporal_type(year_info)
    extension <- tolower(tools::file_ext(primary$filename))

    # Generate UID (check for uniqueness and look up subcategory)
    sequence <- 1
    subcategory <- NULL

    # Generate initial UID without subcategory to check mapping
    temp_uid <- generate_uid(year_info$year, temporal_type, "pumf",
                            category, language, extension, sequence)

    # Check for uniqueness
    while (temp_uid %in% seen_checksums) {
      sequence <- sequence + 1
      temp_uid <- generate_uid(year_info$year, temporal_type, "pumf",
                              category, language, extension, sequence)
    }

    # Look up subcategory from mapping file (if sequence > 1)
    if (!is.null(subcat_mapping) && sequence > 1) {
      mapping_row <- subcat_mapping %>%
        filter(cchs_uid == temp_uid)
      if (nrow(mapping_row) > 0) {
        subcategory <- mapping_row$subcategory[1]
      }
    }

    # Generate final UID with subcategory (if applicable)
    uid <- generate_uid(year_info$year, temporal_type, "pumf",
                       category, language, extension, sequence, subcategory)
    seen_checksums <- c(seen_checksums, uid)

    # Create catalog entry
    entry <- list(
      cchs_uid = uid,
      catalog_id = generate_catalog_id(),
      year = year_info$year,
      temporal_type = temporal_type,
      doc_type = "pumf",
      category = category,
      language = language,
      version = "v1",
      sequence = as.integer(sequence),
      filename = primary$filename,
      canonical_filename = generate_canonical_filename(
        year_info$year, temporal_type, category, "pumf",
        language, sequence, extension, subcategory
      ),
      source = "pumf",
      pumf_path = sub(paste0("^", PUMF_DIR, "/"), "", primary$filepath),
      file_extension = extension,
      file_size = as.integer(primary$size),
      checksum = primary$checksum,
      created_date = as.character(Sys.Date()),
      last_modified = as.character(Sys.Date())
    )

    # Add subcategory to entry if it exists
    if (!is.null(subcategory) && subcategory != "" && !is.na(subcategory)) {
      entry$subcategory <- subcategory
    }

    # Add alternate paths if duplicates exist
    if (!is.null(alternates) && length(alternates) > 0) {
      entry$alternate_paths <- lapply(alternates, function(p) {
        sub(paste0("^", PUMF_DIR, "/"), "", p)
      })
      entry$duplicate_count = length(alternates)
    }

    catalog_entries[[length(catalog_entries) + 1]] <- entry
  }

  cat(sprintf("   Unique files: %d\n", length(catalog_entries)))
  cat(sprintf("   Duplicates removed: %d\n", dup_count))

  # Create catalog structure
  cat("\n📋 Step 4: Building catalog...\n")

  catalog <- list(
    catalog_metadata = list(
      version = "v2.0.0",
      created_date = as.character(Sys.Date()),
      last_updated = as.character(Sys.Date()),
      total_files = length(catalog_entries),
      years_covered = "2001-2021",
      uid_system_version = "3.0",
      schema_version = "3.0.0",
      data_sources = list("Google Drive PUMF (deduplicated)"),
      namespaces = list(
        local_pumf = "cchs-pumf-docs/",
        gdrive = "https://drive.google.com/drive/folders/1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW"
      ),
      deduplication_stats = list(
        original_files = nrow(file_data),
        unique_files = length(catalog_entries),
        duplicates_removed = dup_count,
        space_saved = sum(file_data$size) - sum(sapply(catalog_entries, function(e) e$file_size))
      )
    ),
    files = catalog_entries
  )

  # Write catalog
  cat(sprintf("\n💾 Step 5: Writing catalog to %s...\n", OUTPUT_FILE))

  # Ensure directory exists
  dir.create(dirname(OUTPUT_FILE), showWarnings = FALSE, recursive = TRUE)

  yaml::write_yaml(catalog, OUTPUT_FILE)

  cat("\n✅ Cataloging complete!\n\n")

  # Summary
  cat("═══════════════════════════════════════════════════════════\n")
  cat("📊 Summary\n")
  cat("═══════════════════════════════════════════════════════════\n")
  cat(sprintf("Total files scanned:     %d\n", nrow(file_data)))
  cat(sprintf("Unique files cataloged:  %d\n", length(catalog_entries)))
  cat(sprintf("Duplicates removed:      %d\n", dup_count))
  cat(sprintf("Space saved:             %.2f MB\n",
              catalog$catalog_metadata$deduplication_stats$space_saved / (1024 * 1024)))
  cat(sprintf("Catalog file:            %s\n", OUTPUT_FILE))

  # Category breakdown
  cat("\n📂 Files by Category:\n")
  category_counts <- table(sapply(catalog_entries, function(e) e$category))
  for (cat_name in names(sort(category_counts, decreasing = TRUE))) {
    cat(sprintf("   %-25s: %3d files\n", cat_name, category_counts[cat_name]))
  }

  # Extension breakdown
  cat("\n📄 Files by Extension:\n")
  ext_counts <- table(sapply(catalog_entries, function(e) e$file_extension))
  for (ext_name in names(sort(ext_counts, decreasing = TRUE))) {
    cat(sprintf("   %-15s: %3d files\n", ext_name, ext_counts[ext_name]))
  }

  return(catalog)
}

# Run cataloging
if (!interactive()) {
  catalog <- catalog_pumf_files()
} else {
  cat("ℹ️  Run catalog_pumf_files() to generate PUMF catalog\n")
}
