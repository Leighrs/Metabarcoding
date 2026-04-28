#!/usr/bin/env bash
set -euo pipefail

export TZ=UTC

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

# Export asvs and metadata (if a phyloseq object needs to be created):
export ASV_FASTA="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/ASV_seqs.fasta"
export METADATA_TSV=$(ls \
  "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/input/"*metadata*.txt \
  "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/input/"*metadata*.tsv \
  2>/dev/null | head -n 1)

if [[ -z "${METADATA_TSV:-}" ]]; then
  echo "ERROR: No metadata file found matching *metadata*.txt or *metadata*.tsv" >&2
  exit 1
fi

# Export DADA2 table (if a phyloseq object needs to be created):
export ASV_TABLE_TSV="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/DADA2_table.tsv"

# Export project directory:
export BASE_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs"
export PROJECT_DIR="${BASE_DIR}/${PROJECT_NAME}"

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
SCRIPT_PATH="/group/ajfingergrp/Metabarcoding/GVL_ampliseq_scripts/scripts_do_not_alter/review_and_update_phyloseq.R"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "ERROR: R script not found: $SCRIPT_PATH" >&2
  exit 1
fi

echo "Running review/update script for project: ${PROJECT_NAME}"

# ----------------------------
# Choose run mode
# ----------------------------
echo "Select run mode for review/update:"
echo "  1) first      - create review workbook for the first time."
echo "  2) second     - read edited workbook and update taxonomic assignments."
echo "  3) reprocess  - create review workbook from scratch and overwrite existing file."
read -rp "Enter choice [1/2/3]: " RUN_CHOICE

case "$RUN_CHOICE" in
  1|first|FIRST)
    export REVIEW_RUN_MODE="first"
    ;;
  2|second|SECOND)
    export REVIEW_RUN_MODE="second"
    ;;
  3|reprocess|REPROCESS|rebuild|overwrite)
    export REVIEW_RUN_MODE="reprocess"
    ;;
  *)
    echo "ERROR: Invalid choice. Use 1, 2, or 3." >&2
    exit 1
    ;;
esac

echo "Selected mode: $REVIEW_RUN_MODE"
echo

# ----------------------------
# Prompt user for extra ranks
# ----------------------------
export EXTRA_TAX_RANKS=""

if [[ "$REVIEW_RUN_MODE" == "first" || "$REVIEW_RUN_MODE" == "reprocess" ]]; then
  if [[ -f "$PHYLOSEQ_RDS" ]]; then
    echo
    echo "Existing phyloseq object detected:"
    echo "  $PHYLOSEQ_RDS"
    echo

    echo "Current tax_table ranks:"
    TZ=UTC Rscript -e "
      suppressPackageStartupMessages(library(phyloseq))
      ps <- readRDS(Sys.getenv('PHYLOSEQ_RDS'))
      cat(paste(colnames(as(tax_table(ps), 'matrix')), collapse=', '), '\n')
    "

    echo
    read -rp "Add any extra taxa/rank columns to preserve/show in review sheet? Enter comma-separated names or leave blank: " EXTRA_TAX_RANKS
    export EXTRA_TAX_RANKS
  fi
fi

# ----------------------------
# Optional auto-treatment settings
# ----------------------------

# Default values (used for second mode)
export TREAT_BACTERIA="FALSE"
export TREAT_FUNGI="FALSE"
export TREAT_PLANTS="FALSE"

if [[ "$REVIEW_RUN_MODE" == "first" || "$REVIEW_RUN_MODE" == "reprocess" ]]; then
  echo "Enable automatic treatment for specific groups?"
  echo "  (y = yes, n = no)"
  echo

  read -rp "Treat bacterial-like assignments automatically? (y/n): " BACT_CHOICE
  read -rp "Treat fungal-like assignments automatically? (y/n): " FUNG_CHOICE
  read -rp "Treat plant-like assignments automatically? (y/n): " PLANT_CHOICE

  case "${BACT_CHOICE,,}" in
    y|yes) export TREAT_BACTERIA="TRUE" ;;
    n|no|"") export TREAT_BACTERIA="FALSE" ;;
    *) echo "ERROR: invalid bacteria choice. Use y or n." >&2; exit 1 ;;
  esac

  case "${FUNG_CHOICE,,}" in
    y|yes) export TREAT_FUNGI="TRUE" ;;
    n|no|"") export TREAT_FUNGI="FALSE" ;;
    *) echo "ERROR: invalid fungi choice. Use y or n." >&2; exit 1 ;;
  esac

  case "${PLANT_CHOICE,,}" in
    y|yes) export TREAT_PLANTS="TRUE" ;;
    n|no|"") export TREAT_PLANTS="FALSE" ;;
    *) echo "ERROR: invalid plant choice. Use y or n." >&2; exit 1 ;;
  esac

  echo
  echo "Auto-treatment settings:"
  echo "  Bacteria: $TREAT_BACTERIA"
  echo "  Fungi:    $TREAT_FUNGI"
  echo "  Plants:   $TREAT_PLANTS"
  echo

fi

Rscript "$SCRIPT_PATH"