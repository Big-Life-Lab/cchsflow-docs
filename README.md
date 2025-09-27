# CCHS Documentation Management

This repository manages Canadian Community Health Survey (CCHS) documentation using OSF.io, providing automated folder structure creation and comprehensive file inventory tracking.

## Quick Start

1. **Install required R packages:**
   ```r
   install.packages(c("osfr", "config", "dplyr", "yaml"))
   ```

2. **Load CCHS structure data:**
   ```r
   source("R/load_cchs_structure.R")
   load_cchs_structure()
   cchs_summary()
   ```

## Setup (for OSF management)

1. **Set up OSF.io credentials:**
   - Get your Personal Access Token from [OSF.io settings](https://osf.io/settings/tokens/)
   - Ensure token has **full read and write permissions**
   - Copy `.env.example` to `.env` and add your credentials:
     ```bash
     cp .env.example .env
     # Edit .env with your OSF_PAT and OSF_PROJECT_ID
     ```

2. **Test OSF connection:**
   ```r
   source("R/setup_osf.R")
   project <- init_osf()
   ```

## Usage

### Load CCHS Structure Data
```r
source("R/load_cchs_structure.R")
load_cchs_structure()  # Loads cchs_structure_data into global environment

# Quick summary
cchs_summary()

# Get all expected years
get_expected_years()

# Search for specific files
user_guides <- search_files("User_Guide")
data_dicts <- search_files("DataDictionary")

# Get files for specific year
files_2023 <- get_files_for_year(2023)
```

### Basic OSF Connection
```r
source("R/setup_osf.R")
project <- init_osf()
```

### Create CCHS Folder Structure (if needed)
```r
source("R/cchs_folder_structure.R")

# Create missing years with annual structure
create_cchs_years(c(2024, 2025), "annual")

# Create early cycle years  
create_cchs_years(c(2001, 2003, 2005), "cycle")
```

## Project Structure

- `R/` - R scripts for OSF.io management
  - `load_cchs_structure.R` - Load and access CCHS structure data
  - `cchs_folder_structure.R` - Create folder structures on OSF
  - `setup_osf.R` - OSF authentication and connection
- `data/` - CCHS structure data files
  - `cchs_structure_enhanced.RData` - Complete structure with file listings
  - `cchs_expected_structure.RData` - Expected structure definitions only
- `cchs-docs/` - Local documentation files
- `config.yml` - Configuration using the config package
- `.env.example` - Template for environment variables

## CCHS Survey Structure

The Canadian Community Health Survey has evolved over time:

### Early Cycles (2001-2005)
- **Biannual surveys** with specific cycle naming
- **2001**: Cycle 1.1, **2003**: Cycle 2.1, **2005**: Cycle 3.1
- **Structure**: `YEAR/CYCLE.1/Master/[Docs|Layout]`

### Annual Surveys (2006-2023)
- **Annual data collection** starting 2006
- **Structure**: `YEAR/12-Month/Master/[Docs|Layout]`

## Data Files

The repository contains comprehensive CCHS structure data:
- **Years covered**: All CCHS years from 2001-2023 (21 total)
- **Folder structure**: Complete hierarchy for all years 
- **File inventory**: 30 files documented across 2022-2023
- **Search capabilities**: Find files by name patterns across years

### Current File Inventory
- **2022**: 10 documentation files (PDFs in English/French)
- **2023**: 20 files (10 PDFs + 10 SAS/SPSS syntax files)
- **Other years**: Folder structure created, ready for documentation

## Advanced Usage

### Create New Year Folders
```r
source("R/cchs_folder_structure.R")

# For future annual surveys
create_cchs_years(c(2024, 2025), "annual")

# For historical cycles (if needed)
create_cchs_years(c(2001), "cycle")
```

### Verify Structure
```r
source("R/cchs_structure_verification.R")
results <- run_complete_verification()
```

### Update File Inventory
```r
source("R/enhance_structure_with_files.R")
enhanced_data <- enhance_structure_with_files()
```