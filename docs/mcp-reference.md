# CCHS metadata server: tool reference

Complete reference for the 10 MCP tools provided by the CCHS metadata server (`mcp-server/server.py`). For tutorials and workflow examples, see [mcp-guide.md](mcp-guide.md).

The server queries a unified DuckDB database containing 16,963 variables across 253 datasets from 8 data sources spanning CCHS cycles 2001-2023.

---

## search_variables

Search for variables by name or label.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `query` | string | *required* | Search term matched against variable_name and label |
| `limit` | integer | 20 | Maximum results to return |

### Returns

Array of matching variables:

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Unique variable identifier (e.g., `SMKDSTY`) |
| `label` | string | Short descriptive label |
| `type` | string | Data type (`Num8`, `Char`, `haven_labelled`) |
| `n_datasets` | integer | Number of datasets containing this variable |
| `status` | string | `active` or `temp` |

### Example

```
search_variables("blood pressure")
```

```json
[
  {
    "variable_name": "BPC_010",
    "label": "Ever had blood pressure taken",
    "type": "Num8",
    "n_datasets": 7,
    "status": "active"
  },
  {
    "variable_name": "DOBPC",
    "label": "Module: BPC - (F)",
    "type": "Num8",
    "n_datasets": 6,
    "status": "active"
  },
  {
    "variable_name": "CCC_071",
    "label": "Hypertension",
    "type": "Num8",
    "n_datasets": 4,
    "status": "active"
  }
]
```

### Notes

- Search matches both variable names and labels using case-insensitive substring matching.
- Use module prefixes (e.g., `SMK_`, `ALC_`) to find variables within a subject area.
- Results are sorted by relevance.

---

## get_variable_detail

Get full metadata for a specific variable, including question text, response categories, and availability across all datasets.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | *required* | Exact variable name (e.g., `SMKDSTY`, `DHHGAGE`) |

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `label_short` | string | Short label |
| `label_long` | string | Extended description |
| `label_statcan` | string | Statistics Canada label |
| `type` | string | Data type |
| `value_format` | string | ICES format name for value codes |
| `question_text` | string | Survey question wording (from DDI) |
| `universe` | string | Target population (e.g., "All respondents") |
| `section` | string | Thematic section (e.g., "Health behaviour") |
| `subject` | string | Subject area (e.g., "Smoking") |
| `cchsflow_name` | string | Harmonised name in cchsflow package |
| `n_datasets` | integer | Number of datasets containing this variable |
| `n_primary_sources` | integer | Number of primary sources attesting this variable |
| `status` | string | `active` or `temp` |
| `datasets` | array | Per-dataset metadata (see below) |
| `value_codes` | array | Response categories with frequencies |
| `summary_stats` | object | Distributional statistics (mean, median, stdev, min, max) |
| `module_groups` | array | Module group memberships (code and label) |

**datasets array elements:**

| Field | Type | Description |
|-------|------|-------------|
| `dataset_id` | string | Canonical dataset identifier |
| `label` | string | Variable label in this dataset |
| `type` | string | Data type in this dataset |
| `year_start` | integer | Survey start year |
| `year_end` | integer | Survey end year |
| `temporal_type` | string | `single`, `dual`, or `multi` |
| `release` | string | `pumf`, `share`, `master`, `linked`, `income` |
| `dataset_label` | string | Label from the dataset source |
| `question_text` | string | Question text specific to this dataset |
| `sources` | string | Data sources attesting this link |

### Example

```
get_variable_detail("SMKDSTY")
```

Response includes label fields, question text, 12 datasets (2003-2014 PUMF and Master cycles), 10 value codes with weighted frequencies, summary statistics from the 2013 cycle, and module group memberships (SMK: Smoking, SMO: Smoking During Pregnancy).

### Notes

- The `question_text` field may be `NaN` for cycles that lack DDI question text (notably 2009-2010).
- The `sources` field is a string representation of an array (e.g., `"['ddi_xml' 'pumf_rdata']"`).
- Value codes and summary stats come from the latest available cycle with DDI data.

---

## get_variable_history

Trace a variable across all CCHS cycles and datasets. Shows which cycles and file types contain this variable.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | *required* | Exact variable name (e.g., `SMKDSTY`) |

### Returns

Array of dataset appearances, sorted chronologically:

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `label` | string | Variable label |
| `dataset_id` | string | Canonical dataset identifier |
| `year_start` | integer | Survey start year |
| `year_end` | integer | Survey end year |
| `temporal_type` | string | `single`, `dual`, or `multi` |
| `release` | string | File release type |
| `dataset_label` | string | Label from the dataset source |
| `question_text` | string | Question text (may be `NaN`) |
| `type` | string | Data type |
| `sources` | string | Attesting data sources |

### Example

```
get_variable_history("SMKDSTY")
```

```json
[
  {
    "variable_name": "SMKDSTY",
    "label": "Smoking status",
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

### Notes

- A variable may appear in different release types (PUMF, Share, Master) across cycles.
- An empty result means the variable is registered but not linked to any dataset in the database.
- Gaps in the history may indicate variable renaming across cycles, not necessarily that the concept was dropped.

---

## get_dataset_variables

List all variables in a specific dataset.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `dataset_id` | string | *required* | Dataset identifier (e.g., `cchs-2015d-p-can`) |
| `limit` | integer | 100 | Maximum results to return |

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `dataset_id` | string | Canonical dataset ID (after alias resolution) |
| `resolved_from` | string or null | Original alias if resolved, otherwise null |
| `n_variables` | integer | Number of variables returned |
| `variables` | array | Variable list (see below) |

**variables array elements:**

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `label` | string | Short label |
| `type` | string | Data type |
| `subject` | string or null | Subject area |
| `section` | string or null | Thematic section |
| `position` | integer or null | Position in the data file |
| `sources` | string | Attesting data sources |

### Example

```
get_dataset_variables("cchs-2015d-p-can", limit=5)
```

```json
{
  "dataset_id": "cchs-2015d-p-can",
  "resolved_from": null,
  "n_variables": 5,
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

### Notes

- Accepts dataset aliases (e.g., `CCHS201516_ONT_SHARE`), which are resolved to canonical IDs. The `resolved_from` field shows the alias used.
- Set `limit` to a large number (e.g., 2000) to retrieve the full variable list for a dataset. The 2005 PUMF has the most variables at 1,284.

---

## get_common_variables

Find variables shared between two datasets.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `dataset_id_1` | string | *required* | First dataset identifier |
| `dataset_id_2` | string | *required* | Second dataset identifier |

### Returns

Array of shared variables with name, label, and type. Consecutive PUMF national datasets typically share 700-900 variables.

### Example

```
get_common_variables("cchs-2013d-p-can", "cchs-2015d-p-can")
```

Returns approximately 800 shared variables between the 2013-2014 and 2015-2016 PUMF national files.

### Notes

- The response can be large for datasets with many shared variables. Results are not paginated.
- Variables are matched by exact name. Variables that measure the same concept but were renamed between cycles will not appear as common.

---

## compare_master_pumf

Compare a variable between different file types (Share, PUMF, Linked) for a given cycle.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | *required* | Exact variable name |
| `cycle` | string | *required* | Cycle year(s) (e.g., `2015-2016` or `2015`) |

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `cycle` | string | Cycle searched |
| `releases_found` | array | Release types found (e.g., `["pumf", "share"]`) |
| `comparisons` | array | Per-release details (see below) |

**comparisons array elements:**

| Field | Type | Description |
|-------|------|-------------|
| `dataset_id` | string | Canonical dataset ID |
| `release` | string | Release type |
| `label` | string | Variable label in this release |
| `type` | string | Data type |
| `question_text` | string | Question wording |
| `intrvl` | string | Measurement level (`discrete` or `contin`) |
| `sources` | array | Attesting data sources |
| `value_codes` | array | Response categories with frequencies |

### Example

```
compare_master_pumf("SMKDSTY", "2013-2014")
```

```json
{
  "variable_name": "SMKDSTY",
  "cycle": "2013-2014",
  "releases_found": ["master", "pumf"],
  "comparisons": [
    {
      "dataset_id": "cchs-2013d-m-can",
      "release": "master",
      "label": "Type of smoker - (D)",
      "sources": ["613apps"],
      "value_codes": [
        {"code": "1", "label": "DAILY"},
        {"code": "2", "label": "OCCASIONAL"},
        {"code": "6", "label": "NEVER SMOKED"}
      ]
    },
    {
      "dataset_id": "cchs-2013d-p-can",
      "release": "pumf",
      "label": "Type of smoker - (D)",
      "type": "numeric",
      "intrvl": "discrete",
      "sources": ["613apps", "ddi_xml", "pumf_rdata"],
      "value_codes": [
        {"code": "1", "label": "DAILY", "frequency": 18413},
        {"code": "2", "label": "OCCASIONAL", "frequency": 3135},
        {"code": "6", "label": "NEVER SMOKED", "frequency": 49385}
      ]
    }
  ]
}
```

### Notes

- The cycle parameter matches against the dataset's year range. Use the dual-year format (e.g., `2013-2014`) for dual-year cycles.
- This tool is most useful when both PUMF and Share/Master releases are present — it reveals differences in variable coding or category collapsing applied for privacy protection.
- If only one release type is in the database, the comparison still returns that release's full details.

---

## get_value_codes

Get response categories and value codes for a variable. Checks both the ICES value formats table and DDI categories.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | *required* | Exact variable name |

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `ices_format_name` | string | ICES value format name |
| `latest_cycle_year` | integer | Year of the latest cycle with codes |
| `latest_dataset` | string | Dataset ID for the latest codes |
| `codes` | array | Value codes (see below) |
| `n_datasets_with_codes` | integer | Number of datasets with value codes |

**codes array elements:**

| Field | Type | Description |
|-------|------|-------------|
| `code` | string | Numeric code |
| `label` | string | Code label (e.g., `DAILY`, `NEVER SMOKED`) |
| `frequency` | integer | Unweighted count |
| `frequency_weighted` | number | Survey-weighted count |

### Example

```
get_value_codes("SMKDSTY")
```

```json
{
  "variable_name": "SMKDSTY",
  "ices_format_name": "CCHS2014_ONT_SHARE_SMCDTYP",
  "latest_dataset": "cchs-2013d-p-can",
  "codes": [
    {"code": "1", "label": "DAILY", "frequency": 18413, "frequency_weighted": 4147683.12},
    {"code": "2", "label": "OCCASIONAL", "frequency": 3135, "frequency_weighted": 813707.2},
    {"code": "3", "label": "ALWAYS OCCASIONALLY", "frequency": 1985, "frequency_weighted": 602006.02},
    {"code": "4", "label": "FORMER DAILY", "frequency": 34381, "frequency_weighted": 6626745.17},
    {"code": "5", "label": "FORMER OCCASIONAL", "frequency": 19197, "frequency_weighted": 4511750.99},
    {"code": "6", "label": "NEVER SMOKED", "frequency": 49385, "frequency_weighted": 13099102.14},
    {"code": "96", "label": "NOT APPLICABLE", "frequency": 0},
    {"code": "97", "label": "DON'T KNOW", "frequency": 0},
    {"code": "98", "label": "REFUSAL", "frequency": 0},
    {"code": "99", "label": "NOT STATED", "frequency": 966, "frequency_weighted": 201822.36}
  ],
  "n_datasets_with_codes": 4
}
```

### Notes

- Codes come from the latest available cycle with DDI data.
- Frequencies and weighted frequencies are from the PUMF file for that cycle.
- Codes 96-99 (or 6-9, 996-999 depending on the variable range) are standard CCHS special codes for not applicable, don't know, refusal, and not stated.
- The `ices_format_name` links to the ICES Data Dictionary value format table if available.

---

## suggest_cchsflow_row

Generate a draft cchsflow worksheet row for a variable in a target cycle. Used to prepare variable harmonisation mappings for the [cchsflow R package](https://github.com/Big-Life-Lab/cchsflow).

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | *required* | Variable to harmonise |
| `target_cycle` | string | *required* | Cycle to generate the row for (e.g., `2015-2016`) |

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `variable_name` | string | Variable identifier |
| `target_cycle` | string | Cycle searched |
| `available_in_cycle` | boolean | Whether the variable exists in the target cycle |
| `label` | string | Variable label |
| `type` | string | Data type |
| `question_text` | string | Question wording |
| `cchsflow_name` | string | Harmonised target name |
| `datasets_in_cycle` | array | Matching datasets (if available) |
| `value_codes` | array | Response categories (if available) |
| `suggested_row` | object | Draft cchsflow worksheet row (if available) |

**suggested_row fields:**

| Field | Type | Description |
|-------|------|-------------|
| `variable` | string | Source variable name |
| `databaseStart` | string | Dataset ID |
| `variableStart` | string | Variable name in this dataset |
| `variableStartLabel` | string | Label in this dataset |
| `rec_from` | string | Recoding instruction (`copy` or transformation) |
| `rec_to` | string | Target harmonised variable name |
| `note` | string | Auto-generated note |

### Example

```
suggest_cchsflow_row("GEN_010", "2015-2016")
```

```json
{
  "variable_name": "GEN_010",
  "target_cycle": "2015-2016",
  "available_in_cycle": true,
  "label": "Life satisfaction_cont",
  "question_text": "Using a scale of 0 to 10, where 0 means \"Very dissatisfied\" and 10 means \"Very satisfied\", how do you feel about your life as a whole right now?",
  "cchsflow_name": "GEN_02A2",
  "suggested_row": {
    "variable": "GEN_010",
    "databaseStart": "cchs-2015d-p-can",
    "variableStart": "GEN_010",
    "variableStartLabel": "Life satisfaction_cont",
    "rec_from": "copy",
    "rec_to": "GEN_02A2",
    "note": "Auto-suggested for cycle 2015-2016. Review before use."
  }
}
```

### Notes

- When `available_in_cycle` is `false`, the variable was not found in any dataset for that cycle. This may mean it was renamed or dropped.
- The `suggested_row` is a starting point. Always review the recoding logic before adding to cchsflow worksheets.
- The `rec_from` field defaults to `copy` when no transformation is needed. Complex recodings require manual specification.

---

## get_source_conflicts

Find label disagreements between data sources for a variable or dataset. Useful for auditing metadata quality and identifying where sources provide different labels for the same variable.

### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | `null` | Optional variable name filter |
| `dataset_id` | string | `null` | Optional dataset ID filter |

### Returns

Without filters, returns summary counts:

| Field | Type | Description |
|-------|------|-------------|
| `total_label_conflicts` | integer | Total variable-dataset label disagreements |
| `total_value_code_conflicts` | integer | Total value code label disagreements |
| `label_conflict_sources` | array | Breakdown by source pair with counts |
| `n_label_conflicts` | integer | Same as total (for consistency) |
| `n_value_code_conflicts` | integer | Same as total (for consistency) |

With filters, returns detailed conflict rows:

| Field | Type | Description |
|-------|------|-------------|
| `label_conflicts` | array | Each row: variable_name, dataset_id, source_a, label_a, source_b, label_b |
| `value_code_conflicts` | array | Each row: variable_name, dataset_id, code, source_a, label_a, source_b, label_b |

### Example

```
get_source_conflicts(variable_name="SMKDSTY")
```

### Notes

- Conflicts are pairwise: if three sources disagree, you'll see up to three conflict rows (A vs B, A vs C, B vs C).
- Most conflicts are cosmetic (encoding differences, abbreviation styles). The text normalisation pipeline reduces but does not eliminate these.
- Use with `variable_name` to audit a specific variable, or with `dataset_id` to audit an entire dataset.

---

## get_database_summary

Get high-level summary statistics for the CCHS metadata database.

### Parameters

None.

### Returns

| Field | Type | Description |
|-------|------|-------------|
| `total_variables` | integer | Total variable count |
| `active_variables` | integer | Variables with `active` status |
| `total_datasets` | integer | Total dataset count |
| `total_variable_dataset_links` | integer | Variable-dataset pairs |
| `total_value_codes` | integer | Total response category entries |
| `total_summary_stats` | integer | Variables with distributional statistics |
| `total_variable_groups` | integer | Module group count |
| `total_group_memberships` | integer | Variable-to-group links |
| `sources` | array | Data source details (id, name, authority, file count) |
| `pumf_national_datasets` | array | PUMF national datasets with year range and variable count |
| `dataset_releases` | array | Count of datasets by release type |
| `catalog_metadata` | object | Schema version, build date, R version |

### Example

```
get_database_summary()
```

```json
{
  "total_variables": 16963,
  "active_variables": 7011,
  "total_datasets": 253,
  "total_variable_dataset_links": 79251,
  "total_value_codes": 532215,
  "sources": [
    {"source_id": "ddi_xml", "source_name": "CCHS DDI XML documentation", "authority": "primary", "n_files": 11},
    {"source_id": "master_pdf_dd", "source_name": "CCHS Master PDF Data Dictionary", "authority": "primary", "n_files": 2},
    {"source_id": "master_sas_label", "source_name": "CCHS Master SAS English label files", "authority": "primary", "n_files": 35},
    {"source_id": "pumf_rdata", "source_name": "CCHS PUMF RData files", "authority": "primary", "n_files": 11},
    {"source_id": "613apps", "source_name": "613apps.ca CCHS Data Dictionary", "authority": "secondary", "n_files": 24},
    {"source_id": "cchsflow", "authority": "secondary", "n_files": 2},
    {"source_id": "ices_scrape", "authority": "secondary", "n_files": 1},
    {"source_id": "yaml_extract", "authority": "secondary", "n_files": 42}
  ],
  "pumf_national_datasets": [
    {"dataset_id": "cchs-2001d-p-can", "year_start": 2000, "year_end": 2001, "n_variables": 614},
    {"dataset_id": "cchs-2003d-p-can", "year_start": 2003, "n_variables": 1068},
    {"dataset_id": "cchs-2022s-p-can", "year_start": 2022, "n_variables": 255}
  ],
  "catalog_metadata": {
    "schema_version": "2.0.0",
    "build_date": "2026-02-22"
  }
}
```

### Notes

- Use this tool to verify the database is built and to understand its scope before querying.
- The `active_variables` count (7,011) is a subset of `total_variables` (16,963). Many variables have `temp` status, meaning they appear in metadata but have limited documentation.
- The `pumf_national_datasets` array lists only PUMF national files. Share, Master, Linked, and Income datasets are counted in `dataset_releases` but not listed individually.
