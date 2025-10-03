# Changelog

All notable changes to the CCHS Documentation Catalog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2025-10-03

### BREAKING CHANGES ⚠️

**UID Format Change**: UID system updated to v3.0 with optional subcategory support for differentiating file variants.

**Previous format (v2.0)**:
```
cchs-{year}{temporal}-{doc_type}-{category}-{language}-{extension}-{sequence:02d}
Example: cchs-2005s-p-data-dictionary-e-pdf-02
```

**New format (v3.0)**:
```
cchs-{year}{temporal}-{doc_type}-{category}-[{subcategory}-]{language}-{extension}-{sequence:02d}
Example: cchs-2005s-p-data-dictionary-simp-e-pdf-02
```

**Canonical Filename Change**: Filenames updated to include optional subcategory.

**Previous format**:
```
cchs_{year}{temporal}_{category}_{doc_type}_{language}_{sequence}_v{version}.{ext}
Example: cchs_2005s_data-dictionary_p_en_2_v1.pdf
```

**New format**:
```
cchs_{year}{temporal}_{category}[_{subcategory}]_{doc_type}_{language}_{sequence}_v{version}.{ext}
Example: cchs_2005s_data-dictionary_simp_p_en_2_v1.pdf
```

### Added
- **Namespace system** for multi-source provenance tracking:
  - `Namespace` class defines source locations (OSF projects, Google Drive folders, local mirrors)
  - `source_namespace` field links files to namespace definitions
  - `source_filepath` preserves original path+filename from source
  - Supports URL reconstruction: `base_url + "/" + source_filepath`
  - `NamespaceTypeEnum` with values: osf, gdrive, local, odesi, statcan, other
  - Catalog metadata contains namespace definitions with project_id, component_id, base_url, base_path

- **Subcategory support** for differentiating file variants:
  - `main` - Main/primary version (typically Statistics Canada official format)
  - `simp` - Simplified format (user-friendly tabular format)
  - `subs` - Sub-sample or subset version
  - `freq` - Frequency distribution version
  - `rev` - Revised or updated version (use sparingly - prefer sequence numbers)
  - `alt` - Alternative format or version
  - `comp` - Companion or supplementary document
  - `synt` - Synthetic data version
  - `spec` - Special topic or focused subset

- **Multi-source catalog support**:
  - `source` field tracks file origin (osf, pumf, other)
  - DataSourceEnum in schema for validation
  - Infrastructure for integrating PUMF (Public Use Microdata Files)

- **Enhanced schema validation** (v3.0.0):
  - SubcategoryEnum with 9 permissible values
  - Optional subcategory field in CCHSFile class
  - Updated UID and canonical filename patterns
  - Subcategory consistency validation between UID and metadata
  - Required fields: source_namespace and source_filepath

- **New file extensions** for PUMF integration:
  - `xml` - DDI metadata files
  - `webarchive` - Archived web questionnaires
  - `html` - HTML format questionnaires

- **New document categories** for PUMF:
  - `ddi-metadata` - Data Documentation Initiative files
  - `bootstrap` - Bootstrap weight documentation
  - `quality-assurance` - Quality assurance reports
  - `study-documentation` - Study-level documentation

- **Reproducible environment management**:
  - `renv` for package version locking and reproducibility
  - `renv.lock` tracks all package dependencies with exact versions
  - `.Rprofile` activates renv automatically on project load
  - `ENVIRONMENT.md` documents R version requirements, package management workflow, and IDE setup
  - `.renvignore` excludes data directories from dependency scanning
  - R version compatibility floor: R 4.2+ (development on R 4.5.1)
  - Support for `rig` (R version management) and `pak` (fast package installation)

- **Documentation**:
  - `docs/future-improvements.md` - Roadmap for schema-driven validation
  - `docs/pumf-subcategory-proposal.md` - Subcategory design rationale
  - `ENVIRONMENT.md` - Complete environment setup and package management guide
  - Updated README.md with v3.0 UID format examples and renv setup instructions

### Changed
- **Schema version**: 2.1.0 → 3.0.0 (BREAKING CHANGE)
- **UID system version**: 2.0 → 3.0
- **Catalog metadata**: Now includes `schema_version` and `uid_system_version` fields
- **Validation scripts**: Updated for v3.0 patterns and subcategory validation

### Technical Details
- LinkML schema ID: `https://github.com/Big-Life-Lab/cchs-documentation/schema/v3`
- Subcategory is optional - only used when semantically meaningful
- Files without subcategory use sequence numbers for differentiation
- Backward compatible for files without subcategories (UIDs remain valid)

### Migration Notes
**For OSF Catalog Users**:
- OSF catalog (1,262 files) will be updated to v3.0 format
- Add `source: osf` field to all entries
- No subcategories needed for most OSF files (use sequence numbers)
- UIDs remain stable for files without subcategories

**For New PUMF Integration**:
- PUMF files will use v3.0 format from initial cataloging
- Subcategories differentiate file variants (main vs simplified vs sub-sample)
- Original filenames preserved in metadata alongside canonical names

### Removed
- **Deprecated path fields** removed from catalog (breaking change, but project is new):
  - `local_path` - Replaced by `source_filepath` with local namespace
  - `osf_path` - Replaced by `source_filepath` with OSF namespace
  - `pumf_path` - Replaced by `source_filepath` with PUMF namespace
  - Fields still marked as deprecated in schema for reference, but removed from catalog entries
  - Cleaner catalog structure with namespace-based approach from the start

### Added
- **Collections distribution system** via GitHub releases
  - Manifest files for collection metadata tracking (`data/manifests/`)
  - Core Master Collection v1.1.0: 129 English master files (2001-2023)
  - Build directory for temporary collection artifacts (`build/`)
  - Collection generation script (`R/extract_collection.R`)
- **GitHub infrastructure** for releases and collaboration
  - Release template for consistent collection releases
  - GitHub workflow for automated collection releases
  - Issue templates for bug reports, collection requests, and documentation
- **Structured documentation** in `docs/` directory
  - Architecture documentation with system design
  - Collections guide for creating and using collections
  - OSF sync guide for synchronization workflows
  - CCHS glossary for terminology clarification

### Changed
- **Repository architecture**: Shifted from single monolithic catalog to OSF mirror → Collections workflow
- **Distribution model**: Collections distributed via GitHub releases (not stored in Git repository)
- **File organization**: Separated source files (`cchs-osf-docs/`) from build artifacts (`build/`)
- Updated README.md with collections architecture and accurate file counts
- Updated CLAUDE.md with current system architecture and workflows
- Renamed collection from "rag-collection" to "core-master-collection" for clarity

### Technical
- Collections are reproducible from OSF mirror
- Manifests tracked in Git, collection ZIPs in releases
- Build artifacts properly gitignored

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