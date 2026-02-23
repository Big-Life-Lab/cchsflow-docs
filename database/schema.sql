-- =============================================================================
-- CCHS Unified Metadata Schema v2 (DuckDB)
-- =============================================================================
--
-- Three-tier architecture:
--   CSV (source of truth)  →  DuckDB (queryable)  →  MCP server (tools)
--
-- CSV-sourced tables: sources, datasets, variables
--   - Human-editable, git-tracked reference data
--   - Loaded into DuckDB at build time
--
-- DuckDB-only tables: dataset_sources, dataset_aliases, variable_datasets,
--   variable_families, variable_family_members, value_codes,
--   variable_summary_stats, variable_groups, variable_group_members
--   - Machine-generated during ingestion
--   - Too large or too dynamic for CSV
--
-- See: development/architecture/PLAN_database_rebuild.md
-- =============================================================================

-- ============================================================
-- 1. Sources: registry of all data sources
--    CSV-sourced: data/sources.csv
-- ============================================================
CREATE TABLE IF NOT EXISTS sources (
    source_id VARCHAR PRIMARY KEY,
    source_name VARCHAR NOT NULL,
    source_type VARCHAR NOT NULL,        -- 'data', 'documentation', 'derived', 'scrape', 'extraction'
    authority VARCHAR NOT NULL,          -- 'primary', 'secondary'
    location VARCHAR,                    -- relative path to source files
    n_files INTEGER,
    content VARCHAR,
    ingestion_script VARCHAR,
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',     -- 'active', 'draft', 'inactive'
    last_updated DATE,
    notes VARCHAR
);

-- ============================================================
-- 2. Datasets: one row per survey file release
--    CSV-sourced: data/datasets.csv
-- ============================================================
CREATE TABLE IF NOT EXISTS datasets (
    ices_id VARCHAR,                     -- original ICES dataset ID (blank for non-ICES sources)
    dataset_id VARCHAR PRIMARY KEY,      -- canonical: 'cchs-2007d-p-can'
    year_start INTEGER NOT NULL,
    year_end INTEGER NOT NULL,
    geo VARCHAR NOT NULL,                -- 'can', 'ont'
    temporal_type VARCHAR NOT NULL,      -- 'single', 'dual', 'multi'
    content VARCHAR NOT NULL,            -- 'gen', 'mh', 'nut', 'ha'
    release VARCHAR NOT NULL,            -- 'pumf', 'master', 'share', 'linked', 'income'
    cycle VARCHAR,                       -- '1.1', '2.1', etc. (blank for post-2007)
    subfile VARCHAR,                     -- 'boot', 'hh', 'pb', etc.
    n_variables INTEGER,
    n_primary_sources INTEGER DEFAULT 0,   -- count of primary-authority sources attesting this dataset
    n_secondary_sources INTEGER DEFAULT 0, -- count of secondary-authority sources
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'active',
    last_updated DATE,
    notes VARCHAR
);

-- ============================================================
-- 3. Variables: one row per unique variable name
--    CSV-sourced: data/variables.csv
-- ============================================================
CREATE TABLE IF NOT EXISTS variables (
    variable_name VARCHAR PRIMARY KEY,
    label_short VARCHAR,                 -- clean short label (<=40 chars, from cchsflow or manual)
    label_long VARCHAR,                  -- full descriptive label (from cchsflow or DDI)
    label_statcan VARCHAR,               -- verbatim StatCan/ICES label (often truncated)
    type VARCHAR,                        -- data type (Num8, Char1, etc. from ICES; or R class)
    value_format VARCHAR,                -- format name for response categories (e.g., CCHS_YESNOFM)
    question_text VARCHAR,               -- DDI question text (latest cycle)
    universe VARCHAR,                    -- DDI universe (latest cycle)
    section VARCHAR,                     -- e.g., 'Health behaviour' (from cchsflow)
    subject VARCHAR,                     -- e.g., 'Smoking', 'Alcohol' (from cchsflow)
    subsection VARCHAR,
    cchsflow_name VARCHAR,               -- harmonised variable name in cchsflow
    n_datasets INTEGER,                  -- count of datasets containing this variable
    n_cycles INTEGER,                    -- count of distinct cycles
    n_primary_sources INTEGER DEFAULT 0,   -- count of primary-authority sources attesting this variable
    n_secondary_sources INTEGER DEFAULT 0, -- count of secondary-authority sources
    version INTEGER DEFAULT 1,
    status VARCHAR DEFAULT 'temp',       -- 'active', 'temp', 'draft', 'inactive'
    last_updated DATE,
    notes VARCHAR
);

-- ============================================================
-- 4. Dataset sources: which sources attest each dataset
--    DuckDB-only, populated during ingestion
-- ============================================================
CREATE TABLE IF NOT EXISTS dataset_sources (
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    source_detail VARCHAR NOT NULL,      -- specific file: 'CCHS_2007_2008.RData'
    first_seen DATE,
    last_verified DATE,
    PRIMARY KEY (dataset_id, source_id, source_detail)
);

-- ============================================================
-- 5. Dataset aliases: maps external IDs to canonical dataset_id
--    DuckDB-only, populated during ingestion
-- ============================================================
CREATE TABLE IF NOT EXISTS dataset_aliases (
    alias VARCHAR NOT NULL,              -- e.g., 'CCHS200708_PUMF', 'CCHS_2007_2008'
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (alias, source_id)
);

-- ============================================================
-- 6. Variable-dataset linking: which datasets contain each variable
--    DuckDB-only, populated during ingestion
--    One row per (variable_name, dataset_id, source_id)
--    Separate rows per source preserves full provenance
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_datasets (
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    label VARCHAR,                       -- label from this source for this dataset
    type VARCHAR,                        -- R class (from RData) or DDI type
    position INTEGER,                    -- column position (from DDI)
    length INTEGER,                      -- field length (from DDI)
    question_text VARCHAR,               -- question text (from DDI)
    universe VARCHAR,                    -- universe (from DDI)
    intrvl VARCHAR,                      -- measurement level: 'discrete' or 'contin' (from DDI)
    wgt_var VARCHAR,                     -- weight variable reference ID (from DDI)
    notes VARCHAR,                       -- derivation notes, UNF fingerprint, etc. (from DDI)
    PRIMARY KEY (variable_name, dataset_id, source_id)
);

-- ============================================================
-- 7. Variable families: groups structurally identical variables
--    with different cycle-letter names
--    DuckDB-only, populated from cchsflow
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_families (
    family_id VARCHAR PRIMARY KEY,       -- canonical name (e.g., 'GEO_PRV' or cchsflow name)
    label VARCHAR,
    description VARCHAR
);

-- ============================================================
-- 8. Variable family members: maps cycle-specific names to families
--    DuckDB-only, populated from cchsflow
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_family_members (
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    family_id VARCHAR NOT NULL REFERENCES variable_families(family_id),
    dataset_id VARCHAR,                  -- optional: which dataset this name appears in
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (variable_name, family_id)
);

-- ============================================================
-- 9. Value codes: response categories per variable per dataset
--    DuckDB-only, populated during ingestion
--    Same code from different sources kept as separate rows
-- ============================================================
CREATE TABLE IF NOT EXISTS value_codes (
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    code VARCHAR NOT NULL,
    label VARCHAR,
    frequency INTEGER,                   -- unweighted count (from RData or DDI)
    frequency_weighted DOUBLE,           -- weighted count (from DDI catStat wgtd)
    is_range BOOLEAN DEFAULT FALSE,      -- TRUE if code represents a range (e.g., '012-121')
    range_low DOUBLE,                    -- lower bound of range (NULL if not a range)
    range_high DOUBLE,                   -- upper bound of range (NULL if not a range)
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (variable_name, dataset_id, code, source_id)
);

-- ============================================================
-- 10. Variable summary statistics: distributional stats per variable per dataset
--     DuckDB-only, populated from DDI XML sumStat elements
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_summary_stats (
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    stat_mean DOUBLE,                    -- DDI sumStat type="mean"
    stat_median DOUBLE,                  -- DDI sumStat type="medn"
    stat_mode VARCHAR,                   -- DDI sumStat type="mode" (can be '.')
    stat_stdev DOUBLE,                   -- DDI sumStat type="stdev"
    stat_min DOUBLE,                     -- DDI sumStat type="min"
    stat_max DOUBLE,                     -- DDI sumStat type="max"
    n_valid INTEGER,                     -- DDI sumStat type="vald"
    n_invalid INTEGER,                   -- DDI sumStat type="invd"
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (variable_name, dataset_id, source_id)
);

-- ============================================================
-- 11. Variable groups: module classifications per dataset
--     DuckDB-only, populated from DDI XML varGrp elements
--     e.g., "SMK: Smoking", "ALC: Alcohol use"
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_groups (
    group_id VARCHAR NOT NULL,           -- generated: dataset_id || '::' || group_code
    dataset_id VARCHAR NOT NULL REFERENCES datasets(dataset_id),
    group_code VARCHAR NOT NULL,         -- e.g., 'SMK', 'ALC', 'DIA'
    group_label VARCHAR NOT NULL,        -- e.g., 'Smoking', 'Alcohol use', 'Diabetes care'
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (group_id)
);

-- ============================================================
-- 12. Variable group members: which variables belong to which groups
--     DuckDB-only, populated from DDI XML varGrp var attribute
-- ============================================================
CREATE TABLE IF NOT EXISTS variable_group_members (
    group_id VARCHAR NOT NULL REFERENCES variable_groups(group_id),
    variable_name VARCHAR NOT NULL REFERENCES variables(variable_name),
    PRIMARY KEY (group_id, variable_name)
);

-- ============================================================
-- 13. Catalog metadata: key-value store for build info
-- ============================================================
CREATE TABLE IF NOT EXISTS catalog_metadata (
    key VARCHAR PRIMARY KEY,
    value VARCHAR
);


-- =============================================================================
-- Views
-- =============================================================================

-- Variable history across cycles
-- One row per (variable, dataset), best metadata merged from all sources
CREATE OR REPLACE VIEW v_variable_history AS
SELECT
    v.variable_name,
    COALESCE(v.label_short, v.label_statcan) AS label,
    d.year_start, d.year_end, d.temporal_type, d.release,
    vd.dataset_id,
    COALESCE(
        MAX(CASE WHEN vd.source_id = 'ddi_xml' THEN vd.label END),
        MAX(vd.label)
    ) AS dataset_label,
    COALESCE(
        MAX(CASE WHEN vd.source_id = 'ddi_xml' THEN vd.question_text END),
        MAX(vd.question_text)
    ) AS question_text,
    COALESCE(
        MAX(CASE WHEN vd.source_id = 'pumf_rdata' THEN vd.type END),
        MAX(vd.type)
    ) AS type,
    LIST(DISTINCT vd.source_id ORDER BY vd.source_id) AS sources
FROM variables v
JOIN variable_datasets vd ON v.variable_name = vd.variable_name
JOIN datasets d ON vd.dataset_id = d.dataset_id
GROUP BY v.variable_name, v.label_short, v.label_statcan,
         d.year_start, d.year_end, d.temporal_type, d.release, vd.dataset_id
ORDER BY v.variable_name, d.year_start;

-- Variable-dataset detail — all source rows preserved (for auditing)
CREATE OR REPLACE VIEW v_variable_datasets_detail AS
SELECT
    vd.variable_name, vd.dataset_id, vd.source_id,
    vd.label, vd.type, vd.position, vd.length,
    vd.question_text, vd.universe,
    vd.intrvl, vd.wgt_var, vd.notes,
    d.year_start, d.year_end, d.temporal_type, d.release
FROM variable_datasets vd
JOIN datasets d ON vd.dataset_id = d.dataset_id
ORDER BY vd.variable_name, d.year_start, vd.source_id;

-- Family history: trace a variable concept across cycles
CREATE OR REPLACE VIEW v_family_history AS
SELECT
    f.family_id, f.label AS family_label,
    fm.variable_name, vd.dataset_id,
    d.year_start, d.year_end, d.temporal_type, d.release,
    vd.label AS dataset_label, vd.type, vd.source_id
FROM variable_families f
JOIN variable_family_members fm ON f.family_id = fm.family_id
JOIN variable_datasets vd ON fm.variable_name = vd.variable_name
JOIN datasets d ON vd.dataset_id = d.dataset_id
ORDER BY f.family_id, d.year_start;

-- Dataset variable list with best labels (deduplicated across sources)
CREATE OR REPLACE VIEW v_dataset_variables AS
SELECT
    vd.dataset_id, vd.variable_name,
    COALESCE(
        MAX(CASE WHEN vd.source_id = 'ddi_xml' THEN vd.label END),
        MAX(vd.label),
        v.label_short,
        v.label_statcan
    ) AS label,
    COALESCE(
        MAX(CASE WHEN vd.source_id = 'pumf_rdata' THEN vd.type END),
        MAX(vd.type),
        v.type
    ) AS type,
    v.subject, v.section, v.cchsflow_name,
    MAX(vd.position) AS position,
    LIST(DISTINCT vd.source_id ORDER BY vd.source_id) AS sources
FROM variable_datasets vd
JOIN variables v ON vd.variable_name = v.variable_name
GROUP BY vd.dataset_id, vd.variable_name, v.label_short, v.label_statcan,
         v.type, v.subject, v.section, v.cchsflow_name
ORDER BY vd.dataset_id, position;

-- Dataset provenance: all sources for each dataset
CREATE OR REPLACE VIEW v_dataset_provenance AS
SELECT
    ds.dataset_id, d.release, d.year_start, d.year_end,
    s.source_id, s.source_name, s.authority,
    ds.source_detail, ds.first_seen, ds.last_verified
FROM dataset_sources ds
JOIN datasets d ON ds.dataset_id = d.dataset_id
JOIN sources s ON ds.source_id = s.source_id
ORDER BY ds.dataset_id, s.authority, s.source_id;

-- Variable group membership: which module each variable belongs to per dataset
CREATE OR REPLACE VIEW v_variable_groups AS
SELECT
    vgm.variable_name, vg.dataset_id,
    vg.group_code, vg.group_label,
    d.year_start, d.year_end
FROM variable_group_members vgm
JOIN variable_groups vg ON vgm.group_id = vg.group_id
JOIN datasets d ON vg.dataset_id = d.dataset_id
ORDER BY vg.dataset_id, vg.group_code, vgm.variable_name;

-- Source conflicts: label disagreements between sources for the same variable-dataset
CREATE OR REPLACE VIEW v_source_conflicts AS
SELECT
    vd1.variable_name, vd1.dataset_id,
    vd1.source_id AS source_a, vd1.label AS label_a,
    vd2.source_id AS source_b, vd2.label AS label_b,
    'label' AS conflict_type
FROM variable_datasets vd1
JOIN variable_datasets vd2
    ON vd1.variable_name = vd2.variable_name
    AND vd1.dataset_id = vd2.dataset_id
    AND vd1.source_id < vd2.source_id
WHERE vd1.label IS NOT NULL
    AND vd2.label IS NOT NULL
    AND vd1.label != vd2.label;

-- Value code conflicts: label disagreements between sources for the same code
CREATE OR REPLACE VIEW v_value_code_conflicts AS
SELECT
    vc1.variable_name, vc1.dataset_id, vc1.code,
    vc1.source_id AS source_a, vc1.label AS label_a,
    vc2.source_id AS source_b, vc2.label AS label_b
FROM value_codes vc1
JOIN value_codes vc2
    ON vc1.variable_name = vc2.variable_name
    AND vc1.dataset_id = vc2.dataset_id
    AND vc1.code = vc2.code
    AND vc1.source_id < vc2.source_id
WHERE vc1.label IS NOT NULL
    AND vc2.label IS NOT NULL
    AND vc1.label != vc2.label;
