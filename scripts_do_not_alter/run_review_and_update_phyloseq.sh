#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Config
# ----------------------------
ENV_PREFIX="/group/ajfingergrp/Metabarcoding/conda_envs/review_env"

# ----------------------------
# Load conda (Farm module system)
# ----------------------------
module load conda

if [[ -f "$(conda info --base)/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1090
  source "$(conda info --base)/etc/profile.d/conda.sh"
else
  echo "ERROR: Could not find conda.sh at: $(conda info --base)/etc/profile.d/conda.sh" >&2
  exit 1
fi

# ----------------------------
# Ensure mamba exists
# ----------------------------
if ! command -v mamba >/dev/null 2>&1; then
  echo "mamba not found; installing into base environment..."
  conda activate base
  conda install -y -n base -c conda-forge mamba
fi

# ----------------------------
# Create env if missing (with lock)
# ----------------------------
ENV_DIR="$(dirname "$ENV_PREFIX")"
mkdir -p "$ENV_DIR" || { echo "ERROR: cannot create $ENV_DIR (permissions?)" >&2; exit 1; }
LOCKFILE="$ENV_DIR/review_env.lock"

exec 9>"$LOCKFILE"
flock -n 9 || {
  echo "Conda env creation already in progress by another user."
  echo "If this seems stuck, check/remove: $LOCKFILE"
  exit 0
}

if [[ ! -d "$ENV_PREFIX/conda-meta" ]]; then
  echo "Creating conda env at: $ENV_PREFIX"
  mamba create -y -p "$ENV_PREFIX" \
    -c conda-forge -c bioconda \
    r-base=4.3 \
    r-dplyr \
    r-openxlsx \
    r-stringr \
    bioconductor-biostrings \
    bioconductor-phyloseq
else
  echo "Conda env already exists at: $ENV_PREFIX"
fi

# ----------------------------
# Activate env
# ----------------------------
conda activate "$ENV_PREFIX"

# ----------------------------
# Export env vars
# ----------------------------

# Export project name:
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
export PROJECT_NAME="$(cat "$PROJECT_NAME_FILE")"

echo "Detected project: $PROJECT_NAME"
echo ""

# Export metadata (if a phyloseq object needs to be created):
export METADATA_PATH=$(ls /group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/input/*metadata*.{txt,tsv} 2>/dev/null | head -n 1)

# Export asv fasta file and table (if a phyloseq object needs to be created):
export ASV_FASTA="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/ASV_seqs.fasta"
export ASV_TABLE_TSV="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/DADA2_table.tsv"

# Export project directory:
export PROJECT_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME"

# Export phyloseq object (for those who used a reference database):
export PHYLOSEQ_RDS="${PROJECT_DIR}/output/phyloseq/dada2_phyloseq.rds"

# Export path to review folder and create folder (this is where review sheet will be placed):
export REVIEW_OUTDIR="${PROJECT_DIR}/output/BLAST/Review"
mkdir -p "$REVIEW_OUTDIR"

# Export path to 
export BLAST_ALL_TSV="$PROJECT_DIR/output/BLAST/${PROJECT_NAME}_raw_blast_results.tsv"


# ---- Debug + safety checks (fail fast with useful info) ----

if [[ -z "${PROJECT_DIR}" ]]; then
  echo "ERROR: PROJECT_DIR is empty; cannot build paths." >&2
  exit 1
fi

if [[ ! -d "${PROJECT_DIR}/output/BLAST" ]]; then
  echo "ERROR: BLAST output directory not found: ${PROJECT_DIR}/output/BLAST" >&2
  ls -lh "${PROJECT_DIR}/output" || true
  exit 1
fi

if [[ ! -f "${BLAST_ALL_TSV}" ]]; then
  echo "ERROR: BLAST_ALL_TSV not found at: ${BLAST_ALL_TSV}" >&2
  echo "Here are files in ${PROJECT_DIR}/output/BLAST (to find the real name):" >&2
  ls -lh "${PROJECT_DIR}/output/BLAST" >&2 || true
  exit 1
fi



# ----------------------------
# Run
# ----------------------------
SCRIPT_PATH="$HOME/Metabarcoding/scripts_do_not_alter/review_and_update_phyloseq.R"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: R script not found: $SCRIPT_PATH" >&2
  exit 1
fi

echo "Running review/update script for project: ${PROJECT_NAME}"
Rscript "$SCRIPT_PATH"
