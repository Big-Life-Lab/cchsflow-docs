#!/usr/bin/env Rscript
# Extract structured data from CCHS data dictionary PDFs
#
# Usage:
#   Rscript extract_data_dictionary.R <pdf_file> [output_file] [--metadata key=value ...] [--raw-text]
#
# Output: YAML file with variable definitions aligned with DDI structure
#         Optionally, a companion QMD file with raw text for validation
#
# Options:
#   --raw-text     Generate a companion .qmd file with raw extracted text
#                  organized by variable for manual validation
#
# Metadata options (passed as --metadata key=value):
#   year           Survey year (e.g., "2015-2016")
#   temporal_type  single/dual/multi (s/d/m)
#   doc_type       master/share/pumf (m/s/p)
#   language       EN/FR
#   cchs_uid       Catalog UID (e.g., cchs-2015d-p-dd-en-pdf-01)
#   catalog_id     6-char catalog ID
#   canonical      Canonical filename base
#   source_path    Original PDF path relative to repo
#
# This script can also be sourced to use the parsing functions directly:
#   source("extract_data_dictionary.R")
#   variables <- parse_variables(lines)

suppressPackageStartupMessages({
  library(yaml)
  library(digest)
})

#==============================================================================
# PARSING FUNCTIONS (can be sourced by other scripts)
#==============================================================================

# Detect PDF format based on first few variable entries
# Returns "new" (2015+) or "old" (2007-2014)
detect_format <- function(lines) {
  # Scan a larger portion for PUMF format since it may have extensive preamble
  # PUMF PDFs can have 6000+ lines of documentation before variable definitions
  scan_limit <- min(10000, length(lines))

  for (line in lines[1:scan_limit]) {
    # PUMF/ODESI format: "# VARNAME: label" (e.g., "# ADM_RNO: Sequential record number")
    if (grepl("^# [A-Z][A-Z0-9_]+:", line)) {
      return("pumf")
    }
    # New format: "Variable Name:      VARNAME"
    if (grepl("^Variable Name:\\s+\\S+", line)) {
      return("new")
    }
    # Old format: "Variable Name      VARNAME      Length"
    if (grepl("^Variable\\s+Name\\s+[A-Z]", line)) {
      return("old")
    }
  }
  return("new")  # Default to new format
}

# Parse variable entries from PDF text lines
# Handles old (2007-2014), new (2015+), and PUMF/ODESI formats
parse_variables <- function(lines) {
  format <- detect_format(lines)

  if (format == "old") {
    return(parse_variables_old(lines))
  } else if (format == "pumf") {
    return(parse_variables_pumf(lines))
  } else {
    return(parse_variables_new(lines))
  }
}

# Parse NEW format (2015+): "Variable Name:      XXX_NNN"
parse_variables_new <- function(lines) {
  variables <- list()

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Look for variable header (may have leading whitespace)
    if (grepl("^\\s*Variable Name:\\s+", line)) {
      var_entry <- parse_single_variable_new(lines, i)
      if (!is.null(var_entry)) {
        variables[[var_entry$name]] <- var_entry
        # Skip past this entry
        i <- var_entry$end_line
      }
    }
    i <- i + 1
  }

  return(variables)
}

# Parse OLD format (2007-2014): "Variable Name      VARNAME      Length      N"
parse_variables_old <- function(lines) {
  variables <- list()

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Look for variable header - old format has no colon
    # Must include "Length" to distinguish from index/TOC entries
    # Pattern: "Variable Name      GEOGPRV                       Length            2    Position        9 - 10"
    if (grepl("^Variable\\s+Name\\s+[A-Z0-9_]+.*Length", line)) {
      var_entry <- parse_single_variable_old(lines, i)
      if (!is.null(var_entry)) {
        variables[[var_entry$name]] <- var_entry
        # Skip past this entry
        i <- var_entry$end_line
      }
    }
    i <- i + 1
  }

  return(variables)
}

# Parse single variable - NEW format (2015+)
parse_single_variable_new <- function(lines, start_line) {
  # Extract variable name, length, position from header line
  header <- lines[start_line]

  # Pattern: "Variable Name:      SMK_005                              Length:    1.0                                   Position: 319"
  name_match <- regmatches(header, regexpr("Variable Name:\\s+(\\S+)", header))
  if (length(name_match) == 0) return(NULL)

  var_name <- sub("Variable Name:\\s+", "", name_match)

  # Extract length
  length_match <- regmatches(header, regexpr("Length:\\s+([0-9.]+)", header))
  var_length <- if (length(length_match) > 0) {
    as.numeric(sub("Length:\\s+", "", length_match))
  } else NA

  # Extract position
  pos_match <- regmatches(header, regexpr("Position:\\s+([0-9-]+)", header))
  var_position <- if (length(pos_match) > 0) {
    sub("Position:\\s+", "", pos_match)
  } else NA

  # Now parse subsequent lines for concept, question, universe, categories
  entry <- list(
    name = var_name,
    length = var_length,
    position = var_position,
    label = NA,
    question_text = NA,
    universe = NA,
    note = NA,
    categories = list()
  )

  i <- start_line + 1
  in_categories <- FALSE

  while (i <= length(lines)) {
    line <- lines[i]

    # Stop at next variable (may have leading whitespace)
    if (grepl("^\\s*Variable Name:\\s+", line)) {
      break
    }

    # Parse fields (may have leading whitespace)
    if (grepl("^\\s*Concept:", line)) {
      # May span multiple lines - collect continuation lines
      entry$label <- trimws(sub("^\\s*Concept:\\s*", "", line))
      # Look ahead for continuation lines (indented text before next field)
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field or variable header
        if (grepl("^\\s*(Question Text:|Universe:|Note:|Answer Categories|Variable Name:)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") {
          j <- j + 1
          next
        }
        # Skip page headers - these appear as "Page XX - YYY" with page totals
        if (grepl("Page\\s+\\d+\\s*-\\s*\\d+", next_line)) {
          j <- j + 1
          next
        }
        # Skip lines containing form feed or CCHS header patterns
        if (grepl("\\f|CCHS\\s+\\d+\\s*-\\s*Data Dictionary|Master [Ff]ile", next_line)) {
          j <- j + 1
          next
        }
        # Skip "Updated Month Year" footers
        if (grepl("Updated\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}", next_line)) {
          j <- j + 1
          next
        }
        # Skip standalone "Month Year" page headers (e.g., "November 2023")
        if (grepl("^\\s*(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}\\s*$", next_line)) {
          j <- j + 1
          next
        }
        # Continuation: indented line that's not a field header
        if (grepl("^\\s{10,}", next_line) && !grepl("^\\s*\\S+:", next_line)) {
          entry$label <- paste(entry$label, trimws(next_line))
          j <- j + 1
        } else {
          break
        }
      }
    } else if (grepl("^\\s*Question Text:", line)) {
      # Question text may span multiple lines (e.g., "Very satis-" / "fied")
      entry$question_text <- trimws(sub("^\\s*Question Text:\\s*", "", line))
      # Look ahead for continuation lines until next field (Universe:, Note:, Answer Categories)
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field or variable header
        if (grepl("^\\s*(Universe:|Note:|Answer Categories|Variable Name:)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") {
          j <- j + 1
          next
        }
        # Skip page headers - these appear as "Page XX - YYY" with page totals
        if (grepl("Page\\s+\\d+\\s*-\\s*\\d+", next_line)) {
          j <- j + 1
          next
        }
        # Skip lines containing form feed or CCHS header patterns
        if (grepl("\\f|CCHS\\s+\\d+\\s*-\\s*Data Dictionary|Master [Ff]ile", next_line)) {
          j <- j + 1
          next
        }
        # Skip "Updated Month Year" footers
        if (grepl("Updated\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}", next_line)) {
          j <- j + 1
          next
        }
        # Skip standalone "Month Year" page headers (e.g., "November 2023")
        if (grepl("^\\s*(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}\\s*$", next_line)) {
          j <- j + 1
          next
        }
        # Continuation: indented line that's not a field header
        if (grepl("^\\s{10,}", next_line) && !grepl("^\\s*\\S+:", next_line)) {
          entry$question_text <- paste(entry$question_text, trimws(next_line))
          j <- j + 1
        } else {
          break
        }
      }
    } else if (grepl("^\\s*Universe:", line)) {
      # Universe may span multiple lines
      entry$universe <- trimws(sub("^\\s*Universe:\\s*", "", line))
      # Look ahead for continuation lines
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field or variable header
        if (grepl("^\\s*(Note:|Source:|Answer Categories|Variable Name:)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") { j <- j + 1; next }
        # Skip page headers and footers
        if (grepl("Page\\s+\\d+\\s*-\\s*\\d+", next_line)) { j <- j + 1; next }
        if (grepl("\\f|CCHS\\s+\\d+\\s*-\\s*Data Dictionary|Master [Ff]ile", next_line)) { j <- j + 1; next }
        if (grepl("Updated\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}", next_line)) { j <- j + 1; next }
        # Skip standalone "Month Year" page headers (e.g., "November 2023")
        if (grepl("^\\s*(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}\\s*$", next_line)) { j <- j + 1; next }
        # Continuation: indented line that's not a field header
        if (grepl("^\\s{10,}", next_line) && !grepl("^\\s*\\S+:", next_line)) {
          entry$universe <- paste(entry$universe, trimws(next_line))
          j <- j + 1
        } else { break }
      }
    } else if (grepl("^\\s*Note:", line)) {
      # Note may span multiple lines
      entry$note <- trimws(sub("^\\s*Note:\\s*", "", line))
      # Look ahead for continuation lines
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field or variable header
        if (grepl("^\\s*(Source:|Answer Categories|Variable Name:)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") { j <- j + 1; next }
        # Skip page headers and footers
        if (grepl("Page\\s+\\d+\\s*-\\s*\\d+", next_line)) { j <- j + 1; next }
        if (grepl("\\f|CCHS\\s+\\d+\\s*-\\s*Data Dictionary|Master [Ff]ile", next_line)) { j <- j + 1; next }
        if (grepl("Updated\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}", next_line)) { j <- j + 1; next }
        # Skip standalone "Month Year" page headers (e.g., "November 2023")
        if (grepl("^\\s*(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}\\s*$", next_line)) { j <- j + 1; next }
        # Continuation: indented line that's not a field header
        if (grepl("^\\s{10,}", next_line) && !grepl("^\\s*\\S+:", next_line)) {
          entry$note <- paste(entry$note, trimws(next_line))
          j <- j + 1
        } else { break }
      }
    } else if (grepl("^\\s*Answer Categories\\s+Code\\s+Frequency", line)) {
      # Start of category table
      in_categories <- TRUE
      last_cat_idx <- 0  # Track index of last category for continuations
    } else if (in_categories && grepl("^\\s+Total\\s+", line)) {
      # End of categories
      in_categories <- FALSE
    } else if (in_categories) {
      # Parse category line
      # Format: "Daily                                                1              15,367              3,765,095      12.3"
      cat_parsed <- parse_category_line(line)
      if (!is.null(cat_parsed)) {
        if (!is.null(cat_parsed$continuation)) {
          # This is a continuation line - append to last category's label
          if (last_cat_idx > 0 && last_cat_idx <= length(entry$categories)) {
            entry$categories[[last_cat_idx]]$label <- paste(
              entry$categories[[last_cat_idx]]$label,
              cat_parsed$continuation
            )
          }
        } else {
          # New category
          entry$categories <- c(entry$categories, list(cat_parsed))
          last_cat_idx <- length(entry$categories)
        }
      }
    }

    i <- i + 1
  }

  # Clean page header/footer contamination from all category labels
  if (length(entry$categories) > 0) {
    for (j in seq_along(entry$categories)) {
      entry$categories[[j]]$label <- clean_label(entry$categories[[j]]$label)
    }
  }

  # Clean page header/footer contamination from variable label and question_text
  entry$label <- clean_label(entry$label)
  entry$question_text <- clean_label(entry$question_text)

  entry$end_line <- i - 1
  return(entry)
}

#==============================================================================
# PUMF/ODESI FORMAT PARSER
# Format: "# VARNAME: label" headers with DDI-derived structure
#==============================================================================

parse_variables_pumf <- function(lines) {
  variables <- list()

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Look for variable headers: "# VARNAME: label"
    if (grepl("^# [A-Z][A-Z0-9_]+:", line)) {
      entry <- parse_single_variable_pumf(lines, i)
      if (!is.null(entry) && !is.null(entry$name)) {
        variables[[entry$name]] <- entry
        i <- entry$end_line
      }
    }
    i <- i + 1
  }

  return(variables)
}

parse_single_variable_pumf <- function(lines, start_line) {
  header <- lines[start_line]

  # Parse header: "# VARNAME: label"
  header_match <- regmatches(header, regexec("^# ([A-Z][A-Z0-9_]+):\\s*(.*)$", header))[[1]]
  if (length(header_match) < 3) return(NULL)

  var_name <- header_match[2]
  var_label <- trimws(header_match[3])

  # Initialize entry
  entry <- list(
    name = var_name,
    label = var_label,
    length = NA,
    position = NA,
    question_text = NA,
    universe = NA,
    note = NA,
    categories = list()
  )

  i <- start_line + 1
  in_categories <- FALSE
  last_cat_idx <- 0

  while (i <= length(lines)) {
    line <- lines[i]
    trimmed <- trimws(line)

    # Stop at next variable header
    if (grepl("^# [A-Z][A-Z0-9_]+:", line)) {
      break
    }

    # Skip warning lines
    if (grepl("^Warning:", line)) {
      i <- i + 1
      next
    }

    # Parse Information line: [Type= discrete] [Format=numeric] [Range= 10-62]
    if (grepl("^Information\\s+", line)) {
      # Extract type and format
      type_match <- regmatches(line, regexec("\\[Type=\\s*([^]]+)\\]", line))[[1]]
      if (length(type_match) >= 2) entry$type <- trimws(type_match[2])
    }

    # Parse Universe
    if (grepl("^Universe\\s+", line)) {
      entry$universe <- trimws(sub("^Universe\\s+", "", line))
    }

    # Parse Notes
    if (grepl("^Notes\\s+", line)) {
      entry$note <- trimws(sub("^Notes\\s+", "", line))
    }

    # Parse Definition
    if (grepl("^Definition\\s+", line)) {
      entry$definition <- trimws(sub("^Definition\\s+", "", line))
    }

    # Detect category table header
    if (grepl("^\\s*Value\\s+Label\\s+", line)) {
      in_categories <- TRUE
      i <- i + 1
      next
    }

    # Parse category lines
    if (in_categories && trimmed != "") {
      cat_parsed <- parse_category_line_pumf(line)
      if (!is.null(cat_parsed)) {
        if (!is.null(cat_parsed$continuation)) {
          # Append to last category's label
          if (last_cat_idx > 0 && last_cat_idx <= length(entry$categories)) {
            entry$categories[[last_cat_idx]]$label <- paste(
              entry$categories[[last_cat_idx]]$label,
              cat_parsed$continuation
            )
          }
        } else {
          entry$categories <- c(entry$categories, list(cat_parsed))
          last_cat_idx <- length(entry$categories)
        }
      }
    }

    i <- i + 1
  }

  # Clean page header/footer contamination from all category labels
  if (length(entry$categories) > 0) {
    for (j in seq_along(entry$categories)) {
      entry$categories[[j]]$label <- clean_label(entry$categories[[j]]$label)
    }
  }

  # Clean page header/footer contamination from variable label and question_text
  entry$label <- clean_label(entry$label)
  entry$question_text <- clean_label(entry$question_text)

  entry$end_line <- i - 1
  return(entry)
}

parse_category_line_pumf <- function(line) {
  # Skip empty, header, or warning lines
  trimmed <- trimws(line)
  if (trimmed == "" || grepl("^Value\\s+Label", line) || grepl("^Warning:", line)) {
    return(NULL)
  }

  # PUMF category format: "CODE   LABEL   CASES   WEIGHTED   PERCENTAGE"
  # Example: "999.96                   Valid skip                                                                0                  0.0"
  # Or with percentage: "10                       NEWFOUNDLAND AND LABRADOR                                               3233             459001.9               1.5%"

  # Split on 2+ spaces
  parts <- strsplit(trimmed, "\\s{2,}")[[1]]
  parts <- parts[parts != ""]

  if (length(parts) < 2) {
    # Might be continuation line
    if (nchar(trimmed) > 0 && !grepl("^\\d", trimmed)) {
      return(list(continuation = trimmed))
    }
    return(NULL)
  }

  # First part is code (possibly decimal like 999.96)
  code_str <- parts[1]
  code <- suppressWarnings(as.numeric(code_str))
  if (is.na(code)) {
    # Not a code - might be label continuation or header text
    return(NULL)
  }

  # Preserve decimal codes as strings
  code_value <- if (grepl("\\.", code_str)) code_str else as.integer(code)

  # Second part is label
  label <- parts[2]

  # Build category entry
  cat_entry <- list(
    value = code_value,
    label = label
  )

  # Parse frequency (cases) and weighted frequency
  if (length(parts) >= 3) {
    freq <- suppressWarnings(as.numeric(gsub(",", "", parts[3])))
    if (!is.na(freq)) cat_entry$frequency <- freq
  }
  if (length(parts) >= 4) {
    wfreq <- suppressWarnings(as.numeric(gsub(",|%", "", parts[4])))
    if (!is.na(wfreq)) cat_entry$weighted_frequency <- wfreq
  }
  if (length(parts) >= 5) {
    pct <- suppressWarnings(as.numeric(gsub("%", "", parts[5])))
    if (!is.na(pct)) cat_entry$percent <- pct
  }

  return(cat_entry)
}

# Parse single variable - OLD format (2007-2014)
parse_single_variable_old <- function(lines, start_line) {
  # Extract variable name, length, position from header line
  # Old format: "Variable Name      GEOGPRV                       Length            2    Position        9 - 10"
  header <- lines[start_line]

  # Extract variable name (after "Variable Name" with spaces, before "Length")
  name_match <- regmatches(header, regexpr("Variable\\s+Name\\s+([A-Z0-9_]+)", header))
  if (length(name_match) == 0) return(NULL)

  var_name <- sub("Variable\\s+Name\\s+", "", name_match)

  # Extract length
  length_match <- regmatches(header, regexpr("Length\\s+([0-9.]+)", header))
  var_length <- if (length(length_match) > 0) {
    as.numeric(sub("Length\\s+", "", length_match))
  } else NA

  # Extract position
  pos_match <- regmatches(header, regexpr("Position\\s+([0-9]+\\s*-\\s*[0-9]+|[0-9]+)", header))
  var_position <- if (length(pos_match) > 0) {
    gsub("\\s+", "", sub("Position\\s+", "", pos_match))
  } else NA

  # Initialize entry
 entry <- list(
    name = var_name,
    length = var_length,
    position = var_position,
    label = NA,
    question_text = NA,
    universe = NA,
    note = NA,
    categories = list()
  )

  i <- start_line + 1
  in_categories <- FALSE

  while (i <= length(lines)) {
    line <- lines[i]
    trimmed <- trimws(line)

    # Stop at next variable (must have Length to be actual variable entry)
    if (grepl("^Variable\\s+Name\\s+[A-Z0-9_]+.*Length", line)) {
      break
    }

    # Skip page headers
    if (grepl("^CCHS.*Data Dictionary", line) || grepl("^Page\\s+[0-9]+", trimmed)) {
      i <- i + 1
      next
    }

    # Parse fields - old format uses different field names
    if (grepl("^Concept\\s+", line)) {
      entry$label <- trimws(sub("^Concept\\s+", "", line))
    } else if (grepl("^Question Name", line)) {
      # Old format has "Question Name" but content is on same line or next
      qn <- trimws(sub("^Question Name\\s*", "", line))
      if (nchar(qn) > 0) entry$question_name <- qn
    } else if (grepl("^Question\\s+", line) && !grepl("^Question Name", line)) {
      # Question may span multiple lines
      entry$question_text <- trimws(sub("^Question\\s+", "", line))
      # Look ahead for continuation lines
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field
        if (grepl("^(Universe|Note|Content\\s+Code|Variable\\s+Name)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") { j <- j + 1; next }
        # Skip page headers
        if (grepl("^CCHS|^Page\\s+[0-9]+|^Master [Ff]ile|\\f", next_line)) { j <- j + 1; next }
        # Continuation: indented line
        if (grepl("^\\s{8,}", next_line) && !grepl("^\\s*[A-Z][a-z]+\\s+", next_line)) {
          entry$question_text <- paste(entry$question_text, trimws(next_line))
          j <- j + 1
        } else { break }
      }
    } else if (grepl("^Universe\\s+", line)) {
      entry$universe <- trimws(sub("^Universe\\s+", "", line))
    } else if (grepl("^Note\\s+", line)) {
      # Note may span multiple lines
      entry$note <- trimws(sub("^Note\\s+", "", line))
      # Look ahead for continuation lines
      j <- i + 1
      while (j <= length(lines)) {
        next_line <- lines[j]
        # Stop if we hit a new field or category table
        if (grepl("^(Content\\s+Code|Variable\\s+Name|Source)", next_line)) break
        # Skip empty lines
        if (trimws(next_line) == "") { j <- j + 1; next }
        # Skip page headers
        if (grepl("^CCHS|^Page\\s+[0-9]+|^Master [Ff]ile|\\f", next_line)) { j <- j + 1; next }
        # Continuation: indented line that's not a new field
        if (grepl("^\\s{8,}", next_line) && !grepl("^\\s*[A-Z][a-z]+\\s+", next_line)) {
          entry$note <- paste(entry$note, trimws(next_line))
          j <- j + 1
        } else { break }
      }
    } else if (grepl("^Content\\s+Code\\s+Sample\\s+Population", line)) {
      # Start of category table - old format
      in_categories <- TRUE
      last_cat_idx <- 0  # Track index of last category for continuations
    } else if (in_categories && grepl("^\\s*Total\\s+", line)) {
      # End of categories
      in_categories <- FALSE
    } else if (in_categories && trimmed != "") {
      # Parse category line - old format: "LABEL                    CODE    SAMPLE    POPULATION"
      cat_parsed <- parse_category_line_old(line)
      if (!is.null(cat_parsed)) {
        if (!is.null(cat_parsed$continuation)) {
          # This is a continuation line - append to last category's label
          if (last_cat_idx > 0 && last_cat_idx <= length(entry$categories)) {
            entry$categories[[last_cat_idx]]$label <- paste(
              entry$categories[[last_cat_idx]]$label,
              cat_parsed$continuation
            )
          }
        } else {
          # New category
          entry$categories <- c(entry$categories, list(cat_parsed))
          last_cat_idx <- length(entry$categories)
        }
      }
    }

    i <- i + 1
  }

  # Clean page header/footer contamination from all category labels
  if (length(entry$categories) > 0) {
    for (j in seq_along(entry$categories)) {
      entry$categories[[j]]$label <- clean_label(entry$categories[[j]]$label)
    }
  }

  # Clean page header/footer contamination from variable label and question_text
  entry$label <- clean_label(entry$label)
  entry$question_text <- clean_label(entry$question_text)

  entry$end_line <- i - 1
  return(entry)
}

# Parse category line - OLD format
parse_category_line_old <- function(line) {
  trimmed <- trimws(line)
  if (trimmed == "" || grepl("^Content\\s+Code", line)) {
    return(NULL)
  }

  # Check for range code format first (e.g., "000 - 050    1234    5678" or "Label  000 - 050  1234")
  range_match <- regmatches(trimmed, regexec("^(.*)\\b(\\d+)\\s*-\\s*(\\d+)\\s{2,}([0-9,]+.*)$", trimmed))[[1]]
  if (length(range_match) == 5) {
    label_prefix <- trimws(range_match[2])
    range_start <- range_match[3]
    range_end <- range_match[4]
    rest <- range_match[5]

    nums <- strsplit(rest, "\\s{2,}")[[1]]
    nums <- gsub(",", "", nums)
    nums <- nums[nums != ""]

    range_label <- if (nchar(label_prefix) > 0) {
      label_prefix
    } else {
      paste0("Range ", range_start, " to ", range_end)
    }

    cat_entry <- list(
      value = paste0(range_start, "-", range_end),
      label = range_label,
      is_range = TRUE
    )

    if (length(nums) >= 1) {
      cat_entry$sample <- suppressWarnings(as.numeric(nums[1]))
    }
    if (length(nums) >= 2) {
      cat_entry$population <- suppressWarnings(as.numeric(nums[2]))
    }

    return(cat_entry)
  }

  # Split on multiple spaces
  parts <- strsplit(trimmed, "\\s{2,}")[[1]]
  parts <- parts[parts != ""]

  if (length(parts) < 2) {
    # This might be a continuation line (just text, no numbers)
    if (nchar(trimmed) > 0 && !grepl("^\\d", trimmed) && !grepl("^Page\\s+\\d", trimmed)) {
      return(list(continuation = trimmed))
    }
    return(NULL)
  }

  # First part is label, rest are numeric columns
  label <- parts[1]

  # Try to parse code (should be first numeric after label)
  nums <- parts[-1]
  nums <- gsub(",", "", nums)  # Remove commas from numbers

  # First number is code - preserve decimal for missing value types (999.6, 999.9, etc.)
  code_str <- nums[1]
  code <- suppressWarnings(as.numeric(code_str))
  if (is.na(code)) return(NULL)

  # Preserve decimal codes as strings, convert integers to integer type
  code_value <- if (grepl("\\.", code_str)) code_str else as.integer(code)

  # Build category entry
  cat_entry <- list(
    value = code_value,
    label = label
  )

  # Try to get sample and population (old format columns)
  if (length(nums) >= 2) {
    cat_entry$sample <- suppressWarnings(as.numeric(nums[2]))
  }
  if (length(nums) >= 3) {
    cat_entry$population <- suppressWarnings(as.numeric(nums[3]))
  }

  return(cat_entry)
}

# Clean page header/footer contamination from category labels
# These can get appended when page breaks occur within category tables
clean_label <- function(label) {
  if (is.null(label) || is.na(label) || label == "") return(label)

  # Remove "Master file - 12 Month" and variants (case-insensitive)
  label <- gsub("\\s*Master [Ff]ile\\s*-\\s*12\\s*Month.*$", "", label)
  label <- gsub("\\s*Master [Ff]ile\\s*-\\s*\\d+.*$", "", label)

  # Remove "CCHS YYYY - Data Dictionary" patterns
  label <- gsub("\\s*CCHS\\s+\\d+\\s*-\\s*Data Dictionary.*$", "", label)

  # Remove "Updated Month Year" footers
  label <- gsub("\\s*Updated\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}.*$", "", label)

  # Remove "Month Year" footers (e.g., "September 2017")
  label <- gsub("\\s+(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}$", "", label)

  # Remove page number patterns at end
  label <- gsub("\\s*Page\\s+\\d+\\s*-\\s*\\d+.*$", "", label)

  # Remove form feed characters
  label <- gsub("\\f.*$", "", label)

  trimws(label)
}

parse_category_line <- function(line) {
  # Skip empty or header lines
  if (trimws(line) == "" || grepl("^Answer Categories", line)) {
    return(NULL)
  }

  trimmed <- trimws(line)

  # Skip page headers: "Page 32 - 802" followed by date like "2017-03-16"
  # These appear as "Page XX - 802" in CCHS 2015 master data dictionaries
  # and get incorrectly parsed as range codes if not filtered out
  if (grepl("^Page\\s+\\d+\\s*-\\s*\\d+", trimmed)) {
    return(NULL)
  }

  # Check for range code format first: "00 - 12    5,467    1,057,999    3.4"
  # Range pattern: number-dash-number, possibly with leading label, followed by numeric columns
  # Handle both "00 - 12  5467" and "Label text  00 - 12  5467" formats
  range_match <- regmatches(trimmed, regexec("^(.*)\\b(\\d+)\\s*-\\s*(\\d+)\\s{2,}([0-9,]+.*)$", trimmed))[[1]]
  if (length(range_match) == 5) {
    label_prefix <- trimws(range_match[2])
    range_start <- range_match[3]
    range_end <- range_match[4]
    rest <- range_match[5]

    # Parse numeric columns from rest
    nums <- strsplit(rest, "\\s{2,}")[[1]]
    nums <- gsub(",", "", nums)
    nums <- nums[nums != ""]

    # Use label prefix if present, otherwise generate range label
    range_label <- if (nchar(label_prefix) > 0) {
      label_prefix
    } else {
      paste0("Range ", range_start, " to ", range_end)
    }

    cat_entry <- list(
      value = paste0(range_start, "-", range_end),
      label = range_label,
      is_range = TRUE
    )

    if (length(nums) >= 1) {
      cat_entry$frequency <- suppressWarnings(as.numeric(nums[1]))
    }
    if (length(nums) >= 2) {
      cat_entry$weighted_frequency <- suppressWarnings(as.numeric(nums[2]))
    }
    if (length(nums) >= 3) {
      cat_entry$percent <- suppressWarnings(as.numeric(nums[3]))
    }

    return(cat_entry)
  }

  # Pattern: label (text) followed by numbers
  # Example: "Daily                                                1              15,367              3,765,095      12.3"
  # Also handle code-only lines (no label): "96               107,809           30,213,538     96.6"

  # Split on multiple spaces to separate columns
  parts <- strsplit(trimmed, "\\s{2,}")[[1]]
  parts <- parts[parts != ""]

  if (length(parts) < 2) {
    # This might be a continuation line (just text, no numbers)
    # Return special marker for continuation
    # Skip: page numbers, headers, footers, form feeds
    #
    # Be more permissive about what constitutes a continuation:
    # - Allow lines starting with digits if they look like label text (e.g., "25" from "less than 25")
    # - A line is likely a continuation if it has no numeric columns (just text or a short number)
    # - Skip only clear non-continuation patterns
    if (nchar(trimmed) > 0 &&
        !grepl("^Page\\s+\\d", trimmed) &&
        !grepl("CCHS.*Data Dictionary", trimmed) &&
        !grepl("PUMF", trimmed) &&
        !grepl("Master [Ff]ile", trimmed, ignore.case = TRUE) &&  # Skip "Master File - 12 Month" header fragments
        !grepl("^Updated\\s+", trimmed) &&  # Skip "Updated March 2022" footer
        !grepl("^(January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{4}", trimmed) &&
        !grepl("^\\d{4}-\\d{2}-\\d{2}$", trimmed) &&  # Skip date lines like "2017-03-16"
        !grepl("\\f", trimmed)) {  # Form feed character
      # Additional check: if it's just digits, it's likely a continuation of a numeric label
      # (e.g., "25" continuing "less than 25")
      # But skip if it looks like a standalone frequency count (large number with commas)
      if (grepl("^\\d+$", trimmed) && nchar(trimmed) <= 4) {
        # Short number - likely continuation like "25" from "less than 25"
        return(list(continuation = trimmed))
      } else if (!grepl("^[0-9,]+$", trimmed)) {
        # Not a pure number - it's text continuation
        return(list(continuation = trimmed))
      }
    }
    return(NULL)
  }

  # Check if first part looks like a code (just a number, possibly decimal)
  # This handles lines like "96   107,809   30,213,538   96.6" where there's no label
  # Also handles decimal missing codes like "999.6   Valid skip" -> parsed as code-only
  first_as_num <- suppressWarnings(as.numeric(parts[1]))
  if (!is.na(first_as_num) && grepl("^\\d+\\.?\\d*$", parts[1])) {
    # First part is the code, rest are numeric columns
    # Preserve decimal codes as-is (important for missing value types like 999.6)
    code <- if (grepl("\\.", parts[1])) parts[1] else as.integer(first_as_num)
    nums <- parts[-1]
    nums <- gsub(",", "", nums)

    cat_entry <- list(
      value = code,
      label = ""  # No label for this category
    )

    if (length(nums) >= 1) {
      cat_entry$frequency <- suppressWarnings(as.numeric(nums[1]))
    }
    if (length(nums) >= 2) {
      cat_entry$weighted_frequency <- suppressWarnings(as.numeric(nums[2]))
    }
    if (length(nums) >= 3) {
      cat_entry$percent <- suppressWarnings(as.numeric(nums[3]))
    }

    return(cat_entry)
  }

  # First part is label, rest are numeric columns
  label <- parts[1]

  # Try to parse code (should be first numeric)
  nums <- parts[-1]
  nums <- gsub(",", "", nums)  # Remove commas from numbers

  # First number is code - preserve decimal for missing value types (999.6, 999.9, etc.)
  code_str <- nums[1]
  code <- suppressWarnings(as.numeric(code_str))
  if (is.na(code)) return(NULL)

  # Preserve decimal codes as strings, convert integers to integer type
  code_value <- if (grepl("\\.", code_str)) code_str else as.integer(code)

  # Build category entry
  cat_entry <- list(
    value = code_value,
    label = label
  )

  # Try to get frequency, weighted frequency, percent
  if (length(nums) >= 2) {
    cat_entry$frequency <- suppressWarnings(as.numeric(nums[2]))
  }
  if (length(nums) >= 3) {
    cat_entry$weighted_frequency <- suppressWarnings(as.numeric(nums[3]))
  }
  if (length(nums) >= 4) {
    cat_entry$percent <- suppressWarnings(as.numeric(nums[4]))
  }

  return(cat_entry)
}

# Determine temporal type code from year pattern
infer_temporal <- function(year) {
  if (is.null(year)) return(NULL)
  if (grepl("-", year)) {
    years <- as.numeric(strsplit(year, "-")[[1]])
    if (length(years) == 2 && diff(years) == 1) return("dual")
    return("multi")
  }
  return("single")
}

#==============================================================================
# RAW TEXT OUTPUT FUNCTIONS
#==============================================================================

# Generate a human-readable QMD file with raw extracted text
# Organized by variable for easy manual validation and cross-referencing
generate_raw_text_qmd <- function(variables, output_path, metadata = list()) {
  lines <- character()

  # YAML front matter
  lines <- c(lines, "---")
  lines <- c(lines, paste0("title: \"Data Dictionary - Raw Text Extract\""))
  if (!is.null(metadata$year)) {
    lines <- c(lines, paste0("subtitle: \"CCHS ", metadata$year, "\""))
  }
  lines <- c(lines, paste0("date: \"", format(Sys.Date(), "%Y-%m-%d"), "\""))
  lines <- c(lines, "format: html")
  lines <- c(lines, "---")
  lines <- c(lines, "")
  lines <- c(lines, "This file contains the raw extracted text from the data dictionary PDF,")
  lines <- c(lines, "organized by variable. Use this for manual validation and cross-referencing")
  lines <- c(lines, "with the structured YAML output.")
  lines <- c(lines, "")
  lines <- c(lines, paste0("**Variables extracted:** ", length(variables)))
  lines <- c(lines, "")

  # Table of contents by first letter
  first_letters <- unique(substr(names(variables), 1, 3))
  first_letters <- first_letters[order(first_letters)]

  lines <- c(lines, "## Variable index")
  lines <- c(lines, "")
  for (prefix in first_letters) {
    vars_with_prefix <- names(variables)[startsWith(names(variables), prefix)]
    if (length(vars_with_prefix) > 0) {
      links <- sapply(vars_with_prefix, function(v) paste0("[", v, "](#", tolower(v), ")"))
      lines <- c(lines, paste0("**", prefix, "**: ", paste(links, collapse = ", ")))
    }
  }
  lines <- c(lines, "")
  lines <- c(lines, "---")
  lines <- c(lines, "")

  # Each variable as a section
  for (var_name in names(variables)) {
    var <- variables[[var_name]]
    lines <- c(lines, paste0("## ", var_name, " {#", tolower(var_name), "}"))
    lines <- c(lines, "")

    # Variable metadata
    if (!is.null(var$label)) {
      lines <- c(lines, paste0("**Label:** ", var$label))
      lines <- c(lines, "")
    }

    if (!is.null(var$position) && !is.null(var$length)) {
      lines <- c(lines, paste0("**Position:** ", var$position, ", **Length:** ", var$length))
      lines <- c(lines, "")
    }

    if (!is.null(var$universe)) {
      lines <- c(lines, "**Universe:**")
      lines <- c(lines, "")
      lines <- c(lines, paste0("> ", var$universe))
      lines <- c(lines, "")
    }

    if (!is.null(var$question_text)) {
      lines <- c(lines, "**Question:**")
      lines <- c(lines, "")
      lines <- c(lines, paste0("> ", var$question_text))
      lines <- c(lines, "")
    }

    # Categories table
    if (!is.null(var$categories) && length(var$categories) > 0) {
      lines <- c(lines, "**Categories:**")
      lines <- c(lines, "")
      lines <- c(lines, "| Value | Label | Frequency |")
      lines <- c(lines, "|-------|-------|-----------|")

      for (cat in var$categories) {
        value <- if (is.null(cat$value)) "" else as.character(cat$value)
        label <- if (is.null(cat$label)) "" else cat$label
        # Escape pipe characters in label
        label <- gsub("\\|", "\\\\|", label)
        freq <- if (!is.null(cat$frequency)) {
          format(cat$frequency, big.mark = ",")
        } else if (!is.null(cat$sample)) {
          format(cat$sample, big.mark = ",")
        } else {
          ""
        }
        lines <- c(lines, paste0("| ", value, " | ", label, " | ", freq, " |"))
      }
      lines <- c(lines, "")
    }

    lines <- c(lines, "---")
    lines <- c(lines, "")
  }

  # Write file
  writeLines(lines, output_path)
  cat("Raw text QMD written to:", output_path, "\n")
}

#==============================================================================
# MAIN EXECUTION (only runs when script is called directly, not when sourced)
#==============================================================================

# Check if script is being run directly (not sourced)
if (sys.nframe() == 0) {

  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    stop("Usage: Rscript extract_data_dictionary.R <pdf_file> [output_file] [--metadata key=value ...] [--raw-text]")
  }

  pdf_file <- args[1]
  if (!file.exists(pdf_file)) {
    stop("PDF file not found: ", pdf_file)
  }

  # Parse metadata arguments
  metadata_args <- list()
  i <- 2
  output_file <- NULL
  generate_raw_text <- FALSE

  while (i <= length(args)) {
    if (args[i] == "--metadata" && i < length(args)) {
      i <- i + 1
      # Parse key=value pairs
      while (i <= length(args) && !startsWith(args[i], "--")) {
        kv <- strsplit(args[i], "=", fixed = TRUE)[[1]]
        if (length(kv) == 2) {
          metadata_args[[kv[1]]] <- kv[2]
        }
        i <- i + 1
      }
    } else if (args[i] == "--raw-text") {
      generate_raw_text <- TRUE
      i <- i + 1
    } else if (is.null(output_file) && !startsWith(args[i], "--")) {
      output_file <- args[i]
      i <- i + 1
    } else {
      i <- i + 1
    }
  }

  # Default output file
  if (is.null(output_file)) {
    output_file <- sub("\\.pdf$", ".yaml", pdf_file, ignore.case = TRUE)
  }

  cat("Extracting from:", pdf_file, "\n")
  cat("Output to:", output_file, "\n\n")

  # Compute checksum of source PDF
  pdf_checksum <- digest(file = pdf_file, algo = "sha256")
  pdf_size <- file.info(pdf_file)$size

  # Extract text from PDF using pdftotext
  text <- system2("pdftotext", c("-layout", shQuote(pdf_file), "-"), stdout = TRUE)
  text <- paste(text, collapse = "\n")

  # Split into lines for parsing
  lines <- strsplit(text, "\n")[[1]]

  # Main extraction
  cat("Parsing PDF text...\n")
  variables <- parse_variables(lines)

  cat("Found", length(variables), "variables\n")

  # Helper to get metadata with default
  get_meta <- function(key, default = NULL) {
    if (key %in% names(metadata_args)) metadata_args[[key]] else default
  }

  # Build output structure with comprehensive metadata
  output <- list(
    # Document identification (mirrors catalog schema)
    cchs_uid = get_meta("cchs_uid"),
    catalog_id = get_meta("catalog_id"),

    # Survey identification
    survey = "CCHS",
    year = get_meta("year"),
    temporal_type = get_meta("temporal_type", infer_temporal(get_meta("year"))),

    # Document classification
    category = "data-dictionary",
    doc_type = get_meta("doc_type"),  # master/share/pumf (m/s/p)
    language = get_meta("language", "EN"),

    # File identification
    canonical_filename = if (!is.null(get_meta("canonical"))) {
      paste0(get_meta("canonical"), ".yaml")
    } else NULL,

    # Source provenance
    source = list(
      filename = basename(pdf_file),
      path = get_meta("source_path", pdf_file),
      checksum_sha256 = pdf_checksum,
      file_size_bytes = pdf_size
    ),

    # Extraction metadata
    extraction = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_data_dictionary.R",
      script_version = "1.1.0",
      output_format = "yaml",
      variables_count = length(variables)
    ),

    # Content: Variable definitions
    variables = variables
  )

  # Remove NULL entries for cleaner YAML
  output <- Filter(Negate(is.null), output)
  output$source <- Filter(Negate(is.null), output$source)

  # Write YAML
  cat("Writing YAML...\n")
  yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
  writeLines(yaml_text, output_file)

  cat("Done! Extracted", length(variables), "variables to", output_file, "\n")

  # Print sample
  if (length(variables) > 0) {
    cat("\nSample variable:\n")
    sample_var <- variables[[1]]
    cat("  Name:", sample_var$name, "\n")
    cat("  Label:", sample_var$label, "\n")
    cat("  Categories:", length(sample_var$categories), "\n")
  }

  # Generate raw text QMD if requested
  if (generate_raw_text) {
    qmd_file <- sub("\\.yaml$", ".qmd", output_file)
    cat("\nGenerating raw text QMD...\n")
    generate_raw_text_qmd(
      variables,
      qmd_file,
      metadata = list(year = get_meta("year"))
    )
  }
}
