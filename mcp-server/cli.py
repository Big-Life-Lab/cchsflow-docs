#!/usr/bin/env python3
"""
CCHS Metadata CLI

Query the CCHS metadata database from the command line without MCP.

Usage:
    python mcp-server/cli.py search smoking
    python mcp-server/cli.py detail SMKDSTY
    python mcp-server/cli.py history SMKDSTY
    python mcp-server/cli.py dataset cchs-2015d-p-can
    python mcp-server/cli.py common cchs-2013d-p-can cchs-2015d-p-can
    python mcp-server/cli.py compare SMKDSTY 2015-2016
    python mcp-server/cli.py codes SMKDSTY
    python mcp-server/cli.py conflicts --variable SMKDSTY
    python mcp-server/cli.py cchsflow GEN_010 2015-2016
    python mcp-server/cli.py summary

Add --json for machine-readable JSON output.
"""

import argparse
import json
import math
import os
import sys
from pathlib import Path

import duckdb

DB_PATH = os.environ.get(
    "CCHS_DB_PATH",
    str(Path(__file__).parent.parent / "database" / "cchs_metadata.duckdb"),
)


def get_connection():
    if not os.path.exists(DB_PATH):
        print(f"Error: database not found at {DB_PATH}", file=sys.stderr)
        print(
            "Run ./scripts/setup.sh or download from GitHub Releases.",
            file=sys.stderr,
        )
        sys.exit(1)
    return duckdb.connect(DB_PATH, read_only=True)


def _clean(val):
    """Convert NaN/None to empty string for display."""
    if val is None:
        return ""
    if isinstance(val, float) and math.isnan(val):
        return ""
    return val


def _json_default(obj):
    """JSON serializer for non-standard types."""
    if isinstance(obj, float) and math.isnan(obj):
        return None
    return str(obj)


def _print_table(rows, columns, max_col_width=60):
    """Print rows as a simple aligned table."""
    if not rows:
        print("(no results)")
        return

    # Calculate column widths
    widths = [len(c) for c in columns]
    str_rows = []
    for row in rows:
        str_row = []
        for i, val in enumerate(row):
            s = str(_clean(val))
            if len(s) > max_col_width:
                s = s[: max_col_width - 3] + "..."
            str_row.append(s)
            widths[i] = max(widths[i], len(s))
        str_rows.append(str_row)

    # Header
    header = "  ".join(c.ljust(widths[i]) for i, c in enumerate(columns))
    print(header)
    print("  ".join("-" * widths[i] for i in range(len(columns))))

    for str_row in str_rows:
        print("  ".join(str_row[i].ljust(widths[i]) for i in range(len(columns))))


def _print_kv(pairs):
    """Print key-value pairs vertically."""
    max_key = max(len(k) for k, _ in pairs) if pairs else 0
    for key, val in pairs:
        print(f"  {key.ljust(max_key)}  {_clean(val)}")


# ── Subcommands ─────────────────────────────────────────────

def cmd_search(args):
    con = get_connection()
    rows = con.execute(
        """
        SELECT variable_name,
               COALESCE(label_short, label_long, label_statcan) AS label,
               type, n_datasets, status
        FROM variables
        WHERE variable_name ILIKE ?
           OR label_short ILIKE ?
           OR label_long ILIKE ?
           OR label_statcan ILIKE ?
        ORDER BY n_datasets DESC NULLS LAST
        LIMIT ?
        """,
        [f"%{args.query}%"] * 4 + [args.limit],
    ).fetchall()
    columns = ["variable_name", "label", "type", "n_datasets", "status"]
    con.close()

    if args.json:
        out = [dict(zip(columns, r)) for r in rows]
        print(json.dumps(out, indent=2, default=_json_default))
    else:
        print(f"Found {len(rows)} variable(s) matching '{args.query}':\n")
        _print_table(rows, columns)


def cmd_detail(args):
    con = get_connection()

    var_info = con.execute(
        """
        SELECT variable_name,
               label_short, label_long, label_statcan,
               type, value_format,
               question_text, universe,
               section, subject, subsection, cchsflow_name,
               n_datasets, n_cycles, n_primary_sources, status
        FROM variables
        WHERE variable_name = ?
        """,
        [args.variable_name],
    ).fetchone()

    if not var_info:
        con.close()
        print(f"Variable '{args.variable_name}' not found.", file=sys.stderr)
        sys.exit(1)

    var_cols = [
        "variable_name",
        "label_short", "label_long", "label_statcan",
        "type", "value_format",
        "question_text", "universe",
        "section", "subject", "subsection", "cchsflow_name",
        "n_datasets", "n_cycles", "n_primary_sources", "status",
    ]
    var_dict = dict(zip(var_cols, var_info))

    history = con.execute(
        """
        SELECT dataset_id, label, year_start, year_end,
               temporal_type, release, sources
        FROM v_variable_history
        WHERE variable_name = ?
        ORDER BY year_start
        """,
        [args.variable_name],
    ).fetchall()
    hist_cols = [
        "dataset_id", "label", "year_start", "year_end",
        "temporal_type", "release", "sources",
    ]

    codes = con.execute(
        """
        SELECT vc.dataset_id, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted, vc.source_id,
               d.year_start
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ?
        ORDER BY d.year_start DESC, vc.code
        """,
        [args.variable_name],
    ).fetchall()
    code_cols = [
        "dataset_id", "code", "label",
        "frequency", "frequency_weighted", "source_id", "year_start",
    ]

    groups = con.execute(
        """
        SELECT DISTINCT vg.group_code, vg.group_label
        FROM variable_group_members vgm
        JOIN variable_groups vg ON vgm.group_id = vg.group_id
        WHERE vgm.variable_name = ?
        """,
        [args.variable_name],
    ).fetchall()

    con.close()

    if args.json:
        result = var_dict.copy()
        result["datasets"] = [dict(zip(hist_cols, r)) for r in history]
        if codes:
            # Latest cycle, prefer DDI
            code_dicts = [dict(zip(code_cols, r)) for r in codes]
            latest_year = max(c["year_start"] for c in code_dicts)
            latest = [c for c in code_dicts if c["year_start"] == latest_year]
            ddi = [c for c in latest if c["source_id"] == "ddi_xml"]
            show = ddi if ddi else latest
            result["value_codes"] = [
                {k: c[k] for k in ("code", "label", "frequency", "frequency_weighted")}
                for c in show
            ]
        if groups:
            result["module_groups"] = [
                {"group_code": g[0], "group_label": g[1]} for g in groups
            ]
        print(json.dumps(result, indent=2, default=_json_default))
    else:
        print(f"Variable: {var_dict['variable_name']}\n")
        _print_kv([
            ("Label (short)", var_dict.get("label_short")),
            ("Label (long)", var_dict.get("label_long")),
            ("Label (StatCan)", var_dict.get("label_statcan")),
            ("Type", var_dict.get("type")),
            ("Question text", var_dict.get("question_text")),
            ("Universe", var_dict.get("universe")),
            ("Section", var_dict.get("section")),
            ("Subject", var_dict.get("subject")),
            ("cchsflow name", var_dict.get("cchsflow_name")),
            ("Datasets", var_dict.get("n_datasets")),
            ("Status", var_dict.get("status")),
        ])

        if history:
            print(f"\nDatasets ({len(history)}):\n")
            _print_table(history, hist_cols)

        if codes:
            code_dicts = [dict(zip(code_cols, r)) for r in codes]
            latest_year = max(c["year_start"] for c in code_dicts)
            latest = [c for c in code_dicts if c["year_start"] == latest_year]
            ddi = [c for c in latest if c["source_id"] == "ddi_xml"]
            show = ddi if ddi else latest
            print(f"\nValue codes (from {show[0]['dataset_id']}):\n")
            _print_table(
                [(c["code"], c["label"], c["frequency"], c["frequency_weighted"]) for c in show],
                ["code", "label", "frequency", "weighted"],
            )

        if groups:
            print(f"\nModule groups ({len(groups)}):\n")
            _print_table(groups, ["group_code", "group_label"])


def cmd_history(args):
    con = get_connection()
    rows = con.execute(
        """
        SELECT dataset_id, label, year_start, year_end,
               temporal_type, release, sources
        FROM v_variable_history
        WHERE variable_name = ?
        ORDER BY year_start
        """,
        [args.variable_name],
    ).fetchall()
    columns = [
        "dataset_id", "label", "year_start", "year_end",
        "temporal_type", "release", "sources",
    ]
    con.close()

    if not rows:
        print(f"Variable '{args.variable_name}' not found.", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(
            [dict(zip(columns, r)) for r in rows],
            indent=2, default=_json_default,
        ))
    else:
        print(f"{args.variable_name} appears in {len(rows)} dataset(s):\n")
        _print_table(rows, columns)


def cmd_dataset(args):
    con = get_connection()

    # Resolve aliases
    resolved_id = args.dataset_id
    alias = con.execute(
        "SELECT dataset_id FROM dataset_aliases WHERE alias = ? LIMIT 1",
        [args.dataset_id],
    ).fetchone()
    if alias:
        resolved_id = alias[0]

    rows = con.execute(
        """
        SELECT variable_name, label, type, subject, section, position, sources
        FROM v_dataset_variables
        WHERE dataset_id = ?
        ORDER BY position NULLS LAST, variable_name
        LIMIT ?
        """,
        [resolved_id, args.limit],
    ).fetchall()
    columns = ["variable_name", "label", "type", "subject", "section", "position", "sources"]
    con.close()

    if not rows:
        print(f"Dataset '{args.dataset_id}' not found or empty.", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps({
            "dataset_id": resolved_id,
            "resolved_from": args.dataset_id if args.dataset_id != resolved_id else None,
            "n_variables": len(rows),
            "variables": [dict(zip(columns, r)) for r in rows],
        }, indent=2, default=_json_default))
    else:
        if args.dataset_id != resolved_id:
            print(f"Resolved '{args.dataset_id}' → '{resolved_id}'")
        print(f"Dataset {resolved_id}: {len(rows)} variable(s)\n")
        _print_table(rows, columns)


def cmd_common(args):
    con = get_connection()
    rows = con.execute(
        """
        SELECT DISTINCT vd1.variable_name,
               COALESCE(v.label_short, v.label_long, v.label_statcan) AS label,
               v.type
        FROM variable_datasets vd1
        JOIN variable_datasets vd2
            ON vd1.variable_name = vd2.variable_name
        JOIN variables v ON vd1.variable_name = v.variable_name
        WHERE vd1.dataset_id = ? AND vd2.dataset_id = ?
        ORDER BY vd1.variable_name
        """,
        [args.dataset_id_1, args.dataset_id_2],
    ).fetchall()
    columns = ["variable_name", "label", "type"]
    con.close()

    if args.json:
        print(json.dumps({
            "dataset_1": args.dataset_id_1,
            "dataset_2": args.dataset_id_2,
            "common_count": len(rows),
            "variables": [dict(zip(columns, r)) for r in rows],
        }, indent=2, default=_json_default))
    else:
        print(
            f"{len(rows)} variable(s) shared between "
            f"{args.dataset_id_1} and {args.dataset_id_2}:\n"
        )
        _print_table(rows, columns)


def cmd_compare(args):
    con = get_connection()
    year_start = int(args.cycle.split("-")[0])

    rows = con.execute(
        """
        SELECT vd.dataset_id, d.release,
               vd.label, vd.type, vd.question_text, vd.intrvl, vd.source_id
        FROM variable_datasets vd
        JOIN datasets d ON vd.dataset_id = d.dataset_id
        WHERE vd.variable_name = ? AND d.year_start = ?
        ORDER BY d.release, vd.source_id
        """,
        [args.variable_name, year_start],
    ).fetchall()
    meta_cols = ["dataset_id", "release", "label", "type", "question_text", "intrvl", "source_id"]

    codes = con.execute(
        """
        SELECT vc.dataset_id, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted, vc.source_id
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ? AND d.year_start = ?
        ORDER BY vc.dataset_id, vc.code
        """,
        [args.variable_name, year_start],
    ).fetchall()
    con.close()

    if not rows:
        print(
            f"No data for '{args.variable_name}' in cycle '{args.cycle}'.",
            file=sys.stderr,
        )
        sys.exit(1)

    row_dicts = [dict(zip(meta_cols, r)) for r in rows]
    code_dicts = [
        dict(zip(["dataset_id", "code", "label", "frequency", "frequency_weighted", "source_id"], c))
        for c in codes
    ]

    # Group by dataset_id
    dataset_ids = list(dict.fromkeys(r["dataset_id"] for r in row_dicts))

    if args.json:
        comparisons = []
        for ds_id in dataset_ids:
            ds_rows = [r for r in row_dicts if r["dataset_id"] == ds_id]
            ddi = [r for r in ds_rows if r["source_id"] == "ddi_xml"]
            best = ddi[0] if ddi else ds_rows[0]
            entry = {
                "dataset_id": ds_id,
                "release": best["release"],
                "label": best["label"],
                "type": best["type"],
                "question_text": best["question_text"],
                "sources": list(set(r["source_id"] for r in ds_rows)),
            }
            ds_codes = [c for c in code_dicts if c["dataset_id"] == ds_id]
            if ds_codes:
                ddi_c = [c for c in ds_codes if c["source_id"] == "ddi_xml"]
                show_c = ddi_c if ddi_c else ds_codes
                entry["value_codes"] = [
                    {k: c[k] for k in ("code", "label", "frequency", "frequency_weighted")}
                    for c in show_c
                ]
            comparisons.append(entry)
        print(json.dumps({
            "variable_name": args.variable_name,
            "cycle": args.cycle,
            "comparisons": comparisons,
        }, indent=2, default=_json_default))
    else:
        for ds_id in dataset_ids:
            ds_rows = [r for r in row_dicts if r["dataset_id"] == ds_id]
            ddi = [r for r in ds_rows if r["source_id"] == "ddi_xml"]
            best = ddi[0] if ddi else ds_rows[0]
            sources = ", ".join(set(r["source_id"] for r in ds_rows))

            print(f"--- {ds_id} ({best['release']}) ---")
            _print_kv([
                ("Label", best["label"]),
                ("Type", best["type"]),
                ("Question", best["question_text"]),
                ("Sources", sources),
            ])

            ds_codes = [c for c in code_dicts if c["dataset_id"] == ds_id]
            if ds_codes:
                ddi_c = [c for c in ds_codes if c["source_id"] == "ddi_xml"]
                show_c = ddi_c if ddi_c else ds_codes
                print()
                _print_table(
                    [(c["code"], c["label"], c["frequency"], c["frequency_weighted"]) for c in show_c],
                    ["code", "label", "frequency", "weighted"],
                )
            print()


def cmd_codes(args):
    con = get_connection()

    codes = con.execute(
        """
        SELECT vc.dataset_id, d.year_start, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted,
               vc.is_range, vc.range_low, vc.range_high, vc.source_id
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ?
        ORDER BY d.year_start DESC, vc.source_id, vc.code
        """,
        [args.variable_name],
    ).fetchall()

    var_format = con.execute(
        "SELECT value_format FROM variables WHERE variable_name = ?",
        [args.variable_name],
    ).fetchone()
    con.close()

    cols = [
        "dataset_id", "year_start", "code", "label",
        "frequency", "frequency_weighted",
        "is_range", "range_low", "range_high", "source_id",
    ]

    if not codes:
        print(f"No value codes found for '{args.variable_name}'.", file=sys.stderr)
        sys.exit(1)

    code_dicts = [dict(zip(cols, r)) for r in codes]
    latest_year = max(c["year_start"] for c in code_dicts)
    latest = [c for c in code_dicts if c["year_start"] == latest_year]
    ddi = [c for c in latest if c["source_id"] == "ddi_xml"]
    show = ddi if ddi else latest

    has_range = any(c["is_range"] for c in show)

    if args.json:
        result = {"variable_name": args.variable_name}
        if var_format and var_format[0]:
            result["ices_format_name"] = var_format[0]
        result["latest_cycle_year"] = int(latest_year)
        result["latest_dataset"] = show[0]["dataset_id"]
        out_keys = ["code", "label", "frequency", "frequency_weighted"]
        if has_range:
            out_keys.extend(["is_range", "range_low", "range_high"])
        result["codes"] = [{k: c[k] for k in out_keys} for c in show]
        result["n_datasets_with_codes"] = len(set(c["dataset_id"] for c in code_dicts))
        print(json.dumps(result, indent=2, default=_json_default))
    else:
        fmt_info = f" (format: {var_format[0]})" if var_format and var_format[0] else ""
        n_ds = len(set(c["dataset_id"] for c in code_dicts))
        print(
            f"Value codes for {args.variable_name}{fmt_info}\n"
            f"Showing: {show[0]['dataset_id']} ({int(latest_year)}), "
            f"codes across {n_ds} dataset(s)\n"
        )
        if has_range:
            _print_table(
                [(c["code"], c["label"], c["frequency"], c["frequency_weighted"],
                  c["is_range"], c["range_low"], c["range_high"]) for c in show],
                ["code", "label", "frequency", "weighted", "is_range", "range_low", "range_high"],
            )
        else:
            _print_table(
                [(c["code"], c["label"], c["frequency"], c["frequency_weighted"]) for c in show],
                ["code", "label", "frequency", "weighted"],
            )


def cmd_conflicts(args):
    con = get_connection()

    conditions = []
    params = []
    if args.variable:
        conditions.append("variable_name = ?")
        params.append(args.variable)
    if args.dataset:
        conditions.append("dataset_id = ?")
        params.append(args.dataset)
    where = " WHERE " + " AND ".join(conditions) if conditions else ""

    label_conflicts = con.execute(
        f"SELECT * FROM v_source_conflicts{where} ORDER BY variable_name, dataset_id",
        params,
    ).fetchall()
    lc_cols = ["variable_name", "dataset_id", "source_a", "label_a", "source_b", "label_b", "conflict_type"]

    code_conflicts = con.execute(
        f"SELECT * FROM v_value_code_conflicts{where} ORDER BY variable_name, dataset_id, code",
        params,
    ).fetchall()
    cc_cols = ["variable_name", "dataset_id", "code", "source_a", "label_a", "source_b", "label_b"]

    con.close()

    if args.json:
        result = {
            "n_label_conflicts": len(label_conflicts),
            "n_value_code_conflicts": len(code_conflicts),
        }
        if conditions:
            result["label_conflicts"] = [dict(zip(lc_cols, r)) for r in label_conflicts]
            result["value_code_conflicts"] = [dict(zip(cc_cols, r)) for r in code_conflicts]
        else:
            # Summary only when unfiltered
            from collections import Counter
            pair_counts = Counter((r[2], r[4]) for r in label_conflicts)
            result["label_conflict_sources"] = [
                {"source_a": k[0], "source_b": k[1], "count": v}
                for k, v in pair_counts.items()
            ]
        print(json.dumps(result, indent=2, default=_json_default))
    else:
        if conditions:
            if label_conflicts:
                print(f"Label conflicts ({len(label_conflicts)}):\n")
                _print_table(label_conflicts, lc_cols)
            else:
                print("No label conflicts.")

            if code_conflicts:
                print(f"\nValue code conflicts ({len(code_conflicts)}):\n")
                _print_table(code_conflicts, cc_cols)
            else:
                print("No value code conflicts.")
        else:
            print(f"Label conflicts: {len(label_conflicts)}")
            print(f"Value code conflicts: {len(code_conflicts)}")
            if label_conflicts:
                from collections import Counter
                pair_counts = Counter((r[2], r[4]) for r in label_conflicts)
                print("\nBy source pair:")
                for (a, b), count in sorted(pair_counts.items(), key=lambda x: -x[1]):
                    print(f"  {a} vs {b}: {count}")


def cmd_cchsflow(args):
    con = get_connection()
    year_start = int(args.target_cycle.split("-")[0])

    avail = con.execute(
        """
        SELECT DISTINCT vd.dataset_id, d.release
        FROM variable_datasets vd
        JOIN datasets d ON vd.dataset_id = d.dataset_id
        WHERE vd.variable_name = ? AND d.year_start = ?
        """,
        [args.variable_name, year_start],
    ).fetchall()

    var_info = con.execute(
        """
        SELECT variable_name,
               COALESCE(label_short, label_long, label_statcan) AS label,
               type, question_text, cchsflow_name
        FROM variables WHERE variable_name = ?
        """,
        [args.variable_name],
    ).fetchone()

    value_codes = con.execute(
        """
        SELECT vc.code, vc.label, vc.frequency, vc.frequency_weighted
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ? AND d.year_start = ?
          AND vc.source_id = 'ddi_xml'
        ORDER BY vc.code
        """,
        [args.variable_name, year_start],
    ).fetchall()

    if not value_codes:
        value_codes = con.execute(
            """
            SELECT vc.code, vc.label, vc.frequency, vc.frequency_weighted
            FROM value_codes vc
            JOIN datasets d ON vc.dataset_id = d.dataset_id
            WHERE vc.variable_name = ? AND d.year_start = ?
            ORDER BY vc.code
            """,
            [args.variable_name, year_start],
        ).fetchall()

    con.close()

    if not var_info:
        print(f"Variable '{args.variable_name}' not found.", file=sys.stderr)
        sys.exit(1)

    var_cols = ["variable_name", "label", "type", "question_text", "cchsflow_name"]
    var_dict = dict(zip(var_cols, var_info))

    if args.json:
        result = {
            "variable_name": args.variable_name,
            "target_cycle": args.target_cycle,
            "available_in_cycle": bool(avail),
            **var_dict,
        }
        if avail:
            result["datasets_in_cycle"] = [
                {"dataset_id": a[0], "release": a[1]} for a in avail
            ]
        if value_codes:
            result["value_codes"] = [
                dict(zip(["code", "label", "frequency", "frequency_weighted"], c))
                for c in value_codes
            ]
        if avail:
            result["suggested_row"] = {
                "variable": args.variable_name,
                "databaseStart": avail[0][0],
                "variableStart": args.variable_name,
                "variableStartLabel": var_dict.get("label", ""),
                "rec_from": "copy",
                "rec_to": var_dict.get("cchsflow_name") or args.variable_name,
                "note": f"Auto-suggested for cycle {args.target_cycle}. Review before use.",
            }
        print(json.dumps(result, indent=2, default=_json_default))
    else:
        in_cycle = "Yes" if avail else "No"
        print(f"cchsflow row for {args.variable_name} in {args.target_cycle}\n")
        _print_kv([
            ("Available", in_cycle),
            ("Label", var_dict.get("label")),
            ("Type", var_dict.get("type")),
            ("cchsflow name", var_dict.get("cchsflow_name")),
        ])
        if avail:
            print(f"\nDatasets in cycle:")
            for a in avail:
                print(f"  {a[0]} ({a[1]})")
            print(f"\nSuggested row:")
            _print_kv([
                ("variable", args.variable_name),
                ("databaseStart", avail[0][0]),
                ("variableStart", args.variable_name),
                ("variableStartLabel", var_dict.get("label", "")),
                ("rec_from", "copy"),
                ("rec_to", var_dict.get("cchsflow_name") or args.variable_name),
            ])
            print(f"\n  Note: Auto-suggested. Review before use.")

        if value_codes:
            print(f"\nValue codes ({len(value_codes)}):\n")
            _print_table(
                value_codes,
                ["code", "label", "frequency", "weighted"],
            )


def cmd_summary(args):
    con = get_connection()

    counts = {}
    for table in [
        "variables", "datasets", "variable_datasets",
        "value_codes", "variable_summary_stats",
        "variable_groups", "variable_group_members",
    ]:
        counts[table] = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]

    active = con.execute(
        "SELECT COUNT(*) FROM variables WHERE status = 'active'"
    ).fetchone()[0]

    sources = con.execute(
        "SELECT source_id, source_name, authority, n_files FROM sources ORDER BY authority"
    ).fetchall()

    releases = con.execute(
        "SELECT release, COUNT(*) as count FROM datasets GROUP BY release ORDER BY count DESC"
    ).fetchall()

    meta = con.execute("SELECT key, value FROM catalog_metadata").fetchall()

    con.close()

    if args.json:
        result = {
            "total_variables": counts["variables"],
            "active_variables": active,
            "total_datasets": counts["datasets"],
            "total_variable_dataset_links": counts["variable_datasets"],
            "total_value_codes": counts["value_codes"],
            "total_summary_stats": counts["variable_summary_stats"],
            "total_variable_groups": counts["variable_groups"],
            "total_group_memberships": counts["variable_group_members"],
            "sources": [
                dict(zip(["source_id", "source_name", "authority", "n_files"], s))
                for s in sources
            ],
            "dataset_releases": [
                {"release": r[0], "count": r[1]} for r in releases
            ],
        }
        if meta:
            result["catalog_metadata"] = {m[0]: m[1] for m in meta}
        print(json.dumps(result, indent=2, default=_json_default))
    else:
        print("CCHS Metadata Database\n")
        _print_kv([
            ("Variables", f"{counts['variables']:,} ({active:,} active)"),
            ("Datasets", f"{counts['datasets']:,}"),
            ("Variable-dataset links", f"{counts['variable_datasets']:,}"),
            ("Value codes", f"{counts['value_codes']:,}"),
            ("Summary stats", f"{counts['variable_summary_stats']:,}"),
            ("Variable groups", f"{counts['variable_groups']:,}"),
            ("Group memberships", f"{counts['variable_group_members']:,}"),
        ])

        print("\nSources:")
        _print_table(
            sources,
            ["source_id", "source_name", "authority", "n_files"],
        )

        print("\nDatasets by release type:")
        for r in releases:
            print(f"  {r[0]}: {r[1]}")

        if meta:
            print("\nBuild metadata:")
            for m in meta:
                print(f"  {m[0]}: {m[1]}")


# ── Main ────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="cchs",
        description="Query the CCHS metadata database from the command line.",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Output as JSON instead of formatted tables",
    )
    parser.add_argument(
        "--db", metavar="PATH",
        help="Path to DuckDB database (default: database/cchs_metadata.duckdb)",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # search
    p = sub.add_parser("search", help="Search variables by name or label")
    p.add_argument("query", help="Search term")
    p.add_argument("--limit", type=int, default=20, help="Max results (default 20)")

    # detail
    p = sub.add_parser("detail", help="Full metadata for a variable")
    p.add_argument("variable_name", help="Exact variable name")

    # history
    p = sub.add_parser("history", help="Trace variable across cycles")
    p.add_argument("variable_name", help="Exact variable name")

    # dataset
    p = sub.add_parser("dataset", help="List variables in a dataset")
    p.add_argument("dataset_id", help="Dataset ID (e.g., cchs-2015d-p-can)")
    p.add_argument("--limit", type=int, default=100, help="Max results (default 100)")

    # common
    p = sub.add_parser("common", help="Find shared variables between datasets")
    p.add_argument("dataset_id_1", help="First dataset ID")
    p.add_argument("dataset_id_2", help="Second dataset ID")

    # compare
    p = sub.add_parser("compare", help="Compare variable across file types in a cycle")
    p.add_argument("variable_name", help="Exact variable name")
    p.add_argument("cycle", help="Cycle year (e.g., 2015-2016)")

    # codes
    p = sub.add_parser("codes", help="Get response categories for a variable")
    p.add_argument("variable_name", help="Exact variable name")

    # conflicts
    p = sub.add_parser("conflicts", help="Find cross-source label disagreements")
    p.add_argument("--variable", help="Filter by variable name")
    p.add_argument("--dataset", help="Filter by dataset ID")

    # cchsflow
    p = sub.add_parser("cchsflow", help="Generate draft cchsflow harmonisation row")
    p.add_argument("variable_name", help="Variable to harmonise")
    p.add_argument("target_cycle", help="Target cycle (e.g., 2015-2016)")

    # summary
    sub.add_parser("summary", help="Database overview and statistics")

    args = parser.parse_args()

    # Override DB path if provided
    if args.db:
        global DB_PATH
        DB_PATH = args.db

    commands = {
        "search": cmd_search,
        "detail": cmd_detail,
        "history": cmd_history,
        "dataset": cmd_dataset,
        "common": cmd_common,
        "compare": cmd_compare,
        "codes": cmd_codes,
        "conflicts": cmd_conflicts,
        "cchsflow": cmd_cchsflow,
        "summary": cmd_summary,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
