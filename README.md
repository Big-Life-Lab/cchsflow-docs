# Canadian Health Surveys Documentation System

A production metadata catalog system for Canadian health survey documentation including the Canadian Community Health Survey (CCHS) and Canadian Health Measures Survey (CHMS), with enhanced UID generation, LinkML schema validation, and OSF.io synchronization capabilities.

## Finding documentation

| If you need... | Go to... | Coverage |
|----------------|----------|----------|
| **Complete CCHS files** | [`cchs-osf-docs/`](cchs-osf-docs/) | 2001-2023 (1,262 files) |
| **Complete CHMS files** | [`chms-osf-docs/`](chms-osf-docs/) | Cycles 1-6 (52 files) |
| **Parsed/extracted content** | [`cchs-extracted/`](cchs-extracted/) | Variable definitions as YAML |
| **Curated download** | [GitHub Releases](../../releases) | Core Master Collection ZIP |
| **Search by metadata** | [`data/catalog/`](data/catalog/) | YAML catalogs with all file info |

> **Note:** The `cchs-pumf-docs/` folder contains a legacy subset of PUMF files (through 2017 only). For complete documentation, use `cchs-osf-docs/`.

---

## Purpose

Statistics Canada health survey documentation is scattered across multiple sources with inconsistent naming, incomplete coverage, and formats that aren't machine-readable. This repository consolidates and organises that documentation into a unified, searchable catalog.

**What this repo does:**

1. **Consolidates fragmented sources** - Merges documentation from OSF.io, Google Drive, and Borealis/ODESSI Dataverse into one catalog
2. **Creates machine-readable metadata** - Extracts variable definitions from PDFs and DDI XML into structured YAML for programmatic access
3. **Provides stable identifiers** - The UID system gives every file a predictable, canonical name regardless of original source
4. **Tracks provenance** - Every file includes source, checksums, and extraction metadata for reproducibility
5. **Bridges Master and PUMF documentation** - Reconciles RDC documentation (more variables) with public-use PUMF files
6. **Enables searchable access** - Powers the [CCHS NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) AI assistant and integrates with analysis workflows

## Related resources

| Resource | Description |
|----------|-------------|
| [CCHS NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) | AI assistant for exploring CCHS documentation |
| [cchsflow](https://github.com/Big-Life-Lab/cchsflow) | R package for harmonising CCHS variables across cycles |
| [cchsflow-data](https://github.com/Big-Life-Lab/cchsflow-data) | CCHS PUMF data files and DDI metadata from ODESSI |
| [613apps.ca](https://613apps.ca) | Population health applications using CCHS data |

## Data sources

This catalog integrates documentation from multiple sources:

| Source | Content | Location in repo |
|--------|---------|------------------|
| OSF.io ([CCHS Docs](https://osf.io/6p3n9/)) | Master and Share files (2001-2023) | `cchs-osf-docs/` |
| OSF.io ([CHMS Docs](https://osf.io/buva4/)) | CHMS cycles 1-6 | `chms-osf-docs/` |
| Google Drive | Legacy PUMF documentation | `cchs-pumf-docs/` |
| Borealis/ODESSI Dataverse | DDI XML with PUMF variable definitions | Extracted to `cchs-extracted/` via `cchsflow-data` |

The YAML catalog (`data/catalog/cchs_catalog.yaml`) tracks all files with their `source_namespace` indicating origin.

## Documentation coverage

### CCHS: 1,421 files (2001-2023)

| Type | Files | | Language | Files |
|------|------:|-|----------|------:|
| Master | 1,118 | | English | 1,097 |
| Share | 183 | | French | 324 |
| PUMF | 120 | | | |

<details>
<summary><strong>Coverage by year and document type</strong> (click to expand)</summary>

| Year | Questionnaire | Data dictionary | User guide | Derived variables |
|------|:---:|:---:|:---:|:---:|
| 2001 | ✓ | ✓ | ✓ | ✓ |
| 2003 | ✓ | ✓ | ✓ | ✓ |
| 2005 | ✓ | ✓ | ✓ | ✓ |
| 2007 | ✓ | ✓ | ✓ | ✓ |
| 2009 | ✓ | ✓ | ✓ | ✓ |
| 2010 | ✓ | ✓ | ✓ | ✓ |
| 2011 | ✓ | ✓ | ✓ | ✓ |
| 2012 | ✓ | ✓ | ✓ | ✓ |
| 2013 | ✓ | ✓ | ✓ | ✓ |
| 2014 | ✓ | ✓ | ✓ | ✓ |
| 2015 | ✓ | ✓ | ✓ | ✓ |
| 2016 | ✓ | ✓ | ✓ | ✓ |
| 2017 | ✓ | ✓ | ✓ | ✓ |
| 2018 | ✓ | ✓ | ✓ | ✓ |
| 2019 | ✓ | ✓ | ✓ | ✓ |
| 2020 | ✓ | ✓ | ✓ | ✓ |
| 2021 | ✓ | ✓ | ✓ | ✓ |
| 2022 | ✓ | ✓ | ✓ | ✓ |
| 2023 | ✓ | ✓ | ✓ | ✓ |

</details>

### CHMS: 52 files (Cycles 1-6)

All cycles include user guides, questionnaires, and data dictionaries covering household, clinic, activity monitor, and fasting components.

## Quick start

### ⚙️ Setup R Environment

This project uses **renv** for reproducible package management:

```r
# Install renv if not already installed
install.packages("renv")

# Restore project packages
renv::restore()
```

**R Version Requirement**: R 4.2+ (development on R 4.4.3)

See [ENVIRONMENT.md](ENVIRONMENT.md) for complete setup instructions, including using **rig** for R version management and **pak** for faster package installation.

---

### 🔍 CCHS Variable Browser

**[Browse 14,005 CCHS Variables](https://big-life-lab.github.io/cchsflow-docs/cchs-browser/)** 🔗

Interactive searchable table of all Statistics Canada CCHS variables across 231 datasets. Search by variable name, label, module, or type. Export filtered results to CSV.

---

### 🤖 AI-Powered Documentation Assistant

**[CCHS Documentation NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08)** 🔗

Interactive AI assistant powered by Google NotebookLM with the complete CCHS Core Master Collection plus PUMF documentation. Ask questions, explore documentation, and get instant answers about CCHS surveys.

---

### Download a collection

Download curated collections from [GitHub Releases](../../releases):

**Core Master Collection (v1.1.0)** - Essential English master documentation
- 129 files: Questionnaires, data dictionaries, user guides, derived variables
- English only, Master files only
- Years 2001-2023 (complete coverage)
- Canonical filenames for easy sharing
- **Also available in**: [NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) for AI-assisted exploration

```r
# After downloading and extracting, load the manifest
library(readr)
manifest <- read_csv("cchs-core-master-collection-v1.1.0/manifest.csv")

# Find files by category
questionnaires <- manifest %>% filter(category == "questionnaire")
```

### View the Full Catalogs

```r
# Load and explore the CCHS catalog (1,262 files)
library(yaml)
cchs_catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")

# View catalog metadata
cchs_catalog$catalog_metadata

# Search files by year
files_2009 <- cchs_catalog$files[sapply(cchs_catalog$files, function(x) x$year == "2009")]

# Find files by category
questionnaires <- cchs_catalog$files[sapply(cchs_catalog$files, function(x) x$category == "questionnaire")]

# Load and explore the CHMS catalog (52 files)
chms_catalog <- yaml::read_yaml("data/catalog/chms_catalog.yaml")

# Search by cycle
cycle3_files <- chms_catalog$files[sapply(chms_catalog$files, function(x) x$chms_cycle == "cycle3")]
```

### Validate Catalogs
```r
# Run comprehensive validation for both surveys
source("R/validate_health_survey_catalog.R")

# Validate CCHS catalog
cchs_validation <- validate_health_survey_catalog("data/catalog/cchs_catalog.yaml")

# Validate CHMS catalog
chms_validation <- validate_health_survey_catalog("data/catalog/chms_catalog.yaml")
```

## 🏗️ System Architecture

### Core Components

#### 📊 **Metadata Catalog System**
- **`data/catalog/cchs_catalog.yaml`** - CCHS production catalog (1,262 files)
- **`data/catalog/chms_catalog.yaml`** - CHMS production catalog (52 files)
- **`metadata/health_survey_schema_linkml.yaml`** - Unified LinkML schema for both surveys
- **`R/clean_catalog_structure.R`** - CCHS catalog generation
- **`R/build_chms_catalog.R`** - CHMS catalog generation
- **`R/validate_health_survey_catalog.R`** - Comprehensive validation for both surveys

#### 📦 **Collections & Distribution**
- **`data/manifests/`** - Collection manifests (tracked in Git)
- **`R/extract_collection.R`** - Survey-aware collection generation from OSF mirrors
- **`build/`** - Temporary build artifacts (gitignored)
- **GitHub Releases** - Distribution platform for collection ZIP files

#### 🔗 **OSF.io Infrastructure**
- **`cchs-osf-docs/`** - CCHS read-only mirror (original filenames)
- **`chms-osf-docs/`** - CHMS read-only mirror (original filenames)
- **`R/osf_api_client.R`** - Production OSF API client for both surveys
- **`R/osf_sync_system.R`** - CCHS synchronization system
- **`R/chms_sync_system.R`** - CHMS synchronization system
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

## 📖 CHMS Terminology

Understanding key CHMS concepts:

**Survey Structure**
- **Cycles**: CHMS collects data in cycles (Cycle 1-6), each representing a distinct data collection period
- **Components**: Each cycle contains multiple components organized by measurement type:
  - **General (gen)**: User guides and general documentation
  - **Household (hhd)**: Household questionnaire data
  - **Clinic (clc)**: Clinical measurements and questionnaires
  - **Activity Monitor Subsample (ams)**: Physical activity monitoring data
  - **Fasting Subsample (fast)**: Fasting blood sample measurements
  - **Environmental (nel)**: Environmental contaminants data
  - **Medication (med)**: Medication usage information
  - **Income (inc)**: Income-related variables
  - **Health Clinic (hcl)**: Health clinic supplementary data

**Document Types**
- **User Guides (ug)**: Methodology, sampling, and data usage instructions
- **Questionnaires (qu)**: Survey instruments and questions
- **Data Dictionaries (dd)**: Variable definitions, codes, and frequencies
- **Derived Variables (dv)**: Documentation of calculated/constructed variables

## 🆔 UID Systems

### CCHS UID System (v3.0)

The CCHS UID system provides unique identifiers with temporal awareness, format differentiation, and optional subcategories for file variants.

#### Format
```
cchs-{year}{temporal}-{doc_type}-{category}-[{subcategory}-]{language}-{extension}-{sequence:02d}
```

**Note**: Subcategory is optional and only used when semantically meaningful (e.g., differentiating main vs simplified formats).

#### Examples

**Without subcategory** (most files):
```bash
cchs-2009d-m-questionnaire-e-pdf-01   # 2009 dual-year, master questionnaire, English PDF
cchs-2015s-s-data-dictionary-f-docx-01   # 2015 single-year, share data dictionary, French Word
cchs-2007d-m-syntax-setvalue-e-sas-01    # 2007 dual-year, master SAS syntax, English
```

**With subcategory** (file variants):
```bash
cchs-2005s-p-data-dictionary-main-e-pdf-01    # Main/official Statistics Canada format
cchs-2005s-p-data-dictionary-simp-e-pdf-02    # Simplified user-friendly format
cchs-2005s-p-data-dictionary-subs-e-pdf-03    # Sub-sample specific version
cchs-2010s-p-ddi-metadata-synt-e-xml-01       # Synthetic data DDI metadata
```

#### Components
- **Year + Temporal**: `2009d` (dual-year), `2015s` (single-year), `2013m` (multi-year)
- **Document Type**: `m` (master), `s` (share), `p` (pumf - Public Use Microdata File)
- **Category**: `questionnaire`, `data-dictionary`, `user-guide`, `derived-variables`, etc.
- **Subcategory** (optional): `main`, `simp`, `subs`, `freq`, `alt`, `comp`, `synt`, `spec`
- **Language**: `e` (English), `f` (French)
- **Extension**: `pdf`, `doc`, `docx`, `sas`, `sps`, `xml`, `html`, `webarchive`, etc.
- **Sequence**: `01`, `02`, `03` (for multiple versions)

#### Subcategory Codes

Use subcategories to differentiate file **types**, not **versions**:

| Code | Meaning | Use Case | Example |
|------|---------|----------|---------|
| `main` | Main/primary version | Official Statistics Canada format | Full data dictionary |
| `simp` | Simplified format | User-friendly tabular layout | Condensed data dictionary |
| `subs` | Sub-sample | Specific subset of data | HUI sub-sample documentation |
| `freq` | Frequency distribution | Summary statistics | Frequency tables |
| `alt` | Alternative format | Different file format of same content | Webarchive vs PDF |
| `comp` | Companion document | Supplementary guide | Complement user guide |
| `synt` | Synthetic data | Synthetic/simulated data | Synthetic file DDI |
| `spec` | Special topic | Focused subset | Income variables only |

**When NOT to use subcategories:**
- Revision numbers (V1, V2, V3) → Use sequence numbers instead
- Minor updates → Use sequence numbers
- Same content, different years → Use year component

### CHMS UID System

The CHMS UID system identifies files by cycle and component rather than year and temporal type.

#### Format
```
chms-c{cycle}-{component}-{doc_type}-{language}-{extension}-{sequence:02d}
```

#### Examples
```bash
chms-c1-gen-ug-e-pdf-01        # Cycle 1, general user guide, English PDF
chms-c3-clc-dd-e-pdf-01        # Cycle 3, clinic data dictionary, English PDF
chms-c5-ams-dd-e-pdf-01        # Cycle 5, activity monitor subsample data dict, English PDF
chms-c6-hcl-dd-f-pdf-01        # Cycle 6, health clinic data dictionary, French PDF
```

#### Components
- **Cycle**: `c1`, `c2`, `c3`, `c4`, `c5`, `c6`
- **Component**: `gen`, `hhd`, `clc`, `ams`, `fast`, `nel`, `med`, `inc`, `hcl`
- **Document Type**: `ug` (user-guide), `qu` (questionnaire), `dd` (data-dictionary), `dv` (derived-variables)
- **Language**: `e` (English), `f` (French)
- **Extension**: `pdf`, `doc`, `docx`
- **Sequence**: `01`, `02`, `03` (for multiple versions)

## 💻 Usage Examples

### Create a Collection
```r
# Generate collections from OSF mirrors
source("R/extract_collection.R")

# CCHS: Core master collection (English master files only)
cchs_core <- extract_collection(
  survey = "CCHS",
  collection_name = "cchs-core-master-collection",
  version = "v1.1.0",
  doc_type = "master",
  language = "EN",
  exclude_syntax = TRUE
)

# CHMS: Cycle 3 collection (example)
chms_c3 <- extract_collection(
  survey = "CHMS",
  collection_name = "chms-cycle3-collection",
  version = "v1.0.0",
  cycles = "cycle3",
  language = "EN"
)

# This creates:
# - build/{collection-name}-{version}.zip
# - data/manifests/{collection-name}-manifest-{version}.csv
```

### OSF Synchronization
```r
# Set up OSF credentials in .env file:
# OSF_PAT=your_personal_access_token

# Sync CCHS with OSF.io
source("R/osf_sync_system.R")
cchs_sync <- sync_osf_structure(
  target_dir = "cchs-osf-docs",
  dry_run = FALSE
)

# Sync CHMS with OSF.io
source("R/chms_sync_system.R")
chms_sync <- sync_chms_structure(
  target_dir = "chms-osf-docs",
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

## Repository structure

### Documentation sources

| Folder | Contents | Status |
|--------|----------|--------|
| `cchs-osf-docs/` | Complete CCHS OSF.io mirror | **Primary** (2001-2023) |
| `chms-osf-docs/` | Complete CHMS OSF.io mirror | **Primary** (Cycles 1-6) |
| `cchs-extracted/` | Parsed content from PDFs | Active development |
| `cchs-pumf-docs/` | Legacy PUMF subset | Incomplete (see README) |

### Metadata and code

- `data/catalog/` - YAML catalogs (`cchs_catalog.yaml`, `chms_catalog.yaml`)
- `data/manifests/` - Collection manifests for GitHub releases
- `R/` - Core scripts (sync, validation, extraction)
- `scripts/` - PDF extraction batch scripts
- `metadata/` - LinkML schema and UID documentation
- `reports/` - Quarto reports for catalog browsing
- `docs/` - Technical documentation

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

### CCHS
✅ **Production Ready**: 1,262 files cataloged with 100% unique UIDs
✅ **Validated**: Comprehensive schema and pattern validation
✅ **Documented**: Complete system documentation and examples
✅ **Maintained**: Active OSF synchronization and change tracking

### CHMS
✅ **Production Ready**: 52 files cataloged with 100% unique UIDs
✅ **Validated**: Schema-compliant with unified validation system
✅ **Documented**: UID system and component detection documented
✅ **Synchronized**: Complete OSF.io mirror downloaded and cataloged

## 📊 Catalog Statistics

### CCHS
- **Total Files**: 1,262 documented files
- **Years Covered**: 2001-2023 (23 survey years)
- **Languages**: English and French documents
- **File Types**: PDF, DOC, DOCX, SAS, SPSS, Stata, TXT, CSV, Excel, Access
- **Categories**: 34 document categories from questionnaires to syntax files
- **UID Uniqueness**: 100% unique identifiers across all files

### CHMS
- **Total Files**: 52 documented files
- **Cycles Covered**: Cycle 1-6 (complete coverage)
- **Languages**: English and French documents
- **File Types**: PDF
- **Components**: 9 component types (gen, hhd, clc, ams, fast, nel, med, inc, hcl)
- **UID Uniqueness**: 100% unique identifiers across all files

---

## 📜 Statistics Canada Attribution

The Canadian Community Health Survey (CCHS) and Canadian Health Measures Survey (CHMS) are conducted by Statistics Canada. Survey data and documentation are accessed and adapted in accordance with the [Statistics Canada Open Licence](https://www.statcan.gc.ca/eng/reference/licence).

**Source**: Statistics Canada, Canadian Community Health Survey (CCHS) and Canadian Health Measures Survey (CHMS). Reproduced and distributed on an "as is" basis with the permission of Statistics Canada.

**Adapted from**: Statistics Canada survey documentation. This does not constitute an endorsement by Statistics Canada of this product.

For information about accessing CCHS and CHMS data, visit:
- [CCHS Survey Information](https://www23.statcan.gc.ca/imdb/p2SV.pl?Function=getSurvey&SDDS=3226)
- [CHMS Survey Information](https://www.statcan.gc.ca/en/survey/household/5071)
- [Research Data Centres](https://www.statcan.gc.ca/en/microdata/data-centres)

---

🤖 *Enhanced metadata catalog system for comprehensive Canadian health survey documentation management*