"""
CCHS Metadata MCP Server

Exposes the unified CCHS metadata DuckDB via Model Context Protocol tools.
See: development/redevelopment/PROPOSAL_mcp_metadata_architecture.md
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


@mcp.tool()
def search_variables(query: str, limit: int = 20) -> str:
    """Search for CCHS variables by name or label.

    Args:
        query: Search term (matched against variable_name and label)
        limit: Maximum results to return (default 20)
    """
    con = get_connection()
    results = con.execute("""
        SELECT variable_name, label, type, dataset_count
        FROM variables
        WHERE variable_name ILIKE ? OR label ILIKE ?
        ORDER BY dataset_count DESC
        LIMIT ?
    """, [f"%{query}%", f"%{query}%", limit]).fetchdf()
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
        SELECT variable_name, label, type, format, dataset_count
        FROM variables
        WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    if var_info.empty:
        con.close()
        return json.dumps({"error": f"Variable '{variable_name}' not found"})

    # Availability with cycle info
    availability = con.execute("""
        SELECT ds.dataset_id, ds.cycle, ds.file_type
        FROM variable_availability va
        JOIN datasets ds ON va.dataset_id = ds.dataset_id
        WHERE va.variable_name = ?
        ORDER BY ds.cycle
    """, [variable_name]).fetchdf()

    # DDI enrichment (if available)
    ddi = con.execute("""
        SELECT dataset_id, question_text, universe_logic, categories_json
        FROM ddi_variables
        WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    # Value format codes
    format_name = var_info["format"].iloc[0]
    value_codes = None
    if format_name:
        vc = con.execute("""
            SELECT code, label FROM value_formats WHERE format_name = ?
        """, [format_name]).fetchdf()
        if not vc.empty:
            value_codes = vc.to_dict(orient="records")

    con.close()

    result = {
        "variable_name": var_info["variable_name"].iloc[0],
        "label": var_info["label"].iloc[0],
        "type": var_info["type"].iloc[0],
        "format": format_name,
        "dataset_count": int(var_info["dataset_count"].iloc[0]),
        "availability": availability.to_dict(orient="records"),
    }

    if not ddi.empty:
        # Use the first non-null question text
        qt = ddi.loc[ddi["question_text"].notna(), "question_text"]
        ul = ddi.loc[ddi["universe_logic"].notna(), "universe_logic"]
        result["question_text"] = qt.iloc[0] if not qt.empty else None
        result["universe_logic"] = ul.iloc[0] if not ul.empty else None

        # Parse categories from DDI
        cats = ddi.loc[ddi["categories_json"].notna(), "categories_json"]
        if not cats.empty:
            try:
                result["ddi_categories"] = json.loads(cats.iloc[0])
            except (json.JSONDecodeError, TypeError):
                pass

    if value_codes:
        result["value_codes"] = value_codes

    return json.dumps(result, indent=2, default=str)


@mcp.tool()
def get_variable_history(variable_name: str) -> str:
    """Trace a variable across all CCHS cycles and datasets.
    Shows which cycles and file types contain this variable.

    Args:
        variable_name: Exact variable name (e.g., 'SMKDSTY')
    """
    con = get_connection()
    results = con.execute("""
        SELECT
            v.variable_name,
            v.label,
            ds.cycle,
            ds.file_type,
            ds.dataset_id,
            d.question_text
        FROM variables v
        JOIN variable_availability va ON v.variable_name = va.variable_name
        JOIN datasets ds ON va.dataset_id = ds.dataset_id
        LEFT JOIN ddi_variables d
            ON v.variable_name = d.variable_name
            AND va.dataset_id = d.dataset_id
        WHERE v.variable_name = ?
        ORDER BY ds.cycle, ds.file_type
    """, [variable_name]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({"error": f"Variable '{variable_name}' not found"})

    return results.to_json(orient="records", indent=2)


@mcp.tool()
def get_dataset_variables(dataset_id: str, limit: int = 100) -> str:
    """List all variables in a specific dataset.

    Args:
        dataset_id: Dataset identifier (e.g., 'CCHS201516_ONT_SHARE')
        limit: Maximum results (default 100)
    """
    con = get_connection()
    results = con.execute("""
        SELECT v.variable_name, v.label, v.type
        FROM variable_availability va
        JOIN variables v ON va.variable_name = v.variable_name
        WHERE va.dataset_id = ?
        ORDER BY v.variable_name
        LIMIT ?
    """, [dataset_id, limit]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({"error": f"Dataset '{dataset_id}' not found or empty"})

    return results.to_json(orient="records", indent=2)


@mcp.tool()
def get_common_variables(dataset_id_1: str, dataset_id_2: str) -> str:
    """Find variables shared between two datasets.

    Args:
        dataset_id_1: First dataset identifier
        dataset_id_2: Second dataset identifier
    """
    con = get_connection()
    results = con.execute("""
        SELECT v.variable_name, v.label, v.type
        FROM variable_availability va1
        JOIN variable_availability va2
            ON va1.variable_name = va2.variable_name
        JOIN variables v ON va1.variable_name = v.variable_name
        WHERE va1.dataset_id = ? AND va2.dataset_id = ?
        ORDER BY v.variable_name
    """, [dataset_id_1, dataset_id_2]).fetchdf()
    con.close()

    return json.dumps({
        "dataset_1": dataset_id_1,
        "dataset_2": dataset_id_2,
        "common_count": len(results),
        "variables": results.to_dict(orient="records") if not results.empty else []
    }, indent=2)


@mcp.tool()
def compare_master_pumf(variable_name: str, cycle: str) -> str:
    """Compare a variable between different file types (Share, PUMF, Linked)
    for a given cycle.

    Args:
        variable_name: Exact variable name
        cycle: Cycle year(s) (e.g., '2015-2016' or '2015')
    """
    con = get_connection()

    results = con.execute("""
        SELECT
            ds.file_type,
            ds.dataset_id,
            d.question_text,
            d.universe_logic,
            d.categories_json
        FROM variable_availability va
        JOIN datasets ds ON va.dataset_id = ds.dataset_id
        LEFT JOIN ddi_variables d
            ON va.variable_name = d.variable_name
            AND va.dataset_id = d.dataset_id
        WHERE va.variable_name = ? AND ds.cycle = ?
        ORDER BY ds.file_type
    """, [variable_name, cycle]).fetchdf()
    con.close()

    if results.empty:
        return json.dumps({
            "error": f"No data for '{variable_name}' in cycle '{cycle}'"
        })

    comparisons = []
    for _, row in results.iterrows():
        entry = {
            "file_type": row["file_type"],
            "dataset_id": row["dataset_id"],
        }
        if row["question_text"]:
            entry["question_text"] = row["question_text"]
        if row["categories_json"]:
            try:
                entry["categories"] = json.loads(row["categories_json"])
            except (json.JSONDecodeError, TypeError):
                entry["categories_raw"] = row["categories_json"]
        comparisons.append(entry)

    return json.dumps({
        "variable_name": variable_name,
        "cycle": cycle,
        "file_types_found": list(results["file_type"].unique()),
        "comparisons": comparisons
    }, indent=2, default=str)


@mcp.tool()
def get_value_codes(variable_name: str) -> str:
    """Get response categories/value codes for a variable.
    Checks both the ICES value_formats table and DDI categories.

    Args:
        variable_name: Exact variable name
    """
    con = get_connection()

    # Get format name from variables table
    var = con.execute("""
        SELECT format FROM variables WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    result = {"variable_name": variable_name}

    if not var.empty and var["format"].iloc[0]:
        format_name = var["format"].iloc[0]
        codes = con.execute("""
            SELECT code, label FROM value_formats WHERE format_name = ?
            ORDER BY code
        """, [format_name]).fetchdf()
        if not codes.empty:
            result["ices_value_codes"] = codes.to_dict(orient="records")

    # Also check DDI categories
    ddi = con.execute("""
        SELECT dataset_id, categories_json
        FROM ddi_variables
        WHERE variable_name = ? AND categories_json IS NOT NULL
        LIMIT 1
    """, [variable_name]).fetchdf()

    if not ddi.empty:
        try:
            result["ddi_categories"] = json.loads(ddi["categories_json"].iloc[0])
            result["ddi_source_dataset"] = ddi["dataset_id"].iloc[0]
        except (json.JSONDecodeError, TypeError):
            pass

    con.close()

    if len(result) == 1:
        result["message"] = f"No value codes found for '{variable_name}'"

    return json.dumps(result, indent=2)


@mcp.tool()
def suggest_cchsflow_row(variable_name: str, target_cycle: str) -> str:
    """Generate a draft cchsflow worksheet row for a variable in a target cycle.
    Uses existing metadata to suggest rec_with_table format.

    Args:
        variable_name: Variable to harmonise
        target_cycle: Cycle to generate the row for (e.g., '2015-2016')
    """
    con = get_connection()

    # Check if variable exists in target cycle
    avail = con.execute("""
        SELECT ds.dataset_id, ds.file_type
        FROM variable_availability va
        JOIN datasets ds ON va.dataset_id = ds.dataset_id
        WHERE va.variable_name = ? AND ds.cycle = ?
    """, [variable_name, target_cycle]).fetchdf()

    # Get variable metadata
    var_info = con.execute("""
        SELECT label, type, format FROM variables WHERE variable_name = ?
    """, [variable_name]).fetchdf()

    # Get DDI categories if available
    ddi = con.execute("""
        SELECT categories_json, question_text
        FROM ddi_variables
        WHERE variable_name = ?
        LIMIT 1
    """, [variable_name]).fetchdf()

    # Get value codes
    value_codes = None
    if not var_info.empty and var_info["format"].iloc[0]:
        vc = con.execute("""
            SELECT code, label FROM value_formats WHERE format_name = ?
        """, [var_info["format"].iloc[0]]).fetchdf()
        if not vc.empty:
            value_codes = vc.to_dict(orient="records")

    con.close()

    result = {
        "variable_name": variable_name,
        "target_cycle": target_cycle,
        "available_in_cycle": not avail.empty,
    }

    if not var_info.empty:
        result["label"] = var_info["label"].iloc[0]
        result["type"] = var_info["type"].iloc[0]

    if not avail.empty:
        result["datasets_in_cycle"] = avail.to_dict(orient="records")

    if not ddi.empty:
        if ddi["question_text"].iloc[0]:
            result["question_text"] = ddi["question_text"].iloc[0]
        if ddi["categories_json"].iloc[0]:
            try:
                result["categories"] = json.loads(ddi["categories_json"].iloc[0])
            except (json.JSONDecodeError, TypeError):
                pass

    if value_codes:
        result["value_codes"] = value_codes

    # Generate suggested cchsflow row
    if not avail.empty and not var_info.empty:
        result["suggested_row"] = {
            "variable": variable_name,
            "databaseStart": avail["dataset_id"].iloc[0],
            "variableStart": variable_name,
            "variableStartLabel": var_info["label"].iloc[0] if not var_info.empty else "",
            "rec_from": "copy",
            "rec_to": variable_name,
            "note": f"Auto-suggested for cycle {target_cycle}. Review before use."
        }

    return json.dumps(result, indent=2, default=str)


@mcp.tool()
def get_database_summary() -> str:
    """Get high-level summary statistics for the CCHS metadata database."""
    con = get_connection()

    stats = {}
    stats["total_variables"] = con.execute(
        "SELECT COUNT(*) FROM variables"
    ).fetchone()[0]
    stats["total_datasets"] = con.execute(
        "SELECT COUNT(*) FROM datasets"
    ).fetchone()[0]
    stats["total_availability_rows"] = con.execute(
        "SELECT COUNT(*) FROM variable_availability"
    ).fetchone()[0]
    stats["total_value_formats"] = con.execute(
        "SELECT COUNT(*) FROM value_formats"
    ).fetchone()[0]
    stats["ddi_enriched_variables"] = con.execute(
        "SELECT COUNT(DISTINCT variable_name) FROM ddi_variables"
    ).fetchone()[0]
    stats["ddi_with_question_text"] = con.execute(
        "SELECT COUNT(*) FROM ddi_variables WHERE question_text IS NOT NULL"
    ).fetchone()[0]

    # Cycle coverage
    cycles = con.execute("""
        SELECT cycle, COUNT(*) as dataset_count
        FROM datasets
        GROUP BY cycle
        ORDER BY cycle
    """).fetchdf()
    stats["cycles"] = cycles.to_dict(orient="records")

    # File type distribution
    file_types = con.execute("""
        SELECT file_type, COUNT(*) as count
        FROM datasets
        GROUP BY file_type
        ORDER BY count DESC
    """).fetchdf()
    stats["file_types"] = file_types.to_dict(orient="records")

    # Metadata
    meta = con.execute("SELECT * FROM catalog_metadata").fetchdf()
    if not meta.empty:
        stats["catalog_metadata"] = dict(zip(meta["key"], meta["value"]))

    con.close()
    return json.dumps(stats, indent=2)


if __name__ == "__main__":
    mcp.run()
