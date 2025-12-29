#!/usr/bin/env python3
"""
Extract CCHS derived variables PDFs to YAML format using pdfplumber.

Converts derived variable specification PDFs to structured YAML with:
- YAML metadata header
- Module listings
- Variable specifications with properly parsed tables

Usage:
    python extract_derived_variables_pdfplumber.py <pdf_path> <output_path> [--year YEAR]

Requires: pip install pdfplumber pyyaml
"""

import argparse
import hashlib
import re
from datetime import date
from pathlib import Path

import pdfplumber
import yaml


def compute_sha256(file_path: str) -> str:
    """Compute SHA256 checksum of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


def parse_module_header(text: str) -> dict | None:
    """Parse module header like 'Alcohol use (1 DV)' or 'Activities of Daily Living (2 DVs)'."""
    # Match: Module Name (N DV/DVs)
    match = re.match(r'^([A-Za-z][A-Za-z\s\-]+)\s*\((\d+)\s+DVs?\)', text.strip())
    if match:
        return {
            'name': match.group(1).strip(),
            'count': int(match.group(2))
        }
    return None


def parse_variable_header(text: str) -> dict | None:
    """Parse variable header like '1) Type of drinker (12 months)'."""
    match = re.match(r'^(\d+)\)\s+(.+)$', text.strip())
    if match:
        return {
            'number': int(match.group(1)),
            'label': match.group(2).strip()
        }
    return None


def parse_variable_name_line(text: str) -> str | None:
    """Parse 'Variable name: ALCDVTTM'."""
    match = re.match(r'^Variable name:\s*(\w+)', text.strip())
    if match:
        return match.group(1)
    return None


def parse_based_on_line(text: str) -> list | None:
    """Parse 'Based on: ALC_005, ALC_010, ALC_015'."""
    match = re.match(r'^Based on:\s*(.+)$', text.strip())
    if match:
        vars_text = match.group(1)
        # Split by comma and clean
        variables = [v.strip() for v in vars_text.split(',')]
        return [v for v in variables if v]
    return None


def parse_description_line(text: str) -> str | None:
    """Parse 'Description: ...'."""
    match = re.match(r'^Description:\s*(.+)$', text.strip())
    if match:
        return match.group(1)
    return None


def parse_note_line(text: str) -> str | None:
    """Parse 'Note: ...'."""
    match = re.match(r'^Note:\s*(.+)$', text.strip())
    if match:
        return match.group(1)
    return None


def clean_table_cell(cell) -> str:
    """Clean a table cell value."""
    if cell is None:
        return ""
    return str(cell).strip().replace('\n', ' ')


def extract_specification_table(table_data: list) -> list:
    """Extract specification rows from a pdfplumber table.

    Expected columns: Value, Condition(s), Description, Notes
    """
    if not table_data or len(table_data) < 2:
        return []

    # Find header row
    headers = [clean_table_cell(c).lower() for c in table_data[0]]

    # Check if this looks like a specification table
    if not any('value' in h for h in headers):
        return []

    # Map columns
    value_idx = next((i for i, h in enumerate(headers) if 'value' in h), 0)
    condition_idx = next((i for i, h in enumerate(headers) if 'condition' in h), 1)
    desc_idx = next((i for i, h in enumerate(headers) if 'description' in h), 2)
    notes_idx = next((i for i, h in enumerate(headers) if 'note' in h), 3)

    specs = []
    for row in table_data[1:]:
        if len(row) < 2:
            continue

        value = clean_table_cell(row[value_idx]) if value_idx < len(row) else ""
        condition = clean_table_cell(row[condition_idx]) if condition_idx < len(row) else ""
        description = clean_table_cell(row[desc_idx]) if desc_idx < len(row) else ""
        notes = clean_table_cell(row[notes_idx]) if notes_idx < len(row) else ""

        # Skip empty rows or header repeats
        if not value or value.lower() == 'value':
            continue

        specs.append({
            'value': value,
            'condition': condition,
            'description': description,
            'notes': notes
        })

    return specs


def parse_text_specifications(lines: list, start_idx: int) -> list:
    """Parse specification table from text lines (when pdfplumber doesn't detect tables).

    The format is:
    Value Condition(s) Description Notes
    6 DOALC = 2 Module not selected NA
    9 ALC_005 in (DK,RF,NS) or At least one required question was not answered NS
    ...
    """
    specs = []
    i = start_idx

    # Skip the header line
    if i < len(lines) and 'Value' in lines[i] and 'Condition' in lines[i]:
        i += 1

    current_spec = None

    while i < len(lines):
        line = lines[i].strip()

        # End conditions - new variable, module, or page footer
        if not line:
            i += 1
            continue

        # Page footer pattern
        if re.match(r'^(March|April|May|June|July|August|September|October|November|December|January|February)\s+\d{4}\s+\d+$', line):
            i += 1
            continue

        # Page header
        if 'Canadian Community Health Survey' in line:
            i += 1
            continue

        # New variable or module starts - stop parsing this table
        if parse_variable_header(line) or parse_module_header(line):
            break

        # Temporary reformat section - stop
        if line.startswith('Temporary Reformat'):
            break

        # Check if this looks like a new spec row (starts with value)
        # Values are typically: numbers (6, 9, 96, 99, 996, 999), formulas, or variable expressions
        spec_match = re.match(r'^(\d+|[A-Z][A-Z0-9_]*(?:\s*[+\-*/]\s*[A-Z0-9_]+)*)\s+(.+)$', line)

        if spec_match:
            # Save previous spec
            if current_spec:
                specs.append(current_spec)

            value = spec_match.group(1).strip()
            rest = spec_match.group(2).strip()

            # Parse the rest - try to identify condition, description, notes
            # Notes are typically at end: NA, NS, or (min: X; max: Y)
            notes = ''
            notes_match = re.search(r'\s+(NA|NS)\s*$', rest)
            if notes_match:
                notes = notes_match.group(1)
                rest = rest[:notes_match.start()].strip()

            notes_match = re.search(r'\s+(\(min:\s*\d+;\s*max:\s*\d+\))\s*$', rest)
            if notes_match:
                notes = notes_match.group(1)
                rest = rest[:notes_match.start()].strip()

            # Split condition from description using double-space heuristic
            parts = re.split(r'\s{2,}', rest, maxsplit=1)
            if len(parts) >= 2:
                condition = parts[0]
                description = parts[1]
            else:
                condition = rest
                description = ''

            current_spec = {
                'value': value,
                'condition': condition,
                'description': description,
                'notes': notes
            }
        elif current_spec:
            # Continuation line - append to condition
            current_spec['condition'] += ' ' + line

        i += 1

    # Save last spec
    if current_spec:
        specs.append(current_spec)

    return specs


def extract_derived_variables(pdf_path: str, metadata: dict) -> dict:
    """Extract derived variables PDF to structured data."""

    modules = []
    variables = {}

    current_module = None
    current_module_code = None
    current_variable = None

    # Module code mapping (from TOC analysis)
    module_codes = {}

    with pdfplumber.open(pdf_path) as pdf:
        # First pass: extract module codes from TOC
        for page in pdf.pages[:10]:  # TOC is in first pages
            text = page.extract_text() or ""
            for line in text.split('\n'):
                # Match: "ADL Activities of Daily Living (2 DVs)"
                match = re.match(r'^([A-Z0-9]+)\s+([A-Za-z][A-Za-z\s\-]+)\s*\((\d+)\s+DVs?\)', line.strip())
                if match:
                    code = match.group(1)
                    name = match.group(2).strip()
                    module_codes[name.lower()] = code

        # Second pass: extract variables
        for page_num, page in enumerate(pdf.pages):
            text = page.extract_text() or ""
            lines = text.split('\n')

            # Extract tables from this page
            page_tables = page.extract_tables() or []

            for i, line in enumerate(lines):
                stripped = line.strip()

                # Skip page headers/footers
                if 'Canadian Community Health Survey' in stripped:
                    continue
                if re.match(r'^(March|April|May|June|July|August|September|October|November|December|January|February)\s+\d{4}\s+\d+$', stripped):
                    continue
                if re.match(r'^\d+$', stripped):
                    continue

                # Check for module header
                module_match = parse_module_header(stripped)
                if module_match:
                    current_module = module_match['name']
                    # Find module code
                    current_module_code = module_codes.get(current_module.lower(), '')
                    if not current_module_code:
                        # Try to find from previous line or nearby
                        for j in range(max(0, i-3), i):
                            prev_line = lines[j].strip()
                            code_match = re.match(r'^([A-Z0-9]+)\s*$', prev_line)
                            if code_match:
                                current_module_code = code_match.group(1)
                                break

                    modules.append({
                        'code': current_module_code,
                        'name': current_module,
                        'count': module_match['count']
                    })
                    continue

                # Check for variable header
                var_header = parse_variable_header(stripped)
                if var_header:
                    # Save previous variable if exists
                    if current_variable and current_variable.get('name'):
                        variables[current_variable['name']] = current_variable

                    current_variable = {
                        'name': None,
                        'label': var_header['label'],
                        'module': current_module,
                        'module_code': current_module_code,
                        'based_on': [],
                        'description': '',
                        'note': '',
                        'specifications': []
                    }
                    continue

                # Check for variable name
                var_name = parse_variable_name_line(stripped)
                if var_name and current_variable:
                    current_variable['name'] = var_name
                    continue

                # Check for based on
                based_on = parse_based_on_line(stripped)
                if based_on and current_variable:
                    current_variable['based_on'] = based_on
                    continue

                # Check for description
                desc = parse_description_line(stripped)
                if desc and current_variable:
                    current_variable['description'] = desc
                    continue

                # Check for note
                note = parse_note_line(stripped)
                if note and current_variable:
                    current_variable['note'] = note
                    continue

                # Check for "Specifications" header - parse the specification table
                if stripped == 'Specifications' and current_variable:
                    # First try pdfplumber tables
                    found_specs = False
                    if page_tables:
                        for table in page_tables:
                            specs = extract_specification_table(table)
                            if specs:
                                current_variable['specifications'].extend(specs)
                                found_specs = True
                                break

                    # If no pdfplumber table, parse from text
                    if not found_specs:
                        # Find the header line and parse from there
                        for j in range(i + 1, min(i + 5, len(lines))):
                            if 'Value' in lines[j] and 'Condition' in lines[j]:
                                specs = parse_text_specifications(lines, j)
                                if specs:
                                    current_variable['specifications'].extend(specs)
                                break

        # Save last variable
        if current_variable and current_variable.get('name'):
            variables[current_variable['name']] = current_variable

    return {
        'modules': modules,
        'variables': variables
    }


def main():
    parser = argparse.ArgumentParser(description='Extract CCHS derived variables PDF to YAML format')
    parser.add_argument('pdf_path', help='Path to input PDF file')
    parser.add_argument('output_path', help='Path to output YAML file')
    parser.add_argument('--year', default='', help='Survey year')
    parser.add_argument('--temporal-type', default='', help='Temporal type (single/dual)')
    parser.add_argument('--uid', default='', help='CCHS UID for extracted file')
    parser.add_argument('--derived-from', default='', help='Source PDF CCHS UID')
    parser.add_argument('--doc-type', default='master', help='Document type (master/pumf/share)')
    parser.add_argument('--language', default='EN', help='Language (EN/FR)')

    args = parser.parse_args()

    pdf_path = Path(args.pdf_path)
    if not pdf_path.exists():
        print(f"Error: PDF file not found: {pdf_path}")
        return 1

    # Compute checksum
    checksum = compute_sha256(str(pdf_path))
    file_size = pdf_path.stat().st_size

    print(f"Extracting: {pdf_path}")
    print(f"  Year: {args.year}")
    print(f"  Language: {args.language}")

    # Extract data
    extracted = extract_derived_variables(str(pdf_path), {})

    # Build output structure
    output = {
        'cchs_uid': args.uid,
        'derived_from': args.derived_from,
        'survey': 'CCHS',
        'year': args.year,
        'temporal_type': args.temporal_type,
        'category': 'derived-variables',
        'doc_type': args.doc_type,
        'language': args.language,
        'canonical_filename': Path(args.output_path).name,
        'source': {
            'filename': pdf_path.name,
            'path': str(pdf_path),
            'checksum_sha256': checksum,
            'file_size_bytes': file_size
        },
        'extraction': {
            'date': str(date.today()),
            'script': 'extract_derived_variables_pdfplumber.py',
            'script_version': '1.0.0',
            'output_format': 'yaml',
            'variables_count': len(extracted['variables']),
            'modules_count': len(extracted['modules'])
        },
        'modules': extracted['modules'],
        'variables': extracted['variables']
    }

    # Write output
    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        yaml.dump(output, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print(f"  Output: {output_path}")
    print(f"  Modules: {len(extracted['modules'])}")
    print(f"  Variables: {len(extracted['variables'])}")
    print(f"  Checksum: {checksum[:16]}...")
    print("  Done!")

    return 0


if __name__ == '__main__':
    exit(main())
