#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Config
# ----------------------------
ENV_PREFIX="/group/ajfingergrp/Metabarcoding_containers_conda/conda_envs/review_env"

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
PROJECT_NAME="$(cat "$HOME/Metabarcoding/current_project_name.txt")"
export PROJECT_NAME

export PROJECT_DIR="$HOME/Metabarcoding/$PROJECT_NAME"
export PHYLOSEQ_RDS="$PROJECT_DIR/output/phyloseq/dada2_phyloseq.rds"
export REVIEW_OUTDIR="$PROJECT_DIR/output/BLAST/Review"

# ----------------------------
# Run
# ----------------------------
SCRIPT_PATH="$PROJECT_DIR/scripts/${PROJECT_NAME}_review_and_update_phyloseq.R"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: R script not found: $SCRIPT_PATH" >&2
  exit 1
fi

echo "Running review/update script for project: ${PROJECT_NAME}"
Rscript "$SCRIPT_PATH"
