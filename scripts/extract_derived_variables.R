#!/usr/bin/env Rscript
# Extract CCHS derived variable specifications from PDFs to YAML
#
# Usage:
#   Rscript extract_derived_variables.R <pdf_file> [output_file]
#
# Output: YAML file with derived variable definitions including:
#   - Variable name, label, description
#   - Source variables (based_on)
#   - Calculation specifications (conditions -> values)
#   - Notes and references
#
# This script can also be sourced to use the parsing functions directly.

suppressPackageStartupMessages({
  library(yaml)
  library(digest)
})

#==============================================================================
# PARSING FUNCTIONS (can be sourced by other scripts)
#==============================================================================

# Clean line - remove page headers/footers
clean_dv_line <- function(line) {
  trimmed <- trimws(line)
  # Skip page numbers alone
  if (grepl("^[0-9]+$", trimmed)) return("")
  # Skip page headers with document title
  if (grepl("Canadian Community Health Survey", trimmed)) return("")
  if (grepl("Derived Variable Specifications", trimmed)) return("")
  # Skip form feed characters
  if (grepl("^\f", line)) return("")
  # Skip date-only lines (e.g., "January 2019")
  if (grepl("^(January|February|March|April|May|June|July|August|September|October|November|December)\\s+[0-9]{4}$", trimmed)) return("")
  return(line)
}

# Clean text that may contain embedded page headers/footers
clean_embedded_headers <- function(text) {
  if (is.null(text) || text == "") return(text)
  # Remove embedded date + page number patterns (e.g., "January 2019                    1")
  text <- gsub("(January|February|March|April|May|June|July|August|September|October|November|December)\\s+[0-9]{4}\\s+[0-9]+\\s*$", "", text)
  # Remove trailing page numbers with lots of whitespace
  text <- gsub("\\s{5,}[0-9]+\\s*$", "", text)
  # Normalize whitespace
  text <- gsub("\\s+", " ", text)
  return(trimws(text))
}

# Detect variable header line
# Pattern: "Variable name:     VARNAME"
detect_variable_header <- function(line) {
  if (grepl("^Variable name:\\s+", line, ignore.case = TRUE)) {
    var_name <- trimws(sub("^Variable name:\\s+", "", line, ignore.case = TRUE))
    return(var_name)
  }
  return(NULL)
}

# Detect "Based on:" line
detect_based_on <- function(line) {
  if (grepl("^Based on:\\s+", line, ignore.case = TRUE)) {
    vars <- trimws(sub("^Based on:\\s+", "", line, ignore.case = TRUE))
    # Split on comma and clean up
    var_list <- strsplit(vars, ",\\s*")[[1]]
    var_list <- trimws(var_list)
    var_list <- var_list[var_list != ""]
    return(var_list)
  }
  return(NULL)
}

# Detect "Description:" line
detect_description <- function(line) {
  if (grepl("^Description:\\s+", line, ignore.case = TRUE)) {
    desc <- trimws(sub("^Description:\\s+", "", line, ignore.case = TRUE))
    return(desc)
  }
  return(NULL)
}

# Detect "Note:" line
detect_note <- function(line) {
  if (grepl("^Note:\\s+", line, ignore.case = TRUE)) {
    note <- trimws(sub("^Note:\\s+", "", line, ignore.case = TRUE))
    return(note)
  }
  return(NULL)
}

# Detect section header (module grouping)
# Pattern: "ACC   Access to health care services (7 DVs)"
detect_module_header <- function(line) {
  line <- trimws(line)
  if (grepl("^[A-Z]{2,4}\\s{2,}[A-Z].*\\([0-9]+ DVs?\\)", line)) {
    # Extract module code and name
    parts <- regmatches(line, regexec("^([A-Z]{2,4})\\s+(.+)\\s+\\(([0-9]+) DVs?\\)", line))[[1]]
    if (length(parts) == 4) {
      return(list(
        code = parts[2],
        name = trimws(parts[3]),
        count = as.integer(parts[4])
      ))
    }
  }
  return(NULL)
}

# Detect numbered variable entry in TOC
# Pattern: "1) ACCG030M - Diff. - Non-emergency surgery..."
detect_toc_entry <- function(line) {
  if (grepl("^\\s*[0-9]+\\)\\s+[A-Z]", line)) {
    # Extract variable name and label
    parts <- regmatches(line, regexec("^\\s*[0-9]+\\)\\s+([A-Z0-9_]+)\\s*-\\s*(.+?)\\s*[0-9]*$", line))[[1]]
    if (length(parts) >= 3) {
      return(list(
        name = parts[2],
        label = trimws(parts[3])
      ))
    }
  }
  return(NULL)
}

# Detect specifications table header
detect_specs_header <- function(line) {
  if (grepl("^\\s*Value\\s+Condition", line, ignore.case = TRUE)) {
    return(TRUE)
  }
  return(FALSE)
}

# Parse a specification row
# Format: "  6                    DOCPG = 2                                           Module not selected                                   NA"
parse_spec_row <- function(line) {
  # Skip empty lines
  if (trimws(line) == "") return(NULL)

  # Skip header lines
  if (grepl("^\\s*Value\\s+Condition", line, ignore.case = TRUE)) return(NULL)
  if (grepl("Specifications", line)) return(NULL)

  # Split on multiple spaces
  parts <- strsplit(trimws(line), "\\s{2,}")[[1]]
  parts <- parts[parts != ""]

  if (length(parts) >= 2) {
    # First part is value, second is condition
    value <- parts[1]
    condition <- parts[2]
    description <- if (length(parts) >= 3) parts[3] else ""
    notes <- if (length(parts) >= 4) parts[4] else ""

    return(list(
      value = value,
      condition = condition,
      description = description,
      notes = notes
    ))
  }

  return(NULL)
}

# Parse a single derived variable entry
parse_derived_variable <- function(lines, start_idx) {
  entry <- list(
    name = NULL,
    label = NULL,
    based_on = character(),
    description = "",
    note = "",
    specifications = list()
  )

  i <- start_idx
  in_specs <- FALSE
  description_continues <- FALSE
  note_continues <- FALSE

  while (i <= length(lines)) {
    line <- lines[i]

    # Clean page headers/footers
    cleaned <- clean_dv_line(line)
    if (cleaned == "") {
      i <- i + 1
      next
    }

    trimmed <- trimws(cleaned)

    # Check for next variable (end of this one)
    if (i > start_idx && !is.null(detect_variable_header(trimmed))) {
      break
    }

    # Check for module header (end of variable)
    if (!is.null(detect_module_header(trimmed))) {
      break
    }

    # Check for numbered entry header like "1 ) Depression severity scale"
    if (grepl("^[0-9]+\\s*\\)\\s+[A-Z]", trimmed) && i > start_idx) {
      break
    }

    # Parse variable name
    var_name <- detect_variable_header(trimmed)
    if (!is.null(var_name)) {
      entry$name <- var_name
      description_continues <- FALSE
      note_continues <- FALSE
      i <- i + 1
      next
    }

    # Parse based on
    based_on <- detect_based_on(trimmed)
    if (!is.null(based_on)) {
      entry$based_on <- based_on
      description_continues <- FALSE
      note_continues <- FALSE
      i <- i + 1
      next
    }

    # Parse description
    desc <- detect_description(trimmed)
    if (!is.null(desc)) {
      entry$description <- desc
      description_continues <- TRUE
      note_continues <- FALSE
      i <- i + 1
      next
    }

    # Parse note
    note <- detect_note(trimmed)
    if (!is.null(note)) {
      entry$note <- note
      note_continues <- TRUE
      description_continues <- FALSE
      i <- i + 1
      next
    }

    # Check for specs table
    if (detect_specs_header(trimmed)) {
      in_specs <- TRUE
      description_continues <- FALSE
      note_continues <- FALSE
      i <- i + 1
      next
    }

    # Parse spec rows
    if (in_specs && trimmed != "") {
      spec <- parse_spec_row(line)
      if (!is.null(spec)) {
        entry$specifications <- c(entry$specifications, list(spec))
      }
    }

    # Continue description across lines
    if (description_continues && trimmed != "" && !in_specs) {
      if (!grepl("^(Based on|Note|Value|Condition)", trimmed, ignore.case = TRUE)) {
        entry$description <- paste(entry$description, trimmed)
      }
    }

    # Continue note across lines
    if (note_continues && trimmed != "" && !in_specs) {
      if (!grepl("^(Based on|Description|Value|Condition|Specifications)", trimmed, ignore.case = TRUE)) {
        entry$note <- paste(entry$note, trimmed)
      }
    }

    i <- i + 1
  }

  # Clean embedded page headers from description and note
  entry$description <- clean_embedded_headers(entry$description)
  entry$note <- clean_embedded_headers(entry$note)

  entry$end_idx <- i - 1
  return(entry)
}

# Parse all derived variables from document
parse_derived_variables <- function(lines) {
  variables <- list()
  modules <- list()
  current_module <- NULL

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Clean page headers/footers
    cleaned <- clean_dv_line(line)
    if (cleaned == "") {
      i <- i + 1
      next
    }

    trimmed <- trimws(cleaned)

    # Check for module header
    module <- detect_module_header(trimmed)
    if (!is.null(module)) {
      current_module <- module
      modules <- c(modules, list(module))
      i <- i + 1
      next
    }

    # Check for variable header
    var_name <- detect_variable_header(trimmed)
    if (!is.null(var_name)) {
      entry <- parse_derived_variable(lines, i)
      if (!is.null(entry$name)) {
        entry$module <- current_module$code
        entry$module_name <- current_module$name
        variables[[entry$name]] <- entry
        i <- entry$end_idx
      }
    }

    i <- i + 1
  }

  return(list(
    modules = modules,
    variables = variables
  ))
}

#==============================================================================
# MAIN EXECUTION (only runs when script is called directly)
#==============================================================================

if (sys.nframe() == 0) {

  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    stop("Usage: Rscript extract_derived_variables.R <pdf_file> [output_file]")
  }

  pdf_file <- args[1]
  if (!file.exists(pdf_file)) {
    stop("PDF file not found: ", pdf_file)
  }

  # Default output file
  if (length(args) >= 2) {
    output_file <- args[2]
  } else {
    output_file <- sub("\\.pdf$", ".yaml", pdf_file, ignore.case = TRUE)
  }

  cat("Extracting from:", pdf_file, "\n")
  cat("Output to:", output_file, "\n\n")

  # Compute checksum of source PDF
  pdf_checksum <- digest(file = pdf_file, algo = "sha256")
  pdf_size <- file.info(pdf_file)$size

  # Extract text from PDF using pdftotext
  text <- system2("pdftotext", c("-layout", shQuote(pdf_file), "-"), stdout = TRUE)

  cat("Parsing PDF text...\n")
  result <- parse_derived_variables(text)

  cat("Found", length(result$modules), "modules\n")
  cat("Found", length(result$variables), "derived variables\n")

  # Build output structure
  output <- list(
    survey = "CCHS",
    category = "derived-variables",
    language = "EN",
    source = list(
      filename = basename(pdf_file),
      path = pdf_file,
      checksum_sha256 = pdf_checksum,
      file_size_bytes = pdf_size
    ),
    extraction = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_derived_variables.R",
      script_version = "1.0.0",
      output_format = "yaml",
      modules_count = length(result$modules),
      variables_count = length(result$variables)
    ),
    modules = lapply(result$modules, function(m) {
      list(code = m$code, name = m$name, dv_count = m$count)
    }),
    variables = lapply(result$variables, function(v) {
      list(
        name = v$name,
        module = v$module,
        based_on = v$based_on,
        description = v$description,
        note = if (nchar(v$note) > 0) v$note else NULL,
        specifications = v$specifications
      )
    })
  )

  # Write YAML
  cat("Writing YAML...\n")
  yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
  writeLines(yaml_text, output_file)

  cat("Done! Extracted", length(result$variables), "derived variables to", output_file, "\n")

  # Print sample
  if (length(result$variables) > 0) {
    cat("\nSample variable:\n")
    sample_var <- result$variables[[1]]
    cat("  Name:", sample_var$name, "\n")
    cat("  Module:", sample_var$module, "\n")
    cat("  Based on:", paste(sample_var$based_on, collapse = ", "), "\n")
    cat("  Specs:", length(sample_var$specifications), "rows\n")
  }
}
