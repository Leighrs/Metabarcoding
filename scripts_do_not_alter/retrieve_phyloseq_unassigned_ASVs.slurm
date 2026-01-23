#!/bin/bash
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --job-name=blast_asv
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=10:00:00
#SBATCH --output=Metabarcoding/Logs_archive/phyloseq_unassigned_asv_%j.out
#SBATCH --error=Metabarcoding/Logs_archive/phyloseq_unassigned_asv_%j.err


###############################################
# DO NOT EDIT ANYTHING unless you know what you are doing. :)
###############################################

# -----------------------------
# Group location for shared containers
# -----------------------------
GROUP_CONTAINER_DIR="/group/ajfingergrp/Metabarcoding/Containers"
mkdir -p "$GROUP_CONTAINER_DIR"


# -----------------------------
# Make sure the log directory exists.
# -----------------------------
mkdir -p "$HOME/Metabarcoding/Logs_archive"

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
export PROJECT_NAME

# -----------------------------
# Create a directory for R output
# -----------------------------
mkdir -p "$HOME/Metabarcoding/$PROJECT_NAME/output/R"

# -------------------------------
# 1. Ensure container exists
# -------------------------------
CONTAINER="$GROUP_CONTAINER_DIR/Retrieve_phyloseq_unassigned_ASVs.sif"
CONTAINER_URL="oras://community.wave.seqera.io/library/bioconductor-biomformat_bioconductor-phyloseq_conda_r-base:035a5152df7dbbfd"

echo "Checking for Apptainer container: $CONTAINER"

module load apptainer

LOCKFILE="$CONTAINER.lock"

if [ ! -f "$CONTAINER" ]; then
    echo "Container not found. Attempting to pull with lock..."

    (
        flock -n 9 || exit 1
        if [ ! -f "$CONTAINER" ]; then
            apptainer pull "$CONTAINER" "$CONTAINER_URL"
        fi
    ) 9>"$LOCKFILE" || {
        echo "Another job is currently pulling this container. Exiting."
        exit 1
    }

else
    echo "Container found: $CONTAINER"
fi

echo "Job running on node: $(hostname)"
echo "Starting BLAST directly from /group/ database..."

# -------------------------------
# 2. Run R inside the container
# -------------------------------
apptainer exec "$CONTAINER" Rscript - << 'EOF'

# ---------------- R CODE STARTS HERE ----------------

# Grab environment variables
home <- Sys.getenv("HOME")
project_name <- Sys.getenv("PROJECT_NAME")

if (project_name == "") {
  stop("PROJECT_NAME environment variable is not set inside R.")
}

cat("Using container .libPaths():\n")
print(.libPaths())

suppressPackageStartupMessages({
  library(phyloseq)
})
cat("Successfully loaded phyloseq\n")

# Build paths
rds_path <- file.path(home, "Metabarcoding", project_name, "output", "phyloseq", "dada2_phyloseq.rds")
out_dir  <- file.path(home, "Metabarcoding", project_name, "output", "R")
out_fasta <- file.path(out_dir, paste0(project_name, "_DADA2_unassigned_ASVs.fasta"))

cat("Using RDS file: ", rds_path, "\n", sep = "")
cat("Output FASTA:  ", out_fasta, "\n", sep = "")

if (!file.exists(rds_path)) {
  stop("RDS file not found at: ", rds_path)
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

# Load phyloseq object
ps <- readRDS(rds_path)

# Extract taxonomy table
taxa <- tax_table(ps)
taxa <- as.matrix(taxa)

# Treat empty strings as NA
taxa[taxa == ""] <- NA

# Find NA positions in taxa
taxa.na <- which(is.na(taxa), arr.ind = TRUE)
taxa.na

if (nrow(taxa.na) == 0) {
  cat("No ASVs with NA/empty taxonomy found.\n")
  quit(status = 0)
}

# Keeps only unique ASVs (row names of the NA positions). ASVs with multiple NA/blank taxa fields will appear multiple times.
asv_rows <- unique(taxa.na[, "row"]) #Identifies rows in which to find NA ASVs

asv_raw <- as.character(taxa[asv_rows, 10]) # Raw strings from column 10 (may contain ID + sequence)


extract_seq <- function(x) { # Function: grab the first stretch of DNA letters from the string
  x_upper <- toupper(x)
  m <- regexpr("[ACGTURYKMSWBDHVN]+", x_upper)  # standard IUPAC DNA codes
  ifelse(
    m > 0,
    substr(x_upper, m, m + attr(m, "match.length") - 1),
    NA_character_
  )
}

asv_seqs <- extract_seq(asv_raw)

cat("Found ", length(asv_rows), " ASVs with NA/empty taxonomy.\n", sep = "")

# FASTA header names: use rownames of taxa (ASV IDs)
asv_names <- rownames(taxa)[asv_rows]

# Simple FASTA writer (no external packages)
write_fasta <- function(sequences, names, file) {
  con <- file(file, open = "w")
  on.exit(close(con), add = TRUE)

  for (i in seq_along(sequences)) {
    writeLines(paste0(">", names[i]), con)
    # single-line sequence is fine for FASTA
    writeLines(sequences[i], con)
  }
}

write_fasta(
  sequences = asv_seqs,
  names     = asv_names,
  file      = out_fasta
)


cat("Wrote FASTA file with unassigned ASVs to:\n", out_fasta, "\n")

# ---------------- R CODE ENDS HERE ----------------
EOF

# -----------------------------
# Create a directory for BLAST output
# -----------------------------
mkdir -p "$HOME/Metabarcoding/$PROJECT_NAME/output/BLAST"


# -----------------------------
# Optional: control BLAST via env var
# -----------------------------
RUN_BLAST_VALUE=$(echo "${RUN_BLAST:-no}" | tr '[:upper:]' '[:lower:]')

if [[ "$RUN_BLAST_VALUE" != "yes" ]]; then
    echo "RUN_BLAST is '$RUN_BLAST_VALUE' ? Skipping BLAST step."
    echo "Job finished. SLURM logs are in $HOME/Metabarcoding/Logs_archive"
    exit 0
fi

echo "RUN_BLAST='yes' ? proceeding with BLAST."


# BLAST 


# -------------------------------
# 1. Ensure BLAST container exists
# -------------------------------
BLAST_CONTAINER="$GROUP_CONTAINER_DIR/GVL_blast_unassigned_ASVs.sif"
BLAST_CONTAINER_URL="oras://community.wave.seqera.io/library/blast_conda_r-base:8a9e1389abdacf11"

echo "Checking for Apptainer container: $BLAST_CONTAINER"

LOCKFILE="$BLAST_CONTAINER.lock" # prevents double pull if two people submit jobs at once

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


QUERY="$PROJECT_DIR/output/R/${PROJECT_NAME}_DADA2_unassigned_ASVs.fasta"
OUTFILE="$BLAST_DIR/${PROJECT_NAME}_raw_blast_results_from_phyloseq_obj.tsv"

# -------------------------------
# 5. Run BLAST using the group database
# -------------------------------
apptainer exec --bind /group/ajfingergrp:/group/ajfingergrp "$BLAST_CONTAINER" \
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
