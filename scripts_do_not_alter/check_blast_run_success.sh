#!/usr/bin/env bash
# check_blast_run_success.sh
#
# Prompts user for workflow choice (1A, 1B, or 2)
# and checks whether expected output files exist.

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
  echo "ERROR: Project name file is empty."
  exit 1
fi

BASE="/group/ajfingergrp/Metabarcoding/Project_Runs/${PROJECT_NAME}"
[[ -d "$BASE" ]] || { echo "ERROR: Project directory not found: $BASE"; exit 1; }

FASTA_UNASSIGNED="${BASE}/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta"
BLAST_RESULTS="${BASE}/output/BLAST/${PROJECT_NAME}_raw_blast_results.tsv"

# -----------------------------
# Helper for FASTA status
# -----------------------------
report_fasta_status() {
  local fasta="$1"

  if [[ -f "$fasta" ]]; then
    if [[ -s "$fasta" ]]; then
      echo "GOOD: Found FASTA (non-empty):"
      echo "  $fasta"
      return 0
    else
      echo "GOOD: FASTA file exists but is empty:"
      echo "  $fasta"
      echo "INFO: You had no unassigned ASVs."
      echo "      All ASVs were likely assigned using the reference database in nf-core/ampliseq."
      return 0
    fi
  else
    echo "ERROR: FASTA file not found:"
    echo "  $fasta"
    return 1
  fi
}

echo "----------------------------------------"
echo "Project: $PROJECT_NAME"
echo "----------------------------------------"
echo ""
echo "What workflow did you run?"
echo "  1A) Retrieve + BLAST unassigned ASVs"
echo "  1B) Retrieve unassigned ASVs (NO BLAST)"
echo "  2)  BLAST ALL ASVs"
echo ""

read -r USER_CHOICE
CHOICE="$(echo "$USER_CHOICE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"

echo ""

case "$CHOICE" in

  1B)
    echo "Checking for unassigned ASV FASTA..."
    if report_fasta_status "$FASTA_UNASSIGNED"; then
      echo "Run was likely successful."
      exit 0
    else
      echo "Run likely failed or has not finished."
      exit 1
    fi
    ;;

    1A)
    echo "Checking for FASTA + BLAST results..."
    missing=0

    if [[ -f "$FASTA_UNASSIGNED" ]]; then
      if [[ -s "$FASTA_UNASSIGNED" ]]; then
        echo "GOOD: Found FASTA (non-empty):"
        echo "  $FASTA_UNASSIGNED"

        # FASTA has sequences ? BLAST results must be non-empty
        if [[ -s "$BLAST_RESULTS" ]]; then
          echo "GOOD: Found BLAST results (non-empty):"
          echo "  $BLAST_RESULTS"
          echo "Run was likely successful."
          exit 0
        elif [[ -f "$BLAST_RESULTS" ]]; then
          echo "ERROR: BLAST results file exists but is empty:"
          echo "  $BLAST_RESULTS"
          echo "Run likely unsuccessful. Check SLURM logs."
          exit 1
        else
          echo "ERROR: BLAST results file not found:"
          echo "  $BLAST_RESULTS"
          echo "Run likely unsuccessful. Check SLURM logs."
          exit 1
        fi

      else
        # FASTA exists but empty
        echo "GOOD: FASTA file exists but is empty:"
        echo "  $FASTA_UNASSIGNED"
        echo "INFO: No unassigned ASVs were found."
        echo "      All ASVs were likely assigned by nf-core/ampliseq."
        echo "BLAST results being empty is expected."
        echo "Run was likely successful."
        exit 0
      fi
    else
      echo "ERROR: FASTA file not found:"
      echo "  $FASTA_UNASSIGNED"
      echo "Run likely unsuccessful. Check SLURM logs."
      exit 1
    fi
    ;;

  2)
    echo "Checking for BLAST results..."
    if [[ -s "$BLAST_RESULTS" ]]; then
      echo "GOOD: Found BLAST results (non-empty):"
      echo "  $BLAST_RESULTS"
      echo "Run was likely successful."
      exit 0
    elif [[ -f "$BLAST_RESULTS" ]]; then
      echo "ERROR: BLAST results file exists but is empty:"
      echo "  $BLAST_RESULTS"
      echo "Run likely failed or produced no output. Check SLURM logs."
      exit 1
    else
      echo "ERROR: BLAST results not found:"
      echo "  $BLAST_RESULTS"
      echo "Run likely failed or has not finished."
      exit 1
    fi
    ;;

  *)
    echo "ERROR: Please enter 1A, 1B, or 2."
    exit 1
    ;;

esac