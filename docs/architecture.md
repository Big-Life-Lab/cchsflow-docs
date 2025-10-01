# CCHS Documentation Catalog - System Architecture

This document describes the architecture, components, and data flow of the CCHS Documentation Catalog System.

## 🎯 System Overview

The CCHS Documentation Catalog is a **metadata catalog and distribution system** for Canadian Community Health Survey documentation. It maintains a read-only mirror of OSF.io documentation, generates a comprehensive metadata catalog, and distributes curated collections via GitHub releases.

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         OSF.io (Source)                         │
│                    Project: 6p3n9 / jm8bx                       │
│                    1,262 files (2001-2023)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ R/osf_sync_system.R
                             │ R/osf_api_client.R
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                    cchs-osf-docs/ (Mirror)                      │
│              Original filenames, Git-tracked                    │
│              Read-only authoritative source                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ R/clean_catalog_structure.R
                             │ R/enhance_categorization.R
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│              data/catalog/cchs_catalog.yaml                     │
│           1,262 files with UIDs and metadata                    │
│           LinkML schema validation                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ R/extract_collection.R
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Collections (Themed Sets)                    │
│              Canonical filenames, filtered scope                │
│              ZIP files + CSV manifests                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    ↓                 ↓
            ┌──────────────┐  ┌──────────────┐
            │  build/*.zip │  │ data/        │
            │  (gitignored)│  │ manifests/   │
            │  Temporary   │  │ *.csv        │
            └──────┬───────┘  │ (Git-tracked)│
                   │          └──────────────┘
                   │
                   ↓
         ┌──────────────────┐
         │ GitHub Releases  │
         │ Distribution     │
         └──────────────────┘
```

## 🏗️ Core Components

### 1. OSF.io Integration Layer

**Purpose**: Synchronize with OSF.io and maintain local mirror

**Components**:
- `R/osf_api_client.R` - Custom API client (replaces broken `osfr`)
- `R/osf_sync_system.R` - Sync orchestration and change detection
- `R/osf_versioning_system.R` - Git-based change tracking
- `cchs-osf-docs/` - Local mirror directory

**Key Features**:
- Handles OSF API pagination correctly (fixes 10-item limitation)
- Preserves original filenames and folder structure
- Detects changes via git diff
- Supports incremental updates

### 2. Metadata Catalog System

**Purpose**: Comprehensive metadata catalog with validation

**Components**:
- `data/catalog/cchs_catalog.yaml` - Production catalog (1,262 files)
- `metadata/cchs_schema_linkml.yaml` - LinkML schema
- `R/clean_catalog_structure.R` - Catalog generation
- `R/enhance_categorization.R` - Enhanced categorization
- `R/validate_catalog.R` - Validation system

**Key Features**:
- UID system v2 with extension awareness
- 34 document categories
- Secondary categories and semantic tags
- LinkML schema validation
- 100% unique identifiers

### 3. Collections System

**Purpose**: Generate and distribute themed file collections

**Components**:
- `R/extract_collection.R` - Collection generation
- `data/manifests/` - Collection metadata (Git-tracked)
- `build/` - Temporary build artifacts (gitignored)
- `.github/workflows/release-collection.yml` - Automated releases

**Key Features**:
- Filter by year, language, doc type, category
- Canonical filenames (Jenny Bryan conventions)
- CSV manifests with metadata
- GitHub releases for distribution
- Automated checksums

### 4. Reporting System

**Purpose**: Status reporting and workflow documentation

**Components**:
- `cchs_osf_download_report.qmd` - Download status
- `sync_workflow.qmd` - Executable workflow docs
- `cchs_catalog.qmd` - Catalog browser

**Key Features**:
- Quarto-based reports
- HTML and PDF output
- Interactive tables (GT, DataTables)
- Reproducible workflows

## 🔄 Data Flow

### 1. OSF Synchronization Flow

```
OSF.io API
    ↓ (GET requests with pagination)
Metadata extraction
    ↓ (Save to YAML)
cchs-osf-docs/osf-metadata/YEAR.yaml
    ↓ (Git diff detection)
Change detection
    ↓ (Download if needed)
cchs-osf-docs/YEAR/... (files)
```

### 2. Catalog Generation Flow

```
cchs-osf-docs/ (source files)
    ↓ (Scan and extract metadata)
File metadata extraction
    ↓ (UID assignment)
UID generation (smart sequencing)
    ↓ (Categorization)
Enhanced categorization
    ↓ (Validation)
LinkML schema validation
    ↓ (Save)
data/catalog/cchs_catalog.yaml
```

### 3. Collection Generation Flow

```
User specifies filters
    ↓ (Load catalog)
Read cchs_catalog.yaml
    ↓ (Filter files)
Apply filters (year, lang, doc_type, category)
    ↓ (Copy files)
Copy to temp directory with canonical names
    ↓ (Generate manifest)
Create CSV manifest with metadata
    ↓ (Package)
Create ZIP + move manifest to data/manifests/
    ↓ (Release)
Upload to GitHub release
```

## 💾 Data Storage Strategy

### Git-Tracked (Repository)

**What**: Metadata, manifests, code, small configs

- Source code (`R/`, `.github/`)
- OSF mirror (`cchs-osf-docs/`) - ~166 MB
- Catalog (`data/catalog/cchs_catalog.yaml`) - ~500 KB
- Manifests (`data/manifests/*.csv`) - ~25 KB each
- Documentation (`docs/`, `README.md`, etc.)
- Configuration (`.gitignore`, `config.yml`)

**Why**: Version control, change tracking, collaboration

### Gitignored (Local Only)

**What**: Build artifacts, credentials, temporary files

- Collection ZIPs (`build/*.zip`)
- Environment variables (`.env`)
- R workspace (`.RData`, `.Rhistory`)
- Temporary files (`*~`, `.DS_Store`)

**Why**: Large files, sensitive data, generated content

### GitHub Releases (Distribution)

**What**: Collection ZIP files and manifests

- Collection ZIPs (e.g., `cchs-core-master-collection-v1.1.0.zip`)
- Manifest copies (for convenience)
- Release notes with checksums

**Why**: Large file distribution, versioned downloads, user access

## 🔐 Security & Authentication

### OSF.io Authentication

- Personal Access Token (PAT) stored in `.env`
- Never committed to Git
- Required permissions: Read/write for private project
- Token passed via HTTP headers

### GitHub Authentication

- GitHub Actions uses `GITHUB_TOKEN` (automatic)
- No manual token management needed for releases
- Workflow permissions configured in YAML

## 🎨 Design Principles

### 1. Separation of Concerns

- **Source** (`cchs-osf-docs/`): Original files, read-only
- **Catalog** (`data/catalog/`): Metadata only
- **Collections** (`build/`): Derived artifacts
- **Releases**: Distribution platform

### 2. Reproducibility

- All collections regenerable from OSF mirror
- Deterministic UID assignment
- Documented workflows
- Version-controlled code

### 3. Single Source of Truth

- OSF.io is upstream source
- `cchs-osf-docs/` is local mirror (authoritative copy)
- Catalog derived from mirror
- Collections derived from catalog

### 4. Automation

- Scripted sync workflows
- Automated catalog generation
- GitHub Actions for releases
- Validation at every step

### 5. Versioning

- Semantic versioning for collections
- Git for code and metadata
- Manifests track file versions
- Release tags for distribution

## 🔧 Technology Stack

### Core Technologies

- **R**: Data processing, cataloging, collection generation
- **YAML**: Catalog storage format
- **CSV**: Manifest format (portable, simple)
- **LinkML**: Schema validation
- **Git**: Version control
- **GitHub**: Hosting and releases
- **Quarto**: Reporting and documentation

### Key R Packages

```r
# OSF Integration
library(httr)         # HTTP client for OSF API
library(jsonlite)     # JSON parsing

# Data Processing
library(dplyr)        # Data manipulation
library(readr)        # CSV reading/writing
library(yaml)         # YAML reading/writing

# Infrastructure
library(config)       # Configuration management
library(git2r)        # Git operations

# Reporting
library(gt)           # Tables
library(quarto)       # Documentation
```

## 📊 Performance Characteristics

### Catalog Size

- **Files**: 1,262 documents
- **YAML Size**: ~500 KB (uncompressed)
- **Load Time**: <1 second in R
- **Validation Time**: ~2-3 seconds

### Collection Generation

- **Core Master Collection**: 129 files, ~166 MB
- **Generation Time**: ~30-60 seconds
- **Manifest Size**: ~23 KB

### OSF Synchronization

- **Full Sync**: ~10-15 minutes (all years)
- **Incremental Sync**: ~1-2 minutes (changed years only)
- **Change Detection**: <10 seconds (git-based)

## 🚀 Scalability

### Current Scale

- ✅ 1,262 files cataloged
- ✅ 19 survey years (2001-2023)
- ✅ Repository size: ~166 MB
- ✅ Clone time: ~30-60 seconds

### Future Scale

- Can handle 5,000+ files without architectural changes
- Can support 50+ survey years
- Repository size manageable up to ~500 MB
- For larger scale, consider Git LFS for OSF mirror

## 🔍 Monitoring & Validation

### Automated Checks

- LinkML schema validation on catalog
- UID uniqueness verification
- File count consistency checks
- Checksum validation

### Manual Reviews

- Change detection reports
- Collection manifest reviews
- Documentation updates
- Release notes verification

---

For more details on specific components, see:
- [Collections Guide](collections-guide.md)
- [OSF Sync Guide](osf-sync-guide.md)
- [UID System](uid-system.md)
