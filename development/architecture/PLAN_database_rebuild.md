# Plan: Rebuild CCHS metadata database from primary sources

## Context

The current unified DuckDB was built on the ICES Data Dictionary scrape as its foundation, with DDI XML bolted on as enrichment. A quality audit revealed serious validity problems: broken joins between sources (8 of 11 DDI files can't join), 1,402 invisible PUMF variables, ICES-specific abbreviated labels, and no provenance tracking.

The rebuild starts from two tier-1 primary sources (PUMF RData + DDI XML), uses the existing catalog and LinkML schemas to define the database structure, and is designed to extend to Master/Share/ICES data later — with every record tracking its source.

## Data sources (tiered)

**Tier 1 — rebuild foundation (this phase):**

| Source | Location | Files | Content |
|--------|----------|-------|---------|
| ICES scrape | `cchsflow-docs/data/ices_cchs_dictionary.duckdb` | 1 | 231 dataset IDs, 14,005 variables, 118K availability rows — seeds the `datasets` table with all known file releases |
| PUMF RData | `cchsflow-data/data/sources/rdata/` | 11 | Ground truth for national PUMF: variable names, types, haven labels, factor levels |
| DDI XML | `cchsflow-data/ddi/` | 11 | Labels, question text, universe, response categories for national PUMF |

PUMF RData and DDI XML are 1:1 aligned by cycle (2001, 2003, 2005, 2007-2008, 2009-2010, 2011-2012, 2013-2014, 2015-2016, 2017-2018, 2019-2020, 2022).

The ICES scrape provides broad coverage of all CCHS file types (PUMF, Master, Share, Linked, Bootstrap) but with abbreviated labels and no question text. RData + DDI provide deep metadata but only for national PUMF. Together: broad dataset coverage + deep PUMF metadata.

**Tier 2 — future extension (design for, don't populate yet):**

| Source | Location | Content |
|--------|----------|---------|
| Extracted YAML (Master) | `cchsflow-docs/cchs-extracted/data-dictionary/` | 21 Master + 18 PUMF from PDF extraction |
| Extracted YAML (Share) | same | 3 Share data dictionaries |

## Existing schemas informing this design

Three LinkML schemas already exist. The DuckDB schema extends them — it must capture attributes that no single LinkML schema covers today. The enums and descriptions below serve as the reference for future LinkML harmonisation.

1. **`metadata/health_survey_schema_linkml.yaml`** (v4.0.0) — Documentation catalog
   - `cchs_uid` pattern: `cchs-{year}{temporal}-{doc_type}-{category}-...`
   - `TemporalTypeEnum`: single, dual, multi
   - `DocTypeEnum`: master, share, pumf
   - No content type (general vs nutrition vs mental-health)
   - No geography enum
   - No linked or income release types

2. **`cchsflow-data/schema/cchs_data_schema.yaml`** (v0.1.0) — Data file catalog
   - `survey_year_start`, `survey_year_end`, `temporal_type`
   - `TemporalTypeEnum`: annual, biannual, multi-cycle (**different terms** from schema 1)
   - `FileTypeEnum`: pumf, bootstrap_weights, documentation, syntax
   - `cycle_name` as free text (e.g., "CCHS Cycle 1.1") — no enum
   - No content type or geography

3. **`metadata/ices_data_dictionary_schema.yaml`** (v1.0.0) — ICES scrape schema
   - Raw `dataset_id` (e.g., `CCHS2009_ONT_SHARE`) — no parsing, no enums
   - `ValueFormat` + `ValueCode` for response categories

**Gaps across all three schemas** (discovered by parsing the 231 ICES dataset IDs):

| Attribute | Existing coverage | Gap |
|-----------|------------------|-----|
| Release type | `DocTypeEnum`: master, share, pumf | Missing: linked (38 datasets), income (15 datasets) |
| Content type | None | 4 content types: general, nutrition, mental-health, healthy-aging |
| Geography | None | Ontario (181 datasets) vs Canada (50 datasets) |
| Cycle number | Free text `cycle_name` in data schema only | Early cycles (1.1, 1.2, 2.1, 2.2, 3.1) need structured representation |
| Subfile type | `bootstrap_weights` in data schema | 26 subfile types (household, lhin, level1, cognition, pb, ikn, nutrition subfiles, etc.) |
| Temporal terminology | Two conflicting sets: single/dual/multi vs annual/biannual/multi-cycle | Needs harmonisation |

The DuckDB schema uses the `single/dual/multi` convention (matching the documentation catalog schema) as the canonical form.

## Key design decisions

### 1. Canonical dataset naming

Canonical dataset IDs use a human-readable pattern: `cchs-{year}{s|d}-{release}-{geo}[-{content}][-{subfile}]`

- `{year}` = `year_start` (4 digits)
- `{s|d}` = `s` for single-year, `d` for dual-year
- `{release}` = `p` (pumf), `m` (master), `s` (share), `l` (linked), `inc` (income)
- `{geo}` = `can` (Canada), `ont` (Ontario) — always explicit
- `{content}` = omitted for general; `nut` (nutrition), `mh` (mental health), `ha` (healthy aging)
- `{subfile}` = `boot`, `hh`, `lhin`, etc. (omitted for primary files); compound subfiles use `.` separator (e.g., `boot.hh`)

The early CCHS cycle number (e.g., 1.1, 2.2) is stored as a **metadata column** (`cycle`) on the `datasets` table but is NOT part of the canonical ID. The year + content type already disambiguate: 2004 + nutrition = cycle 2.2.

Examples:
- **`cchs-2001s-p-can`** — 2001 single-year PUMF, Canada
- **`cchs-2001s-s-ont`** — 2001 single-year Ontario Share
- **`cchs-2004s-s-can-nut`** — 2004 nutrition Share, Canada (cycle 2.2 in metadata)
- **`cchs-2007d-s-ont-boot`** — 2007-2008 Ontario Share bootstrap weights
- **`cchs-2007d-s-ont-boot.hh`** — 2007-2008 Ontario Share bootstrap + household weights
- **`cchs-2008d-m-can-ha`** — 2008-2009 Healthy Aging Master, Canada
- **`cchs-2002s-s-ont-mh`** — 2002 Mental Health Ontario Share (cycle 1.2)
- **`cchs-2012s-m-can-mh`** — 2012 Mental Health Master, Canada

Each dataset in the DB gets a canonical name, plus an `aliases` list for all other names from different sources.

Alias example for 2007-2008 PUMF:
- **Canonical**: `cchs-2007d-p-can`
- **Alias**: `CCHS_2007_2008` (source: pumf_rdata)
- **Alias**: `CCHS_2007_2008_DDI` (source: ddi_xml)
- **Alias**: `CCHS200708_PUMF` (source: ices_scrape)

### 2. Variables are one-row-per-unique-name

The variable name IS the unique identifier. A variable's name changes when its structure changes — so each unique variable name gets exactly one row in the `variables` table with its canonical metadata (latest label, type, subject, section).

A separate **`variable_datasets`** linking table records which datasets contain each variable, with per-dataset specifics (position, length, source provenance). This makes it easy to query "where does SMKDSTY appear?" without duplicating the variable's core identity.

### 3. Cross-cycle variable linking via cchsflow

Early CCHS cycles used a cycle letter in variable names (A=2001, B/C=2003, E=2005, etc.). For example, GEOA_PRV, GEOB_PRV, GEOC_PRV are structurally identical — they are Province of residence, differing only by cycle letter. The cchsflow R package already maintains these mappings in `variables.csv`.

Rather than a separate family table, we add a **`cchsflow_name`** column directly on the `variables` table. This is the harmonised variable name from cchsflow (e.g., `ADL_01` for `RACA_6A`, `RACC_6A`, etc.; `GEO_PRV` for `GEOA_PRV`, `GEOB_PRV`, etc.). Querying cross-cycle equivalents is then just `WHERE cchsflow_name = 'GEO_PRV'`.

For variables that kept the same name across cycles (like SMKDSTY), the `cchsflow_name` matches `variable_name`. For variables not in cchsflow, it's NULL.

### 4. Full provenance — every reference kept, never collapsed

Every record keeps an explicit list of its sources. The `variable_datasets` table is keyed by `(variable_name, dataset_id, document_id)` — so if both the RData file and the DDI XML describe the same variable in the same dataset, they get separate rows, each carrying their own metadata and value codes. We never collapse to `source='both'`.

For value codes specifically: each `variable_datasets` row has its own `value_codes` LIST. If RData says code `1 = "Yes"` and DDI also says code `1 = "YES"`, both are preserved — the RData row carries RData factor levels with frequencies, the DDI row carries DDI categories with DDI frequencies. This makes disagreements visible and makes it trivial to query "what does this document say about this variable?"

### 5. Documents table — the catalog in DuckDB

The existing catalog (`data/catalog/cchs_catalog.yaml`, 1,421 entries) is loaded into a `documents` table. Each document has a `cchs_uid` (e.g., `cchs-2001s-m-dd-e-pdf-01`), category, language, checksum, etc. This becomes the provenance backbone: the `variable_datasets` table references `document_id`, and the `datasets` and `variables` tables carry `source_documents` lists. Every piece of metadata traces back to a specific cataloged document.

For data sources not yet in the catalog (like RData files and DDI XML from cchsflow-data), we create document entries during ingestion. These could later be added to the catalog proper.

### 6. Three-label model

StatCan labels are inconsistent across cycles and sources. For DHHGAGE: "Age - (G)" (2007 DDI), "Age" (2015 DDI), "Age - Grouped" (2019 DDI), "Age" (2015 RData haven label). The `(G)` and `(D)` suffixes are StatCan conventions meaning "Grouped" and "Derived" but they're applied inconsistently.

The `variables` table carries three labels:

- **`label_statcan`** — the original StatCan label, preserved as-is from the latest cycle's DDI or RData haven attribute. Never modified. For provenance and fidelity.
- **`label_short`** — a concise label (≤40 chars) following CCHS conventions, suitable for table headers and search results. E.g., "Type of smoker (D)", "Age (G)", "Province of residence".
- **`label_long`** — full descriptive label. E.g., "Type of smoker - derived variable", "Age - grouped", "Province of residence of respondent".

The per-cycle StatCan label is also preserved on each `variable_datasets` row (the `label` column), since labels do change between cycles.

Initial population: `label_statcan` from latest DDI/RData. `label_short` and `label_long` initially copied from `label_statcan`, to be improved over time (manually, via LLM batch processing, or from cchsflow's label/labelLong columns where available).

### 7. Value format types and missing data classification

The ICES scrape assigns a `format` name to each variable (e.g., `CCHS_YESNOFM` for Yes/No variables, `CCHS_AGREEFM` for Likert scales, `CCHS_AGE3DFM` for age groups). Over 5,000 variables share `CCHS_YESNOFM`. This tells you the type of response coding without examining every code. Stored as `value_format` on `variables`.

The CCHS uses a systematic missing data convention across all variables:
- **6** = Valid skip / Not applicable (structural — question didn't apply to respondent)
- **7** = Don't know (respondent non-response)
- **8** = Refusal (respondent non-response)
- **9** = Not stated (data processing)

For multi-digit variables, the pattern extends: 96/97/98/99, 996/997/998/999, 9.996/9.997/9.998/9.999, etc. Each value code in the `value_codes` LIST carries an `is_missing` flag, inferred during ingestion from the label text (matching patterns like "Valid skip", "Don't know", "Refusal", "Not stated", "Not applicable").

### 8. Explicit temporal and geographic model

Datasets have `year_start`, `year_end`, `temporal_type` columns matching the catalog schemas. Single-year Master (2007/2007/single) can coexist with dual-year PUMF (2007/2008/dual) for the same period.

The `geo` column distinguishes national files (`'can'`) from provincial subsets (`'ont'`). All 11 tier-1 PUMF files are national, so `geo='can'` for those. The ICES scrape datasets include Ontario Share and Linked files, so `geo` becomes meaningful when those are loaded. Keeping `geo` from the start avoids a schema migration later.

### 9. Content type and cycle

The CCHS is not one survey — it's a family of surveys conducted under the CCHS umbrella. The `content` column on `datasets` captures what health topic a dataset covers:

- **`gen`** (186 datasets) — the main annual/biannual CCHS covering general health, chronic conditions, health behaviours, healthcare use
- **`nut`** (28 datasets) — nutrition: cycle 2.2 (2004) and Rapid Food Health (2015), with food-specific subfiles
- **`mh`** (10 datasets) — mental health: cycle 1.2 (2002) and CCHS 2012
- **`ha`** (7 datasets) — healthy aging: CCHS 2008-09, with cognition module

The `cycle` column preserves the early CCHS cycle numbering (1.1, 1.2, 2.1, 2.2, 3.1) for datasets from 2000-2005. From 2007 onward, StatCan dropped cycle numbers in favour of year-based naming, so `cycle` is NULL for those datasets. The numbering encodes: **major cycle** (1, 2, 3) and **survey number** within that cycle (.1 = general health, large sample at health-region level; .2 = focused topic, smaller sample at provincial level). Cycle 1.2 (2002) was mental health; cycle 2.2 (2004) was nutrition. There was no cycle 3.2.

These columns together with `release` capture the full classification of CCHS data files: **what health topic** (content), **what era** (cycle + year), **what access level** (release), **what geography** (geo), and **what temporal scope** (temporal_type).

### 10. Row-level metadata on every table

Every row in the database tracks its own quality and lifecycle. This is essential because the database is populated incrementally from sources of varying reliability — ICES abbreviations, DDI XML, RData factor levels, manual curation — and we need to know which rows have been verified and which are still provisional.

Four columns appear on every table (except `catalog_metadata`):

- **`version`** (INTEGER, default 1) — increments on each update. Enables change tracking across rebuilds and manual edits.
- **`status`** (VARCHAR, default 'active') — lifecycle state:
  - `active` — verified or confirmed against a primary source
  - `temp` — parsed from a secondary source (e.g., ICES scrape) but not yet verified
  - `draft` — incomplete, needs enrichment from additional sources
  - `inactive` — superseded, deprecated, or known duplicate
- **`last_updated`** (TIMESTAMP, default current_timestamp) — set during ingestion and on manual edits.
- **`notes`** (VARCHAR) — free text for caveats, verification status, known issues, or cross-references. E.g., "Duplicate of cchs-2001s-p-can — same 614 variables", "Subfile meaning unverified — inferred from ICES abbreviation".

**Ingestion defaults**: Rows from ICES scrape start as `status='temp'`. Rows enriched by RData or DDI are promoted to `status='active'`. Rows created manually (e.g., missing datasets discovered during validation) start as `status='draft'`.

For `variable_datasets`, the row-level status covers the nested `value_codes` LIST too — the value codes inherit the reliability of the source document that provided them. Individual value code disagreements are tracked in the `notes` column (e.g., "DDI label 'YES' vs RData label 'Yes' for code 1").

## New schema

See design decision 10 for the row-level metadata columns (`version`, `status`, `last_updated`, `notes`) that appear on every table.

```sql
-- 0. Documents: the catalog in DuckDB — every source file/document
--    Loaded from data/catalog/cchs_catalog.yaml + entries created during ingestion
CREATE TABLE documents (
    document_id VARCHAR PRIMARY KEY,    -- cchs_uid: 'cchs-2001s-m-dd-e-pdf-01'
    year VARCHAR,                       -- '2001', '2007', etc.
    temporal_type VARCHAR,              -- 'single', 'dual', 'multi'
    doc_type VARCHAR,                   -- 'master', 'share', 'pumf'
    category VARCHAR,                   -- 'data-dictionary', 'questionnaire', 'user-guide', 'data-file', 'ddi-xml'
    subcategory VARCHAR,                -- 'derived-variables', etc.
    language VARCHAR,                   -- 'EN', 'FR'
    filename VARCHAR,
    canonical_filename VARCHAR,
    file_extension VARCHAR,
    file_size INTEGER,
    checksum VARCHAR,
    source_namespace VARCHAR,           -- 'osf_cchs_docs', 'gdrive_pumf_collection', 'cchsflow_data'
    source_filepath VARCHAR,
    github_url VARCHAR,
    -- Row-level metadata
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',    -- 'active', 'temp', 'inactive', 'draft'
    last_updated TIMESTAMP DEFAULT current_timestamp,
    notes VARCHAR
);

-- 1. Datasets: one row per survey file release
--    source_documents and aliases stored as LIST columns (lightweight references)
CREATE TABLE datasets (
    dataset_id VARCHAR PRIMARY KEY,     -- e.g., 'cchs-2007d-p-can', 'cchs-2012s-m-can-mh'
    year_start INTEGER NOT NULL,
    year_end INTEGER NOT NULL,
    geo VARCHAR NOT NULL,               -- 'can', 'ont'
    temporal_type VARCHAR NOT NULL,      -- 'single', 'dual'
    content VARCHAR NOT NULL,            -- 'gen', 'nut', 'mh', 'ha'
    release VARCHAR NOT NULL,           -- 'pumf', 'master', 'share', 'linked', 'income'
    cycle VARCHAR,                      -- '1.1', '2.2', '3.1', etc. (NULL for 2007+)
    subfile VARCHAR,                    -- 'boot', 'hh', 'lhin', 'level1', etc.; compound: 'boot.hh' (NULL for primary files)
    n_variables INTEGER,
    n_respondents INTEGER,
    source_documents VARCHAR[],         -- document_ids that attest this dataset
    aliases STRUCT(alias VARCHAR, document_id VARCHAR)[],  -- external IDs with provenance
    -- Row-level metadata
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',    -- 'active', 'temp', 'inactive', 'draft'
    last_updated TIMESTAMP DEFAULT current_timestamp,
    notes VARCHAR
);

-- 2. Variables: one row per unique variable name (canonical record)
--    source_documents stored as LIST column (lightweight reference)
CREATE TABLE variables (
    variable_name VARCHAR PRIMARY KEY,
    label_short VARCHAR,                -- concise label (≤40 chars), generated following CCHS conventions
    label_long VARCHAR,                 -- full descriptive label
    label_statcan VARCHAR,              -- original StatCan label (from latest DDI or RData haven label)
    type VARCHAR,                       -- R class or DDI type (latest)
    value_format VARCHAR,               -- format type name: 'CCHS_YESNOFM', 'CCHS_AGREEFM', etc.
    question_text VARCHAR,              -- from DDI (latest cycle with this var)
    universe VARCHAR,                   -- from DDI
    section VARCHAR,                    -- e.g., 'Health behaviour' (from cchsflow)
    subject VARCHAR,                    -- e.g., 'Smoking', 'Alcohol' (from cchsflow)
    subsection VARCHAR,                 -- e.g., 'smoking initiation'
    cchsflow_name VARCHAR,             -- harmonised name from cchsflow (NULL if not in cchsflow)
    n_datasets INTEGER,                 -- count of distinct datasets containing this variable
    n_cycles INTEGER,                   -- count of distinct cycles (year_start values)
    source_documents VARCHAR[],         -- document_ids that reference this variable
    -- Row-level metadata
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',    -- 'active', 'temp', 'inactive', 'draft'
    last_updated TIMESTAMP DEFAULT current_timestamp,
    notes VARCHAR
);

-- 3. Variable-dataset linking: which datasets contain each variable
--    One row per (variable_name, dataset_id, document_id) — separate rows per source document
--    Value codes stored as LIST column — each source document carries its own codes
--    Row-level status covers the value codes too (they inherit the source document's reliability)
CREATE TABLE variable_datasets (
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    document_id VARCHAR NOT NULL REFERENCES documents(document_id),
    label VARCHAR,                      -- label from this document for this dataset
    type VARCHAR,                       -- R class (from RData) or DDI type
    position INTEGER,                   -- column position (from DDI)
    length INTEGER,                     -- field length (from DDI)
    question_text VARCHAR,              -- question text (from DDI)
    universe VARCHAR,                   -- universe (from DDI)
    value_codes STRUCT(
        code VARCHAR,                   -- response code: '1', '2', '6', '96', etc.
        label VARCHAR,                  -- response label: 'Yes', 'No', 'Valid skip', etc.
        frequency INTEGER,              -- count from RData factors (NULL for DDI)
        is_missing BOOLEAN              -- TRUE for codes 6/7/8/9 (skip, don't know, refusal, not stated)
    )[],
    -- Row-level metadata
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',    -- 'active', 'temp', 'inactive', 'draft'
    last_updated TIMESTAMP DEFAULT current_timestamp,
    notes VARCHAR,
    PRIMARY KEY (variable_name, dataset_id, document_id)
);

-- 4. Catalog metadata
CREATE TABLE catalog_metadata (
    key VARCHAR PRIMARY KEY,
    value VARCHAR
);
```

**Schema summary: 5 tables**

| Table | Rows (est.) | Purpose |
|---|---|---|
| `documents` | ~1,500 | Catalog backbone — every source file has a document_id |
| `datasets` | ~231 | One row per survey file release (all ICES datasets + any new ones from RData/DDI) |
| `variables` | ~14,000 | One row per unique variable name; ICES provides broad coverage, RData/DDI enrich PUMF subset |
| `variable_datasets` | ~120,000-140,000 | Per-(variable, dataset, document) metadata + value codes as LIST |
| `catalog_metadata` | ~10 | Build metadata (version, date, counts) |

**Schema rationale — tables vs LIST columns:**

| Relationship | Storage | Why |
|---|---|---|
| Dataset → source documents | `datasets.source_documents VARCHAR[]` | Simple list of document_ids, no per-link metadata |
| Dataset → aliases | `datasets.aliases STRUCT(...)[]` | Lightweight pairs (alias + provenance document) |
| Variable → source documents | `variables.source_documents VARCHAR[]` | Simple list of document_ids |
| Variable → dataset | `variable_datasets` table | Heavy: per-link metadata (label, type, position, question_text, universe) |
| Value codes | `variable_datasets.value_codes STRUCT(...)[]` | Naturally scoped to (variable, dataset, document); avoids separate table |
| Cross-cycle equivalence | `variables.cchsflow_name` | Simple column, no join table needed; group by cchsflow_name |

### Key changes from v1

1. **`documents` table** — the catalog loaded into DuckDB; every source file has a `document_id` (its `cchs_uid`)
2. **ICES scrape seeds datasets and variables** — 231 datasets and 14,005 variables from ICES provide broad skeletal coverage; RData + DDI enrich the national PUMF subset with deep metadata
3. **`variables` is one-row-per-name** — variable name IS the unique ID
4. **Three-label model** — `label_short`, `label_long`, `label_statcan` on variables; per-cycle labels preserved on `variable_datasets`
5. **Lightweight LIST columns throughout** — `source_documents`, `aliases`, and `value_codes` stored as LIST/STRUCT columns on their parent tables, eliminating 5 junction tables from the original design
6. **`variable_datasets` table** — keyed by (variable, dataset, document_id); rich per-link metadata including value codes as nested STRUCT list
7. **`cchsflow_name` replaces `variable_families`** — simple column on `variables` for cross-cycle equivalence, seeded from cchsflow `variables.csv`
8. **`ddi_variables` merged** — no more broken LEFT JOINs; DDI enriches `variables` and `variable_datasets`
9. **`value_format`** — format type name (e.g., `CCHS_YESNOFM`, `CCHS_AGREEFM`) on `variables`, classifying the type of response coding
10. **`is_missing` on value codes** — each response code flagged as missing or valid, enabling proper missing data handling
11. **`n_datasets` and `n_cycles`** — computed counts on `variables` for search ranking and quick reference
12. **`release` replaces `doc_type`** — extended to 5 values: pumf, master, share, linked, income
13. **`geo` column on `datasets`** — 'can', 'ont', etc.
14. **`content` column on `datasets`** — gen, nut, mh, ha
15. **`cycle` column on `datasets`** — early CCHS cycle numbers (1.1–3.1); NULL for 2007+
16. **`subfile` column on `datasets`** — boot, hh, lhin, level1, etc.; compound subfiles use `.` separator (boot.hh, boot.lhin); NULL for primary files
17. **`subsection` on `variables`** — finer-grained topic within a section
18. **5 tables total** — minimal schema using DuckDB native LIST/STRUCT types
19. **Full provenance via `document_id`** — every record traces to a specific cataloged document
20. **cchsflow integration** — `subject`, `section`, `subsection`, `cchsflow_name`, `label_short`, `label_long` seeded from `variables.csv`
21. **Row-level metadata on every table** — `version`, `status`, `last_updated`, `notes` on documents, datasets, variables, and variable_datasets. Enables quality tracking: ICES-seeded rows start as `status='temp'`; rows verified against primary sources are promoted to `status='active'`; superseded entries become `status='inactive'`

### Views

```sql
-- Variable history across cycles — one row per (variable, dataset), best metadata from all source documents
CREATE VIEW v_variable_history AS
SELECT v.variable_name, v.label_short, v.cchsflow_name, v.value_format,
       d.year_start, d.year_end, d.geo, d.temporal_type, d.content, d.release,
       vd.dataset_id,
       COALESCE(
           MAX(CASE WHEN doc.category = 'ddi-xml' THEN vd.label END),
           MAX(vd.label)
       ) AS dataset_label,
       COALESCE(
           MAX(CASE WHEN doc.category = 'ddi-xml' THEN vd.question_text END),
           MAX(vd.question_text)
       ) AS question_text,
       COALESCE(
           MAX(CASE WHEN doc.category = 'data-file' THEN vd.type END),
           MAX(vd.type)
       ) AS type,
       LIST(DISTINCT vd.document_id ORDER BY vd.document_id) AS source_documents
FROM variables v
JOIN variable_datasets vd ON v.variable_name = vd.variable_name
JOIN datasets d ON vd.dataset_id = d.dataset_id
JOIN documents doc ON vd.document_id = doc.document_id
GROUP BY v.variable_name, v.label_short, v.cchsflow_name, v.value_format,
         d.year_start, d.year_end, d.geo,
         d.temporal_type, d.content, d.release, vd.dataset_id
ORDER BY v.variable_name, d.year_start;

-- Variable-dataset detail — all source document rows preserved (for auditing provenance)
CREATE VIEW v_variable_datasets_detail AS
SELECT vd.variable_name, vd.dataset_id, vd.document_id,
       doc.category AS doc_category, doc.filename,
       vd.label, vd.type, vd.position, vd.length,
       vd.question_text, vd.universe,
       vd.value_codes,
       d.year_start, d.year_end, d.geo, d.temporal_type, d.content, d.release
FROM variable_datasets vd
JOIN datasets d ON vd.dataset_id = d.dataset_id
JOIN documents doc ON vd.document_id = doc.document_id
ORDER BY vd.variable_name, d.year_start, doc.category;

-- Cross-cycle equivalence: trace a variable concept across cycles including all name variants
-- Uses cchsflow_name to group variables that represent the same concept with different names
CREATE VIEW v_cchsflow_history AS
SELECT v.cchsflow_name, v.variable_name, v.label_short,
       vd.dataset_id,
       d.year_start, d.year_end, d.temporal_type, d.release,
       COALESCE(
           MAX(CASE WHEN doc.category = 'ddi-xml' THEN vd.label END),
           MAX(vd.label)
       ) AS dataset_label,
       MAX(vd.type) AS type
FROM variables v
JOIN variable_datasets vd ON v.variable_name = vd.variable_name
JOIN datasets d ON vd.dataset_id = d.dataset_id
JOIN documents doc ON vd.document_id = doc.document_id
WHERE v.cchsflow_name IS NOT NULL
GROUP BY v.cchsflow_name, v.variable_name, v.label_short,
         vd.dataset_id, d.year_start, d.year_end, d.temporal_type, d.release
ORDER BY v.cchsflow_name, d.year_start;

-- Dataset variable list with best labels (deduplicated across source documents)
CREATE VIEW v_dataset_variables AS
SELECT vd.dataset_id, vd.variable_name,
       COALESCE(
           MAX(CASE WHEN doc.category = 'ddi-xml' THEN vd.label END),
           MAX(vd.label),
           v.label_short
       ) AS label,
       COALESCE(
           MAX(CASE WHEN doc.category = 'data-file' THEN vd.type END),
           MAX(vd.type),
           v.type
       ) AS type,
       v.section, v.subject, v.subsection, v.cchsflow_name, v.value_format, v.n_datasets,
       MAX(vd.position) AS position,
       LIST(DISTINCT vd.document_id ORDER BY vd.document_id) AS source_documents
FROM variable_datasets vd
JOIN variables v ON vd.variable_name = v.variable_name
JOIN documents doc ON vd.document_id = doc.document_id
GROUP BY vd.dataset_id, vd.variable_name, v.label_short, v.type,
         v.section, v.subject, v.subsection, v.cchsflow_name, v.value_format, v.n_datasets
ORDER BY vd.dataset_id, position;

-- Dataset aliases (unnested from LIST column for querying)
CREATE VIEW v_dataset_aliases AS
SELECT d.dataset_id, a.alias, a.document_id,
       d.year_start, d.year_end, d.geo, d.temporal_type, d.content, d.release, d.cycle
FROM datasets d, UNNEST(d.aliases) AS a
ORDER BY d.dataset_id, a.alias;

-- Value codes flattened (unnested from variable_datasets for easy querying)
CREATE VIEW v_value_codes AS
SELECT vd.variable_name, vd.dataset_id, vd.document_id,
       vc.code, vc.label, vc.frequency, vc.is_missing,
       d.year_start, d.year_end, d.release
FROM variable_datasets vd,
     UNNEST(vd.value_codes) AS vc,
     datasets d
WHERE d.dataset_id = vd.dataset_id
ORDER BY vd.variable_name, d.year_start, vc.code;
```

## Enum reference

Controlled vocabularies for DuckDB columns. These extend the existing LinkML schemas and serve as the reference for future schema harmonisation. Descriptions follow the LinkML `permissible_values` convention.

### `datasets.temporal_type`

Aligns with `health_survey_schema_linkml.yaml` `TemporalTypeEnum`. The `cchs_data_schema.yaml` uses different terms (annual/biannual/multi-cycle) — this schema uses the documentation catalog convention.

| Value | Description |
|-------|-------------|
| `single` | Single calendar year survey (2001, 2003, 2005, and annual files 2007+) |
| `dual` | Two-year cycle survey (2007-2008, 2009-2010, ..., 2019-2020) |

Note: `multi` (from `TemporalTypeEnum`) is not present in current data but reserved for future multi-cycle harmonised datasets.

### `datasets.content`

**New — not in any existing schema.** Classifies what health topic the survey covers. The CCHS umbrella includes distinct surveys with different questionnaires and target populations.

| Value | Full name | Description | Datasets | Years |
|-------|-----------|-------------|----------|-------|
| `gen` | General | Main CCHS annual/biannual survey covering general health, chronic conditions, health behaviours, healthcare utilisation, and sociodemographic factors | 186 | 2000-2021 |
| `nut` | Nutrition | Nutrition-focused surveys: CCHS cycle 2.2 (2004) and Rapid Food Health survey (2015). Include food-specific subfiles (24-hour dietary recall, food description codes, food intake data, supplement data) | 28 | 2004, 2015 |
| `mh` | Mental health | CCHS Mental Health surveys: cycle 1.2 (2002) — Mental Health and Well-being; and CCHS 2012 — Mental Health. Focused instruments measuring mental disorders, mental health service use, and disability | 10 | 2002, 2012 |
| `ha` | Healthy aging | CCHS Healthy Aging survey (2008-2009). Covers older adults (45+) with modules on cognition, functional health, social participation | 7 | 2008-2009 |

### `datasets.release`

Extends `DocTypeEnum` (master, share, pumf) with two additional release types found in the ICES data.

| Value | Description | Datasets |
|-------|-------------|----------|
| `pumf` | Public Use Microdata File — nationally representative, publicly available with privacy protections (top-coding, geographic suppression). Distributed by Statistics Canada via DLI/ODESSI | 6 |
| `master` | Master file — full detail, accessible only in Research Data Centres (RDCs). Contains unrestricted response categories, detailed geography, and all variables | 8 |
| `share` | Share file — provincial subset available to approved institutions (e.g., ICES for Ontario). More detail than PUMF but less than Master | 164 |
| `linked` | Linked file — records with encrypted health insurance numbers (IKN) enabling linkage to administrative health databases. Ontario-specific via ICES | 38 |
| `income` | Income supplement file — small auxiliary files (8-28 variables) containing imputed income variables or income-linked records. Separate from the main survey file | 15 |

### `datasets.geo`

**New — not in any existing schema.** Geography of the dataset's respondent population.

| Value | Full name | Description | Datasets |
|-------|-----------|-------------|----------|
| `can` | Canada | National file covering all provinces and territories | 50 |
| `ont` | Ontario | Ontario-only subset, typically from ICES holdings | 181 |

Note: Future sources may add other provinces (e.g., `qc`, `bc`).

### `datasets.cycle`

StatCan's original CCHS cycle numbering (2000–2005 only). **Metadata column only — not part of the canonical dataset ID.** The year + content type already uniquely identify each dataset. NULL for 2007+ when StatCan switched to year-based naming.

| Value | Year(s) | Content | Sample | Meaning |
|-------|---------|---------|--------|---------|
| `1.1` | 2000-2001 | gen | 131,500 | Cycle 1, survey 1 — general health (health-region level) |
| `1.2` | 2002 | mh | 37,000 | Cycle 1, survey 2 — **mental health and well-being** (provincial level) |
| `2.1` | 2003 | gen | ~136,000 | Cycle 2, survey 1 — general health |
| `2.2` | 2004 | nut | ~35,000 | Cycle 2, survey 2 — **nutrition** |
| `3.1` | 2005 | gen | ~136,000 | Cycle 3, survey 1 — general health |

The numbering encodes: **major cycle** (1, 2, 3) and **survey number** within that cycle. The `.1` surveys were large-sample general health surveys with health-region-level estimates; the `.2` surveys were smaller focused-topic surveys with provincial-level estimates. There was no cycle 3.2 — StatCan redesigned the CCHS to annual collection starting in 2007, sometimes informally called "cycle 4.1" but cycle numbering was dropped.

Note: The ICES dataset `CCHS2000_01` is a duplicate of `CCHS2001_PUBLIC_11` — both contain the same 614 variables from the cycle 1.1 PUMF. The `_01` suffix was misinterpreted as cycle `0.1` during ICES ID parsing; there is no cycle 0.1 in the CCHS. The CCHS2000 label refers to the collection start date (September 2000) while CCHS2001 refers to the reference year.

### `datasets.subfile`

File variant within a release. NULL for primary data files. Primary files contain the main respondent-level survey data; subfiles contain auxiliary data (bootstrap weights, geographic identifiers, supplement files, etc.). Abbreviated values: `boot` (bootstrap), `hh` (household), `cog` (cognition), `imp` (imputed). Compound subfiles use `.` separator (e.g., `boot.hh`, `boot.lhin`, `imp.link`).

**Solo subfile values:**

Confidence levels: **verified** = confirmed against StatCan documentation or data inspection; **likely** = strong evidence but not directly confirmed; **inferred** = derived from ICES abbreviation patterns only.

| Value | Full name | Description | Count | Confidence |
|-------|-----------|-------------|-------|------------|
| `boot` | bootstrap | Bootstrap replicate weights for variance estimation (typically 500 or 1,000 replicates) | 40 | verified |
| `hh` | household | Household-level weight file (separate from person-level) | 21 | likely |
| `lhin` | lhin | Local Health Integration Network identifiers (Ontario health region geography) | 15 | verified |
| `level1` | level1 | Geographic identifiers (possibly census subdivision level — needs verification) | 17 | inferred |
| `imp` | imputed | Imputed income variables | 7 | likely |
| `pb` | pb | Person-based linkage identifiers (inferred from ICES naming) | 6 | inferred |
| `cog` | cognition | Cognition module data (Healthy Aging survey) | 1 | likely |
| `sub1` | sub1 | Sub-sample 1 (2005 cycle 3.1 — purpose unknown) | 1 | inferred |
| `sub3` | sub3 | Sub-sample 3 (2005 cycle 3.1 — purpose unknown) | 1 | inferred |
| `ikn` | ikn | Encrypted health insurance number (IKN) for record linkage | 2 | verified |
| `postalcode` | postalcode | Postal code identifiers | 2 | likely |
| `hhwt` | hhwt | Unknown — possibly household weight file for nutrition survey | 2 | inferred |
| `ontario` | ontario | Ontario-specific income linkage file | 3 | inferred |
| `vars` | vars | Unknown — possibly income variable definitions | 2 | inferred |
| `cfg` | cfg | Unknown — possibly Canada's Food Guide classification (nutrition survey) | 1 | inferred |
| `fdc` | fdc | Unknown — possibly food description code file (nutrition survey) | 1 | inferred |
| `fid` | fid | Unknown — possibly food intake data file (nutrition survey) | 1 | inferred |
| `frl` | frl | Unknown — possibly food recipe level file (nutrition survey) | 1 | inferred |
| `r24` | r24 | Unknown — possibly 24-hour dietary recall file (nutrition survey) | 1 | inferred |
| `side` | side | Unknown — possibly supplement intake data file (nutrition survey) | 1 | inferred |
| `vdc` | vdc | Unknown — possibly vitamin/mineral description code (nutrition survey) | 1 | inferred |
| `vmd` | vmd | Unknown — possibly vitamin/mineral data file (nutrition survey) | 1 | inferred |
| `vsd` | vsd | Unknown — possibly vitamin/mineral supplement data (nutrition survey) | 1 | inferred |

Many nutrition subfile abbreviations (cfg, fdc, fid, frl, r24, side, vdc, vmd, vsd) are guesses based on abbreviation patterns. The actual meanings should be verified against the CCHS cycle 2.2 nutrition user guide before being treated as authoritative.

**Compound subfile values** (`.` separator):

| Value | Components | Description | Count | Confidence |
|-------|-----------|-------------|-------|------------|
| `boot.hh` | boot + hh | Bootstrap weights with household-level weights | 24 | likely |
| `boot.lhin` | boot + lhin | Bootstrap weights with LHIN identifiers | 16 | likely |
| `boot.hs` | boot + hs | Bootstrap weights for unknown component (nutrition survey — possibly health supplement?) | 2 | inferred |
| `boot.hw` | boot + hw | Bootstrap weights for unknown component (nutrition survey — possibly health/wellness?) | 2 | inferred |
| `boot.sub1` | boot + sub1 | Bootstrap weights for sub-sample 1 | 1 | inferred |
| `boot.sub3` | boot + sub3 | Bootstrap weights for sub-sample 3 | 1 | inferred |
| `boot.cog` | boot + cog | Bootstrap weights for cognition module | 1 | likely |
| `level1.sub1` | level1 + sub1 | Level 1 geo identifiers for sub-sample 1 | 1 | inferred |
| `level1.sub3` | level1 + sub3 | Level 1 geo identifiers for sub-sample 3 | 1 | inferred |
| `level1.cog` | level1 + cog | Level 1 geo identifiers for cognition module | 1 | inferred |
| `imp.link` | imp + link | Imputed income with linkage identifiers | 3 | inferred |

### `documents.category`

Aligns with `DocumentCategoryEnum` from `health_survey_schema_linkml.yaml`, extended with data-specific categories.

| Value | Description |
|-------|-------------|
| `data-dictionary` | Variable definitions and coding schemes |
| `questionnaire` | Survey instruments and question sets |
| `user-guide` | Survey methodology and usage guidance |
| `data-file` | Survey microdata (RData, SAS, SPSS, Stata) |
| `ddi-xml` | DDI metadata XML files |
| `bootstrap` | Bootstrap variance estimation documentation |
| `record-layout` | Record layout documentation |
| `derived-variables` | Calculated variables documentation |
| *(and ~20 more from the catalog schema)* | |

### `variables.type`

R class names from PUMF RData files. Not enumerated — stored as-is from `class()`.

Common values: `haven_labelled`, `numeric`, `factor`, `character`, `integer`.

### Label conventions (three-label model)

See design decision 6 for full specification. Summary:

| Column | Max length | Source | Mutable |
|--------|-----------|--------|---------|
| `label_statcan` | Unlimited | Latest DDI or RData haven label, verbatim | No — preserved as-is for provenance |
| `label_short` | ≤40 chars | CCHS conventions: "Type of smoker (D)", "Age (G)" | Yes — initially from StatCan, improved over time |
| `label_long` | Unlimited | Full descriptive: "Type of smoker - derived variable" | Yes — initially from StatCan, improved over time |

`label_short` and `label_long` may be seeded from cchsflow `variables.csv` (columns `label` and `labelLong`) where available, providing higher-quality labels than the raw StatCan originals.

## Ingestion pipeline

### Phase 0: Load catalog into documents table

**Script**: `ingestion/ingest_catalog.R` (new)

1. Read `data/catalog/cchs_catalog.yaml`
2. Insert each file entry into `documents` table (cchs_uid → document_id)
3. Create additional document entries for RData files and DDI XML files from `cchsflow-data/` that aren't yet in the catalog (category='data-file' for RData, category='ddi-xml' for DDI)
4. These synthetic document_ids follow the cchs_uid pattern: e.g., `cchs-2007d-p-data-e-rdata-01` for the RData, `cchs-2007d-p-ddi-e-xml-01` for the DDI

### Phase 1: Seed datasets from ICES scrape

**Script**: `ingestion/ingest_ices_datasets.R` (new)

**Input**: `data/datasets.csv` (231 rows, pre-parsed from ICES dataset IDs with canonical names and attributes) + `data/ices_cchs_dictionary.duckdb`

Load the 231 dataset IDs from the pre-parsed CSV as the foundation for the `datasets` table. The CSV was generated by parsing ICES dataset IDs into canonical names and structured attributes (year_start, year_end, geo, temporal_type, content, release, cycle, subfile).

For each row in the CSV:
1. Read canonical `dataset_id` and all attributes directly from the CSV (no parsing at ingestion time)
2. Insert into `datasets` with the ICES ID stored as an alias
3. Also load ICES variables and availability data into `variables` and `variable_datasets` — these provide skeletal coverage (variable name, abbreviated label, type, format) across all 231 datasets. The `variable_datasets` rows have ICES as their document_id and carry `label`, `type`, but no question_text, universe, position, or value_codes. Status is set to `'temp'` since ICES metadata hasn't been verified against primary sources.

This gives the database broad coverage from day one: 14,005 variables across all file types. PUMF RData and DDI then enrich the national PUMF subset with deep metadata.

### Phase 2: PUMF RData (ground truth for national PUMF)

**Script**: `ingestion/ingest_pumf_rdata.R`

For each of 11 RData files in `cchsflow-data/data/sources/rdata/`:
1. Load into `new.env()` (avoids scoping issues)
2. Extract: column names, R classes, haven labels (`attr(col, "label")`), factor levels with `table()` counts
3. Match to existing dataset_id in the `datasets` table (created in phase 1)
4. Look up `document_id` from `documents` table (created in phase 0)
5. Append document_id to `datasets.source_documents` list; append RData filename to `datasets.aliases` list
6. For each column: UPDATE `variables` row with haven label → `label_statcan` (also copy to `label_short` and `label_long` initially), R class → `type`; append document_id to `source_documents`
7. Insert into `variable_datasets` with document_id, type from R class, haven label, and `value_codes` LIST from factor levels (code, label, frequency, is_missing inferred from label text matching 'Valid skip|Not applicable|Don't know|Refusal|Not stated')

The haven label from the latest cycle (processed chronologically) becomes `label_statcan`. For variables new to the database (not in ICES), INSERT instead of UPDATE.

Reuses pattern from `cchsflow-data/scripts/download_cchs_pumf.R` (`get_rdata_metadata()`).

### Phase 3: DDI XML (documentation enrichment)

**Script**: `ingestion/ingest_ddi_xml.R` (rewrite)

For each of 11 DDI XML files in `cchsflow-data/ddi/`:
1. Parse with `xml2::read_xml()`, namespace-aware XPath
2. Match to dataset_id by cycle alignment
3. Look up `document_id` from `documents` table (created in phase 0)
4. Append document_id to `datasets.source_documents` list; append DDI filename to `datasets.aliases` list
5. For variables already in `variables` table: UPDATE with DDI label → `label_statcan` (DDI preferred over RData haven label), `question_text`, `universe`; append document_id to `source_documents`
6. INSERT into `variable_datasets` with document_id — separate from the RData row. DDI row has label, question_text, universe, position, length, and `value_codes` LIST from DDI `<catgry>` elements (code from `<catValu>`, label from `<labl>`, frequency from `<catStat type="freq">`, is_missing inferred from label text)
7. For DDI-only variables (not in RData or ICES): INSERT into `variables` and `variable_datasets`

Label resolution order for `label_statcan`: DDI label (latest cycle) > RData haven label (latest cycle) > ICES label. The DDI label is preferred because it's the most complete form from the official documentation.

Reuses XPath patterns from existing `ingestion/ingest_ddi_xml.R`.

### Phase 4: cchsflow enrichment

**Script**: `ingestion/ingest_cchsflow.R` (new)

Read `cchsflow/inst/extdata/variables.csv` to enrich `variables` table:
1. **`cchsflow_name`**: Parse the `variableStart` column to find which variable names map to each harmonised name. For each cycle-specific variable (e.g., `cchs2001_p::RACA_6A`), set `variables.cchsflow_name = 'ADL_01'`. For variables that keep the same name across cycles (in `[brackets]`), set `cchsflow_name = variable_name`.
2. **`subject` and `section`**: From the CSV's `subject` and `section` columns.
3. **`value_format`**: From the ICES scrape's `format` column (e.g., `CCHS_YESNOFM`), if available.
4. **`label_short` and `label_long`**: From cchsflow's `label` and `labelLong` columns where available, overriding the initial copies from `label_statcan`.

The `variableStart` column format is: `cchs{year}_p::{VARNAME}, ..., [{DEFAULT_NAME}]`
- Items in `[brackets]` are the default name (used when the variable name doesn't change)
- Items with `::` are cycle-specific mappings
- `DerivedVar::` entries are cchsflow-computed derived variables (skip)

### Phase 5: Compute aggregates

After all sources are loaded:
1. Compute `n_datasets` and `n_cycles` for each variable from `variable_datasets`
2. Compute `n_variables` for each dataset from `variable_datasets`

### Phase 6: Merge validation

**Script**: `ingestion/validate_merge.R`

- Variables in RData but not DDI (per cycle)
- Variables in DDI but not RData (per cycle)
- Variables in ICES but not RData/DDI (per national PUMF cycle)
- Value code disagreements (DDI categories vs RData factor levels)
- Label coverage: % of variables with label_statcan, label_short, label_long
- cchsflow coverage: % of variables with a `cchsflow_name`
- Compare counts against `extraction_summary.yaml`

### Phase 7: Build orchestration

**Script**: `database/build_db.R` (rewrite)

1. Create fresh DuckDB, apply schema
2. Run phase 0 → 1 → 2 → 3 → 4 → 5 → 6
3. Create views, write catalog_metadata

## MCP server changes

### Tool updates

| Tool | Change |
|------|--------|
| `search_variables` | Query `variables` table — search across `variable_name`, `label_short`, `label_long`, `section`, `subject`; rank by `n_datasets` DESC so widely-used variables appear first |
| `get_variable_detail` | Query `variables` + `variable_datasets` + `value_codes` + family info |
| `get_variable_history` | Query `v_variable_history` — shows all datasets containing the variable |
| `get_dataset_variables` | Query `v_dataset_variables` for a specific dataset_id |
| `get_common_variables` | Self-join on `variable_datasets` for two dataset_ids |
| `get_value_codes` | Query `v_value_codes` view (unnested from variable_datasets) |
| `suggest_cchsflow_row` | Query `variables` + `variable_datasets` (with value_codes) for target cycle |
| `get_database_summary` | Updated aggregates from new tables |
| `compare_master_pumf` | **Rename to `compare_across_datasets`** — compare any two datasets |

### New tools

| Tool | Purpose |
|------|---------|
| `resolve_dataset_alias` | Given any alias (e.g., `CCHS200708_PUMF`), return canonical ID + all aliases |
| `get_cchsflow_equivalents` | Given a variable name, find all cross-cycle equivalents via `cchsflow_name` |

## File changes

| File | Action |
|------|--------|
| `database/schema.sql` | Rewrite with new schema (5 tables, 6 views) |
| `database/build_db.R` | Rewrite build orchestration |
| `ingestion/ingest_catalog.R` | **New** — phase 0 (load catalog + create synthetic document entries) |
| `data/datasets.csv` | **New** — pre-parsed ICES dataset IDs with canonical names and structured attributes (231 rows) |
| `ingestion/ingest_ices_datasets.R` | **New** — phase 1 (seed 231 datasets from CSV + skeletal variable coverage from ICES) |
| `ingestion/ingest_pumf_rdata.R` | **New** — phase 2 |
| `ingestion/ingest_ddi_xml.R` | Rewrite — phase 3 |
| `ingestion/ingest_cchsflow.R` | **New** — phase 4 |
| `ingestion/validate_merge.R` | **New** — phase 6 |
| `mcp-server/server.py` | Update all SQL, add `resolve_dataset_alias` + `get_cchsflow_equivalents` |
| `database/cchs_metadata.duckdb` | Rebuilt from scratch |
| `ingestion/ingest_ices_scrape.R` | Archive (don't delete, don't run) |

## Verification

1. **Variable count alignment**: RData vs DDI per cycle. Report deltas.
2. **Cross-reference**: Compare against `extraction_summary.yaml` expected counts
3. **Family coverage**: Report how many of the ~14K variables are grouped into families via cchsflow
4. **MCP smoke tests**:
   - `get_database_summary` — 11 PUMF datasets, all cycles
   - `search_variables("smoking")` — returns SMKDSTY and related, with subject/section
   - `get_variable_detail("SMKDSTY")` — question text, categories, all datasets, family info
   - `get_variable_history("DHHGAGE")` — across cycles with temporal_type
   - `get_value_codes("SMKDSTY")` — categories with provenance
   - `get_cchsflow_equivalents("RACA_6A")` — returns ADL_01 group with all cycle variants
   - `compare_across_datasets("SMKDSTY", "cchs-2007d-p-can", "cchs-2017d-p-can")` — cross-cycle comparison
   - `resolve_dataset_alias("CCHS200708_PUMF")` — returns canonical ID
5. **Referential integrity**: All document_ids in variable_datasets exist in documents; all dataset_ids exist in datasets
6. **Provenance**: Every variable_datasets row has a valid document_id; every dataset and variable has non-empty source_documents list
7. **Missing data flags**: Spot-check is_missing flags on value_codes — codes 6/7/8/9 and their multi-digit equivalents should all be TRUE
