# Plan: ICES CCHS Dictionary Browser - GitHub Pages

## Overview

Create a searchable, interactive table of 14,005 CCHS variables from the ICES Data Dictionary, deployed as a static HTML page on GitHub Pages using Quarto + DT (DataTables).

## Specification

### User requirements
- Search/filter 14,005 ICES CCHS variables by name, label, module, type
- View which datasets contain each variable
- Fast client-side filtering (no server required)
- Accessible via GitHub Pages URL
- Updateable when data changes (re-render and deploy)

### Technical approach: Quarto + DT (Option 1)
- **Rendering**: Quarto HTML document with `embed-resources: true`
- **Table library**: DT (DataTables) - already in renv, proven in catalog-browser.qmd
- **Data source**: CSV exports (data/exports/ices_cchs_variables_for_sheets.csv)
- **Deployment**: GitHub Actions workflow → GitHub Pages

### Data columns to display

| Column | Source | Notes |
|--------|--------|-------|
| Variable | `variable_name` | Searchable, linkable to ICES |
| Module | `module` (derived) | First 3-4 chars of variable name |
| Label | `label` | Full-text searchable |
| Type | `type` | Num8, Char10, etc. |
| Format | `format` | Code list reference |
| Datasets | `n_datasets` | Count (numeric filter) |
| Sample | `sample_datasets` | Truncated list, expandable |

### Performance considerations
- 14,005 rows × 7 columns = 98,035 cells
- Estimated HTML size: 2-3 MB (acceptable for modern browsers)
- DT handles this with client-side pagination and deferred rendering
- `deferRender: true` option loads rows on demand

## Implementation plan

### Phase 1: Create the Quarto report

**File**: `reports/ices-dictionary-browser.qmd`

```yaml
---
title: "ICES CCHS Data Dictionary Browser"
subtitle: "Search 14,005 variables across 231 datasets"
author: "cchsflow-docs"
date: last-modified
format:
  html:
    toc: true
    toc-depth: 2
    theme: cosmo
    embed-resources: true
    self-contained: true
execute:
  echo: false
  warning: false
  message: false
---
```

**R code blocks**:
1. Load CSV data from `data/exports/ices_cchs_variables_for_sheets.csv`
2. Create clickable links to ICES website for each variable
3. Render DT table with filters and pagination

**DT configuration**:
```r
datatable(
  variables_df,
  filter = 'top',
  options = list(
    pageLength = 25,
    scrollX = TRUE,
    deferRender = TRUE,
    searchHighlight = TRUE,
    dom = 'Bfrtip',
    buttons = c('copy', 'csv')
  ),
  escape = FALSE  # Allow HTML links
)
```

### Phase 2: Add datasets summary tab

Create a second table showing the 231 datasets:
- Dataset ID, variable count, type, region
- Sortable by variable count
- Links to filter main table by dataset

### Phase 3: GitHub Actions workflow

**File**: `.github/workflows/deploy-ices-browser.yml`

```yaml
name: Deploy ICES Dictionary Browser

on:
  push:
    paths:
      - 'reports/ices-dictionary-browser.qmd'
      - 'data/exports/ices_cchs_*.csv'
  workflow_dispatch:

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: r-lib/actions/setup-r@v2
      - name: Install renv and restore packages
        run: |
          Rscript -e "install.packages('renv')"
          Rscript -e "renv::restore(prompt = FALSE)"
      - name: Get renv library path
        id: renv-path
        run: echo "path=$(Rscript -e 'cat(renv::paths$library())')" >> $GITHUB_OUTPUT
      - uses: quarto-dev/quarto-actions/setup@v2
      - name: Render Quarto
        run: quarto render reports/ices-dictionary-browser.qmd
        env:
          R_LIBS_USER: ${{ steps.renv-path.outputs.path }}
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./reports
          destination_dir: ices-browser
```

### Phase 4: Enable GitHub Pages

Repository Settings → Pages → Source: Deploy from branch `gh-pages`

Result URL: `https://big-life-lab.github.io/cchsflow-docs/ices-browser/`

## Files to create/modify

| Action | File | Purpose |
|--------|------|---------|
| Create | `reports/ices-dictionary-browser.qmd` | Main browser page |
| Create | `.github/workflows/deploy-ices-browser.yml` | CI/CD deployment |
| Modify | `README.md` | Add link to live browser |

## Verification

1. **Local test**: `quarto render reports/ices-dictionary-browser.qmd` and open HTML
2. **Table functionality**: Search, filter, pagination, export buttons work
3. **Performance**: Page loads in <5 seconds, scrolling is smooth
4. **Deployment**: Push triggers workflow, page appears at GH Pages URL
5. **Links**: Variable links open correct ICES page

## Future enhancements (not in scope)

- Value format lookup (show code/label pairs on click)
- Full availability matrix view
- Cross-variable comparison
- Shiny WebAssembly for server-side filtering (if DT performance insufficient)
