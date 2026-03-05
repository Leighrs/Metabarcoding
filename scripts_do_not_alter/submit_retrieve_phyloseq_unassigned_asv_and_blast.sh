#!/bin/bash
set -euo pipefail

PHYLOSEQ_SBATCH="$HOME/Metabarcoding/scripts_do_not_alter/retrieve_phyloseq_unassigned_ASVs_and_blast.slurm"
BLAST_ASV_SBATCH="$HOME/Metabarcoding/scripts_do_not_alter/blast_asv.slurm"

LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
mkdir -p "$LOGDIR"

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

echo "Detected project: $PROJECT_NAME"
echo ""

# ------------------------------------------------------------
# Prompt: choose workflow
# ------------------------------------------------------------
DEFAULT_CHOICE="2"

echo "What do you want to do?"
echo "  1A) Extract AND BLAST unassigned/incomplete assigned ASVs from phyloseq object."
echo "  1B) Extract unassigned/incomplete assigned ASVs from phyloseq object (NO BLAST)."
echo "  2) BLAST ALL ASVs (use ...output/dada2/ASV_seqs.fasta)."
echo "Enter 1A, 1B, or 2 [default: $DEFAULT_CHOICE]:"

read -r USER_CHOICE
RAW_CHOICE="${USER_CHOICE:-$DEFAULT_CHOICE}"

# Normalize input (remove spaces, uppercase)
CHOICE="$(echo "$RAW_CHOICE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"

FORCE_NO_BLAST="no"

case "$CHOICE" in
  1A)
    SBATCH_SCRIPT="$PHYLOSEQ_SBATCH"
    echo "Selected: phyloseq → unassigned FASTA (BLAST optional)"
    ;;
  1B)
    SBATCH_SCRIPT="$PHYLOSEQ_SBATCH"
    FORCE_NO_BLAST="yes"
    echo "Selected: phyloseq → unassigned FASTA ONLY (no BLAST)"
    ;;
  2)
    SBATCH_SCRIPT="$BLAST_ASV_SBATCH"
    echo "Selected: BLAST all ASVs"
    ;;
  *)
    echo "ERROR: Please enter 1A, 1B, or 2."
    exit 1
    ;;
esac

if [[ ! -f "$SBATCH_SCRIPT" ]]; then
  echo "ERROR: SLURM script not found: $SBATCH_SCRIPT"
  exit 1
fi

echo ""

# ------------------------------------------------------------
# BLAST decision (no prompt for 1A, 1B, or 2)
# ------------------------------------------------------------

if [[ "$CHOICE" == "1A" ]]; then
  RUN_BLAST="yes"
  echo "Option 1A selected → forcing BLAST (RUN_BLAST=yes)."
elif [[ "$CHOICE" == "1B" ]]; then
  RUN_BLAST="no"
  echo "Option 1B selected → BLAST disabled (RUN_BLAST=no)."
elif [[ "$CHOICE" == "2" ]]; then
  RUN_BLAST="yes"
  echo "Option 2 selected → forcing BLAST (RUN_BLAST=yes)."
else
  # Should never happen due to earlier case statement, but safe fallback:
  RUN_BLAST="no"
fi
# ------------------------------------------------------------
# Prompt: BLAST settings (only if RUN_BLAST=yes)
# ------------------------------------------------------------
DEFAULT_PERC_ID=97
DEFAULT_MAX_TARGET=5

BLAST_PERC_IDENTITY="$DEFAULT_PERC_ID"
BLAST_MAX_TARGET_SEQS="$DEFAULT_MAX_TARGET"

if [[ "$RUN_BLAST" == "yes" ]]; then
  echo "Enter BLAST percent identity threshold [default: $DEFAULT_PERC_ID]:"
  read -r USER_PERC_ID

  echo "Enter BLAST max target sequences [default: $DEFAULT_MAX_TARGET]:"
  read -r USER_MAX_TARGET

  BLAST_PERC_IDENTITY="${USER_PERC_ID:-$DEFAULT_PERC_ID}"
  BLAST_MAX_TARGET_SEQS="${USER_MAX_TARGET:-$DEFAULT_MAX_TARGET}"

  if ! [[ "$BLAST_PERC_IDENTITY" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Percent identity must be an integer."
    exit 1
  fi

  if ! [[ "$BLAST_MAX_TARGET_SEQS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Max target sequences must be an integer."
    exit 1
  fi
fi

echo ""
echo "Submitting job with:"
echo "  Script               = $SBATCH_SCRIPT"
echo "  PROJECT_NAME         = $PROJECT_NAME"
echo "  RUN_BLAST            = $RUN_BLAST"
echo "  BLAST_PERC_IDENTITY  = $BLAST_PERC_IDENTITY"
echo "  BLAST_MAX_TARGET     = $BLAST_MAX_TARGET_SEQS"
echo ""

sbatch \
  --chdir="$HOME" \
  --output="$LOGDIR/%x_%j.out" \
  --error="$LOGDIR/%x_%j.err" \
  --export=ALL,PROJECT_NAME="$PROJECT_NAME",CHOICE="$CHOICE",RUN_BLAST="$RUN_BLAST",BLAST_PERC_IDENTITY="$BLAST_PERC_IDENTITY",BLAST_MAX_TARGET_SEQS="$BLAST_MAX_TARGET_SEQS" \
  "$SBATCH_SCRIPT"