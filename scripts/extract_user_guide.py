#!/usr/bin/env python3
"""
Extract CCHS user guide PDFs to QMD format.

Converts user guide PDFs to Quarto markdown with:
- YAML front matter with metadata
- Structured sections from table of contents
- Tables extracted as YAML data blocks using pdfplumber
- Narrative text preserved as markdown

Usage:
    python extract_user_guide.py <pdf_path> <output_path> [--year YEAR] [--uid UID]

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


def detect_section(line: str) -> dict | None:
    """Detect section headers (numbered sections like '1. INTRODUCTION')."""
    line = line.strip()
    if not line:
        return None

    # Main section: "1. INTRODUCTION" or "1.    INTRODUCTION"
    match = re.match(r'^(\d+)\.\s+([A-Z][A-Za-z\s,\-]+)$', line)
    if match:
        return {
            'level': 1,
            'number': match.group(1),
            'title': match.group(2).strip()
        }

    # Subsection: "5.1 TARGET POPULATION"
    match = re.match(r'^(\d+\.\d+)\s+([A-Za-z][A-Za-z\s,\-]+)$', line)
    if match:
        return {
            'level': 2,
            'number': match.group(1),
            'title': match.group(2).strip()
        }

    # Sub-subsection: "5.4.1 Sampling of households"
    match = re.match(r'^(\d+\.\d+\.\d+)\s+([A-Za-z].+)$', line)
    if match:
        return {
            'level': 3,
            'number': match.group(1),
            'title': match.group(2).strip()
        }

    # Appendix: "APPENDIX A" or with title
    match = re.match(r'^APPENDIX\s+([A-Z])\s*[-–:]?\s*(.*)$', line, re.IGNORECASE)
    if match:
        letter = match.group(1).upper()
        title = match.group(2).strip() if match.group(2) else f"Appendix {letter}"
        return {
            'level': 1,
            'number': f"A{letter}",
            'title': title
        }

    return None


def detect_table_header(line: str) -> dict | None:
    """Detect table headers (e.g., 'Table 5.1 Number of health regions...')."""
    line = line.strip()

    # Table N.N or Table N
    match = re.match(r'^Table\s+(\d+(?:\.\d+)?)\s*(.*)$', line, re.IGNORECASE)
    if match:
        return {
            'number': match.group(1),
            'title': match.group(2).strip(),
            'type': 'table'
        }

    # Diagram headers
    match = re.match(r'^Diagram\s+([A-Z])\s*(.*)$', line, re.IGNORECASE)
    if match:
        return {
            'number': f"D{match.group(1).upper()}",
            'title': match.group(2).strip(),
            'type': 'diagram'
        }

    return None


def is_page_header_footer(line: str) -> bool:
    """Check if line is a page header or footer."""
    line = line.strip()
    # Page numbers
    if re.match(r'^\d{1,3}$', line):
        return True
    # User guide headers
    if re.search(r'CCHS.*User Guide|Microdata File User Guide', line, re.IGNORECASE):
        return True
    # Roman numeral page numbers
    if re.match(r'^[ivxlc]+$', line, re.IGNORECASE):
        return True
    return False


def is_toc_line(line: str) -> bool:
    """Check if line is a table of contents entry."""
    line = line.strip()
    # TOC lines typically have dots leading to page numbers
    if re.search(r'\.{3,}\s*\d+$', line):
        return True
    # Or end with page number after spaces
    if re.search(r'\s{2,}\d+$', line) and len(line) > 30:
        return True
    return False


def clean_text(text: str) -> str:
    """Clean extracted text, removing artifacts."""
    # Remove multiple blank lines
    text = re.sub(r'\n{3,}', '\n\n', text)
    # Remove trailing whitespace
    text = '\n'.join(line.rstrip() for line in text.split('\n'))
    return text


def table_to_markdown(table_data: list) -> str:
    """Convert table data to markdown format."""
    if not table_data or len(table_data) < 2:
        return ""

    # Clean cells
    def clean_cell(cell):
        if cell is None:
            return ""
        return str(cell).strip().replace('\n', ' ')

    headers = [clean_cell(c) for c in table_data[0]]
    rows = [[clean_cell(c) for c in row] for row in table_data[1:]]

    # Filter empty columns
    non_empty_cols = []
    for i in range(len(headers)):
        if headers[i] or any(row[i] if i < len(row) else "" for row in rows):
            non_empty_cols.append(i)

    if not non_empty_cols:
        return ""

    headers = [headers[i] if i < len(headers) else "" for i in non_empty_cols]
    rows = [[row[i] if i < len(row) else "" for i in non_empty_cols] for row in rows]

    # Calculate column widths
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            if i < len(widths):
                widths[i] = max(widths[i], len(cell))

    # Build markdown
    lines = []

    # Header row
    header_cells = [f"{h:<{widths[i]}}" for i, h in enumerate(headers)]
    lines.append("| " + " | ".join(header_cells) + " |")

    # Separator
    sep_cells = ["-" * max(w, 3) for w in widths]
    lines.append("| " + " | ".join(sep_cells) + " |")

    # Data rows
    for row in rows:
        row_cells = [f"{(row[i] if i < len(row) else ''):<{widths[i]}}" for i in range(len(widths))]
        lines.append("| " + " | ".join(row_cells) + " |")

    return '\n'.join(lines)


def table_to_yaml_block(table_data: list, table_id: str, table_title: str) -> str:
    """Convert table data to YAML block for embedding in QMD."""
    if not table_data or len(table_data) < 2:
        return ""

    # Clean cells
    def clean_cell(cell):
        if cell is None:
            return ""
        return str(cell).strip().replace('\n', ' ')

    headers = [clean_cell(c) for c in table_data[0]]
    rows = [[clean_cell(c) for c in row] for row in table_data[1:]]

    # Build structured data
    data = []
    for row in rows:
        row_dict = {}
        for i, header in enumerate(headers):
            if header and i < len(row):
                row_dict[header] = row[i]
        if row_dict:
            data.append(row_dict)

    yaml_obj = {
        'id': table_id,
        'title': table_title,
        'columns': [h for h in headers if h],
        'data': data
    }

    yaml_str = yaml.dump(yaml_obj, default_flow_style=False, allow_unicode=True, sort_keys=False)

    # Wrap in code block
    label = f"tbl-{table_id.replace('.', '-')}"
    return f"```{{yaml}}\n#| label: {label}\n{yaml_str}```\n"


def extract_user_guide(pdf_path: str, metadata: dict) -> str:
    """Extract user guide PDF to QMD format."""

    sections = []
    tables = []
    content_blocks = []

    current_section = None
    current_text = []
    in_toc = False
    past_toc = False

    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages):
            # Extract text with layout
            text = page.extract_text() or ""
            lines = text.split('\n')

            # Extract tables from this page
            page_tables = page.extract_tables() or []

            for line in lines:
                stripped = line.strip()

                # Skip page headers/footers
                if is_page_header_footer(line):
                    continue

                # Detect TOC start
                if re.match(r'^Table of Contents$', stripped, re.IGNORECASE):
                    in_toc = True
                    continue

                # Skip TOC entries
                if in_toc:
                    if is_toc_line(line):
                        continue
                    # TOC ends when we hit a real section
                    section = detect_section(stripped)
                    if section and not is_toc_line(line):
                        in_toc = False
                        past_toc = True
                    else:
                        continue

                # After TOC, process content
                if not past_toc:
                    # Check if this looks like the first real section
                    section = detect_section(stripped)
                    if section:
                        past_toc = True
                    else:
                        continue

                # Detect section headers
                section = detect_section(stripped)
                if section:
                    # Save previous content
                    if current_text:
                        content_blocks.append({
                            'type': 'text',
                            'section': current_section,
                            'content': clean_text('\n'.join(current_text))
                        })
                        current_text = []

                    current_section = section
                    sections.append(section)
                    continue

                # Detect table headers
                table_header = detect_table_header(stripped)
                if table_header:
                    # Save current text before table
                    if current_text:
                        content_blocks.append({
                            'type': 'text',
                            'section': current_section,
                            'content': clean_text('\n'.join(current_text))
                        })
                        current_text = []

                    # Find matching table data from pdfplumber
                    if page_tables:
                        table_data = page_tables[0]  # Take first table on page
                        page_tables = page_tables[1:]  # Remove it

                        tables.append({
                            'number': table_header['number'],
                            'title': table_header['title'],
                            'data': table_data
                        })

                        content_blocks.append({
                            'type': 'table',
                            'section': current_section,
                            'table_num': table_header['number'],
                            'table_title': table_header['title'],
                            'data': table_data
                        })
                    continue

                # Regular content
                if stripped:
                    current_text.append(line)

        # Save final content
        if current_text:
            content_blocks.append({
                'type': 'text',
                'section': current_section,
                'content': clean_text('\n'.join(current_text))
            })

    # Generate QMD output
    output_lines = []

    # YAML front matter
    front_matter = {
        'title': metadata.get('title', 'CCHS User Guide'),
        'subtitle': metadata.get('subtitle', ''),
        'date': metadata.get('date', ''),
        'cchs_uid': metadata.get('cchs_uid', ''),
        'derived_from': metadata.get('derived_from', ''),
        'survey': 'CCHS',
        'year': metadata.get('year', ''),
        'temporal_type': metadata.get('temporal_type', ''),
        'category': 'user-guide',
        'doc_type': 'master',
        'language': metadata.get('language', 'EN'),
        'source': {
            'filename': metadata.get('source_filename', ''),
            'path': metadata.get('source_path', ''),
            'checksum_sha256': metadata.get('checksum', '')
        },
        'extraction': {
            'date': str(date.today()),
            'script': 'extract_user_guide.py',
            'script_version': '1.0.0',
            'sections_count': len(sections),
            'tables_count': len(tables)
        }
    }

    output_lines.append('---')
    output_lines.append(yaml.dump(front_matter, default_flow_style=False, allow_unicode=True, sort_keys=False).strip())
    output_lines.append('---')
    output_lines.append('')

    # Content
    current_section_num = None

    for block in content_blocks:
        # Add section header if changed
        section = block.get('section')
        if section:
            section_id = section['number']
            if current_section_num != section_id:
                current_section_num = section_id

                level = section['level']
                prefix = '#' * (level + 1)
                title = section['title']

                # Convert to sentence case (first letter upper, rest lower except proper nouns)
                title = title[0].upper() + title[1:].lower() if title else title

                output_lines.append('')
                output_lines.append(f"{prefix} {section_id} {title}")
                output_lines.append('')

        if block['type'] == 'text':
            content = block['content']
            if content.strip():
                output_lines.append(content)
                output_lines.append('')

        elif block['type'] == 'table':
            # Output table as YAML data block for programmatic access
            yaml_block = table_to_yaml_block(block['data'], block['table_num'], block['table_title'])
            if yaml_block:
                output_lines.append(yaml_block)
                output_lines.append('')

    return '\n'.join(output_lines)


def main():
    parser = argparse.ArgumentParser(description='Extract CCHS user guide PDF to QMD format')
    parser.add_argument('pdf_path', help='Path to input PDF file')
    parser.add_argument('output_path', help='Path to output QMD file')
    parser.add_argument('--year', default='', help='Survey year')
    parser.add_argument('--temporal-type', default='', help='Temporal type (single/dual)')
    parser.add_argument('--uid', default='', help='CCHS UID for extracted file')
    parser.add_argument('--derived-from', default='', help='Source PDF CCHS UID')
    parser.add_argument('--language', default='EN', help='Language (EN/FR)')

    args = parser.parse_args()

    pdf_path = Path(args.pdf_path)
    if not pdf_path.exists():
        print(f"Error: PDF file not found: {pdf_path}")
        return 1

    # Compute checksum
    checksum = compute_sha256(str(pdf_path))

    # Extract title info from PDF
    with pdfplumber.open(str(pdf_path)) as pdf:
        first_page_text = pdf.pages[0].extract_text() or ""
        lines = [l.strip() for l in first_page_text.split('\n') if l.strip()]

    title = "Canadian Community Health Survey User Guide"
    subtitle = ""
    doc_date = ""

    for line in lines[:15]:  # Check first 15 lines
        if "Canadian Community Health Survey" in line:
            title = line
        if re.match(r'User guide|User Guide', line, re.IGNORECASE):
            subtitle = line
        if "Microdata" in line:
            subtitle = f"{subtitle} - {line}" if subtitle else line
        if re.match(r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}$', line):
            doc_date = line

    metadata = {
        'title': title,
        'subtitle': subtitle.strip(' -'),
        'date': doc_date,
        'year': args.year,
        'temporal_type': args.temporal_type,
        'language': args.language,
        'cchs_uid': args.uid,
        'derived_from': args.derived_from,
        'source_filename': pdf_path.name,
        'source_path': str(pdf_path),
        'checksum': checksum
    }

    print(f"Extracting: {pdf_path}")
    print(f"  Year: {args.year}")
    print(f"  Language: {args.language}")

    qmd_content = extract_user_guide(str(pdf_path), metadata)

    output_path = Path(args.output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(qmd_content)

    print(f"  Output: {output_path}")
    print(f"  Checksum: {checksum[:16]}...")
    print("  Done!")

    return 0


if __name__ == '__main__':
    exit(main())
