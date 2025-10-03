# Schema v3.0.0 Quick Reference

## UID Format (v3.0)

```
cchs-{year}{temporal}-{doc_type}-{category}-[{subcategory}-]{language}-{extension}-{sequence:02d}
```

**Subcategory is optional** - only use for semantic differences.

## Examples

### Without Subcategory (Most Files)
```
cchs-2009d-m-questionnaire-e-pdf-01
cchs-2015s-s-data-dictionary-f-docx-01
cchs-2007d-m-syntax-setvalue-e-sas-01
```

### With Subcategory (File Variants)
```
cchs-2005s-p-data-dictionary-main-e-pdf-01   # Official format
cchs-2005s-p-data-dictionary-simp-e-pdf-02   # Simplified format
cchs-2005s-p-data-dictionary-subs-e-pdf-03   # Sub-sample version
cchs-2010s-p-ddi-metadata-synt-e-xml-01      # Synthetic data
```

## Subcategory Codes

| Code | Use When | Example |
|------|----------|---------|
| `main` | Official Statistics Canada format | Full data dictionary |
| `simp` | Simplified/user-friendly format | Condensed data dictionary |
| `subs` | Sub-sample specific | HUI sub-sample docs |
| `freq` | Frequency distribution | Summary tables |
| `alt` | Alternative file format | HTML vs PDF |
| `comp` | Companion/supplementary | Complement guide |
| `synt` | Synthetic data | Synthetic DDI |
| `spec` | Special topic/subset | Income vars only |
| `rev` | Major revision (rarely use) | Prefer sequence! |

## When NOT to Use Subcategories

❌ **Version numbers** (V1, V2, V3) → Use sequence instead
❌ **Minor updates** → Use sequence
❌ **Different years** → Already in year field
❌ **Different languages** → Already in language field

## Components

| Component | Values | Examples |
|-----------|--------|----------|
| **Year** | 2001-2023 | 2009, 2015 |
| **Temporal** | s=single, d=dual, m=multi | s, d, m |
| **Doc Type** | m=master, s=share, p=pumf | m, s, p |
| **Category** | questionnaire, data-dictionary, etc. | questionnaire, user-guide |
| **Subcategory** | main, simp, subs, etc. (optional) | main, simp |
| **Language** | e=English, f=French | e, f |
| **Extension** | pdf, doc, sas, xml, etc. | pdf, xml |
| **Sequence** | 01-99 | 01, 02 |

## Canonical Filenames

```
cchs_{year}{temporal}_{category}[_{subcategory}]_{doc}_{lang}_{seq}_v{ver}.{ext}
```

### Examples

**Without subcategory**:
```
cchs_2009d_questionnaire_m_en_1_v1.pdf
```

**With subcategory**:
```
cchs_2005s_data-dictionary_simp_p_en_2_v1.pdf
```

## Required Metadata Fields

```yaml
cchs_uid: cchs-2005s-p-data-dictionary-simp-e-pdf-02
catalog_id: ABC123
year: "2005"
temporal_type: single
doc_type: pumf
category: data-dictionary
subcategory: simp           # Optional
language: EN
version: v1
sequence: 2
filename: 2005cchsdictionary.pdf              # Original name
canonical_filename: cchs_2005s_data-dictionary_simp_p_en_2_v1.pdf
source: pumf                # osf, pumf, or other
source_namespace: gdrive_pumf_collection  # NEW in v3.0.0
source_filepath: CCHS-PUMF/2005/2005cchsdictionary.pdf  # NEW in v3.0.0
file_extension: pdf
checksum: <sha256>
```

### Namespace System (v3.0.0)

**Namespaces** define source locations for URL reconstruction and provenance tracking. Each catalog defines namespaces in `catalog_metadata.namespaces`:

```yaml
catalog_metadata:
  namespaces:
    osf_cchs_docs:
      name: CCHS Docs - Documentation Component
      description: OSF project containing CCHS master documentation files
      type: osf
      project_id: 6p3n9
      component_id: jm8bx
      base_url: https://osf.io/jm8bx/files/osfstorage
    local_osf_mirror:
      name: OSF Local Mirror
      description: Local filesystem mirror of OSF CCHS documentation
      type: local
      base_path: cchs-osf-docs/
```

**File entries** reference namespaces:
- `source_namespace`: Points to namespace ID (e.g., `osf_cchs_docs`)
- `source_filepath`: Original path+filename from that namespace

**URL Reconstruction**: `namespaces[source_namespace].base_url + "/" + source_filepath`

## Validation Commands

```r
# Validate a catalog
source("R/validate_catalog.R")
validate_catalog("data/catalog/cchs_catalog.yaml")
```

## Current Catalogs

| Catalog | Version | Files | Status |
|---------|---------|-------|--------|
| `cchs_catalog.yaml` (OSF) | v3.0.0 | 1,262 | ✅ Production |
| `cchs_catalog_pumf.yaml` | - | - | 🗑️ Delete (flawed) |

## Schema Versions

| Version | UID Format | Changes |
|---------|------------|---------|
| v1.0 | No extension in UID | Initial |
| v2.0 | Added extension | Extension awareness |
| v3.0 | Added optional subcategory | **Current** |

## Common Patterns

### Data Dictionaries with Variants
```
main: Official Statistics Canada format (long names)
simp: Simplified format (short names)
subs: Sub-sample specific (HUI, etc.)
```

### DDI Metadata
```
main: Main/official DDI
synt: Synthetic data DDI
```

### Questionnaires
```
# No subcategories - use sequence:
01, 02, 03... for different versions/revisions
```

### Derived Variables
```
spec: Special topic (e.g., "new income variables")
simp: Simplified format
```

## Migration Checklist

### OSF Catalog (Complete ✅)
- [x] Update schema to v3.0.0
- [x] Add `source: osf` to all files
- [x] Update metadata versions
- [x] Validate (1,262 files, 0 errors)

### PUMF Integration (Pending ⏳)
- [ ] Replace cchs-pumf-docs with originals
- [ ] Delete flawed catalog
- [ ] Run Phase 1: Initial catalog (no subcategories)
- [ ] Run Phase 2: Extract files needing subcategories
- [ ] Manually assign subcategories
- [ ] Run Phase 3: Re-catalog with subcategories
- [ ] Validate (0 duplicate UIDs, all original names preserved)

## Files to Review

| Document | Purpose |
|----------|---------|
| `WORK_SESSION_SUMMARY.md` | Full session summary |
| `V3_MIGRATION_STATUS.md` | Migration guide |
| `CHANGELOG.md` | v3.0.0 release notes |
| `docs/future-improvements.md` | Validation roadmap |

---

**Quick Start**: See `WORK_SESSION_SUMMARY.md` for complete details.
