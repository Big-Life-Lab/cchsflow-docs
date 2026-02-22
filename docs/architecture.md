# CCHS metadata architecture

This document describes the architecture of the cchsflow-docs repository: a unified metadata database and MCP server for the Canadian Community Health Survey.

For the full design rationale and enum references, see [PLAN_database_rebuild.md](../development/architecture/PLAN_database_rebuild.md).

## Overview

The system merges variable metadata from multiple sources into a single DuckDB database, exposed via Model Context Protocol (MCP) tools for LLM agents, R/Python scripts, and web applications.

### Three-tier architecture

```
CSV (source of truth)  →  DuckDB (queryable)  →  MCP server (tools)
```

1. **CSV files** (`data/sources.csv`, `data/datasets.csv`, `data/variables.csv`) are git-tracked, human-editable reference data. They define the skeletal structure: which sources exist, which datasets exist, which variables exist.

2. **DuckDB** (`database/cchs_metadata.duckdb`) is a build artefact (gitignored). The build script loads CSVs, then runs ingestion scripts that enrich the database with per-dataset metadata from primary sources (RData, DDI XML).

3. **MCP server** (`mcp-server/server.py`) exposes 9 query tools over the DuckDB database for LLM agents and scripts.

### Data flow

```
data/sources.csv    ─┐
data/datasets.csv   ─┤─→ database/build_db.R ─→ database/cchs_metadata.duckdb
data/variables.csv  ─┘         │                        │
                        Phase 0: load CSVs              │
                        Phase 1: ingest RData     mcp-server/server.py
                        Phase 2: ingest DDI XML   (9 query tools)
                        Phase 2.5: ingest Master PDF DD  │
                        Phase 3: ingest 613apps   ┌─────┘
                               │                  ▼
                    ┌──────────┘           LLM agents, R/Python
                    ▼                     scripts, web frontends
          ../cchsflow-data/
          data/sources/rdata/ (11)
          ddi/ (11)
          data/sources/613apps/parsed/ (2)
          data/sources/master-pdf-dd/ (4)
```

## Data sources

| Source ID | Name | Authority | Files | Content |
|-----------|------|-----------|-------|---------|
| `pumf_rdata` | CCHS PUMF RData files | primary | 11 | Variable names, R types, factor levels with frequencies |
| `ddi_xml` | CCHS DDI XML documentation | primary | 11 | Labels, question text, universe, response categories, summary statistics |
| `master_sas_label` | CCHS Master SAS English label files | primary | 35 | Variable names and labels from StatCan Master SAS layout files |
| `master_pdf_dd` | CCHS Master PDF Data Dictionary | primary | 2 | Variable definitions, answer categories with frequencies (2022, 2023) |
| `613apps` | 613apps.ca CCHS Data Dictionary | secondary | 24 | Variable names, labels, format codes, response categories (13 Master + 10 PUMF cycles) |
| `ices_scrape` | ICES Data Dictionary scrape | secondary | 1 | Variable names, abbreviated labels, dataset IDs, value formats |
| `cchsflow` | cchsflow R package worksheets | secondary | 2 | Harmonised variable names, family mappings, section/subject classification |
| `yaml_extract` | Extracted YAML data dictionaries | secondary | 42 | Variable definitions from PDF data dictionaries (AI-extracted, quality varies) |

Sources are registered in `data/sources.csv` and loaded into the `sources` table during the build.

## Database schema (v2)

The database has 13 tables and 6 views, defined in `database/schema.sql`.

### CSV-sourced tables

These tables are loaded directly from git-tracked CSV files. They define the reference structure.

| Table | Rows | Description |
|-------|------|-------------|
| `sources` | 8 | Data source registry with authority level |
| `datasets` | 253 | One row per survey file release with parsed cycle, temporal_type, release, geo, content |
| `variables` | 16,963 | One row per unique variable name with three-label model, status, and provenance counts |

### DuckDB-only tables

These tables are machine-generated during ingestion. Too large or dynamic for CSV.

| Table | Rows | Description |
|-------|------|-------------|
| `dataset_sources` | ~276 | Which specific files attest each dataset |
| `dataset_aliases` | ~274 | Maps external IDs (e.g., `CCHS200708_PUMF`) to canonical `dataset_id` |
| `variable_datasets` | ~79,251 | Per-source metadata for each variable-dataset pair (label, type, position, question_text) |
| `value_codes` | ~532,215 | Response categories per variable per dataset, separate rows per source |
| `variable_summary_stats` | ~10,893 | Distributional statistics from DDI XML (mean, median, stdev, min, max) |
| `variable_groups` | ~562 | Module classifications from DDI XML (e.g., "SMK: Smoking") |
| `variable_group_members` | ~9,642 | Which variables belong to which module groups |
| `variable_families` | 0 | Cross-cycle variable equivalents (future) |
| `variable_family_members` | 0 | Maps cycle-specific names to families (future) |
| `catalog_metadata` | 3 | Build metadata (schema version, build date, R version) |

### Views

| View | Purpose |
|------|---------|
| `v_variable_history` | Variable across cycles — best metadata merged from all sources |
| `v_variable_datasets_detail` | All source rows preserved for provenance auditing |
| `v_dataset_variables` | Variables in a dataset with deduplicated labels |
| `v_dataset_provenance` | All sources for each dataset (joins dataset_sources → sources) |
| `v_family_history` | Cross-cycle variable equivalents via family tables |
| `v_variable_groups` | Module membership per variable per dataset |

## Provenance model

Every record tracks its origin. This is essential because the database is populated incrementally from sources of varying reliability.

### Three mechanisms

1. **Source authority** (`sources.authority`): `primary` (StatCan-generated) vs `secondary` (derived/scraped). Primary sources are trusted for promoting `status` from `temp` to `active`.

2. **Row-level metadata** on every table: `version`, `status`, `last_updated`, `notes`. The `status` field tracks verification: `active` (verified against primary source), `temp` (unverified), `draft` (incomplete), `inactive` (superseded).

3. **Separate rows per source** in linking tables: `variable_datasets` is keyed by `(variable_name, dataset_id, source_id)`. The same variable from RData and DDI gets separate rows, each carrying their own metadata. Disagreements are visible, not silently collapsed.

### Three-label model

| Column | Source | Mutable | Purpose |
|--------|--------|---------|---------|
| `label_statcan` | Latest DDI or RData, verbatim | No | Provenance and fidelity |
| `label_short` | CCHS conventions (≤40 chars) | Yes | Table headers, search results |
| `label_long` | Full descriptive | Yes | Documentation |

## Build pipeline

```bash
Rscript --vanilla database/build_db.R
```

The build is deterministic and takes approximately 2 minutes. It deletes the existing database and rebuilds from scratch.

| Phase | Script | Input | Output |
|-------|--------|-------|--------|
| 0 | `build_db.R` | CSVs + `schema.sql` | Fresh DuckDB with sources, datasets, variables, dataset_sources, dataset_aliases |
| 1 | `ingest_pumf_rdata.R` | 11 RData files | variable_datasets, value_codes (source_id = `pumf_rdata`) |
| 2 | `ingest_ddi_xml.R` | 11 DDI XML files | variable_datasets, value_codes, variable_summary_stats, variable_groups (source_id = `ddi_xml`) |
| 2.5 | `ingest_master_pdf_dd.R` | 4 Master DD CSVs | variable_datasets, value_codes for 2022-2023 Master (source_id = `master_pdf_dd`) |
| 3 | `ingest_613apps.R` | 2 parsed CSVs | variable_datasets, value_codes for 13 Master + 9 PUMF cycles (source_id = `613apps`) |
| Post | `build_db.R` | — | Status promotion: variables with primary sources → `active` |

Future phases (not yet implemented):
- **Phase 4**: Variable family seeding from cchsflow
- **Phase 5**: Merge validation and integrity checks

## MCP server

The MCP server at `mcp-server/server.py` exposes 9 read-only tools via FastMCP:

| Tool | Purpose |
|------|---------|
| `search_variables` | Full-text search on variable names and labels |
| `get_variable_detail` | Complete metadata for one variable (history, value codes, summary stats, groups) |
| `get_variable_history` | Trace a variable across all cycles and datasets |
| `get_dataset_variables` | List all variables in a dataset (with alias resolution) |
| `get_common_variables` | Variables shared between two datasets |
| `compare_master_pumf` | Compare a variable across file types within a cycle |
| `get_value_codes` | Response categories with weighted frequencies |
| `suggest_cchsflow_row` | Draft cchsflow worksheet row for harmonization |
| `get_database_summary` | High-level database statistics |

For tutorials and workflow examples, see [mcp-guide.md](mcp-guide.md). For complete tool specifications, see [mcp-reference.md](mcp-reference.md).

### Configuration

The MCP server is configured in `.mcp.json` at the repository root. It connects to the DuckDB database via the `CCHS_DB_PATH` environment variable.

## Repository structure

```
cchsflow-docs/
├── database/
│   ├── cchs_metadata.duckdb       # Build artefact (gitignored)
│   ├── schema.sql                 # v2 schema DDL (13 tables, 6 views)
│   └── build_db.R                 # Master build script (Phase 0→1→2→2.5→3)
├── ingestion/
│   ├── ingest_pumf_rdata.R        # Phase 1: RData → variable_datasets + value_codes
│   ├── ingest_ddi_xml.R           # Phase 2: DDI XML → full enrichment
│   ├── ingest_master_pdf_dd.R     # Phase 2.5: Master PDF DD → variable_datasets + value_codes
│   └── ingest_613apps.R           # Phase 3: 613apps → variable_datasets + value_codes
├── mcp-server/
│   ├── server.py                  # FastMCP v2 server (9 tools)
│   └── requirements.txt
├── data/
│   ├── sources.csv                # Source registry (8 sources)
│   ├── datasets.csv               # Dataset definitions (253 datasets)
│   ├── variables.csv              # Variable registry (16,963 variables)
│   ├── sources/
│   │   ├── sas-master-labels/     # 35 StatCan Master SAS label files
│   │   ├── master-pdf-dd/         # Master PDF DD CSVs (2022, 2023)
│   │   └── 613apps/               # 613apps scraped data (raw + parsed)
│   └── catalog/
│       └── cchs_catalog.yaml      # Document-level metadata (1,421 entries)
├── development/
│   ├── architecture/
│   │   ├── PLAN_database_rebuild.md  # Full design rationale and enum references
│   │   └── PROPOSAL_mcp_metadata_architecture.md
│   └── ontology/                  # Variable relationship modelling (in progress)
├── docs/
│   ├── architecture.md            # This file
│   ├── mcp-guide.md               # MCP tool tutorials and workflow examples
│   └── mcp-reference.md           # MCP tool specifications
├── .claude/
│   └── skills/
│       ├── cchs-database/         # Database build and maintenance workflow
│       └── cchs-documentation/    # CCHS documentation lookups and naming conventions
└── .mcp.json                      # MCP server configuration
```

## Design decisions

1. **Variable names as primary keys.** DDI position IDs (V622, V238) change between cycles. Variable names (SMKDSTY) are what researchers use and are stable identifiers.

2. **Normalised storage, denormalised views.** Tables are normalised for integrity. Views aggregate data into complete records so MCP tools return full context in one call.

3. **Full provenance — never collapsed.** Every record keeps its source_id. If RData and DDI both describe the same variable, they get separate rows. This makes disagreements visible and auditable.

4. **CSV source of truth.** Human-editable CSV files define the reference structure. The DuckDB database is a reproducible build artefact. This separates curation (CSV edits) from computation (ingestion scripts).

5. **DuckDB.** Embedded, serverless, fast analytical queries. R and Python both read the same file. No infrastructure to maintain.

6. **Canonical dataset naming.** `cchs-{year}{s|d}-{release}-{geo}[-{content}][-{subfile}]` — human-readable, parseable, consistent. External IDs (ICES, RData filenames) are stored as aliases.

See [PLAN_database_rebuild.md](../development/architecture/PLAN_database_rebuild.md) for the complete set of design decisions, enum references, and schema rationale.
