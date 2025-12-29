# CCHS Documentation Extraction Scripts

Scripts for extracting CCHS PDF documentation to machine-readable formats (YAML/QMD).

## Overview

The extraction pipeline converts Statistics Canada CCHS PDF documentation into structured formats that enable:
- Programmatic variable lookup
- Cross-cycle comparison
- Integration with cchsflow harmonization workflows
- AI/LLM querying of survey metadata

## Quick start

```bash
# 1. Update source PDF catalog
Rscript generate_master_pdf_catalog.R /path/to/cchsflow-docs

# 2. Extract each document category
Rscript batch_extract_master_data_dictionaries.R /path/to/cchsflow-docs
Rscript batch_extract_master_derived_variables.R /path/to/cchsflow-docs
Rscript batch_extract_master_questionnaires.R /path/to/cchsflow-docs
python batch_extract_master_user_guides.py /path/to/cchsflow-docs

# 3. Update extracted files catalog
Rscript generate_extracted_catalog.R /path/to/cchsflow-docs
```

## Scripts by category

### Catalog generation

| Script | Purpose |
|--------|---------|
| `generate_master_pdf_catalog.R` | Scan source PDFs, generate `cchs-master-pdf-catalog.csv` |
| `generate_extracted_catalog.R` | Scan extracted files, generate `cchs-extracted-files-manifest.csv` |

### Data dictionary extraction

| Script | Purpose |
|--------|---------|
| `extract_data_dictionary.R` | Extract single data dictionary PDF to YAML |
| `batch_extract_data_dictionaries.R` | Batch extract all data dictionaries |
| `batch_extract_master_data_dictionaries.R` | Extract master file data dictionaries |

### Derived variables extraction

| Script | Purpose |
|--------|---------|
| `extract_derived_variables.R` | Extract single DV PDF to YAML (R/pdftools) |
| `extract_derived_variables_pdfplumber.py` | Extract single DV PDF to YAML (Python/pdfplumber) |
| `batch_extract_derived_variables.R` | Batch extract all derived variables |
| `batch_extract_master_derived_variables.R` | Extract master file derived variables |

### Questionnaire extraction

| Script | Purpose |
|--------|---------|
| `extract_questionnaire.R` | Extract single questionnaire PDF to YAML |
| `batch_extract_master_questionnaires.R` | Extract master file questionnaires |

### User guide extraction

| Script | Purpose |
|--------|---------|
| `extract_user_guide.py` | Extract single user guide PDF to QMD (with YAML tables) |
| `batch_extract_master_user_guides.py` | Extract all master user guides |

### Validation scripts

| Script | Purpose |
|--------|---------|
| `validate_against_ddi.py` | Validate PUMF extraction against DDI XML (canonical source) |
| `validate_against_questionnaire.py` | Triangulate extraction against questionnaire |
| `compare_extractions.py` | Compare R vs Python extractions for the same PDF |

### Utility scripts

| Script | Purpose |
|--------|---------|
| `update_extracted_metadata.R` | Update metadata in existing extracted files |
| `extract_data_dictionary_pdfplumber.py` | Alternative Python extractor with `--raw-text` option |

## Output formats

### YAML (data dictionaries, derived variables, questionnaires)

```yaml
cchs_uid: cchs-2015s-m-dd-e-yaml-01
derived_from: cchs-2015s-m-dd-en-pdf-01
survey: CCHS
year: '2015'
category: data-dictionary
source:
  filename: CCHS_2015_DataDictionary.pdf
  checksum_sha256: abc123...
extraction:
  date: '2025-12-28'
  script: extract_data_dictionary.R
  variables_count: 1686
variables:
  GEO_PRV:
    name: GEO_PRV
    label: Province of residence
    categories:
      - value: 10
        label: NEWFOUNDLAND AND LABRADOR
        frequency: 1548
```

### QMD (user guides)

```yaml
---
title: Canadian Community Health Survey User Guide
cchs_uid: cchs-2015s-m-ug-e-qmd-01
derived_from: cchs-2015s-m-ug-en-pdf-01
extraction:
  sections_count: 87
  tables_count: 8
---

## 1 Introduction

The Canadian Community Health Survey (CCHS) is...

```{yaml}
#| label: tbl-4-1
id: '4.1'
title: Length of survey by component
columns:
- CCHS component
- Length
data:
- CCHS component: Core content
  Length: 20 minutes
```
```

## Naming convention (cchs_uid)

```
cchs-{year}{temporal}-{doc_type}-{category}-{language}-{extension}-{sequence}
```

| Component | Values |
|-----------|--------|
| year | 2001, 2015, 2015-2016 |
| temporal | s (single), d (dual) |
| doc_type | m (master), p (PUMF), s (share) |
| category | dd, dv, q, ug |
| language | en, fr, e (extracted) |
| extension | pdf, yaml, qmd |
| sequence | 01, 02, etc. |

## Tool selection

| Tool | Best for | Notes |
|------|----------|-------|
| R/pdftools | Predictable structure, variable tables | Integrates with R workflows |
| Python/pdfplumber | Complex tables, layout-aware extraction | Better table detection |

User guides use pdfplumber because they contain narrative text interspersed with tables. Other document types use R/pdftools because their structure is more predictable.

## Dependencies

### R packages

```r
install.packages(c("pdftools", "yaml", "stringr"))
```

### Python packages

```bash
pipx install pdfplumber
pipx inject pdfplumber pyyaml
```

## Validation workflow

Extraction accuracy is validated through triangulation with multiple authoritative sources:

### DDI validation (PUMF files)

DDI XML files are the canonical source for PUMF variables - they were used to generate the PDF data dictionaries. Validating against DDI identifies extraction bugs.

```bash
python validate_against_ddi.py \
  cchs-pumf-docs/CCHS-PUMF/CCHS_DDI/cchs-82M0013-E-2015-2016-Annual-component.xml \
  cchs-extracted/data-dictionary/2015-2016/pumf_extraction.yaml
```

### Questionnaire triangulation

Questionnaires provide an independent validation source, especially useful for Master files where DDI is not available.

```bash
python validate_against_questionnaire.py \
  cchs-extracted/questionnaire/2015/cchs_2015s_qu_m_en_1_v1.yaml \
  cchs-extracted/data-dictionary/2015/master_extraction.yaml
```

### Dual extraction comparison

Compare R and Python extractions of the same PDF to identify tool-specific bugs:

```bash
python compare_extractions.py \
  extraction_r.yaml \
  extraction_python.yaml
```

### Raw text output

The Python extractor can generate a raw text QMD alongside the structured YAML for manual inspection:

```bash
python extract_data_dictionary_pdfplumber.py input.pdf output.yaml --raw-text
```

This creates `output.qmd` with the raw extracted text organized by variable.

## Adding new survey cycles

1. Download PDFs from Statistics Canada
2. Place in `cchs-osf-docs/{year}/{temporal}/Master/Docs/`
3. Run catalog generation: `Rscript generate_master_pdf_catalog.R`
4. Run batch extraction for each category
5. Run `generate_extracted_catalog.R` to update manifest
