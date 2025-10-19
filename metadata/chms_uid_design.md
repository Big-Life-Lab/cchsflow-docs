# CHMS UID System Design

## Format Specification

```
chms-c{cycle}-{component}-{doc_type}-{language}-{extension}-{seq:02d}
```

### Components

1. **Survey prefix**: `chms` (fixed)
2. **Cycle**: `c1`, `c2`, `c3`, `c4`, `c5`, `c6`
3. **Component**: Document subject area
4. **Doc type**: Document category
5. **Language**: `e` (English), `f` (French)
6. **Extension**: File extension without dot
7. **Sequence**: Two-digit number for multiple versions

## Component Codes

| Code | Name | Description |
|------|------|-------------|
| `gen` | General | User guides, general documentation |
| `hhd` | Household | Household questionnaire |
| `clc` | Clinic | Clinic/physical measures questionnaire |
| `ams` | Activity Monitor | Activity monitor subsample |
| `fast` | Fasting | Fasting subsample |
| `nel` | Nutrition | Nutrition/environmental subsample |
| `med` | Medication | Medication data |
| `inc` | Income | Income-linked data |
| `hcl` | Health Claims | Health claims supplement |

## Document Type Codes

| Code | Name | Example |
|------|------|---------|
| `ug` | User Guide | User guide documentation |
| `qu` | Questionnaire | Survey questionnaire |
| `dd` | Data Dictionary | Data dictionary (rounded or unrounded) |
| `dv` | Derived Variables | Derived variable documentation |

## Examples

### User Guides
- `chms-c1-gen-ug-e-pdf-01` ← CHMS_User_Guide_Cycle1_E.pdf
- `chms-c5-gen-ug-e-pdf-01` ← ug_c5_e_december_2021.pdf

### Questionnaires
- `chms-c1-hhd-qu-e-pdf-01` ← hhld_cycle1_E.pdf
- `chms-c1-clc-qu-e-pdf-01` ← clinic_cycle1_E.pdf
- `chms-c3-hhd-qu-e-pdf-01` ← quest_hhd_c3_e.pdf
- `chms-c4-clc-qu-e-pdf-01` ← quest_clc_c4_e.pdf

### Data Dictionaries (Rounded)
- `chms-c1-ams-dd-e-pdf-01` ← AM_rounded_C1.pdf
- `chms-c1-fast-dd-e-pdf-01` ← Fasted_rounded_C1.pdf
- `chms-c1-hcl-dd-e-pdf-01` ← HCLSup_rounded_C1.pdf
- `chms-c1-med-dd-e-pdf-01` ← Medication_rounded_C1.pdf
- `chms-c3-ams-dd-e-pdf-01` ← rounded_dd_ams_freq_c3_e.pdf
- `chms-c3-clc-dd-e-pdf-01` ← rounded_dd_clc_freq_c3_e.pdf
- `chms-c3-fast-dd-e-pdf-01` ← rounded_dd_fast_freq_c3_e.pdf
- `chms-c3-hhd-dd-e-pdf-01` ← rounded_dd_hhd_freq_c3_e.pdf
- `chms-c3-nel-dd-e-pdf-01` ← rounded_dd_nel_freq_c3_e.pdf

### Data Dictionaries (Unrounded)
- `chms-c3-med-dd-e-pdf-02` ← releasable_unrounded_dd_med_freq_c3_e.pdf (seq=02 for unrounded version)
- `chms-c5-med-dd-e-pdf-01` ← dd_med_freq_c5_E.pdf

### Derived Variables
- `chms-c6-clc-dv-e-pdf-01` ← dv_dhh_clc_c6_e.pdf

## Filename Pattern Recognition

### Original CHMS Naming Patterns

**Pattern 1: Legacy format (Cycles 1-2)**
- `{component}_{rounded}_C{cycle}.pdf`
- `{component}_cycle{cycle}_{language}.pdf`
- Examples: `AM_rounded_C1.pdf`, `hhld_cycle1_E.pdf`

**Pattern 2: Standard format (Cycles 3-6)**
- `rounded_dd_{component}_freq_c{cycle}_{language}.pdf`
- `quest_{component}_c{cycle}_{language}.pdf`
- `dd_{component}_freq_c{cycle}_{language}.pdf` (unrounded)
- `dv_{derived}_c{cycle}_{language}.pdf`
- Examples: `rounded_dd_ams_freq_c3_e.pdf`, `quest_hhd_c4_e.pdf`

**Pattern 3: User guides**
- `CHMS_User_Guide_Cycle{cycle}_{language}.pdf`
- `ug_c{cycle}_{language}_{date}.pdf`

## Component Detection Logic

```r
# Filename → Component mapping
detect_component <- function(filename) {
  filename_lower <- tolower(filename)

  # User guides
  if (grepl("user_guide|^ug_", filename_lower)) return("gen")

  # Household
  if (grepl("hhld|hhd|household", filename_lower)) return("hhd")

  # Clinic
  if (grepl("clinic|clc", filename_lower)) return("clc")

  # Activity Monitor
  if (grepl("^am_|ams|activity", filename_lower)) return("ams")

  # Fasting
  if (grepl("fast", filename_lower)) return("fast")

  # Medication
  if (grepl("med", filename_lower)) return("med")

  # Nutrition/Environmental
  if (grepl("nel|nutrition|environmental", filename_lower)) return("nel")

  # Income
  if (grepl("inc|income", filename_lower)) return("inc")

  # Health Claims
  if (grepl("hcl", filename_lower)) return("hcl")

  return("unknown")
}
```

## UID Assignment Rules

1. **Cycle extraction**: Parse from filename or folder path
2. **Component detection**: Use filename pattern matching
3. **Doc type detection**:
   - User guide: Look for "user_guide" or "ug_"
   - Questionnaire: Look for "quest_" or "cycle{n}_E"
   - Data dictionary: Look for "dd_" or "rounded"
   - Derived variables: Look for "dv_"
4. **Language**: Extract from filename (_E = English, _F = French)
5. **Extension**: Parse from filename
6. **Sequence**: Default to 01; increment for duplicates (e.g., rounded vs unrounded)

## Uniqueness Guarantee

- All 52 CHMS files should have unique UIDs
- Sequence number handles cases like:
  - Rounded vs unrounded data dictionaries for same component
  - Multiple versions of same document type
