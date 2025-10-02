# CCHS Documentation Catalog System

A production metadata catalog system for Canadian Community Health Survey (CCHS) documentation with enhanced UID generation, LinkML schema validation, and OSF.io synchronization capabilities.

## 🎯 Overview

This repository provides:
- **Comprehensive metadata catalog** for 1,262 CCHS files (2001-2023)
- **Unique identifier system** with file extension awareness
- **LinkML schema validation** for data consistency
- **OSF.io synchronization** infrastructure (read-only mirror)
- **Curated collections** with canonical filenames distributed via GitHub releases
- **Automated reporting** and workflow management

## 📋 Quick Start

### Download a Collection

Download curated collections from [GitHub Releases](../../releases):

**Core Master Collection (v1.1.0)** - Essential English master documentation
- 129 files: Questionnaires, data dictionaries, user guides, derived variables
- English only, Master files only
- Years 2001-2023 (complete coverage)
- Canonical filenames for easy sharing

```r
# After downloading and extracting, load the manifest
library(readr)
manifest <- read_csv("cchs-core-master-collection-v1.1.0/manifest.csv")

# Find files by category
questionnaires <- manifest %>% filter(category == "questionnaire")
```

### View the Full Catalog

```r
# Load and explore the complete production catalog (1,262 files)
library(yaml)
catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")

# View catalog metadata
catalog$catalog_metadata

# Search files by year
files_2009 <- catalog$files[sapply(catalog$files, function(x) x$year == "2009")]

# Find files by category
questionnaires <- catalog$files[sapply(catalog$files, function(x) x$category == "questionnaire")]
```

### Validate Catalog
```r
# Run comprehensive validation
source("R/validate_catalog.R")
validation_results <- validate_cchs_catalog("data/catalog/cchs_catalog.yaml")
```

## 🏗️ System Architecture

### Core Components

#### 📊 **Metadata Catalog System**
- **`data/catalog/cchs_catalog.yaml`** - Production catalog (1,262 files)
- **`metadata/cchs_schema_linkml.yaml`** - LinkML schema definition
- **`R/clean_catalog_structure.R`** - Catalog generation with smart UID assignment
- **`R/validate_catalog.R`** - Comprehensive validation system

#### 📦 **Collections & Distribution**
- **`data/manifests/`** - Collection manifests (tracked in Git)
- **`R/extract_collection.R`** - Collection generation from OSF mirror
- **`build/`** - Temporary build artifacts (gitignored)
- **GitHub Releases** - Distribution platform for collection ZIP files

#### 🔗 **OSF.io Infrastructure**
- **`cchs-osf-docs/`** - Read-only mirror of OSF.io (original filenames)
- **`R/osf_api_client.R`** - Production OSF API client (replaces broken `osfr`)
- **`R/osf_sync_system.R`** - Comprehensive synchronization system
- **`R/osf_versioning_system.R`** - Git-based change tracking and automation

#### 📈 **Reporting & Workflows**
- **`reports/`** - Quarto-based analysis and reporting
  - [Catalog Browser](reports/catalog-browser.qmd) - Interactive catalog exploration
  - [Download Status](reports/download-status.qmd) - OSF sync status and verification
  - [Sync Workflow](reports/sync-workflow.qmd) - Executable workflow documentation

#### 📚 **Documentation**
- **`docs/`** - Technical documentation directory
  - [UID System](docs/uid-system.md) - UID reference and examples
  - [Architecture](docs/architecture.md) - System design and data flow
  - [Collections Guide](docs/collections-guide.md) - Creating and using collections
  - [OSF Sync Guide](docs/osf-sync-guide.md) - Synchronization workflows
  - [Glossary](docs/glossary.md) - CCHS terminology
- **`data/manifests/README.md`** - Collection manifests documentation

## 📖 CCHS Terminology

Understanding key CCHS concepts:

**Master vs Share Files**
- **Master Files**: Full survey documentation distributed to Research Data Centres (RDCs). Contains complete questionnaires, full data dictionaries, and unrestricted variables. Used by researchers with secure data access.
- **Share Files**: Public-use subset files with enhanced privacy protection. Contains subset of variables, some aggregated or suppressed. Available for public access with fewer restrictions.
- **When to use**: Download Master collections for comprehensive research at RDCs. Use Share collections for public analyses or preliminary exploration.

**Temporal Types**
- **Single-year (s)**: Standard annual surveys (most common after 2007)
- **Dual-year (d)**: Two-year combined data collections (2007-2008, 2009-2010, etc.)
- **Multi-year (m)**: Multi-year pooled surveys (less common)

**Document Categories**
- **Questionnaires (qu)**: Survey instruments with all questions asked
- **Data Dictionaries (dd)**: Variable definitions, codes, and frequencies
- **User Guides (ug)**: Methodology, sampling, weighting instructions
- **Derived Variables (dv)**: Documentation of calculated/constructed variables
- **Record Layouts (rl)**: File structure and variable positions
- **Syntax Files (various)**: SAS/SPSS/Stata code for data processing

## 🆔 UID System

Our enhanced UID system provides unique identifiers with temporal and format awareness:

### Format
```
cchs-{year}{temporal}-{doc_type}-{category}-{language}-{extension}-{sequence:02d}
```

### Examples
```bash
cchs-2009d-m-qu-e-pdf-01    # 2009 dual-year, master questionnaire, English PDF
cchs-2015s-s-dd-f-docx-02   # 2015 single-year, share data dictionary, French Word doc
cchs-2007d-m-ss-e-sas-01    # 2007 dual-year, master SAS syntax, English
```

### Components
- **Year + Temporal**: `2009d` (dual-year), `2015s` (single-year), `2013m` (multi-year)
- **Document Type**: `m` (master), `s` (share)
- **Category Codes**: `qu` (questionnaire), `dd` (data-dictionary), `ug` (user-guide), etc.
- **Language**: `e` (English), `f` (French)
- **Extension**: `pdf`, `doc`, `docx`, `sas`, `sps`, etc.
- **Sequence**: `01`, `02`, `03` (for multiple versions)

## 💻 Usage Examples

### Create a Collection
```r
# Generate a new collection from OSF mirror
source("R/extract_collection.R")

# Core master collection (English master files only)
core_master <- extract_collection(
  collection_name = "cchs-core-master-collection",
  version = "v1.1.0",
  doc_type = "master",
  language = "EN",
  exclude_syntax = TRUE
)

# This creates:
# - build/cchs-core-master-collection-v1.1.0.zip
# - data/manifests/cchs-core-master-collection-manifest-v1.1.0.csv
```

### OSF Synchronization
```r
# Set up OSF credentials in .env file:
# OSF_PAT=your_personal_access_token
# OSF_PROJECT_ID=your_project_id

# Sync with OSF.io
source("R/osf_sync_system.R")
sync_results <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  dry_run = FALSE
)
```

### Generate Reports
```r
# Create download status report
library(quarto)
quarto::quarto_render("cchs_osf_download_report.qmd")

# Run workflow pipeline
quarto::quarto_render("sync_workflow.qmd")
```

### Search and Filter Files
```r
library(yaml)
catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")

# Find all 2009 questionnaires
questionnaires_2009 <- catalog$files[sapply(catalog$files, function(x) {
  x$year == "2009" && x$category == "questionnaire"
})]

# Get all French documents
french_docs <- catalog$files[sapply(catalog$files, function(x) {
  x$language == "FR"
})]

# Find master files only
master_files <- catalog$files[sapply(catalog$files, function(x) {
  x$doc_type == "master"
})]
```

## 🔧 Setup & Configuration

### 1. R Dependencies
```r
install.packages(c(
  "yaml", "dplyr", "httr", "jsonlite", 
  "config", "git2r", "quarto"
))
```

### 2. OSF.io Credentials (Optional)
Create `.env` file:
```bash
OSF_PAT=your_personal_access_token
OSF_PROJECT_ID=your_project_id
```

### 3. Configuration
The system uses `config.yml` for environment-specific settings:
```yaml
default:
  osf:
    documentation_component_id: "your_component_id"
    base_url: "https://api.osf.io/v2"
```

## 📁 Repository Structure

```
├── R/                              # Core R scripts
│   ├── clean_catalog_structure.R      # Catalog generation
│   ├── validate_catalog.R             # Validation system
│   ├── extract_collection.R           # Collection generation
│   ├── osf_api_client.R               # OSF API client
│   ├── osf_sync_system.R              # Sync infrastructure
│   └── osf_versioning_system.R        # Change tracking
├── data/
│   ├── catalog/
│   │   └── cchs_catalog.yaml          # Production catalog (1,262 files)
│   └── manifests/                     # Collection manifests (Git-tracked)
│       ├── README.md                  # Manifests documentation
│       └── cchs-core-master-collection-manifest-v1.1.0.csv
├── metadata/
│   ├── cchs_schema_linkml.yaml        # LinkML schema
│   └── legacy/                        # Historical artifacts
├── cchs-osf-docs/                     # OSF.io mirror (original filenames)
├── build/                             # Temporary artifacts (gitignored)
│   └── *.zip                          # Collection builds
├── docs/                              # Technical documentation
│   ├── architecture.md                # System design
│   ├── collections-guide.md           # Collections usage
│   ├── osf-sync-guide.md             # OSF synchronization
│   ├── uid-system.md                 # UID specification
│   └── glossary.md                   # CCHS terminology
└── reports/                           # Quarto reports
    ├── catalog-browser.qmd            # Catalog exploration
    ├── download-status.qmd            # Sync status
    └── sync-workflow.qmd              # Workflow pipeline
```

## 🔬 Technical Details

### LinkML Schema
The catalog uses LinkML for structured validation:
- **Type safety**: Integer sequences, proper data types
- **Pattern validation**: UID format enforcement  
- **Enumerated values**: Controlled vocabularies for categories
- **Relationship integrity**: File metadata consistency

### UID Generation Algorithm
1. **Category Detection**: Intelligent filename-based categorization
2. **Smart Sequencing**: Prevents duplicate UIDs through base pattern tracking
3. **Extension Awareness**: Differentiates formats (PDF vs DOC of same document)
4. **Language Detection**: Automatic English/French identification
5. **Temporal Classification**: Single/dual/multi-year survey handling

### OSF Integration
- **Pagination Handling**: Correct retrieval of all files (fixes `osfr` limitations)
- **Error Recovery**: Robust HTTP error handling and retries
- **Change Detection**: Git-based tracking of metadata modifications
- **Automated Workflows**: Scheduled sync and reporting

## 🚀 Production Status

✅ **Production Ready**: 1,262 files cataloged with 100% unique UIDs  
✅ **Validated**: Comprehensive schema and pattern validation  
✅ **Documented**: Complete system documentation and examples  
✅ **Maintained**: Active OSF synchronization and change tracking  

## 📊 Catalog Statistics

- **Total Files**: 1,262 documented files
- **Years Covered**: 2001-2023 (23 survey years)
- **Languages**: English and French documents
- **File Types**: PDF, DOC, DOCX, SAS, SPSS, Stata, TXT, CSV, Excel, Access
- **Categories**: 34 document categories from questionnaires to syntax files
- **UID Uniqueness**: 100% unique identifiers across all files

---

🤖 *Enhanced metadata catalog system for comprehensive CCHS documentation management*