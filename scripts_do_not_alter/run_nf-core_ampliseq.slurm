#!/bin/bash
#SBATCH --job-name=ampliseq
#SBATCH --account=millermrgrp
#SBATCH --partition=bmh
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=120G
#SBATCH --time=10:00:00
#SBATCH --output=Metabarcoding/Logs_archive/run_nfcore_ampliseq_%j.out
#SBATCH --error=Metabarcoding/Logs_archive/run_nfcore_ampliseq_%j.err

# ------------------------------------
# 1. Get project name created earlier
# ------------------------------------
PROJECT_FILE="$HOME/Metabarcoding/current_project_name.txt"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "ERROR: No project defined."
    echo "Run setup_metabarcoding_directory.sh first."
    exit 1
fi

PROJECT=$(cat "$PROJECT_FILE")
echo "Running project: $PROJECT"

# ------------------------------------
# 2. Ensure required directories exist
# ------------------------------------
mkdir -p "$HOME/Metabarcoding/Logs_archive"
mkdir -p "$HOME/Metabarcoding/Containers"

# ------------------------------------
# 3. Define paths
# ------------------------------------
BASE_OUT="$HOME/Metabarcoding/$PROJECT/output"
CACHE_DIR="${BASE_OUT}/intermediates_logs_cache"
SINGULARITY_CACHE="${CACHE_DIR}/singularity"
PARAMS_FILE="$HOME/Metabarcoding/$PROJECT/scripts/${PROJECT}_nf-params_expanded.json"

CONTAINER="$HOME/Metabarcoding/Containers/GVL_metabarcoding.sif"
CONTAINER_URL="oras://community.wave.seqera.io/library/nextflow_nf-core_apptainer_conda_pruned:0f9c913ab4de9751"


# ------------------------------------
# 4. Load modules
# ------------------------------------
module load apptainer

echo "Node: $(hostname)"
echo "Container: $CONTAINER"

# ------------------------------------
# 5. Pull container if missing
# ------------------------------------
if [ ! -f "$CONTAINER" ]; then
    echo "Container not found. Pulling..."
    apptainer pull "$CONTAINER" "$CONTAINER_URL"
else
    echo "Container already exists."
fi

# ------------------------------------
# 6. Set Nextflow Apptainer cache
# ------------------------------------
export NXF_APPTAINER_CACHEDIR="$SINGULARITY_CACHE"

# ------------------------------------
# 7. Run NF-core Ampliseq
# ------------------------------------
echo "Starting nf-core/ampliseq pipeline..."
apptainer exec "$CONTAINER" \
    nextflow run nf-core/ampliseq \
        -r 2.15.0 \
        -profile apptainer \
        -work-dir "$CACHE_DIR" \
        -params-file "$PARAMS_FILE" \
        -c <(echo "apptainer { pullTimeout = '20 min' }")

echo "nf-core/ampliseq pipeline completed successfully."
