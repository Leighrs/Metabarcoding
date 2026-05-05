#!/bin/bash
set -euo pipefail

# ----------------------------
# Project Path Setup
# ----------------------------
PROJECT_NAME_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

if [[ ! -f "$PROJECT_NAME_FILE" ]]; then
    echo "ERROR: Project name file not found for $USER at $PROJECT_NAME_FILE" >&2
    exit 1
fi

PROJECT_NAME=$(cat "$PROJECT_NAME_FILE")
RAW_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/fastq"
CLEAN_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/fastq_cleaned"
ADAPTER="AGATGTGTATAAGAGACAG"

# ----------------------------
# Conda Configuration
# ----------------------------
ENV_PREFIX_CUTADAPT="/group/ajfingergrp/Metabarcoding/conda_envs/cutadapt_env"

# Load conda (Farm module system)
module load conda

if [[ -f "$(conda info --base)/etc/profile.d/conda.sh" ]]; then
  source "$(conda info --base)/etc/profile.d/conda.sh"
else
  echo "ERROR: Could not find conda.sh" >&2
  exit 1
fi

# Ensure mamba exists for faster env creation
if ! command -v mamba >/dev/null 2>&1; then
  conda activate base
  conda install -y -n base -c conda-forge mamba
fi

# ----------------------------
# Create/Verify Environment
# ----------------------------
ENV_DIR_BASE="$(dirname "$ENV_PREFIX_CUTADAPT")"
mkdir -p "$ENV_DIR_BASE"

if [[ ! -d "$ENV_PREFIX_CUTADAPT/conda-meta" ]]; then
  LOCKFILE="$ENV_DIR_BASE/cutadapt_env.lock"
  # Use a file descriptor for locking to prevent race conditions
  exec 9>"$LOCKFILE"
  if ! flock -n 9; then
    echo "Conda env creation in progress by another user. Waiting..."
    flock 9
  fi

  echo "Creating cutadapt environment at: $ENV_PREFIX_CUTADAPT"
  mamba create -y -p "$ENV_PREFIX_CUTADAPT" \
    -c conda-forge -c bioconda \
    cutadapt \
    pigz
else
  echo "Using existing environment: $ENV_PREFIX_CUTADAPT"
fi

conda activate "$ENV_PREFIX_CUTADAPT"

# ----------------------------
# Processing Loop
# ----------------------------
mkdir -p "$CLEAN_DIR"

echo "--------------------------------------------------------"
echo "Cleaning Project: $PROJECT_NAME"
echo "Target Directory: $CLEAN_DIR"
echo "--------------------------------------------------------"

# Changed wildcard to match _R1.fastq.gz (without requiring _001)
for r1 in "$RAW_DIR"/*_R1.fastq.gz; do
    [ -e "$r1" ] || { echo "No R1 files found in $RAW_DIR"; exit 1; }
    
    # Updated substitution to match _R1. instead of _R1_
    r2="${r1/_R1./_R2.}"
    
    out_r1="$CLEAN_DIR/$(basename "$r1")"
    out_r2="$CLEAN_DIR/$(basename "$r2")"
    
    # Safety check: Ensure R1 and R2 are different
    if [[ "$out_r1" == "$out_r2" ]]; then
        echo "ERROR: Filename substitution failed. R1 and R2 are the same: $(basename "$r1")"
        exit 1
    fi
    
    echo "Processing: $(basename "$r1") and $(basename "$r2")"

    cutadapt \
        -j 0 \
        -g "$ADAPTER" -a "$ADAPTER" \
        -G "$ADAPTER" -A "$ADAPTER" \
        --overlap 10 \
        --times 2 \
        --pair-filter=any \
        --minimum-length 50 \
        -o "$out_r1" -p "$out_r2" \
        "$r1" "$r2" > "$CLEAN_DIR/$(basename "$r1").cutadapt.log"
done