#!/usr/bin/env Rscript
# Extract structured data from CCHS questionnaire PDFs
#
# Usage:
#   Rscript extract_questionnaire.R <pdf_file> [output_file]
#
# Output: YAML file with question definitions, response options, and skip patterns
#
# This script can also be sourced to use the parsing functions directly:
#   source("extract_questionnaire.R")
#   questions <- parse_questionnaire(lines)

suppressPackageStartupMessages({
  library(yaml)
  library(digest)
})

#==============================================================================
# PARSING FUNCTIONS (can be sourced by other scripts)
#==============================================================================

# Clean line - remove page headers/footers
clean_quest_line <- function(line) {
  trimmed <- trimws(line)
  # Skip page numbers alone
  if (grepl("^[0-9]+$", trimmed)) return("")
  # Skip page headers with document title
  if (grepl("Canadian Community Health Survey", trimmed)) return("")
  if (grepl("^\\s*[0-9]{4}\\s+Questionnaire\\s*$", trimmed)) return("")
  # Skip form feed characters
  if (grepl("^\f", line)) return("")
  return(line)
}

# Detect section/module header
# Pattern: "Module Name (CODE)" or just section titles
detect_section_header <- function(line) {
  trimmed <- trimws(line)

  # Common section patterns
  # "General health (GEN)" or "Chronic conditions (CCC)"
  if (grepl("^[A-Z][a-z].*\\([A-Z]{2,4}\\)\\s*$", trimmed)) {
    # Extract section name and code
    name <- sub("\\s*\\([A-Z]{2,4}\\)\\s*$", "", trimmed)
    code <- regmatches(trimmed, regexpr("\\([A-Z]{2,4}\\)", trimmed))
    code <- gsub("[()]", "", code)
    return(list(name = name, code = code))
  }

  # Section headers like "Core content", "Theme content", "Optional content"
  if (grepl("^(Core|Theme|Optional|Rapid Response)\\s+(content|modules?)\\s*$", trimmed, ignore.case = TRUE)) {
    return(list(name = trimmed, code = NA))
  }

  return(NULL)
}

# Detect question code pattern
# Patterns: "GEN_Q015", "GEN_015", "GEN_C010", "GEN_B010", "GEN_R01", "GEN_N01"
# Q = question, C = condition/check, B = block call, R = read text, N = interviewer note
detect_question_code <- function(line) {
  trimmed <- trimws(line)

  # Pattern: CODE_TYPE### at start of line followed by text
  # e.g., "GEN_Q015    In general, would you say..."
  match <- regmatches(trimmed, regexpr("^[A-Z]{2,6}_[A-Z]?[0-9]{2,3}[A-Z]?", trimmed))
  if (length(match) > 0 && nchar(match) > 0) {
    return(match)
  }

  return(NULL)
}

# Detect variable name line (external variable name, usually on line after question code)
# These are typically standalone variable names like "GEN_015" or "DHH_SEX"
detect_variable_name <- function(line) {
  trimmed <- trimws(line)

  # Standalone variable name (no text after it, or just whitespace)
  if (grepl("^[A-Z]{2,6}_[0-9]{2,3}[A-Z]?\\s*$", trimmed)) {
    return(trimws(trimmed))
  }

  return(NULL)
}

# Detect response option line
# Pattern: "1    Response text" or "DK, RF" or "(DK, RF are not allowed)"
detect_response_option <- function(line) {
  trimmed <- trimws(line)

  # Numbered response: "1    Excellent" or "01   Option"
  if (grepl("^[0-9]{1,2}\\s{2,}", trimmed)) {
    num <- as.integer(regmatches(trimmed, regexpr("^[0-9]+", trimmed)))
    label <- trimws(sub("^[0-9]+\\s+", "", trimmed))
    # Check for skip pattern
    skip <- NULL
    if (grepl("\\(Go to [A-Z]{2,6}_[A-Z]?[0-9]+\\)", label)) {
      skip <- regmatches(label, regexpr("\\(Go to [A-Z]{2,6}_[A-Z]?[0-9]+\\)", label))
      skip <- gsub("[()]", "", skip)
      label <- trimws(sub("\\s*\\(Go to [A-Z]{2,6}_[A-Z]?[0-9]+\\)", "", label))
    }
    return(list(value = num, label = label, skip = skip))
  }

  # DK, RF line
  if (grepl("^DK,?\\s*RF", trimmed)) {
    skip <- NULL
    if (grepl("\\(Go to", trimmed)) {
      skip <- regmatches(trimmed, regexpr("\\(Go to [A-Z]{2,6}_[A-Z]?[0-9]+\\)", trimmed))
      skip <- gsub("[()]", "", skip)
    }
    return(list(value = "DK/RF", label = "Don't know / Refused", skip = skip))
  }

  # "(DK, RF are not allowed)"
  if (grepl("^\\(DK,?\\s*RF\\s+(are\\s+)?not allowed\\)", trimmed, ignore.case = TRUE)) {
    return(list(value = "NO_DK_RF", label = "DK/RF not allowed", skip = NULL))
  }

  return(NULL)
}

# Detect skip/flow control pattern
# Pattern: "If condition, go to CODE" or "Otherwise, go to CODE"
detect_skip_pattern <- function(line) {
  trimmed <- trimws(line)

  if (grepl("(If|Otherwise),?\\s+(go to|Go to)\\s+[A-Z]{2,6}_[A-Z]?[0-9]+", trimmed, ignore.case = TRUE)) {
    # Extract condition and target
    target <- regmatches(trimmed, regexpr("[A-Z]{2,6}_[A-Z]?[0-9]+", trimmed))
    condition <- trimws(sub("(,?\\s*)?(go to|Go to)\\s+[A-Z]{2,6}_[A-Z]?[0-9]+.*$", "", trimmed))
    return(list(condition = condition, target = target))
  }

  return(NULL)
}

# Parse a single question entry
parse_single_question <- function(lines, start_idx, question_code) {
  entry <- list(
    code = question_code,
    variable_name = NA,
    question_text = "",
    interviewer_instruction = NA,
    response_options = list(),
    skip_patterns = list(),
    processing_note = NA,
    question_type = NA  # Q, C, B, R, N
  )

  # Determine question type from code suffix
  if (grepl("_Q[0-9]", question_code)) {
    entry$question_type <- "question"
  } else if (grepl("_C[0-9]", question_code)) {
    entry$question_type <- "condition"
  } else if (grepl("_B[0-9]", question_code)) {
    entry$question_type <- "block"
  } else if (grepl("_R[0-9]", question_code)) {
    entry$question_type <- "read"
  } else if (grepl("_N[0-9]", question_code)) {
    entry$question_type <- "interviewer"
  } else {
    entry$question_type <- "other"
  }

  # Get text on same line as question code
  first_line <- lines[start_idx]
  text_after_code <- trimws(sub(paste0("^", question_code, "\\s*"), "", first_line))
  if (nchar(text_after_code) > 0) {
    entry$question_text <- text_after_code
  }

  i <- start_idx + 1
  in_responses <- FALSE
  text_continues <- TRUE

  while (i <= length(lines)) {
    line <- lines[i]
    cleaned <- clean_quest_line(line)
    if (cleaned == "") {
      i <- i + 1
      next
    }

    trimmed <- trimws(cleaned)

    # Check for next question (end of this one)
    if (i > start_idx && !is.null(detect_question_code(trimmed))) {
      break
    }

    # Check for section header (end of question)
    if (!is.null(detect_section_header(trimmed))) {
      break
    }

    # Check for variable name
    var_name <- detect_variable_name(trimmed)
    if (!is.null(var_name)) {
      entry$variable_name <- var_name
      i <- i + 1
      next
    }

    # Check for response option
    resp <- detect_response_option(trimmed)
    if (!is.null(resp)) {
      in_responses <- TRUE
      text_continues <- FALSE
      entry$response_options <- c(entry$response_options, list(resp))
      i <- i + 1
      next
    }

    # Check for skip pattern
    skip <- detect_skip_pattern(trimmed)
    if (!is.null(skip)) {
      entry$skip_patterns <- c(entry$skip_patterns, list(skip))
      i <- i + 1
      next
    }

    # Check for interviewer instruction
    if (grepl("^INTERVIEWER:", trimmed, ignore.case = TRUE)) {
      instr <- trimws(sub("^INTERVIEWER:\\s*", "", trimmed, ignore.case = TRUE))
      if (is.na(entry$interviewer_instruction)) {
        entry$interviewer_instruction <- instr
      } else {
        entry$interviewer_instruction <- paste(entry$interviewer_instruction, instr)
      }
      i <- i + 1
      next
    }

    # Check for processing note
    if (grepl("^Processing:", trimmed, ignore.case = TRUE)) {
      note <- trimws(sub("^Processing:\\s*", "", trimmed, ignore.case = TRUE))
      entry$processing_note <- note
      i <- i + 1
      next
    }

    # Check for "Note:" line
    if (grepl("^Note:", trimmed, ignore.case = TRUE)) {
      # This is metadata, skip for now
      i <- i + 1
      next
    }

    # Continue building question text if we haven't hit responses yet
    if (text_continues && !in_responses && nchar(trimmed) > 0) {
      # Skip lines that look like section headers or special markers
      if (!grepl("^(If necessary|Read categories|Press <)", trimmed, ignore.case = TRUE)) {
        if (nchar(entry$question_text) > 0) {
          entry$question_text <- paste(entry$question_text, trimmed)
        } else {
          entry$question_text <- trimmed
        }
      } else if (grepl("^(If necessary|Read categories)", trimmed, ignore.case = TRUE)) {
        # This is part of interviewer instruction
        if (is.na(entry$interviewer_instruction)) {
          entry$interviewer_instruction <- trimmed
        } else {
          entry$interviewer_instruction <- paste(entry$interviewer_instruction, trimmed)
        }
      }
    }

    i <- i + 1
  }

  entry$end_idx <- i - 1
  return(entry)
}

# Parse all questions from questionnaire
parse_questionnaire <- function(lines) {
  questions <- list()
  sections <- list()
  current_section <- NULL

  i <- 1
  while (i <= length(lines)) {
    line <- lines[i]

    # Clean page headers/footers
    cleaned <- clean_quest_line(line)
    if (cleaned == "") {
      i <- i + 1
      next
    }

    trimmed <- trimws(cleaned)

    # Check for section header
    section <- detect_section_header(trimmed)
    if (!is.null(section)) {
      current_section <- section
      sections <- c(sections, list(section))
      i <- i + 1
      next
    }

    # Check for question code
    code <- detect_question_code(trimmed)
    if (!is.null(code)) {
      q_entry <- parse_single_question(lines, i, code)
      q_entry$section <- current_section$name
      q_entry$section_code <- current_section$code
      questions[[code]] <- q_entry
      i <- q_entry$end_idx + 1
      next
    }

    i <- i + 1
  }

  return(list(
    questions = questions,
    sections = sections
  ))
}

#==============================================================================
# MAIN EXECUTION (only runs when script is called directly, not when sourced)
#==============================================================================

# Check if script is being run directly (not sourced)
if (sys.nframe() == 0) {

  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1) {
    stop("Usage: Rscript extract_questionnaire.R <pdf_file> [output_file]")
  }

  pdf_file <- args[1]
  if (!file.exists(pdf_file)) {
    stop("PDF file not found: ", pdf_file)
  }

  # Default output file
  output_file <- if (length(args) >= 2) args[2] else sub("\\.pdf$", ".yaml", pdf_file, ignore.case = TRUE)

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
  result <- parse_questionnaire(lines)

  cat("Found", length(result$questions), "questions\n")
  cat("Found", length(result$sections), "sections\n")

  # Build output structure
  output <- list(
    survey = "CCHS",
    category = "questionnaire",

    # Source provenance
    source = list(
      filename = basename(pdf_file),
      path = pdf_file,
      checksum_sha256 = pdf_checksum,
      file_size_bytes = pdf_size
    ),

    # Extraction metadata
    extraction = list(
      date = format(Sys.Date(), "%Y-%m-%d"),
      script = "extract_questionnaire.R",
      script_version = "1.0.0",
      output_format = "yaml",
      questions_count = length(result$questions),
      sections_count = length(result$sections)
    ),

    # Content
    sections = result$sections,
    questions = result$questions
  )

  # Write YAML
  cat("Writing YAML...\n")
  yaml_text <- as.yaml(output, indent.mapping.sequence = TRUE)
  writeLines(yaml_text, output_file)

  cat("Done! Extracted", length(result$questions), "questions to", output_file, "\n")

  # Print sample
  if (length(result$questions) > 0) {
    cat("\nSample question:\n")
    sample_q <- result$questions[[1]]
    cat("  Code:", sample_q$code, "\n")
    cat("  Variable:", sample_q$variable_name, "\n")
    cat("  Type:", sample_q$question_type, "\n")
    cat("  Text:", substr(sample_q$question_text, 1, 60), "...\n")
    cat("  Options:", length(sample_q$response_options), "\n")
  }
}
