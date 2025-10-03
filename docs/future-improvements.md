# Future Improvements

## Schema-Driven Validation (High Priority)

### Current Problem
The validation script (`R/validate_catalog.R`) has extensive hard-coded validation logic:
- Hard-coded regex patterns for UID and canonical filenames
- Hard-coded enum lists (doc types, languages, temporal types, subcategories, etc.)
- Duplicated validation logic between schema definition and validation code
- Risk of schema and validator getting out of sync

**Example of the problem:**
```r
# In validate_catalog.R (hard-coded):
valid_doc_type <- c("master", "share", "pumf")
valid_subcategories <- c("main", "simp", "subs", "freq", "rev", "alt", "comp", "synt", "spec")
uid_pattern <- "^cchs-[0-9]{4}[sdm]-[msp]-[a-z-]+(-[a-z]{4})?-(e|f)-(pdf|...)-[0-9]{2}$"

# In cchs_schema_linkml.yaml (also defined):
DocTypeEnum:
  permissible_values:
    master: ...
    share: ...
    pumf: ...
```

This duplication led to issues in v3.0.0 development where:
- Schema was updated but validator wasn't updated correctly
- UID pattern parsing logic was complex and error-prone
- No automated check that validator matches schema

### Proposed Solution: LinkML-Generated Validation

Use LinkML's built-in validation capabilities instead of custom R code:

```r
# Future approach:
library(linkml)  # hypothetical R LinkML bindings
library(yaml)

# Load schema
schema <- linkml::load_schema("metadata/cchs_schema_linkml.yaml")

# Validate catalog directly against schema
catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")
validation_results <- linkml::validate(catalog, schema)

# All validation rules come from schema:
# - Enum membership
# - Pattern matching
# - Required fields
# - Type checking
```

### Benefits

1. **Single Source of Truth**: Schema definition IS the validation
2. **Automatic Updates**: Change schema → validation automatically updated
3. **Better Error Messages**: LinkML knows context and can give precise errors
4. **Cross-Language**: Same schema can validate in Python, R, or other languages
5. **Standard Compliance**: Follows LinkML/JSON-Schema best practices

### Implementation Plan (Future Version)

**Phase 1: Research** (v3.1 or v4.0)
- Investigate LinkML Python validation tools
- Check if R bindings exist or if we need to call Python from R
- Prototype validation with small catalog subset

**Phase 2: Hybrid Approach** (v3.1)
- Keep custom R validator for now
- Add automated tests that compare validator against schema
- Generate validator code from schema (code generation)

**Phase 3: Full Migration** (v4.0)
- Replace custom validator with schema-driven approach
- Add LinkML validation as CI/CD check
- Document migration path for existing catalogs

### Related Improvements

**Infrastructure Code Quality**
- Unit tests for cataloging functions
- Integration tests for full workflow
- Automated schema validation in CI/CD
- Type hints/documentation for all functions
- Separation of concerns (cataloging vs validation vs reporting)

**Current Pain Points**
- No tests for UID generation logic
- No tests for subcategory assignment
- Hard to verify changes don't break existing catalogs
- Manual validation of validation script updates

## Other Future Improvements

### Collection System Enhancements
- Automated collection generation based on user queries
- Collection versioning and dependency tracking
- Delta updates (only changed files)

### OSF Sync Improvements
- Incremental sync (only download changed files)
- Parallel downloads for faster sync
- Automatic conflict resolution

### Catalog Features
- Full-text search across file contents
- Semantic tagging and classification
- Automatic category detection from filenames
- Cross-reference detection between documents

---

**Priority**: High for v4.0
**Effort**: Medium (2-4 weeks research + implementation)
**Impact**: High (prevents bugs, reduces maintenance, improves reliability)
