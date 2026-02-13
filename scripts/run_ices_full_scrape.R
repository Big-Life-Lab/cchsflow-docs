#!/usr/bin/env Rscript
# run_ices_full_scrape.R
# Run the complete ICES CCHS variable scrape (14,006 variables)
#
# Estimated time: ~6 hours at 1.5s rate limit
#
# Usage:
#   Rscript --vanilla scripts/run_ices_full_scrape.R
#
# Output:
#   data/catalog/ices_cchs_variables.yaml
#   data/catalog/ices_cchs_availability_matrix.csv

# Change to project root
setwd(normalizePath(file.path(dirname(sys.frame(1)$ofile), "..")))

source("R/scrape_ices_variables.R")

cat("=================================================\n")
cat("ICES CCHS Full Variable Scrape\n")
cat("=================================================\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("\n")

# Load variable names
var_file <- "development/ices-dictionary/ices_variable_names.txt"
if (!file.exists(var_file)) {
  stop("Variable names file not found: ", var_file)
}

variable_names <- readr::read_lines(var_file)
variable_names <- variable_names[nchar(trimws(variable_names)) > 0]

cat("Variables to scrape:", length(variable_names), "\n")
cat("Rate limit: 1.5 seconds\n")
cat("Estimated time:", round(length(variable_names) * 1.5 / 3600, 1), "hours\n")
cat("\n")

# Run the scrape
results <- scrape_ices_variables_batch(variable_names, delay = 1.5)

# Save results
save_ices_results(results)

cat("\n")
cat("=================================================\n")
cat("Scrape complete!\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Variables scraped:", length(results$variables), "\n")
cat("Variables not found:", length(results$not_found), "\n")
cat("=================================================\n")
