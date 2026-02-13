# CCHS metadata architecture: a unified database and API for survey harmonization

**Draft for review** — February 2026

*Reviewed by Google Gemini Deep Research (Feb 2026). Recommendations incorporated below.*

## The problem

Three independent efforts have produced valuable CCHS metadata, but none of them talk to each other:

1. **Joel Barnes' Data Dictionary Builder** ([613apps.ca/data-dictionary-builder](https://613apps.ca/data-dictionary-builder/)). A Shiny app that groups 10+ years of national survey metadata from flat files in a filterable, searchable format. It draws on actual PUMF and Master files at Statistics Canada to list every variable and its response categories. The underlying data is rich but locked inside the app — there is no programmatic API.

2. **cchsflow R package** ([github.com/Big-Life-Lab/cchsflow](https://github.com/Big-Life-Lab/cchsflow)). Provides variable harmonisation across CCHS cycles (2001–2018) via CSV worksheets and R recoding functions. It knows *how* to transform variables but lacks a queryable metadata layer for discovery.

3. **cchsflow-docs repository**. Houses CCHS documentation (PDFs, DDI XML files, data dictionaries) and a scraped DuckDB containing 14,005 variables across 231 datasets from the ICES Data Dictionary. The data is structured but has no query interface beyond raw SQL.

Each effort solves part of the puzzle. None solves all of it. The result is that researchers and developers constantly repeat the same manual lookups: "Is variable X available in cycle Y?", "What response categories does it have?", "Did the variable name change?"

## What we want to build

A single, unified DuckDB database exposed through an MCP (Model Context Protocol) server that any LLM agent, R developer, or web application can query. The database merges metadata from multiple sources and the MCP server provides structured tool-use access.

This is not a replacement for Joel's Shiny app or cchsflow's worksheets. It is the shared data layer that both could draw from — and that new tools (LLM agents, APIs, web frontends) could use directly.

## Use cases

### UC1: Variable lookup

**Actor**: Researcher, LLM agent, or web application

**Query**: "Is SMKDSTY available in CCHS 2015?"

**Current process**: Open Joel's Shiny app and search manually, or grep through PDF documentation.

**Proposed process**: `search_variables("SMKDSTY")` returns structured JSON with availability across all cycles, response categories, and (where available) the original question text.

### UC2: Variable history

**Actor**: cchsflow developer or harmonisation agent

**Query**: "What variable names has smoking status used from 2001 to 2024?"

**Current process**: Manually review data dictionaries for each cycle, noting name changes (SMKA_202 → SMKC_202 → SMKE_202 → SMK_202 → SMK_005 → CSS_05).

**Proposed process**: `get_variable_history("SMK_202")` returns the full chain of datasets where this variable (or its equivalents) appears, with cycle years and file types.

### UC3: Master vs PUMF comparison

**Actor**: Researcher choosing between file types

**Query**: "How does BMI differ between Master and PUMF in 2015–2016?"

**Current process**: Compare two separate data dictionaries side by side.

**Proposed process**: `compare_master_pumf("HWTGBMI", "2015-2016")` returns a structured diff showing that Master has continuous values while PUMF has categorical ranges.

### UC4: New cycle onboarding

**Actor**: cchsflow developer adding CCHS 2023 support

**Query**: "What variables in CCHS 2023 don't exist in our database yet?"

**Current process**: Download the new data dictionary, manually compare against the existing variable list.

**Proposed process**: `get_dataset_variables("CCHS2023_...")` returns the full variable list; a diff against existing data highlights new, renamed, or removed variables.

### UC5: Response category browsing

**Actor**: Researcher designing an analysis, web application user

**Query**: "Show all response options for DHHGAGE across cycles."

**Current process**: Look up each cycle's codebook individually.

**Proposed process**: `get_value_codes("DHHGAGE")` returns the response categories, or `get_variable_detail("DHHGAGE")` returns the full metadata including DDI question text and universe logic.

### UC6: Programmatic API access (Data Dictionary Builder v2)

**Actor**: External application or API client

**Query**: Same as UC1–UC5, but via HTTP.

**Current process**: Not possible. Joel's Shiny app is interactive only.

**Proposed process**: The MCP server could serve as the backend for a next-generation Data Dictionary Builder — either directly (MCP protocol) or wrapped in a lightweight REST API. Any web frontend could query the same database that LLM agents use.

## Data sources

We have metadata from four complementary sources. Each has strengths the others lack.

| Source | What it contains | Strengths | Gaps |
|--------|-----------------|-----------|------|
| **ICES Data Dictionary scrape** | 14,005 variables, 231 datasets (PUMF, Master, Ontario Share, Ontario Linked), response categories | Broadest coverage: every CCHS variable ICES has catalogued | No question text, no universe logic, limited to ICES holdings |
| **DDI XML files** (14 PUMF files) | Variable definitions with question text, universe/skip logic, response categories | Rich context: the actual survey question and who was asked | PUMF only, covers 2001–2018 |
| **Data Dictionary Builder** (Joel's flat files) | Variables and categories from actual PUMF and Master files at Statistics Canada | Ground truth: derived from the data files themselves | Currently not available programmatically |
| **cchsflow worksheets** | Harmonisation mappings (variable_details.csv) | Knows which variables are equivalent across cycles | Focused on harmonised variables only (~300), not the full 14K |

### How they fit together

```
                    ┌──────────────────────────┐
                    │    Unified DuckDB         │
                    │                           │
  ICES scrape ─────►│  variables (14,005)       │
  (broadest)        │  variable_availability    │
                    │  value_formats            │
                    │                           │
  DDI XML ─────────►│  ddi_variables            │
  (richest)         │  (question text,          │
                    │   universe logic)         │
                    │                           │
  Joel's data ─────►│  statcan_variables        │
  (ground truth)    │  (actual file contents)   │
                    │                           │
  cchsflow ────────►│  harmonisation_mappings   │
  (relationships)   │  (rec_from, rec_to)       │
                    │                           │
                    └─────────┬────────────────┘
                              │
                              ▼
                    ┌──────────────────────────┐
                    │    MCP Server (API)       │
                    │                           │
                    │  search_variables()       │
                    │  get_variable_detail()    │
                    │  get_variable_history()   │
                    │  compare_master_pumf()    │
                    │  get_value_codes()        │
                    │  get_database_summary()   │
                    │  ...                      │
                    └─────────┬────────────────┘
                              │
                 ┌────────────┼────────────────┐
                 ▼            ▼                ▼
           LLM Agents    Web Frontend    R/Python
           (Claude,      (Data Dict     scripts
            Gemini)       Builder v2)
```

## Architecture

### The database

**Technology**: DuckDB — a fast, embedded analytical database. No server to maintain. A single `.duckdb` file that R, Python, and the MCP server all read directly.

**Schema overview**:

| Table | Source | Rows (current) | Purpose |
|-------|--------|-----------------|---------|
| `datasets` | ICES scrape | 231 | Dataset identifiers with explicit cycle and file type columns |
| `variables` | ICES scrape | 14,005 | One row per unique variable name, with label and type |
| `variable_availability` | ICES scrape | 118,668 | Which variables appear in which datasets |
| `value_formats` | ICES scrape | 11,065 | Response categories (code → label mappings) |
| `ddi_variables` | DDI XML | ~TBD | Question text, universe logic, and structured categories from DDI |
| `ontology_stubs` | Manual | 0 (v1) | Empty tables for capturing variable equivalences as they're discovered |
| `catalog_metadata` | Various | 9 | Database version, source provenance |

The schema is designed so that each source populates its own table(s) and views join them together. This means:

- Adding Joel's data is a matter of creating a new table (`statcan_variables`) and updating the views — no restructuring required.
- Missing data from one source does not break queries. A LEFT JOIN fills in what's available.
- Each source remains independently verifiable.

**Key design decision**: Variable names are the primary key. Our analysis of DDI XML files confirmed that the `ID` attribute (e.g., V622) is a sequential position identifier that changes between cycles. The `name` attribute (e.g., SMKDSTY) is what researchers use and search for.

### The MCP server

**Technology**: Python FastMCP — a lightweight framework for exposing tools via the Model Context Protocol.

**What is MCP?** The Model Context Protocol is a standard that allows LLM applications (Claude, Gemini, etc.) to call structured functions ("tools") rather than relying on raw text dumps. Instead of pasting a 14,000-row CSV into a prompt, the LLM calls `search_variables("smoking")` and gets back exactly the 15 relevant rows as structured JSON.

**Proposed tools**:

| Tool | Parameters | Returns |
|------|-----------|---------|
| `search_variables` | `query`, `limit` | Variables matching by name or label |
| `get_variable_detail` | `variable_name` | Full metadata: label, type, question text, categories, availability |
| `get_variable_history` | `variable_name` | All datasets where this variable appears, with cycle years |
| `get_dataset_variables` | `dataset_id`, `limit` | All variables in a specific dataset |
| `get_common_variables` | `dataset_id_1`, `dataset_id_2` | Variables shared between two datasets |
| `compare_master_pumf` | `variable_name`, `cycle` | Side-by-side comparison of Master vs PUMF metadata |
| `get_value_codes` | `variable_name` | Response categories for a variable |
| `suggest_cchsflow_row` | `variable_name`, `target_cycle` | Draft cchsflow worksheet row (`rec_with_table` format) for a variable in a new cycle |
| `get_database_summary` | — | High-level statistics: variable count, dataset count, coverage |

Each tool returns structured JSON. The same tools could be wrapped in a REST API with minimal additional code.

### From MCP to REST API

MCP tools are functions with typed parameters and structured returns — essentially the same as REST API endpoints. A thin wrapper (FastAPI, Plumber, or similar) could expose the same functions as HTTP endpoints:

```
MCP:  search_variables(query="smoking", limit=10)
REST: GET /api/variables/search?query=smoking&limit=10
```

This means Joel's next-generation Data Dictionary Builder could consume the same backend that LLM agents use. One database, multiple interfaces.

## Repository structure

The cchsflow-docs repository currently contains ~2.5 GB of documentation mirrors (PDFs synced from OSF.io). These PDFs now live on Google Drive. We propose restructuring around the database and MCP server:

```
cchsflow-docs/
├── database/
│   ├── cchs_metadata.duckdb       # The unified database (built artefact)
│   ├── schema.sql                 # DuckDB schema DDL
│   └── build_db.R                 # Master build script
├── ingestion/
│   ├── ingest_ices_scrape.R       # Load ICES data → DuckDB
│   ├── ingest_ddi_xml.R           # Parse DDI XML → DuckDB
│   ├── ingest_extracted_yaml.R    # Load extracted YAMLs → DuckDB
│   └── README.md
├── mcp-server/
│   ├── server.py                  # FastMCP server
│   ├── requirements.txt
│   └── README.md
├── ddi-xml/                       # DDI XML files (~50 MB, kept in repo)
├── data/
│   ├── cchs_variable_dictionary.csv  # Flat export for LLM consumption
│   └── catalog/                      # YAML catalogs
├── development/
│   ├── ontology/                  # Variable ontology (in progress)
│   └── redevelopment/             # Planning documents
├── reports/
│   └── cchs-variable-browser.html
└── docs/
    └── architecture.md
```

**What gets removed**: ~1.3 GB of OSF documentation mirrors. PDFs are stored on Google Drive; this repo becomes the catalog and database.

## Ingestion pipeline

The database is built from source data in a reproducible pipeline:

```
Phase 1: ICES scrape data
  ├── Read existing data/ices_cchs_dictionary.duckdb
  ├── Migrate 5 tables into unified database
  └── Verify: 14,005 variables, 231 datasets

Phase 2: DDI XML enrichment
  ├── Parse 14 DDI XML files (2001–2018 PUMF)
  ├── Extract: variable_name, question_text, universe_logic, categories
  ├── Match to existing variables by name
  └── Load into ddi_variables table

Phase 3: StatCan data (future, with Joel)
  ├── Ingest variable/category data from flat files
  ├── Load into statcan_variables table
  └── Cross-reference with ICES and DDI data

Phase 4: cchsflow worksheets (future)
  ├── Import variable_details.csv harmonisation mappings
  └── Load into harmonisation_mappings table
```

Each phase is idempotent — the full database can be rebuilt from source data at any time.

## What this enables

### For researchers

- **Instant lookups**: "What smoking variables are in CCHS 2015?" — answered in seconds via MCP or web interface, instead of 20 minutes with PDFs.
- **Gap analysis**: "Which cycles have sleep duration data?" — query availability across all 231 datasets at once.
- **Rich context**: Where DDI data is available, the actual survey question text and universe logic ("asked of respondents aged 12+ who reported smoking in last 30 days") are returned alongside the variable metadata.

### For cchsflow developers

- **New cycle onboarding**: When CCHS 2024 data arrives, query the database to identify new, renamed, and removed variables — instead of manually comparing codebooks.
- **Harmonisation assistance**: LLM agents can query the database to understand variable changes and generate candidate recoding logic.

### For Joel's Data Dictionary Builder

- **Programmatic access**: The MCP server (or a REST wrapper) replaces the need to interact with a Shiny app manually. Any script or application can query the same metadata.
- **Combined data**: Joel's ground-truth data from actual PUMF/Master files, combined with ICES coverage data and DDI question text, creates a more complete picture than any single source.
- **Shared maintenance**: New cycles or corrections update one database, benefiting all downstream consumers.

### For LLM agents

- **Structured tool use**: Instead of dumping 14,000 rows of CSV into context, agents call targeted functions and get back exactly the data they need. This is more accurate, cheaper (fewer tokens), and auditable.
- **Harmonisation workflows**: An agent can query `get_variable_history("SMKDSTY")`, understand the naming chain across cycles, then query `get_value_codes("SMKDSTY")` to see the response categories — and use that to generate cchsflow recoding logic.

## Scope and phasing

### v1 (current plan)

1. Unified DuckDB from ICES scrape + DDI XML
2. MCP server with 9 query tools (including `suggest_cchsflow_row`)
3. Repository restructured around database + MCP
4. DDI ingestion pipeline (R, parsing 14 XML files)
5. Flat CSV export with question text for LLM consumption
6. Ontology stub tables (empty but structurally complete, ready for immediate use)

### v2 (with Joel's data)

7. Ingest Joel's flat-file metadata into the database
8. REST API wrapper for web frontend consumption
9. Cross-referencing: reconcile ICES, DDI, and StatCan variable lists
10. Coverage dashboard: which cycles and file types have metadata from which sources

### v3 (ontology and harmonisation)

11. Populate ontology tables (conceptual variables, equivalence groups, harmonisation potential)
12. Formal variable ontology — potentially OWL/SKOS or a graph database (e.g., Neo4j, DuckDB graph extensions) to model relationships: variable equivalences across cycles, derived-from chains (e.g., BMI requires HEIGHT and WEIGHT), and hierarchical subject groupings
13. Automated candidate detection when new cycles arrive
14. cchsflow worksheet generation from ontology relationships
15. Vector embeddings for semantic variable search

## Technical details

### Existing data

| Asset | Location | Size | Status |
|-------|----------|------|--------|
| ICES DuckDB | `data/ices_cchs_dictionary.duckdb` | 33 MB | Complete: 14,005 variables, 231 datasets |
| DDI XML files | `cchs-pumf-docs/CCHS-PUMF/CCHS_DDI/` | ~50 MB | 14 files, 2001–2018 PUMF |
| Variable dictionary CSV | `data/cchs_variable_dictionary.csv` | 4.9 MB | 14,005 variables with response categories |
| Ontology prototype | `development/ontology/examples/` | — | Smoking variables YAML (v0.3.0) |

### Dependencies

- **R**: DBI, duckdb, xml2, jsonlite (managed via renv)
- **Python**: fastmcp, duckdb
- **DuckDB**: v0.9.0+ (embedded, no server)

### DuckDB schema (detailed)

```sql
-- Datasets: 231 entries from ICES scrape
-- Cycle and file_type are parsed from dataset_id to support
-- compare_master_pumf() and cycle-based filtering (Gemini rec. A)
CREATE TABLE datasets (
    dataset_id VARCHAR PRIMARY KEY,   -- e.g. 'CCHS201516_ONT_SHARE'
    cycle VARCHAR,                    -- e.g. '2015-2016' (parsed from ID)
    file_type VARCHAR,                -- 'PUMF', 'Share', 'Linked', 'Bootstrap', 'Other'
    variable_count INTEGER
);

-- Variables: 14,005 unique variable names
CREATE TABLE variables (
    variable_name VARCHAR PRIMARY KEY,
    label VARCHAR,
    type VARCHAR,
    format VARCHAR,
    dataset_count INTEGER
);

-- Availability: which variables appear in which datasets
CREATE TABLE variable_availability (
    variable_name VARCHAR,
    dataset_id VARCHAR,
    PRIMARY KEY (variable_name, dataset_id)
);

-- Response categories (normalised storage)
CREATE TABLE value_formats (
    format_name VARCHAR,
    code VARCHAR,
    label VARCHAR
);

-- DDI enrichment: question text, universe logic, categories
CREATE TABLE ddi_variables (
    variable_name VARCHAR,
    dataset_id VARCHAR,
    label_en VARCHAR,
    question_text VARCHAR,
    universe_logic VARCHAR,
    notes VARCHAR,
    categories_json JSON,             -- denormalised for LLM consumption
    source_filename VARCHAR,
    PRIMARY KEY (variable_name, dataset_id)
);

-- Ontology stubs: empty in v1, ready for immediate use when
-- equivalences are discovered during v1 usage (Gemini rec. B)
CREATE TABLE variable_concepts (
    variable_name VARCHAR,
    concept_id VARCHAR,
    match_confidence FLOAT DEFAULT 1.0,
    match_source VARCHAR,             -- 'manual', 'automated', 'cchsflow'
    PRIMARY KEY (variable_name, concept_id)
);

CREATE TABLE ontology_concepts (
    concept_id VARCHAR PRIMARY KEY,
    preferred_label VARCHAR,
    description VARCHAR
);

-- v_variable_detail: the primary view for MCP tools
-- Aggregates categories into JSON so LLM agents get full context
-- in a single round-trip (Gemini rec. on normalised vs document)
CREATE VIEW v_variable_detail AS
SELECT
    v.variable_name, v.label, v.type,
    d.question_text, d.universe_logic, d.categories_json,
    ds.cycle, ds.file_type,
    va.dataset_id
FROM variables v
JOIN variable_availability va ON v.variable_name = va.variable_name
JOIN datasets ds ON va.dataset_id = ds.dataset_id
LEFT JOIN ddi_variables d
    ON v.variable_name = d.variable_name
    AND va.dataset_id = d.dataset_id;
```

**Design notes on the schema**:

- **Normalised storage, denormalised views.** The underlying tables are normalised for data integrity (e.g., `value_formats` stores each code/label pair once). But the `v_variable_detail` view and the `ddi_variables.categories_json` column present data as JSON blobs so that MCP tools return complete context in a single call. LLMs prefer context windows over joins.

- **Explicit cycle and file_type columns on `datasets`.** The existing dataset IDs (e.g., `CCHS201516_ONT_SHARE`) encode this information implicitly. Parsing it into explicit columns enables `WHERE cycle = '2015-2016' AND file_type = 'Share'` — which is what `compare_master_pumf()` needs.

- **Ontology stubs in v1.** The `ontology_concepts` and `variable_concepts` tables ship empty but structurally complete. As soon as v1 launches and users spot synonyms ("SMK_01 is definitely SMK_202"), these can be captured immediately without a schema migration. In v3, these tables may evolve into a formal ontology (OWL/SKOS) or a graph structure to model richer relationships — variable equivalences, derived-from chains (BMI → HEIGHT + WEIGHT), and hierarchical subject groupings. The relational stubs serve as the seed data for whichever direction that takes.

## Open questions

1. **Joel's data format**: What structure are the flat files in? CSV, JSON, something else? What columns/fields are available? Understanding this determines how we design the `statcan_variables` table.

2. **Coverage overlap**: How much do the ICES, DDI, and StatCan sources overlap vs complement? A reconciliation analysis would be valuable early on.

3. **Hosting the MCP server**: For LLM agents (Claude Code, etc.), the MCP server runs locally. For a web frontend, it would need to be hosted. What's the deployment target?

4. **Authentication and access**: The CCHS metadata itself is not restricted (it describes variable definitions, not individual responses). But do we want access controls on the API?

5. **Update frequency**: How often does new CCHS data arrive, and what's the process for updating the database? Annual? Ad hoc?

## Next steps

1. Build v1 (unified DuckDB + DDI ingestion + MCP server) — this can proceed immediately with existing data
2. Share this document with Joel and other reviewers for feedback
3. Explore Joel's flat-file data format and plan the ingestion
4. Discuss REST API requirements if a web frontend is in scope
5. Test the MCP server with Claude Code and other LLM agents against real harmonisation tasks
