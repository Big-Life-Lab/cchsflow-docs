-- =============================================================================
-- CCHS Unified Metadata Schema (DuckDB)
-- Version: 1.0.0
-- See: development/redevelopment/PROPOSAL_mcp_metadata_architecture.md
-- =============================================================================

-- 1. Datasets
-- Cycle and file_type are parsed from dataset_id to support
-- compare_master_pumf() and cycle-based filtering.
CREATE TABLE IF NOT EXISTS datasets (
    dataset_id VARCHAR PRIMARY KEY,
    cycle VARCHAR,
    file_type VARCHAR,
    variable_count INTEGER
);

-- 2. Variables: one row per unique variable name
CREATE TABLE IF NOT EXISTS variables (
    variable_name VARCHAR PRIMARY KEY,
    label VARCHAR,
    type VARCHAR,
    format VARCHAR,
    dataset_count INTEGER
);

-- 3. Variable availability: which variables appear in which datasets
CREATE TABLE IF NOT EXISTS variable_availability (
    variable_name VARCHAR,
    dataset_id VARCHAR,
    PRIMARY KEY (variable_name, dataset_id)
);

-- 4. Response categories (normalised storage)
CREATE TABLE IF NOT EXISTS value_formats (
    format_name VARCHAR,
    code VARCHAR,
    label VARCHAR
);

-- 5. DDI enrichment: question text, universe logic, categories
CREATE TABLE IF NOT EXISTS ddi_variables (
    variable_name VARCHAR,
    dataset_id VARCHAR,
    label_en VARCHAR,
    question_text VARCHAR,
    universe_logic VARCHAR,
    notes VARCHAR,
    categories_json VARCHAR,
    source_filename VARCHAR,
    PRIMARY KEY (variable_name, dataset_id)
);

-- 6. Ontology stubs: empty in v1, ready for immediate use
CREATE TABLE IF NOT EXISTS ontology_concepts (
    concept_id VARCHAR PRIMARY KEY,
    preferred_label VARCHAR,
    description VARCHAR
);

CREATE TABLE IF NOT EXISTS variable_concepts (
    variable_name VARCHAR,
    concept_id VARCHAR,
    match_confidence FLOAT DEFAULT 1.0,
    match_source VARCHAR,
    PRIMARY KEY (variable_name, concept_id)
);

-- 7. Catalog metadata
CREATE TABLE IF NOT EXISTS catalog_metadata (
    key VARCHAR PRIMARY KEY,
    value VARCHAR
);

-- =============================================================================
-- Views
-- =============================================================================

-- v_variable_detail: primary view for MCP tools
-- Returns full context in a single query so LLM agents get everything
-- in one round-trip.
CREATE OR REPLACE VIEW v_variable_detail AS
SELECT
    v.variable_name,
    v.label,
    v.type,
    v.format,
    d.question_text,
    d.universe_logic,
    d.categories_json,
    ds.cycle,
    ds.file_type,
    va.dataset_id
FROM variables v
JOIN variable_availability va ON v.variable_name = va.variable_name
JOIN datasets ds ON va.dataset_id = ds.dataset_id
LEFT JOIN ddi_variables d
    ON v.variable_name = d.variable_name
    AND va.dataset_id = d.dataset_id;

-- v_variable_history: trace a variable across cycles
CREATE OR REPLACE VIEW v_variable_history AS
SELECT
    v.variable_name,
    v.label,
    ds.cycle,
    ds.file_type,
    ds.dataset_id,
    d.question_text
FROM variables v
JOIN variable_availability va ON v.variable_name = va.variable_name
JOIN datasets ds ON va.dataset_id = ds.dataset_id
LEFT JOIN ddi_variables d
    ON v.variable_name = d.variable_name
    AND va.dataset_id = d.dataset_id
ORDER BY v.variable_name, ds.cycle;
