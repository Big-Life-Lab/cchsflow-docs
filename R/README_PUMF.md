# PUMF Documentation Download from Google Drive

This directory contains R scripts to download CCHS PUMF (Public Use Microdata Files) documentation from Google Drive.

## Quick Start

```r
# Download PUMF documentation (214 files)
source("R/download_gdrive_pumf.R")
```

## Files

### `download_gdrive_pumf.R`
**Main download script** - Downloads all PUMF documentation from public Google Drive folder.

- **Source**: Google Drive folder `1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW`
- **Destination**: `cchs-pumf-docs/` (214 files)
- **Method**: Direct download using `googledrive` + `httr` packages
- **Authentication**: Uses public access (no login required)

### `setup_gdrive_auth.R`
**Google Drive authentication setup** (optional, for private folders).

- Creates `.secrets/` directory for OAuth tokens
- Interactive browser-based authentication
- Not required for public PUMF folder

### `download_gdrive_pumf_auth.R`
**Download script with full authentication** - Supports private folders.

- Requires authentication setup via `setup_gdrive_auth.R`
- Use `download_gdrive_pumf.R` instead for public PUMF docs

### `download_gdrive_pumf_missing.R`
**Development script** - Downloads specific missing folders.

- Used during troubleshooting
- Not needed for normal operation

## PUMF Documentation Structure

Downloaded to `cchs-pumf-docs/` with 9 main folders:

```
cchs-pumf-docs/
├── CCHS-Errata/              # Error corrections (3 files)
├── CCHS-PUMF/                # Main PUMF documentation
│   ├── Bootstrap/
│   ├── CCHS_DDI/
│   ├── CCHS_data_dictionary/
│   ├── CCHS_derived_variables/
│   ├── CCHS_study_documentation/
│   ├── CCHS_user_guide/
│   ├── CV-tables/
│   ├── Quality assurance/
│   └── Record-layout/
├── CCHS-questionnnaire/      # Questionnaires (note: 3 n's - typo in GD)
├── CCHS-share/               # Share file documentation
├── CCHS_DDI/                 # Top-level DDI files
├── CCHS_data_dictionary/     # Data dictionaries
├── CCHS_derived_variables/   # Derived variable documentation
├── CCHS_study_documentation/ # Study documentation
└── CCHS_user_guide/          # User guides
```

## Requirements

```r
install.packages(c("googledrive", "httr"))
```

## Notes

- **Git**: `cchs-pumf-docs/` is excluded from version control (see `.gitignore`)
- **Source of truth**: Google Drive folder (public link)
- **Update strategy**: Re-run `download_gdrive_pumf.R` to sync
- **File count**: 214 files as of 2025-10-02
- **Typo**: Questionnaire folder has 3 n's (`CCHS-questionnnaire`) in Google Drive

## Google Drive Link

Public folder: https://drive.google.com/drive/folders/1BWtYYCU6XKbOAiZYvr_znFQK5ORO2AzW

## Future: PUMF Data Distribution

This workflow validates Google Drive + R for future PUMF **data** distribution:

1. **Store data on Google Drive** (no 5GB OSF limit)
2. **Programmatic sync** with `googledrive` package
3. **Git tracks metadata only** (not large data files)
4. **GitHub releases** for curated data subsets
5. **Collection manifests** in `data/manifests/`

See project CLAUDE.md for full architecture.
