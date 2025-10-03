# R Environment Configuration

## Compatibility Floor

This project maintains compatibility with **R 4.2+** to ensure it runs in controlled environments.

**Current Development Environment:**

- R version: **4.4.3**
- Platform: macOS (aarch64-apple-darwin20)
- Environment management: **renv 1.1.5**

## R Version Strategy

- **Compatibility floor**: R 4.2 (approximately 1-2 years behind current release)
- **Development version**: R 4.4.3 (current)
- **Review cadence**: Annual (update compatibility floor after testing)

## Package Management

This project uses **renv** for reproducible package management.

### First-time Setup

```r
# Install renv if not already installed
install.packages("renv")

# Restore project packages
renv::restore()
```

### Core Dependencies

Key packages used in this project:

**Data Processing:**

- yaml (2.3.10) - Catalog file handling
- dplyr (1.1.4) - Data manipulation
- purrr (1.1.0) - Functional programming
- readr (2.1.5) - CSV/data reading
- tibble (3.3.0) - Modern data frames
- stringr (1.5.2) - String operations

**OSF Integration:**

- httr (1.4.7) - HTTP requests
- jsonlite (2.0.0) - JSON parsing
- osfr (0.2.9) - OSF.io client (with custom fixes)
- crul (1.6.0) - HTTP client
- curl (7.0.0) - HTTP library

**Reporting & Documentation:**

- knitr (1.50) - Dynamic documents
- rmarkdown (2.30) - R Markdown
- gt (1.1.0) - Grammar of Tables
- DT (0.34.0) - Interactive tables
- ggplot2 (4.0.0) - Data visualization
- htmltools (0.5.8.1) - HTML generation
- htmlwidgets (1.6.4) - Interactive widgets

**Utilities:**

- fs (1.6.6) - File system operations
- here (1.0.2) - Project-relative paths
- git2r (0.36.2) - Git integration
- config (0.3.2) - Configuration management
- digest (0.6.37) - Hashing/checksums
- googledrive (2.1.2) - Google Drive integration

## Development Workflow

### Adding New Packages

```r
# Install new package
install.packages("packagename")

# Update lockfile
renv::snapshot()
```

### Updating Packages

```r
# Update specific package
renv::update("packagename")

# Update all packages
renv::update()

# Capture updates
renv::snapshot()
```

### Package Installation with pak

For faster installation, you can use `pak`:

```r
# Install pak
install.packages("pak")

# Install packages with pak
pak::pkg_install("yaml")
```

## Controlled Environments (StatsCan/ICES)

### Pre-deployment Checklist

1. **Test with compatibility floor R version** (R 4.2):

   ```r
   # Using rig to switch versions
   rig use 4.2
   ```
2. **Verify all packages install successfully**:

   ```r
   renv::restore()
   ```
3. **Run validation scripts**:

   ```r
   source("R/validate_catalog.R")
   ```
4. **Check for deprecated functions**:

   - Review R CMD check output
   - Test with controlled environment R version

### Offline Installation

For environments without internet access:

```r
# Create bundle with all packages
renv::bundle(file = "cchs-docs-bundle.tar.gz")

# On target system, restore from bundle
renv::restore(bundle = "cchs-docs-bundle.tar.gz")
```

## IDE Configuration

### RStudio use

**Using rig to manage R versions:**

```bash
# Install rig
# macOS: brew install rig
# Windows: Download from https://github.com/r-lib/rig

# List available R versions
rig list

# Install R 4.2 (compatibility floor)
rig add 4.2

# Switch to R 4.2
rig default 4.2

# Or use specific version for this project
rig rstudio 4.2
```

RStudio will automatically detect and use renv when opening the project.

### Positron

Positron auto-detects available R versions. Select R 4.2+ from the interpreter menu.

### VS Code

Configure R extension to use renv:

```json
{
  "r.rterm.option": ["--vanilla"],
  "r.rpath.mac": "/usr/local/bin/R"
}
```

## Bioconductor (Not Currently Used)

This project does not currently use Bioconductor packages. If Bioconductor packages are added in the future:

- R 4.2 → Bioconductor 3.16
- R 4.3 → Bioconductor 3.18
- R 4.4 → Bioconductor 3.19
- R 4.5 → Bioconductor 3.20

## Version History

| Date       | R Version | renv Version | Notes                         |
| ---------- | --------- | ------------ | ----------------------------- |
| 2025-10-03 | 4.4.3     | 1.1.5        | Initial renv setup for v3.0.0 |

## Maintenance Schedule

- **Compatibility floor review**: Annual (Q1)
- **Package updates**: As needed, tested before deployment
- **R version updates**: After testing in main projects

## Troubleshooting

### renv Not Activating

```r
# Manually activate renv
source("renv/activate.R")
```

### Package Installation Fails

```r
# Try updating renv
renv::upgrade()

# Clear cache and retry
renv::purge()
renv::restore()
```

### Version Conflicts

```r
# Check package status
renv::status()

# Align with lockfile
renv::restore()
```

## Resources

- [renv documentation](https://rstudio.github.io/renv/)
- [rig documentation](https://github.com/r-lib/rig)
- [pak documentation](https://pak.r-lib.org/)

---

**Last Updated**: 2025-10-03
**Maintained By**: CCHS Documentation Team
