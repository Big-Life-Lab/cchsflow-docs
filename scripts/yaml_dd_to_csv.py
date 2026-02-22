#!/usr/bin/env python3
"""Convert CCHS Master Data Dictionary YAML extractions to CSV for DuckDB ingestion.

Reads the YAML files produced by scripts/extract_data_dictionary.R and outputs
two CSVs per year: variable metadata and value codes (answer categories).

Usage:
    python3 scripts/yaml_dd_to_csv.py

Output:
    data/sources/master-pdf-dd/cchs_2022_master_dd.csv
    data/sources/master-pdf-dd/cchs_2022_master_dd_categories.csv
    data/sources/master-pdf-dd/cchs_2023_master_dd.csv
    data/sources/master-pdf-dd/cchs_2023_master_dd_categories.csv
"""

import csv
import sys
from pathlib import Path

import yaml

YAML_FILES = {
    2022: "cchs-extracted/data-dictionary/2022/cchs_2022s_dd_m_en_1_v1.yaml",
    2023: "cchs-extracted/data-dictionary/2023/cchs_2023s_dd_m_en_1_v1.yaml",
}

OUTPUT_DIR = Path("data/sources/master-pdf-dd")

VAR_COLUMNS = [
    "variable_name", "length", "position", "label",
    "question_text", "universe", "note", "n_categories",
]

CAT_COLUMNS = [
    "variable_name", "code", "label",
    "frequency", "frequency_weighted", "percent",
]


def load_yaml(path: str) -> dict:
    with open(path, "r") as f:
        return yaml.safe_load(f)


def convert_year(year: int, yaml_path: str, output_dir: Path):
    data = load_yaml(yaml_path)
    variables = data["variables"]

    var_csv = output_dir / f"cchs_{year}_master_dd.csv"
    cat_csv = output_dir / f"cchs_{year}_master_dd_categories.csv"

    var_count = 0
    cat_count = 0

    with open(var_csv, "w", newline="") as vf, open(cat_csv, "w", newline="") as cf:
        var_writer = csv.DictWriter(vf, fieldnames=VAR_COLUMNS, quoting=csv.QUOTE_ALL)
        cat_writer = csv.DictWriter(cf, fieldnames=CAT_COLUMNS, quoting=csv.QUOTE_ALL)
        var_writer.writeheader()
        cat_writer.writeheader()

        for var_name, var_data in variables.items():
            categories = var_data.get("categories", []) or []

            var_writer.writerow({
                "variable_name": var_name,
                "length": var_data.get("length", ""),
                "position": var_data.get("position", ""),
                "label": var_data.get("label", ""),
                "question_text": var_data.get("question_text", ""),
                "universe": var_data.get("universe", ""),
                "note": var_data.get("note", ""),
                "n_categories": len(categories),
            })
            var_count += 1

            for cat in categories:
                code = cat.get("value", "")
                # Codes may be numeric (int/float) — convert to string, strip .0
                if isinstance(code, float) and code == int(code):
                    code = str(int(code))
                else:
                    code = str(code)

                freq = cat.get("frequency", "")
                if isinstance(freq, float) and freq == int(freq):
                    freq = int(freq)

                cat_writer.writerow({
                    "variable_name": var_name,
                    "code": code,
                    "label": cat.get("label", ""),
                    "frequency": freq,
                    "frequency_weighted": cat.get("weighted_frequency", ""),
                    "percent": cat.get("percent", ""),
                })
                cat_count += 1

    print(f"{year}: {var_count} variables, {cat_count} value codes")
    print(f"  → {var_csv}")
    print(f"  → {cat_csv}")

    return var_count, cat_count


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    total_vars = 0
    total_cats = 0

    for year, yaml_path in sorted(YAML_FILES.items()):
        if not Path(yaml_path).exists():
            print(f"WARNING: {yaml_path} not found, skipping {year}", file=sys.stderr)
            continue
        v, c = convert_year(year, yaml_path, OUTPUT_DIR)
        total_vars += v
        total_cats += c

    print(f"\nTotal: {total_vars} variables, {total_cats} value codes")


if __name__ == "__main__":
    main()
