# CCHS Documentation Project - AI Context

## Project Overview
This repository manages Canadian Community Health Survey (CCHS) documentation using OSF.io. We've created a complete folder structure for CCHS cycles from 2001-2023 and tools to manage/verify the documentation.

## What We Built
1. **OSF.io Integration**: R scripts to authenticate and interact with OSF project `6p3n9`, Documentation component `jm8bx`
2. **Folder Structure Creation**: Automated creation of CCHS folder hierarchies for all survey years
3. **Structure Verification**: Tools to verify expected vs actual folder/file structure
4. **Data Management**: Comprehensive data files capturing structure and file inventories

## Key Technical Details

### CCHS Survey Structure
- **Early Cycles (2001, 2003, 2005)**: Biannual surveys with naming `1.1`, `2.1`, `3.1`
- **Annual Surveys (2006-2023)**: Standard `12-Month` structure
- **Folder Pattern**: `YEAR/[CYCLE|12-Month]/Master/[Docs|Layout]`

### Authentication Setup
- Uses OSF Personal Access Token stored in `.env` file
- Config managed via `config` package with `config.yml`
- Token needs full read/write permissions for private project

### Current Status
- **All folder structures created**: 2001, 2003, 2005 (cycles) + 2006-2023 (annual)
- **Files documented**: 30 files found across 2022 (10 files) and 2023 (20 files)
- **Pagination issue**: OSF API only returns 10 folders at a time, but all folders exist on website

## Important Files

### Core Scripts
- `R/setup_osf.R` - OSF authentication and connection
- `R/cchs_folder_structure.R` - Folder creation and management
- `R/load_cchs_structure.R` - Simple data loading (recommended entry point)

### Data Files
- `data/cchs_structure_enhanced.RData` - Complete structure with file listings
- Contains: folder hierarchy, file inventories, metadata, verification functions

### Configuration
- `.env` - OSF credentials (not committed)
- `config.yml` - Project configuration with OSF IDs

## Key Functions
```r
# Load data
source("R/load_cchs_structure.R")
load_cchs_structure()  # Loads cchs_structure_data globally

# Quick access
cchs_summary()                    # Overview
get_expected_years()              # All years 2001-2023
search_files("User_Guide")        # Find files by pattern
get_files_for_year(2023)         # Files for specific year

# Create new folders (if needed)
source("R/cchs_folder_structure.R")
create_cchs_years(c(2024), "annual")  # New annual years
```

## Data Structure Notes
User mentioned the current structure is quite complex with nested metadata, and prefers simpler folder/file listings. Current structure is comprehensive but could be simplified to just:
- Year → file paths mapping
- Or flat data frame with year, path, type columns

## OSF Project Details
- **Project ID**: `6p3n9` (CCHS Docs)
- **Documentation Component**: `jm8bx`
- **URL**: https://osf.io/6p3n9/ (main), https://osf.io/jm8bx/files/osfstorage (documentation)
- **Access**: Private project, requires proper token permissions

## Future Considerations
- Structure ready for documentation files to be added to Docs/Layout folders
- File enhancement script can be re-run when new files added
- Verification scripts help ensure structure integrity
- Could create simplified data structure focused just on file listings

## Technical Context for AI
- R-centric workflow using `osfr`, `dplyr`, `config` packages
- OSF API has pagination limitations (shows 10 folders max in listings)
- User prefers .RData over YAML for R workflows
- Focus on practical, simple access to structure data
- Built comprehensive verification system but keep usage simple