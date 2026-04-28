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
PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "ERROR: No project defined."
    echo "Run setup_metabarcoding_directory.sh first."
    exit 1
fi

PROJECT_NAME="$(cat "$PROJECT_FILE")"
export PROJECT_NAME
echo "Running project: $PROJECT_NAME"

export PROJECT_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME"
export REVIEW_OUTDIR="$PROJECT_DIR/output/BLAST/Review"
export SCRIPT_DIR="/group/ajfingergrp/Metabarcoding/GVL_ampliseq_scripts/scripts_do_not_alter/R_ASV_cleanup_scripts"
export ASV_CLEANUP_DIR="$PROJECT_DIR/output/ASV_cleanup_output"
export PHYLOSEQ_RDS_REVIEWED="$REVIEW_OUTDIR/phyloseq_${PROJECT_NAME}_UPDATED_reviewed_taxonomy.rds"

# ----------------------------
# User parameter prompts
# ----------------------------

echo ""
echo "Configure ASV cleanup parameters (press Enter to use defaults)"
echo ""

# metadata column definitions
read -rp "Metadata column name indicating sample/control type [Default: Sample_or_Control]: " SAMPLE_TYPE_COL
SAMPLE_TYPE_COL=${SAMPLE_TYPE_COL:-Sample_or_Control}

read -rp "Metadata label type for biological samples [Default: Sample]: " SAMPLE_LABEL
SAMPLE_LABEL=${SAMPLE_LABEL:-Sample}

read -rp "Metadata label type for controls [Default: Control]: " CONTROL_LABEL
CONTROL_LABEL=${CONTROL_LABEL:-Control}

read -rp "Metadata column name assigning controls to samples [Default: Control_Assign]: " ASSIGNED_CONTROLS_COL
ASSIGNED_CONTROLS_COL=${ASSIGNED_CONTROLS_COL:-Control_Assign}

echo ""

# threshold parameters
read -rp "Sample ASV threshold [Default: 0.0005]: " SAMPLE_THRES
SAMPLE_THRES=${SAMPLE_THRES:-0.0005}

read -rp "Minimum sequencing depth threshold [Default: 0.0005]: " MIN_DEPTH_THRES
MIN_DEPTH_THRES=${MIN_DEPTH_THRES:-0.0005}

# export variables for R
export SAMPLE_TYPE_COL
export SAMPLE_LABEL
export CONTROL_LABEL
export ASSIGNED_CONTROLS_COL
export SAMPLE_THRES
export MIN_DEPTH_THRES

echo ""
echo "Using parameters:"
echo "  SAMPLE_TYPE_COL=$SAMPLE_TYPE_COL"
echo "  SAMPLE_LABEL=$SAMPLE_LABEL"
echo "  CONTROL_LABEL=$CONTROL_LABEL"
echo "  ASSIGNED_CONTROLS_COL=$ASSIGNED_CONTROLS_COL"
echo "  SAMPLE_THRES=$SAMPLE_THRES"
echo "  MIN_DEPTH_THRES=$MIN_DEPTH_THRES"
echo ""

# ----------------------------
# Run
# ----------------------------
SCRIPT_PATH="$SCRIPT_DIR/GVL_metabarcoding_cleanup_main.R"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: R script not found: $SCRIPT_PATH" >&2
  exit 1
fi

echo "Running decontaminations script for project: ${PROJECT_NAME}"
Rscript "$SCRIPT_PATH"
