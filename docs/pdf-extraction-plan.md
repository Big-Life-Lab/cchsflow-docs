# PDF Extraction Plan

## Overview

Extract structured data from CCHS PDF documentation into machine-readable formats (YAML/JSON) that align with DDI XML structure.

## Folder structure

```
cchsflow-docs/
├── cchs-pumf-docs/           # Original PDFs (existing)
│   ├── CCHS-PUMF/
│   │   ├── CCHS_data_dictionary/
│   │   ├── CCHS_user_guide/
│   │   └── ...
│   └── ...
├── cchs-extracted/           # NEW: Extracted data
│   ├── data-dictionary/      # Mirrors PDF structure
│   │   ├── 2015-2016/
│   │   │   ├── cchs_2015d_dd_m_en_1_v1.yaml
│   │   │   └── cchs_2015d_dd_m_en_1_v1.md   # Optional markdown
│   │   └── ...
│   ├── user-guide/
│   │   ├── 2015-2016/
│   │   │   └── cchs_2015d_ug_m_en_1_v1.md
│   │   └── ...
│   └── derived-variables/
│       └── ...
└── data/
    └── catalog/
        └── cchs_catalog.yaml  # Add extracted_path field
```

## Naming convention

Build from canonical filename, change extension:
- Original: `cchs_2015d_dd_m_en_1_v1.pdf`
- Extracted: `cchs_2015d_dd_m_en_1_v1.yaml` (structured) or `.md` (prose)

## Catalog schema extension

Add to `cchs_catalog.yaml` file entries:

```yaml
- cchs_uid: cchs-2015d-dd-m-en-pdf-01
  canonical_filename: cchs_2015d_dd_m_en_1_v1.pdf
  # ... existing fields ...
  extracted:
    path: cchs-extracted/data-dictionary/2015-2016/cchs_2015d_dd_m_en_1_v1.yaml
    format: yaml
    extraction_date: 2025-12-27
    extraction_version: 1.0.0
    variables_count: 450  # For data dictionaries
```

## Extraction formats by document type

### Data Dictionary → YAML

Aligned with DDI structure:

```yaml
metadata:
  source_file: cchs_2015d_dd_m_en_1_v1.pdf
  survey: CCHS
  year: 2015-2016
  doc_type: data-dictionary
  extraction_date: 2025-12-27

variables:
  SMK_005:
    name: SMK_005
    length: 1
    position: 319
    label: "Type of smoker (daily / occasionally / not at all) - presently"
    question_text: "At the present time, do you smoke cigarettes every day, occasionally or not at all?"
    universe: "Respondents with DOSMK = 1"
    categories:
      - value: 1
        label: "Daily"
        frequency: 15367
        weighted_frequency: 3765095
        percent: 12.3
      - value: 2
        label: "Occasionally"
        frequency: 4910
      # ... etc
```

### User Guide → Markdown

Preserve section structure:

```markdown
---
source_file: cchs_2015d_ug_m_en_1_v1.pdf
survey: CCHS
year: 2015-2016
doc_type: user-guide
extraction_date: 2025-12-27
---

# CCHS 2015-2016 User Guide

## 12.6 Variable naming convention

The variable naming convention adopted allows data users to easily use...

### Position meanings

| Position | Meaning | Example |
|----------|---------|---------|
| 1-3 | Module name | SMK |
| 4 | Variable type | _ (collected), D (derived), G (grouped) |
| 5-8 | Question number | 005 |
```

### Derived Variables → YAML

```yaml
metadata:
  source_file: cchs_2015d_dv_m_en_1_v1.pdf
  survey: CCHS
  year: 2015-2016
  doc_type: derived-variables

derived_variables:
  SMKDVSTY:
    name: SMKDVSTY
    label: "Smoking status (type 2) - traditional definition"
    description: |
      Classifies respondents by smoking status...
    source_variables:
      - SMK_005
      - SMK_020
      - SMK_030
    calculation: |
      IF SMK_005 = 1 THEN SMKDVSTY = 1 (Daily smoker)
      ELSE IF SMK_005 = 2 THEN SMKDVSTY = 2 (Occasional smoker)
      ...
    categories:
      - value: 1
        label: "Daily smoker"
      - value: 2
        label: "Occasional smoker (former daily)"
      # ...
```

## Implementation plan

### Phase 1: Data dictionary parser (priority)

1. Create R script: `scripts/extract_data_dictionary.R`
2. Parse structured variable entries from PDF text
3. Output YAML aligned with DDI structure
4. Test on 2015-2016 data dictionary

### Phase 2: Catalog integration

1. Add `extracted` field to LinkML schema
2. Update `cchs_catalog.yaml` with extraction references
3. Create manifest of extracted files

### Phase 3: User guide extraction

1. Create script for prose documents
2. Preserve section hierarchy
3. Output markdown with YAML frontmatter

### Phase 4: Derived variables extraction

1. Parse calculation logic
2. Link to source variables
3. Output structured YAML

## TODO

- [ ] Create `cchs-extracted/` folder structure
- [ ] Write `extract_data_dictionary.R`
- [ ] Define extraction YAML schema (LinkML)
- [ ] Test on one data dictionary PDF
- [ ] Update catalog schema with `extracted` field
