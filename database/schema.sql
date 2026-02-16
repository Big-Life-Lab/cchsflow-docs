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
--   variable_families, variable_family_members, value_codes
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
    frequency INTEGER,                   -- from RData factor counts (NULL for DDI)
    source_id VARCHAR NOT NULL REFERENCES sources(source_id),
    PRIMARY KEY (variable_name, dataset_id, code, source_id)
);

-- ============================================================
-- 10. Catalog metadata: key-value store for build info
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
