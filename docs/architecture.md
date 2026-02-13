# CCHS metadata architecture

This document describes the architecture of the cchsflow-docs repository: a unified metadata database and MCP server for the Canadian Community Health Survey.

## Overview

The system merges variable metadata from multiple sources into a single DuckDB database, exposed via Model Context Protocol (MCP) tools for LLM agents, R/Python scripts, and web applications.

```
  ICES scrape ──────►┌──────────────────────────┐
  (14,005 variables) │    Unified DuckDB         │
                     │                           │
  DDI XML ──────────►│  database/                │
  (11 PUMF files)    │  cchs_metadata.duckdb     │
                     │                           │
  Joel's data ──────►│  (future: v2)             │
  (StatCan files)    │                           │
                     └─────────┬────────────────┘
                               │
                               ▼
                     ┌──────────────────────────┐
                     │    MCP Server             │
                     │    mcp-server/server.py   │
                     │    9 query tools          │
                     └─────────┬────────────────┘
                               │
                  ┌────────────┼────────────────┐
                  ▼            ▼                ▼
            LLM Agents    Web Frontend    R/Python
            (Claude,      (future)        scripts
             Gemini)
```

## Data sources

| Source | Tables populated | Content |
|--------|-----------------|---------|
| ICES Data Dictionary scrape | `datasets`, `variables`, `variable_availability`, `value_formats` | 14,005 variables, 231 datasets, 118,668 availability rows |
| DDI XML files (11 valid) | `ddi_variables` | 11,135 records with question text, universe logic, response categories |
| Joel's Data Dictionary Builder | `statcan_variables` (future) | Ground truth from actual PUMF/Master files |
| cchsflow worksheets | `harmonisation_mappings` (future) | Variable recoding rules |

## Database schema

The unified database is at `database/cchs_metadata.duckdb`. Schema is defined in `database/schema.sql`.

### Core tables (from ICES scrape)

- **`datasets`** (239 rows): Dataset identifiers with parsed `cycle` and `file_type` columns
- **`variables`** (14,005 rows): One row per unique variable name with label, type, format
- **`variable_availability`** (118,668 rows): Which variables appear in which datasets
- **`value_formats`** (11,065 rows): Response category code-label pairs

### DDI enrichment

- **`ddi_variables`** (11,135 rows): Question text, universe/skip logic, structured response categories from DDI XML parsing

### Ontology stubs (empty in v1)

- **`ontology_concepts`**: For capturing conceptual variable groupings
- **`variable_concepts`**: For linking variables to concepts

### Views

- **`v_variable_detail`**: Joins variables + availability + datasets + DDI in a single query
- **`v_variable_history`**: Traces a variable across cycles with DDI context

## MCP server

The MCP server at `mcp-server/server.py` exposes 9 tools via FastMCP:

| Tool | Purpose |
|------|---------|
| `search_variables` | Full-text search on variable names and labels |
| `get_variable_detail` | Complete metadata for one variable |
| `get_variable_history` | Trace a variable across all cycles/datasets |
| `get_dataset_variables` | List all variables in a dataset |
| `get_common_variables` | Variables shared between two datasets |
| `compare_master_pumf` | Compare a variable across file types within a cycle |
| `get_value_codes` | Response categories for a variable |
| `suggest_cchsflow_row` | Draft cchsflow worksheet row for harmonisation |
| `get_database_summary` | High-level database statistics |

### Running the server

```bash
# Install dependencies
pip install -r mcp-server/requirements.txt

# Run directly
python mcp-server/server.py

# Or configure in Claude Code settings
```

### Claude Code configuration

Add to `~/.claude/mcp-servers.json`:

```json
{
  "cchs-metadata": {
    "command": "python",
    "args": ["mcp-server/server.py"],
    "cwd": "/path/to/cchsflow-docs"
  }
}
```

## Ingestion pipeline

The database is built reproducibly from source data:

```bash
Rscript --vanilla database/build_db.R
```

This runs:
1. `ingestion/ingest_ices_scrape.R` — migrates ICES DuckDB, parses cycle/file_type
2. `ingestion/ingest_ddi_xml.R` — parses 11 DDI XML files, loads enrichment data

## Repository structure

```
cchsflow-docs/
├── database/
│   ├── cchs_metadata.duckdb       # Unified database (built artefact)
│   ├── schema.sql                 # DuckDB schema DDL
│   └── build_db.R                 # Master build script
├── ingestion/
│   ├── ingest_ices_scrape.R       # ICES data → DuckDB
│   └── ingest_ddi_xml.R          # DDI XML → DuckDB
├── mcp-server/
│   ├── server.py                  # FastMCP server (9 tools)
│   └── requirements.txt
├── ddi-xml/                       # DDI XML source files (11 valid)
├── data/
│   ├── ices_cchs_dictionary.duckdb  # Original ICES scrape (source)
│   ├── cchs_variable_dictionary.csv # Flat export for LLM consumption
│   └── catalog/                     # YAML document catalogs
├── development/
│   ├── ontology/                  # Variable ontology (in progress)
│   └── redevelopment/             # Architecture proposal and specs
├── reports/
│   └── cchs-variable-browser.html
└── docs/
    └── architecture.md            # This file
```

## Design decisions

1. **Variable names as primary keys.** DDI XML analysis confirmed that position IDs (V622, V238) change between cycles. Variable names (SMKDSTY) are what researchers use.

2. **Normalised storage, denormalised views.** Tables are normalised for integrity. Views aggregate data into complete records so MCP tools return full context in one call.

3. **Separate DDI table.** DDI data is per variable per dataset (11K rows). The base `variables` table has one row per name (14K rows). A LEFT JOIN fills in DDI context where available without breaking queries where it's absent.

4. **Explicit cycle and file_type.** Parsed from dataset_id patterns (e.g., `CCHS201516_ONT_SHARE` → cycle `2015-2016`, file_type `Share`) to support cycle-based queries.

5. **DuckDB.** Embedded, serverless, fast analytical queries. R and Python both read the same file. No infrastructure to maintain.
