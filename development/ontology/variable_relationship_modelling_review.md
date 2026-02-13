# **Architectures of Interoperability: A Comprehensive Analysis of Longitudinal Survey Variable Modeling**

## **Executive Summary**

The capacity to model relationships between survey variables across disparate time points and independent studies constitutes the fundamental challenge of longitudinal research and data harmonization. As measurement instruments evolve, variables undergo "drift"—subtle or drastic shifts in question wording, response categories, respondent universes, and measurement units. Without rigorous architectural frameworks to model these shifts, longitudinal inference becomes precarious, and cross-study meta-analysis becomes impossible.  
This research report provides an exhaustive technical analysis of five distinct methodological approaches to solving this problem: the **Data Documentation Initiative (DDI)** standards (Lifecycle and Cross-Domain Integration), the **Maelstrom Research** retrospective harmonization methodology, the **cchsflow** algorithmic framework, semantic **Ontologies** (OBOE and STATO), and **Graph-Based Architectures** (Knowledge Graphs and Neo4j).  
The analysis reveals a critical dichotomy in the field: the tension between **declarative metadata modeling**—typified by DDI and ontologies, which establish static, machine-readable maps of equivalence—and **procedural harmonization**—typified by Maelstrom and cchsflow, which define relationships through executable code and transformation logic.  
The report details how DDI-CDI utilizes a three-tiered "Variable Cascade" (Conceptual, Represented, Instance) to anchor shifting physical data to stable concepts. It contrasts this with the code-first approach of cchsflow, which manages variable history through row-based CSV registries and R-based transformation functions. It further explores how ontologies like OBOE replace the concept of a "variable" with recursive "Observation Contexts," allowing for infinite nesting of environmental and temporal metadata. Finally, it examines the emergence of Knowledge Graphs, such as the GESIS Knowledge Graph, which synthesize these approaches by ingesting declarative metadata into traversable property graphs, using semantic predicates to probabilistic link variable lineage across decades of research.

## ---

**1\. The Theoretical Imperative: Semantic Interoperability and the Variable Cascade**

To understand the specific mechanisms employed by DDI, Maelstrom, or Graph databases, one must first establish the theoretical problem they are attempting to solve: **Semantic Interoperability** in the face of **Variable Drift**.  
In longitudinal surveys, a "variable" is rarely a static entity. It is a lineage of related measurements. For example, a concept such as "Tobacco Consumption" may be measured in 2001 via a question about "cigarettes per day," in 2005 via "packs per week," and in 2010 via "frequency of vaping." While the physical variables differ in name, type, and representation, they are semantically linked to a shared underlying concept. Modeling this relationship requires a move away from flat data dictionaries toward hierarchical conceptual models.

### **1.1 The Variable Cascade Theory**

The central construct adopted by advanced metadata standards to manage this complexity is the **Variable Cascade**. This theoretical model addresses the many-to-one relationship inherent in longitudinal data: a single theoretical concept is realized through multiple representations, which are in turn instantiated as multiple physical data columns across different files.1  
The variable cascade decomposes the "survey variable" into three distinct layers of abstraction:

1. **The Conceptual Variable**: This is the most abstract layer. It defines the semantics of the variable independent of any particular representation or implementation. It answers the question: *What is being measured?* For example, "Marital Status" is a conceptual variable defined by the social and legal state of a relationship. It contains no information about the codes used to record it (e.g., whether "Single" is coded as '1' or 'S').2 This level is designed for broad search and discovery, allowing researchers to identify all variables related to a topic regardless of their specific encoding.3  
2. **The Represented Variable**: This layer adds specificity regarding the value domain and measurement unit. It answers the question: *How is the concept encoded?* A Represented Variable might be "Marital Status (Standard 5-Category Code)." It specifies the set of valid categories (Single, Married, Divorced, Widowed, Separated) but remains independent of any specific data file. This layer is crucial for identifying comparability; if two survey waves share a Represented Variable, their data can be pooled directly. If they differ at this level (e.g., one uses a 5-category scale and another uses a 3-category scale), harmonization logic is required.1  
3. **The Instance Variable**: This is the physical realization of the variable in a specific dataset. It answers the question: *Where is the data stored?* An Instance Variable includes platform-specific technical metadata, such as the physical data type (e.g., SAS numeric, SQL varchar), the variable name (e.g., MARITAL\_01), and its role in the dataset (e.g., weight, identifier, measure).2

### **1.2 The Mechanism of Longitudinal Linkage**

The "modeling" of relationships across time is essentially the act of tracing these vertical and horizontal connections.

* **Vertical Linkage**: Connecting an Instance Variable (e.g., SMK\_2005) to its parent Represented Variable and Conceptual Variable.  
* **Horizontal Linkage**: Connecting two Instance Variables (e.g., SMK\_2005 and SMK\_2007) by identifying their common ancestors in the cascade.

If two variables share a **Represented Variable**, they are structurally identical and can be merged. If they share only a **Conceptual Variable**, they are semantically related but require transformation (re-coding) to be compared. This theoretical distinction underpins the architecture of DDI-CDI, Maelstrom's DataSchema, and the cchsflow harmonization tables.

## ---

**2\. Declarative Metadata Standards: The Data Documentation Initiative (DDI)**

The Data Documentation Initiative (DDI) represents the most mature and comprehensive effort to standardize the description of these relationships. DDI approaches the problem through **declarative metadata**: explicit, machine-readable XML structures that document the existence and nature of links between variables without necessarily executing the transformation.

### **2.1 DDI Lifecycle (3.2): The Comparison Module**

DDI Lifecycle 3.2 introduced a dedicated architectural component known as the **Comparison Module**. Unlike previous versions (DDI Codebook), which largely described static files, Lifecycle 3.2 was built to manage the intellectual lineage of data across time.4

#### **2.1.1 The Comparison Map Structure**

The core of DDI’s modeling capability lies in the Comparison element. This container allows archivists to create a "map" that explicitly links items from a Source scheme (e.g., the 2001 survey) to a Target scheme (e.g., the 2005 survey or a harmonized standard).5  
The relationships are defined using the GenericMapType, which can be specialized into a VariableMap, QuestionMap, ConceptMap, or CategoryMap.6 This specialization allows for granular linking: researchers can model that *Question A* is equivalent to *Question B* even if *Variable A* is not equivalent to *Variable B* (perhaps due to different coding instructions).  
The fundamental unit of linkage is the ItemMap. Its structure is sophisticated and designed to capture the nuance of longitudinal change:

* **SourceItem**: A reference (URN) to the original object.  
* **TargetItem**: A reference (URN) to the comparison object.  
* **Correspondence**: A text or code description of the relationship (e.g., "Identical," "Recoded," "Aggregated").7  
* **InheritanceAction**: This attribute is architecturally significant. It defines whether the metadata from the source should be *added*, *updated*, or *deleted* in the target.5 This allows for "delta" modeling, where only the changes in a variable (e.g., a new category label) are recorded, while unchanged attributes are inherited, reducing XML verbosity and maintenance overhead.

#### **2.1.2 Comparison of Response Domains**

Longitudinal drift often occurs not in the variable concept, but in the **Response Domain**—the set of valid answers. DDI 3.2 provides specific structures to model these shifts.

* **CodeRepresentation**: Used for categorical variables. The metadata can map a code of '1' in 2001 to a code of '10' in 2005, documenting that while the physical value changed, the semantic meaning (e.g., "Yes") remained constant.8  
* **NumericRepresentation**: Used for continuous variables. It defines value ranges and intervals.  
* **TextRepresentation**: Used for open-ended responses.8

DDI 3.2 enforces a rigorous definition of equality. For a datum to be considered strictly equal across time (comparable without transformation), it must satisfy the Equality  property. This implies that the social and legal status of the value must be identical.9 For example, the value "Married" in a 1990 survey might not be strictly equal to "Married" in a 2020 survey if the legal definition of marriage in the jurisdiction has expanded to include same-sex couples. DDI allows this distinction to be modeled: the label "Married" persists, but the underlying Concept has shifted, requiring a new version in the metadata.

### **2.2 DDI-Cross Domain Integration (DDI-CDI)**

DDI-CDI represents the next evolution in modeling, designed to integrate survey data with non-survey sources (registers, web scrapes, sensor data). Its approach to variable relationships is even more abstract and modular than DDI Lifecycle.

#### **2.2.1 Structural Transformation as Relationship**

DDI-CDI acknowledges that variables often change their *structural* form over time. A variable might exist as a column in a "Wide" dataset (one row per respondent) in Wave 1, but as a row value in a "Long" or "Dimensional" dataset in Wave 2\. DDI-CDI separates the description of the **Variable** from the description of the **Data Structure**.10  
This separation allows for powerful relationship modeling. A single Conceptual Variable can be linked to:

* An Instance Variable in a CSV file (Wide format).  
* A Data Point in a multidimensional cube (Dimensional format).  
* A Key-Value pair in a streaming data log.11

This effectively models the relationship between "Survey Data" and "Process Data" or "Paradata." For example, the variable "Time to Completion" might be a calculated column in the survey dataset but a series of timestamp logs in the instrument data. DDI-CDI models these as two representations of the same concept, linked via the Variable Cascade.1

#### **2.2.2 Integration with SDTL and Provenance**

DDI-CDI enhances relationship modeling by integrating with the **Structured Data Transformation Language (SDTL)** and **PROV-O (Provenance Ontology)**.

* **SDTL**: Instead of simply stating "Variable B is derived from Variable A," DDI-CDI can embed the SDTL script that performed the derivation (e.g., RECODE (1=0) (2=1)). This makes the relationship *actionable* and transparent.3  
* **PROV-O**: This allows the model to capture the *agent* and *activity* that created the relationship. It answers: *Who decided these variables were equivalent?* This is critical for retrospective harmonization, where the equivalence is an assertion made by a researcher, not an inherent property of the data.12

The VariableRelationship class in DDI-CDI formally models the ordered relations between variables in the cascade, providing a graph-ready structure that can be serialized into RDF for semantic web applications.1

## ---

**3\. Procedural Harmonization Frameworks: Maelstrom Research**

While DDI provides a standard for *describing* data, **Maelstrom Research** provides a methodology for *processing* it. Maelstrom’s approach is fundamentally **retrospective** and **procedural**. It is designed to harmonize data from existing cohorts that were never intended to be compatible.

### **3.1 The DataSchema Architecture**

The relationship modeling in Maelstrom begins with the definition of a **DataSchema**. This is a target standard—essentially a set of Conceptual and Represented Variables defined by the research question, not by the source data.14  
The DataSchema acts as the "North Star." Relationships are not modeled between Study A and Study B directly (which leads to ![][image1] mappings); rather, all studies are mapped to the DataSchema (![][image2] mappings). This "Hub-and-Spoke" model is the industry standard for scalable harmonization.16

### **3.2 The Harmonization Potential Status**

A unique feature of the Maelstrom modeling approach is the explicit categorization of the relationship's quality via the **Harmonization Potential** status. Before any transformation code is written, experts evaluate the link between the Input Variable and the DataSchema Variable.14

| Status | Definition | Implication for Modeling |
| :---- | :---- | :---- |
| **Complete** | No loss of information. | Concepts are identical. Direct mapping or simple recoding is possible. |
| **Partial** | Some loss of precision. | Concepts are related but distinct (e.g., continuous age vs. age groups). Transformation involves aggregation. |
| **Impossible** | No compatible information. | No relationship exists. This explicit "null" link is critical metadata. |

This status metadata allows researchers to filter datasets based on the "tightness" of the variable relationships. A study requiring high precision might exclude "Partial" matches, whereas a broader exploratory study might include them.

### **3.3 The Data Processing Elements (DPE)**

The technical implementation of these relationships is contained in the **Data Processing Elements (DPE)**, a structured format used by Maelstrom’s Rmonize package.18  
The DPE is a tabular model that defines the transformation logic. Key columns include:

* dataschema\_variable: The target (Represented Variable).  
* input\_dataset: The source context.  
* input\_variables: The source instances (Instance Variables).  
* Mlstr\_harmo::rule\_category: A taxonomy of the transformation logic.  
* Mlstr\_harmo::algorithm: The executable code.

#### **3.3.1 Rule Categories as Relationship Predicates**

The rule\_category effectively functions as a semantic predicate describing the nature of the link between source and target variables 20:

* **direct\_mapping**: Indicates an identity relationship (sameAs). The source values are transferred without modification.  
* **recode**: Indicates a semantic alignment of categories. The relationship is defined by the mapping of code values (e.g., 1-\>0, 2-\>1).  
* **operation**: Indicates a functional derivation. The relationship is mathematical (e.g., unit conversion, BMI calculation).  
* **case\_when**: Indicates complex conditional logic. The relationship depends on the values of multiple input variables (e.g., defining "Smoker" based on both "frequency" and "lifetime consumption").  
* **id\_creation**: Indicates the generation of structural identifiers.

By categorizing the *type* of algorithmic processing required, Maelstrom allows for high-level analysis of the harmonization complexity. A dataset requiring mostly direct\_mapping is closer in lineage to the target schema than one requiring complex case\_when logic.

### **3.4 Error Handling and Validation**

The Rmonize package includes functions like show\_harmo\_error to validate these relationships during execution.21 If an algorithm fails (e.g., due to a data type mismatch or missing input column), the relationship is flagged as broken. This creates a "runtime validation" of the variable model, ensuring that the theoretical link described in the DPE is physically executable on the dataset. This contrasts with DDI, where a Comparison map might be syntactically valid XML but fail against the actual data files.

## ---

**4\. Algorithmic Harmonization: The cchsflow Framework**

The cchsflow package provides a specific, code-centric implementation of variable modeling, tailored for the Canadian Community Health Survey (CCHS). It exemplifies a **"Code-First"** approach to longitudinal data management, prioritizing reproducibility and execution over abstract metadata standards.22

### **4.1 The Metadata Registry: variables.csv**

cchsflow externalizes the definition of the "Represented Variable" layer into a master registry file named variables.csv. This file lists every variable that has been harmonized across the survey's history (2001–2018).23

* **Role**: It serves as the definitive catalog of "Target" variables.  
* **Content**: Columns include variable (the harmonized name), label, variableType, and units.  
* **Semantics**: By defining a single entry for a variable like HWTGBMI (BMI), the package asserts that this concept exists continuously across all survey cycles, regardless of how it was originally named or measured.23

### **4.2 The Transformation Map: variable\_details.csv**

The longitudinal relationships—the connections between the stable target variables and the shifting source variables—are modeled in variable\_details.csv.23 This file is the operational heart of the framework.

#### **4.2.1 Explicit Variable Lineage**

The variable\_details.csv file uses a row-based structure to map each category of each variable in each cycle.

* **variable**: The target harmonized variable (e.g., HWTGBMI).  
* **databaseStart**: The source survey cycle (e.g., cchs2001\_p).  
* **variableStart**: The source variable name in that specific cycle.

This structure explicitly handles **Variable Renaming**. For example, BMI might be named HWTAGBMI in 2001 and HWTCGBMI in 2005\. cchsflow models this by having rows for both source names mapping to the same target variable. This unifies them under a single semantic umbrella.23

#### **4.2.2 Handling Unit and Logic Drift**

cchsflow does not just map names; it maps logic. The recEnd column defines the transformation for specific values.

* **Unit Conversion**: The documentation notes that height was collected in **inches** in early CCHS cycles (2001, 2003\) but in **meters** in later cycles (2005+). The variable\_details logic handles this by applying a mathematical transformation to the early cycles while copying the later cycles. This effectively "harmonizes" the measurement unit drift within the relationship definition itself.25  
* **Metadata Standardization**: It standardizes special codes. The "Not Applicable" code might be 999.6 in one cycle and 999.9 in another. cchsflow maps both to a standardized NA::a (tagged NA), ensuring that missing data is semantically consistent across time.23

### **4.3 The Execution Engine: rec\_with\_table**

The relationship model is operationalized via the rec\_with\_table() function in R. This function reads the CSV map and executes the transformations on the raw data frames.26  
The tightness of the coupling between the CSV metadata and the R function is a defining characteristic of this approach. Unlike DDI, which is software-agnostic, the cchsflow model is designed to be executed by specific software. This limits interoperability with non-R systems but guarantees that the documentation and the code are always in sync. If a variable relationship is documented in the CSV, it *will* be harmonized by the function; there is no risk of the documentation drifting from the implementation.23

### **4.4 Handling Universe Changes**

One limitation of the cchsflow model is its handling of **Respondent Universe** changes (e.g., a question asked of 12+ year olds in 2001 but 18+ in 2005). While the variables.csv file contains a description column to note these changes, the harmonization logic itself typically processes the data "as is." It relies on the user to read the description and understand that the population denominator has shifted. This contrasts with DDI-CDI, which can explicitly model the Universe as a separate metadata object linked to the variable.23

## ---

**5\. Semantic Modeling via Ontologies: OBOE and STATO**

Ontological approaches shift the modeling paradigm from "data processing" to "knowledge representation." By describing survey variables using formal logic (OWL/RDF), ontologies allow for automated reasoning about the relationships between measurements, independent of their tabular structure.

### **5.1 OBOE: The Extensible Observation Ontology**

OBOE (Extensible Observation Ontology) provides a generic semantic model for observational data. It is particularly powerful because it deconstructs the concept of a "variable" into its atomic semantic components.27

#### **5.1.1 The Observation-Context Model**

In traditional survey modeling, "Year" and "BMI" are two separate columns in a table. In OBOE, they are fundamentally different types of entities linked by a context relationship.

* **Observation**: The fundamental unit.  
* **Entity**: The thing being measured (e.g., the Respondent).  
* **Characteristic**: The property being measured (e.g., Mass, Height).  
* **Measurement**: The value assigned to the characteristic using a specific Standard (Unit).

The relationship between variables is modeled via the **hasContext** property. An observation of "BMI" is not just a number; it is an observation that exists *within the context* of other observations.29

* Observation\_1 (Characteristic: BMI) ![][image3] Observation\_2 (Characteristic: Time, Value: 2001\)  
* Observation\_1 ![][image3] Observation\_3 (Characteristic: Location, Value: Toronto)

#### **5.1.2 Modeling Longitudinality via Recursion**

This context model allows for infinite recursion, which is ideal for modeling complex longitudinal designs. A specific measurement in a panel survey can be modeled as: Measurement ![][image4] Observation (Respondent) ![][image4] Observation (Wave 3\) ![][image4] Observation (Panel Study).  
Variable drift is handled by changing the context. If the measurement unit for Height changes from inches to meters, OBOE models this as a change in the Standard of the Measurement, while the Characteristic (Height) and the Entity (Respondent) remain identical. This allows a semantic query engine to retrieve "All Height measurements of Respondent X" regardless of the unit or the year, simply by traversing the Entity relationship.30

### **5.2 STATO: The Statistics Ontology**

While OBOE models the observation, **STATO** models the *statistical role* of the variable. This is critical for longitudinal analysis, where a variable might serve as a dependent outcome in one analysis and a covariate in another.32

#### **5.2.1 Variables as Information Entities**

STATO defines a variable as a "directive information entity" that is *about* a data item. It explicitly categorizes variables based on their role in the study design:

* **Independent Variable**: The predictor.  
* **Dependent Variable**: The outcome.  
* **Confounding Variable**: A variable that influences both.

#### **5.2.2 Linking to Study Design and Provenance**

STATO allows researchers to model the relationship between a variable and the **Study Design** (e.g., is\_part\_of a Cross-Over Design or Cohort Study). This allows for the modeling of structural changes in the survey. For example, if a survey switches from a cross-sectional design to a longitudinal panel design, STATO can capture this change in the metadata of the variables. A variable collected under the new design is linked to the Cohort Study class, distinguishing it from previous variables linked to Cross-Sectional Study.34  
Furthermore, STATO links variables to the **Statistical Methods** used to analyze them (e.g., t-test, ANOVA). This provides a "downstream" relationship model, showing not just where the variable came from, but how it is intended to be used.36

## ---

**6\. Execution at Scale: Graph-Based Architectures**

Graph databases and Knowledge Graphs (KGs) represent the implementation layer for these semantic models. They allow the rigid hierarchies of DDI and the complex logic of ontologies to be stored in a flexible, traversable network structure.

### **6.1 The GESIS Knowledge Graph (GESIS KG)**

The GESIS Knowledge Graph is a premier example of utilizing graph architecture to model survey metadata. It integrates DDI, schema.org, and the NFDIcore ontology to create a linked data ecosystem for the social sciences.37

#### **6.1.1 The Ontology of the Graph**

The GESIS KG acts as a "Meta-Model," ingesting data from various sources and mapping them to a unified graph ontology.

* **Nodes**: ddi:Variable, ddi:Instrument (Questionnaire), schema:Dataset, schema:ScholarlyArticle.37  
* **Edges**: is\_measured\_by, is\_part\_of, is\_derived\_from.38

By representing variables as nodes, the graph allows for many-to-many relationships. A single ddi:Variable node can be part of multiple schema:Dataset nodes (e.g., the original file and a harmonized file) and can be measured by multiple ddi:Instrument nodes (e.g., different versions of a questionnaire).39

#### **6.1.2 Semantic Linking with SKOS**

To model relationships between variables across different studies, GESIS KG relies on **SKOS (Simple Knowledge Organization System)** predicates.

* **skos:exactMatch**: Used to assert that Variable A is identical to Variable B.  
* **skos:closeMatch**: Used to assert that they are similar but not identical (handling drift).40

This allows the graph to support "fuzzy" traversal. A researcher querying for "Political Interest" can find exact matches in the current study and close matches in historical studies, bridging the longitudinal gap semanticly.42

#### **6.1.3 Link Scoring and Confidence**

An innovative feature of the GESIS KG is the **linkScore** property. Automated harmonization algorithms (often based on text similarity of question labels) generate links between variables. The graph stores these links along with a confidence score (e.g., linkScore: 0.85). This explicitly models the *uncertainty* of the relationship, a feature absent in DDI's binary Comparison maps.37

### **6.2 Neo4j: Property Graph Modeling**

Neo4j is the database technology often used to implement these graph models. Its **Property Graph** structure (Nodes and Relationships, both with internal key-value properties) offers distinct advantages over RDF triples for modeling survey logic.43

#### **6.2.1 Modeling Survey Lineage**

In a Neo4j longitudinal model, the survey evolution is captured directly in the graph topology.

* **Nodes**: Question, Variable, Survey\_Cycle.  
* **Versioning Edges**: (:Question\_2005)--\>(:Question\_2001).

This NEXT\_VERSION\_OF relationship creates a linked list of question versions. To find the history of a variable, one simply traverses this chain. This is far more efficient than querying relational join tables.45

#### **6.2.2 Handling Sparse Data**

Longitudinal surveys are notoriously "sparse"—questions are added and dropped frequently. In a relational database, this results in tables with millions of NULL values. In Neo4j, if a question is not asked in a specific cycle, the relationship simply does not exist. This "Schema-Free" nature allows the data model to evolve naturally with the survey without requiring costly schema migrations.47

#### **6.2.3 Graph Embeddings for Relationship Discovery**

Advanced applications of graph databases involve **Knowledge Graph Embeddings** (e.g., TransE, MSTE). These machine learning techniques map nodes to vectors in a low-dimensional space. By analyzing the vector distance between Variable\_A (from Study 1\) and Variable\_B (from Study 2), the system can predict likely relationships (matches) based on the structural context of the variables (e.g., their neighbors, topics, and question text).49 This automates the discovery of potential harmonization links in vast data lakes.

## ---

**7\. Comparative Synthesis and Strategic Architecture**

The analysis identifies two fundamental architectural philosophies for modeling survey variable relationships: **Schema-First** and **Code-First**.

### **7.1 Schema-First vs. Code-First**

| Feature | Schema-First (DDI, Ontologies) | Code-First (Maelstrom, cchsflow) |
| :---- | :---- | :---- |
| **Primary Artifact** | Metadata (XML, RDF, OWL) | Code (R Scripts, CSV tables) |
| **Relationship Definition** | Declarative Mapping (ItemMap, sameAs) | Procedural Logic (recode, case\_when) |
| **Strengths** | Interoperability, Standards-Compliance, Archival Stability | Reproducibility, Execution Speed, Pragmatism |
| **Weaknesses** | High Complexity, Implementation Overhead | Platform Lock-in (R/SAS), "Black Box" Logic |
| **Handling Drift** | Versioned Objects, Variable Cascade | Transformation Algorithms |

**DDI and Ontologies** excel at *describing* the world. They provide a stable, software-independent record of relationships. They are essential for libraries, archives, and search engines (like the GESIS KG) where discovery is the primary goal.  
**Maelstrom and cchsflow** excel at *manipulating* the world. They provide the tools to actually produce a harmonized dataset. They are essential for research teams performing active data analysis. The relationship is defined by the *act* of harmonization.

### **7.2 The Convergence: Knowledge Graphs**

The future of this field lies in the convergence of these approaches via **Knowledge Graphs**.

* **Ingest Schema**: Graphs can ingest DDI-CDI metadata to establish the nodes and basic relationships (The Variable Cascade).  
* **Ingest Code**: Graphs can ingest the logic of cchsflow or Maelstrom by representing transformations as process nodes (e.g., (:Variable\_A)--\>(:Variable\_B)).  
* **Semantic Glue**: Ontologies like OBOE and STATO provide the semantic types for these nodes, ensuring that the graph is logically consistent.

This hybrid architecture allows for a system that is both descriptively rich (like DDI) and executably potent (like Maelstrom), bridging the gap between metadata standards and data science practice.

### **7.3 Comparison Table of Approaches**

The following table synthesizes the five approaches based on their primary modeling primitives and their handling of longitudinal drift.

| Approach | Modeling Primitive | Handling of Longitudinal Drift | Strengths | Limitations |
| :---- | :---- | :---- | :---- | :---- |
| **DDI Lifecycle (3.2)** | Comparison Module, ItemMap | Explicit Source \-\> Target mapping with Correspondence descriptions. | Standardized, machine-readable, supports inheritance to reduce redundancy. | Verbose XML, complex to implement, separate from execution logic. |
| **DDI-CDI** | Variable Cascade (Concept, Represented, Instance) | Models structural changes (Wide/Long) and links instances to stable concepts. | Integrates with Big Data/Process data, separates structure from semantics. | Newer standard, fewer tools, requires high abstraction. |
| **Maelstrom Research** | DataSchema & DPE (rule\_category) | Harmonization Potential status \+ Transformation Algorithms (recode, operation). | rigorous process, explicit "Impossible" status, ties metadata to R execution (Rmonize). | Requires manual expert evaluation, metadata tied to spreadsheet formats. |
| **cchsflow** | CSV Registry \+ R Function | Row-based history (variableStart) mapped to harmonized target (variable). | Highly reproducible, code-first, explicit handling of unit/code changes. | Specific to CCHS/R, limited handling of universe changes, platform dependent. |
| **Ontologies (OBOE)** | Observation Context (hasContext) | Recursion: Drift is modeled as a change in Context (Time/Space) of the Observation. | Semantic rigor, handles infinite nesting, precise scientific description. | High learning curve, requires graph database, verbose for simple surveys. |
| **Knowledge Graphs** | Nodes & Edges (skos:match) | Versioning edges (NEXT\_VERSION\_OF), Link Scoring, Lineage paths. | Flexible, schema-free, queryable, supports AI/Embeddings for discovery. | Requires graph infrastructure (Neo4j), ontology mapping effort. |

## ---

**8\. Conclusion**

The modeling of relationships between survey variables across time is a multidimensional problem requiring a multidimensional solution. No single standard solves all aspects of the challenge. **DDI** provides the necessary vocabulary and structural hierarchy (The Variable Cascade) to describe the data. **Maelstrom** and **cchsflow** provide the necessary procedural logic to transform the data. **Ontologies** provide the semantic precision to define what the data means. **Knowledge Graphs** provide the scalable infrastructure to store and query these connections.  
For researchers and archivists building the next generation of longitudinal data infrastructure, the optimal architecture is likely a **Graph-based implementation of the DDI-CDI Variable Cascade**, populated by **Maelstrom-style processing logic**, and enriched by **Ontological semantics**. This synthesis ensures that data is not only findable and accessible but also interoperable and reusable across the decades of scientific inquiry.

#### **Works cited**

1. Cross Domain Integration: Specification Overview \- DDI Product Documentation, accessed January 23, 2026, [https://docs.ddialliance.org/DDI-CDI/1.0/model/high-level-documentation/DDI-CDI\_Model\_Specification.pdf](https://docs.ddialliance.org/DDI-CDI/1.0/model/high-level-documentation/DDI-CDI_Model_Specification.pdf)  
2. DDI \- Confluence, accessed January 23, 2026, [https://ddi-alliance.atlassian.net/wiki/spaces/DDI4/pages/2790359041/Glossary+work](https://ddi-alliance.atlassian.net/wiki/spaces/DDI4/pages/2790359041/Glossary+work)  
3. Data Integration: Using DDI-CDI with Other Standards | CODATA, accessed January 23, 2026, [https://codata.org/wp-content/uploads/2021/09/DDI-CDI\_Other\_Standards\_Webinar.pdf](https://codata.org/wp-content/uploads/2021/09/DDI-CDI_Other_Standards_Webinar.pdf)  
4. Behavioral Health MITA \- CMS, accessed January 23, 2026, [https://www.cms.gov/Research-Statistics-Data-and-Systems/Computer-Data-and-Systems/MedicaidInfoTechArch/downloads/BH-MITA-BPM.pdf](https://www.cms.gov/Research-Statistics-Data-and-Systems/Computer-Data-and-Systems/MedicaidInfoTechArch/downloads/BH-MITA-BPM.pdf)  
5. \[Meta\]-Data Management using DDI \- IZA \- Institute of Labor Economics, accessed January 23, 2026, [https://conference.iza.org/conference\_files/EDDI2011/EDDI11%20W1%20-%20Wendy%20Thomas%20-%20Making%20the%20Business%20Case%20for%20Implementing%20DDI.pptx](https://conference.iza.org/conference_files/EDDI2011/EDDI11%20W1%20-%20Wendy%20Thomas%20-%20Making%20the%20Business%20Case%20for%20Implementing%20DDI.pptx)  
6. element  
7. element  
8. Representations — DDI 3.2 (2017) documentation, accessed January 23, 2026, [https://ddi-lifecycle-3-2-documentation.readthedocs.io/en/latest/generalstructures/representations.html](https://ddi-lifecycle-3-2-documentation.readthedocs.io/en/latest/generalstructures/representations.html)  
9. DDI Alliance Scientific Board Annual Meeting May 18, 2020, 13:00-15:00 UTC, accessed January 23, 2026, [https://ddialliance.org/hubfs/sites/default/files/20200518\_Scientific\_Board\_Annual\_Meeting\_Minutes.pdf](https://ddialliance.org/hubfs/sites/default/files/20200518_Scientific_Board_Annual_Meeting_Minutes.pdf)  
10. The DDI Cross-Domain Integration (DDI-CDI) Specification: Overview and Implementations \- UNECE, accessed January 23, 2026, [https://unece.org/sites/default/files/2024-10/MWW2024\_S1\_3\_DDI-CODATA\_Gregory\_P.pdf](https://unece.org/sites/default/files/2024-10/MWW2024_S1_3_DDI-CODATA_Gregory_P.pdf)  
11. ddi-cdi/ddi-cdi \- GitHub, accessed January 23, 2026, [https://github.com/ddi-cdi/ddi-cdi](https://github.com/ddi-cdi/ddi-cdi)  
12. DDI Cross-Domain Integration (DDI-CDI): An Introudction \- UNECE, accessed January 23, 2026, [https://unece.org/sites/default/files/2022-07/MWW2022\_Presentation\_CODATA\_Gregory.pdf](https://unece.org/sites/default/files/2022-07/MWW2022_Presentation_CODATA_Gregory.pdf)  
13. VariableRelationship — UML Model \- DDI Product Documentation, accessed January 23, 2026, [https://docs.ddialliance.org/DDI-CDI/1.0/model/FieldLevelDocumentation/DDICDILibrary/Classes/Conceptual/VariableRelationship.html](https://docs.ddialliance.org/DDI-CDI/1.0/model/FieldLevelDocumentation/DDICDILibrary/Classes/Conceptual/VariableRelationship.html)  
14. Maelstrom Research guidelines for rigorous retrospective data harmonization \- PMC, accessed January 23, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC5407152/](https://pmc.ncbi.nlm.nih.gov/articles/PMC5407152/)  
15. Overview of retrospective data harmonisation in the MINDMAP project: process and results, accessed January 23, 2026, [https://jech.bmj.com/content/75/5/433](https://jech.bmj.com/content/75/5/433)  
16. MOLGENIS/connect: a system for semi-automatic integration of heterogeneous phenotype data with applications in biobanks \- NIH, accessed January 23, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC4937195/](https://pmc.ncbi.nlm.nih.gov/articles/PMC4937195/)  
17. Overview of retrospective data harmonisation in the MINDMAP project: process and results, accessed January 23, 2026, [https://repub.eur.nl/pub/132167/jech-2020-214259.full.pdf](https://repub.eur.nl/pub/132167/jech-2020-214259.full.pdf)  
18. Data Processing Elements \- GitHub Pages, accessed January 23, 2026, [https://maelstrom-research.github.io/Rmonize-documentation/dpe/index.html](https://maelstrom-research.github.io/Rmonize-documentation/dpe/index.html)  
19. Glossary, accessed January 23, 2026, [https://maelstrom-research.github.io/Rmonize-documentation/glossary/index.html](https://maelstrom-research.github.io/Rmonize-documentation/glossary/index.html)  
20. Help for package Rmonize \- CRAN, accessed January 23, 2026, [https://cran.r-project.org/web/packages/Rmonize/refman/Rmonize.html](https://cran.r-project.org/web/packages/Rmonize/refman/Rmonize.html)  
21. Print a summary of data processing in the console — show\_harmo\_error • Rmonize, accessed January 23, 2026, [https://maelstrom-research.github.io/Rmonize-documentation/reference/show\_harmo\_error.html](https://maelstrom-research.github.io/Rmonize-documentation/reference/show_harmo_error.html)  
22. cchsflow: an open science approach to transform and combine population health surveys \- PubMed, accessed January 23, 2026, [https://pubmed.ncbi.nlm.nih.gov/33761108/](https://pubmed.ncbi.nlm.nih.gov/33761108/)  
23. Big-Life-Lab/cchsflow: Variable transformation and ... \- GitHub, accessed January 23, 2026, [https://github.com/Big-Life-Lab/cchsflow](https://github.com/Big-Life-Lab/cchsflow)  
24. Transforming and Harmonizing CCHS Variables • cchsflow, accessed January 23, 2026, [https://big-life-lab.github.io/cchsflow/](https://big-life-lab.github.io/cchsflow/)  
25. Body Mass Index (BMI) derived variable — bmi\_fun • cchsflow, accessed January 23, 2026, [https://big-life-lab.github.io/cchsflow/reference/bmi\_fun.html](https://big-life-lab.github.io/cchsflow/reference/bmi_fun.html)  
26. cchsflow: Transforming and Harmonizing CCHS Variables \- CRAN, accessed January 23, 2026, [https://cran.r-project.org/web/packages/cchsflow/cchsflow.pdf](https://cran.r-project.org/web/packages/cchsflow/cchsflow.pdf)  
27. OBOE — Semantic Tools Project, accessed January 23, 2026, [https://semtools.ecoinformatics.org/oboe.html](https://semtools.ecoinformatics.org/oboe.html)  
28. An ontology for describing and synthesizing ecological observation data \- Computer Science, accessed January 23, 2026, [https://cs.gonzaga.edu/faculty/bowers/papers/bowers-ecoinf-07.pdf](https://cs.gonzaga.edu/faculty/bowers/papers/bowers-ecoinf-07.pdf)  
29. Context-Awareness in Geographic Information Services (CAGIS 2014\) \- UGent personal websites, accessed January 23, 2026, [https://users.ugent.be/\~haohuang/pdfs/CAGIS2014\_proceedings.pdf](https://users.ugent.be/~haohuang/pdfs/CAGIS2014_proceedings.pdf)  
30. An ontology for describing and synthesizing ecological observation data \- ResearchGate, accessed January 23, 2026, [https://www.researchgate.net/publication/223833893\_An\_ontology\_for\_describing\_and\_synthesizing\_ecological\_observation\_data](https://www.researchgate.net/publication/223833893_An_ontology_for_describing_and_synthesizing_ecological_observation_data)  
31. Emerging semantics to link phenotype and environment \- PMC \- PubMed Central, accessed January 23, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC4690371/](https://pmc.ncbi.nlm.nih.gov/articles/PMC4690371/)  
32. The Ontology of Biological and Clinical Statistics (OBCS) for standardized and reproducible statistical analysis \- PMC \- NIH, accessed January 23, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC5024438/](https://pmc.ncbi.nlm.nih.gov/articles/PMC5024438/)  
33. Statistics Ontology \- NCBO BioPortal, accessed January 23, 2026, [https://bioportal.bioontology.org/ontologies/STATO](https://bioportal.bioontology.org/ontologies/STATO)  
34. stato \- OBO Foundry, accessed January 23, 2026, [http://obofoundry.org/ontology/stato.html](http://obofoundry.org/ontology/stato.html)  
35. Statistics Ontology | BiŌkeanós, accessed January 23, 2026, [https://biokeanos.com/source/Statistics%20Ontology](https://biokeanos.com/source/Statistics%20Ontology)  
36. STATO ontology, accessed January 23, 2026, [https://stato-ontology.org/](https://stato-ontology.org/)  
37. GESIS KG, accessed January 23, 2026, [https://data.gesis.org/gesiskg](https://data.gesis.org/gesiskg)  
38. GESIS-Suche: GESIS Knowledge Graph (GESIS KG) \- GESIS Search, accessed January 23, 2026, [https://search.gesis.org/research\_data/SDN-10.7802-2878](https://search.gesis.org/research_data/SDN-10.7802-2878)  
39. AI-assisted Linking of Knowledge Graphs | GESIS Research, accessed January 23, 2026, [https://www.gesis.org/en/research/research-area-computational-methods/ai-assisted-linking](https://www.gesis.org/en/research/research-area-computational-methods/ai-assisted-linking)  
40. Leveraging the DDI Model for Linked Statistical Data in the Social, Behavioural, and Economic Sciences, accessed January 23, 2026, [https://dcpapers.dublincore.org/files/articles/952135935/dcmi-952135935.pdf](https://dcpapers.dublincore.org/files/articles/952135935/dcmi-952135935.pdf)  
41. Use Cases Related to an Ontology of the Data Documentation Initiative \- Semantic Scholar, accessed January 23, 2026, [https://pdfs.semanticscholar.org/0706/e208f2e85303fa74b630efc6a85b1360c47e.pdf](https://pdfs.semanticscholar.org/0706/e208f2e85303fa74b630efc6a85b1360c47e.pdf)  
42. Enhancing FAIR compliance: A controlled vocabulary for mapping Social Sciences survey variables | IASSIST Quarterly, accessed January 23, 2026, [https://iassistquarterly.com/index.php/iassist/article/view/1118](https://iassistquarterly.com/index.php/iassist/article/view/1118)  
43. Describing a Property Graph Data Model \- Graph Database & Analytics \- Neo4j, accessed January 23, 2026, [https://neo4j.com/blog/developer/describing-property-graph-data-model/](https://neo4j.com/blog/developer/describing-property-graph-data-model/)  
44. Graph Data Modeling: All About Relationships | by David Allen | Neo4j Developer Blog, accessed January 23, 2026, [https://medium.com/neo4j/graph-data-modeling-all-about-relationships-5060e46820ce](https://medium.com/neo4j/graph-data-modeling-all-about-relationships-5060e46820ce)  
45. Decyphering Your Graph Model \- Neo4j, accessed January 23, 2026, [https://neo4j.com/blog/cypher-and-gql/decyphering-your-graph-model/](https://neo4j.com/blog/cypher-and-gql/decyphering-your-graph-model/)  
46. Ne04j's Property Graph Data Model \[31\] \- ResearchGate, accessed January 23, 2026, [https://www.researchgate.net/figure/Ne04js-Property-Graph-Data-Model-31\_fig1\_304414637](https://www.researchgate.net/figure/Ne04js-Property-Graph-Data-Model-31_fig1_304414637)  
47. neo4j \- How do I model a customer surveys in a graph database? \- Stack Overflow, accessed January 23, 2026, [https://stackoverflow.com/questions/36123961/how-do-i-model-a-customer-surveys-in-a-graph-database](https://stackoverflow.com/questions/36123961/how-do-i-model-a-customer-surveys-in-a-graph-database)  
48. FROM ARCHITECTURAL SURVEY TO CONTINUOUS MONITORING: GRAPH- BASED DATA MANAGEMENT FOR CULTURAL HERITAGE CONSERVATION WITH DIGITAL, accessed January 23, 2026, [https://d-nb.info/1239823282/34](https://d-nb.info/1239823282/34)  
49. Effective knowledge graph embeddings based on multidirectional semantics relations for polypharmacy side effects prediction | Bioinformatics | Oxford Academic, accessed January 23, 2026, [https://academic.oup.com/bioinformatics/article/38/8/2315/6530273](https://academic.oup.com/bioinformatics/article/38/8/2315/6530273)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFQAAAAYCAYAAABk8drWAAACrElEQVR4Xu2YS+hOQRjGX5fkXliwkQWhJAsWUhYiyUJYKYt/QimFUmKpRFjbykrYWEhChJ2FnUKKJCzc7/fL+3wz4/+ep5lvpvSdw/H96uk753ln5szMmTOXT6RPn/+V5Wy0hEbatUW1m82WMEL1ms0UR1VvVT+9jlWiju8yGIeWVsMyVfWYPMtTqZbBXJVq+U+q4doYrvrCpmeN6gab3bANinFZNYNND/KMZJPYobomLu0eigW+sVETtyXffoDYZDZjDFGdU50Wl2ltNdwh9aBFqs9sRnjuf1OVnqs6zGbNvJF43QIbVR/ZjLFdtcBfpxqcGj1fpWzuDGXe9NdzTAycUI0nr25yHQpy8Q5h9IBX4jLZxs1UHTT3FqQdxSaBL+CMvx4jLg/mbUtRRXtMaYeuZJOxhWCexP0d4x1XjTX3gXGSrwDYpppv7n+Iy4eODmCkN01Jh2LROs+mxY6eAAq1BaceskTSMYv9AsAKcfnCc2er9g+GG6OkQ7GAPWDTYudP66HgsEikthIbJF8BEEtjX9pJcVNBCZPE1bdEs3yeUko6FIt31zQv2PCEBmPx2EexwIBkCleGqs6yqRwRl3eT/y1lmmpVoRb7PKWUdCja0jVNKnhRXOyepBedhZLOH9gpLl2M8NJKtl11UNKhtyQ9CDsng0tsejCyQoNTTJDucYBKprgvLv9eDjRESYd+Ul1gEwxTPVNd54Dhg+Q3sqgAzroxlomLj+aAZ6K4eO6UVRdob65DEV/N5ilxh32svth34pwdY55qK5sEHoDPmnmneinu88D1gWr4N4g1DfbE+P/godcjcfWebhN5ch3+x+ySv6NT6mCd1PTHDd4a5uO2g3ZOYbMXYKN+l82WgUPMFTZ7ySHVZjZbAnY879msgwE2WsJ6Nvr0+Xf4BbC4upcoS+rEAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAAYCAYAAAD3Va0xAAAA3UlEQVR4XmNgGAWkgnlA/BmI/0PxAhRZCPjLgJAHYWdUaVSArBAb2AfEKuiC6IARiLcD8XoGiEFBqNJggMsCFJAPxCZQNi5X/UEXwAbeIrE/MEAM4kMSUwPiTiQ+ToDsAlA4gPg3kcSWATEPEh8rAIXPZjQxdO9h8yoGQA4fZDGQ5m4o/xeSHE7wDl0ACmCu0gbiFjQ5rACXs3czQOTuATEnmhwGYAHiveiCUMDEgBlWWAEzEL8B4pPoEkjgGxB/RxdEBquA+CMDJP2A0g0oL2ED+kCcjS44CkYBEAAABi803bhnVOIAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFQAAAAbCAYAAADiZah4AAAClUlEQVR4Xu2ZS8gOURjHn9wSipRbsXNNLNySsqQkKYkFCyUiCwsl2bBhQbmVWOlLLguKWLCwUMTCJSLKLXLJdSHCwu3/d87hmWfO+6WZs3x+9WvmPM/Mec97Zt5nzjefyP8xGT6Ed2yiJb3hG7gfjobz4AH4Sx/UggE20JBS/VS4DRfbYAtGSH7idsIrNtiAgfCnDTagVD81cl++DexvsA2CWXCODTZgN9xrgw0o1U8NTsBFeBg+qKZkAnwG78G1sJfKjYHvJdzh42LsEvz694gqQ027L/wAj8BXMTYJnoer4TF4CL6MOcKxJl+r+FIJY+G5U2KsB7wrofSMgmfgo5jr1E9rFsIfqq3vVt5lnXK6vUpCfUyxDXG/O1i7dH9H4Xb4HI43uU6fm+iScFESF+L2XdzOgJ/hVOm+3yLclHB1E/pDPsHlqm0HkK7wQRPL/dzJSrX/Xap1+zQ8Efc5OZtVTn/uIKnXPebPwSdSndjEcbjRxHL9FEEPdomECU7o3Ar5d+VJz7hdJOG4ibHN/fST08yH/VU7d3FYQtJ+n7jPu4plIbEL7lNtYvuyMJ/Gm8j1UwQ9mC8SatjlTO4jnAvvq1yqp0/jluyQUMs0IyUsnzS672lSPUfnbkkoS12xzRI0DPaDM2PMTihrOklxnd8Wt7l+WsPJO6Xa6+ENOCS2eafxi/JBNV3CepV3DNkjoeA/lrDO1GyS8CVOwreSf7IPl3DMdbhVxfmg4hgSLAtcI4+N7QVSP2c2/CbhwbZFxfmwYSlYBq/BsyqX68dxHMcpg33QOS25KvWlltMSLhWdgnDZmNbdf2AdcMto/3R1GsKXNets0GnGC6m/cnQawpc5a2zQaQ7rplOQ0v+0dBzHcZxy/Ab8c+7nM4J4hwAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAXCAYAAADQpsWBAAAAj0lEQVR4XmNgGAW0AcFAnAHEmVDsiCqNAKxA/BeI1wGxBRArAbEUEIsAMSeSOjhQAOLH6IKEwB90AULAmQGPm3GBhUBsQgDLwFVDwT4g9iOAdeGqoSACiM3RBYkBv9AFiAGqQHwFXZAYIATE/4F4GhCrAzEvEDOiqMADQCkjB4jrgLgJiJuBOAxFxShgYAAAKeQS84lK5TsAAAAASUVORK5CYII=>