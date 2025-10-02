# CCHS Collections Guide

Complete guide to using and creating CCHS documentation collections.

## 📦 What Are Collections?

Collections are **curated subsets** of CCHS documentation files packaged with:
- **Canonical filenames** (standardized, shareable)
- **CSV manifests** with metadata
- **Filtered scope** (by year, language, doc type, category)
- **Distribution via GitHub releases**

Collections make it easy to download and work with specific sets of CCHS documentation without managing the full 1,262-file catalog.

## 🎯 Available Collections

### Core Master Collection (v1.1.0)

**Scope**: Essential English master documentation

- **Files**: 129 files
- **Years**: 2001-2023 (all years)
- **Languages**: English only
- **Doc Type**: Master files only
- **Categories**: Questionnaires, data dictionaries, user guides, derived variables
- **Exclusions**: Redundant syntax files

**When to use**: Research at RDCs, comprehensive documentation needs, English-language analysis

**Download**: [Releases](https://github.com/YOUR_USERNAME/cchsflow-docs/releases)

**🤖 AI Assistant**: [CCHS Documentation NotebookLM](https://notebooklm.google.com/notebook/d89f1bf8-1eb5-4bc7-bfd4-462be2c01a08) - Interactive AI assistant with this collection plus PUMF documentation for instant answers and exploration

### Future Collections

Coming soon:
- **Core Share Collection** - Share files (English)
- **Core Master FR** - Master files (French)
- **Complete Master** - All master files (EN + FR)
- **Syntax Collection** - SAS/SPSS/Stata files only

## 📥 Using a Collection

### Step 1: Download

1. Go to [GitHub Releases](https://github.com/YOUR_USERNAME/cchsflow-docs/releases)
2. Find your desired collection
3. Download the ZIP file and manifest CSV

### Step 2: Extract

```bash
# Extract the collection
unzip cchs-core-master-collection-v1.1.0.zip

# Verify contents
cd cchs-core-master-collection-v1.1.0/
ls -lh
```

### Step 3: Load Manifest

#### In R

```r
library(readr)
library(dplyr)

# Load the manifest
manifest <- read_csv("cchs-core-master-collection-manifest-v1.1.0.csv")

# Explore the manifest
View(manifest)
str(manifest)

# Find specific files
questionnaires <- manifest %>%
  filter(category == "questionnaire")

# Find files for specific year
year_2015 <- manifest %>%
  filter(year == 2015)

# Find derived variables documentation
derived_vars <- manifest %>%
  filter(category == "derived-variables")

# Get file path for a UID
file_path <- manifest %>%
  filter(uid == "cchs-2015s-m-qu-e-pdf-01") %>%
  pull(canonical_filename)
```

#### In Python

```python
import pandas as pd

# Load the manifest
manifest = pd.read_csv("cchs-core-master-collection-manifest-v1.1.0.csv")

# Explore the manifest
print(manifest.head())
print(manifest.info())

# Find specific files
questionnaires = manifest[manifest['category'] == 'questionnaire']

# Find files for specific year
year_2015 = manifest[manifest['year'] == 2015]

# Find files with specific content
income_docs = manifest[
    manifest['content_tags'].str.contains('income-variables', na=False)
]

# Get file path for a UID
file_path = manifest[
    manifest['uid'] == 'cchs-2015s-m-qu-e-pdf-01'
]['canonical_filename'].values[0]
```

### Step 4: Access Files

```r
# Load a specific file
library(pdftools)

# Read a PDF questionnaire
pdf_path <- manifest %>%
  filter(year == 2023, category == "questionnaire") %>%
  pull(canonical_filename) %>%
  first()

pdf_text <- pdf_text(pdf_path)

# Or open in external viewer
system(paste("open", pdf_path))  # macOS
# system(paste("xdg-open", pdf_path))  # Linux
```

## 🛠️ Creating a Custom Collection

### Prerequisites

1. Clone the repository
2. Set up R environment
3. Install dependencies:

```r
install.packages(c("yaml", "dplyr", "readr"))
```

### Basic Collection Generation

```r
# Load the collection generator
source("R/extract_collection.R")

# Generate a collection
my_collection <- extract_collection(
  collection_name = "my-custom-collection",
  version = "v1.0.0",
  doc_type = "master",      # "master", "share", or "all"
  language = "EN",          # "EN", "FR", or "all"
  exclude_syntax = TRUE     # Exclude redundant syntax files
)

# Output:
# - build/my-custom-collection-v1.0.0.zip
# - data/manifests/my-custom-collection-manifest-v1.0.0.csv
```

### Advanced Filtering

```r
# Custom collection with specific years
custom_recent <- extract_collection(
  collection_name = "cchs-recent-master",
  version = "v1.0.0",
  years = 2015:2023,           # Only recent years
  doc_type = "master",
  language = "EN",
  categories = c("questionnaire", "data-dictionary", "user-guide")
)

# French-only collection
french_collection <- extract_collection(
  collection_name = "cchs-master-fr",
  version = "v1.0.0",
  doc_type = "master",
  language = "FR",
  exclude_syntax = FALSE  # Include syntax files
)

# Share files only
share_collection <- extract_collection(
  collection_name = "cchs-share-public",
  version = "v1.0.0",
  doc_type = "share",
  language = "all"
)
```

### Collection Parameters

| Parameter | Options | Description |
|-----------|---------|-------------|
| `collection_name` | String | Name for the collection |
| `version` | String (vX.Y.Z) | Semantic version |
| `years` | Vector or "all" | Specific years to include |
| `doc_type` | "master", "share", "all" | Document type filter |
| `language` | "EN", "FR", "all" | Language filter |
| `categories` | Vector or "all" | Document categories |
| `exclude_syntax` | TRUE/FALSE | Exclude redundant syntax files |

## 📝 Manifest Structure

Each collection includes a CSV manifest with these columns:

| Column | Description | Example |
|--------|-------------|---------|
| `uid` | Unique identifier | cchs-2015s-m-qu-e-pdf-01 |
| `canonical_filename` | Standardized filename | cchs_2015s_qu_m_en_1_v1.pdf |
| `original_filename` | OSF.io filename | CCHS_2015_Questionnaire.pdf |
| `year` | Survey year | 2015 |
| `category` | Document category | questionnaire |
| `secondary_categories` | Additional types | derived-variables |
| `content_tags` | Semantic tags | income-variables |
| `language` | EN or FR | EN |
| `temporal_type` | single/dual/multi | single |
| `doc_type` | master or share | master |
| `file_extension` | Format | pdf |
| `version` | Document version | v1 |
| `sequence` | Order within versions | 1 |
| `file_size` | Bytes | 1472820 |
| `status` | Extraction status | extracted |

## 🎨 Naming Conventions

### Collection Names

Format: `cchs-{scope}-{subset}-collection`

Examples:
- `cchs-core-master-collection` - Core master files
- `cchs-complete-collection` - Everything
- `cchs-syntax-collection` - Syntax files only
- `cchs-recent-master-collection` - Recent years master

### Canonical Filenames

Format: `cchs_{year}{temporal}_{category}_{doctype}_{lang}_{seq}_v{ver}.{ext}`

Examples:
- `cchs_2015s_qu_m_en_1_v1.pdf` - 2015 single-year questionnaire
- `cchs_2009d_dd_m_fr_2_v1.pdf` - 2009 dual-year data dictionary (French)

See [UID System](uid-system.md) for complete specification.

## 🚀 Publishing Collections

### Manual Release

1. Generate collection locally
2. Create GitHub release
3. Upload ZIP and manifest
4. Add release notes with checksums

### Automated Release (GitHub Actions)

```bash
# Trigger workflow via GitHub UI
# Go to Actions → Release CCHS Collection → Run workflow

# Or via gh CLI
gh workflow run release-collection.yml \
  -f collection_name=cchs-core-master-collection \
  -f version=v1.2.0 \
  -f doc_type=master \
  -f language=EN \
  -f exclude_syntax=true
```

The workflow automatically:
- Generates the collection
- Creates checksums (MD5, SHA256)
- Creates GitHub release
- Uploads ZIP and manifest
- Generates release notes

## 📊 Collection Best Practices

### For Users

1. **Always check the manifest** before using files
2. **Verify checksums** after download
3. **Use canonical filenames** for sharing/referencing
4. **Keep manifests** with your collections for metadata

### For Creators

1. **Use semantic versioning** (vX.Y.Z)
2. **Document exclusions** in release notes
3. **Test locally first** before publishing
4. **Include checksums** in release notes
5. **Update manifests** when regenerating collections

## 🔍 Troubleshooting

### Collection Generation Fails

```r
# Check catalog is loaded
library(yaml)
catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")
length(catalog$files)  # Should be 1262

# Check source files exist
dir.exists("cchs-osf-docs/2015")  # Should be TRUE
```

### Missing Files in Collection

```r
# Check filters aren't too restrictive
manifest <- read_csv("data/manifests/my-collection-manifest-v1.0.0.csv")
table(manifest$year)      # Check year distribution
table(manifest$language)  # Check language distribution
table(manifest$category)  # Check category distribution
```

### Manifest Won't Load

```r
# Check file exists and is valid CSV
file.exists("manifest.csv")
manifest <- read_csv("manifest.csv", show_col_types = FALSE)
problems(manifest)  # Show any parsing issues
```

## 📚 Related Documentation

- [Architecture](architecture.md) - System design
- [OSF Sync Guide](osf-sync-guide.md) - Synchronization workflows
- [UID System](uid-system.md) - Identifier specification
- [Glossary](glossary.md) - CCHS terminology

## 📧 Getting Help

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/cchsflow-docs/issues)
- **Collection Requests**: Use [Collection Request template](../.github/ISSUE_TEMPLATE/collection_request.md)
- **Documentation**: Use [Documentation template](../.github/ISSUE_TEMPLATE/documentation.md)

---

**Next Steps**: See [OSF Sync Guide](osf-sync-guide.md) to keep your collections up to date.
