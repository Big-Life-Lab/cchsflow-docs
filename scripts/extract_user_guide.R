#!/usr/bin/env Rscript
# Extract CCHS user guide PDFs to QMD (Quarto Markdown)
#
# Usage:
#   Rscript extract_user_guide.R <pdf_file> [output_file]
#
# Output: QMD file with YAML frontmatter and markdown content
#         Tables are converted to markdown tables or YAML code blocks
#
# This script can also be sourced to use the parsing functions directly.

suppressPackageStartupMessages({
  library(yaml)
  library(digest)
})

#==============================================================================
# PARSING FUNCTIONS (can be sourced by other scripts)
#==============================================================================

# Detect if a line is a section heading
# Returns list(level, title) or NULL
detect_heading <- function(line) {
  line <- trimws(line)
  if (nchar(line) == 0) return(NULL)


# Pattern: "1. INTRODUCTION" or "4.1 CORE CONTENT" or "5.4.1 Sampling..."
  # Main sections: single number followed by period/dot and text
  if (grepl("^[0-9]+\\.\\s+[A-Z]", line)) {
    title <- sub("^[0-9]+\\.\\s+", "", line)
    return(list(level = 1, title = title, raw = line))
  }

  # Subsections: X.Y pattern
 if (grepl("^[0-9]+\\.[0-9]+\\s+[A-Z]", line)) {
    title <- sub("^[0-9]+\\.[0-9]+\\s+", "", line)
    return(list(level = 2, title = title, raw = line))
  }

  # Sub-subsections: X.Y.Z pattern
  if (grepl("^[0-9]+\\.[0-9]+\\.[0-9]+\\s+", line)) {
    title <- sub("^[0-9]+\\.[0-9]+\\.[0-9]+\\s+", "", line)
    return(list(level = 3, title = title, raw = line))
  }

  # APPENDIX pattern
  if (grepl("^APPENDIX\\s+[A-Z]", line)) {
    return(list(level = 1, title = line, raw = line))
  }

  # ALL CAPS lines that look like section titles (but not page headers)
  if (grepl("^[A-Z][A-Z ]{10,}$", line) && !grepl("CCHS|Microdata|User Guide", line)) {
    return(list(level = 1, title = line, raw = line))
  }

  return(NULL)
}

# Detect table start - looks for "Table X.Y" pattern
detect_table_start <- function(line) {
  if (grepl("^\\s*Table\\s+[0-9]+\\.[0-9]+", line, ignore.case = TRUE)) {
    return(TRUE)
  }
  return(FALSE)
}

# Parse a simple two-column table from text lines
# Returns list with title, headers, rows
parse_simple_table <- function(lines, start_idx) {
  # Find table title
  title_line <- trimws(lines[start_idx])
  title <- sub("^Table\\s+[0-9.]+\\s*", "", title_line)

  # Look for header row (usually has column separators or follows blank line)
  i <- start_idx + 1
  headers <- NULL
  rows <- list()

  # Skip blank lines after title
  while (i <= length(lines) && trimws(lines[i]) == "") {
    i <- i + 1
  }

  # Try to detect table structure
  in_table <- TRUE
  while (i <= length(lines) && in_table) {
    line <- lines[i]
    trimmed <- trimws(line)

    # End of table: blank line followed by non-table content, or new section
    if (trimmed == "") {
      # Check if next non-blank line is a heading
      j <- i + 1
      while (j <= length(lines) && trimws(lines[j]) == "") j <- j + 1
      if (j <= length(lines)) {
        if (!is.null(detect_heading(lines[j]))) {
          in_table <- FALSE
        }
      }
      i <- i + 1
      next
    }

    # Check for new section
    if (!is.null(detect_heading(trimmed))) {
      in_table <- FALSE
      next
    }

    # Parse row - split on multiple spaces
    parts <- strsplit(trimmed, "\\s{2,}")[[1]]
    parts <- parts[parts != ""]

    if (length(parts) >= 2) {
      if (is.null(headers)) {
        headers <- parts
      } else {
        rows <- c(rows, list(parts))
      }
    }

    i <- i + 1
  }

  return(list(
    title = title,
    headers = headers,
    rows = rows,
    end_idx = i - 1
  ))
}

# Convert table to markdown format
table_to_markdown <- function(tbl) {
  if (is.null(tbl$headers) || length(tbl$rows) == 0) {
    return(NULL)
  }

  # Build markdown table
  lines <- character()

  # Header row
  header_line <- paste("|", paste(tbl$headers, collapse = " | "), "|")
  lines <- c(lines, header_line)

  # Separator
  sep_parts <- sapply(tbl$headers, function(h) paste(rep("-", max(3, nchar(h))), collapse = ""))
  sep_line <- paste("|", paste(sep_parts, collapse = " | "), "|")
  lines <- c(lines, sep_line)

  # Data rows
 for (row in tbl$rows) {
    # Pad row to match header length
    while (length(row) < length(tbl$headers)) {
      row <- c(row, "")
    }
    row_line <- paste("|", paste(row[1:length(tbl$headers)], collapse = " | "), "|")
    lines <- c(lines, row_line)
  }

  return(paste(lines, collapse = "\n"))
}

# Convert table to YAML block
table_to_yaml <- function(tbl) {
  if (is.null(tbl$headers) || length(tbl$rows) == 0) {
    return(NULL)
  }

  # Build structured data
  data <- lapply(tbl$rows, function(row) {
    entry <- list()
    for (j in seq_along(tbl$headers)) {
      key <- gsub("[^a-zA-Z0-9]", "_", tolower(tbl$headers[j]))
      entry[[key]] <- if (j <= length(row)) row[j] else ""
    }
    entry
  })

  yaml_text <- as.yaml(list(
    table_title = tbl$title,
    data = data
  ), indent.mapping.sequence = TRUE)

  return(paste0("```yaml\n", yaml_text, "```"))
}

# Clean up text line - remove page headers/footers, fix spacing
clean_line <- function(line) {
  # Remove common page header patterns
  if (grepl("^\\s*[0-9]+\\s*$", line)) return("")  # Page numbers only
  if (grepl("CCHS.*Microdata.*User Guide", line)) return("")  # Page header
  if (grepl("^\\s*[ivxlc]+\\s*$", line, ignore.case = TRUE)) return("")  # Roman numerals

  # Normalize whitespace
  line <- gsub("\\s+", " ", line)

  return(line)
}

# Parse entire document into sections
parse_user_guide <- function(lines) {
  sections <- list()
  current_section <- list(
    level = 0,
    title = "Preamble",
    content = character()
  )

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]
    cleaned <- clean_line(line)

    # Skip empty lines at start of sections
    if (cleaned == "" && length(current_section$content) == 0) {
      i <- i + 1
      next
    }

    # Check for heading
    heading <- detect_heading(cleaned)
    if (!is.null(heading)) {
      # Save current section if it has content
      if (length(current_section$content) > 0 || current_section$title != "Preamble") {
        sections <- c(sections, list(current_section))
      }

      # Start new section
      current_section <- list(
        level = heading$level,
        title = heading$title,
        content = character()
      )
      i <- i + 1
      next
    }

    # Check for table
    if (detect_table_start(cleaned)) {
      tbl <- parse_simple_table(lines, i)
      md_table <- table_to_markdown(tbl)
      if (!is.null(md_table)) {
        current_section$content <- c(
          current_section$content,
          "",
          paste0("**", tbl$title, "**"),
          "",
          md_table,
          ""
        )
      }
      i <- tbl$end_idx + 1
      next
    }

    # Regular content line
    if (cleaned != "") {
      current_section$content <- c(current_section$content, cleaned)
    } else if (length(current_section$content) > 0) {
      # Preserve paragraph breaks
      last_line <- current_section$content[length(current_section$content)]
      if (last_line != "") {
        current_section$content <- c(current_section$content, "")
      }
    }

    i <- i + 1
  }

  # Don't forget last section
  if (length(current_section$content) > 0) {
    sections <- c(sections, list(current_section))
  }

  return(sections)
}

# Convert sections to QMD markdown
sections_to_qmd <- function(sections) {
  output <- character()

  for (section in sections) {
    # Add heading
    if (section$level > 0) {
      heading_prefix <- paste(rep("#", section$level), collapse = "")
      output <- c(output, "", paste(heading_prefix, section$title), "")
    }

    # Add content
    output <- c(output, section$content)
  }

  return(paste(output, collapse = "\n"))
}

#==============================================================================
# MAIN EXECUTION (only runs when script is called directly)
#==============================================================================

if (sys.nframe() == 0) {

  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    stop("Usage: Rscript extract_user_guide.R <pdf_file> [output_file]")
  }

  pdf_file <- args[1]
  if (!file.exists(pdf_file)) {
    stop("PDF file not found: ", pdf_file)
  }

  # Default output file
  if (length(args) >= 2) {
    output_file <- args[2]
  } else {
    output_file <- sub("\\.pdf$", ".qmd", pdf_file, ignore.case = TRUE)
  }

  cat("Extracting from:", pdf_file, "\n")
  cat("Output to:", output_file, "\n\n")

  # Compute checksum of source PDF
  pdf_checksum <- digest(file = pdf_file, algo = "sha256")
  pdf_size <- file.info(pdf_file)$size

  # Extract text from PDF using pdftotext
  text <- system2("pdftotext", c("-layout", shQuote(pdf_file), "-"), stdout = TRUE)
  lines <- text  # Already split by line

  cat("Parsing PDF text...\n")
  sections <- parse_user_guide(lines)
  cat("Found", length(sections), "sections\n")

  # Build QMD content
  body <- sections_to_qmd(sections)

  # Count sections by level
  section_counts <- table(sapply(sections, function(s) s$level))

  # Build YAML frontmatter
  frontmatter <- list(
    title = "CCHS User Guide",
    cchs_uid = NULL,  # To be filled by batch script
    survey = "CCHS",
    category = "user-guide",
    language = "EN",
    source = list(
      filename = basename(pdf_file),
      path = pdf_file,
      checksum_sha256 = pdf_checksum,
      file_size_bytes = pdf_size
    ),
    extraction = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_user_guide.R",
      script_version = "1.0.0",
      output_format = "qmd",
      sections_count = length(sections)
    )
  )

  # Write QMD file
  cat("Writing QMD...\n")

  yaml_header <- as.yaml(frontmatter, indent.mapping.sequence = TRUE)
  qmd_content <- paste0(
    "---\n",
    yaml_header,
    "---\n\n",
    body
  )

  writeLines(qmd_content, output_file)

  cat("Done! Extracted", length(sections), "sections to", output_file, "\n")

  # Print summary
  cat("\nSection summary:\n")
  for (lvl in names(section_counts)) {
    cat("  Level", lvl, ":", section_counts[lvl], "sections\n")
  }
}
