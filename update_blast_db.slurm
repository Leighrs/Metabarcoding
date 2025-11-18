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

# -----------------------------
# Make sure the log directory exists.
# -----------------------------
mkdir -p "$HOME/Metabarcoding/Logs_archive"

# -------------------------------
# 0. IMPORTANT NOTES
# -------------------------------
# - Database directory will be suffixed with today's date (YYYYMMDD)
# - Old folders matching NCBI_core_nt_* will be deleted except today's
# - Some earlier versions of perl may not work, and give curl errors.
# - Ouput and error logs will be stored in ~/Logs_archive/". If this folder does not exist, this script will create it.
# - Duration of script is usually about 10 hours. But keep the reserved time as 30 hours. Sometimes it just takes a lot longer.

echo "Job running on node: $(hostname)"

# -------------------------------
# 1. Define paths
# -------------------------------
DATE_SUFFIX=$(date +%Y%m%d)
DB_DIR="/group/ajfingergrp/NCBI_core_nt_${DATE_SUFFIX}/"

# -------------------------------
# 2. Remove old database folders
# -------------------------------
echo "Checking for old NCBI_core_nt_* folders to delete..."
for folder in /group/ajfingergrp/NCBI_core_nt_*; do
    if [ "$folder" != "$DB_DIR" ] && [ -d "$folder" ]; then
        echo "Deleting old folder: $folder"
        rm -rf "$folder"
    fi
done

# -------------------------------
# 3. Ensure database directory exists
# -------------------------------
if [ ! -d "$DB_DIR" ]; then
    echo "Creating today's database folder: $DB_DIR"
    mkdir -p "$DB_DIR"
else
    echo "Today's database folder already exists: $DB_DIR"
fi

# -------------------------------
# 4. Update NCBI core_nt database
# -------------------------------
echo "Updating NCBI core_nt database..."

cd "$DB_DIR"
module load perl/5.40.0
module load blast-plus/2.16.0
update_blastdb.pl --passive --decompress core_nt
update_blastdb.pl --passive --decompress taxdb

echo "Database update completed."
echo "Database stored in: $DB_DIR"

# -------------------------------
# 6. Done
# -------------------------------
echo "Job finished. SLURM logs are in "$HOME/Metabarcoding/Logs_archive
