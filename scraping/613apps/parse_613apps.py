"""
Parse raw 613apps.ca scraped CSVs into normalised variables and value codes.

Reads raw CSVs from data/sources/613apps/raw/ and outputs:
  - data/sources/613apps/parsed/613apps_variables.csv
  - data/sources/613apps/parsed/613apps_value_codes.csv

Usage:
    python parse_613apps.py
    python parse_613apps.py --raw-dir /path/to/raw --parsed-dir /path/to/parsed
    python parse_613apps.py --cycle 2023
"""

import argparse
import csv
import glob
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RAW_DIR = os.path.join(
    SCRIPT_DIR, "..", "..", "data", "sources", "613apps", "raw"
)
DEFAULT_PARSED_DIR = os.path.join(
    SCRIPT_DIR, "..", "..", "data", "sources", "613apps", "parsed"
)


def extract_variable_name(raw_name: str) -> str:
    """
    Strip cycle year suffix from a 613apps variable name.

    613apps concatenates all cycle years onto the variable name:
      EAHDVDAS2023           -> EAHDVDAS
      FSCDVAF22019-2020202120222023  -> FSCDVAF2
      GEODVSAT2015-20162017-2018...  -> GEODVSAT
      LSM_0120222023         -> LSM_01
      ALDDSF4.12009-2010     -> ALDDSF4.1
      HWT_2A4.12009-2010     -> HWT_2A4.1

    Strategy: match the base name (letters, digits, underscores, dots
    following CCHS naming conventions) then the year suffix (starts with
    a 4-digit year like 20xx or 19xx).
    """
    m = re.match(
        r"^([A-Za-z_][A-Za-z0-9_.]*?)((?:20\d{2}|19\d{2})[-0-9]*)$",
        raw_name,
    )
    if m:
        return m.group(1).upper()

    # Fallback: return as-is (uppercased)
    return raw_name.upper()


def strip_cycle_suffix(value: str) -> str:
    """
    Strip cycle year suffix from Format or File column values.

    Examples:
      D00375F2023              -> D00375F
      hs2023                   -> hs
      NA2023                   -> NA
      hs2019-2020202120222023  -> hs
      HS2015-2016              -> HS
    """
    if not value:
        return value

    m = re.match(r"^(.+?)((?:20\d{2}|19\d{2})[-0-9]*)$", value)
    if m:
        return m.group(1)
    return value


def parse_response_lines(response: str) -> list[dict]:
    """
    Parse newline-delimited response string into code/label pairs.

    Input (from DOM scraping, newlines preserved):
        "0 = No depression\n1 = Minimal depression\n..."

    Returns: [{"code": "0", "label": "No depression"}, ...]
    """
    if not response or response == "No response options available":
        return []

    codes = []
    for line in response.split("\n"):
        line = line.strip()
        if not line:
            continue
        m = re.match(r"^(\d+)\s*=\s*(.+)$", line)
        if m:
            codes.append({"code": m.group(1), "label": m.group(2).strip()})

    return codes


def extract_cycles_from_suffix(raw_name: str) -> list[str]:
    """
    Extract the list of cycle years from a variable name suffix.

    GEODVSAT2015-20162017-20182019-2020202120222023
    -> ['2015-2016', '2017-2018', '2019-2020', '2021', '2022', '2023']
    """
    m = re.match(r"^[A-Za-z_][A-Za-z0-9_.]*?((?:20\d{2}|19\d{2})[-0-9]*)$", raw_name)
    if not m:
        return []

    suffix = m.group(1)
    cycles = []

    # Parse the suffix: look for YYYY-YYYY (dual-year) or YYYY (single-year)
    i = 0
    while i < len(suffix):
        # Try dual-year: YYYY-YYYY
        dm = re.match(r"(\d{4})-(\d{4})", suffix[i:])
        if dm:
            cycles.append(f"{dm.group(1)}-{dm.group(2)}")
            i += len(dm.group(0))
            continue

        # Try single-year: YYYY
        sm = re.match(r"(\d{4})", suffix[i:])
        if sm:
            cycles.append(sm.group(1))
            i += 4
            continue

        # Skip unexpected characters
        i += 1

    return cycles


def parse_raw_csv(filepath: str) -> tuple[list[dict], list[dict]]:
    """
    Parse a single raw scraped CSV into variables and value codes.

    Handles grouped rows where the Variable and File cells contain multiple
    entries separated by newlines (from the 613apps "Group variables" toggle).
    Each line represents a different variable name for the same concept
    across different cycles.

    Returns: (variables_rows, value_codes_rows)
    """
    # Extract survey and cycle from filename:
    #   613apps_master_2023.csv -> survey=master, cycle=2023
    #   613apps_pumf_2019-2020.csv -> survey=pumf, cycle=2019-2020
    #   613apps_2023.csv -> survey=master, cycle=2023 (legacy format)
    basename = os.path.basename(filepath)
    m = re.search(r"613apps_(master|pumf)_(.+)\.csv$", basename)
    if m:
        file_survey = m.group(1)
        file_cycle = m.group(2)
    else:
        cycle_match = re.search(r"613apps_(.+)\.csv$", basename)
        file_survey = "master"
        file_cycle = cycle_match.group(1) if cycle_match else "unknown"

    variables = []
    value_codes = []

    with open(filepath, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            label = row["Label"].strip()
            response = row["Response"]

            # Split grouped variables: Variable and File may have multiple
            # lines when the app groups related variables across cycles
            var_lines = row["Variable"].strip().split("\n")
            file_lines = row["File"].strip().split("\n")
            format_lines = row["Format"].strip().split("\n")

            # Pad file/format lines if shorter than var lines
            while len(file_lines) < len(var_lines):
                file_lines.append(file_lines[-1] if file_lines else "")
            while len(format_lines) < len(var_lines):
                format_lines.append(format_lines[-1] if format_lines else "")

            # Parse response codes once (shared across all grouped vars)
            codes = parse_response_lines(response)

            for var_raw, file_raw, fmt_raw in zip(
                var_lines, file_lines, format_lines
            ):
                var_raw = var_raw.strip()
                file_raw = file_raw.strip()
                fmt_raw = fmt_raw.strip()

                if not var_raw:
                    continue

                var_name = extract_variable_name(var_raw)
                format_code = strip_cycle_suffix(fmt_raw)
                file_code = strip_cycle_suffix(file_raw)
                cycles = extract_cycles_from_suffix(var_raw)

                if not cycles:
                    cycles = [file_cycle]

                variables.append({
                    "variable_name": var_name,
                    "variable_raw": var_raw,
                    "label": label,
                    "format_code": format_code if format_code != "NA" else "",
                    "file_code": file_code if file_code != "NA" else "",
                    "cycles": ",".join(cycles),
                    "file_cycle": file_cycle,
                    "survey": file_survey,
                })

                for code in codes:
                    value_codes.append({
                        "variable_name": var_name,
                        "code": code["code"],
                        "code_label": code["label"],
                        "file_cycle": file_cycle,
                        "survey": file_survey,
                    })

    return variables, value_codes


def parse_all(
    raw_dir: str, parsed_dir: str, cycle_filter: str | None = None
):
    """Parse all raw CSVs and write normalised output."""
    raw_dir = os.path.abspath(raw_dir)
    parsed_dir = os.path.abspath(parsed_dir)

    # Match both old (613apps_2023.csv) and new (613apps_master_2023.csv) formats
    # Exclude *_all.csv files (unfiltered scrapes used for cross-reference only)
    pattern = os.path.join(raw_dir, "613apps_*.csv")
    files = sorted(
        f for f in glob.glob(pattern) if not f.endswith("_all.csv")
    )

    if not files:
        print(f"No raw CSV files found in {raw_dir}")
        sys.exit(1)

    if cycle_filter:
        files = [f for f in files if cycle_filter in os.path.basename(f)]
        if not files:
            print(f"No files matching cycle '{cycle_filter}'")
            sys.exit(1)

    print(f"Parsing {len(files)} raw CSV file(s)...")

    all_variables = []
    all_value_codes = []

    for filepath in files:
        print(f"  {os.path.basename(filepath)}: ", end="", flush=True)
        variables, value_codes = parse_raw_csv(filepath)
        print(f"{len(variables)} variables, {len(value_codes)} value codes")
        all_variables.extend(variables)
        all_value_codes.extend(value_codes)

    # Deduplicate variables: same variable may appear in multiple cycle files
    # Keep the first occurrence per (variable_name, file_cycle, survey) tuple
    seen = set()
    deduped_vars = []
    for v in all_variables:
        key = (v["variable_name"], v["file_cycle"], v["survey"])
        if key not in seen:
            seen.add(key)
            deduped_vars.append(v)

    # Deduplicate value codes
    seen_codes = set()
    deduped_codes = []
    for c in all_value_codes:
        key = (c["variable_name"], c["code"], c["file_cycle"], c["survey"])
        if key not in seen_codes:
            seen_codes.add(key)
            deduped_codes.append(c)

    # Write output
    os.makedirs(parsed_dir, exist_ok=True)

    vars_path = os.path.join(parsed_dir, "613apps_variables.csv")
    with open(vars_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "variable_name", "variable_raw", "label",
                "format_code", "file_code", "cycles", "file_cycle",
                "survey",
            ],
            quoting=csv.QUOTE_ALL,
        )
        writer.writeheader()
        writer.writerows(deduped_vars)

    codes_path = os.path.join(parsed_dir, "613apps_value_codes.csv")
    with open(codes_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "variable_name", "code", "code_label", "file_cycle",
                "survey",
            ],
            quoting=csv.QUOTE_ALL,
        )
        writer.writeheader()
        writer.writerows(deduped_codes)

    # Summary
    print(f"\n{'='*60}")
    print("Parsing complete!")
    print(f"{'='*60}")
    print(f"  Variables: {len(deduped_vars)} (from {len(all_variables)} raw rows)")
    print(f"  Value codes: {len(deduped_codes)} (from {len(all_value_codes)} raw)")
    print(f"  Output: {vars_path}")
    print(f"  Output: {codes_path}")

    # Validation
    validate(deduped_vars, deduped_codes)


def validate(variables: list[dict], value_codes: list[dict]):
    """Run basic validation checks on parsed output."""
    print(f"\n{'='*60}")
    print("Validation")
    print(f"{'='*60}")

    issues = 0

    # Check for variable names that still contain year suffixes
    year_pattern = re.compile(r"(20\d{2}|19\d{2})$")
    bad_names = [v for v in variables if year_pattern.search(v["variable_name"])]
    if bad_names:
        print(f"  WARNING: {len(bad_names)} variable names still end with year digits:")
        for v in bad_names[:5]:
            print(f"    {v['variable_name']} (from {v['variable_raw']})")
        issues += 1
    else:
        print("  OK: No variable names end with year digits")

    # Check value codes are numeric
    non_numeric = [c for c in value_codes if not c["code"].isdigit()]
    if non_numeric:
        print(f"  WARNING: {len(non_numeric)} non-numeric codes found:")
        for c in non_numeric[:5]:
            print(f"    {c['variable_name']}: code='{c['code']}'")
        issues += 1
    else:
        print("  OK: All codes are numeric")

    # Check for empty labels
    empty_labels = [c for c in value_codes if not c["code_label"]]
    if empty_labels:
        print(f"  WARNING: {len(empty_labels)} value codes with empty labels")
        issues += 1
    else:
        print("  OK: No empty value code labels")

    # Per-cycle counts
    cycle_counts = {}
    for v in variables:
        c = v["file_cycle"]
        cycle_counts[c] = cycle_counts.get(c, 0) + 1
    print(f"\n  Variables per cycle:")
    for c in sorted(cycle_counts):
        print(f"    {c}: {cycle_counts[c]}")

    if issues == 0:
        print("\n  All validation checks passed!")
    else:
        print(f"\n  {issues} issue(s) found — review warnings above")


def main():
    parser = argparse.ArgumentParser(
        description="Parse raw 613apps.ca scraped CSVs"
    )
    parser.add_argument(
        "--raw-dir",
        default=DEFAULT_RAW_DIR,
        help="Directory containing raw 613apps_*.csv files",
    )
    parser.add_argument(
        "--parsed-dir",
        default=DEFAULT_PARSED_DIR,
        help="Output directory for parsed CSVs",
    )
    parser.add_argument(
        "--cycle",
        help="Parse only a specific cycle (e.g., '2023')",
    )

    args = parser.parse_args()
    parse_all(args.raw_dir, args.parsed_dir, args.cycle)


if __name__ == "__main__":
    main()
