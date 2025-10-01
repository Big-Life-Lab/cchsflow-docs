# CCHS Documentation Project - AI Context

## Project Overview
This repository manages Canadian Community Health Survey (CCHS) documentation as a comprehensive metadata catalog and distribution system. We've created a complete OSF.io mirror, metadata catalog with 1,262 files (2001-2023), and curated collections distributed via GitHub releases.

## What We Built

### 1. **Metadata Catalog System**
- **Production catalog**: 1,262 CCHS files from 2001-2023
- **LinkML schema validation**: Ensures data consistency and type safety
- **UID system v2**: Unique identifiers with file extension and temporal awareness
- **Enhanced categorization**: 34 document types with secondary categories and semantic tags

### 2. **OSF.io Integration & Mirror**
- **Complete OSF.io mirror**: `cchs-osf-docs/` - read-only mirror preserving original filenames
- **Custom OSF API client**: Production client replacing broken `osfr` package
- **Sync system**: Comprehensive synchronization with change detection
- **Git-based versioning**: Automated tracking of OSF.io metadata changes

### 3. **Collections Distribution System**
- **Curated collections**: Generate themed file sets with canonical filenames
- **Manifest system**: CSV metadata files tracked in Git (`data/manifests/`)
- **GitHub releases**: Collections distributed as ZIP files via releases (not in Git)
- **Core Master Collection v1.1.0**: 129 English master files (questionnaires, data dicts, user guides, derived vars)

### 4. **Automated Workflows**
- **OSF synchronization**: Detect and download new OSF.io files
- **Collection generation**: Extract and package themed collections
- **Reporting**: Quarto documents for download status and sync workflows

## System Architecture

### Data Flow
```
OSF.io (source)
  ↓ sync
cchs-osf-docs/ (mirror, original filenames, Git-tracked)
  ↓ catalog
data/catalog/cchs_catalog.yaml (1,262 files, Git-tracked)
  ↓ extract
Collections (canonical filenames, ZIP files)
  ↓ manifest
data/manifests/*.csv (Git-tracked)
  ↓ distribute
GitHub Releases (ZIP downloads)
```

### Repository Structure
- **Source**: `cchs-osf-docs/` - OSF.io mirror (original filenames)
- **Catalog**: `data/catalog/` - Full metadata catalog (1,262 files)
- **Manifests**: `data/manifests/` - Collection metadata (Git-tracked)
- **Build**: `build/` - Temporary collection ZIPs (gitignored)
- **Releases**: GitHub releases - Distribution platform

## Key Technical Details

### CCHS Survey Structure
- **Early Cycles (2001, 2003, 2005)**: Biannual surveys with naming `1.1`, `2.1`, `3.1`
- **Annual Surveys (2007-2023)**: Standard `12-Month` or `24-Month` structure
- **Folder Pattern**: `YEAR/[CYCLE|12-Month]/[Master|Share]/[Docs|Layout]`

### File Types
- **Master Files**: Full survey documentation distributed to RDCs (Research Data Centres)
- **Share Files**: Public-use subset with additional privacy protection
- **Document Types**: Questionnaires, data dictionaries, user guides, derived variables, syntax files
- **Languages**: English and French
- **Formats**: PDF, DOC, DOCX, SAS, SPSS, Stata, TXT, CSV, Excel, Access

### UID System (v2)
Format: `cchs-{year}{temporal}-{doc_type}-{category}-{language}-{extension}-{sequence:02d}`

Examples:
- `cchs-2009d-m-qu-e-pdf-01` - 2009 dual-year, master questionnaire, English PDF
- `cchs-2015s-s-dd-f-docx-02` - 2015 single-year, share data dictionary, French Word doc

Components:
- **Year + Temporal**: `2009d` (dual), `2015s` (single), `2013m` (multi)
- **Doc Type**: `m` (master), `s` (share)
- **Category**: `qu` (questionnaire), `dd` (data-dictionary), `ug` (user-guide), etc.
- **Language**: `e` (English), `f` (French)
- **Extension**: `pdf`, `doc`, `docx`, `sas`, `sps`, etc.
- **Sequence**: `01`, `02`, `03` (for multiple versions)

## Core Components

### Metadata & Catalog
- `data/catalog/cchs_catalog.yaml` - Production catalog (1,262 files)
- `metadata/cchs_schema_linkml.yaml` - LinkML schema definition
- `R/clean_catalog_structure.R` - Catalog generation with smart UID assignment
- `R/validate_catalog.R` - Comprehensive validation system

### Collections & Distribution
- `data/manifests/` - Collection manifests (Git-tracked)
- `R/extract_collection.R` - Generate collections from OSF mirror
- `build/` - Temporary build artifacts (gitignored)
- GitHub Releases - Distribution platform for ZIP files

### OSF Infrastructure
- `cchs-osf-docs/` - Read-only OSF.io mirror (original filenames)
- `R/osf_api_client.R` - Production OSF API client (fixes pagination issues)
- `R/osf_sync_system.R` - Synchronization and change detection
- `R/osf_versioning_system.R` - Git-based change tracking

### Reporting & Workflows
- `cchs_osf_download_report.qmd` - Download status reporting
- `sync_workflow.qmd` - Executable workflow documentation
- `cchs_catalog.qmd` - Catalog browser and analysis

## OSF Project Details
- **Project ID**: `6p3n9` (CCHS Docs)
- **Documentation Component**: `jm8bx`
- **URL**: https://osf.io/6p3n9/ (main), https://osf.io/jm8bx/files/osfstorage (documentation)
- **Access**: Private project, requires OSF Personal Access Token

### Authentication Setup
- OSF Personal Access Token stored in `.env` file
- Configuration managed via `config` package with `config.yml`
- Token needs full read/write permissions for private project

## Current Collections

### Core Master Collection (v1.1.0)
- **Files**: 129 files
- **Scope**: Master files only, English only
- **Years**: 2001-2023 (complete coverage)
- **Categories**: Questionnaires, data dictionaries, user guides, derived variables
- **Exclusions**: Redundant syntax files (variable-labels-english category)
- **Distribution**: GitHub release as ZIP file

### Future Collections
- Core Share Collection - Share files (English only)
- Core Master FR Collection - Master files (French only)
- Complete Master Collection - All master files (English + French)
- Complete Collection - Everything (Master + Share, English + French)
- Syntax Collection - SAS/SPSS/Stata syntax files only

## Key Workflows

### Create a Collection
```r
source("R/extract_collection.R")

core_master <- extract_collection(
  collection_name = "cchs-core-master-collection",
  version = "v1.1.0",
  doc_type = "master",
  language = "EN",
  exclude_syntax = TRUE
)
# Creates: build/*.zip and data/manifests/*.csv
```

### Sync with OSF.io
```r
source("R/osf_sync_system.R")
sync_results <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  dry_run = FALSE
)
```

### Use a Collection
```r
library(readr)
manifest <- read_csv("data/manifests/cchs-core-master-collection-manifest-v1.1.0.csv")

# Find files by category
questionnaires <- manifest %>% filter(category == "questionnaire")
data_dicts <- manifest %>% filter(category == "data-dictionary")
```

## Production Status

✅ **Production Ready**: 1,262 files cataloged with 100% unique UIDs
✅ **Validated**: Comprehensive schema and pattern validation
✅ **Documented**: Complete system documentation and examples
✅ **Maintained**: Active OSF synchronization and change tracking
✅ **Distributed**: Collections available via GitHub releases

## Technical Context for AI

### Technology Stack
- **R**: Primary language for data processing and cataloging
- **YAML**: Catalog storage format (1,262 files)
- **CSV**: Manifest format (collection metadata)
- **LinkML**: Schema validation framework
- **Quarto**: Reporting and documentation
- **Git**: Version control and change tracking
- **GitHub**: Repository hosting and release distribution

### Key Packages
- `httr`, `jsonlite` - OSF API client
- `yaml` - Catalog reading/writing
- `dplyr`, `readr` - Data manipulation
- `config` - Configuration management
- `git2r` - Git-based versioning
- `gt`, `quarto` - Reporting

### Design Principles
- **Reproducibility**: All collections regenerable from OSF mirror
- **Separation of concerns**: Source (OSF mirror) vs artifacts (collections)
- **Version control**: Metadata in Git, large files in releases
- **Canonical naming**: Jenny Bryan conventions for shareable filenames
- **Automation**: Scripted workflows for sync, catalog, and distribution

---

**Current Version**: v1.1.0
**Last Updated**: 2025-10-01
