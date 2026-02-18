# Terminology mapping: Ontology ↔ cchsflow worksheets

This document maps ontology concepts to existing cchsflow worksheet terminology to ensure consistency.

## Core principle

The ontology uses DDI Variable Cascade terminology for theoretical rigour, but **field names in YAML should align with cchsflow conventions** where possible to reduce cognitive load.

## Terminology mapping

### Variable Cascade → cchsflow

| DDI Cascade term | cchsflow equivalent | Notes |
|------------------|---------------------|-------|
| **Conceptual Variable** | `sub_subject` | Abstract concept (e.g., "status", "intensity", "initiation") |
| **Represented Variable** | `variable` + `variableType` | Harmonised variable with value domain (e.g., `SMKDSTY_A` Categorical 6-cat) |
| **Instance Variable** | `variableStart` entry | Cycle-specific source variable (e.g., `cchs2007_p::SMKDSTY`) |

### Relationship metadata

| Ontology term | cchsflow equivalent | Notes |
|---------------|---------------------|-------|
| `source` | `variableStart` | The cycle-specific source variable |
| `target` | `variable` | The harmonised target variable |
| `harmonisation_potential` | (new) | Complete/Partial/Impossible - add to notes or new field |
| `confidence` | (new) | 1.0 = manual review, <1.0 = automated |
| `evidence` | (implicit in notes) | Could formalise in structured field |

### Grouping hierarchy

| DDI term | cchsflow term | Example |
|----------|---------------|---------|
| Domain | `section` | "Health behaviour" |
| Concept family | `subject` | "Smoking" |
| Concept | `sub_subject` | "status", "intensity", "initiation", "cessation" |

### Recommendation levels

From cchsflow notes field pattern `{recommended:X}`:

| Level | Meaning | Ontology equivalent |
|-------|---------|---------------------|
| `primary` | Preferred variable for most analyses | Use as canonical Represented Variable |
| `secondary` | Valid alternative, use-case specific | Alternative operationalisation |
| (none) | Standard variable, no special status | - |

## Proposed ontology field names

Based on alignment with cchsflow:

```yaml
# Conceptual grouping (matches cchsflow hierarchy)
conceptual_variables:
  - id: smoking-status
    label: "Smoking status"
    section: "Health behaviour"     # matches cchsflow section
    subject: "Smoking"              # matches cchsflow subject
    sub_subject: "status"           # matches cchsflow notes {sub_subject:X}

# Represented variable (harmonised variable spec)
represented_variables:
  - id: smoking-status-6cat
    label: "Type of smoker (6 categories)"
    conceptual_variable: smoking-status
    variable_type: "Categorical"    # matches cchsflow variableType
    recommended: "primary"          # matches cchsflow {recommended:X}
    value_domain:
      - code: 1
        label: "Daily"
        label_long: "Daily smoker"  # matches cchsflow catLabelLong
      # ...

# Instance variable (cycle-specific source)
instance_variables:
  - id: cchs2007-SMKDSTY
    variable_name: SMKDSTY          # the raw CCHS variable name
    represented_variable: smoking-status-6cat
    database: cchs2007_p            # matches cchsflow databaseStart format
    # Note: This is the variableStart in cchsflow worksheets

# Relationships
relationships:
  - id: rel-smkdsty-chain-001
    type: same_variable_different_name
    source: cchs2001-SMKADSTY       # variableStart for 2001
    target: cchs2007-SMKDSTY        # variableStart for 2007
    harmonisation_potential: complete
    evidence:
      question_text_match: exact
      response_categories_match: exact
      universe_match: exact
    rationale: "Prefix change SMKA→SMK; question unchanged"
    confidence: 1.0
```

## Existing patterns in cchsflow notes

The `notes` field in variables.csv already contains structured metadata using curly-brace tags:

```
{recommended:primary} {sub_subject:status} Full coverage 2001-2023...
```

### Current tags observed

| Tag | Values seen | Purpose |
|-----|-------------|---------|
| `{recommended:X}` | `primary`, `secondary` | Indicates preferred variable for use case |
| `{sub_subject:X}` | `status`, `intensity`, `initiation`, `cessation`, `pack-years` | Conceptual variable grouping |

### Proposed additional tags

| Tag | Values | Purpose |
|-----|--------|---------|
| `{harmonisation:X}` | `complete`, `partial`, `impossible` | Maelstrom status |
| `{ontology_ref:X}` | Ontology relationship ID | Cross-reference to ontology |

## Design decision: Ontology complements, doesn't replace

The ontology provides:
- Explicit relationship documentation with evidence
- Query-able structure for discovery
- Confidence scoring for automated matches

The worksheets remain authoritative for:
- Recoding instructions (`recStart`, `recEnd`)
- Database coverage (`databaseStart`)
- Operational metadata (`status`, `version`)

The two systems reference each other via IDs but don't duplicate information.

## Examples of alignment

### cchsflow worksheet entry

```csv
"SMKDSTY_A","Smoking (6-cat pre-2015)","Type of smoker...","Categorical",
"cchs2001_p, cchs2003_p, ...",
"cchs2001_p::SMKADSTY, cchs2003_p::SMKCDSTY, cchs2005_p::SMKEDSTY, cchs2007_2008_p::SMKDSTY, ...",
"Smoking","Health behaviour","N/A",
"{recommended:primary} {sub_subject:status} Full coverage 2001-2023..."
```

### Corresponding ontology entry

```yaml
instance_variables:
  - id: iv-smkadsty-2001
    variable_name: SMKADSTY
    represented_variable: rv-smoking-status-6cat
    database: cchs2001_p

  - id: iv-smkcdsty-2003
    variable_name: SMKCDSTY
    represented_variable: rv-smoking-status-6cat
    database: cchs2003_p

  - id: iv-smkdsty-2007
    variable_name: SMKDSTY
    represented_variable: rv-smoking-status-6cat
    database: cchs2007_2008_p

relationships:
  - id: rel-smkdsty-2001-2003
    type: same_variable_different_name
    source: iv-smkadsty-2001
    target: iv-smkcdsty-2003
    harmonisation_potential: complete
    evidence:
      question_text_match: exact
      response_categories_match: exact
    rationale: "Prefix SMKA→SMKC for 2003 cycle"

  - id: rel-smkdsty-2003-2007
    type: same_variable_different_name
    source: iv-smkcdsty-2003
    target: iv-smkdsty-2007
    harmonisation_potential: complete
    evidence:
      question_text_match: exact
      response_categories_match: exact
    rationale: "Prefix dropped from SMKC to SMK for 2007+ cycles"
```

## DDI XML ID structure analysis

Reviewed actual DDI XML files to understand how Statistics Canada assigns variable IDs.

### DDI ID attributes observed

| Cycle | DDI ID | Variable Name | XML Element |
|-------|--------|---------------|-------------|
| 2003 (C2.1) | `V694` | `SMKCDSTY` | `<var ID="V694" name="SMKCDSTY">` |
| 2007-2008 | `V622` | `SMKDSTY` | `<var ID="V622" name="SMKDSTY">` |
| 2015-2016 | `V238` | `SMKDVSTY` | `<var ID="V238" name="SMKDVSTY">` |

### Key findings

1. **DDI `ID` attribute** (e.g., `V622`) is a **sequential position identifier**—it represents the variable's position in the file, not a semantic identifier
2. **DDI `name` attribute** (e.g., `SMKDSTY`) is the **human-meaningful identifier**—this is what researchers use
3. The DDI ID changes across cycles even for the same underlying concept (V694 → V622 → V238)
4. DDI `name` also changes across cycles due to Statistics Canada's prefix conventions (SMKCDSTY → SMKDSTY → SMKDVSTY)

### Design implication

**The variable name is the natural key, not abstract IDs.**

The DDI `ID` attribute is essentially useless for cross-cycle harmonisation—it's just a file offset. The `name` attribute is what people recognise and search for.

### Recommended ID scheme for ontology

Given this finding, propose a **variable-name-centric ID scheme**:

```yaml
# Instance variables keyed by variable name
instance_variables:
  SMKDSTY:                           # Variable name IS the key
    cycles:
      cchs2007_2008_p:               # Database as sub-key
        label: "Type of smoker - (D)"
        represented_variable: rv-smoking-type-6cat
        ddi_id: V622                 # Optional: DDI reference for provenance
      cchs2009_2010_p:
        label: "Type of smoker - (D)"
        represented_variable: rv-smoking-type-6cat
        ddi_id: V...
      # ... continues for all cycles where this name appears

  SMKCDSTY:                          # Earlier name
    cycles:
      cchs2003_p:
        label: "Type of smoker - (D)"
        represented_variable: rv-smoking-type-6cat
        ddi_id: V694

# Relationships reference variable names directly
relationships:
  - type: same_variable_different_name
    variables:
      - SMKADSTY                     # 2001
      - SMKCDSTY                     # 2003
      - SMKEDSTY                     # 2005
      - SMKDSTY                      # 2007-2014
      - SMKDVSTY                     # 2015+
    harmonisation_potential: complete
    evidence:
      question_text_match: exact
      response_categories_match: exact
    rationale: "Statistics Canada prefix changes; underlying question unchanged"
```

### Benefits of variable-name-as-key

1. **Natural lookup**: Query "what is SMKDSTY?" returns all cycles where it appears
2. **Human readable**: Relationships show actual variable names, not abstract IDs
3. **Aligns with cchsflow**: `variableStart` uses variable names, not IDs
4. **Matches researcher mental model**: People search by variable name, not by cycle+abstract-id

### Alternative: Flat structure with composite key

If hierarchical YAML proves awkward, use `database::variable_name` as the key:

```yaml
instance_variables:
  - key: "cchs2007_2008_p::SMKDSTY"   # Composite key (matches variableStart format)
    variable_name: SMKDSTY
    database: cchs2007_2008_p
    label: "Type of smoker - (D)"
    represented_variable: rv-smoking-type-6cat

relationships:
  - type: same_variable_different_name
    source: "cchs2003_p::SMKCDSTY"
    target: "cchs2007_2008_p::SMKDSTY"
    harmonisation_potential: complete
```

This mirrors the `variableStart` format exactly (`cchs2007_2008_p::SMKDSTY`).

---

## Open questions

1. **Variable-name-as-key vs composite-key?**
   - Option A: Variable name is primary key, cycles nested beneath
   - Option B: Composite key `database::variable_name` (matches variableStart)
   - **Recommendation**: Option B for simplicity and direct alignment with cchsflow

2. **How to handle the {recommended} tag?**
   - Currently in notes field with curly braces
   - Could be elevated to a proper worksheet column
   - Ontology should reference this when identifying canonical operationalisations

3. **Database suffix convention (_p, _m)?**
   - cchsflow uses `_p` (PUMF), `_m` (Master)
   - Ontology should follow same convention for `database` field

---

## Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2026-01-23 | Initial draft mapping DDI terms to cchsflow conventions |
