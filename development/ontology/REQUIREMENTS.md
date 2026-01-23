# CCHS Variable Ontology: Requirements and Specifications

**Status**: Draft
**Version**: 0.1.0
**Last updated**: 2026-01-23

## 1. Background

### 1.1 Problem statement

The Canadian Community Health Survey (CCHS) has collected health data since 2000, with variable names, question wording, and response categories changing across cycles. Researchers need to harmonise variables across cycles to conduct trend analyses and pooled studies.

The `cchsflow` R package addresses this by providing worksheets that define variable mappings and generate recoding functions. However, the current approach has limitations:

1. **Opacity**: Worksheets define *what* maps to *what*, but not *why* or *how* variables differ
2. **Maintenance burden**: Each new cycle requires manual review and updates
3. **Discovery gap**: Researchers cannot easily find which variables are comparable across cycles
4. **No formal semantics**: Relationships are implicit in code, not explicitly modelled

### 1.2 Proposed solution

Develop a variable ontology that explicitly models relationships between CCHS variables, providing:

- Machine-readable relationship definitions
- Human-readable documentation of equivalence rationale
- Integration with existing cchsflow infrastructure
- Potential for automated harmonisation code generation

### 1.3 Scope

**In scope**:
- CCHS variable relationships across cycles (2001-present)
- Integration with scraped ICES metadata (14,005 variables)
- Support for cchsflow harmonisation workflows

**Out of scope** (for initial version):
- Cross-survey harmonisation (CCHS ↔ CHMS, international)
- Full semantic ontology with reasoning capabilities
- Real-time survey data validation

---

## 2. Use cases

### 2.1 Primary use case: Same variable, different name

**Actor**: Health researcher using cchsflow

**Scenario**: A researcher wants to analyse smoking status trends from 2001-2015 using Ontario Share files. The variable measuring "daily/occasional/non-smoker" status changed names:

| Cycle | Variable |
|-------|----------|
| 2001 (Cycle 1.1) | `SMKDSTY` |
| 2003+ (Cycle 2.1 onwards) | `SMK_005` |

**Current workflow**:
1. Consult cchsflow documentation or worksheets
2. Find the `rec_with_table()` call that handles this mapping
3. Trust that the mapping is correct (no explanation provided)

**Desired workflow**:
1. Search ontology for "smoking status" or `SMKDSTY`
2. See explicit relationship: `SMKDSTY same_variable_different_name SMK_005`
3. View evidence: "Question text identical, response categories identical, universe identical"
4. Optionally: Generate cchsflow recoding code from relationship

**Requirements derived**:
- R1.1: Store relationships between variable instances
- R1.2: Classify relationship types (same-variable-different-name is simplest)
- R1.3: Document evidence for each relationship
- R1.4: Support search/discovery by variable name or concept

### 2.2 Secondary use case: Derived variables with response recoding

**Scenario**: A variable exists across cycles but response categories changed. For example, a question with 5 response options in 2001 was simplified to 3 options in 2005.

**Requirements derived**:
- R2.1: Store value mappings (source codes → target codes)
- R2.2: Distinguish relationship types (same-name-different-coding vs derived)
- R2.3: Support bidirectional reasoning where applicable

### 2.3 Future use case: Conceptual hierarchy

**Scenario**: A researcher wants all variables related to "tobacco use" regardless of specific question type.

**Requirements derived**:
- R3.1: Support broader/narrower concept relationships
- R3.2: Allow grouping variables under abstract concepts

### 2.4 Future use case: Standard vocabulary linking

**Scenario**: Export CCHS variable metadata to a system that uses SNOMED-CT or LOINC codes.

**Requirements derived**:
- R4.1: Support links to external vocabularies
- R4.2: Maintain vocabulary version information

---

## 3. Requirements summary

### 3.1 Functional requirements

| ID | Requirement | Priority | Use case |
|----|-------------|----------|----------|
| R1.1 | Store relationships between variable instances | Must | 2.1 |
| R1.2 | Classify relationship types | Must | 2.1 |
| R1.3 | Document evidence for relationships | Must | 2.1 |
| R1.4 | Search/discover by variable name or concept | Must | 2.1 |
| R2.1 | Store value mappings | Should | 2.2 |
| R2.2 | Distinguish derived vs renamed variables | Should | 2.2 |
| R2.3 | Support bidirectional reasoning | Could | 2.2 |
| R3.1 | Support broader/narrower relationships | Could | 2.3 |
| R3.2 | Group variables under abstract concepts | Could | 2.3 |
| R4.1 | Link to external vocabularies | Won't (v1) | 2.4 |
| R4.2 | Track vocabulary versions | Won't (v1) | 2.4 |

### 3.2 Non-functional requirements

| ID | Requirement | Rationale |
|----|-------------|-----------|
| NF1 | Human-readable/editable format | Domain experts must review and contribute |
| NF2 | Version controllable | Track changes, enable collaboration |
| NF3 | Queryable | Support programmatic discovery |
| NF4 | Interoperable with existing tools | Integrate with DuckDB, cchsflow, R |
| NF5 | Extensible | Add relationship types without restructuring |

---

## 4. Existing approaches

This section reviews existing standards and tools for survey variable harmonisation and semantic modelling.

### 4.1 DDI (Data Documentation Initiative)

**Overview**: XML-based standard for documenting social science data. DDI Lifecycle (3.x) and DDI-CDI introduce concepts for variable comparison.

**Relevant concepts**:
- **ConceptualVariable**: Abstract concept independent of measurement
- **RepresentedVariable**: Concept with specified representation (value domain)
- **InstanceVariable**: Concrete variable in a specific dataset
- **VariableCascade**: Links variables across studies measuring same concept
- **Comparison module**: Explicitly designed for cross-study harmonisation

**Strengths**:
- Established standard, used by Statistics Canada
- CCHS has DDI metadata available
- Maelstrom Research uses DDI

**Limitations**:
- XML complexity, steep learning curve
- Comparison module underutilised and poorly documented
- Tooling ecosystem fragmented

**References**:
- DDI Alliance: https://ddialliance.org/
- DDI-CDI specification: https://ddialliance.org/Specification/DDI-CDI/
- Comparison module: DDI 3.2 Chapter 8

### 4.2 SKOS (Simple Knowledge Organization System)

**Overview**: W3C standard for knowledge organization systems (thesauri, taxonomies, classification schemes).

**Relevant concepts**:
- `skos:exactMatch`: Equivalent concepts across schemes
- `skos:closeMatch`: Similar but not identical
- `skos:broadMatch` / `skos:narrowMatch`: Hierarchical relationships
- `skos:related`: Associative relationship

**Strengths**:
- Simple, well-understood vocabulary
- RDF-based, interoperable
- Good for concept hierarchies

**Limitations**:
- Too generic for survey harmonisation specifics
- No support for value mappings or transformation logic
- Doesn't capture *why* concepts match

**References**:
- SKOS Reference: https://www.w3.org/TR/skos-reference/
- SKOS Primer: https://www.w3.org/TR/skos-primer/

### 4.3 OWL (Web Ontology Language)

**Overview**: W3C standard for defining ontologies with formal semantics and reasoning capabilities.

**Strengths**:
- Full logical inference
- Class hierarchies, property restrictions
- Established in biomedical informatics (SNOMED-CT, etc.)

**Limitations**:
- Overkill for survey harmonisation
- Steep learning curve
- Reasoning performance concerns at scale
- Poor tooling for non-ontologists

**References**:
- OWL 2 Overview: https://www.w3.org/TR/owl2-overview/

### 4.4 Maelstrom Research / Opal

**Overview**: Platform for epidemiological study harmonisation, developed at McGill.

**Approach**:
- **DataSchema**: Target harmonised variable definitions
- **Harmonization algorithms**: R/JavaScript code per variable per study
- **Opal server**: Central repository with MongoDB backend

**Strengths**:
- Proven at scale (dozens of cohort studies)
- Handles complex derivations
- Active development

**Limitations**:
- Server-dependent architecture
- Algorithms are code blobs, not structured relationships
- Limited support for explaining *why* variables match

**References**:
- Maelstrom Research: https://www.maelstrom-research.org/
- Opal documentation: https://opaldoc.obiba.org/
- Fortier et al. (2017) "Maelstrom Research guidelines for rigorous retrospective data harmonization"

### 4.5 LinkML (Linked Data Modeling Language)

**Overview**: YAML-based modelling language that generates multiple output formats (JSON Schema, SHACL, SQL, Python/TypeScript classes).

**Strengths**:
- Human-readable YAML source
- Generates validation schemas
- Already used in this project for catalog metadata
- Active development, good documentation

**Limitations**:
- Not designed specifically for ontologies
- Less expressive than OWL for inference
- Relatively new standard

**References**:
- LinkML: https://linkml.io/
- LinkML documentation: https://linkml.io/linkml/

### 4.6 Summary comparison

| Approach | Expressiveness | Usability | Tooling | Survey-specific |
|----------|---------------|-----------|---------|-----------------|
| DDI | High | Low | Medium | Yes |
| SKOS | Low | High | High | No |
| OWL | Very High | Low | Medium | No |
| Maelstrom | Medium | Medium | Low | Yes |
| LinkML | Medium | High | Medium | No |

---

## 5. Literature review scope

To inform the design, a more comprehensive review should examine:

### 5.1 Survey harmonisation methodology

- **Retrospective harmonisation**: Fortier et al. (2017), Doiron et al. (2013)
- **Prospective harmonisation**: Granda et al. (2010)
- **Harmonisation quality assessment**: Griffith et al. (2013)

### 5.2 DDI for comparison and harmonisation

- DDI Comparison module specifications and implementation guides
- Case studies using DDI for cross-study comparison
- DDI-CDI adoption in statistical agencies

### 5.3 Ontology design patterns for survey data

- OBOE (Extensible Observation Ontology)
- STATO (Statistics Ontology)
- Survey ontology patterns in social science

### 5.4 Knowledge graph approaches

- Property graphs vs RDF for survey metadata
- Graph databases for variable discovery (Neo4j, etc.)
- Hybrid approaches (YAML source → graph query)

### 5.5 Existing CCHS harmonisation work

- cchsflow design decisions and lessons learned
- Statistics Canada's own harmonisation approaches
- ICES and other RDC harmonisation practices

---

## 6. Open questions

1. **Granularity**: Should relationships be defined at the variable level or variable-cycle level?

2. **Transitivity**: If A same_as B and B same_as C, should we infer A same_as C, or require explicit assertions?

3. **Versioning**: How do we handle updates when we discover a relationship was incorrect?

4. **cchsflow integration**: Generate worksheets from ontology, or annotate existing worksheets with ontology references?

5. **Automation potential**: Can we auto-detect `same_variable_different_name` cases from question text matching?

---

## 7. Next steps

1. **Literature review**: Expand Section 5 with specific papers and findings
2. **DDI deep-dive**: Examine CCHS DDI files on Maelstrom for comparison module usage
3. **cchsflow audit**: Document current worksheet structure and identify gaps
4. **Prototype**: Small YAML example for smoking variables to test schema
5. **Stakeholder input**: Review with cchsflow maintainers and users

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Harmonisation** | Process of making variables comparable across datasets or time periods |
| **Variable instance** | A specific variable in a specific dataset/cycle |
| **Conceptual variable** | Abstract concept measured by one or more variable instances |
| **Pass-through** | Harmonisation where no recoding is needed (1:1 mapping) |
| **Derived variable** | Variable computed from one or more source variables |

## Appendix B: Document history

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1.0 | 2026-01-23 | cchsflow-docs | Initial draft |
