# CCHS Collection Manifests

This directory contains CSV manifests that describe CCHS documentation collections distributed as GitHub releases.

## Purpose

Manifests provide detailed metadata about files in each collection, including:
- Canonical filenames (following Jenny Bryan conventions)
- Original OSF.io filenames
- File categorization and metadata
- Version information

## Current Manifests

### Core Master Collection (v1.1.0)

**File:** `cchs-core-master-collection-manifest-v1.1.0.csv`
**Collection:** `cchs-core-master-collection-v1.1.0.zip` (GitHub Release)

Essential CCHS **Master file** documentation for analysis and research:
- Questionnaires (English only)
- Data dictionaries (English only)
- User guides (English only)
- Derived variables documentation (English only)

**Scope:** Master files only (not Share files)
**Language:** English only
**Exclusions:** Redundant syntax files (variable-labels-english category)

**Statistics:**
- Files: 129 files
- Years: 2001-2023 (all years covered)
- Languages: English only
- Doc Type: Master files only
- Categories: Questionnaires, data dictionaries, user guides, derived variables

## Manifest Structure

Each manifest CSV contains the following columns:

| Column | Description |
|--------|-------------|
| `uid` | Unique identifier (CCHS UID system) |
| `canonical_filename` | Standardized filename for sharing |
| `original_filename` | Original OSF.io filename |
| `year` | Survey year |
| `category` | Primary document category |
| `secondary_categories` | Additional content classifications |
| `content_tags` | Semantic tags (e.g., health-variables) |
| `language` | EN or FR |
| `temporal_type` | Single/dual/multi-year survey |
| `doc_type` | Master or share files |
| `file_extension` | Document format |
| `version` | Document version (v1 = first OSF download) |
| `sequence` | Ordering within versions |
| `osf_path` | Original OSF.io path |

## Using Manifests

### Load in R

```r
library(readr)
manifest <- read_csv("data/manifests/cchs-core-master-collection-manifest-v1.1.0.csv")

# Find specific files
questionnaires <- manifest %>% filter(category == "questionnaire")
data_dicts <- manifest %>% filter(category == "data-dictionary")

# Get canonical filename for a UID
manifest %>% filter(uid == "cchs-2015s-m-qu-e-pdf-01") %>% pull(canonical_filename)
```

### Load in Python

```python
import pandas as pd
manifest = pd.read_csv("data/manifests/cchs-core-master-collection-manifest-v1.1.0.csv")

# Search by year
year_2023 = manifest[manifest['year'] == 2023]

# Find files with specific content
income_vars = manifest[manifest['content_tags'].str.contains('income-variables', na=False)]
```

## Collection Generation

Collections are generated from the OSF.io mirror in `cchs-osf-docs/` using:

```r
source("R/extract_collection.R")

# Generate core master collection
core_master_collection <- extract_collection(
  collection_name = "cchs-core-master-collection",
  version = "v1.1.0",
  doc_type = "master",      # Master files only
  language = "EN",          # English only
  exclude_syntax = TRUE     # Excludes redundant variable-labels-english files
)
```

This creates:
- `build/cchs-core-master-collection-v1.1.0.zip` (temporary build artifact)
- `data/manifests/cchs-core-master-collection-manifest-v1.1.0.csv` (tracked in Git)

## Workflow

1. **Source:** `cchs-osf-docs/` (OSF.io mirror, original filenames)
2. **Generate:** Run `extract_collection()` to create ZIP and manifest
3. **Commit:** Commit manifest CSV to Git
4. **Release:** Upload ZIP to GitHub release (delete from repo)
5. **Distribute:** Users download ZIP from releases, use manifest for metadata

## Future Collections

Potential future collections:
- `cchs-core-share-collection` - Share files (English only)
- `cchs-core-master-fr-collection` - Master files (French only)
- `cchs-complete-master-collection` - All master files (English + French)
- `cchs-complete-collection` - Everything (Master + Share, English + French)
- `cchs-syntax-collection` - SAS/SPSS/Stata syntax files only

Each collection will have its own versioned manifest in this directory.

---

**Manifests are tracked in Git. Collections are distributed via GitHub releases.**
