# Health Survey Document Collection Extractor
# Extracts curated document collections from CCHS and CHMS catalogs
# Uses existing catalog naming schema and maintains traceability to OSF sources

library(yaml)
library(dplyr)
library(fs)

#' Extract Document Collection from Health Survey Catalog
#'
#' @param survey Survey type ("CCHS" or "CHMS")
#' @param target_categories Vector of categories to extract (default: high-value for RAG)
#' @param output_dir Output directory for extracted files
#' @param catalog_file Path to catalog YAML file (auto-detected if NULL)
#' @param source_dir Path to OSF documents directory (auto-detected if NULL)
#' @param languages Languages to include ("EN"/"e", "FR"/"f", or both)
#' @param years Year range to include for CCHS (NULL for all years)
#' @param cycles CHMS cycles to include (NULL for all cycles)
#' @param exclude_syntax Whether to exclude syntax files (variable-labels category)
#' @param create_zip Whether to create ZIP archive
#' @param create_inventory Whether to generate inventory files
#' @return List with extraction results and statistics
extract_collection <- function(survey = "CCHS",
                               target_categories = c("questionnaire", "data-dictionary", "derived-variables", "user-guide"),
                               output_dir = NULL,
                               catalog_file = NULL,
                               source_dir = NULL,
                               languages = c("EN", "FR"),
                               years = NULL,
                               cycles = NULL,
                               exclude_syntax = TRUE,
                               create_zip = TRUE,
                               create_inventory = TRUE) {

  # Auto-detect paths based on survey
  if (is.null(catalog_file)) {
    catalog_file <- ifelse(survey == "CCHS",
                           "data/catalog/cchs_catalog.yaml",
                           "data/catalog/chms_catalog.yaml")
  }

  if (is.null(source_dir)) {
    source_dir <- ifelse(survey == "CCHS", "cchs-osf-docs", "chms-osf-docs")
  }

  if (is.null(output_dir)) {
    output_dir <- paste0(tolower(survey), "-collection")
  }

  cat("===", survey, "Document Collection Extractor ===\n")
  cat("Target categories:", paste(target_categories, collapse = ", "), "\n")
  cat("Output directory:", output_dir, "\n")
  cat("Languages:", paste(languages, collapse = ", "), "\n")
  if (survey == "CHMS" && !is.null(cycles)) {
    cat("Cycles:", paste(cycles, collapse = ", "), "\n")
  }
  cat("Exclude syntax files:", exclude_syntax, "\n\n")
  
  # Load catalog
  if (!file.exists(catalog_file)) {
    stop("Catalog file not found: ", catalog_file)
  }
  
  cat("📖 Loading catalog:", catalog_file, "\n")
  catalog <- yaml::read_yaml(catalog_file)
  
  # Filter files by criteria
  cat("🔍 Filtering files by criteria...\n")
  selected_files <- filter_catalog_files(
    catalog = catalog,
    survey = survey,
    categories = target_categories,
    languages = languages,
    years = years,
    cycles = cycles,
    exclude_syntax = exclude_syntax
  )
  
  cat("Found", length(selected_files), "matching files\n\n")
  
  if (length(selected_files) == 0) {
    cat("❌ No files match the criteria\n")
    return(list(success = FALSE, files_extracted = 0))
  }
  
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cat("📁 Created output directory:", output_dir, "\n")
  }
  
  # Extract files
  cat("📋 Extracting files...\n")
  extraction_results <- extract_files(
    selected_files = selected_files,
    source_dir = source_dir,
    output_dir = output_dir
  )
  
  # Generate inventory
  if (create_inventory) {
    cat("📝 Generating inventory files...\n")
    create_collection_inventory(
      extraction_results = extraction_results,
      output_dir = output_dir,
      target_categories = target_categories
    )
  }
  
  # Create ZIP archive
  if (create_zip) {
    cat("📦 Creating ZIP archive...\n")
    zip_file <- create_collection_zip(
      output_dir = output_dir,
      extraction_results = extraction_results
    )
    extraction_results$zip_file <- zip_file
  }
  
  # Print summary
  print_extraction_summary(extraction_results)
  
  return(extraction_results)
}

#' Filter catalog files by criteria (survey-aware)
filter_catalog_files <- function(catalog, survey, categories, languages, years, cycles, exclude_syntax = TRUE) {
  files <- catalog$files
  selected <- list()

  # Normalize language codes (handle both EN/e and FR/f)
  languages_normalized <- tolower(substr(languages, 1, 1))

  for (i in seq_along(files)) {
    file_entry <- files[[i]]

    # Check category
    if (!file_entry$category %in% categories) next

    # Exclude syntax files if requested
    if (exclude_syntax && file_entry$category == "variable-labels-english") next

    # Check language (normalize comparison)
    file_lang <- tolower(substr(file_entry$language, 1, 1))
    if (!file_lang %in% languages_normalized) next

    # Survey-specific filters
    if (survey == "CCHS") {
      # Check year if specified
      if (!is.null(years)) {
        if (!as.numeric(file_entry$year) %in% years) next
      }
    } else if (survey == "CHMS") {
      # Check cycle if specified
      if (!is.null(cycles)) {
        # Normalize cycle format (handle both "cycle1" and "1")
        file_cycle <- gsub("^cycle", "", file_entry$chms_cycle)
        cycles_normalized <- gsub("^cycle", "", as.character(cycles))
        if (!file_cycle %in% cycles_normalized) next
      }
    }

    # Use canonical_filename as the standardized name (already in catalog)
    file_entry$extraction_name <- file_entry$canonical_filename
    file_entry$index <- i

    selected[[length(selected) + 1]] <- file_entry
  }

  return(selected)
}

#' Extract files from source to output directory
extract_files <- function(selected_files, source_dir, output_dir) {
  results <- list(
    successful = list(),
    failed = list(),
    total_files = length(selected_files),
    total_size = 0
  )
  
  for (file_entry in selected_files) {
    # Construct source path using source_filepath (or fallback to local_path for backward compat)
    relative_path <- file_entry$source_filepath %||% file_entry$local_path
    source_path <- file.path(source_dir, relative_path)

    # Use canonical_filename/filename_canonical as extraction name (maintains catalog schema)
    target_filename <- file_entry$canonical_filename %||% file_entry$filename_canonical
    target_path <- file.path(output_dir, target_filename)

    # Track the mapping for traceability with enhanced metadata (survey-aware)
    file_mapping <- list(
      uid = file_entry$uid %||% file_entry$cchs_uid,  # Support both UID formats
      original_filename = file_entry$filename_original %||% file_entry$filename,
      canonical_filename = file_entry$canonical_filename %||% file_entry$filename_canonical,
      source_path = source_path,
      target_path = target_path,
      category = file_entry$category,
      secondary_categories = file_entry$secondary_categories,
      content_tags = file_entry$content_tags,
      year = file_entry$year,
      temporal_type = file_entry$temporal_type,
      doc_type = file_entry$doc_type,
      chms_cycle = file_entry$chms_cycle,
      chms_component = file_entry$chms_component,
      language = file_entry$language,
      file_extension = file_entry$file_extension,
      version = file_entry$version,
      sequence = file_entry$sequence,
      file_size = file_entry$file_size
    )
    
    # Attempt file copy
    if (file.exists(source_path)) {
      tryCatch({
        file.copy(source_path, target_path, overwrite = TRUE)
        
        # Verify copy
        if (file.exists(target_path)) {
          file_mapping$status <- "success"
          file_mapping$extracted_size <- file.info(target_path)$size
          results$successful[[length(results$successful) + 1]] <- file_mapping
          results$total_size <- results$total_size + file_mapping$extracted_size
          
          cat("  ✅", file_entry$uid %||% file_entry$cchs_uid, "→", target_filename, "\n")
        } else {
          file_mapping$status <- "copy_failed"
          file_mapping$error <- "File copy failed verification"
          results$failed[[length(results$failed) + 1]] <- file_mapping
          cat("  ❌", file_entry$uid %||% file_entry$cchs_uid, "→ Copy failed verification\n")
        }
        
      }, error = function(e) {
        file_mapping$status <- "error"
        file_mapping$error <- e$message
        results$failed[[length(results$failed) + 1]] <- file_mapping
        cat("  ❌", file_entry$uid %||% file_entry$cchs_uid, "→ Error:", e$message, "\n")
      })

    } else {
      file_mapping$status <- "source_missing"
      file_mapping$error <- paste("Source file not found:", source_path)
      results$failed[[length(results$failed) + 1]] <- file_mapping
      cat("  ❌", file_entry$uid %||% file_entry$cchs_uid, "→ Source file missing\n")
    }
  }
  
  return(results)
}

#' Create inventory files for the collection
create_collection_inventory <- function(extraction_results, output_dir, target_categories) {
  
  # Create detailed inventory CSV with enhanced metadata (survey-aware)
  inventory_data <- data.frame(
    uid = character(),
    original_filename = character(),
    canonical_filename = character(),
    category = character(),
    secondary_categories = character(),
    content_tags = character(),
    year = character(),
    temporal_type = character(),
    chms_cycle = character(),
    chms_component = character(),
    doc_type = character(),
    language = character(),
    file_extension = character(),
    version = character(),
    sequence = numeric(),
    file_size = numeric(),
    status = character(),
    stringsAsFactors = FALSE
  )
  
  # Add successful extractions
  for (file_info in extraction_results$successful) {
    inventory_data <- rbind(inventory_data, data.frame(
      uid = file_info$uid,
      original_filename = file_info$original_filename,
      canonical_filename = file_info$canonical_filename,
      category = file_info$category,
      secondary_categories = paste(file_info$secondary_categories %||% character(0), collapse = "; "),
      content_tags = paste(file_info$content_tags %||% character(0), collapse = "; "),
      year = file_info$year %||% "",
      temporal_type = file_info$temporal_type %||% "",
      chms_cycle = file_info$chms_cycle %||% "",
      chms_component = file_info$chms_component %||% "",
      doc_type = file_info$doc_type %||% "",
      language = file_info$language,
      file_extension = file_info$file_extension %||% "",
      version = file_info$version %||% "",
      sequence = file_info$sequence %||% 0,
      file_size = file_info$file_size %||% 0,
      status = "extracted",
      stringsAsFactors = FALSE
    ))
  }
  
  # Add failed extractions for reference
  for (file_info in extraction_results$failed) {
    inventory_data <- rbind(inventory_data, data.frame(
      uid = file_info$uid,
      original_filename = file_info$original_filename,
      canonical_filename = file_info$canonical_filename %||% "N/A",
      category = file_info$category,
      secondary_categories = paste(file_info$secondary_categories %||% character(0), collapse = "; "),
      content_tags = paste(file_info$content_tags %||% character(0), collapse = "; "),
      year = file_info$year %||% "",
      temporal_type = file_info$temporal_type %||% "",
      chms_cycle = file_info$chms_cycle %||% "",
      chms_component = file_info$chms_component %||% "",
      doc_type = file_info$doc_type %||% "",
      language = file_info$language,
      file_extension = file_info$file_extension %||% "",
      version = file_info$version %||% "",
      sequence = file_info$sequence %||% 0,
      file_size = file_info$file_size %||% 0,
      status = file_info$status,
      stringsAsFactors = FALSE
    ))
  }
  
  # Write inventory CSV
  inventory_file <- file.path(output_dir, "collection_inventory.csv")
  write.csv(inventory_data, inventory_file, row.names = FALSE)
  
  # Create README
  readme_content <- generate_collection_readme(
    extraction_results = extraction_results,
    target_categories = target_categories,
    inventory_data = inventory_data
  )
  
  readme_file <- file.path(output_dir, "README.md")
  writeLines(readme_content, readme_file)
  
  cat("  ✅ Inventory saved:", inventory_file, "\n")
  cat("  ✅ README created:", readme_file, "\n")
}

#' Generate README content for the collection
generate_collection_readme <- function(extraction_results, target_categories, inventory_data) {
  
  successful_count <- length(extraction_results$successful)
  total_size_mb <- round(extraction_results$total_size / (1024 * 1024), 2)
  
  # Statistics by category and year
  stats_by_category <- table(inventory_data$category[inventory_data$status == "extracted"])
  stats_by_year <- table(inventory_data$year[inventory_data$status == "extracted"])
  stats_by_language <- table(inventory_data$language[inventory_data$status == "extracted"])
  
  readme_content <- c(
    "# CCHS Document Collection",
    "",
    paste("Curated collection of", successful_count, "high-value CCHS documents"),
    paste("extracted on", Sys.Date()),
    "",
    "## Collection Overview",
    "",
    paste("- **Total files:**", successful_count),
    paste("- **Total size:**", total_size_mb, "MB"),
    paste("- **Categories:**", paste(target_categories, collapse = ", ")),
    paste("- **Years covered:**", min(inventory_data$year), "-", max(inventory_data$year)),
    "",
    "## Files by Category",
    ""
  )
  
  for (cat_name in names(stats_by_category)) {
    readme_content <- c(readme_content, 
      paste("- **", cat_name, ":**", stats_by_category[cat_name], "files"))
  }
  
  readme_content <- c(readme_content,
    "",
    "## Files by Language",
    ""
  )
  
  for (lang in names(stats_by_language)) {
    readme_content <- c(readme_content,
      paste("- **", lang, ":**", stats_by_language[lang], "files"))
  }
  
  readme_content <- c(readme_content,
    "",
    "## Naming Convention",
    "",
    "Files use the CCHS canonical naming schema:",
    "`cchs_{year}{temporal}_{category}_{type}_{language}_{sequence}_{version}.{ext}`",
    "",
    "Examples:",
    "- `cchs_2009d_qu_m_en_1_v1.pdf` - 2009 dual-year questionnaire, master, English",
    "- `cchs_2015s_dd_m_fr_1_v1.docx` - 2015 single-year data dictionary, master, French",
    "",
    "## File Inventory",
    "",
    "See `collection_inventory.csv` for complete file listing with:",
    "- CCHS UID (unique identifier)",
    "- Original OSF filename", 
    "- Canonical filename (used in this collection)",
    "- Document metadata (category, year, language)",
    "- Extraction status",
    "",
    "## Usage",
    "",
    "These files are ready for:",
    "- RAG (Retrieval-Augmented Generation) systems",
    "- Text analysis and processing",
    "- Research and documentation",
    "- Archive and preservation",
    "",
    "---",
    "",
    "🤖 *Generated by CCHS Document Collection Extractor*"
  )
  
  return(readme_content)
}

#' Create ZIP archive of the collection
create_collection_zip <- function(output_dir, extraction_results) {
  
  collection_name <- paste0("cchs_collection_", format(Sys.Date(), "%Y%m%d"))
  zip_file <- paste0(collection_name, ".zip")
  
  # Create ZIP file
  old_wd <- getwd()
  setwd(dirname(output_dir))
  
  tryCatch({
    zip(zipfile = zip_file, 
        files = basename(output_dir),
        flags = "-r")
    
    zip_path <- file.path(dirname(output_dir), zip_file)
    cat("  ✅ ZIP created:", zip_path, "\n")
    
    setwd(old_wd)
    return(zip_path)
    
  }, error = function(e) {
    setwd(old_wd)
    cat("  ❌ ZIP creation failed:", e$message, "\n")
    return(NULL)
  })
}

#' Print extraction summary
print_extraction_summary <- function(results) {
  cat("\n=== EXTRACTION SUMMARY ===\n")
  cat("📊 Total files processed:", results$total_files, "\n")
  cat("✅ Successfully extracted:", length(results$successful), "\n")
  cat("❌ Failed extractions:", length(results$failed), "\n")
  cat("💾 Total size:", round(results$total_size / (1024 * 1024), 2), "MB\n")
  
  if (length(results$failed) > 0) {
    cat("\n❌ Failed files:\n")
    for (failed in results$failed) {
      cat("  -", failed$cchs_uid, ":", failed$error, "\n")
    }
  }
  
  cat("\n🎉 Collection extraction complete!\n")
}

# Helper function for null coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x

cat("CCHS Document Collection Extractor loaded.\n")
cat("Usage: extract_collection(target_categories = c('questionnaire', 'data-dictionary'))\n")