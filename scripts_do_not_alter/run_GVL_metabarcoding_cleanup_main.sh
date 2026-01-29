#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Config
# ----------------------------
ENV_PREFIX_decon="/group/ajfingergrp/Metabarcoding/conda_envs/decontam_env"

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
ENV_DIR_decon="$(dirname "$ENV_PREFIX_decon")"
mkdir -p "$ENV_DIR_decon" || { echo "ERROR: cannot create $ENV_DIR_decon (permissions?)" >&2; exit 1; }

if [[ ! -d "$ENV_PREFIX_decon/conda-meta" ]]; then
  LOCKFILE_decon="$ENV_DIR_decon/review_env.lock"
  exec 9>"$LOCKFILE_decon"
  flock -n 9 || {
    echo "Conda env creation already in progress by another user."
    echo "If this seems stuck, check/remove: $LOCKFILE_decon"
    exit 0
  }

  echo "Creating conda env at: $ENV_PREFIX_decon"
  mamba create -y -p "$ENV_PREFIX_decon" \
    -c conda-forge -c bioconda \
    r-base=4.3 r-dplyr r-openxlsx r-stringr r-readxl r-here r-writexl bioconductor-phyloseq
else
  echo "Conda env already exists at: $ENV_PREFIX_decon"
fi


# ----------------------------
# Activate env
# ----------------------------
conda activate "$ENV_PREFIX_decon"

# ----------------------------
# Export env vars
# ----------------------------
PROJECT_NAME="$(cat "$HOME/Metabarcoding/current_project_name.txt")"
export PROJECT_NAME

export PROJECT_DIR="$HOME/Metabarcoding/$PROJECT_NAME"
export REVIEW_OUTDIR="$PROJECT_DIR/output/BLAST/Review"
export SCRIPT_DIR="$PROJECT_DIR/scripts/${PROJECT_NAME}_R_ASV_cleanup_scripts"
export ASV_CLEANUP_DIR="$PROJECT_DIR/output/ASV_cleanup_output"
export PHYLOSEQ_RDS_REVIEWED="$REVIEW_OUTDIR/phyloseq_${PROJECT_NAME}_UPDATED_reviewed_taxonomy.rds"

# ----------------------------
# Run
# ----------------------------
SCRIPT_PATH="$SCRIPT_DIR/${PROJECT_NAME}_GVL_metabarcoding_cleanup_main.R"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: R script not found: $SCRIPT_PATH" >&2
  exit 1
fi

echo "Running decontaminations script for project: ${PROJECT_NAME}"
Rscript "$SCRIPT_PATH"
