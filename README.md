# Canadian Community Health Survey documentation and metadata

A unified metadata database and documentation system for the Canadian Community Health Survey (CCHS). Merges variable metadata from 6 data sources into a queryable DuckDB database exposed through an MCP server with 9 query tools.

## Finding what you need

| If you need... | Go to... | Coverage |
|----------------|----------|----------|
| **Query variable metadata** | [MCP server](docs/mcp-guide.md) | 16,899 variables across 251 datasets |
| **Complete CCHS files** | [`cchs-osf-docs/`](cchs-osf-docs/) | 2001-2023 (1,262 files) |
| **Curated download** | [GitHub Releases](../../releases) | Core Master Collection ZIP |
| **File catalog** | [`data/catalog/`](data/catalog/) | YAML catalog with file metadata |

---

## Quick start

### Build the metadata database

```bash
# Setup R packages (first time)
Rscript --vanilla -e "renv::restore()"

# Build the unified database (~2 min)
Rscript --vanilla database/build_db.R

# Install MCP server dependencies
pip install -r mcp-server/requirements.txt
```

The MCP server is configured in `.mcp.json` and discovered automatically by Claude Code and other MCP-compatible clients.

**R version**: 4.2+ required (development on R 4.4.3)

### CCHS variable metadata (MCP server)

The MCP server provides 9 query tools for exploring CCHS variable metadata programmatically. LLM agents (Claude, ChatGPT) and researchers can search variables, trace them across cycles, compare PUMF vs Master releases, and generate cchsflow harmonisation rows.

- **[Tutorial and how-to guide](docs/mcp-guide.md)** — Walkthrough and task-oriented recipes
- **[Tool reference](docs/mcp-reference.md)** — Complete specification for all 9 tools

Database: 16,899 variables, 251 datasets, 6 data sources, cycles 2001-2022.

---

### Download a collection

Download curated collections from [GitHub Releases](../../releases):

**Core Master Collection (v1.1.0)** - Essential English master documentation
- 129 files: Questionnaires, data dictionaries, user guides, derived variables
- English only, Master files only
- Years 2001-2023 (complete coverage)
- Canonical filenames for easy sharing
- **Also available in**: [NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) for AI-assisted exploration

---

## Purpose

Statistics Canada health survey documentation is scattered across multiple sources with inconsistent naming, incomplete coverage, and formats that aren't machine-readable. This repository consolidates that documentation and metadata into a unified, queryable system.

**What this repo does:**

1. **Unified metadata database** — Merges variable definitions from DDI XML, PUMF RData files, Master SAS labels, ICES Data Dictionary, cchsflow worksheets, and extracted YAML into a single DuckDB database
2. **MCP query interface** — 9 tools for searching variables, tracing them across cycles, comparing file types, and generating harmonisation rows
3. **Documentation catalog** — 1,262 CCHS files with UIDs, provenance tracking, and curated collections via GitHub Releases
4. **Stable identifiers** — The UID system gives every file a predictable, canonical name regardless of original source
5. **Full provenance** — Every record traces to a specific data source with authority level

## Related resources

| Resource | Description |
|----------|-------------|
| [CCHS NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) | AI assistant for exploring CCHS documentation |
| [cchsflow](https://github.com/Big-Life-Lab/cchsflow) | R package for harmonising CCHS variables across cycles |
| [cchsflow-data](https://github.com/Big-Life-Lab/cchsflow-data) | CCHS PUMF data files and DDI metadata from ODESSI |
| [613apps.ca](https://613apps.ca) | Population health applications using CCHS data |

## Repository structure

```
cchsflow-docs/
├── database/
│   ├── cchs_metadata.duckdb       # Unified database (gitignored build artefact)
│   ├── schema.sql                 # DuckDB schema (13 tables, 6 views)
│   └── build_db.R                 # Build script (Phase 0 → 1 → 2)
├── ingestion/
│   ├── ingest_pumf_rdata.R        # Phase 1: PUMF RData → variable_datasets, value_codes
│   └── ingest_ddi_xml.R           # Phase 2: DDI XML → question text, stats, groups
├── mcp-server/
│   ├── server.py                  # FastMCP v2 server (9 tools)
│   └── requirements.txt
├── data/
│   ├── sources.csv                # Data source registry (6 sources)
│   ├── datasets.csv               # Dataset definitions (251 datasets)
│   ├── variables.csv              # Variable registry (16,899 variables)
│   ├── catalog/
│   │   └── cchs_catalog.yaml      # Document-level metadata (1,262 entries)
│   └── manifests/                 # Collection manifests for GitHub Releases
├── development/
│   ├── architecture/              # Design rationale and proposals
│   └── ontology/                  # Variable relationship modelling (in progress)
├── docs/
│   ├── mcp-guide.md               # MCP tool tutorials and workflow examples
│   ├── mcp-reference.md           # MCP tool specifications (all 9 tools)
│   ├── architecture.md            # System architecture and data flow
│   ├── uid-system.md              # UID specification
│   └── glossary.md                # CCHS terminology
└── cchs-osf-docs/                 # CCHS documentation mirror (gitignored)
```

## CCHS terminology

**Master vs Share files**
- **Master files**: Full survey documentation for Research Data Centres (RDCs). Complete questionnaires, full data dictionaries, unrestricted variables.
- **Share files**: Public-use subsets with privacy protection. Subset of variables, some aggregated or suppressed.

**Temporal types**
- **Single-year (s)**: Standard annual surveys (most common after 2007)
- **Dual-year (d)**: Two-year combined data collections (2007-2008, 2009-2010, etc.)
- **Multi-year (m)**: Multi-year pooled surveys (less common)

**Document categories**
- **Questionnaires (qu)**: Survey instruments with all questions asked
- **Data dictionaries (dd)**: Variable definitions, codes, and frequencies
- **User guides (ug)**: Methodology, sampling, weighting instructions
- **Derived variables (dv)**: Documentation of calculated/constructed variables
- **Record layouts (rl)**: File structure and variable positions
- **Syntax files**: SAS/SPSS/Stata code for data processing

## UID system

The CCHS UID system provides unique identifiers for documentation files:

```
cchs-{year}{temporal}-{doc_type}-{category}-[{subcategory}-]{language}-{extension}-{sequence:02d}
```

Examples:
```bash
cchs-2009d-m-questionnaire-e-pdf-01     # 2009 dual-year, master questionnaire, English PDF
cchs-2015s-s-data-dictionary-f-docx-01  # 2015 single-year, share data dictionary, French Word
```

See [docs/uid-system.md](docs/uid-system.md) for the full specification.

---

## Statistics Canada attribution

The Canadian Community Health Survey (CCHS) is conducted by Statistics Canada. Survey data and documentation are accessed and adapted in accordance with the [Statistics Canada Open Licence](https://www.statcan.gc.ca/eng/reference/licence).

**Source**: Statistics Canada, Canadian Community Health Survey (CCHS). Reproduced and distributed on an "as is" basis with the permission of Statistics Canada.

**Adapted from**: Statistics Canada survey documentation. This does not constitute an endorsement by Statistics Canada of this product.

For information about accessing CCHS data, visit:
- [CCHS Survey Information](https://www23.statcan.gc.ca/imdb/p2SV.pl?Function=getSurvey&SDDS=3226)
- [Research Data Centres](https://www.statcan.gc.ca/en/microdata/data-centres)
