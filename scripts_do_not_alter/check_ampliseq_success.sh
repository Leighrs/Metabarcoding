#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# check_run_success_and_optionally_remove_failed_samples.sh
#
# Combined script: handles BOTH
#   A) cutadapt trimming failures
#   B) DADA2 quality-filtering failures
#
# What it does:
# 1) Detects current PROJECT_NAME from the standard project file.
# 2) Asks if you expect a phyloseq object.
#    - If YES: success if dada2_phyloseq.rds exists
#    - If NO : success if ASV_seqs.fasta exists
# 3) If not successful: asks for SLURM job ID, finds the matching .out log,
#    scans for:
#       - cutadapt "too few reads" block (failed trimming)
#       - DADA2   "too few reads" block (failed quality filtering)
#    extracts sample IDs, and offers to remove those samples from samplesheet + metadata (with backups).
# 4) Writes separate records of removed rows to:
#    .../output/Removed_Samples/Samples_Removed_Failed_Trimming.txt
#    .../output/Removed_Samples/Samples_Removed_Failed_Filtering.txt
# ------------------------------------------------------------

if [[ ! -t 0 ]]; then
  echo "ERROR: This script requires an interactive terminal (it prompts for input)." >&2
  exit 1
fi

# -----------------------------
# Config / paths
# -----------------------------
PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"
LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: Project name file does not exist: $PROJECT_FILE"
  exit 1
fi

PROJECT_NAME="$(tr -d '[:space:]' < "$PROJECT_FILE")"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: Project name file is empty: $PROJECT_FILE"
  exit 1
fi

echo "Detected project: $PROJECT_NAME"

PROJECT_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME"

PHYLOSEQ_RDS="$PROJECT_DIR/output/phyloseq/dada2_phyloseq.rds"
ASV_FASTA="$PROJECT_DIR/output/dada2/ASV_seqs.fasta"

SAMPLESHEET="$PROJECT_DIR/input/${PROJECT_NAME}_samplesheet.txt"
PARAMS_JSON="$PROJECT_DIR/params/${PROJECT_NAME}_nf-params_expanded.json"

REMOVED_DIR="$PROJECT_DIR/output/Removed_Samples"
mkdir -p "$REMOVED_DIR"

# Failure block markers (must match exact text in logs)
CUTADAPT_START="The following samples had too few reads (<1) after trimming with cutadapt:"
CUTADAPT_END="Please check whether the correct primer sequences for trimming were supplied. Ignore that samples using \`--ignore_failed_trimming\` or adjust the threshold with \`--min_read_counts\`."

DADA2_START="The following samples had too few reads (<1) after quality filtering with DADA2:"
DADA2_END="Please check settings related to quality filtering such as \`--max_ee\` (increase), \`--trunc_qmin\` (increase) or \`--trunclenf\`/\`--trunclenr\` (decrease). Ignore that samples using \`--ignore_failed_filtering\` or adjust the threshold with \`--min_read_counts\`."

# -----------------------------
# Helpers
# -----------------------------
prompt_yn() {
  # Usage: prompt_yn "Question?" "default"
  # default should be "yes" or "no"
  local q="$1"
  local def="${2:-no}"
  local ans

  echo "$q (yes/no) [default: $def]:" >&2
  read -r ans
  ans="$(echo "${ans:-$def}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ans" != "yes" && "$ans" != "no" ]]; then
    echo "ERROR: Please answer 'yes' or 'no'." >&2
    exit 1
  fi
  echo "$ans"
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -p "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
  fi
}

# Extract metadata path from the params JSON reliably using python (no jq dependency)
get_metadata_path_from_json() {
  local json="$1"
  python3 - <<'PY' "$json"
import json, sys
p = sys.argv[1]
with open(p, "r") as fh:
    obj = json.load(fh)
for key_path in (("metadata",), ("params","metadata")):
    cur = obj
    ok = True
    for k in key_path:
        if isinstance(cur, dict) and k in cur:
            cur = cur[k]
        else:
            ok = False
            break
    if ok and isinstance(cur, str) and cur.strip():
        print(cur.strip())
        sys.exit(0)
print("")
PY
}

# Find a log file in LOGDIR containing job id and ending in .out
find_slurm_out_for_job() {
  local jobid="$1"
  local exact any
  exact="$(ls -1 "$LOGDIR"/*_"$jobid".out 2>/dev/null | head -n 1 || true)"
  if [[ -n "$exact" ]]; then
    echo "$exact"
    return 0
  fi
  any="$(ls -1 "$LOGDIR"/*"$jobid"*.out 2>/dev/null | head -n 1 || true)"
  if [[ -n "$any" ]]; then
    echo "$any"
    return 0
  fi
  echo ""
}

# Extract sample IDs between markers. Assumes one sample ID per line.
extract_samples_between_markers() {
  local logfile="$1"
  local start="$2"
  local end="$3"
  awk -v start="$start" -v end="$end" '
    $0 == start {inblock=1; next}
    $0 == end {inblock=0}
    inblock {
      gsub(/\r/,"")
      if ($0 ~ /^[[:space:]]*$/) next
      sub(/^[[:space:]]+/, "", $0)
      sub(/[[:space:]]+$/, "", $0)
      if (!seen[$0]++) print $0
    }
  ' "$logfile"
}

# Remove rows from a TSV by matching first column to IDs in a file.
# Saves removed data rows (header excluded) to removed_out. Output keeps header.
filter_tsv_by_first_col_remove_ids() {
  local in_tsv="$1"
  local ids_file="$2"
  local out_tsv="$3"
  local removed_out="$4"

  awk -v ids="$ids_file" -v removed="$removed_out" '
    BEGIN{
      while ((getline line < ids) > 0) {
        gsub(/\r/,"",line)
        if (line!="") bad[line]=1
      }
      close(ids)
    }
    NR==1 {print; next}
    {
      key=$1
      if (key in bad) { print > removed; next }
      print
    }
  ' "$in_tsv" > "$out_tsv"
}

# Perform removal workflow for a given failure type + sample list
remove_samples_workflow() {
  local reason_label="$1"          # e.g., "Failed trimming ..."
  local report_file="$2"           # full path to report
  local logfile="$3"               # slurm log file path
  local sample_list="$4"           # newline-separated sample IDs

  if [[ ! -f "$SAMPLESHEET" ]]; then
    echo "ERROR: Samplesheet not found: $SAMPLESHEET"
    exit 1
  fi
  if [[ ! -f "$PARAMS_JSON" ]]; then
    echo "ERROR: Params JSON not found: $PARAMS_JSON"
    exit 1
  fi

  local metadata_path
  metadata_path="$(get_metadata_path_from_json "$PARAMS_JSON")"
  if [[ -z "$metadata_path" ]]; then
    echo "ERROR: Could not read metadata path from params JSON: $PARAMS_JSON"
    echo "Look for a key named \"metadata\" in that JSON."
    exit 1
  fi
  if [[ ! -f "$metadata_path" ]]; then
    echo "ERROR: Metadata file not found at path read from params JSON:"
    echo "  $metadata_path"
    exit 1
  fi

  local ids_tmp ss_removed_tmp md_removed_tmp ss_new_tmp md_new_tmp
  ids_tmp="$(mktemp)"
  ss_removed_tmp="$(mktemp)"
  md_removed_tmp="$(mktemp)"
  ss_new_tmp="$(mktemp)"
  md_new_tmp="$(mktemp)"

  cleanup_local() {
    rm -f "$ids_tmp" "$ss_removed_tmp" "$md_removed_tmp" "$ss_new_tmp" "$md_new_tmp" 2>/dev/null || true
  }
  trap cleanup_local RETURN

  echo "$sample_list" > "$ids_tmp"

  # Backups
  backup_file "$SAMPLESHEET"
  backup_file "$metadata_path"

  # Filter samplesheet + metadata
  filter_tsv_by_first_col_remove_ids "$SAMPLESHEET" "$ids_tmp" "$ss_new_tmp" "$ss_removed_tmp"
  filter_tsv_by_first_col_remove_ids "$metadata_path" "$ids_tmp" "$md_new_tmp" "$md_removed_tmp"

  # Overwrite originals
  cp -f "$ss_new_tmp" "$SAMPLESHEET"
  cp -f "$md_new_tmp" "$metadata_path"

  # Write report
  {
    echo "Project: $PROJECT_NAME"
    echo "Date: $(date)"
    echo "Reason: $reason_label"
    echo ""
    echo "Samples removed (from SLURM log $logfile):"
    echo "$sample_list"
    echo ""
    echo "---- Removed rows from samplesheet: $SAMPLESHEET ----"
    if [[ -s "$ss_removed_tmp" ]]; then
      cat "$ss_removed_tmp"
    else
      echo "[None matched / none removed]"
    fi
    echo ""
    echo "---- Removed rows from metadata: $metadata_path ----"
    if [[ -s "$md_removed_tmp" ]]; then
      cat "$md_removed_tmp"
    else
      echo "[None matched / none removed]"
    fi
    echo ""
    echo "NOTE: Backups were created next to edited files with suffix .bak.YYYYMMDD_HHMMSS"
  } > "$report_file"

  echo ""
  echo "Done. Wrote report to:"
  echo "  $report_file"
  echo ""
}

# -----------------------------
# 1) Ask if they expect phyloseq
# -----------------------------
EXPECT_PHYLOSEQ="$(prompt_yn "Do you expect a phyloseq object (dada2_phyloseq.rds) to be produced?" "yes")"

SUCCESS="no"
if [[ "$EXPECT_PHYLOSEQ" == "yes" ]]; then
  [[ -f "$PHYLOSEQ_RDS" ]] && SUCCESS="yes"
else
  [[ -f "$ASV_FASTA" ]] && SUCCESS="yes"
fi

if [[ "$SUCCESS" == "yes" ]]; then
  echo "Run likely successful, should be safe to proceed to next module."
  exit 0
fi

echo "Run likely unsuccessful based on the expected output file check."

# -----------------------------
# 2) Ask for job ID and locate log
# -----------------------------
echo "Enter the SLURM job ID to inspect logs:"
read -r JOBID
JOBID="$(echo "$JOBID" | tr -d '[:space:]')"

if [[ -z "$JOBID" ]]; then
  echo "ERROR: No job ID provided."
  exit 1
fi

LOGFILE="$(find_slurm_out_for_job "$JOBID")"
if [[ -z "$LOGFILE" ]]; then
  echo "ERROR: Could not find a .out file in:"
  echo "  $LOGDIR"
  echo "containing job ID: $JOBID"
  exit 1
fi

echo "Using SLURM out log: $LOGFILE"

# -----------------------------
# 3) Scan for BOTH failure blocks
# -----------------------------
CUTADAPT_FAILED="$(extract_samples_between_markers "$LOGFILE" "$CUTADAPT_START" "$CUTADAPT_END" || true)"
DADA2_FAILED="$(extract_samples_between_markers "$LOGFILE" "$DADA2_START" "$DADA2_END" || true)"

if [[ -z "$CUTADAPT_FAILED" && -z "$DADA2_FAILED" ]]; then
  echo "Could not locate cutadapt or DADA2 'too few reads' sample blocks in the SLURM log."
  echo "Please check your SLURM logs for other run errors to see why the pipeline may not have succeeded."
  exit 0
fi

# -----------------------------
# 4) Present and optionally remove (separately)
# -----------------------------
if [[ -n "$CUTADAPT_FAILED" ]]; then
  echo ""
  echo "Samples with too few reads (<1) after trimming with cutadapt:"
  echo "$CUTADAPT_FAILED" | paste -sd ", " -
  echo ""
  if [[ "$(prompt_yn "Remove these cutadapt-failed samples from samplesheet + metadata?" "no")" == "yes" ]]; then
    remove_samples_workflow \
      "Failed trimming (too few reads after cutadapt trimming)" \
      "$REMOVED_DIR/Samples_Removed_Failed_Trimming.txt" \
      "$LOGFILE" \
      "$CUTADAPT_FAILED"
  else
    echo "Skipped removal for cutadapt-failed samples."
  fi
fi

if [[ -n "$DADA2_FAILED" ]]; then
  echo ""
  echo "Samples with too few reads (<1) after quality filtering with DADA2:"
  echo "$DADA2_FAILED" | paste -sd ", " -
  echo ""
  if [[ "$(prompt_yn "Remove these DADA2 filter-failed samples from samplesheet + metadata?" "no")" == "yes" ]]; then
    remove_samples_workflow \
      "Failed filtering (too few reads after DADA2 quality filtering)" \
      "$REMOVED_DIR/Samples_Removed_Failed_Filtering.txt" \
      "$LOGFILE" \
      "$DADA2_FAILED"
  else
    echo "Skipped removal for DADA2-failed samples."
  fi
fi

echo ""
echo "All done."
echo "If you removed samples, please rerun the nf-core/ampliseq pipeline step."