#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=blast_asv
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=10:00:00
#SBATCH --output=Metabarcoding/Logs_archive/blast_asv_%j.out
#SBATCH --error=Metabarcoding/Logs_archive/blast_asv_%j.err


###############################################
# DO NOT EDIT ANYTHING ELSE unless you know what you are doing. :)
# The script automatically finds the newest NCBI database folder and pulls in scripths.
###############################################

# -----------------------------
# Make sure the log and container directories exists.
# -----------------------------
mkdir -p "$HOME/Metabarcoding/Logs_archive"
mkdir -p "/group/ajfingergrp/Metabarcoding/Containers"

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

# -----------------------------
# Create a directory for BLAST output
# -----------------------------
mkdir -p "$HOME/Metabarcoding/$PROJECT_NAME/output/BLAST"


# -------------------------------
# 1. Ensure BLAST container exists
# -------------------------------
CONTAINER="/group/ajfingergrp/Metabarcoding/Containers/GVL_blast_unassigned_ASVs.sif"
CONTAINER_URL="oras://community.wave.seqera.io/library/blast_conda_r-base:8a9e1389abdacf11"

echo "Checking for Apptainer container: $CONTAINER"

if [ ! -f "$CONTAINER" ]; then
    echo "Container not found. Downloading with apptainer pull..."
    module load apptainer
    apptainer pull "$CONTAINER" "$CONTAINER_URL"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to pull container from $CONTAINER_URL"
        exit 1
    fi
else
    echo "Container found: $CONTAINER"
fi


# -------------------------------
# 2. Load modules / environment
# -------------------------------
module load apptainer

echo "Job running on node: $(hostname)"
echo "Starting BLAST directly from /group/ database..."

# -------------------------------
# 3. Detect latest NCBI DB folder
# -------------------------------
LATEST_DB_DIR=$(ls -d /group/ajfingergrp/NCBI_core_nt_* 2>/dev/null | sort -V | tail -n 1)

if [ -z "$LATEST_DB_DIR" ]; then
    echo "ERROR: No NCBI_core_nt_* folders found in /group/ajfingergrp/"
    exit 1
fi

DB="${LATEST_DB_DIR}/core_nt"
echo "Using database: $DB"

# -------------------------------
# 4. Set query and outfile paths
# -------------------------------
PROJECT_DIR="$HOME/Metabarcoding/$PROJECT_NAME"
BLAST_DIR="$PROJECT_DIR/output/BLAST"


QUERY="$PROJECT_DIR/output/dada2/ASV_seqs.fasta"
OUTFILE="$BLAST_DIR/${PROJECT_NAME}_raw_blast_results.tsv"

# -------------------------------
# 5. Run BLAST using the group database
# -------------------------------
echo "Using BLAST thresholds:"
BLAST_PERC_IDENTITY="${BLAST_PERC_IDENTITY:-97}"
BLAST_MAX_TARGET_SEQS="${BLAST_MAX_TARGET_SEQS:-5}"

apptainer exec --bind /group/ajfingergrp:/group/ajfingergrp "$CONTAINER" \
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

# -------------------------------
# 6. Done
# -------------------------------
echo "Job finished. SLURM logs are in "$HOME/Metabarcoding/Logs_archive
