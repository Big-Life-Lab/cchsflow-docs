# cchsflow-docs: Harmonization engine & metadata architecture

## Overview

This repository serves as the "Source of Truth" for the cchsflow R package. It houses the comprehensive metadata for the Canadian Community Health Survey (CCHS), specifically designed to support **variable harmonization** across:

* **Time:** Cycles from 2001 to 2024.
* **Data Source:** Public Use Microdata Files (PUMF) vs. Master Files.

## Core objective

To provide a structured, queryable DuckDB database that allows AI Agents (via MCP) and R developers to:

1. Instantly lookup variable definitions, labels, and categories for any cycle.
2. Compare "Master" vs. "PUMF" variable granularities.
3. Programmatically generate rec_with_table rows for cchsflow.

## Repository structure

```
cchsflow-docs/
├── database/
│   ├── schema.sql          # The DuckDB schema specifications
│   └── build_db.R          # R script to hydrate the DB from CSVs
├── specs/
│   ├── ARCHITECTURE.md     # Technical specs for MCP & Agent workflow
│   └── INGESTION.md        # Rules for parsing raw variables
├── raw_metadata/
│   ├── 2001_1.1/           # Organised by Cycle
│   ├── ...
│   └── 2015_2016/
└── dictionaries/
    ├── master_variable_list.csv  # The 14,000+ variable dump
    └── cchsflow_current.csv      # Current variable_details.csv from package
```

## Quick start

To query the variable history (requires DuckDB):

```bash
duckdb cchs_metadata.duckdb < database/schema.sql
```
