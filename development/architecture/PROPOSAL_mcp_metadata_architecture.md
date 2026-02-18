# CCHS metadata architecture: a unified database and API for survey harmonisation

**Draft for review** — February 2026 (updated)

*Reviewed by Google Gemini Deep Research (Feb 2026). Recommendations incorporated below.*

## The problem

Three independent efforts have produced valuable CCHS metadata, but none of them talk to each other:

1. **Joel Barnes' Data Dictionary Builder** ([613apps.ca/data-dictionary-builder](https://613apps.ca/data-dictionary-builder/)). A Shiny app that groups 10+ years of national survey metadata from flat files in a filterable, searchable format. It draws on actual PUMF and Master files at Statistics Canada to list every variable and its response categories. The underlying data is rich but locked inside the app — there is no programmatic API.

2. **cchsflow R package** ([github.com/Big-Life-Lab/cchsflow](https://github.com/Big-Life-Lab/cchsflow)). Provides variable harmonisation across CCHS cycles (2001–2018) via CSV worksheets and R recoding functions. It knows *how* to transform variables but lacks a queryable metadata layer for discovery.

3. **cchsflow-docs repository**. Houses CCHS documentation (PDFs, DDI XML files, data dictionaries) and metadata from multiple sources. The data is structured but previously had no query interface beyond raw SQL.

Each effort solves part of the puzzle. None solves all of it. The result is that researchers and developers constantly repeat the same manual lookups: "Is variable X available in cycle Y?", "What response categories does it have?", "Did the variable name change?"

## Pilot status

We have built a working pilot of the unified database and MCP server. The core infrastructure is operational and being used for cchsflow harmonisation work. This section summarises what exists today; the rest of the document describes the full vision.

### What's built

- **Unified DuckDB database** with 16,899 variables across 251 datasets, built from 6 data sources
- **MCP server** with 9 query tools, operational in Claude Code
- **Three-phase build pipeline**: CSV loading → PUMF RData ingestion → DDI XML extraction
- **Full provenance tracking**: every record traces to a specific data source with authority level

### Current data sources (6)

| Source | Authority | Content | Status |
|--------|-----------|---------|--------|
| DDI XML (11 files) | Primary | Question text, value codes, frequencies, summary stats | Complete for PUMF 2001–2018 |
| PUMF RData (11 files) | Primary | Variable types, value labels from data files | Complete for PUMF 2001–2022 |
| Master SAS labels (35 files) | Primary | Variable labels from Master files | Complete for available cycles |
| cchsflow worksheets | Secondary | Harmonisation mappings | Loaded |
| ICES Data Dictionary | Secondary | Variable labels across 231 ICES datasets | Loaded |
| Extracted YAML | Secondary | Data dictionaries from PDF extraction | Loaded |

### Known gaps

- **Missing cycles**: PUMF DDI coverage ends at 2018. Cycles 2019–2022 have RData but no DDI question text. The 2022 single-year file has only 255 variables in our database.
- **Master file metadata**: We have SAS labels (variable names and descriptions) but not full Master data dictionaries with response categories and frequencies. Joel's ground-truth documents from actual Master files would fill this gap.
- **Variable families**: Cross-cycle equivalence mappings (e.g., SMKA_202 in 2001 = SMK_202 in 2007 = SMK_005 in 2015) are not yet populated. The schema supports this but the data requires expert review.
- **No REST API**: The MCP server works for LLM agents and local scripts. A web-accessible API (for 613apps.ca or other frontends) would require a thin REST wrapper.

## What we want to build

A single, unified DuckDB database exposed through an MCP (Model Context Protocol) server that any LLM agent, R developer, or web application can query. The database merges metadata from multiple sources and the MCP server provides structured tool-use access.

This is not a replacement for Joel's Shiny app or cchsflow's worksheets. It is the shared data layer that both could draw from — and that new tools (LLM agents, APIs, web frontends) could use directly.

## Use cases

### UC1: Variable lookup

**Actor**: Researcher, LLM agent, or web application

**Query**: "Is SMKDSTY available in CCHS 2015?"

**Previous process**: Open Joel's Shiny app and search manually, or grep through PDF documentation.

**With MCP**: `search_variables("SMKDSTY")` returns structured JSON with availability across all cycles, response categories, and (where available) the original question text. *This works today in the pilot.*

### UC2: Variable history

**Actor**: cchsflow developer or harmonisation agent

**Query**: "What variable names has smoking status used from 2001 to 2024?"

**Previous process**: Manually review data dictionaries for each cycle, noting name changes (SMKA_202 → SMKC_202 → SMKE_202 → SMK_202 → SMK_005 → CSS_05).

**With MCP**: `get_variable_history("SMK_202")` returns the full chain of datasets where this variable appears, with cycle years and file types. *Works today for variables that share the same name. Cross-cycle equivalences (where the name changed) require the variable families feature — not yet populated.*

### UC3: Master vs PUMF comparison

**Actor**: Researcher choosing between file types

**Query**: "How does BMI differ between Master and PUMF in 2015–2016?"

**Previous process**: Compare two separate data dictionaries side by side.

**With MCP**: `compare_master_pumf("HWTGBMI", "2015-2016")` returns a structured diff showing differences between releases. *Works today for cycles where both PUMF and Master metadata exist in the database. Currently strongest for PUMF files; Master file coverage would improve significantly with Joel's data.*

### UC4: New cycle onboarding

**Actor**: cchsflow developer adding CCHS 2023 support

**Query**: "What variables in CCHS 2023 don't exist in our database yet?"

**Previous process**: Download the new data dictionary, manually compare against the existing variable list.

**With MCP**: `get_dataset_variables("cchs-2022s-p-can")` returns the full variable list; a diff against existing data highlights new, renamed, or removed variables. *Works today — we used this during the pilot to identify 362 variables present only in YAML extracts.*

### UC5: Response category browsing

**Actor**: Researcher designing an analysis, web application user

**Query**: "Show all response options for DHHGAGE across cycles."

**Previous process**: Look up each cycle's codebook individually.

**With MCP**: `get_value_codes("DHHGAGE")` returns the response categories with frequencies, or `get_variable_detail("DHHGAGE")` returns the full metadata including DDI question text and universe logic. *Works today for variables with DDI data.*

### UC6: Programmatic API access (Data Dictionary Builder v2)

**Actor**: External application or API client

**Query**: Same as UC1–UC5, but via HTTP.

**Previous process**: Not possible. Joel's Shiny app is interactive only.

**With MCP/REST**: The MCP server could serve as the backend for a next-generation Data Dictionary Builder — either directly (MCP protocol) or wrapped in a lightweight REST API. Any web frontend could query the same database that LLM agents use. *The MCP server works today; the REST wrapper is a future step that would need to be assessed for use cases like 613apps.ca.*

## Data sources

We have metadata from six sources. Each has strengths the others lack. The pilot has ingested all six; Joel's ground-truth data would be the seventh and most valuable addition.

| Source | What it contains | Strengths | Gaps |
|--------|-----------------|-----------|------|
| **PUMF RData files** (11 files) | Variable types and value labels from actual data files | Ground truth for PUMF variables | PUMF only, no question text |
| **DDI XML files** (11 files) | Variable definitions with question text, universe/skip logic, frequencies | Rich context: the actual survey question and who was asked | PUMF only, covers 2001–2018 |
| **Master SAS labels** (35 files) | Variable names and labels from Master file layouts | Covers Master-only variables not in PUMF | Labels only — no response categories or frequencies |
| **ICES Data Dictionary** | 14,005 variables, 231 datasets (PUMF, Master, Ontario Share, Linked) | Broadest coverage: every variable ICES has catalogued | No question text, no universe logic, limited to ICES holdings |
| **cchsflow worksheets** | Harmonisation mappings (variable_details.csv) | Knows which variables are equivalent across cycles | Focused on harmonised variables only (~300), not the full 16K |
| **Extracted YAML** | Data dictionaries parsed from PDF documentation | Covers some Master and Share files | Variable quality; PDF parsing is imperfect |
| **Data Dictionary Builder** (Joel's flat files) | Variables and categories from actual PUMF and Master files at Statistics Canada | **Ground truth**: derived from the data files themselves, with full response categories | Not yet integrated |

### How they fit together

```
                    ┌──────────────────────────────────┐
                    │    Unified DuckDB (16,899 vars)   │
                    │                                   │
  PUMF RData ──────►│  variables          (16,899)      │
  DDI XML ─────────►│  variable_datasets  (21,810)      │
  Master SAS ──────►│  value_codes        (145,910)     │
  ICES scrape ─────►│  variable_groups    (562)         │
  cchsflow ────────►│  datasets           (251)         │
  YAML extract ────►│  sources            (6)           │
                    │                                   │
  Joel's data ────►│  [future integration]              │
  (ground truth)    │                                   │
                    └─────────┬─────────────────────────┘
                              │
                              ▼
                    ┌──────────────────────────────────┐
                    │    MCP Server (9 tools)           │
                    │                                   │
                    │  search_variables()               │
                    │  get_variable_detail()            │
                    │  get_variable_history()           │
                    │  compare_master_pumf()            │
                    │  get_value_codes()                │
                    │  get_dataset_variables()          │
                    │  get_common_variables()           │
                    │  suggest_cchsflow_row()           │
                    │  get_database_summary()           │
                    └─────────┬─────────────────────────┘
                              │
                 ┌────────────┼────────────────┐
                 ▼            ▼                ▼
           LLM Agents    Web Frontend    R/Python
           (Claude,      (Data Dict     scripts
            ChatGPT)      Builder v2,
                          613apps.ca)
```

## Architecture

### The database

**Technology**: DuckDB — a fast, embedded analytical database. No server to maintain. A single `.duckdb` file that R, Python, and the MCP server all read directly.

**Schema (v2)**: 13 tables and 6 views. The schema has evolved from the original proposal based on what we learned during the pilot.

| Table | Source | Rows | Purpose |
|-------|--------|------|---------|
| `sources` | CSV | 6 | Data source registry with authority level |
| `datasets` | CSV | 251 | One row per survey file release |
| `variables` | CSV | 16,899 | One row per unique variable name |
| `variable_datasets` | Ingestion | 21,810 | Per-source metadata for each variable-dataset pair |
| `value_codes` | Ingestion | 145,910 | Response categories with frequencies |
| `variable_summary_stats` | DDI | 10,893 | Distributional statistics |
| `variable_groups` | DDI | 562 | Module classifications |
| `variable_group_members` | DDI | 9,642 | Variable-to-group membership |
| `dataset_sources` | Ingestion | 253 | Which files attest each dataset |
| `dataset_aliases` | Ingestion | 253 | External ID → canonical dataset_id mapping |
| `variable_families` | Future | 0 | Cross-cycle equivalences |
| `variable_family_members` | Future | 0 | Cycle-specific name → family mapping |
| `catalog_metadata` | Build | 3 | Schema version, build date |

The schema is designed so that each source populates its own records with provenance. Views join them together for querying. This means:

- Adding Joel's data is a matter of registering a new source in `sources.csv` and running an ingestion script — no restructuring required.
- Missing data from one source does not break queries. Provenance tracking shows which sources attest each record.
- Each source remains independently verifiable.

**Key design decisions**:

- **Variable names are the primary key.** Our analysis of DDI XML files confirmed that the `ID` attribute (e.g., V622) is a sequential position identifier that changes between cycles. The `name` attribute (e.g., SMKDSTY) is what researchers use and search for.
- **Three-tier architecture.** CSVs are the source of truth (human-editable, version-controlled). DuckDB is a build artefact. The MCP server reads DuckDB. This separation means the database can always be rebuilt from source.
- **Authority levels.** Primary sources (Statistics Canada documentation) take precedence over secondary sources (ICES scrape, cchsflow) when conflicts exist.

### The MCP server

**Technology**: Python FastMCP v2 — a lightweight framework for exposing tools via the Model Context Protocol.

**What is MCP?** The Model Context Protocol is a standard that allows LLM applications (Claude, ChatGPT, etc.) to call structured functions ("tools") rather than relying on raw text dumps. Instead of pasting a 16,000-row CSV into a prompt, the LLM calls `search_variables("smoking")` and gets back exactly the relevant rows as structured JSON.

**Implemented tools** (all 9 operational):

| Tool | Parameters | Returns |
|------|-----------|---------|
| `search_variables` | `query`, `limit` | Variables matching by name or label |
| `get_variable_detail` | `variable_name` | Full metadata: label, type, question text, categories, availability |
| `get_variable_history` | `variable_name` | All datasets where this variable appears, with cycle years |
| `get_dataset_variables` | `dataset_id`, `limit` | All variables in a specific dataset |
| `get_common_variables` | `dataset_id_1`, `dataset_id_2` | Variables shared between two datasets |
| `compare_master_pumf` | `variable_name`, `cycle` | Side-by-side comparison of different release types |
| `get_value_codes` | `variable_name` | Response categories for a variable |
| `suggest_cchsflow_row` | `variable_name`, `target_cycle` | Draft cchsflow worksheet row for a variable in a new cycle |
| `get_database_summary` | — | High-level statistics: variable count, dataset count, coverage |

Each tool returns structured JSON. The same tools could be wrapped in a REST API with minimal additional code.

### From MCP to REST API

MCP tools are functions with typed parameters and structured returns — essentially the same as REST API endpoints. A thin wrapper (FastAPI, Plumber, or similar) could expose the same functions as HTTP endpoints:

```
MCP:  search_variables(query="smoking", limit=10)
REST: GET /api/variables/search?query=smoking&limit=10
```

This means Joel's next-generation Data Dictionary Builder or other web applications (e.g., 613apps.ca) could consume the same backend that LLM agents use. One database, multiple interfaces. Whether this makes sense depends on the specific use cases — a REST API adds hosting, authentication, and maintenance requirements that need to be assessed.

## Ingestion pipeline

The database is built from source data in a reproducible pipeline (~2 minutes):

```
Phase 0: CSV loading
  ├── Load data/sources.csv (6 sources)
  ├── Load data/datasets.csv (251 datasets)
  └── Load data/variables.csv (16,899 variables)

Phase 1: PUMF RData ingestion
  ├── Parse 11 RData files (2001–2022 PUMF)
  ├── Extract: variable types, value labels (haven_labelled)
  ├── Populate variable_datasets (10,905 links)
  └── Populate value_codes (72,955 codes from RData)

Phase 2: DDI XML enrichment
  ├── Parse 11 DDI XML files (2001–2018 PUMF)
  ├── Extract: question text, universe, frequencies, summary stats, module groups
  ├── Enrich variable_datasets with DDI metadata
  ├── Add DDI value codes with weighted frequencies (72,955 codes)
  └── Populate variable_groups (562) and variable_summary_stats (10,893)

Phase 3: Joel's data (future)
  ├── Ingest variable/category data from flat files
  ├── Register as new source with 'primary' authority
  └── Cross-reference with existing PUMF and DDI data

Phase 4: Variable families (future)
  ├── Populate cross-cycle equivalences from expert review
  └── Enable true variable history across name changes
```

Each phase is idempotent — the full database can be rebuilt from source data at any time with `Rscript --vanilla database/build_db.R`.

## What this enables

### For researchers

- **Instant lookups**: "What smoking variables are in CCHS 2015?" — answered in seconds via MCP or web interface, instead of 20 minutes with PDFs.
- **Gap analysis**: "Which cycles have sleep duration data?" — query availability across all 251 datasets at once.
- **Rich context**: Where DDI data is available, the actual survey question text and universe logic ("asked of respondents aged 12+ who reported smoking in last 30 days") are returned alongside the variable metadata.

### For cchsflow developers

- **New cycle onboarding**: When CCHS 2024 data arrives, query the database to identify new, renamed, and removed variables — instead of manually comparing codebooks.
- **Harmonisation assistance**: LLM agents can query the database to understand variable changes and generate candidate recoding logic. The `suggest_cchsflow_row` tool drafts worksheet entries directly.

### For Joel's Data Dictionary Builder and 613apps.ca

- **Programmatic access**: The MCP server (or a REST wrapper) provides the programmatic API that the Shiny app currently lacks. Any script or application can query the same metadata.
- **Combined data**: Joel's ground-truth data from actual PUMF/Master files, combined with DDI question text and ICES coverage data, would create a more complete picture than any single source.
- **Shared maintenance**: New cycles or corrections update one database, benefiting all downstream consumers.
- **Assessment needed**: Whether the MCP/REST architecture is the right fit for 613apps.ca and other web applications depends on deployment requirements, hosting, and access patterns. This is worth discussing before building the REST layer.

### For LLM agents

- **Structured tool use**: Instead of dumping 16,000 rows of CSV into context, agents call targeted functions and get back exactly the data they need. This is more accurate, cheaper (fewer tokens), and auditable.
- **Harmonisation workflows**: An agent can query `get_variable_history("SMKDSTY")`, understand the naming chain across cycles, then query `get_value_codes("SMKDSTY")` to see the response categories — and use that to generate cchsflow recoding logic. *We are piloting this workflow now with the cchsflow package.*

## Scope and phasing

### Pilot (complete)

1. ~~Unified DuckDB from 6 data sources (16,899 variables, 251 datasets)~~ Done
2. ~~MCP server with 9 query tools~~ Done
3. ~~Repository restructured around database + MCP~~ Done
4. ~~DDI ingestion pipeline (R, parsing 11 XML files)~~ Done
5. ~~Master SAS label ingestion (35 files, 2,166 Master-only variables)~~ Done
6. ~~Full provenance tracking with source authority levels~~ Done
7. ~~Documentation (architecture, MCP guide, tool reference)~~ Done

### Next (with Joel's data)

8. Ingest Joel's ground-truth metadata into the database — this is the most valuable addition, as it provides full response categories and frequencies from actual Master files
9. Assess REST API requirements for web frontend consumption (613apps.ca, Data Dictionary Builder v2)
10. Cross-referencing: reconcile all sources to identify coverage gaps and conflicts
11. Coverage dashboard: which cycles and file types have metadata from which sources
12. Fill missing cycles: 2019–2022 DDI data, recent Master file documentation

### Future (ontology and harmonisation)

13. Populate variable family tables (cross-cycle equivalences from expert review)
14. Formal variable ontology — potentially OWL/SKOS or a graph database to model relationships: variable equivalences across cycles, derived-from chains (e.g., BMI requires HEIGHT and WEIGHT), and hierarchical subject groupings
15. Automated candidate detection when new cycles arrive
16. cchsflow worksheet generation from ontology relationships
17. Vector embeddings for semantic variable search

## Open questions

1. **Joel's data format**: What structure are the flat files in? CSV, JSON, something else? What columns/fields are available? Understanding this determines how we design the ingestion.

2. **Coverage overlap**: How much do the existing 6 sources and Joel's data overlap vs complement? A reconciliation analysis would be valuable and straightforward to run against the pilot database.

3. **613apps.ca and web use cases**: The MCP server works well for LLM agents and local scripts. For web applications like 613apps.ca, what are the specific data needs? Would a REST API serve them, or is the Shiny app pattern better suited? This assessment should happen before building infrastructure.

4. **Hosting**: For LLM agents (Claude Code, etc.), the MCP server runs locally. For a web frontend, it would need to be hosted. What's the deployment target?

5. **Authentication and access**: The CCHS metadata itself is not restricted (it describes variable definitions, not individual responses). But do we want access controls on the API?

6. **Update frequency**: How often does new CCHS data arrive, and what's the process for updating the database? Annual? Ad hoc?

## Next steps

1. ~~Build pilot (unified DuckDB + DDI ingestion + MCP server)~~ Complete
2. ~~Test the MCP server with Claude Code against real harmonisation tasks~~ In progress (cchsflow)
3. Share this updated document with Joel and other reviewers for feedback
4. Explore Joel's flat-file data format and plan the ingestion
5. Assess REST API requirements for 613apps.ca and other web applications
6. Discuss deployment options if a hosted API is in scope
