# Architecture & specifications: CCHS harmonization agent

## 1. System goals

This architecture allows an LLM Agent (via MCP) to act as a "Research Assistant" for cchsflow developers.

* **Input:** "Add the 2015-2024 Master file logic for the *Fruit & Vegetable Consumption* derived variable."
* **Mechanism:** Agent queries DuckDB for raw definitions → Compares with legacy logic → Generates R code.
* **Output:** Valid row_bind R syntax for variable_details.csv.

## 2. Component diagram

```
graph TD
  A[User / R Developer] -->|Natural Language Query| B(MCP Server / Agent)
  B -->|SQL Queries| C{DuckDB Database}
  C -->|Returns Schema & Values| B

  D[Raw PDFs/CSVs] -->|Ingestion Scripts| C
  E[Current cchsflow Package] -->|variable_details.csv| C

  B -->|Generates| F[R Code / Pull Request]
```

## 3. The Model Context Protocol (MCP) strategy

We will not just "dump" text into the context. We will use **Tool-Use**.

### Required MCP tools

The Agent must have access to these specific functions backed by the DuckDB:

#### get_variable_history(concept_keyword)

* **Purpose:** Traces a concept across years.
* **SQL Logic:** `SELECT cycle_id, variable_name, label_en FROM raw_variables WHERE label_en ILIKE ? ORDER BY cycle_id`

#### compare_master_pumf(variable_name, cycle)

* **Purpose:** Detects granularity loss.
* **SQL Logic:** Retrieves categories_json for both 'MASTER' and 'PUMF' for the given variable and returns a diff.
* **Use Case:** The Agent realises Master has "Height in cm" (Continuous) while PUMF has "Height Range" (Categorical), and adjusts the R recode logic accordingly.

#### check_existing_harmonization(target_var)

* **Purpose:** Formatting consistency.
* **Logic:** Returns the existing rows from cchsflow_definitions for previous years (e.g., 2014) to use as a template for 2015+.

## 4. Ontology-driven discovery

The system now supports semantic relationships. The Agent acts as a graph traverser.

### The "synonym" workflow

When a user asks to harmonize "Smoking", the Agent does not just search for the string "SMOKE".

1. **Concept Lookup:** Agent queries ontology_concepts to find CONCEPT_SMOKING_STATUS.
2. **Synonym Retrieval:** Agent queries v_synonyms to find *every* variable name ever linked to this concept (SMK_203, SMKG203, SMK_01A).
3. **Result:** The Agent automatically identifies the correct variable for the 2024 cycle, even if the name changed completely, without the user needing to know the new acronym.

### The "parent/child" (derivation) workflow

When harmonizing a derived variable (e.g., BMI):

1. Agent checks variable_relationships for target_node = 'BMI'.
2. DB returns source_node = 'HEIGHT' and source_node = 'WEIGHT' with relationship PARENT.
3. Agent knows it **must** harmonize Height and Weight *first* (or check their existence) before attempting to calculate BMI.

## 5. Harmonization workflow (the "loop")

1. **Discovery:** Agent queries raw_variables to find the new variable names for 2015-2024 (e.g., discovering WTM_123 changed to WTM_456).
2. **Granularity Check:** Agent checks file_type='MASTER'.
   * *If Master:* It attempts to keep continuous values.
   * *If PUMF:* It looks for the "Not Stated" codes (9, 99) in missing_codes_json.
3. **Code Generation:** Agent formats the output as a CSV row matching cchsflow standards:
   * variable: "WTM_Der"
   * source_var: "WTM_456"
   * rec_from: "ELSE"
   * rec_to: "WTM_456"
4. **Validation:** Agent verifies that the rec_to logic covers all keys found in categories_json.

## 6. Technical requirements

* **Database:** DuckDB (v0.9.0+)
* **Language:** Python (for MCP Server) OR R (for DB Build scripts).
* **Embedding:** Optional. If variable labels are vague, we may generate vector embeddings for label_en to allow semantic search (e.g., finding "Smoking" variables even if labelled "Tobacco Use").
