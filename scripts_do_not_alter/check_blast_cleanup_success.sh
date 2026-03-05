#!/usr/bin/env bash
# check_blast_cleanup_success.sh
#
# Checks whether submit_blast_cleanup.sh (NCBI taxonomy / BLAST cleanup) likely succeeded
# by verifying expected output files exist in the project's BLAST folder.

set -euo pipefail

# -----------------------------
# Get project name
# -----------------------------
PROJECT_NAME_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

if [[ ! -f "$PROJECT_NAME_FILE" ]]; then
  echo "ERROR: Project name file does not exist: $PROJECT_NAME_FILE"
  exit 1
fi

PROJECT_NAME="$(cat "$PROJECT_NAME_FILE")"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: Project name file is empty: $PROJECT_NAME_FILE"
  exit 1
fi

BASE="/group/ajfingergrp/Metabarcoding/Project_Runs/${PROJECT_NAME}"
BLAST_DIR="${BASE}/output/BLAST"

if [[ ! -d "$BLAST_DIR" ]]; then
  echo "ERROR: BLAST directory not found:"
  echo "  $BLAST_DIR"
  exit 1
fi

# -----------------------------
# Expected outputs
# -----------------------------
declare -a FILES=(
  "${PROJECT_NAME}_ncbi_taxon_rank_cache.tsv"
  "${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.tsv"
  "${PROJECT_NAME}_final_LCTR_taxonomy.tsv"
  "${PROJECT_NAME}_best_taxa_per_ASV.tsv"
  "${PROJECT_NAME}_blast_taxonomy_merged.tsv"
  "${PROJECT_NAME}_ncbi_taxonomy_results.tsv"
)

echo "----------------------------------------"
echo "Project:   $PROJECT_NAME"
echo "BLAST dir: $BLAST_DIR"
echo "----------------------------------------"

missing=0
empty=0

for f in "${FILES[@]}"; do
  path="${BLAST_DIR}/${f}"

  if [[ ! -f "$path" ]]; then
    echo "MISSING: $f"
    missing=1
  elif [[ ! -s "$path" ]]; then
    echo "EMPTY:   $f"
    empty=1
  else
    echo "FOUND:   $f"
  fi
done

echo "----------------------------------------"

if [[ "$missing" -eq 0 && "$empty" -eq 0 ]]; then
  echo "GOOD: All expected BLAST cleanup outputs are present and non-empty."
  echo "The submit_blast_cleanup.sh run was likely successful."
  exit 0
fi

if [[ "$missing" -eq 0 && "$empty" -eq 1 ]]; then
  echo "WARN: All expected files exist, but one or more are empty."
  echo "The run may have completed but produced no results (or failed partway)."
  echo "Check SLURM logs in:"
  echo "  /group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
  exit 1
fi

echo "ERROR: One or more expected output files are missing."
echo "The run was likely unsuccessful or has not finished."
echo "Check SLURM logs in:"
echo "  /group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
exit 1