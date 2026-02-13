# build_db.R
# Master build script for the unified CCHS metadata database.
# Runs all ingestion phases in sequence.
# Usage: Rscript --vanilla database/build_db.R

cat("=== Building CCHS Unified Metadata Database ===\n\n")

cat("Phase 1: ICES scrape data\n")
source("ingestion/ingest_ices_scrape.R")

cat("\n\nPhase 2: DDI XML enrichment\n")
source("ingestion/ingest_ddi_xml.R")

cat("\n\n=== Build complete ===\n")
cat("Database: database/cchs_metadata.duckdb\n")
