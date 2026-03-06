#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=blast_cleanup
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:30:00

set -euo pipefail


echo "Job running on node: $(hostname)"

# ----------------------------
# Config
# ----------------------------
ENV_PREFIX_ncbi="/group/ajfingergrp/Metabarcoding/conda_envs/ncbi_env"

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
ENV_DIR_ncbi="$(dirname "$ENV_PREFIX_ncbi")"
mkdir -p "$ENV_DIR_ncbi" || { echo "ERROR: cannot create $ENV_DIR_ncbi (permissions?)" >&2; exit 1; }

if [[ ! -d "$ENV_PREFIX_ncbi/conda-meta" ]]; then
  LOCKFILE_ncbi="$ENV_DIR_ncbi/ncbi_env.lock"
  exec 9>"$LOCKFILE_ncbi"
  flock -n 9 || {
    echo "Conda env creation already in progress by another user."
    echo "If this seems stuck, check/remove: $LOCKFILE_ncbi"
    exit 0
  }

  echo "Creating conda env at: $ENV_PREFIX_ncbi"
  mamba create -y -p "$ENV_PREFIX_ncbi" \
    -c conda-forge -c bioconda \
    python \
    biopython \
    pandas \
    tqdm
else
  echo "Conda env already exists at: $ENV_PREFIX_ncbi"
fi


# ----------------------------
# Activate env
# ----------------------------
conda activate "$ENV_PREFIX_ncbi"


# ------------------------------------------------------------
# Read project name
# ------------------------------------------------------------
PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "ERROR: No project defined."
    echo "Run setup_metabarcoding_directory.sh first."
    exit 1
fi

PROJECT_NAME=$(cat "$PROJECT_FILE")
echo "Running project: $PROJECT_NAME"

# ------------------------------------------------------------
# Create BLAST output directory if missing
# ------------------------------------------------------------

BLAST_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST"

if [[ ! -d "$BLAST_DIR" ]]; then
    echo "BLAST directory not found — creating: $BLAST_DIR"
    mkdir -p "$BLAST_DIR"
else
    echo "BLAST directory exists: $BLAST_DIR"
fi

# ------------------------------------------------------------
# Export variables for Python script
# ------------------------------------------------------------
export PROJECT_NAME
export BLAST_DIR

export INPUT_FILE="$BLAST_DIR/${PROJECT_NAME}_raw_blast_results.tsv"
export FASTA_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/dada2/ASV_seqs.fasta"

export OUTPUT_FILE="$BLAST_DIR/${PROJECT_NAME}_ncbi_taxonomy_results.tsv"
export MERGED_OUTPUT="$BLAST_DIR/${PROJECT_NAME}_blast_taxonomy_merged.tsv"
export BEST_OUTPUT="$BLAST_DIR/${PROJECT_NAME}_best_taxa_per_ASV.tsv"
export LCTR_OUTPUT="$BLAST_DIR/${PROJECT_NAME}_final_LCTR_taxonomy.tsv"
export LCTR_RANK_OUTPUT="$BLAST_DIR/${PROJECT_NAME}_final_LCTR_taxonomy_with_ranks.tsv"
export RANK_CACHE_FILE="$BLAST_DIR/${PROJECT_NAME}_ncbi_taxon_rank_cache.tsv"

echo "Input BLAST file: $INPUT_FILE"
echo "ASV FASTA file:  $FASTA_FILE"
echo "Output directory: $BLAST_DIR"

# Basic sanity checks before launching container
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "ERROR: BLAST results file not found: $INPUT_FILE"
    exit 1
fi

if [[ ! -f "$FASTA_FILE" ]]; then
    echo "ERROR: ASV FASTA file not found: $FASTA_FILE"
    exit 1
fi

# ------------------------------------------------------------
# Run Python script
# ------------------------------------------------------------
PIPELINE_DIR="$HOME/Metabarcoding/scripts_do_not_alter"
PYTHON_SCRIPT="$PIPELINE_DIR/blast_cleanup.py"
PYTHON_BIN="$ENV_PREFIX_ncbi/bin/python"

echo "HOME=$HOME"
echo "PIPELINE_DIR=$PIPELINE_DIR"
echo "PYTHON_SCRIPT=$PYTHON_SCRIPT"
echo "PYTHON_BIN=$PYTHON_BIN"

ls -ld "$PIPELINE_DIR" || true
ls -l "$PIPELINE_DIR" | grep blast || true
stat "$PYTHON_SCRIPT" || true
stat "$PYTHON_BIN" || true

if [[ ! -e "$PYTHON_SCRIPT" ]]; then
    echo "ERROR: Python script path does not exist: $PYTHON_SCRIPT"
    exit 1
fi

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "ERROR: Path exists but is not a regular file: $PYTHON_SCRIPT"
    exit 1
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "ERROR: Python interpreter not executable: $PYTHON_BIN"
    exit 1
fi

echo "Running Python pipeline..."
"$PYTHON_BIN" "$PYTHON_SCRIPT"

echo "Done."
