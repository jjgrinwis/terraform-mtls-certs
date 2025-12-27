#!/usr/bin/env bash
set -euo pipefail

# Sync GitHub release notes from CHANGELOG.md
# Usage:
#   scripts/release.sh --version v0.1.2 [--notes-file /path/to/notes.md] [--dry-run]
# Behavior:
# - If --notes-file is not provided, extracts the section for the given version
#   from CHANGELOG.md (lines between the heading and the next version heading).
# - If the release exists, edits it; otherwise, creates it.
# - Requires GitHub CLI `gh` to be installed and authenticated.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

version=""
notes_file=""
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="$2"; shift 2;;
    --notes-file)
      notes_file="$2"; shift 2;;
    --dry-run)
      dry_run="true"; shift;;
    -h|--help)
      echo "Usage: $0 --version vX.Y.Z [--notes-file file] [--dry-run]"; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; exit 1;;
  esac
done

if [[ -z "$version" ]]; then
  echo "Error: --version is required (e.g., v0.1.2)" >&2
  exit 1
fi

if [[ -z "$notes_file" ]]; then
  if [[ ! -f "$CHANGELOG" ]]; then
    echo "Error: CHANGELOG.md not found at $CHANGELOG" >&2
    exit 1
  fi
  # Find start line for heading like: ## v0.1.2 — YYYY-MM-DD
  start_line=$(grep -nE "^##[[:space:]]+${version}[[:space:]]+—|^##[[:space:]]+${version}[[:space:]]" "$CHANGELOG" | head -n1 | cut -d: -f1 || true)
  if [[ -z "$start_line" ]]; then
    echo "Error: Version heading not found in CHANGELOG: $version" >&2
    exit 1
  fi
  total_lines=$(wc -l < "$CHANGELOG")
  # Find end line: first subsequent heading starting with '## '
  end_line=$(awk -v s="$start_line" 'NR > s && /^##[[:space:]]/{print NR; exit}' "$CHANGELOG" || true)
  if [[ -z "$end_line" ]]; then
    end_line=$((total_lines + 1))
  fi
  tmp_notes="$(mktemp)"
  # Extract lines from after heading to before next heading
  sed -n "${start_line},$((end_line-1))p" "$CHANGELOG" | tail -n +2 > "$tmp_notes"
  notes_file="$tmp_notes"
fi

if [[ "$dry_run" == "true" ]]; then
  echo "--- DRY RUN: would update release $version with notes ---"
  echo "Notes file: $notes_file"
  echo "---------------------------------------------"
  cat "$notes_file"
  echo "---------------------------------------------"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI 'gh' not found. Install from https://cli.github.com/" >&2
  exit 1
fi

# Decide whether to edit or create
if gh release view "$version" >/dev/null 2>&1; then
  gh release edit "$version" --notes-file "$notes_file"
else
  gh release create "$version" --title "$version" --notes-file "$notes_file"
fi

echo "✓ Release $version updated successfully."