#!/usr/bin/env bash

# validate_metadata.sh
#
# Checks a project's metadata file for common formatting issues that trigger nf-core/ampliseq / R read.table errors
# and enforces your metadata rules.
#
#
# Looks in:
#   /group/ajfingergrp/Metabarcoding/Project_Runs/${PROJECT_NAME}/input/
#
# Rules enforced:
#  - filename contains "metadata"
#  - file is .txt (tab-delimited) or .tsv
#  - first column header must be exactly "ID"
#  - warns if Run column missing; if present, validates A/B/C... style
#  - warns if Control_Assign missing (for decontam later)
#  - checks for CRLF (^M) and inconsistent field counts (classic "line X did not have N elements")
#  - checks for empty/duplicate sample IDs
#  - checks for hyphens and spaces
#
# Exit codes:
#  0 success
#  1 validation error (fix needed)
#  2 usage / missing directory

set -euo pipefail

PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")
if [ -z "$PROJECT_NAME" ]; then
  echo "ERROR: missing PROJECT_NAME"
  echo "Usage: $0 PROJECT_NAME"
  exit 2
fi

BASE="/group/ajfingergrp/Metabarcoding/Project_Runs/${PROJECT_NAME}/input"
if [[ ! -d "$BASE" ]]; then
  echo "ERROR: input directory not found: $BASE"
  exit 2
fi

shopt -s nullglob

# Find metadata candidates (case-insensitive contains 'metadata')
mapfile -t META_CANDIDATES < <(find "$BASE" -maxdepth 1 -type f \
  \( -iname "*metadata*.tsv" -o -iname "*metadata*.txt" \) | sort)

if (( ${#META_CANDIDATES[@]} == 0 )); then
  echo "ERROR: No metadata file found in $BASE with 'metadata' in the filename and extension .txt/.tsv"
  exit 1
fi

if (( ${#META_CANDIDATES[@]} > 1 )); then
  echo "ERROR: Multiple metadata candidates found. Please keep only one (or rename extras):"
  printf '  - %s\n' "${META_CANDIDATES[@]}"
  exit 1
fi

META="${META_CANDIDATES[0]}"
echo "Using metadata file: $META"

EXT="${META##*.}"
if [[ "$EXT" != "tsv" && "$EXT" != "txt" ]]; then
  echo "ERROR: Metadata must be .tsv or .txt (tab-delimited). Found: .$EXT"
  exit 1
fi

# ---------- Helpers ----------
fail() { echo "ERROR: $*" ; exit 1; }
warn() { echo "WARN:  $*" ; }
info() { echo "GOOD:  $*" ; }

# ---------- Basic content checks ----------

if [[ ! -s "$META" ]]; then
  fail "Metadata file is empty."
fi

# CRLF endings (Windows ^M)
if LC_ALL=C grep -q $'\r' "$META"; then
  fail "Metadata contains Windows CRLF (^M). Fix with: dos2unix \"$META\"  OR  sed -i 's/\\r$//' \"$META\""
fi
info "No CRLF (^M) detected."

# Confirm tab-delimited (header must contain at least one tab)
HEADER="$(head -n 1 "$META")"
if [[ "$HEADER" != *$'\t'* ]]; then
  fail "Metadata does not appear tab-delimited (no tabs found in header). Export as TSV (tabs), not CSV/spaces."
fi
info "Tabs detected in header."

# ---------- Disallowed characters check ----------
# Enforce: no hyphens '-' and no spaces ' ' in ANY field (data rows)
# (Do not print offending values/lines; just instruct user to fix & re-upload)
if ! awk -F'\t' '
  NR==1 { next }   # skip header
  {
    for (i=1; i<=NF; i++) {
      if ($i ~ /-/ || $i ~ / /) exit 1
    }
  }
' "$META"; then
  fail "Metadata contains hyphens (-) or spaces in one or more fields. Please fix the metadata file and re-upload before running the pipeline."
fi
info "No hyphens or spaces detected in any metadata fields."

# Field count consistency (classic read.table/scan failure)
EXPECTED_FIELDS="$(awk -F'\t' 'NR==1{print NF; exit}' "$META")"

BAD_LINES="$(
  awk -F'\t' -v expected="$EXPECTED_FIELDS" '
    NF!=expected {print NR ":" NF}
  ' "$META" | head -n 20 || true
)"

if [[ -n "$BAD_LINES" ]]; then
  echo "ERROR: Inconsistent number of tab-separated fields."
  echo "       Header has $EXPECTED_FIELDS fields; first offending lines (line:NF):"
  echo "$BAD_LINES" | sed 's/^/         - /'
  echo "Tip: inspect a bad line with:"
  echo "  sed -n '<LINE>p' \"$META\" | cat -A"
  exit 1
fi
info "All rows have consistent field counts ($EXPECTED_FIELDS fields)."

# ---------- Header/rules checks ----------
# First column must be exactly 'ID'
FIRST_COL="$(awk -F'\t' 'NR==1{print $1; exit}' "$META")"
if [[ "$FIRST_COL" != "ID" ]]; then
  fail "First column header must be exactly 'ID'. Found: '$FIRST_COL'"
fi
info "First column header is 'ID'."

# Presence checks
HAS_RUN="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="Run") found=1} END{print (found?1:0)}' "$META")"
HAS_CTRL="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="Control_Assign") found=1} END{print (found?1:0)}' "$META")"

if [[ "$HAS_RUN" -ne 1 ]]; then
  warn "No 'Run' column found. If you sequenced multiple runs, add a 'Run' column with IDs A, B, C, ..."
else
  info "'Run' column found."
fi

if [[ "$HAS_CTRL" -ne 1 ]]; then
  warn "No 'Control_Assign' column found. Add it if you plan decontamination later."
else
  info "'Control_Assign' column found."
fi

# ---------- sample ID sanity checks ----------
# Non-empty sample IDs
EMPTY_SIDS="$(awk -F'\t' 'NR>1 && ($1=="" || $1 ~ /^[[:space:]]+$/){print NR}' "$META" | head -n 10 || true)"
if [[ -n "$EMPTY_SIDS" ]]; then
  fail "Empty sample ID(s) detected on line(s): $(echo "$EMPTY_SIDS" | paste -sd, -)"
fi

# Duplicate sample IDs
DUP_SIDS="$(awk -F'\t' 'NR>1{print $1}' "$META" | sort | uniq -d | head -n 20 || true)"
if [[ -n "$DUP_SIDS" ]]; then
  echo "ERROR: Duplicate sample ID(s) detected (first 20):"
  echo "$DUP_SIDS" | sed 's/^/  - /'
  exit 1
fi
info "No duplicate sample ID values detected."

# ---------- Run column validation (if present) ----------
if [[ "$HAS_RUN" -eq 1 ]]; then
  RUN_COL="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="Run"){print i; exit}}' "$META")"

  BLANK_RUN="$(awk -F'\t' -v c="$RUN_COL" 'NR>1 && $c==""{print NR}' "$META" | head -n 10 || true)"
  if [[ -n "$BLANK_RUN" ]]; then
    warn "Some rows have blank Run values (first 10 line numbers): $(echo "$BLANK_RUN" | paste -sd, -)"
  fi

  BAD_RUN="$(awk -F'\t' -v c="$RUN_COL" 'NR>1 && $c!="" && $c !~ /^[A-Z]$/ {print NR ":" $c}' "$META" | head -n 20 || true)"
  if [[ -n "$BAD_RUN" ]]; then
    echo "WARN: Some Run IDs are not single-letter A/B/C... (line:Run) (first 20):"
    echo "$BAD_RUN" | sed 's/^/  - /'
    echo "      nf-core/ampliseq prefers Run IDs like A, B, C, ..."
  else
    info "Run IDs look like single-letter A/B/C... (or blank)."
  fi
fi

# ---------- Control_Assign quick validation (if present) ----------
if [[ "$HAS_CTRL" -eq 1 ]]; then
  CTRL_COL="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="Control_Assign"){print i; exit}}' "$META")"
  # Allow: empty, single token, or comma-separated tokens with letters/numbers/underscore/hyphen (e.g. 1,2,4 or F1,E9)
  BAD_CTRL="$(awk -F'\t' -v c="$CTRL_COL" '
    NR>1 && $c!="" {
      v=$c; gsub(/"/,"",v);
      if(v !~ /^([A-Za-z0-9_-]+)(,([A-Za-z0-9_-]+))*$/) print NR ":" v
    }' "$META" | head -n 20 || true)"
  if [[ -n "$BAD_CTRL" ]]; then
    echo "WARN: Some Control_Assign values look oddly formatted (line:Control_Assign) (first 20):"
    echo "$BAD_CTRL" | sed 's/^/  - /'
    echo "      Expected like: 1,2,4  or  F1,E9,T5"
  else
    info "Control_Assign values look reasonably formatted (or blank)."
  fi
fi

echo "Metadata validation completed successfully."