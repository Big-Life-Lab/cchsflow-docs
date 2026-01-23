# CCHS Variable Ontology

Development folder for the CCHS variable ontology - semantic mapping of survey variables to standardised concepts.

## Primary purpose

Support **variable harmonisation** and **prevalence estimation** in the CCHS and related surveys.

### The problem with cchsflow worksheets

The `cchsflow` package worksheets are effective for generating harmonisation code, but they have limitations:

- **Hard to develop**: Creating new variable mappings requires understanding the worksheet structure and R code generation
- **Hard to maintain**: Changes across cycles require manual updates without clear traceability
- **Hard to use**: The worksheets lack explanation of *why* variables are linked or *how* they differ

An ontology approach provides:
- Explicit relationships between variables
- Documented rationale for mappings
- Machine-readable structure for validation and tooling

## First use case: same-variable-different-name

The simplest harmonisation case is **1:1 matching** (also called "pass through" harmonisation):

> Variables with exactly the same question wording, universe, and response categories, but different variable names across cycles.

### Proposed relationship type

Rather than generic "exact_synonym" (which could mean many things), use an explicit relationship:

**`same_variable_different_name`**
- Source and target variables have identical:
  - Question text
  - Response categories/codes
  - Target population (universe)
- Only the variable name differs between cycles

This is more precise than ontology synonyms because it captures the *reason* for equivalence (naming change, not conceptual equivalence).

### Example

| Cycle | Variable | Question |
|-------|----------|----------|
| 2001  | `SMKDSTY` | "At the present time, do you smoke cigarettes daily, occasionally or not at all?" |
| 2003  | `SMK_005` | "At the present time, do you smoke cigarettes daily, occasionally or not at all?" |

These would be linked as: `SMKDSTY same_variable_different_name SMK_005`

## Future use cases

Beyond 1:1 matching, the ontology could support:

1. **Derivation rules**: Variables with different questions but mappable responses
2. **Conceptual hierarchies**: Smoking → tobacco use → substance use
3. **Standard vocabulary links**: SNOMED-CT, LOINC codes for interoperability
4. **Cross-survey harmonisation**: CCHS ↔ CHMS ↔ international surveys

## Status

Planning phase - defining relationship types and data model.

## Documents

- [REQUIREMENTS.md](REQUIREMENTS.md) - Full requirements, use cases, and existing approaches review

## Related

- `../cchs-variable-dictionary/` - Variable metadata from Statistics Canada CCHS
- `cchsflow` package - Existing variable harmonisation rules
- CCHS Variable Browser - Searchable interface to 14,005 variables
