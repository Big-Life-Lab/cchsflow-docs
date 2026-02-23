#!/bin/bash
# setup.sh — Set up the CCHS metadata MCP server.
#
# Checks prerequisites, installs Python dependencies, downloads the
# pre-built database from GitHub Releases, and creates .mcp.json.
#
# Usage:
#   ./scripts/setup.sh

set -euo pipefail

REPO="Big-Life-Lab/cchsflow-docs"
DB_PATH="database/cchs_metadata.duckdb"
MCP_CONFIG=".mcp.json"
MCP_TEMPLATE=".mcp.json.example"
REQUIREMENTS="mcp-server/requirements.txt"

# Colours (disabled if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

ok()   { echo -e "${GREEN}OK${NC}: $1"; }
warn() { echo -e "${YELLOW}WARNING${NC}: $1"; }
fail() { echo -e "${RED}ERROR${NC}: $1"; exit 1; }

echo "=== CCHS Metadata Server Setup ==="
echo ""

# -------------------------------------------------------------------
# 1. Check prerequisites
# -------------------------------------------------------------------
echo "Checking prerequisites..."

# Python 3
if command -v python3 &>/dev/null; then
  PY_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
  ok "Python $PY_VERSION"
else
  fail "Python 3 not found. Install Python 3.8+ from https://www.python.org"
fi

# pip
if python3 -m pip --version &>/dev/null; then
  ok "pip available"
else
  fail "pip not found. Install with: python3 -m ensurepip --upgrade"
fi

echo ""

# -------------------------------------------------------------------
# 2. Install Python dependencies
# -------------------------------------------------------------------
echo "Installing Python dependencies..."

if [ ! -f "$REQUIREMENTS" ]; then
  fail "Requirements file not found: $REQUIREMENTS"
fi

python3 -m pip install -q -r "$REQUIREMENTS"
ok "Python dependencies installed (fastmcp, duckdb, pandas)"
echo ""

# -------------------------------------------------------------------
# 3. Download database from GitHub Releases (if not present)
# -------------------------------------------------------------------
if [ -f "$DB_PATH" ]; then
  ok "Database already exists: $DB_PATH"
else
  echo "Downloading pre-built database from GitHub Releases..."

  mkdir -p database

  DOWNLOADED=false

  # Try gh CLI first (handles auth, private repos)
  if command -v gh &>/dev/null; then
    LATEST_TAG=$(gh release list --repo "$REPO" --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || echo "")
    if [ -n "$LATEST_TAG" ]; then
      echo "  Found release: $LATEST_TAG"
      if gh release download "$LATEST_TAG" --repo "$REPO" --pattern "cchs_metadata.duckdb" --dir database/ 2>/dev/null; then
        DOWNLOADED=true
      fi
    fi
  fi

  # Fallback: curl from GitHub API
  if [ "$DOWNLOADED" = false ]; then
    RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"
    ASSET_URL=$(curl -sL "$RELEASE_URL" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for asset in data.get('assets', []):
        if asset['name'] == 'cchs_metadata.duckdb':
            print(asset['browser_download_url'])
            break
except: pass
" 2>/dev/null || echo "")

    if [ -n "$ASSET_URL" ]; then
      echo "  Downloading from: $ASSET_URL"
      curl -sL -o "$DB_PATH" "$ASSET_URL"
      DOWNLOADED=true
    fi
  fi

  if [ "$DOWNLOADED" = true ] && [ -f "$DB_PATH" ]; then
    SIZE=$(du -h "$DB_PATH" | cut -f1)
    ok "Database downloaded ($SIZE): $DB_PATH"
  else
    warn "Could not download database from GitHub Releases."
    echo ""
    echo "  To build from source (requires R 4.2+ and cchsflow-data repo):"
    echo "    Rscript --vanilla -e \"renv::restore()\""
    echo "    Rscript --vanilla database/build_db.R"
    echo ""
    echo "  Or download manually from:"
    echo "    https://github.com/$REPO/releases"
    echo ""
  fi
fi

echo ""

# -------------------------------------------------------------------
# 4. Create .mcp.json from template
# -------------------------------------------------------------------
if [ -f "$MCP_CONFIG" ]; then
  ok "MCP config already exists: $MCP_CONFIG"
else
  if [ -f "$MCP_TEMPLATE" ]; then
    cp "$MCP_TEMPLATE" "$MCP_CONFIG"
    ok "Created $MCP_CONFIG from $MCP_TEMPLATE"
  else
    fail "MCP template not found: $MCP_TEMPLATE"
  fi
fi

echo ""

# -------------------------------------------------------------------
# 5. Verify
# -------------------------------------------------------------------
echo "Verifying setup..."

if [ ! -f "$DB_PATH" ]; then
  warn "Database not found — MCP server will not work until the database is built or downloaded."
  echo ""
  exit 1
fi

RESULT=$(python3 -c "
import duckdb
con = duckdb.connect('$DB_PATH', read_only=True)
n_vars = con.execute('SELECT COUNT(*) FROM variables').fetchone()[0]
n_datasets = con.execute('SELECT COUNT(*) FROM datasets').fetchone()[0]
version = con.execute(\"SELECT value FROM catalog_metadata WHERE key = 'version'\").fetchone()
v = version[0] if version else 'unknown'
print(f'{n_vars} variables, {n_datasets} datasets, database version {v}')
con.close()
" 2>&1) || fail "Database verification failed: $RESULT"

ok "Database: $RESULT"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Open this folder in Claude Code or another MCP-compatible client"
echo "  2. The CCHS metadata tools will be available automatically"
echo "  3. Try asking: \"Search for smoking variables in the CCHS\""
echo ""
echo "  For usage guide: docs/mcp-guide.md"
echo "  For tool reference: docs/mcp-reference.md"
