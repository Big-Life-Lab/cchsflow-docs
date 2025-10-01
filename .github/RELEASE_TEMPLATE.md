# CCHS [Collection Name] v[X.Y.Z]

## 📦 Collection Details

- **Files**: [N] files
- **Years**: [YYYY-YYYY] ([N] survey years)
- **Languages**: [English only / French only / English + French]
- **Doc Type**: [Master only / Share only / Master + Share]
- **File Size**: [N] MB (compressed)
- **Categories**: [List primary categories: questionnaires, data dictionaries, user guides, etc.]

## 📄 Contents

[Brief description of what's included in this collection]

This collection contains:
- [Description of file types and scope]
- [Coverage details]
- [Any special notes about contents]

## 🚫 Exclusions

[What's NOT included and why]

- [Exclusion 1 with reason]
- [Exclusion 2 with reason]

## 📥 Download & Usage

### Download

1. Download the ZIP file from the Assets section below
2. Download the manifest CSV for file metadata
3. Extract the ZIP to your preferred location

### Load Manifest in R

```r
library(readr)
library(dplyr)

# Load collection manifest
manifest <- read_csv("[collection-name-manifest-vX.Y.Z.csv]")

# Browse available files
View(manifest)

# Find specific files
questionnaires <- manifest %>% filter(category == "questionnaire")
year_2015 <- manifest %>% filter(year == 2015)
```

### Load Manifest in Python

```python
import pandas as pd

# Load collection manifest
manifest = pd.read_csv("[collection-name-manifest-vX.Y.Z.csv]")

# Browse available files
print(manifest.head())

# Find specific files
questionnaires = manifest[manifest['category'] == 'questionnaire']
year_2015 = manifest[manifest['year'] == 2015]
```

## 🔐 Checksums

Verify download integrity:

```bash
# MD5
[md5sum]

# SHA256
[sha256sum]
```

## 📋 Manifest Columns

The accompanying CSV manifest includes:

| Column | Description |
|--------|-------------|
| `uid` | Unique identifier (CCHS UID system) |
| `canonical_filename` | Standardized filename for sharing |
| `original_filename` | Original OSF.io filename |
| `year` | Survey year |
| `category` | Document category |
| `language` | EN or FR |
| `doc_type` | Master or Share |
| `file_extension` | Document format |

See [data/manifests/README.md](../data/manifests/README.md) for full manifest documentation.

## 📚 Documentation

- **Repository**: [Main repository README](../README.md)
- **Collections Guide**: [docs/collections-guide.md](../docs/collections-guide.md)
- **CCHS Terminology**: [README.md#cchs-terminology](../README.md#-cchs-terminology)
- **UID System**: [docs/uid-system.md](../docs/uid-system.md)

## 🔄 Version History

### vX.Y.Z (Release Date)
- [Change 1]
- [Change 2]

### Previous Versions
- [Link to previous release if applicable]

## 📧 Issues & Feedback

- Report issues: [GitHub Issues](../../issues)
- Request new collections: [Collection Request Template](../../issues/new?template=collection_request.md)
- Documentation improvements: [Documentation Template](../../issues/new?template=documentation.md)

---

**Generated from**: OSF.io CCHS Documentation Project (6p3n9)
**Source Repository**: [cchsflow-docs](../../)
**License**: [Specify license if applicable]
