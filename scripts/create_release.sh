#!/bin/bash
# create_release.sh
# Create a GitHub release with DuckDB and CSV assets.
#
# Assets attached to releases don't count against Git repo size limits.
#
# Usage:
#   ./scripts/create_release.sh           # create release for current VERSION
#   ./scripts/create_release.sh --draft   # create as draft release

set -euo pipefail

VERSION=$(cat VERSION)
TAG="v${VERSION}"
DRAFT_FLAG=""

if [[ "${1:-}" == "--draft" ]]; then
  DRAFT_FLAG="--draft"
  echo "Creating DRAFT release ${TAG}..."
else
  echo "Creating release ${TAG}..."
fi

# Check for uncommitted changes
if ! git diff --quiet HEAD; then
  echo "WARNING: You have uncommitted changes. Commit before releasing."
  exit 1
fi

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "ERROR: Tag ${TAG} already exists. Bump VERSION first."
  exit 1
fi

# Check DuckDB exists
DB_PATH="database/cchs_metadata.duckdb"
if [[ ! -f "$DB_PATH" ]]; then
  echo "ERROR: ${DB_PATH} not found. Run: Rscript --vanilla database/build_db.R"
  exit 1
fi

# Create annotated tag
git tag -a "$TAG" -m "Release ${TAG}"
echo "Created tag: ${TAG}"

# Create release with assets
gh release create "$TAG" \
  --title "CCHS Metadata Database ${TAG}" \
  --generate-notes \
  ${DRAFT_FLAG} \
  "${DB_PATH}" \
  data/sources.csv \
  data/datasets.csv \
  data/variables.csv

echo ""
echo "Release ${TAG} created successfully."
echo "View at: $(gh release view "$TAG" --json url -q .url)"
