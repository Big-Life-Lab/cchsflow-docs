# CCHS Documentation Catalog System

A production metadata catalog system for Canadian Community Health Survey (CCHS) documentation with enhanced UID generation, LinkML schema validation, and OSF.io synchronization capabilities.

## 🎯 Overview

This repository provides:
- **Comprehensive metadata catalog** for 1,262 CCHS files (2001-2023)
- **Unique identifier system** with file extension awareness
- **LinkML schema validation** for data consistency
- **OSF.io synchronization** infrastructure
- **Automated reporting** and workflow management

## 📋 Quick Start

### View the Catalog
```r
# Load and explore the production catalog
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

#### 🔗 **OSF.io Infrastructure** 
- **`R/osf_api_client.R`** - Production OSF API client (replaces broken `osfr`)
- **`R/osf_sync_system.R`** - Comprehensive synchronization system
- **`R/osf_versioning_system.R`** - Git-based change tracking and automation

#### 📈 **Reporting & Workflows**
- **`cchs_osf_download_report.qmd`** - Download status and completion tracking
- **`sync_workflow.qmd`** - Executable workflow documentation and pipeline

#### 📚 **Documentation**
- **`UID_SYSTEM_V2_DOCUMENTATION.md`** - UID system reference and examples

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

### Generate New Catalog
```r
# Clean and regenerate catalog from source data
source("R/clean_catalog_structure.R")
cleaned_catalog <- clean_catalog(
  input_file = "metadata/legacy/source_catalog.yaml",
  output_file = "data/catalog/cchs_catalog_new.yaml"
)
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

# Find SAS syntax files
sas_files <- catalog$files[sapply(catalog$files, function(x) {
  x$file_extension == "sas"
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
│   ├── osf_api_client.R               # OSF API client
│   ├── osf_sync_system.R              # Sync infrastructure
│   └── osf_versioning_system.R        # Change tracking
├── data/
│   └── catalog/
│       └── cchs_catalog.yaml          # Production catalog
├── metadata/
│   ├── cchs_schema_linkml.yaml        # LinkML schema
│   └── legacy/                        # Historical artifacts
├── cchs-osf-docs/                     # Synced OSF content
├── cchs_osf_download_report.qmd       # Status reporting
├── sync_workflow.qmd                  # Workflow pipeline
└── UID_SYSTEM_V2_DOCUMENTATION.md    # System documentation
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