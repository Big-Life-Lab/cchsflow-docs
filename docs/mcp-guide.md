# CCHS metadata server: guide

The CCHS metadata MCP server provides 9 tools for querying the Canadian Community Health Survey variable metadata database. This guide walks through common research workflows and provides recipes for specific tasks.

For complete tool specifications, see [mcp-reference.md](mcp-reference.md).

## TL;DR — what can I ask?

The MCP server has metadata for 16,899 CCHS variables across 251 datasets (2001-2022). Ask your LLM agent questions like:

- "Find all smoking cessation variables across all CCHS Master files from 2001 onward"
- "What response categories does SMKDSTY have, and did they change between cycles?"
- "Which alcohol variables are common to both the 2013-2014 and 2015-2016 PUMF?"
- "Show me the question text and universe for GEN_010"
- "Compare DHHGAGE between the PUMF and Share files for 2017-2018"
- "Generate a cchsflow harmonisation row for CCC_101 in the 2011-2012 cycle"
- "How many variables are in the 2022 PUMF?"
- "What modules group the physical activity variables?"

The agent will call the appropriate MCP tools automatically. No tool syntax required — just describe what you need.

## Getting started

### Prerequisites

1. **Database built** — Run `Rscript --vanilla database/build_db.R` to create the DuckDB database from source CSVs and ingestion files (~2 min).
2. **MCP configured** — The server is defined in `.mcp.json` at the repository root. Claude Code and other MCP-compatible clients will discover it automatically.
3. **Python dependencies** — `pip install -r mcp-server/requirements.txt` (fastmcp, duckdb, pandas).

### Your first query

Search for variables related to smoking:

```
search_variables("smoking")
```

Returns a list of matching variables with their names, labels, types, and how many datasets contain them:

```json
[
  {
    "variable_name": "SMK_06B",
    "label": "Stopped smoking-mth (never daily smok.)",
    "type": "Num8",
    "n_datasets": 24,
    "status": "temp"
  },
  {
    "variable_name": "SMK_09B",
    "label": "Stopped smoking daily - month",
    "type": "Num8",
    "n_datasets": 24,
    "status": "temp"
  }
]
```

## Tutorial: exploring a variable

This walkthrough traces the full research path for investigating smoking status across CCHS cycles. Each step uses one MCP tool.

### Step 1: search for the variable

Start with a keyword search. The `search_variables` tool matches against both variable names and labels.

```
search_variables("smoking")
```

This returns variables like `SMK_06B`, `SMK_09B`, `SMKDSTY`, and others. The variable `SMKDSTY` (Type of smoker — derived) appears across 4 PUMF datasets.

### Step 2: get full details

Use `get_variable_detail` to see everything the database knows about a variable:

```
get_variable_detail("SMKDSTY")
```

Key fields in the response:

| Field | Example value |
|-------|---------------|
| `label_statcan` | Type of smoker - (D) |
| `question_text` | Type of smoker - (D) |
| `universe` | All respondents |
| `section` | Health behaviour |
| `cchsflow_name` | SMKDSTY_cat5 |
| `n_datasets` | 4 |

The response also includes the full list of datasets containing this variable, its value codes with frequencies, summary statistics, and module group memberships.

### Step 3: trace across cycles

Use `get_variable_history` to see which cycles contain the variable:

```
get_variable_history("SMKDSTY")
```

```json
[
  {
    "variable_name": "SMKDSTY",
    "dataset_id": "cchs-2007d-p-can",
    "year_start": 2007,
    "year_end": 2008,
    "release": "pumf",
    "sources": "['ddi_xml' 'pumf_rdata']"
  },
  {
    "dataset_id": "cchs-2009d-p-can",
    "year_start": 2009,
    "year_end": 2010
  },
  {
    "dataset_id": "cchs-2011d-p-can",
    "year_start": 2011,
    "year_end": 2012
  },
  {
    "dataset_id": "cchs-2013d-p-can",
    "year_start": 2013,
    "year_end": 2014
  }
]
```

SMKDSTY appears in four consecutive dual-year PUMF cycles (2007-2014). It is not present in earlier or later PUMF files — the derived variable naming changed over time.

### Step 4: check response categories

Use `get_value_codes` to see valid codes and their weighted frequencies:

```
get_value_codes("SMKDSTY")
```

```json
{
  "variable_name": "SMKDSTY",
  "latest_dataset": "cchs-2013d-p-can",
  "codes": [
    {"code": "1", "label": "DAILY", "frequency": 18413, "frequency_weighted": 4147683.12},
    {"code": "2", "label": "OCCASIONAL", "frequency": 3135, "frequency_weighted": 813707.2},
    {"code": "3", "label": "ALWAYS OCCASIONALLY", "frequency": 1985, "frequency_weighted": 602006.02},
    {"code": "4", "label": "FORMER DAILY", "frequency": 34381, "frequency_weighted": 6626745.17},
    {"code": "5", "label": "FORMER OCCASIONAL", "frequency": 19197, "frequency_weighted": 4511750.99},
    {"code": "6", "label": "NEVER SMOKED", "frequency": 49385, "frequency_weighted": 13099102.14},
    {"code": "96", "label": "NOT APPLICABLE"},
    {"code": "97", "label": "DON'T KNOW"},
    {"code": "98", "label": "REFUSAL"},
    {"code": "99", "label": "NOT STATED", "frequency": 966, "frequency_weighted": 201822.36}
  ]
}
```

Codes 96-99 are standard CCHS special codes (not applicable, don't know, refusal, not stated). These should be handled as missing values in analysis.

### Step 5: compare file types within a cycle

Use `compare_master_pumf` to see whether a variable differs between PUMF, Share, and Master releases for a given cycle:

```
compare_master_pumf("SMKDSTY", "2013-2014")
```

```json
{
  "variable_name": "SMKDSTY",
  "cycle": "2013-2014",
  "releases_found": ["pumf"],
  "comparisons": [
    {
      "dataset_id": "cchs-2013d-p-can",
      "release": "pumf",
      "label": "Type of smoker - (D)",
      "type": "numeric",
      "intrvl": "discrete",
      "sources": ["ddi_xml", "pumf_rdata"],
      "value_codes": [...]
    }
  ]
}
```

In this case only the PUMF release is in the database for this variable. When both PUMF and Share/Master are present, this tool shows whether response categories or labels differ between releases.

## How-to recipes

### Find all variables in a module

CCHS organises variables into subject modules (e.g., SMK for smoking, ALC for alcohol). Search by the module prefix:

```
search_variables("SMK_")
```

Or search by subject keyword:

```
search_variables("alcohol")
```

### List variables in a specific dataset

Get the full variable list for any dataset by its canonical ID:

```
get_dataset_variables("cchs-2015d-p-can", limit=20)
```

```json
{
  "dataset_id": "cchs-2015d-p-can",
  "n_variables": 20,
  "variables": [
    {
      "variable_name": "ACCG030M",
      "label": "Difficulty surgery - unable to leave the house/other",
      "type": "haven_labelled",
      "sources": "['ddi_xml' 'pumf_rdata']"
    }
  ]
}
```

Use a higher `limit` to retrieve more variables (the 2015-2016 PUMF has 1,283 variables total).

### Compare variables across two datasets

Find which variables are shared between two cycles:

```
get_common_variables("cchs-2013d-p-can", "cchs-2015d-p-can")
```

This returns the full list of shared variable names with labels and types. The 2013 and 2015 PUMF datasets share approximately 800 variables.

### Check if a variable exists in a specific cycle

Use `get_variable_history` and look for the target cycle in the results:

```
get_variable_history("GEN_010")
```

If the cycle's dataset appears in the results, the variable is present. If not, the variable was not included in that cycle's PUMF or the naming changed.

### Generate a cchsflow harmonisation row

The `suggest_cchsflow_row` tool drafts a worksheet row for the [cchsflow R package](https://github.com/Big-Life-Lab/cchsflow), which harmonises CCHS variables across cycles:

```
suggest_cchsflow_row("GEN_010", "2015-2016")
```

```json
{
  "variable_name": "GEN_010",
  "target_cycle": "2015-2016",
  "available_in_cycle": true,
  "label": "Satisfaction with life in general",
  "question_text": "Using a scale of 0 to 10, where 0 means \"Very dissatisfied\" and 10 means \"Very satisfied\", how do you feel about your life as a whole right now?",
  "cchsflow_name": "GEN_02A2",
  "suggested_row": {
    "variable": "GEN_010",
    "databaseStart": "cchs-2015d-p-can",
    "variableStart": "GEN_010",
    "variableStartLabel": "Satisfaction with life in general",
    "rec_from": "copy",
    "rec_to": "GEN_02A2",
    "note": "Auto-suggested for cycle 2015-2016. Review before use."
  }
}
```

The `suggested_row` object follows cchsflow's worksheet format. Always review before using — the tool suggests a starting point, not a validated mapping.

### Get database overview

```
get_database_summary()
```

Returns counts of variables (16,899 total, 6,429 active), datasets (251), value codes (145,910), and a breakdown by data source and PUMF national dataset. Useful for verifying the database is built and understanding its scope.

## Tips

### Dataset ID conventions

Dataset IDs follow the pattern `cchs-{year}{temporal}-{release}-{geography}`:

| Component | Values | Example |
|-----------|--------|---------|
| Year | 2001-2022 | `2015` |
| Temporal | `s` (single), `d` (dual) | `d` |
| Release | `p` (PUMF), `s` (Share), `m` (Master), `l` (Linked) | `p` |
| Geography | `can` (national), `ont` (Ontario), etc. | `can` |

Example: `cchs-2015d-p-can` = 2015-2016 dual-year PUMF, national file.

### Alias resolution

Some tools accept dataset aliases (e.g., `CCHS201516_ONT_SHARE`) and resolve them to the canonical ID. The canonical form is always returned in the response.

### Variable naming patterns

CCHS variable names encode their module and question number:

- `SMK_` — Smoking module
- `ALC_` — Alcohol module
- `GEN_` — General health
- `CCC_` — Chronic conditions
- `DHH` — Demographics/household
- `DHHGAGE` — Derived: age group

Derived variables (calculated from other responses) typically have a `D` suffix or appear in the "Derived variables" section.

### Data sources and provenance

Each variable-dataset link tracks which sources attest it. Common sources:

| Source | Authority | Content |
|--------|-----------|---------|
| `ddi_xml` | Primary | Question text, value codes, frequencies, summary stats |
| `pumf_rdata` | Primary | Variable types, value labels from data files |
| `master_sas_label` | Primary | Master file variable labels from SAS |
| `cchsflow` | Secondary | Harmonisation mappings |
| `ices_scrape` | Secondary | ICES Data Dictionary labels |
| `yaml_extract` | Secondary | Extracted YAML data dictionaries |

Primary sources (Statistics Canada documentation) are preferred over secondary sources when conflicts exist.

### Special codes

Most CCHS variables use these standard special codes:

| Code | Meaning |
|------|---------|
| 6 / 96 | Valid skip (not applicable) |
| 7 / 97 | Don't know |
| 8 / 98 | Refusal |
| 9 / 99 | Not stated |

The exact codes depend on the variable's range. Single-digit variables use 6-9; two-digit variables use 96-99; three-digit variables use 996-999.
