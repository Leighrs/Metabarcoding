#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=high
#SBATCH --job-name=blast_asv
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:30:00
#SBATCH --output=Metabarcoding/Logs_archive/ncbi_taxa_%j.out
#SBATCH --error=Metabarcoding/Logs_archive/ncbi_taxa_%j.err

module load apptainer
echo "Job running on node: $(hostname)"

# ------------------------------------------------------------
# Read project name
# ------------------------------------------------------------
PROJECT_FILE="$HOME/Metabarcoding/current_project_name.txt"

if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "ERROR: Project name file does not exist: $PROJECT_FILE"
    exit 1
fi

PROJECT_NAME=$(cat "$PROJECT_FILE")

if [[ -z "$PROJECT_NAME" ]]; then
    echo "ERROR: Project name file is empty."
    exit 1
fi

echo "Detected project: $PROJECT_NAME"

# ------------------------------------------------------------
# Create BLAST output directory if missing
# ------------------------------------------------------------
BLAST_DIR="$HOME/Metabarcoding/$PROJECT_NAME/output/BLAST"

if [[ ! -d "$BLAST_DIR" ]]; then
    echo "BLAST directory not found — creating: $BLAST_DIR"
    mkdir -p "$BLAST_DIR"
else
    echo "BLAST directory exists: $BLAST_DIR"
fi

# ------------------------------------------------------------
# Ensure Apptainer container exists
# ------------------------------------------------------------
CONTAINER="$HOME/Metabarcoding/Containers/GVL_ncbi_taxonomy.sif"
CONTAINER_URL="oras://community.wave.seqera.io/library/biopython_pandas_python_tqdm:f7738f3fa810f52d"

if [[ ! -f "$CONTAINER" ]]; then
    echo "Container missing — downloading..."
    apptainer pull "$CONTAINER" "$CONTAINER_URL"
fi

# ------------------------------------------------------------
# Export variables for Python script
# ------------------------------------------------------------
export PROJECT_NAME
export BLAST_DIR

export INPUT_FILE="$BLAST_DIR/${PROJECT_NAME}_raw_blast_results.tsv"
export FASTA_FILE="$HOME/Metabarcoding/$PROJECT_NAME/output/dada2/ASV_seqs.fasta"

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
# Run Python inside container
# ------------------------------------------------------------
PYTHON_SCRIPT="$HOME/Metabarcoding/$PROJECT_NAME/scripts/${PROJECT_NAME}_ncbi_pipeline.py"

if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "ERROR: Python script not found: $PYTHON_SCRIPT"
    exit 1
fi

echo "Launching Apptainer + Python pipeline..."
apptainer exec "$CONTAINER" python3 "$PYTHON_SCRIPT"

echo "Done."
