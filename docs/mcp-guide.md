# CCHS metadata server: guide

## What is this?

The CCHS metadata server gives AI assistants (Claude, GPT, Gemini, etc.) direct access to the Canadian Community Health Survey variable database. Instead of searching through PDF data dictionaries or spreadsheets, you ask your AI assistant a question in plain English and it queries the database for you.

A **command-line interface** (CLI) is also available for querying the database directly from a terminal, without needing MCP or an AI assistant. See [Command-line interface](#command-line-interface) below.

**What it knows:** metadata for 16,963 CCHS variables across 253 datasets, spanning 2001 to 2023. This includes variable names, labels, question text, response categories with frequencies, and which survey cycles contain each variable. Master file metadata is available from 2001 to 2023; PUMF metadata from 2001 to 2022.

**What it doesn't have:** the actual survey microdata (respondent-level records). This is a metadata tool — it tells you what variables exist and how they're structured, not the data values themselves.

### How it works

The server uses [Model Context Protocol (MCP)](https://modelcontextprotocol.io), an open standard that lets AI assistants call external tools. When you ask "What smoking variables are in the 2015 PUMF?", the AI assistant:

1. Recognises this as a CCHS metadata question
2. Queries the metadata database behind the scenes
3. Gets structured results back
4. Presents the answer in natural language

You never need to write queries or tool calls yourself — just ask questions. The AI handles the mechanics.

### Who is this for?

- **Researchers** preparing CCHS analysis plans who need to find variables, check availability across cycles, or understand response categories
- **Data analysts** harmonising CCHS data across survey years who need to trace variable naming changes
- **Collaborators** evaluating how AI-assisted metadata lookup compares to manual PDF searching

### Setup

**Quick setup** (requires Python 3.8+ and `git`):

```bash
git clone https://github.com/Big-Life-Lab/cchsflow-docs.git
cd cchsflow-docs
./scripts/setup.sh
```

The setup script installs Python dependencies, downloads a pre-built database from [GitHub Releases](https://github.com/Big-Life-Lab/cchsflow-docs/releases), and creates the MCP configuration file. Then open the folder in Claude Code or another MCP-compatible client — the tools are available immediately.

**Manual setup** (if the setup script doesn't work for your environment):

1. Clone the repository: `git clone https://github.com/Big-Life-Lab/cchsflow-docs.git`
2. Install Python dependencies: `pip install -r mcp-server/requirements.txt`
3. Download `cchs_metadata.duckdb` from the [latest release](https://github.com/Big-Life-Lab/cchsflow-docs/releases) and place it in `database/`
4. Copy the MCP config template: `cp .mcp.json.example .mcp.json`
5. Open the folder in an MCP-compatible client

**Build from source** (for developers contributing to the database):

Building requires R 4.2+, `renv`, and the [cchsflow-data](https://github.com/Big-Life-Lab/cchsflow-data) repository cloned as a sibling directory. See [architecture.md](architecture.md) for details.

```bash
Rscript --vanilla -e "renv::restore()"
Rscript --vanilla database/build_db.R
```

**Verify your setup**:

```bash
python3 -c "
import duckdb
con = duckdb.connect('database/cchs_metadata.duckdb', read_only=True)
n = con.execute('SELECT COUNT(*) FROM variables').fetchone()[0]
print(f'OK: {n} variables in database')
con.close()
"
```

**Troubleshooting**:

| Error | Solution |
|-------|----------|
| `ModuleNotFoundError: No module named 'fastmcp'` | Run `pip install -r mcp-server/requirements.txt` |
| `FileNotFoundError: cchs_metadata.duckdb` | Download from [GitHub Releases](https://github.com/Big-Life-Lab/cchsflow-docs/releases) or build from source |
| MCP tools not appearing in your AI client | Check that `.mcp.json` exists in the repo root (copy from `.mcp.json.example`), then restart the client |

For technical details on individual tools, see [mcp-reference.md](mcp-reference.md).

### Command-line interface

If you prefer querying the database directly from a terminal — without MCP or an AI assistant — use the CLI:

```bash
python3 mcp-server/cli.py search smoking
python3 mcp-server/cli.py detail SMKDSTY
python3 mcp-server/cli.py history SMKDSTY
python3 mcp-server/cli.py codes SMKDSTY
python3 mcp-server/cli.py summary
```

The CLI requires only Python 3 and the `duckdb` package (no FastMCP needed). It supports the same 10 queries as the MCP server.

**All subcommands:**

| Command | Description | Example |
|---------|-------------|---------|
| `search` | Search by name or label | `search smoking --limit 10` |
| `detail` | Full metadata for a variable | `detail SMKDSTY` |
| `history` | Trace across cycles | `history SMKDSTY` |
| `dataset` | List variables in a dataset | `dataset cchs-2015d-p-can` |
| `common` | Shared variables between datasets | `common cchs-2013d-p-can cchs-2015d-p-can` |
| `compare` | Compare file types within a cycle | `compare SMKDSTY 2013-2014` |
| `codes` | Response categories | `codes SMKDSTY` |
| `conflicts` | Cross-source label disagreements | `conflicts --variable SMKDSTY` |
| `cchsflow` | Draft harmonisation row | `cchsflow GEN_010 2015-2016` |
| `summary` | Database overview | `summary` |

**Options:**

- `--json` — output as JSON instead of formatted tables (place before the subcommand)
- `--db PATH` — use a different database file
- `--limit N` — limit results (for `search` and `dataset`)

Example with JSON output:

```bash
python3 mcp-server/cli.py --json search smoking --limit 5
```

## TL;DR — what can I ask?

The MCP server has metadata for 16,963 CCHS variables across 253 datasets (2001-2023). Ask your AI assistant questions like:

- "Find all smoking cessation variables across all CCHS Master files from 2001 onward"
- "What response categories does SMKDSTY have, and did they change between cycles?"
- "Which alcohol variables are common to both the 2013-2014 and 2015-2016 PUMF?"
- "Show me the question text and universe for GEN_010"
- "Compare DHHGAGE between the PUMF and Share files for 2017-2018"
- "Generate a cchsflow harmonisation row for CCC_101 in the 2011-2012 cycle"
- "How many variables are in the 2022 PUMF?"
- "What modules group the physical activity variables?"

Just describe what you need. The AI assistant calls the appropriate tools automatically.

## Getting started

Ask your AI assistant:

> *"Search for CCHS smoking variables."*

The assistant will search the database and return matching variables with their names, labels, and how many datasets contain them. For example, it might respond:

> I found several smoking-related variables. Here are some highlights:
>
> - **SMK_06B** — Stopped smoking - month (never daily smoker), appears in 24 datasets
> - **SMK_09B** — Stopped smoking daily - month, appears in 24 datasets
> - **SMKDSTY** — Type of smoker (derived), appears in 4 PUMF datasets
>
> Would you like more detail on any of these?

From here, you can ask follow-up questions in plain English: "Tell me more about SMKDSTY" or "Which cycles have SMKDSTY?"

## Tutorial: exploring a variable

This walkthrough traces the full research path for investigating smoking status across CCHS cycles.

### Step 1: search for the variable

Start with a keyword search.

> *"Search for smoking variables in the CCHS."*

This returns variables like `SMK_06B`, `SMK_09B`, `SMKDSTY`, and others. The variable `SMKDSTY` (Type of smoker — derived) appears across multiple PUMF and Master datasets.

### Step 2: get full details

Ask for everything the database knows about a specific variable.

> *"Show me the full details for SMKDSTY."*

The assistant will return:

| Field | Example value |
|-------|---------------|
| Label | Type of smoker - (D) |
| Question text | Type of smoker - (D) |
| Universe | All respondents |
| Section | Health behaviour |
| cchsflow name | SMKDSTY_cat5 |
| Datasets | 4 |

The response also includes the full list of datasets containing this variable, its value codes with frequencies, summary statistics, and module group memberships.

### Step 3: trace across cycles

Ask which survey cycles contain the variable.

> *"Which CCHS cycles have SMKDSTY?"*

The assistant will report that SMKDSTY appears in multiple PUMF and Master cycles:

| Dataset | Years | Release | Sources |
|---------|-------|---------|---------|
| cchs-2003d-m-can | 2003 | Master | 613apps |
| cchs-2003d-p-can | 2003 | PUMF | 613apps |
| cchs-2005d-m-can | 2005 | Master | 613apps |
| cchs-2005d-p-can | 2005 | PUMF | 613apps |
| cchs-2007d-p-can | 2007-2008 | PUMF | pumf_rdata, ddi_xml, 613apps |
| cchs-2009d-p-can | 2009-2010 | PUMF | pumf_rdata, ddi_xml, 613apps |
| cchs-2011d-p-can | 2011-2012 | PUMF | pumf_rdata, ddi_xml, 613apps |
| cchs-2013d-p-can | 2013-2014 | PUMF | pumf_rdata, ddi_xml, 613apps |

Master datasets now show alongside PUMF, and multiple data sources are listed for each entry.

### Step 4: check response categories

Ask what the valid response codes are.

> *"What are the response categories for SMKDSTY?"*

| Code | Label | Frequency | Weighted |
|------|-------|-----------|----------|
| 1 | Daily | 18,413 | 4,147,683 |
| 2 | Occasional | 3,135 | 813,707 |
| 3 | Always occasionally | 1,985 | 602,006 |
| 4 | Former daily | 34,381 | 6,626,745 |
| 5 | Former occasional | 19,197 | 4,511,751 |
| 6 | Never smoked | 49,385 | 13,099,102 |
| 96 | Not applicable | — | — |
| 97 | Don't know | — | — |
| 98 | Refusal | — | — |
| 99 | Not stated | 966 | 201,822 |

Codes 96-99 are standard CCHS special codes. These should be handled as missing values in analysis.

### Step 5: compare file types within a cycle

Ask whether a variable differs between PUMF, Share, and Master releases.

> *"Compare SMKDSTY between file types for the 2013-2014 cycle."*

The assistant will show both the PUMF and Master releases for this cycle. When both are present, you can compare whether response categories or labels differ between releases — useful for understanding privacy-related category collapsing.

## How-to recipes

### Find all variables in a module

CCHS organises variables into subject modules (e.g., SMK for smoking, ALC for alcohol). You can search by module prefix or by topic:

> *"Find all variables starting with SMK_."*

> *"Search for alcohol variables."*

### List variables in a specific dataset

> *"What variables are in the 2015-2016 PUMF?"*

The assistant will return the variable list for that dataset. The 2015-2016 PUMF has 1,283 variables, so you may want to narrow your request (e.g., "What smoking variables are in the 2015-2016 PUMF?").

### Compare variables across two datasets

> *"Which variables are shared between the 2013-2014 and 2015-2016 PUMF?"*

This returns the full list of shared variable names. Consecutive PUMF national datasets typically share 700-900 variables.

### Check if a variable exists in a specific cycle

> *"Is GEN_010 in the 2017-2018 PUMF?"*

If the variable is present, you'll get its details. If not, the assistant will tell you it's missing — which may mean it was renamed or dropped in that cycle.

### Generate a cchsflow harmonisation row

The database can draft a worksheet row for the [cchsflow R package](https://github.com/Big-Life-Lab/cchsflow), which harmonises CCHS variables across cycles:

> *"Generate a cchsflow harmonisation row for GEN_010 in the 2015-2016 cycle."*

The response follows cchsflow's worksheet format with the source variable, target dataset, harmonised name, and recoding instruction. Always review before using — the tool suggests a starting point, not a validated mapping.

### Get database overview

> *"Give me an overview of the CCHS metadata database."*

Returns counts of variables, datasets, value codes, and a breakdown by data source. Useful for understanding the database's scope.

## Tips

### Dataset ID conventions

CCHS dataset IDs follow the pattern `cchs-{year}{temporal}-{release}-{geography}`:

| Component | Values | Example |
|-----------|--------|---------|
| Year | 2001-2023 | `2015` |
| Temporal | `s` (single-year), `d` (dual-year) | `d` |
| Release | `p` (PUMF), `s` (Share), `m` (Master), `l` (Linked) | `p` |
| Geography | `can` (national), `ont` (Ontario), etc. | `can` |

Example: `cchs-2015d-p-can` = 2015-2016 dual-year PUMF, national file.

You don't need to memorise these — the AI assistant understands requests like "the 2015-2016 PUMF" and resolves them to the correct dataset ID.

### Variable naming patterns

CCHS variable names encode their module and question number:

- `SMK_` — Smoking module
- `ALC_` — Alcohol module
- `GEN_` — General health
- `CCC_` — Chronic conditions
- `DHH` — Demographics/household
- `DHHGAGE` — Derived: age group

Derived variables (calculated from other responses) typically have a `D` suffix or appear in the "Derived variables" section.

### Special codes

Most CCHS variables use these standard special codes for missing or inapplicable responses:

| Code | Meaning |
|------|---------|
| 6 / 96 / 996 | Valid skip (not applicable) |
| 7 / 97 / 997 | Don't know |
| 8 / 98 / 998 | Refusal |
| 9 / 99 / 999 | Not stated |

The exact codes depend on the variable's range. Single-digit variables use 6-9; two-digit variables use 96-99; three-digit variables use 996-999.

### Data sources

The database draws from multiple Statistics Canada sources. Primary sources (StatCan-generated documentation) are preferred over secondary sources when conflicts exist. If you need to know which source a particular piece of metadata came from, ask: "What sources attest SMKDSTY?"
