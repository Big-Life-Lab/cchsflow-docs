#!/usr/bin/env python3
"""
Validate PDF extraction against DDI XML (canonical source).

DDI XML files are the authoritative source for PUMF variables - they were used
to generate the PDF data dictionaries. Validating against DDI identifies
extraction bugs that can then be fixed and applied to Master file extraction.

Usage:
    python validate_against_ddi.py <ddi_xml> <extracted_yaml> [--output report.txt]

Requires: pyyaml, lxml
"""

import argparse
import sys
from pathlib import Path
from xml.etree import ElementTree as ET

import yaml


# DDI namespace
DDI_NS = {'ddi': 'http://www.icpsr.umich.edu/DDI'}


def parse_ddi(xml_path: str) -> dict:
    """Parse DDI XML file and extract variable definitions."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    variables = {}

    # Find all var elements (with or without namespace)
    var_elements = root.findall('.//ddi:var', DDI_NS)
    if not var_elements:
        # Try without namespace
        var_elements = root.findall('.//var')

    for var_elem in var_elements:
        var_name = var_elem.get('name')
        if not var_name:
            continue

        # Extract label
        label_elem = var_elem.find('ddi:labl', DDI_NS)
        if label_elem is None:
            label_elem = var_elem.find('labl')
        label = label_elem.text.strip() if label_elem is not None and label_elem.text else ''

        # Extract universe
        universe_elem = var_elem.find('ddi:universe', DDI_NS)
        if universe_elem is None:
            universe_elem = var_elem.find('universe')
        universe = universe_elem.text.strip() if universe_elem is not None and universe_elem.text else ''

        # Extract location (position, width)
        loc_elem = var_elem.find('ddi:location', DDI_NS)
        if loc_elem is None:
            loc_elem = var_elem.find('location')
        position = loc_elem.get('StartPos') if loc_elem is not None else None
        width = loc_elem.get('width') if loc_elem is not None else None

        # Extract categories
        categories = []
        cat_elements = var_elem.findall('ddi:catgry', DDI_NS)
        if not cat_elements:
            cat_elements = var_elem.findall('catgry')

        for cat_elem in cat_elements:
            # Value
            val_elem = cat_elem.find('ddi:catValu', DDI_NS)
            if val_elem is None:
                val_elem = cat_elem.find('catValu')
            if val_elem is None or val_elem.text is None:
                continue

            try:
                value = int(val_elem.text.strip())
            except ValueError:
                # Some values might be non-numeric codes
                value = val_elem.text.strip()

            # Label
            cat_label_elem = cat_elem.find('ddi:labl', DDI_NS)
            if cat_label_elem is None:
                cat_label_elem = cat_elem.find('labl')
            cat_label = cat_label_elem.text.strip() if cat_label_elem is not None and cat_label_elem.text else ''

            # Frequency (unweighted)
            freq = None
            for stat_elem in cat_elem.findall('ddi:catStat', DDI_NS) + cat_elem.findall('catStat'):
                if stat_elem.get('wgtd') is None and stat_elem.get('type') == 'freq':
                    try:
                        freq = float(stat_elem.text.strip())
                    except (ValueError, AttributeError):
                        pass
                    break

            categories.append({
                'value': value,
                'label': cat_label,
                'frequency': freq
            })

        variables[var_name] = {
            'name': var_name,
            'label': label,
            'universe': universe,
            'position': position,
            'length': width,
            'categories': categories
        }

    return variables


def load_extraction(yaml_path: str) -> dict:
    """Load extracted YAML file."""
    with open(yaml_path, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
    return data.get('variables', {})


def normalize_label(label: str) -> str:
    """Normalize label for comparison (case-insensitive, whitespace-normalized, quote-normalized)."""
    if not label:
        return ''
    # Normalize all quote variants to straight ASCII quotes
    # Single quotes: LEFT/RIGHT SINGLE QUOTATION MARK, MODIFIER LETTER APOSTROPHE, PRIME, GRAVE
    label = label.replace('\u2018', "'").replace('\u2019', "'")  # ' '
    label = label.replace('\u02BC', "'").replace('\u2032', "'").replace('`', "'")  # ʼ ′
    # Double quotes: LEFT/RIGHT DOUBLE QUOTATION MARK, DOUBLE LOW-9, DOUBLE PRIME
    label = label.replace('\u201C', '"').replace('\u201D', '"')  # " "
    label = label.replace('\u201E', '"').replace('\u2033', '"')  # „ ″
    # Normalize whitespace and case
    return ' '.join(label.upper().split())


def parse_range_code(code):
    """Parse a range code like '00-12' or '000-365' into (start, end) tuple.

    Returns None if not a range code.
    """
    if isinstance(code, str) and '-' in code:
        parts = code.split('-')
        if len(parts) == 2:
            try:
                return (int(parts[0]), int(parts[1]))
            except ValueError:
                pass
    return None


def is_covered_by_range(code, ranges):
    """Check if a code is covered by any range in the list."""
    if not isinstance(code, int):
        return False
    for range_code, (start, end) in ranges:
        if start <= code <= end:
            return True
    return False


def compare_categories(ddi_cats: list, ext_cats: list, var_name: str) -> list:
    """Compare category lists between DDI and extraction.

    Note: PDF data dictionaries only include categories with non-zero frequency.
    DDI includes all possible categories. We only compare categories that have
    non-zero frequency in DDI, since those are the ones expected in the PDF.

    Range codes in extraction (e.g., '00-12') represent collapsed continuous
    variables. DDI has individual codes (0, 1, 2, ..., 12). We handle this by
    checking if DDI codes fall within extraction ranges.
    """
    issues = []

    # Filter DDI categories to only those with non-zero frequency
    # (PDF omits zero-frequency categories)
    ddi_nonzero = [c for c in ddi_cats if c.get('frequency', 0) > 0]

    # Normalize codes for comparison (DDI may have strings, extraction may have floats)
    def normalize_code(val):
        """Convert code to comparable form - use string for decimals, int otherwise."""
        if isinstance(val, str):
            try:
                if '.' in val:
                    return float(val)
                # Keep range codes as strings
                if '-' in val:
                    return val
                return int(val)
            except ValueError:
                return val
        return val

    ddi_by_value = {normalize_code(c['value']): c for c in ddi_nonzero}
    ext_by_value = {normalize_code(c['value']): c for c in ext_cats}

    ddi_values = set(ddi_by_value.keys())
    ext_values = set(ext_by_value.keys())

    # Identify range codes in extraction
    ext_ranges = []
    for code in ext_values:
        parsed = parse_range_code(code)
        if parsed:
            ext_ranges.append((code, parsed))

    # Filter out DDI values that are covered by extraction ranges
    ddi_covered_by_range = set()
    for ddi_val in ddi_values:
        if is_covered_by_range(ddi_val, ext_ranges):
            ddi_covered_by_range.add(ddi_val)

    # Adjust missing/extra calculations
    missing = ddi_values - ext_values - ddi_covered_by_range
    extra = ext_values - ddi_values
    # Range codes in extra are expected (they cover DDI individual codes)
    extra_ranges = {code for code in extra if parse_range_code(code) is not None}
    extra_real = extra - extra_ranges

    if missing:
        issues.append(f"  MISSING categories (in DDI with freq>0, not in extraction): {sorted(missing)}")
    if extra_real:
        issues.append(f"  EXTRA categories (in extraction, not in DDI): {sorted(extra_real)}")

    # Compare common categories
    for value in ddi_values & ext_values:
        ddi_cat = ddi_by_value[value]
        ext_cat = ext_by_value[value]

        # Label comparison (normalized)
        ddi_label = normalize_label(ddi_cat.get('label', ''))
        ext_label = normalize_label(ext_cat.get('label', ''))

        if ddi_label != ext_label:
            issues.append(f"  Value {value} label mismatch:")
            issues.append(f"    DDI: {repr(ddi_cat.get('label', ''))}")
            issues.append(f"    Ext: {repr(ext_cat.get('label', ''))}")

        # Frequency comparison (allow small differences)
        ddi_freq = ddi_cat.get('frequency')
        ext_freq = ext_cat.get('frequency')
        if ddi_freq is not None and ext_freq is not None:
            if abs(float(ddi_freq) - float(ext_freq)) > 1:
                issues.append(f"  Value {value} frequency mismatch: DDI={ddi_freq}, Ext={ext_freq}")

    return issues


def validate(ddi_vars: dict, ext_vars: dict) -> tuple:
    """Validate extraction against DDI."""
    summary = {
        'ddi_count': len(ddi_vars),
        'ext_count': len(ext_vars),
        'common': 0,
        'missing': 0,
        'extra': 0,
        'label_matches': 0,
        'label_mismatches': 0,
        'category_perfect': 0,
        'category_issues': 0
    }

    issues = []

    ddi_names = set(ddi_vars.keys())
    ext_names = set(ext_vars.keys())

    missing = ddi_names - ext_names
    extra = ext_names - ddi_names
    common = ddi_names & ext_names

    summary['missing'] = len(missing)
    summary['extra'] = len(extra)
    summary['common'] = len(common)

    if missing:
        issues.append(f"\n=== MISSING from extraction ({len(missing)}) ===")
        for name in sorted(missing)[:20]:
            issues.append(f"  {name}: {ddi_vars[name].get('label', '')[:50]}")
        if len(missing) > 20:
            issues.append(f"  ... and {len(missing) - 20} more")

    if extra:
        issues.append(f"\n=== EXTRA in extraction ({len(extra)}) ===")
        for name in sorted(extra)[:20]:
            issues.append(f"  {name}: {ext_vars[name].get('label', '')[:50]}")
        if len(extra) > 20:
            issues.append(f"  ... and {len(extra) - 20} more")

    # Compare common variables
    issues.append(f"\n=== Comparing {len(common)} common variables ===")

    for name in sorted(common):
        ddi_var = ddi_vars[name]
        ext_var = ext_vars[name]
        var_issues = []

        # Compare labels
        ddi_label = normalize_label(ddi_var.get('label', ''))
        ext_label = normalize_label(ext_var.get('label', ''))

        if ddi_label == ext_label:
            summary['label_matches'] += 1
        else:
            summary['label_mismatches'] += 1
            var_issues.append(f"  Label mismatch:")
            var_issues.append(f"    DDI: {repr(ddi_var.get('label', ''))}")
            var_issues.append(f"    Ext: {repr(ext_var.get('label', ''))}")

        # Compare categories
        ddi_cats = ddi_var.get('categories', [])
        ext_cats = ext_var.get('categories', [])

        cat_issues = compare_categories(ddi_cats, ext_cats, name)
        if cat_issues:
            var_issues.extend(cat_issues)
            summary['category_issues'] += 1
        else:
            summary['category_perfect'] += 1

        if var_issues:
            issues.append(f"\n{name}:")
            issues.extend(var_issues)

    return summary, issues


def main():
    parser = argparse.ArgumentParser(description='Validate extraction against DDI XML')
    parser.add_argument('ddi_xml', help='Path to DDI XML file (canonical source)')
    parser.add_argument('extracted_yaml', help='Path to extracted YAML file')
    parser.add_argument('--output', '-o', help='Output report file (default: stdout)')
    parser.add_argument('--quiet', '-q', action='store_true', help='Only show summary')

    args = parser.parse_args()

    print(f"Loading DDI: {args.ddi_xml}")
    ddi_vars = parse_ddi(args.ddi_xml)
    print(f"  Found {len(ddi_vars)} variables in DDI")

    print(f"Loading extraction: {args.extracted_yaml}")
    ext_vars = load_extraction(args.extracted_yaml)
    print(f"  Found {len(ext_vars)} variables in extraction")

    summary, issues = validate(ddi_vars, ext_vars)

    # Build report
    report = []
    report.append("=" * 70)
    report.append("DDI VALIDATION REPORT")
    report.append("=" * 70)
    report.append("")
    report.append(f"DDI source:     {args.ddi_xml}")
    report.append(f"Extraction:     {args.extracted_yaml}")
    report.append("")
    report.append("=== Summary ===")
    report.append(f"DDI variables:      {summary['ddi_count']}")
    report.append(f"Extracted vars:     {summary['ext_count']}")
    report.append(f"Common variables:   {summary['common']}")
    report.append(f"Missing (in DDI):   {summary['missing']}")
    report.append(f"Extra (not in DDI): {summary['extra']}")
    report.append("")
    report.append(f"Label matches:      {summary['label_matches']}")
    report.append(f"Label mismatches:   {summary['label_mismatches']}")
    report.append(f"Category perfect:   {summary['category_perfect']}")
    report.append(f"Category issues:    {summary['category_issues']}")
    report.append("")

    # Calculate match rates
    if summary['common'] > 0:
        label_rate = summary['label_matches'] / summary['common'] * 100
        cat_rate = summary['category_perfect'] / summary['common'] * 100
        report.append(f"Label match rate:    {label_rate:.1f}%")
        report.append(f"Category match rate: {cat_rate:.1f}%")

        # Overall accuracy
        if summary['missing'] == 0 and summary['extra'] == 0:
            overall = (summary['label_matches'] + summary['category_perfect']) / (2 * summary['common']) * 100
            report.append(f"Overall accuracy:    {overall:.1f}%")

    if not args.quiet:
        report.extend(issues)

    report_text = '\n'.join(report)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(report_text)
        print(f"\nReport written to: {args.output}")
    else:
        print(report_text)

    # Exit with error if significant issues
    if summary['missing'] > 0 or summary['extra'] > 0:
        return 1
    if summary['common'] > 0:
        cat_rate = summary['category_perfect'] / summary['common'] * 100
        if cat_rate < 90:
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
