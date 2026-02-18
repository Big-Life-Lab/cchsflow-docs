# CCHS Terminology Glossary

Complete reference for Canadian Community Health Survey (CCHS) terminology used throughout the documentation catalog.

## Survey Structure

### CCHS (Canadian Community Health Survey)
National cross-sectional survey conducted by Statistics Canada to collect health information from Canadians. Provides data on health status, healthcare utilization, and health determinants.

### Master Files
Full survey documentation distributed to Research Data Centres (RDCs). Contains:
- Complete questionnaires with all questions
- Full data dictionaries with all variables
- Unrestricted variable documentation
- Comprehensive derived variables
- Complete syntax files

**Access**: Restricted to researchers with approved RDC access
**Use case**: Comprehensive research, academic studies, detailed analysis

### Share Files
Public-use subset files with enhanced privacy protection. Contains:
- Subset of variables (sensitive items removed/aggregated)
- Aggregated geography (broader regions)
- Top/bottom-coded continuous variables
- Limited derived variables

**Access**: Available for public download
**Use case**: Public analyses, preliminary exploration, teaching

## Temporal Types

### Single-Year Survey (s)
Standard annual CCHS data collection covering one 12-month period.

**Example**: CCHS 2015 (collected Jan-Dec 2015)
**UID code**: `2015s`
**Most common**: 2008 onwards

### Dual-Year Survey (d)
Two-year combined data collection, sometimes pooled for analysis.

**Examples**:
- CCHS 2007-2008 (24-month cycle)
- CCHS 2009-2010
- CCHS 2013-2014

**UID code**: `2009d` (uses first year)
**Purpose**: Larger sample sizes, regional estimates

### Multi-Year Survey (m)
Multi-year pooled surveys combining several cycles.

**Example**: CCHS 2007-2011 pooled
**UID code**: `2007m`
**Less common**: Special analytical products

### Cycle
Historical term for early CCHS waves:
- Cycle 1.1 (2000-2001)
- Cycle 2.1 (2003)
- Cycle 3.1 (2005)

**Replaced by**: Annual surveys after 2005

## Document Categories

### Questionnaire (qu)
Survey instruments containing all questions asked to respondents.

**Contains**:
- Question wording
- Response options
- Skip patterns/routing
- Interviewer instructions

**Formats**: PDF, DOC, DOCX
**Languages**: English and French

### Data Dictionary (dd)
Comprehensive variable documentation with definitions and codes.

**Contains**:
- Variable names and labels
- Value codes and labels
- Frequencies/distributions
- Variable types and formats
- Topical/alphabetical indices

**Formats**: PDF, MDB (Access databases)
**Special types**:
- With frequencies
- Without frequencies
- Alpha/topical indices

### User Guide (ug)
Methodology and usage documentation for survey data.

**Contains**:
- Survey design and methodology
- Sampling procedures
- Weighting specifications
- Data limitations
- Analysis guidelines
- Known issues/errata

**Formats**: PDF, DOC
**Critical for**: Proper data analysis and interpretation

### Derived Variables (dv)
Documentation of calculated/constructed variables.

**Contains**:
- Derivation algorithms
- Source variables
- Calculation logic
- Missing data handling
- Quality indicators

**Examples**:
- BMI categories
- Income adequacy
- Health indices
- Chronic condition counts

**Formats**: PDF, DOC

### Record Layout (rl)
File structure and variable position specifications.

**Contains**:
- Variable positions (columns)
- Variable widths
- Data types
- Record length
- File organization

**Formats**: PDF, TXT
**Use**: Reading raw data files

### Syntax Files
Programming code for data processing and analysis.

**Types**:
- **SAS (.sas)**: SAS syntax
- **SPSS (.sps)**: SPSS syntax
- **Stata (.do)**: Stata commands

**Categories**:
- Input (_i): Read data files
- Formats (_fmt): Define value formats
- Labels (_lbe, _lbf): Variable/value labels (English/French)
- Print formats (_pfe, _pff): Display formats
- Missing values (_miss): Missing data specs
- Value labels (_vale, _valf): Value label assignments
- Variable labels (_vare, _varf): Variable label assignments

### CV Tables (cv)
Coefficient of variation tables for assessing estimate quality.

**Contains**:
- CVs for key estimates
- Sampling variability measures
- Data quality indicators

**Use**: Assessing statistical reliability

### Metadata Files (md)
Access database files with comprehensive metadata.

**Format**: .mdb (Microsoft Access)
**Contains**: Structured metadata tables
**Note**: May require Access or compatible software

## File Attributes

### Language Codes

**EN (English)**: English language documents
**FR (French)**: French language documents (Français)

**Note**: Some documents are bilingual (contain both languages)

### File Extensions

**Documents**:
- `.pdf` - Portable Document Format (most common)
- `.doc` - Microsoft Word (legacy)
- `.docx` - Microsoft Word (modern)

**Syntax**:
- `.sas` - SAS syntax
- `.sps` - SPSS syntax
- `.do` - Stata commands

**Data**:
- `.mdb` - Microsoft Access database
- `.txt` - Text files
- `.csv` - Comma-separated values

### Version Numbers

**v1**: First version from OSF download
**v2, v3, etc.**: Subsequent versions (if files updated)

**Note**: Current collections use v1 (first OSF download)

## Collection Terms

### Manifest
CSV file containing metadata for all files in a collection.

**Columns**: UID, canonical filename, category, year, language, etc.
**Purpose**: Navigate and query collection contents

### Canonical Filename
Standardized filename following Jenny Bryan conventions.

**Format**: `cchs_{year}{temporal}_{category}_{doctype}_{lang}_{seq}_v{ver}.{ext}`
**Example**: `cchs_2015s_qu_m_en_1_v1.pdf`
**Purpose**: Consistent, shareable file naming

### UID (Unique Identifier)
Globally unique identifier for each file in the catalog.

**Format**: `cchs-{year}{temporal}-{doctype}-{category}-{lang}-{ext}-{seq:02d}`
**Example**: `cchs-2015s-m-qu-e-pdf-01`
**Purpose**: Unambiguous file reference

### Collection
Curated subset of files packaged together.

**Includes**: ZIP file + CSV manifest
**Distribution**: GitHub releases
**Examples**: Core Master Collection, Syntax Collection

## Organizational Terms

### OSF.io (Open Science Framework)
Online platform hosting the source CCHS documentation.

**Project**: 6p3n9
**Component**: jm8bx
**Purpose**: Upstream source for all documentation

### RDC (Research Data Centre)
Secure facilities for accessing confidential microdata.

**Access**: Master files available at RDCs
**Requirements**: Approved research project, security clearance

### Statistics Canada (StatCan)
Government agency conducting CCHS and distributing documentation.

**Role**: Survey owner, data custodian

## Survey Years

### Early Cycles (2001-2005)
- 2001: Cycle 1.1
- 2003: Cycle 2.1
- 2005: Cycle 3.1

**Structure**: Biannual with numbered cycles

### Transition Period (2007)
- 2007-2008: 24-month cycle
- Shift to annual model

### Annual Period (2008-2023)
- Standard 12-month surveys
- Some dual-year collections
- Consistent structure and content

## Content Types

### Core Documentation
Essential files for using CCHS data:
- Questionnaires
- Data dictionaries
- User guides
- Derived variables

### Supporting Documentation
Additional helpful files:
- Record layouts
- Syntax files
- CV tables
- Metadata databases

### Specialized Content
Specific purpose documentation:
- Sub-sample files (2003, 2005)
- Group/module-specific content
- Errata and updates
- Household weights

## Abbreviations

- **CCHS**: Canadian Community Health Survey
- **CV**: Coefficient of Variation
- **DV**: Derived Variables
- **EN**: English
- **FR**: French
- **OSF**: Open Science Framework
- **RDC**: Research Data Centre
- **UID**: Unique Identifier
- **VD**: Variables Dérivées (French: Derived Variables)

---

**See also**:
- [UID System](uid-system.md) - Complete UID specification
- [README](../README.md#-cchs-terminology) - Quick reference
