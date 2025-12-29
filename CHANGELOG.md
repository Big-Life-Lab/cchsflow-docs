# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2025-12-29

### Added

#### Multi-survey support
- **CHMS integration**: Added Canadian Health Measures Survey (CHMS) support alongside CCHS
- **Unified schema v4.0.0**: Extended LinkML schema to support both CCHS and CHMS surveys
- **CHMS OSF sync**: Complete mirror of 52 CHMS files across 6 cycles
- **CHMS catalog**: Full metadata catalog with CHMS-specific fields (cycle, component)
- **CHMS UID system**: Survey-specific identifiers (e.g., `chms-c1-hhd-qu-e-pdf-01`)

#### Extracted files collection
- **137 extracted files** from CCHS Master and PUMF documentation:
  - 35 data dictionary files (YAML + QMD) - 2001-2023
  - 31 derived variables files - 2007-2023
  - 19 questionnaire files - 2009-2023
  - 30 user guide files - 2001-2023 (including PUMF)
- **Full provenance tracking**: Each extracted file includes `cchs_uid` and `derived_from` fields
- **Bidirectional traceability**: Source PDFs linked to extracted files via UID system

#### PUMF documentation
- **PUMF data dictionaries**: Extracted from Google Drive PUMF collection
- **PUMF user guides**: 2003, 2005, 2017-2018 PUMF user guides extracted
- **Share file support**: Added share file extractions for dual-year surveys

#### Extraction infrastructure
- **18 extraction scripts** in `scripts/` directory
- **5 manifests** tracking all extractions with checksums and metadata
- **Catalog-aligned metadata**: All extracted files include full catalog metadata in headers

### Changed

- **Schema version**: Upgraded from v3.1.0 to v4.0.0 (breaking change for CHMS support)
- **UID format**: Extended to support survey-specific identifiers
- **Canonical filename format**: Standardised across all document types

### Technical details

#### Schema changes (v4.0.0)
- Added `survey` field to distinguish CCHS from CHMS
- Added `chms_cycle` and `chms_component` fields for CHMS-specific metadata
- Extended `NamespaceTypeEnum` to include CHMS OSF project
- Updated validation rules for survey-specific patterns

#### Extraction metadata format
Each extracted YAML file includes:
```yaml
cchs_uid: cchs-2015s-m-dd-en-yaml-01
derived_from: cchs-2015s-m-dd-en-pdf-01
survey: CCHS
year: '2015'
temporal_type: single
doc_type: master
category: data-dictionary
language: EN
version: v1
sequence: 1
canonical_filename: cchs_2015s_dd_m_en_1_v1.yaml
source:
  cchs_uid: cchs-2015s-m-dd-en-pdf-01
  filename: CCHS_2015_DataDictionary_Freqs.pdf
  checksum: <sha256>
extraction:
  date: 2025-12-28
  script: extract_data_dictionary.R
  script_version: 1.1.0
```

## [3.1.0] - 2025-10-01

### Added
- PUMF integration with Google Drive download scripts
- Canonical filename fixes for consistent naming
- Namespace system for multi-source support

## [3.0.0] - 2025-10-01

### Added
- Namespace system for URL reconstruction and provenance tracking
- Reproducible R environment with renv
- UID format extended with optional subcategory code

### Breaking changes
- UID format now includes optional subcategory for differentiating file variants

## [1.1.0] - 2025-10-01

### Added
- CCHS Core Master Collection v1.1.0 (129 files)
- Enhanced categorisation with 34 document types
- UID system v2 with temporal awareness
- Collections distribution via GitHub releases

## [1.0.0] - 2025-09-15

### Added
- Initial metadata catalog system for CCHS documentation
- OSF.io mirror synchronisation
- LinkML schema validation
- Basic UID system for file identification
