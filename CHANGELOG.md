# Changelog

All notable changes to the CCHS Documentation Catalog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-09-29

### Fixed
- **BREAKING CHANGE**: Corrected version numbering for all files to v1 (was incorrectly using global sequence numbers)
- Fixed canonical filename generation to use correct v1 version numbers
- Corrected extract_collection() to use enhanced catalog by default

### Added
- Enhanced categorization system with secondary categories and content tags
- Secondary categories for multi-purpose documents (e.g., data dictionaries containing derived variables)
- Content tags for semantic classification (income-variables, health-variables, etc.)
- Enhanced inventory CSV with additional metadata fields:
  - `secondary_categories`: Additional content types found in documents
  - `content_tags`: Semantic classification tags  
  - `temporal_type`: Single vs dual year surveys
  - `doc_type`: Master vs share files
  - `file_extension`: Document format
  - `version`: Document version (now correctly v1 for all OSF downloads)
  - `sequence`: Ordering within document versions
- Automatic exclusion of redundant syntax files (variable-labels-english category) from RAG collections
- Enhanced LinkML schema support for multivalued secondary_categories and content_tags

### Changed
- **BREAKING CHANGE**: All file versions now correctly set to v1 (first version from OSF)
- Canonical filenames now use v1 instead of incremental version numbers
- RAG document collections exclude 37 syntax files by default (redundant with data dictionaries)
- Enhanced catalog is now the default catalog (cchs_catalog.yaml)
- extract_collection() function updated with exclude_syntax parameter

### Technical Details
- Updated clean_catalog_structure.R to force v1 version assignment
- Modified enhance_categorization.R to detect derived variables content in data dictionaries
- Enhanced extract_collection.R with improved inventory generation
- Updated LinkML schema with new multivalued fields

### Migration Notes
For users of the previous catalog:
- All canonical filenames have changed from v2, v3, etc. to v1
- This reflects the correct versioning (these are first downloads from OSF)
- Secondary categories and content tags provide better document classification
- Syntax files are excluded from RAG collections but remain in the full catalog

## [1.0.0] - 2025-09-28

### Added
- Initial CCHS documentation catalog with 1,262 files
- LinkML schema for metadata validation
- CCHS UID system with file extension awareness
- Document categorization and metadata extraction
- OSF integration and file synchronization
- Basic extract_collection() functionality for RAG document preparation

### Features
- Comprehensive metadata catalog for CCHS documentation (2001-2023)
- Standardized canonical file naming using Jenny Bryan conventions
- Document type classification (questionnaire, data-dictionary, user-guide, etc.)
- Language support (English/French)
- Temporal type classification (single/dual/multi-year surveys)
- File integrity verification with checksums