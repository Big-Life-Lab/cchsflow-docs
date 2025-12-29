#!/usr/bin/env python3
"""
Compare R and Python extractions to identify discrepancies.

Loads two YAML extraction files and compares:
- Variable counts
- Variable names
- Labels
- Category values and labels
- Frequencies

Usage:
    python compare_extractions.py <r_yaml> <py_yaml> [--output report.txt]

Requires: pyyaml
"""

import argparse
import sys
from pathlib import Path

import yaml


def load_yaml(path: str) -> dict:
    """Load YAML file."""
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def compare_categories(r_cats: list, py_cats: list, var_name: str) -> list:
    """Compare category lists between R and Python extractions."""
    issues = []

    r_by_value = {c.get('value'): c for c in r_cats}
    py_by_value = {c.get('value'): c for c in py_cats}

    r_values = set(r_by_value.keys())
    py_values = set(py_by_value.keys())

    # Check for missing values
    r_only = r_values - py_values
    py_only = py_values - r_values

    if r_only:
        issues.append(f"  Categories in R only: {sorted(r_only)}")
    if py_only:
        issues.append(f"  Categories in Python only: {sorted(py_only)}")

    # Check common values for label differences
    for value in r_values & py_values:
        r_cat = r_by_value[value]
        py_cat = py_by_value[value]

        r_label = r_cat.get('label', '').strip()
        py_label = py_cat.get('label', '').strip()

        if r_label != py_label:
            issues.append(f"  Value {value} label mismatch:")
            issues.append(f"    R:  {repr(r_label)}")
            issues.append(f"    Py: {repr(py_label)}")

        # Check frequencies (allow small floating point differences)
        r_freq = r_cat.get('frequency')
        py_freq = py_cat.get('frequency')
        if r_freq is not None and py_freq is not None:
            if abs(float(r_freq) - float(py_freq)) > 0.01:
                issues.append(f"  Value {value} frequency mismatch: R={r_freq}, Py={py_freq}")

    return issues


def compare_variables(r_vars: dict, py_vars: dict) -> tuple:
    """Compare variables between R and Python extractions."""
    summary = {
        'r_count': len(r_vars),
        'py_count': len(py_vars),
        'common': 0,
        'r_only': 0,
        'py_only': 0,
        'label_mismatches': 0,
        'category_issues': 0,
        'perfect_matches': 0
    }

    issues = []

    r_names = set(r_vars.keys())
    py_names = set(py_vars.keys())

    # Check for missing variables
    r_only = r_names - py_names
    py_only = py_names - r_names
    common = r_names & py_names

    summary['r_only'] = len(r_only)
    summary['py_only'] = len(py_only)
    summary['common'] = len(common)

    if r_only:
        issues.append(f"\n=== Variables in R only ({len(r_only)}) ===")
        for name in sorted(r_only)[:20]:
            issues.append(f"  {name}")
        if len(r_only) > 20:
            issues.append(f"  ... and {len(r_only) - 20} more")

    if py_only:
        issues.append(f"\n=== Variables in Python only ({len(py_only)}) ===")
        for name in sorted(py_only)[:20]:
            issues.append(f"  {name}")
        if len(py_only) > 20:
            issues.append(f"  ... and {len(py_only) - 20} more")

    # Compare common variables
    issues.append(f"\n=== Comparing {len(common)} common variables ===")

    for name in sorted(common):
        r_var = r_vars[name]
        py_var = py_vars[name]
        var_issues = []

        # Compare labels
        r_label = r_var.get('label', '').strip() if r_var.get('label') else ''
        py_label = py_var.get('label', '').strip() if py_var.get('label') else ''

        if r_label != py_label:
            var_issues.append(f"  Label mismatch:")
            var_issues.append(f"    R:  {repr(r_label)}")
            var_issues.append(f"    Py: {repr(py_label)}")
            summary['label_mismatches'] += 1

        # Compare categories
        r_cats = r_var.get('categories', []) or []
        py_cats = py_var.get('categories', []) or []

        if len(r_cats) != len(py_cats):
            var_issues.append(f"  Category count: R={len(r_cats)}, Py={len(py_cats)}")

        cat_issues = compare_categories(r_cats, py_cats, name)
        if cat_issues:
            var_issues.extend(cat_issues)
            summary['category_issues'] += 1

        if var_issues:
            issues.append(f"\n{name}:")
            issues.extend(var_issues)
        else:
            summary['perfect_matches'] += 1

    return summary, issues


def main():
    parser = argparse.ArgumentParser(description='Compare R and Python YAML extractions')
    parser.add_argument('r_yaml', help='Path to R extraction YAML')
    parser.add_argument('py_yaml', help='Path to Python extraction YAML')
    parser.add_argument('--output', '-o', help='Output report file (default: stdout)')
    parser.add_argument('--quiet', '-q', action='store_true', help='Only show summary')

    args = parser.parse_args()

    # Load files
    print(f"Loading R extraction: {args.r_yaml}")
    r_data = load_yaml(args.r_yaml)

    print(f"Loading Python extraction: {args.py_yaml}")
    py_data = load_yaml(args.py_yaml)

    # Compare
    r_vars = r_data.get('variables', {})
    py_vars = py_data.get('variables', {})

    summary, issues = compare_variables(r_vars, py_vars)

    # Build report
    report = []
    report.append("=" * 60)
    report.append("EXTRACTION COMPARISON REPORT")
    report.append("=" * 60)
    report.append("")
    report.append(f"R extraction:      {args.r_yaml}")
    report.append(f"Python extraction: {args.py_yaml}")
    report.append("")
    report.append("=== Summary ===")
    report.append(f"R variables:       {summary['r_count']}")
    report.append(f"Python variables:  {summary['py_count']}")
    report.append(f"Common variables:  {summary['common']}")
    report.append(f"R only:            {summary['r_only']}")
    report.append(f"Python only:       {summary['py_only']}")
    report.append(f"Perfect matches:   {summary['perfect_matches']}")
    report.append(f"Label mismatches:  {summary['label_mismatches']}")
    report.append(f"Category issues:   {summary['category_issues']}")
    report.append("")

    match_rate = summary['perfect_matches'] / summary['common'] * 100 if summary['common'] > 0 else 0
    report.append(f"Match rate: {match_rate:.1f}%")

    if not args.quiet:
        report.extend(issues)

    report_text = '\n'.join(report)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report_text)
        print(f"\nReport written to: {args.output}")
    else:
        print(report_text)

    # Exit with error if significant discrepancies
    if summary['r_only'] > 0 or summary['py_only'] > 0:
        return 1
    if match_rate < 95:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
