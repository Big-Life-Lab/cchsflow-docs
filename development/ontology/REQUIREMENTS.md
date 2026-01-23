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

## 5. Literature review

### 5.1 Survey harmonisation methodology

#### Maelstrom Research guidelines (Fortier et al. 2017)

The definitive methodological framework for retrospective data harmonisation comes from Maelstrom Research. [Fortier et al. (2017)](https://academic.oup.com/ije/article/46/1/103/2617181) developed guidelines through three initiatives between 2006-2015: a phone survey with 34 major international research initiatives, expert workshops, and case studies.

**Key findings**:
- Wide range of projects use retrospective harmonisation, but terminologies, procedures, technologies and methods vary markedly
- Input from 100+ investigators across 15+ countries
- Harmonisation requires balancing precision (exact matching) against breadth (accepting heterogeneity)
- Definitions of target variables and harmonisation potential are context-specific

**Process steps**:
1. Define research questions, objectives, and protocol
2. Assemble information and select studies
3. Define target variables (DataSchema)
4. Process data and evaluate harmonisation potential
5. Estimate quality of harmonised variables

**Relevance**: The Maelstrom approach separates *what* to harmonise (DataSchema) from *how* (algorithms), but doesn't formally model *why* variables are considered equivalent.

**References**:
- [Maelstrom Research guidelines for rigorous retrospective data harmonization](https://academic.oup.com/ije/article/46/1/103/2617181) (Int J Epidemiol, 2017)
- [Maelstrom Guidelines website](https://www.maelstrom-research.org/page/maelstrom-guidelines)
- [Fostering population-based cohort data discovery: The Maelstrom Research cataloguing toolkit](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0200926) (PLOS ONE, 2018)

#### QuickCharmStats: Documentation standards (Kolczynska 2022)

[Kolczynska (2022)](https://journals.sagepub.com/doi/10.1177/20597991221077923) addresses a gap: comparative statistical analyses require harmonisation, yet there are no agreed documentation standards or journal requirements for reporting harmonisation decisions.

**Key insight**: "The social sciences do not have clear operationalisation frameworks that guide and homogenise variable coding decisions across disciplines."

[QuickCharmStats](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0147795) was proposed as open-source software for organising, documenting, and publishing data harmonisation projects. Future versions aim to import DDI metadata directly.

**Relevance**: Highlights the need for explicit documentation of harmonisation rationale—exactly what we propose with the ontology.

### 5.2 DDI for comparison and harmonisation

#### DDI variable cascade

The [DDI variable cascade](https://ddi4.readthedocs.io/en/latest/userguides/variablecascade.html) provides a model for describing variables from conception to use in datasets, drawing on the Generic Statistical Information Model (GSIM) and ISO/IEC 11179.

**Key concepts**:
- **Conceptual Variable**: Abstract concept (e.g., "smoking status")
- **Represented Variable**: Concept + value domain (e.g., "smoking status measured as daily/occasional/never")
- **Instance Variable**: Concrete variable in a specific dataset

**Challenge identified**: "Each time in the processing cascade the list of sentinel values changes, the value domain changes, which forces the variable to change as well... this variable proliferation is unmanageable and unsustainable."

**Relevance**: The cascade model maps well to our use case (same concept, different instance variables across cycles), but DDI's XML implementation is heavy.

**References**:
- [The Variable Cascade — DDI 4.0 documentation](https://ddi4.readthedocs.io/en/latest/userguides/variablecascade.html)
- [DDI Alliance webinar: The DDI Variable Cascade](https://ddialliance.org/news/news/news-247.html) (March 2023)

#### DDI-CDI (Cross-Domain Integration)

[DDI-CDI Version 1.0](https://ddialliance.org/Specification/ddi-cdi) was released in January 2025. It is a model-driven, domain-neutral specification designed for combining data from diverse sources.

**Variable comparison in DDI-CDI**: Comparable instance variables should have:
- Same unit of measurement
- Same intended data type
- Same substantive value domain
- Sentinel values from same set
- Same sentinel (missing value) concepts
- Population drawn from same universe

**Key innovation**: DDI-CDI is explicitly designed to work with other standards (PROV-O, BPMN, DCAT, SDMX, Schema.org) and supports data integration/harmonisation functions.

**Relevance**: DDI-CDI's comparability criteria align closely with our `same_variable_different_name` relationship type.

**References**:
- [DDI-CDI specification](https://ddialliance.org/Specification/ddi-cdi)
- [CODATA: DDI Cross-Domain Integration](https://codata.org/initiatives/making-data-work/ddi-cross-domain-integration/)
- [WorldFAIR Pilot Testing Harmonisation Workflows](https://zenodo.org/records/10724744) (2024)

#### DDI case studies

The European DDI User Conference has published relevant case studies:
- "Application of DDI Comparison Capabilities to a Multi-Site Sexual Behaviour Data Harmonisation Exercise"
- "French electoral surveys data harmonization based on DDI-L foundational constructs" ([Zenodo](https://zenodo.org/records/7405370))
- [ATHLOS Project: Data harmonization of longitudinal studies on healthy ageing](https://pmc.ncbi.nlm.nih.gov/articles/PMC6184037/)

### 5.3 Ontology design patterns for survey data

#### OBOE (Extensible Observation Ontology)

[OBOE](https://github.com/NCEAS/oboe) is a formal ontology for scientific observation and measurement, developed at NCEAS.

**Core model**:
- **Observation**: About an Entity, provides context for other Observations
- **Measurement**: Of a Characteristic of an Entity
- **Measurement Standard**: Unit, precision, protocol

**Extensibility**: OBOE provides extension points for domain-specific Entity, Characteristic, and Measurement Standard classes.

**Relevance**: OBOE's observation model could inform how we represent survey questions (observations) and responses (measurements), but it's designed for ecological data rather than social surveys.

**References**:
- [OBOE GitHub repository](https://github.com/NCEAS/oboe)
- [OBOE on BioPortal](https://bioportal.bioontology.org/ontologies/OBOE)
- Madin et al. (2007) "An ontology for describing and synthesizing ecological observation data" (Ecological Informatics)

#### STATO (Statistics Ontology)

[STATO](https://stato-ontology.org/) is a general-purpose statistics ontology covering statistical tests, probability distributions, variables, and experimental design.

**Coverage**:
- Statistical methods and tests
- Conditions of application
- Probability distributions
- Plots and graphical representations

**Use case**: Provides formal definitions of statistical tests to support standardised analysis reports and text mining of statistical analyses.

**Relevance**: STATO could provide vocabulary for describing analysis-related metadata, but doesn't address survey variable harmonisation directly.

**References**:
- [STATO website](https://stato-ontology.org/)
- [STATO on OBO Foundry](http://obofoundry.org/ontology/stato.html)

#### COOS (Core Ontology for Official Statistics)

[COOS](https://linked-statistics.github.io/COOS/coos.html) is an RDF/OWL vocabulary for official statistics, describing statistical processes, products, and organisations.

**Relevance**: May provide useful vocabulary for describing Statistics Canada processes, but focused on organisational/process metadata rather than variable semantics.

### 5.4 Knowledge graph and LinkML approaches

#### Knowledge graphs for survey metadata

Knowledge graphs provide structured representation of entities and relationships, enabling:
- Data integration across heterogeneous sources
- Semantic interoperability through shared vocabulary
- Advanced reasoning and inference

**Property graphs vs RDF**: Property graphs (Neo4j, etc.) offer simpler querying but less semantic richness than RDF. For our use case, a hybrid approach (YAML source → queryable store) may be optimal.

**References**:
- [Knowledge Graphs and Ontologies in Semantic Web Applications](https://www.nature.com/research-intelligence/nri-topic-summaries/knowledge-graphs-and-ontologies-in-semantic-web-applications-micro-92) (Nature Research Intelligence)

#### LinkML for survey metadata

[LinkML](https://linkml.io/) bridges data formats (JSON, relational, RDF) while providing semantic grounding through URI mappings.

**Key features for our use case**:
- YAML authoring for human readability
- Generates JSON Schema, SHACL, SQL schemas
- Supports metadata annotations
- Used by DataHarmonizer for sample/specimen metadata

**Relevance**: LinkML is already used in this project for catalog metadata. Extending it for variable relationships maintains consistency and leverages existing tooling.

**References**:
- [LinkML documentation](https://linkml.io/linkml/)
- [The Linked Data Modeling Language (LinkML): A General-Purpose Framework](https://ceur-ws.org/Vol-3073/paper24.pdf)

### 5.5 Existing CCHS harmonisation work

#### cchsflow R package

[cchsflow](https://big-life-lab.github.io/cchsflow/) transforms and harmonises CCHS variables across cycles (2001-2018).

**Architecture**:
- `variables.csv` worksheet: Describes variable mappings
- `variable_details.csv`: Recoding specifications
- `rec_with_table()` function: Applies transformations

**Documented limitations** (from cchsflow documentation):
- "Combining CCHS across survey cycles will result in misclassification error and other forms of bias"
- "Almost all CCHS variables have had at least some change in wording and category responses"
- "Changes in survey sampling, response rates, weighting methods and other survey design changes"

**Gap identified**: The worksheets define transformations but don't explain *why* variables are considered equivalent or document the evidence for equivalence decisions.

**Related package**: [recodeflow](https://big-life-lab.github.io/recodeflow/) provides generic recoding functions that cchsflow builds upon.

**References**:
- [cchsflow on CRAN](https://cran.r-project.org/web/packages/cchsflow/index.html)
- [cchsflow GitHub repository](https://github.com/Big-Life-Lab/cchsflow)
- [Variables sheet vignette](https://github.com/Big-Life-Lab/cchsflow/blob/main/vignettes/variables_sheet.Rmd)

### 5.6 Summary of gaps

| Approach | Captures equivalence | Documents evidence | Machine-readable | Human-editable |
|----------|---------------------|-------------------|-----------------|----------------|
| DDI Comparison | Yes | Partially | Yes (XML) | No |
| DDI-CDI | Yes | Yes | Yes (XML/JSON) | No |
| Maelstrom | Yes | No (code only) | Partially | No |
| cchsflow | Yes | No | CSV | Yes |
| SKOS | Partially | No | Yes (RDF) | No |
| **Proposed** | Yes | Yes | Yes (YAML→DB) | Yes |

The proposed ontology addresses the gap: explicit, documented variable relationships in a human-editable format that can be queried programmatically and integrated with existing cchsflow workflows

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
