# Schema-Driven Validation Proposal

## Problem

The current bug (canonical filename duplicates) resulted from:
1. **Code duplication**: Validation logic hard-coded in R scripts separate from LinkML schema
2. **Pattern mismatch**: Schema patterns don't exactly match implementation
3. **No automated verification**: Changes to generation code aren't validated against schema

## Current State

### What Works
- LinkML schema exists with patterns defined (`metadata/cchs_schema_linkml.yaml`)
- Patterns exist for `cchs_uid` and `canonical_filename`
- Enum definitions exist for all categorical fields

### What's Broken
- **Schema pattern bugs found**:
  - `canonical_filename` pattern line 268: `[ef][nr]` should be `[a-z]+` (matches `en`/`fr`)
  - `canonical_filename` pattern: `[a-z]+$` should be `[a-z0-9]+$` (matches `webarchive`, `html`)

- **Generation vs Validation gap**:
  - `R/catalog_pumf_docs.R` generates filenames
  - `R/fix_osf_canonical_filenames.R` generates filenames
  - `R/deep_validate_catalog.R` validates with different pattern
  - `metadata/cchs_schema_linkml.yaml` defines yet another pattern
  - **4 different places defining the same thing!**

## Proposed Solutions

### Option 1: Quick Fix (Now - v3.0.0)
**Fix schema patterns to match current implementation**

**Pros**:
- Can do before commit
- Catches schema bugs
- No infrastructure changes needed

**Cons**:
- Doesn't solve root cause
- Still have duplication

**Implementation** (15 minutes):
1. Fix `canonical_filename` pattern in schema
2. Fix `cchs_uid` pattern if needed
3. Verify examples match patterns

---

### Option 2: Hybrid Approach (v3.1 - Recommended)
**Generate validation code from schema + add tests**

**Pros**:
- Single source of truth (schema)
- Automated code generation prevents drift
- Can implement incrementally
- Tests catch regressions

**Cons**:
- Requires modest tooling investment
- Need to learn LinkML code generation

**Implementation** (1-2 weeks):

#### Step 1: Fix Schema Patterns (Now)
- Fix patterns as in Option 1

#### Step 2: Schema-to-R Code Generation (Week 1)
```r
# R/generate_validators_from_schema.R
# Reads LinkML schema and generates R validation functions

library(yaml)

schema <- yaml::read_yaml("metadata/cchs_schema_linkml.yaml")

# Extract patterns
uid_pattern <- schema$slots$cchs_uid$pattern
canonical_pattern <- schema$slots$canonical_filename$pattern

# Extract enums
doc_types <- names(schema$enums$DocTypeEnum$permissible_values)
languages <- names(schema$enums$LanguageEnum$permissible_values)
# ... etc

# Generate R code
cat("# AUTO-GENERATED FROM SCHEMA - DO NOT EDIT\n")
cat("# Generated:", Sys.time(), "\n\n")
cat("UID_PATTERN <- \"", uid_pattern, "\"\n", sep = "")
cat("CANONICAL_PATTERN <- \"", canonical_pattern, "\"\n", sep = "")
cat("VALID_DOC_TYPES <- c(\"", paste(doc_types, collapse = "\", \""), "\")\n", sep = "")
# ... etc
```

Save to `R/schema_constants.R` (auto-generated)

#### Step 3: Update Validators to Use Generated Constants
```r
# R/deep_validate_catalog.R
source("R/schema_constants.R")  # Load schema-generated constants

# Instead of hard-coded:
# uid_pattern <- "^cchs-[0-9]{4}..."
# Use:
uid_pattern <- UID_PATTERN  # From schema
```

#### Step 4: Add Pre-Commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
# Regenerate validators if schema changed

if git diff --cached --name-only | grep -q "metadata/cchs_schema_linkml.yaml"; then
    echo "Schema changed - regenerating validators..."
    Rscript R/generate_validators_from_schema.R
    git add R/schema_constants.R
fi
```

#### Step 5: Add Tests
```r
# tests/test_schema_compliance.R
test_that("Generated validators match schema patterns", {
  source("R/schema_constants.R")
  schema <- yaml::read_yaml("metadata/cchs_schema_linkml.yaml")

  expect_equal(UID_PATTERN, schema$slots$cchs_uid$pattern)
  expect_equal(CANONICAL_PATTERN, schema$slots$canonical_filename$pattern)
})

test_that("All catalog files match schema patterns", {
  catalog <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")

  for (file in catalog$files) {
    expect_match(file$cchs_uid, UID_PATTERN)
    expect_match(file$canonical_filename, CANONICAL_PATTERN)
  }
})
```

**Benefits**:
- Schema is single source of truth
- Code generation prevents manual sync errors
- Pre-commit hook prevents schema/code drift
- Tests catch regressions automatically

---

### Option 3: Full LinkML Validation (v4.0 - Future)
**Use LinkML Python validator via reticulate**

**Pros**:
- Industry standard approach
- Comprehensive validation
- Schema evolution support

**Cons**:
- Requires Python dependency
- More complex setup
- Bigger change

**Implementation** (2-4 weeks):
```r
# R/validate_with_linkml.R
library(reticulate)

# Use Python LinkML validator
linkml <- import("linkml_runtime.loaders")
validator <- import("linkml_runtime.utils.schemaview")

# Load schema and validate
schema <- validator$SchemaView("metadata/cchs_schema_linkml.yaml")
catalog_data <- yaml::read_yaml("data/catalog/cchs_catalog.yaml")

# Validate returns detailed errors
validation_report <- linkml$validate(catalog_data, schema)
```

---

## Recommendation

**For v3.0.0 (now)**: Option 1 - Quick fix schema patterns
**For v3.1 (next sprint)**: Option 2 - Hybrid with code generation
**For v4.0 (future)**: Option 3 - Full LinkML validation

This incremental approach:
1. Fixes immediate bugs without blocking commit
2. Prevents future drift with modest tooling
3. Leaves path open to full LinkML adoption later

## Schema Pattern Fixes Needed

### 1. canonical_filename pattern
**Current (line 268)**:
```yaml
pattern: "^cchs_[0-9]{4}[sdm]_[a-z-]+(_[a-z]{4})?_[msp]_[ef][nr]_[0-9]+_v[0-9]+\\.[a-z]+$"
```

**Problems**:
- `[ef][nr]` → Matches only `en`, `er`, `fn`, `fr` (should match `en` or `fr`)
- `[a-z]+$` → Doesn't match `webarchive`, `html` (needs digits)

**Fixed**:
```yaml
pattern: "^cchs_[0-9]{4}[sdm]_[a-z0-9-]+(_[a-z]{4})?_[msp]_[a-z]+_[0-9]+_v[0-9]+\\.[a-z0-9]+$"
```

Changes:
- `[ef][nr]` → `[a-z]+` (matches full language code)
- `[a-z]+$` → `[a-z0-9]+$` (matches extensions with digits)

### 2. Verify cchs_uid pattern
**Current (line 193)**:
```yaml
pattern: "^cchs-[0-9]{4}[sdm]-[msp]-[a-z-]+(-[a-z]{4})?-(e|f)-(pdf|doc|...)-[0-9]{2}$"
```

**Issue**: Extension list is incomplete (doesn't have `html`, `webarchive`)

**Fixed**:
```yaml
pattern: "^cchs-[0-9]{4}[sdm]-[msp]-[a-z0-9-]+(-[a-z]{4})?-(e|f)-(pdf|doc|docx|sas|sps|do|dct|txt|csv|xlsx|mdb|log|xml|webarchive|html)-[0-9]{2}$"
```

Also changed `[a-z-]+` → `[a-z0-9-]+` to match categories with digits

## Implementation Checklist

- [ ] Fix `canonical_filename` pattern in schema
- [ ] Fix `cchs_uid` pattern in schema
- [ ] Verify all examples in schema still match patterns
- [ ] Run validation to confirm all 1,421 files match new patterns
- [ ] Update deep_validate_catalog.R to use schema patterns (or note difference)
- [ ] Document pattern format in schema comments
- [ ] (Optional) Create schema validator generator script for v3.1

---

**Priority**: Option 1 (fix patterns) before v3.0.0 commit
**Effort**: 15 minutes (Option 1), 1-2 weeks (Option 2)
**Impact**: High - prevents future bugs, reduces maintenance burden
