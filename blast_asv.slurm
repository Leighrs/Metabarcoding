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

# -----------------------------
# Make sure the log and container directories exists.
# -----------------------------
mkdir -p "$HOME/Metabarcoding/Logs_archive"
mkdir -p "$HOME/Metabarcoding/Containers"

###############################################
# NOTES — ONLY EDIT THE FOLLOWING FIELDS:
#
# 1. QUERY   ? Path to your input FASTA file
# 2. OUTFILE ? Path/file name for BLAST results
# 3. job-name (optional) ? #SBATCH --job-name=
# 4. resource requests (optional) ? cpus, mem, time
#
# DO NOT EDIT ANYTHING ELSE unless you know what you are doing. :)
# The script automatically finds the newest NCBI database folder.
###############################################

# -------------------------------
# 1. Ensure BLAST container exists
# -------------------------------
CONTAINER="Metabarcoding/Containers/GVL_blast_unassigned_ASVs.sif"
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
# 4. Set user-editable paths
# -------------------------------
QUERY="/home/leighrs/ASV_seqs_AT.fasta"
OUTFILE="/home/leighrs/blast_results_AT_v2.tsv"

# -------------------------------
# 5. Run BLAST using the group database
# -------------------------------
apptainer exec --bind /group/ajfingergrp:/group/ajfingergrp "$CONTAINER" \
    bash -c "export BLASTDB=$LATEST_DB_DIR && \
             blastn \
               -query $QUERY \
               -db $DB \
               -out $OUTFILE \
               -outfmt '6 qseqid qcovs sseqid pident length qlen slen mismatch gapopen qstart qend sstart send evalue bitscore stitle sscinames sblastnames scomnames staxids' \
               -max_target_seqs 5 \
               -perc_identity 97 \
               -num_threads 8"

echo "BLAST completed."
echo "Results written to: $OUTFILE"

# -------------------------------
# 6. Done
# -------------------------------
echo "Job finished. SLURM logs are in "$HOME/Metabarcoding/Logs_archive
