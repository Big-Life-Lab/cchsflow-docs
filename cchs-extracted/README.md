# Extracted CCHS documentation

Machine-readable extractions from CCHS documentation sources.

## Contents

| Folder | Description | Format |
|--------|-------------|--------|
| `data-dictionary/` | Variable definitions, codes, frequencies | YAML + QMD |
| `user-guide/` | Survey methodology | QMD |
| `derived-variables/` | Calculated variable specs | YAML |
| `questionnaire/` | Survey instruments | QMD |

## Usage

```r
library(yaml)
dd_2023 <- yaml::read_yaml("data-dictionary/2023/cchs_2023s_dd_m_en_1_v1.yaml")

# Access variable information
dd_2023$variables[[1]]$name
dd_2023$variables[[1]]$label
```

## Sources

Extractions come from two sources:

| Source | Content | Script |
|--------|---------|--------|
| PDFs in [`cchs-osf-docs/`](../cchs-osf-docs/) | Master/Share documentation | `scripts/extract_data_dictionary.R` |
| DDI XML from [cchsflow-data](https://github.com/Big-Life-Lab/cchsflow-data) | PUMF variable definitions (ODESSI/Borealis) | `scripts/extract_ddi_from_xml.R` |

Each extracted file includes provenance metadata (`source`, `extraction_method`, `derived_from`) linking back to the original.
