#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=blast_asv
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=48:00:00

set -euo pipefail

###############################################
# DO NOT EDIT ANYTHING ELSE unless you know what you are doing. :)
# The script automatically finds the newest NCBI database folder and pulls in scripths.
###############################################

# -----------------------------
# Group location for shared containers
# -----------------------------
GROUP_CONTAINER_DIR="/group/ajfingergrp/Metabarcoding/Containers"
mkdir -p "$GROUP_CONTAINER_DIR"

# -----------------------------
# Make sure the log directory exists.
# -----------------------------
mkdir -p "/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"

# ------------------------------------------------------------
# Read project name
# ------------------------------------------------------------
if [[ -n "${PROJECT_NAME:-}" ]]; then
    echo "Detected project (from exported variable): $PROJECT_NAME"
else
    PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

    if [[ ! -f "$PROJECT_FILE" ]]; then
        echo "ERROR: Project name file does not exist: $PROJECT_FILE"
        exit 1
    fi

    PROJECT_NAME=$(cat "$PROJECT_FILE")

    if [[ -z "$PROJECT_NAME" ]]; then
        echo "ERROR: Project name file is empty."
        exit 1
    fi

    echo "Detected project (from file): $PROJECT_NAME"
fi

export PROJECT_NAME

# -----------------------------
# Create a directory for BLAST output
# -----------------------------
mkdir -p "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/output/BLAST"

# -------------------------------
# Load modules / environment
# -------------------------------
module load apptainer

echo "Job running on node: $(hostname)"
echo "Starting BLAST directly from /group/ database..."

# -------------------------------
# Ensure BLAST container exists
# -------------------------------
BLAST_CONTAINER="$GROUP_CONTAINER_DIR/GVL_blast_unassigned_ASVs.sif"
BLAST_CONTAINER_URL="oras://community.wave.seqera.io/library/blast_conda_r-base:8a9e1389abdacf11"

echo "Checking for Apptainer container: $BLAST_CONTAINER"

LOCKFILE="$BLAST_CONTAINER.lock"

if [ ! -f "$BLAST_CONTAINER" ]; then
    echo "BLAST_Container not found. Attempting to pull with lock..."

    (
        flock -n 9 || exit 1
        if [ ! -f "$BLAST_CONTAINER" ]; then
            apptainer pull "$BLAST_CONTAINER" "$BLAST_CONTAINER_URL"
        fi
    ) 9>"$LOCKFILE" || {
        echo "Another job is currently pulling this container. Exiting."
        exit 1
    }

else
    echo "Container found: $BLAST_CONTAINER"
fi

# -------------------------------
# Detect latest NCBI DB folder
# -------------------------------
LATEST_DB_DIR=$(ls -d /group/ajfingergrp/NCBI_core_nt_* 2>/dev/null | sort -V | tail -n 1)

if [ -z "$LATEST_DB_DIR" ]; then
    echo "ERROR: No NCBI_core_nt_* folders found in /group/ajfingergrp/"
    exit 1
fi

DB="${LATEST_DB_DIR}/core_nt"
echo "Using database: $DB"

# -------------------------------
# Set project and output paths
# -------------------------------
PROJECT_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME"
BLAST_DIR="$PROJECT_DIR/output/BLAST"

# -------------------------------
# Choose query FASTA based on workflow choice
# -------------------------------
CHOICE_VALUE="$(echo "${CHOICE:-}" | tr '[:lower:]' '[:upper:]')"

if [[ "$CHOICE_VALUE" == "2" ]]; then
  QUERY="$PROJECT_DIR/output/dada2/ASV_seqs.fasta"
else
  QUERY="$PROJECT_DIR/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta"
fi

OUTFILE="$BLAST_DIR/${PROJECT_NAME}_raw_blast_results.tsv"

if [[ ! -s "$QUERY" ]]; then
  echo "ERROR: Query FASTA not found (or empty): $QUERY"
  echo "Fix: make sure the expected upstream step produced it."
  exit 1
fi

# -------------------------------
# Run BLAST using the group database
# -------------------------------
echo "Using BLAST thresholds:"
BLAST_PERC_IDENTITY="${BLAST_PERC_IDENTITY:-97}"
BLAST_MAX_TARGET_SEQS="${BLAST_MAX_TARGET_SEQS:-5}"

apptainer exec --bind /group/ajfingergrp:/group/ajfingergrp "$BLAST_CONTAINER" \
  bash -c "export BLASTDB=$LATEST_DB_DIR && \
           blastn \
             -query $QUERY \
             -db $DB \
             -out $OUTFILE \
             -outfmt '6 qseqid qcovs sseqid pident length qlen slen mismatch gapopen qstart qend sstart send evalue bitscore stitle sscinames sblastnames scomnames staxids' \
             -max_target_seqs $BLAST_MAX_TARGET_SEQS \
             -perc_identity $BLAST_PERC_IDENTITY \
             -num_threads 8"

echo "BLAST completed."
echo "Results written to: $OUTFILE"
echo "Job finished. SLURM logs are in /group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
