#!/usr/bin/env python3
"""
Batch extract master CCHS user guide PDFs to QMD format.

Reads from the master PDF catalog and extracts English user guides.

Usage:
    python batch_extract_master_user_guides.py [base_dir]

Output: QMD files in cchs-extracted/user-guide/{year}/
"""

import csv
import sys
from datetime import date
from pathlib import Path

# Import the extraction function
from extract_user_guide import extract_user_guide, compute_sha256

import pdfplumber
import yaml


def main():
    # Define paths
    if len(sys.argv) >= 2:
        base_dir = Path(sys.argv[1]).resolve()
    else:
        base_dir = Path.cwd()

    catalog_file = base_dir / "data" / "manifests" / "cchs-master-pdf-catalog.csv"
    output_base = base_dir / "cchs-extracted" / "user-guide"

    print("=== Batch Master User Guide Extraction ===\n")
    print(f"Base directory: {base_dir}")
    print(f"Catalog file: {catalog_file}")
    print(f"Output base: {output_base}\n")

    # Check catalog exists
    if not catalog_file.exists():
        print("Error: Catalog file not found. Run generate_master_pdf_catalog.R first.")
        return 1

    # Read catalog
    with open(catalog_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        catalog = list(reader)

    print(f"Total entries in catalog: {len(catalog)}")

    # Filter to English user guide files
    ug_to_extract = [
        row for row in catalog
        if row['category'] == 'user-guide' and row['language'] == 'EN'
    ]

    print(f"English user-guide files: {len(ug_to_extract)}\n")

    # Track results
    results = []

    for src in ug_to_extract:
        pdf_path = base_dir / src['local_path']

        # Generate canonical filename
        canonical = src['canonical_filename'].replace('.pdf', '').replace('_v1', '')

        print("---")
        print(f"Processing: {src['cchs_uid']}")
        print(f"  Source: {src['local_path']}")

        # Check if PDF exists
        if not pdf_path.exists():
            print("  Status: SKIPPED (file not found)")
            results.append({
                'year': src['year'],
                'cchs_uid': src['cchs_uid'],
                'canonical': canonical,
                'sections': None,
                'tables': None,
                'checksum': None,
                'status': 'not_found'
            })
            continue

        # Create output directory
        output_dir = output_base / src['year']
        output_dir.mkdir(parents=True, exist_ok=True)

        output_file = output_dir / f"{canonical}_v1.qmd"

        try:
            # Compute checksum
            pdf_checksum = compute_sha256(str(pdf_path))
            pdf_size = pdf_path.stat().st_size

            # Generate extracted file UID
            # Source: cchs-2015s-m-ug-en-pdf-01 -> cchs-2015s-m-ug-e-qmd-01
            uid_parts = src['cchs_uid'].split('-')
            extracted_uid = '-'.join([
                uid_parts[0],  # cchs
                uid_parts[1],  # year+temporal
                uid_parts[2],  # doc_type (m for master)
                uid_parts[3],  # category (ug)
                'e',           # language simplified
                'qmd',         # extension
                uid_parts[6]   # sequence
            ])

            # Extract title info from PDF
            with pdfplumber.open(str(pdf_path)) as pdf:
                first_page_text = pdf.pages[0].extract_text() or ""
                lines = [l.strip() for l in first_page_text.split('\n') if l.strip()]

            title = "Canadian Community Health Survey User Guide"
            subtitle = ""
            doc_date = ""

            import re
            for line in lines[:15]:
                if "Canadian Community Health Survey" in line:
                    title = line
                if re.match(r'User guide|User Guide', line, re.IGNORECASE):
                    subtitle = line
                if "Microdata" in line:
                    subtitle = f"{subtitle} - {line}" if subtitle else line
                if re.match(r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}$', line):
                    doc_date = line

            # Build metadata
            metadata = {
                'title': title,
                'subtitle': subtitle.strip(' -'),
                'date': doc_date,
                'year': src['year'],
                'temporal_type': src['temporal_type'],
                'language': src['language'],
                'cchs_uid': extracted_uid,
                'derived_from': src['cchs_uid'],
                'source_filename': src['filename'],
                'source_path': src['local_path'],
                'checksum': pdf_checksum
            }

            # Extract and generate QMD
            qmd_content = extract_user_guide(str(pdf_path), metadata)

            # Count sections and tables from the output
            sections_count = qmd_content.count('\n## ')
            tables_count = qmd_content.count('**Table ')

            # Write QMD
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(qmd_content)

            print(f"  Output: {output_file}")
            print(f"  Sections: {sections_count}")
            print(f"  Tables: {tables_count}")
            print(f"  Checksum: {pdf_checksum[:16]}...")
            print("  Status: SUCCESS")

            results.append({
                'year': src['year'],
                'cchs_uid': src['cchs_uid'],
                'canonical': canonical,
                'sections': sections_count,
                'tables': tables_count,
                'checksum': pdf_checksum,
                'status': 'success'
            })

        except Exception as e:
            print(f"  Status: ERROR - {e}")
            results.append({
                'year': src['year'],
                'cchs_uid': src['cchs_uid'],
                'canonical': canonical,
                'sections': None,
                'tables': None,
                'checksum': None,
                'status': f'error: {e}'
            })

    # Summary
    print("\n=== Summary ===")
    success_count = sum(1 for r in results if r['status'] == 'success')
    failed_count = len(results) - success_count
    total_sections = sum(r['sections'] or 0 for r in results)
    total_tables = sum(r['tables'] or 0 for r in results)

    print(f"Processed: {len(results)} files")
    print(f"Successful: {success_count}")
    print(f"Failed: {failed_count}")
    print(f"Total sections extracted: {total_sections}")
    print(f"Total tables extracted: {total_tables}")

    # Write summary
    summary_file = output_base / "extraction_summary.yaml"
    summary_output = {
        'extraction_date': str(date.today()),
        'extraction_script_version': '1.0.0',
        'source_type': 'master',
        'category': 'user-guide',
        'output_format': 'qmd',
        'total_files': len(results),
        'successful': success_count,
        'failed': failed_count,
        'total_sections': total_sections,
        'total_tables': total_tables,
        'files': [
            {
                'cchs_uid': r['cchs_uid'],
                'year': r['year'],
                'canonical_filename': f"{r['canonical']}_v1.qmd",
                'sections_count': r['sections'],
                'tables_count': r['tables'],
                'source_checksum': r['checksum'],
                'status': r['status']
            }
            for r in results
        ]
    }

    with open(summary_file, 'w', encoding='utf-8') as f:
        yaml.dump(summary_output, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print(f"\nSummary written to: {summary_file}")

    # Write CSV manifest
    manifest_file = output_base / "extraction_manifest.csv"
    with open(manifest_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=['year', 'cchs_uid', 'canonical', 'sections', 'tables', 'checksum', 'status'])
        writer.writeheader()
        writer.writerows(results)

    print(f"Manifest written to: {manifest_file}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
