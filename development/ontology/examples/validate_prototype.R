# validate_prototype.R
#
# Test queries against the smoking_variables.yaml prototype
# to verify the data model supports the required use cases.
#
# Use cases tested:
#   2.1 - same_variable_different_name discovery
#   2.5 - Find all instances of a conceptual variable
#   2.6 - Find harmonisable variables for a time period
#
# Updated for v0.3.0 with database::variable_name ID format

library(yaml)

# Load the prototype
proto <- read_yaml("smoking_variables.yaml")

cat("=== CCHS Variable Ontology Prototype Validation ===\n")
cat(sprintf("Schema version: %s\n\n", proto$metadata$schema_version))

# -----------------------------------------------------------------------------
# USE CASE 2.1: same_variable_different_name discovery
# Query: "What variables are equivalent to SMKDSTY?"
# -----------------------------------------------------------------------------
cat("USE CASE 2.1: What variables are equivalent to SMKDSTY?\n")
cat(strrep("-", 60), "\n")

# Find the instance variable for SMKDSTY
# New v0.3.0 format: ID is database::variable_name (e.g., cchs2007_2008_p::SMKDSTY)
smkdsty_id <- NULL
for (iv in proto$instance_variables) {
  if (iv$variable_name == "SMKDSTY") {
    smkdsty_id <- iv$id
    cat(sprintf("Found: %s\n", iv$id))
    cat(sprintf("  Variable name: %s\n", iv$variable_name))
    cat(sprintf("  Database: %s\n", iv$database))
    cat(sprintf("  Represented variable: %s\n\n", iv$represented_variable))
    break
  }
}

# Helper function to find all connected variables via same_variable_different_name
find_equivalents <- function(start_id, relationships) {
  visited <- c(start_id)
  queue <- c(start_id)

  while (length(queue) > 0) {
    current <- queue[1]
    queue <- queue[-1]

    for (rel in relationships) {
      if (rel$type == "same_variable_different_name") {
        other <- NULL
        if (rel$source == current && !(rel$target %in% visited)) {
          other <- rel$target
        } else if (rel$target == current && !(rel$source %in% visited)) {
          other <- rel$source
        }
        if (!is.null(other)) {
          visited <- c(visited, other)
          queue <- c(queue, other)
        }
      }
    }
  }
  return(visited)
}

cat("Equivalent variables (traversing same_variable_different_name chain):\n")
equivalent_ids <- find_equivalents(smkdsty_id, proto$relationships)

# Look up variable names for equivalent IDs
# With v0.3.0 format, the ID itself is human-readable (database::variable_name)
for (iv in proto$instance_variables) {
  if (iv$id %in% equivalent_ids) {
    cat(sprintf("  %s\n", iv$id))  # ID already contains db::varname
  }
}
cat("\n")

# -----------------------------------------------------------------------------
# USE CASE 2.5: Find all instances of a conceptual variable
# Query: "What variables measure smoking status?"
# -----------------------------------------------------------------------------
cat("USE CASE 2.5: What variables measure smoking status?\n")
cat(strrep("-", 60), "\n")

# Find the conceptual variable
for (cv in proto$conceptual_variables) {
  if (cv$sub_subject == "status") {
    cat(sprintf("Conceptual variable: %s\n", cv$id))
    cat(sprintf("  Section: %s\n", cv$section))
    cat(sprintf("  Subject: %s\n", cv$subject))
    cat(sprintf("  Sub-subject: %s\n\n", cv$sub_subject))
    break
  }
}

# Find represented variables for cv-smoking-status
cat("Represented variables:\n")
represented_ids <- c()
for (rv in proto$represented_variables) {
  if (rv$conceptual_variable == "cv-smoking-status") {
    represented_ids <- c(represented_ids, rv$id)
    recommended <- if (!is.null(rv$recommended)) rv$recommended else "-"
    cchsflow_var <- if (!is.null(rv$cchsflow_variable)) rv$cchsflow_variable else "-"
    cat(sprintf("  %s: %s (recommended: %s, cchsflow: %s)\n",
                rv$id, rv$label, recommended, cchsflow_var))
  }
}

# Find all instance variables for these represented variables
cat("\nInstance variables:\n")
for (iv in proto$instance_variables) {
  if (iv$represented_variable %in% represented_ids) {
    cat(sprintf("  %s (%s): %s\n", iv$variable_name, iv$database, iv$label))
  }
}
cat("\n")

# -----------------------------------------------------------------------------
# USE CASE 2.6: Find harmonisable variables for a time period
# Query: "What smoking status variables exist for 2007-2015?"
# -----------------------------------------------------------------------------
cat("USE CASE 2.6: Smoking status variables for 2007-2015?\n")
cat(strrep("-", 60), "\n")

# Target databases (using cchsflow naming convention)
target_databases <- c("cchs2007_2008_p", "cchs2009_2010_p", "cchs2011_2012_p",
                      "cchs2013_2014_p", "cchs2015_2016_p")

cat("Target databases:", paste(target_databases, collapse = ", "), "\n\n")

# Find smoking status represented variables
smoking_status_represented <- c("rv-smoking-status-3cat", "rv-smoking-type-6cat")

# Since our prototype uses single database entries, match on prefix
cat("Available variables:\n")
for (iv in proto$instance_variables) {
  if (iv$represented_variable %in% smoking_status_represented) {
    # Check if database falls in our range
    db <- iv$database
    # Extract year from database name (e.g., cchs2007_2008_p -> 2007)
    year_match <- regmatches(db, regexpr("\\d{4}", db))
    if (length(year_match) > 0) {
      year <- as.integer(year_match)
      if (year >= 2007 && year <= 2015) {
        cat(sprintf("  %s (%s): %s\n", iv$variable_name, db, iv$label))
      }
    }
  }
}
cat("\n")

# List the relationship chain
cat("Harmonisation chains (complete potential):\n")
for (rel in proto$relationships) {
  if (rel$type == "same_variable_different_name" &&
      rel$harmonisation_potential == "complete") {
    # Get variable names
    source_name <- target_name <- NULL
    source_db <- target_db <- NULL
    for (iv in proto$instance_variables) {
      if (iv$id == rel$source) {
        source_name <- iv$variable_name
        source_db <- iv$database
      }
      if (iv$id == rel$target) {
        target_name <- iv$variable_name
        target_db <- iv$database
      }
    }
    if (!is.null(source_name) && !is.null(target_name)) {
      cat(sprintf("  %s (%s) → %s (%s)\n", source_name, source_db, target_name, target_db))
    }
  }
}

cat("\n=== Validation complete ===\n")
