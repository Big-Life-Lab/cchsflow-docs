"""
CCHS Metadata MCP Server

Exposes the unified CCHS metadata DuckDB via Model Context Protocol tools.
See: development/architecture/PROPOSAL_mcp_metadata_architecture.md

Database schema v2: 13 tables, 6 views. Built from PUMF RData + DDI XML
primary sources with full provenance tracking.
"""

import json
import os
from pathlib import Path

import duckdb
from fastmcp import FastMCP

mcp = FastMCP("cchs-metadata", instructions="""
CCHS Metadata Server: Query the Canadian Community Health Survey variable
metadata database. Contains 14,005 variables across 231+ datasets spanning
2001-2021, with DDI-enriched question text and response categories for
PUMF files (2001-2018).
""")

# Database path: relative to this script, or override with env var
DB_PATH = os.environ.get(
    "CCHS_DB_PATH",
    str(Path(__file__).parent.parent / "database" / "cchs_metadata.duckdb")
)


def get_connection():
    """Get a read-only DuckDB connection."""
    return duckdb.connect(DB_PATH, read_only=True)


def _safe_json(obj):
    """JSON serializer that handles pandas NaN/NaT and numpy types."""
    import math
    if isinstance(obj, float) and math.isnan(obj):
        return None
    try:
        import numpy as np
        if isinstance(obj, (np.integer,)):
            return int(obj)
        if isinstance(obj, (np.floating,)):
            return float(obj) if not np.isnan(obj) else None
        if isinstance(obj, (np.bool_,)):
            return bool(obj)
    except ImportError:
        pass
    return str(obj)


@mcp.tool()
def search_variables(query: str, limit: int = 20) -> str:
    """Search for CCHS variables by name or label.

    Args:
        query: Search term (matched against variable_name and label)
        limit: Maximum results to return (default 20)
    """
    con = get_connection()
    results = con.execute("""
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
    """, [f"%{query}%", f"%{query}%", f"%{query}%", f"%{query}%", limit]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({"message": f"No variables found matching '{query}'", "results": []})

    return results.to_json(orient="records", indent=2)


@mcp.tool()
def get_variable_detail(variable_name: str) -> str:
    """Get full metadata for a specific variable, including DDI question text,
    response categories, and availability across all datasets.

    Args:
        variable_name: Exact variable name (e.g., 'SMKDSTY', 'DHHGAGE')
    """
    con = get_connection()

    # Base variable info
    var_info = con.execute("""
        SELECT variable_name,
               label_short, label_long, label_statcan,
               type, value_format,
               question_text, universe,
               section, subject, subsection, cchsflow_name,
               n_datasets, n_cycles, n_primary_sources, status
        FROM variables
        WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    if var_info.empty:
        con.close()
        return json.dumps({"error": f"Variable '{variable_name}' not found"})

    # History across datasets (using the view for best merged metadata)
    history = con.execute("""
        SELECT variable_name, dataset_id, label, type,
               year_start, year_end, temporal_type, release,
               dataset_label, question_text, sources
        FROM v_variable_history
        WHERE variable_name = ?
        ORDER BY year_start
    """, [variable_name]).fetchdf()

    # Value codes (prefer DDI for labels, RData for frequencies)
    value_codes = con.execute("""
        SELECT vc.dataset_id, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted, vc.source_id,
               d.year_start
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ?
        ORDER BY d.year_start DESC, vc.code
    """, [variable_name]).fetchdf()

    # Summary stats (latest cycle)
    summary_stats = con.execute("""
        SELECT ss.dataset_id, ss.stat_mean, ss.stat_median, ss.stat_mode,
               ss.stat_stdev, ss.stat_min, ss.stat_max,
               ss.n_valid, ss.n_invalid,
               d.year_start
        FROM variable_summary_stats ss
        JOIN datasets d ON ss.dataset_id = d.dataset_id
        WHERE ss.variable_name = ?
        ORDER BY d.year_start DESC
        LIMIT 1
    """, [variable_name]).fetchdf()

    # Module group membership
    groups = con.execute("""
        SELECT vg.group_code, vg.group_label, vg.dataset_id
        FROM variable_group_members vgm
        JOIN variable_groups vg ON vgm.group_id = vg.group_id
        WHERE vgm.variable_name = ?
        ORDER BY vg.dataset_id
    """, [variable_name]).fetchdf()

    con.close()

    result = var_info.iloc[0].to_dict()
    result["datasets"] = history.to_dict(orient="records") if not history.empty else []

    if not value_codes.empty:
        # Show deduplicated codes from latest cycle
        latest = value_codes[value_codes["year_start"] == value_codes["year_start"].max()]
        # Prefer DDI source for labels
        ddi_codes = latest[latest["source_id"] == "ddi_xml"]
        codes_to_show = ddi_codes if not ddi_codes.empty else latest
        result["value_codes"] = codes_to_show[
            ["code", "label", "frequency", "frequency_weighted"]
        ].to_dict(orient="records")

    if not summary_stats.empty:
        result["summary_stats"] = summary_stats.iloc[0].to_dict()

    if not groups.empty:
        # Deduplicate group codes across datasets
        unique_groups = groups.drop_duplicates(subset=["group_code"])[
            ["group_code", "group_label"]
        ].to_dict(orient="records")
        result["module_groups"] = unique_groups

    return json.dumps(result, indent=2, default=_safe_json)


@mcp.tool()
def get_variable_history(variable_name: str) -> str:
    """Trace a variable across all CCHS cycles and datasets.
    Shows which cycles and file types contain this variable.

    Args:
        variable_name: Exact variable name (e.g., 'SMKDSTY')
    """
    con = get_connection()
    results = con.execute("""
        SELECT variable_name, label, dataset_id,
               year_start, year_end, temporal_type, release,
               dataset_label, question_text, type, sources
        FROM v_variable_history
        WHERE variable_name = ?
        ORDER BY year_start
    """, [variable_name]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({"error": f"Variable '{variable_name}' not found"})

    return json.dumps(results.to_dict(orient="records"), indent=2, default=_safe_json)


@mcp.tool()
def get_dataset_variables(dataset_id: str, limit: int = 100) -> str:
    """List all variables in a specific dataset.

    Args:
        dataset_id: Dataset identifier (e.g., 'CCHS201516_ONT_SHARE')
        limit: Maximum results (default 100)
    """
    con = get_connection()

    # Try canonical ID first, then check aliases
    resolved_id = dataset_id
    alias_check = con.execute("""
        SELECT dataset_id FROM dataset_aliases WHERE alias = ?
        LIMIT 1
    """, [dataset_id]).fetchone()
    if alias_check:
        resolved_id = alias_check[0]

    results = con.execute("""
        SELECT variable_name, label, type, subject, section, position, sources
        FROM v_dataset_variables
        WHERE dataset_id = ?
        ORDER BY position NULLS LAST, variable_name
        LIMIT ?
    """, [resolved_id, limit]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({"error": f"Dataset '{dataset_id}' not found or empty"})

    return json.dumps({
        "dataset_id": resolved_id,
        "resolved_from": dataset_id if dataset_id != resolved_id else None,
        "n_variables": len(results),
        "variables": results.to_dict(orient="records")
    }, indent=2, default=_safe_json)


@mcp.tool()
def get_common_variables(dataset_id_1: str, dataset_id_2: str) -> str:
    """Find variables shared between two datasets.

    Args:
        dataset_id_1: First dataset identifier
        dataset_id_2: Second dataset identifier
    """
    con = get_connection()
    results = con.execute("""
        SELECT DISTINCT vd1.variable_name,
               COALESCE(v.label_short, v.label_long, v.label_statcan) AS label,
               v.type
        FROM variable_datasets vd1
        JOIN variable_datasets vd2
            ON vd1.variable_name = vd2.variable_name
        JOIN variables v ON vd1.variable_name = v.variable_name
        WHERE vd1.dataset_id = ? AND vd2.dataset_id = ?
        ORDER BY vd1.variable_name
    """, [dataset_id_1, dataset_id_2]).fetchdf()
    con.close()

    return json.dumps({
        "dataset_1": dataset_id_1,
        "dataset_2": dataset_id_2,
        "common_count": len(results),
        "variables": results.to_dict(orient="records") if not results.empty else []
    }, indent=2, default=_safe_json)


@mcp.tool()
def compare_master_pumf(variable_name: str, cycle: str) -> str:
    """Compare a variable between different file types (Share, PUMF, Linked)
    for a given cycle.

    Args:
        variable_name: Exact variable name
        cycle: Cycle year(s) (e.g., '2015-2016' or '2015')
    """
    con = get_connection()

    # Parse cycle to year_start
    year_start = int(cycle.split("-")[0])

    results = con.execute("""
        SELECT vd.dataset_id, d.release, d.year_start, d.year_end,
               vd.label, vd.type, vd.question_text, vd.universe,
               vd.intrvl, vd.source_id
        FROM variable_datasets vd
        JOIN datasets d ON vd.dataset_id = d.dataset_id
        WHERE vd.variable_name = ? AND d.year_start = ?
        ORDER BY d.release, vd.source_id
    """, [variable_name, year_start]).fetchdf()

    # Get value codes for each dataset in this cycle
    value_codes = con.execute("""
        SELECT vc.dataset_id, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted, vc.source_id
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ? AND d.year_start = ?
        ORDER BY vc.dataset_id, vc.code
    """, [variable_name, year_start]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({
            "error": f"No data for '{variable_name}' in cycle '{cycle}'"
        })

    comparisons = []
    for dataset_id in results["dataset_id"].unique():
        ds_rows = results[results["dataset_id"] == dataset_id]
        # Prefer DDI source row for metadata
        ddi_row = ds_rows[ds_rows["source_id"] == "ddi_xml"]
        row = ddi_row.iloc[0] if not ddi_row.empty else ds_rows.iloc[0]

        entry = {
            "dataset_id": dataset_id,
            "release": row["release"],
            "label": row["label"],
            "type": row["type"],
            "question_text": row["question_text"],
            "intrvl": row["intrvl"],
            "sources": list(ds_rows["source_id"].unique()),
        }

        # Attach value codes for this dataset
        ds_codes = value_codes[value_codes["dataset_id"] == dataset_id]
        if not ds_codes.empty:
            # Prefer DDI codes
            ddi_codes = ds_codes[ds_codes["source_id"] == "ddi_xml"]
            codes = ddi_codes if not ddi_codes.empty else ds_codes
            entry["value_codes"] = codes[
                ["code", "label", "frequency", "frequency_weighted"]
            ].to_dict(orient="records")

        comparisons.append(entry)

    return json.dumps({
        "variable_name": variable_name,
        "cycle": cycle,
        "releases_found": list(results["release"].unique()),
        "comparisons": comparisons
    }, indent=2, default=_safe_json)


@mcp.tool()
def get_value_codes(variable_name: str) -> str:
    """Get response categories/value codes for a variable.
    Checks both the ICES value_formats table and DDI categories.

    Args:
        variable_name: Exact variable name
    """
    con = get_connection()

    # Get value codes from value_codes table, grouped by dataset
    codes = con.execute("""
        SELECT vc.dataset_id, d.year_start, vc.code, vc.label,
               vc.frequency, vc.frequency_weighted,
               vc.is_range, vc.range_low, vc.range_high, vc.source_id
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ?
        ORDER BY d.year_start DESC, vc.source_id, vc.code
    """, [variable_name]).fetchdf()

    # Also get the ICES value_format name if it exists
    var_info = con.execute("""
        SELECT value_format FROM variables WHERE variable_name = ?
    """, [variable_name]).fetchdf()
    con.close()

    result = {"variable_name": variable_name}

    if not var_info.empty and var_info["value_format"].iloc[0]:
        result["ices_format_name"] = var_info["value_format"].iloc[0]

    if not codes.empty:
        # Show codes from latest cycle, preferring DDI source
        latest_year = codes["year_start"].max()
        latest = codes[codes["year_start"] == latest_year]
        ddi_codes = latest[latest["source_id"] == "ddi_xml"]
        codes_to_show = ddi_codes if not ddi_codes.empty else latest

        result["latest_cycle_year"] = int(latest_year)
        result["latest_dataset"] = codes_to_show["dataset_id"].iloc[0]
        code_cols = ["code", "label", "frequency", "frequency_weighted"]
        if codes_to_show["is_range"].any():
            code_cols.extend(["is_range", "range_low", "range_high"])
        result["codes"] = codes_to_show[code_cols].to_dict(orient="records")

        # Summary: how many cycles have codes
        result["n_datasets_with_codes"] = len(codes["dataset_id"].unique())
    else:
        result["message"] = f"No value codes found for '{variable_name}'"

    return json.dumps(result, indent=2, default=_safe_json)


@mcp.tool()
def suggest_cchsflow_row(variable_name: str, target_cycle: str) -> str:
    """Generate a draft cchsflow worksheet row for a variable in a target cycle.
    Uses existing metadata to suggest rec_with_table format.

    Args:
        variable_name: Variable to harmonise
        target_cycle: Cycle to generate the row for (e.g., '2015-2016')
    """
    con = get_connection()

    # Parse cycle to year_start
    year_start = int(target_cycle.split("-")[0])

    # Check if variable exists in target cycle
    avail = con.execute("""
        SELECT DISTINCT vd.dataset_id, d.release
        FROM variable_datasets vd
        JOIN datasets d ON vd.dataset_id = d.dataset_id
        WHERE vd.variable_name = ? AND d.year_start = ?
    """, [variable_name, year_start]).fetchdf()

    # Get variable metadata
    var_info = con.execute("""
        SELECT variable_name,
               COALESCE(label_short, label_long, label_statcan) AS label,
               type, question_text, cchsflow_name
        FROM variables WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    # Get value codes for target cycle
    value_codes = con.execute("""
        SELECT vc.code, vc.label, vc.frequency, vc.frequency_weighted
        FROM value_codes vc
        JOIN datasets d ON vc.dataset_id = d.dataset_id
        WHERE vc.variable_name = ? AND d.year_start = ?
          AND vc.source_id = 'ddi_xml'
        ORDER BY vc.code
    """, [variable_name, year_start]).fetchdf()

    # If no DDI codes, try RData codes
    if value_codes.empty:
        value_codes = con.execute("""
            SELECT vc.code, vc.label, vc.frequency, vc.frequency_weighted
            FROM value_codes vc
            JOIN datasets d ON vc.dataset_id = d.dataset_id
            WHERE vc.variable_name = ? AND d.year_start = ?
            ORDER BY vc.code
        """, [variable_name, year_start]).fetchdf()

    con.close()

    result = {
        "variable_name": variable_name,
        "target_cycle": target_cycle,
        "available_in_cycle": not avail.empty,
    }

    if not var_info.empty:
        result["label"] = var_info["label"].iloc[0]
        result["type"] = var_info["type"].iloc[0]
        result["question_text"] = var_info["question_text"].iloc[0]
        result["cchsflow_name"] = var_info["cchsflow_name"].iloc[0]

    if not avail.empty:
        result["datasets_in_cycle"] = avail.to_dict(orient="records")

    if not value_codes.empty:
        result["value_codes"] = value_codes.to_dict(orient="records")

    # Generate suggested cchsflow row
    if not avail.empty and not var_info.empty:
        result["suggested_row"] = {
            "variable": variable_name,
            "databaseStart": avail["dataset_id"].iloc[0],
            "variableStart": variable_name,
            "variableStartLabel": var_info["label"].iloc[0] if not var_info.empty else "",
            "rec_from": "copy",
            "rec_to": var_info["cchsflow_name"].iloc[0] or variable_name,
            "note": f"Auto-suggested for cycle {target_cycle}. Review before use."
        }

    return json.dumps(result, indent=2, default=_safe_json)


@mcp.tool()
def get_source_conflicts(variable_name: str = None, dataset_id: str = None) -> str:
    """Find label disagreements between sources for a variable or dataset.

    Without filters, returns summary counts only. With variable_name and/or
    dataset_id, returns detailed conflict rows.

    Args:
        variable_name: Optional variable name filter
        dataset_id: Optional dataset ID filter
    """
    con = get_connection()
    result = {}

    # Build WHERE clause
    conditions = []
    params = []
    if variable_name:
        conditions.append("variable_name = ?")
        params.append(variable_name)
    if dataset_id:
        conditions.append("dataset_id = ?")
        params.append(dataset_id)
    where = " WHERE " + " AND ".join(conditions) if conditions else ""

    # Variable-dataset label conflicts
    label_conflicts = con.execute(
        f"SELECT * FROM v_source_conflicts{where} ORDER BY variable_name, dataset_id",
        params
    ).fetchdf()

    # Value code label conflicts
    code_conflicts = con.execute(
        f"SELECT * FROM v_value_code_conflicts{where} ORDER BY variable_name, dataset_id, code",
        params
    ).fetchdf()

    con.close()

    if conditions:
        result["label_conflicts"] = label_conflicts.to_dict(orient="records") if not label_conflicts.empty else []
        result["value_code_conflicts"] = code_conflicts.to_dict(orient="records") if not code_conflicts.empty else []
    else:
        result["total_label_conflicts"] = len(label_conflicts)
        result["total_value_code_conflicts"] = len(code_conflicts)
        if not label_conflicts.empty:
            result["label_conflict_sources"] = label_conflicts.groupby(
                ["source_a", "source_b"]
            ).size().reset_index(name="count").to_dict(orient="records")

    result["n_label_conflicts"] = len(label_conflicts)
    result["n_value_code_conflicts"] = len(code_conflicts)

    return json.dumps(result, indent=2, default=_safe_json)


@mcp.tool()
def get_database_summary() -> str:
    """Get high-level summary statistics for the CCHS metadata database."""
    con = get_connection()

    stats = {}
    stats["total_variables"] = con.execute(
        "SELECT COUNT(*) FROM variables"
    ).fetchone()[0]
    stats["active_variables"] = con.execute(
        "SELECT COUNT(*) FROM variables WHERE status = 'active'"
    ).fetchone()[0]
    stats["total_datasets"] = con.execute(
        "SELECT COUNT(*) FROM datasets"
    ).fetchone()[0]
    stats["total_variable_dataset_links"] = con.execute(
        "SELECT COUNT(*) FROM variable_datasets"
    ).fetchone()[0]
    stats["total_value_codes"] = con.execute(
        "SELECT COUNT(*) FROM value_codes"
    ).fetchone()[0]
    stats["total_summary_stats"] = con.execute(
        "SELECT COUNT(*) FROM variable_summary_stats"
    ).fetchone()[0]
    stats["total_variable_groups"] = con.execute(
        "SELECT COUNT(*) FROM variable_groups"
    ).fetchone()[0]
    stats["total_group_memberships"] = con.execute(
        "SELECT COUNT(*) FROM variable_group_members"
    ).fetchone()[0]

    # Sources
    sources = con.execute("""
        SELECT source_id, source_name, authority, n_files
        FROM sources
        ORDER BY authority, source_id
    """).fetchdf()
    stats["sources"] = sources.to_dict(orient="records")

    # PUMF datasets with year range
    pumf_datasets = con.execute("""
        SELECT dataset_id, year_start, year_end, n_variables
        FROM datasets
        WHERE release = 'pumf' AND geo = 'can'
        ORDER BY year_start
    """).fetchdf()
    stats["pumf_national_datasets"] = pumf_datasets.to_dict(orient="records")

    # Release type distribution
    releases = con.execute("""
        SELECT release, COUNT(*) as count
        FROM datasets
        GROUP BY release
        ORDER BY count DESC
    """).fetchdf()
    stats["dataset_releases"] = releases.to_dict(orient="records")

    # Metadata
    meta = con.execute("SELECT * FROM catalog_metadata").fetchdf()
    if not meta.empty:
        stats["catalog_metadata"] = dict(zip(meta["key"], meta["value"]))

    con.close()
    return json.dumps(stats, indent=2, default=_safe_json)


if __name__ == "__main__":
    mcp.run()
