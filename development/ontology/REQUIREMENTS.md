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

### 1.3 Architectural principle: Schema-First vs Code-First

The literature (see Section 5 and the [Variable Relationship Modelling Review](variable_relationship_modelling_review.md)) identifies a fundamental dichotomy in harmonisation approaches:

| Philosophy | Artefact | Purpose | Examples |
|------------|----------|---------|----------|
| **Schema-First** | Metadata (XML, YAML, RDF) | Declarative mapping—*what* is equivalent and *why* | DDI, OWL ontologies |
| **Code-First** | Code (R scripts, CSV tables) | Procedural logic—*how* to transform | Maelstrom Rmonize, cchsflow |

**cchsflow is deliberately Code-First**: flat CSVs for universal readability, machine-actionability, and version control transparency.

**This ontology is Schema-First**: it captures the conceptual logic and evidence for equivalence decisions.

**They are complementary, not competing**:
- The ontology documents *what* is equivalent and *why*
- The worksheets specify *how* to transform
- They inform each other but serve different purposes
- There is no requirement for 1:1 mapping between ontology relationships and worksheet rows

### 1.4 Scope

**In scope**:
- CCHS variable relationships across cycles (2001-present)
- Integration with scraped ICES metadata (14,005 variables)
- Support for cchsflow harmonisation workflows
- Documentation of evidence and rationale for equivalence decisions

**Out of scope** (for initial version):
- Cross-survey harmonisation (CCHS ↔ CHMS, international)
- Full semantic ontology with reasoning capabilities
- Real-time survey data validation
- Automatic generation of cchsflow worksheets (future goal)

### 1.5 Theoretical foundation: The Variable Cascade

The DDI Variable Cascade (adopted by DDI-CDI and GSIM) provides the foundational model for understanding variable relationships across time. It decomposes a "survey variable" into three levels of abstraction:

```
Conceptual Variable → Represented Variable → Instance Variable
     (what)              (how encoded)         (where stored)
```

**Conceptual Variable**: The most abstract layer—defines the semantics independent of representation. Answers: *What is being measured?* Example: "Current smoking frequency" (no information about codes or categories).

**Represented Variable**: Adds specificity about the value domain and measurement. Answers: *How is the concept encoded?* Example: "Smoking status measured as daily/occasional/not at all" (specifies the categories but not the dataset).

**Instance Variable**: The physical realisation in a specific dataset. Answers: *Where is the data stored?* Example: `SMKDSTY` in CCHS 2001-p, `SMK_005` in CCHS 2003-p (includes variable name, data type, dataset location).

**Implications for relationship modelling**:

| Shared level | Relationship type | Implication |
|--------------|-------------------|-------------|
| Represented Variable | `same_variable_different_name` | Structurally identical—can merge directly |
| Conceptual Variable only | `derived` or `related` | Semantically linked but transformation required |
| Neither | `impossible` | No harmonisation possible |

This cascade model directly informs our data model design (Section 7).

---

## 2. Use cases

### 2.1 Primary use case: Same variable, different name (Complete harmonisation)

**Actor**: Health researcher using cchsflow

**Scenario**: A researcher wants to analyse smoking status trends from 2001-2015 using Ontario Share files. The variable measuring "daily/occasional/non-smoker" status changed names:

| Cycle | Variable | Question |
|-------|----------|----------|
| 2001 (Cycle 1.1) | `SMKDSTY` | "At the present time, do you smoke cigarettes daily, occasionally or not at all?" |
| 2003+ (Cycle 2.1 onwards) | `SMK_005` | "At the present time, do you smoke cigarettes daily, occasionally or not at all?" |

Both have identical response categories (1=Daily, 2=Occasionally, 3=Not at all) and universe (age 12+).

**Harmonisation Potential**: **Complete** (no information loss)

**Current workflow**:
1. Consult cchsflow documentation or worksheets
2. Find the `rec_with_table()` call that handles this mapping
3. Trust that the mapping is correct (no explanation provided)

**Desired workflow**:
1. Search ontology for "smoking status" or `SMKDSTY`
2. See explicit relationship: `SMKDSTY same_variable_different_name SMK_005`
3. View evidence: "Question text identical, response categories identical, universe identical"
4. View Harmonisation Potential status: Complete
5. Optionally: Generate cchsflow recoding code from relationship

**Requirements derived**:
- R1.1: Store relationships between variable instances
- R1.2: Classify relationship types (same-variable-different-name is simplest)
- R1.3: Document evidence for each relationship
- R1.4: Support search/discovery by variable name or concept
- R1.5: Include Harmonisation Potential status (Complete/Partial/Impossible)

### 2.2 Secondary use case: Response category changes (Partial harmonisation)

**Scenario**: Self-rated health has been asked consistently across CCHS cycles, but response categories changed:

| Cycle | Variable | Response categories |
|-------|----------|-------------------|
| 2001 | `GENDHDI` | 1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor |
| 2003+ | `GEN_005` | 1=Excellent, 2=Very good, 3=Good, 4=Fair, 5=Poor |

In this case, the variable name changed but categories remained identical—still a **Complete** harmonisation.

**More complex example** (hypothetical): Alcohol consumption frequency

| Cycle | Variable | Response categories |
|-------|----------|-------------------|
| Early | `ALC_1` | 1=Daily, 2=4-6/week, 3=2-3/week, 4=Once/week, 5=Once/month, 6=<Once/month, 7=Never |
| Later | `ALC_2` | 1=Daily/almost daily, 2=Weekly, 3=Monthly, 4=Less than monthly, 5=Never |

**Harmonisation Potential**: **Partial** (precision loss from 7 categories to 5)

The ontology must capture:
- Value mapping: 1→1, 2+3→2, 4→2, 5→3, 6→4, 7→5
- Information loss: Cannot distinguish "4-6/week" from "2-3/week" in harmonised data
- Rationale: "Collapsed to align with later survey's reduced granularity"

**Requirements derived**:
- R2.1: Store value mappings (source codes → target codes)
- R2.2: Distinguish relationship types (same-name-different-coding vs derived)
- R2.3: Support bidirectional reasoning where applicable
- R2.4: Document information loss when Harmonisation Potential = Partial

### 2.3 Use case: Unit drift (Complete harmonisation with transformation)

**Scenario**: Height measurement changed units across CCHS cycles:

| Cycle | Variable | Unit |
|-------|----------|------|
| 2001, 2003 | `HWTGHTM` | Inches |
| 2005+ | `HWTGHTM` | Metres |

**Harmonisation Potential**: **Complete** (no information loss—unit conversion is exact)

This is currently handled by cchsflow's `rec_with_table()` function, which applies the conversion formula. The ontology should document:
- Same Represented Variable (concept and precision are identical)
- Transformation required: `height_m = height_in * 0.0254`
- No information loss despite the transformation

**Requirements derived**:
- R2.5: Support relationships that require transformation without information loss

### 2.4 Use case: Universe changes (Partial or Impossible harmonisation)

**Scenario**: A question's target population changed between cycles:

| Cycle | Variable | Universe |
|-------|----------|----------|
| 2001-2005 | `DRUG_X` | Age 12+ |
| 2007+ | `DRUG_X` | Age 18+ |

**Harmonisation Potential**: **Partial** (can harmonise for 18+ only, but lose 12-17 data from early cycles)

The ontology should capture:
- Universe mismatch: 12+ vs 18+
- Conditional harmonisation possible: Restrict analysis to 18+ across all cycles
- Rationale: "Survey changed drug questions to adults-only"

**Requirements derived**:
- R2.6: Document universe differences
- R2.7: Support conditional harmonisation (harmonisable under certain restrictions)

### 2.5 Use case: Discovery across cycles

**Actor**: Researcher planning a new study

**Scenario**: A researcher wants to study diabetes prevalence trends but doesn't know which CCHS variables to use. They need to:
1. Find all diabetes-related variables across cycles
2. Understand which are comparable
3. Identify gaps (cycles where questions weren't asked)

**Current workflow**:
1. Search ICES Data Dictionary or cchsflow docs for "diabetes"
2. Manually compare question wording across cycles
3. Build a spreadsheet tracking comparability (error-prone)

**Desired workflow**:
1. Query ontology: "All variables linked to Conceptual Variable 'diabetes_status'"
2. See all Instance Variables grouped by Represented Variable
3. Identify Complete vs Partial vs Impossible relationships
4. View evidence for each equivalence decision

**Requirements derived**:
- R3.1: Support Conceptual Variable as grouping mechanism
- R3.2: Query by concept to retrieve all related Instance Variables

### 2.6 Use case: New cycle onboarding

**Actor**: cchsflow maintainer

**Scenario**: A new CCHS cycle is released (e.g., 2023). The maintainer needs to:
1. Identify which existing variables have equivalents in the new cycle
2. Flag variables that may need review (question text changed)
3. Document variables that were dropped or added

**Current workflow**:
1. Manual comparison of variable lists
2. Read through documentation for each variable
3. Update worksheets one variable at a time

**Desired workflow**:
1. Import new cycle variable metadata
2. Auto-match by question text similarity → flag high-confidence `same_variable_different_name` candidates
3. Flag low-confidence matches for manual review
4. Document new variables without predecessors
5. Document discontinued variables

**Requirements derived**:
- R3.3: Support automated matching (question text similarity)
- R3.4: Include confidence scores for automated relationships
- R3.5: Track variable lifecycle (introduced, discontinued)

### 2.7 Future use case: Conceptual hierarchy

**Scenario**: A researcher wants all variables related to "tobacco use" regardless of specific question type (smoking status, amount smoked, quit attempts, secondhand exposure).

**Requirements derived**:
- R4.1: Support broader/narrower concept relationships
- R4.2: Allow grouping variables under abstract concepts (taxonomy)

### 2.8 Future use case: Standard vocabulary linking

**Scenario**: Export CCHS variable metadata to a system that uses SNOMED-CT or LOINC codes.

**Requirements derived**:
- R5.1: Support links to external vocabularies
- R5.2: Maintain vocabulary version information

---

## 3. Requirements summary

### 3.1 Functional requirements

| ID | Requirement | Priority | Use case |
|----|-------------|----------|----------|
| **Core relationships** ||||
| R1.1 | Store relationships between variable instances | Must | 2.1 |
| R1.2 | Classify relationship types | Must | 2.1 |
| R1.3 | Document evidence for relationships | Must | 2.1 |
| R1.4 | Search/discover by variable name or concept | Must | 2.1, 2.5 |
| R1.5 | Include Harmonisation Potential status (Complete/Partial/Impossible) | Must | 2.1-2.4 |
| **Value and unit handling** ||||
| R2.1 | Store value mappings (source codes → target codes) | Should | 2.2 |
| R2.2 | Distinguish derived vs renamed variables | Should | 2.2 |
| R2.3 | Support bidirectional reasoning | Could | 2.2 |
| R2.4 | Document information loss when Harmonisation Potential = Partial | Should | 2.2 |
| R2.5 | Support relationships requiring transformation without info loss | Should | 2.3 |
| R2.6 | Document universe differences | Should | 2.4 |
| R2.7 | Support conditional harmonisation | Could | 2.4 |
| **Discovery and onboarding** ||||
| R3.1 | Support Conceptual Variable as grouping mechanism | Should | 2.5 |
| R3.2 | Query by concept to retrieve all related Instance Variables | Should | 2.5 |
| R3.3 | Support automated matching (question text similarity) | Could | 2.6 |
| R3.4 | Include confidence scores for automated relationships | Could | 2.6 |
| R3.5 | Track variable lifecycle (introduced, discontinued) | Could | 2.6 |
| **Concept hierarchy (future)** ||||
| R4.1 | Support broader/narrower relationships | Won't (v1) | 2.7 |
| R4.2 | Group variables under abstract concepts (taxonomy) | Won't (v1) | 2.7 |
| **External vocabularies (future)** ||||
| R5.1 | Link to external vocabularies | Won't (v1) | 2.8 |
| R5.2 | Track vocabulary versions | Won't (v1) | 2.8 |

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

## 6. Emerging data model design

This section captures the evolving data model concepts. Final schema will be developed in LinkML.

### 6.1 Core entities

Based on the Variable Cascade model:

**ConceptualVariable**: Abstract concept independent of measurement
```yaml
conceptual_variables:
  - id: smoking_frequency_current
    label: "Current smoking frequency"
    description: "Self-reported frequency of cigarette smoking at time of survey"
    domain: tobacco_use  # For future hierarchy support
```

**RepresentedVariable**: Concept with specific value domain
```yaml
represented_variables:
  - id: smoking_status_3cat
    label: "Smoking status (3 categories)"
    conceptual_variable: smoking_frequency_current
    value_domain:
      - code: 1
        label: "Daily"
      - code: 2
        label: "Occasionally"
      - code: 3
        label: "Not at all"
```

**InstanceVariable**: Physical variable in a specific dataset
```yaml
instance_variables:
  - id: cchs-2001-SMKDSTY
    name: SMKDSTY
    label: "Type of smoker"
    cycle: cchs-2001
    dataset_type: share  # share, pumf, master
    represented_variable: smoking_status_3cat
    question_text: "At the present time, do you smoke cigarettes daily, occasionally or not at all?"
    universe: "Age 12+"
```

### 6.2 Relationships

**VariableRelationship**: Explicit link between Instance Variables
```yaml
relationships:
  - id: rel-smoking-001
    type: same_variable_different_name
    source: cchs-2001-SMKDSTY
    target: cchs-2003-SMK_005
    harmonisation_potential: complete
    evidence:
      question_text_match: exact
      response_categories_match: exact
      universe_match: exact
    rationale: "Variable renamed between cycles; question, response categories, and universe unchanged"
    confidence: 1.0  # 1.0 = manual review, <1.0 = automated match
    reviewed_by: "DM"
    review_date: "2026-01-23"
```

### 6.3 Relationship types

| Type | Description | Harmonisation Potential |
|------|-------------|------------------------|
| `same_variable_different_name` | Name changed, everything else identical | Complete |
| `recoded` | Response categories changed, requires mapping | Complete or Partial |
| `unit_converted` | Measurement unit changed, requires transformation | Complete |
| `universe_restricted` | Target population narrowed | Partial |
| `derived_from` | Target computed from source(s) | Complete or Partial |
| `no_equivalent` | Evaluated and determined incompatible | Impossible |

### 6.4 Harmonisation Potential status

Following Maelstrom Research guidelines:

| Status | Definition | Example |
|--------|------------|---------|
| **Complete** | No information loss; direct mapping or reversible transformation | Name change, unit conversion |
| **Partial** | Some precision or coverage lost; aggregation required | 5 categories → 3 categories |
| **Impossible** | No compatible information; cannot harmonise | Different constructs entirely |

The explicit "Impossible" status is valuable metadata—it documents that harmonisation was evaluated and rejected.

### 6.5 Evidence structure

Each relationship should document what was compared:

```yaml
evidence:
  question_text_match: exact | similar | different
  response_categories_match: exact | superset | subset | different
  universe_match: exact | subset | different
  unit_match: exact | convertible | incompatible
  notes: "Free text for additional context"
```

### 6.6 Open design questions

1. **Transitivity**: If A same_as B and B same_as C, should we infer A same_as C?
   - **Proposal**: Don't auto-infer; support queries that traverse chains but require explicit assertions for each pair

2. **Bidirectionality**: Are all relationships symmetric?
   - **Proposal**: `same_variable_different_name` is symmetric; `derived_from` is directional

3. **Negative assertions**: How to document "evaluated and not equivalent"?
   - **Proposal**: Relationship with `type: no_equivalent` and `harmonisation_potential: impossible`

4. **Confidence scoring**: How to represent automated vs manual matches?
   - **Proposal**: `confidence` field (0.0-1.0); 1.0 = manual review, <1.0 = automated (include similarity score)

---

## 7. Open questions (for further discussion)

1. **Versioning**: How do we handle updates when we discover a relationship was incorrect?

2. **cchsflow integration**: Generate worksheets from ontology, or annotate existing worksheets with ontology references? (Current thinking: complement first, generate later)

3. **Automation scope**: What level of automated matching is feasible with ICES metadata?

4. **LinkML schema**: Extend existing catalog schema or create new ontology schema?

---

## 8. Next steps

1. ~~**Literature review**: Expand Section 5 with specific papers and findings~~ ✓ Done
2. ~~**Comprehensive review**: Analysis in `variable_relationship_modelling_review.md`~~ ✓ Done
3. **Finalise data model**: Complete LinkML schema based on Section 6 design
4. **Prototype**: Small YAML example for 5-10 smoking variables to test schema
5. **Validate**: Query prototype to verify it supports use cases 2.1, 2.5, 2.6
6. **cchsflow audit**: Document current worksheet structure and identify gaps
7. **Stakeholder input**: Review with cchsflow maintainers and users

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Conceptual Variable** | Abstract concept independent of measurement (DDI Variable Cascade level 1). Example: "Current smoking frequency" |
| **Represented Variable** | Concept with specified value domain (DDI Variable Cascade level 2). Example: "Smoking status as daily/occasional/not at all" |
| **Instance Variable** | Physical variable in a specific dataset (DDI Variable Cascade level 3). Example: `SMKDSTY` in CCHS 2001 |
| **Harmonisation** | Process of making variables comparable across datasets or time periods |
| **Harmonisation Potential** | Maelstrom classification: Complete (no loss), Partial (some loss), Impossible (incompatible) |
| **Pass-through** | Harmonisation where no recoding is needed (1:1 mapping); equivalent to `same_variable_different_name` |
| **Derived variable** | Variable computed from one or more source variables |
| **Variable Cascade** | DDI model linking Conceptual → Represented → Instance Variables |
| **Schema-First** | Approach prioritising declarative metadata (DDI, ontologies)—captures *what* and *why* |
| **Code-First** | Approach prioritising procedural logic (Maelstrom, cchsflow)—captures *how* |

## Appendix B: Document history

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1.0 | 2026-01-23 | cchsflow-docs | Initial draft |
| 0.2.0 | 2026-01-23 | cchsflow-docs | Expanded use cases, added Variable Cascade foundation, Section 6 data model design, Schema-First/Code-First distinction |

## Appendix C: Related documents

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Overview and quick reference |
| [variable_relationship_modelling_review.md](variable_relationship_modelling_review.md) | Comprehensive 49-reference analysis of DDI, Maelstrom, cchsflow, ontologies, and knowledge graphs |
