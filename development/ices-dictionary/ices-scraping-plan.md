# ICES Data Dictionary Scraping Plan

## Target Website
https://datadictionary.ices.on.ca/Applications/DataDictionary/Library.aspx?Library=CCHS

## Goal
Capture CCHS variable availability from ICES shared data files - which variables are available for each survey cycle.

## Current Status (2026-01-21)

### Completed
- [x] **Level 1 scraping complete**: 231 ICES CCHS datasets extracted
- [x] **Catalog generated**: `data/catalog/ices_cchs_datasets.yaml`
- [x] **R script created**: `R/scrape_ices_cchs.R`
- [x] **Storage design**: Dataset-centric YAML schema (matches repo structure)

### Not Started
- [ ] **Level 2**: Scrape variable list for each dataset (requires browser automation)
- [ ] **Level 3**: Variable detail pages (optional)

### Technical Notes
- **robots.txt**: Not found (404) - no explicit restrictions
- **Session handling**: ASP.NET session cookies work
- **VIEWSTATE decoding**: Contains binary with NUL bytes - use byte-by-byte conversion
- **renv issues**: Use `Rscript --vanilla` with standalone script to avoid version conflicts

## Website Structure (3 Levels)

### Level 1: Library Page
- URL: `Library.aspx?Library=CCHS`
- Contains: 33 CCHS dataset groups (2000-2021)
- Each group contains multiple dataset variants (SHARE, LINK, BOOT, etc.)

**Datasets identified (231 total):**
- CCHS2001_ONT_SHARE_11, CCHS2001_ONT_LINK_11, etc.
- Years: 2001-2021
- Types: ONT_SHARE, ONT_LINK, CAN_SHARE, PUMF, etc.

### Level 2: Dataset Page
- Shows list of variables in the selected dataset
- Need to navigate via ASP.NET postback (JavaScript-based navigation)

### Level 3: Variable Detail Page
- Shows variable metadata
- **Key target**: Availability by survey cycle/year

## Technical Challenges

1. **ASP.NET WebForms**: Site uses postback navigation requiring:
   - VIEWSTATE tokens
   - EVENTVALIDATION tokens
   - Session cookies

2. **No direct URLs**: Navigation requires POST requests with form data

3. **Dynamic content**: Variable lists loaded via postback

## Proposed Solution: Python + Selenium/Playwright

### Approach 1: Browser Automation (Recommended)
```python
# Use Playwright or Selenium to:
# 1. Navigate to library page
# 2. Click each dataset link
# 3. Extract variable list
# 4. Click each variable for details
# 5. Extract availability matrix
```

### Approach 2: Session-based requests
```python
# Use requests with session to:
# 1. GET library page, capture VIEWSTATE
# 2. POST to simulate clicks
# 3. Parse HTML responses
```

## Data to Extract

For each variable:
- Variable name
- Description
- Data type
- Available cycles/years (the key data!)
- Dataset membership

## Output Format

```yaml
# ices_cchs_variables.yaml
variables:
  - name: "ADM_N09"
    description: "Age in years"
    cycles:
      - cycle: "2001"
        available: true
        dataset: "CCHS2001_ONT_SHARE_11"
      - cycle: "2003"
        available: true
        dataset: "CCHS2003_ONT_SHARE_21"
```

## Implementation Steps

1. **Setup**: Create R or Python script with browser automation
2. **Level 1**: Scrape dataset list (already have 231 datasets)
3. **Level 2**: For each dataset, scrape variable list
4. **Level 3**: For each variable, scrape availability details
5. **Output**: Generate YAML/CSV catalog of ICES variable availability
6. **Integration**: Merge with existing cchsflow-docs catalogs

## Estimated Scope

- 231 datasets
- ~500-2000 variables per dataset (estimate)
- ~100,000+ variable-dataset combinations
- Need rate limiting to be respectful of ICES servers

## Data Storage Design

### Approach: Dataset-Centric (matches repo focus)

The repo is organized around **datasets/databases**, so ICES data should follow the same pattern:
- Primary unit: Dataset (e.g., `CCHS2009_ONT_SHARE`)
- For each dataset: List of variables it contains
- Variable-centric views can be derived later if needed

### Storage Location

```
data/
└── catalog/
    └── ices_cchs_datasets.yaml    # Dataset catalog with variables
```

### YAML Schema (dataset-centric)

```yaml
# data/catalog/ices_cchs_datasets.yaml
catalog_metadata:
  version: v1.0.0
  created_date: '2025-01-21'
  last_updated: '2025-01-21'
  source: ICES Data Dictionary
  source_url: https://datadictionary.ices.on.ca/Applications/DataDictionary/Library.aspx?Library=CCHS
  total_datasets: 231
  years_covered: 2001-2021
  ices_library: CCHS

datasets:
  - dataset_id: CCHS2001_ONT_SHARE_11
    year: '2001'
    cycle: '1.1'
    type: SHARE
    region: Ontario
    linkage: false
    group: "01. CCHS 2000-2001 Canadian Community Health Survey"
    variable_count: 0  # to be populated
    variables:
      - name: ADM_N09
        label: "Age - 9 groups"
      - name: GEOAGPRV
        label: "Province"
      # ... all variables in this dataset

  - dataset_id: CCHS2001_ONT_LINK_11
    year: '2001'
    cycle: '1.1'
    type: LINK
    region: Ontario
    linkage: true
    group: "02. CCHS Cycle 1.1 Extending the Wealth..."
    variable_count: 0
    variables:
      - name: ADM_N09
        label: "Age - 9 groups"
      # ...

  # ... (231 datasets total)
```

### Scraping Strategy (Dataset-first)

1. **Level 1 (done)**: Extract 231 dataset IDs from Library page
2. **Level 2**: For each dataset, navigate to its page and extract variable list
3. **Level 3 (optional)**: For key variables, get detailed info from variable page

### Integration with Existing Catalogs

- **cchs_catalog.yaml** → Documentation files (PDFs, DDI)
- **ices_cchs_datasets.yaml** → ICES shared data availability
- Cross-reference by year/cycle to link documentation with available data

## Next Steps (Priority Order)

1. ~~Confirm scraping is permitted (check robots.txt, terms of use)~~ ✓ Done
2. ~~Extract dataset list (Level 1)~~ ✓ Done - 231 datasets in `ices_cchs_datasets.yaml`
3. **TODO: Level 2 scraping** - Get variable list for each dataset
   - Requires browser automation (chromote or RSelenium)
   - Site uses ASP.NET postbacks - can't use simple HTTP requests
4. Update catalog with variable counts and names
5. Optional: Level 3 variable details

## Files Created

| File | Purpose | Status |
|------|---------|--------|
| `data/catalog/ices_cchs_datasets.yaml` | Dataset catalog (231 entries) | ✓ Complete |
| `R/scrape_ices_cchs.R` | R script for scraping | ✓ Level 1 working |
| `docs/ices-scraping-plan.md` | This plan document | ✓ Current |

## How to Resume This Work

### To regenerate the dataset catalog:
```bash
# Use standalone script (avoids renv issues)
cat > /tmp/generate_ices_catalog.R << 'EOF'
# ... (see R/scrape_ices_cchs.R for full code)
EOF
Rscript --vanilla /tmp/generate_ices_catalog.R
```

### To implement Level 2 (variable scraping):
1. Install chromote: `remotes::install_github("rstudio/chromote")`
2. Use browser automation to:
   - Navigate to Library.aspx?Library=CCHS
   - Click each dataset link (triggers `__doPostBack`)
   - Extract variable table from resulting page
   - Update `ices_cchs_datasets.yaml` with variables

### Alternative: Contact ICES
Request machine-readable data dictionary export directly.
Contact: helpdesk@ices.on.ca

## Dataset Summary (from Level 1)

| Type | Count | Description |
|------|-------|-------------|
| SHARE | 93 | Ontario shared files |
| BOOT | 87 | Bootstrap weight files |
| LINK | 27 | Linked files |
| INC | 12 | Income imputation |
| OTHER | 7 | Miscellaneous |
| PUMF | 5 | Public use files |

| Region | Count |
|--------|-------|
| Ontario | 181 |
| Unknown | 32 |
| Canada | 18 |
