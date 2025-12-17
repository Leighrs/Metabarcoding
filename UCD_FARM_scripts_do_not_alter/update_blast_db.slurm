#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=update_ncbi_db
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=Metabarcoding/Logs_archive/update_ncbi_db_%j.out
#SBATCH --error=Metabarcoding/Logs_archive/update_ncbi_db_%j.err

# -------------------------------
# A. Parse command-line flags
# -------------------------------
DELETE_OLD=false

for arg in "$@"; do
    if [ "$arg" == "--delete-old" ]; then
        DELETE_OLD=true
    fi
done

if [ "$DELETE_OLD" = true ]; then
    echo "Flag --delete-old detected: old database folders WILL be removed."
else
    echo "No --delete-old flag detected: old databases will NOT be removed."
fi

# -----------------------------
# Make sure the log directory exists.
# -----------------------------
LOGDIR="$HOME/Metabarcoding/Logs_archive"
mkdir -p "$LOGDIR"

# -------------------------------
# 0. IMPORTANT NOTES
# -------------------------------
# - Database directory will be suffixed with today's date (YYYYMMDD)
# - Old folders matching NCBI_core_nt_* will be deleted except today's
# - Some earlier versions of perl may not work, and give curl errors.
# - Ouput and error logs will be stored in ~/Logs_archive/". If this folder does not exist, this script will create it.
# - Duration of script is usually about 10 hours. But keep the reserved time as 30 hours. Sometimes it just takes a lot longer.

echo "------------------------------------------------------------"
echo "Job running on node: $(hostname)"
echo "Start time: $(date)"
echo "Delete old databases: $DELETE_OLD"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Logs saved in: $LOGDIR"
echo "------------------------------------------------------------"

# -------------------------------
# 1. Define paths
# -------------------------------
DATE_SUFFIX=$(date +%Y%m%d)
DB_DIR="/group/ajfingergrp/NCBI_core_nt_${DATE_SUFFIX}/"
echo "Today's database directory: $DB_DIR"

# -------------------------------
# 2. Optional: Remove old database folders
# -------------------------------
if [ "$DELETE_OLD" = true ]; then
    echo "Scanning for old NCBI_core_nt_* directories to delete..."

    for folder in /group/ajfingergrp/NCBI_core_nt_*; do
        
        # Skip if today's directory or if not a directory
        if [ "$folder" = "$DB_DIR" ] || [ ! -d "$folder" ]; then
            continue
        fi

        echo "Deleting old folder: $folder"
        rm -rf "$folder"
    done
else
    echo "Skipping deletion of old database directories (no --delete-old flag)."
fi

# -------------------------------
# 3. Ensure database directory exists
# -------------------------------
if [ ! -d "$DB_DIR" ]; then
    echo "Creating database directory: $DB_DIR"
    mkdir -p "$DB_DIR"
else
    echo "Database directory already exists: $DB_DIR"
fi

cd "$DB_DIR" || {
    echo "ERROR: Could not enter directory $DB_DIR"
    exit 1
}

# -------------------------------
# 4. Update NCBI core_nt database
# -------------------------------

echo "Loading modules..."
cd "$DB_DIR"
module load perl/5.40.0 || { echo "ERROR loading perl module"; exit 1; }
module load blast-plus/2.16.0 || { echo "ERROR loading BLAST+ module"; exit 1; }

echo "------------------------------------------------------------"
echo "Starting BLAST database update at: $(date)"
echo "------------------------------------------------------------"


update_blastdb.pl --passive --decompress core_nt \
    || { echo "ERROR updating core_nt"; exit 1; }

update_blastdb.pl --passive --decompress taxdb \
    || { echo "ERROR updating taxdb"; exit 1; }

echo "------------------------------------------------------------"
echo "Database update completed successfully."
echo "Database stored in: $DB_DIR"
echo "End time: $(date)"
echo "------------------------------------------------------------"

# -------------------------------
# 6. Done
# -------------------------------
echo "Job finished. SLURM logs in $LOGDIR"
