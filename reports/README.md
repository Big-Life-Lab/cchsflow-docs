# CCHS Reports

Quarto-based reports for analyzing and documenting the CCHS catalog and synchronization status.

## 📊 Available Reports

### Catalog Browser (`catalog-browser.qmd`)

**Purpose**: Interactive catalog exploration and analysis

**Contents**:
- Survey overview and timeline
- File type distribution analysis
- Document availability matrix
- Detailed file inventories by year
- Download planning recommendations

**Generate**:
```r
library(quarto)
quarto_render("reports/catalog-browser.qmd")
```

**Outputs**: `catalog-browser.html`, `catalog-browser.pdf`

---

### Download Status Report (`download-status.qmd`)

**Purpose**: Comprehensive OSF.io synchronization status and verification

**Contents**:
- Executive summary of downloads
- Core documentation availability matrix
- File type distribution and statistics
- Folder structure evolution analysis
- OSF.io change detection results
- Sync recommendations and gap analysis
- Quality assurance verification

**Generate**:
```r
library(quarto)
quarto_render("reports/download-status.qmd")
```

**Outputs**: `download-status.html`, `download-status.pdf`

---

### Sync Workflow (`sync-workflow.qmd`)

**Purpose**: Executable workflow documentation for OSF.io synchronization

**Contents**:
- Git-based versioning setup
- Baseline snapshot creation
- Automated change detection
- Sync validation workflows
- Complete workflow execution
- Scheduling and automation examples

**Generate**:
```r
library(quarto)
quarto_render("reports/sync-workflow.qmd")
```

**Outputs**: `sync-workflow.html`, `sync-workflow.pdf`

**Note**: This is both documentation AND executable workflow

---

## 🚀 Generating Reports

### Generate All Reports

```r
library(quarto)

# Generate all reports
reports <- c(
  "reports/catalog-browser.qmd",
  "reports/download-status.qmd",
  "reports/sync-workflow.qmd"
)

for (report in reports) {
  cat(sprintf("Generating %s...\n", report))
  quarto_render(report)
}
```

### Generate Specific Format

```r
# HTML only
quarto_render("reports/catalog-browser.qmd", output_format = "html")

# PDF only
quarto_render("reports/download-status.qmd", output_format = "pdf")

# Both formats
quarto_render("reports/sync-workflow.qmd", output_format = "all")
```

### Generate with Parameters

```r
# Custom parameters
quarto_render(
  "reports/catalog-browser.qmd",
  execute_params = list(
    year_filter = 2020:2023,
    language = "EN"
  )
)
```

## 📋 Report Dependencies

### R Packages Required

```r
# Install required packages
install.packages(c(
  "quarto",      # Report rendering
  "dplyr",       # Data manipulation
  "gt",          # Publication-quality tables
  "DT",          # Interactive DataTables
  "ggplot2",     # Visualizations
  "readr",       # CSV reading
  "yaml",        # YAML reading
  "htmltools"    # HTML utilities
))
```

### Data Dependencies

Reports require:
- `cchs-osf-docs/` - OSF.io mirror (source files)
- `data/catalog/cchs_catalog.yaml` - Production catalog
- `R/load_cchs_structure.R` - Data loading functions
- `R/cchs_file_download.R` - File categorization functions
- `R/osf_sync_system.R` - Sync functions

## 🎨 Report Customization

### Modify Output Formats

Edit the YAML front matter in each `.qmd` file:

```yaml
format:
  html:
    toc: true
    theme: cosmo
    code-fold: true
  pdf:
    toc: true
    papersize: letter
```

### Add Custom Sections

Reports are standard Quarto documents - add R code chunks and markdown:

````markdown
## New Section

```{r}
# Your R code here
custom_analysis <- manifest %>%
  group_by(year, category) %>%
  summarize(count = n())
```
````

## 📊 Report Output Location

By default, reports are generated in the same directory as the `.qmd` file:

```
reports/
  ├── catalog-browser.qmd
  ├── catalog-browser.html          # Generated
  ├── catalog-browser.pdf           # Generated
  ├── download-status.qmd
  ├── download-status.html          # Generated
  ├── download-status.pdf           # Generated
  ├── sync-workflow.qmd
  ├── sync-workflow.html            # Generated
  └── sync-workflow.pdf             # Generated
```

**Note**: Generated HTML/PDF files are gitignored (add `reports/*.html` and `reports/*.pdf` to `.gitignore` if needed)

## 🔄 Automated Report Generation

### Scheduled Reports

```r
# Generate weekly status report (cron job)
# Save as: scripts/weekly_reports.R

library(quarto)
library(here)

setwd(here())

# Generate download status report
quarto_render("reports/download-status.qmd")

# Email or save to shared location
# (Add your distribution logic here)
```

**Cron entry** (Sunday 7 AM):
```bash
0 7 * * 0 cd /path/to/cchsflow-docs && Rscript scripts/weekly_reports.R
```

### GitHub Actions

See `.github/workflows/` for automated report generation examples.

## 🔍 Troubleshooting

### Report Won't Render

```r
# Check Quarto installation
system("quarto --version")

# Check required packages
library(quarto)
library(dplyr)
library(gt)
# etc.

# Check data files exist
file.exists("data/catalog/cchs_catalog.yaml")
dir.exists("cchs-osf-docs")
```

### Missing Data

```r
# Load and verify data
source("R/load_cchs_structure.R")
load_cchs_structure()

# Check loaded data
ls()  # Should show cchs_structure_data
```

### Rendering Errors

Check the specific error message - common issues:
- Missing R packages
- Data files not found
- Invalid YAML syntax
- Code chunk errors

## 📚 Related Documentation

- [Main README](../README.md) - Project overview
- [Collections Guide](../docs/collections-guide.md) - Working with collections
- [OSF Sync Guide](../docs/osf-sync-guide.md) - Synchronization workflows

---

**Reports are for internal analysis and documentation. They are not distributed with collections.**
