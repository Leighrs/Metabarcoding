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


# ----------------------------
# Config
# ----------------------------
ENV_PREFIX_nfcore="/group/ajfingergrp/Metabarcoding/conda_envs/nfcore_env"

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
ENV_DIR_nfcore="$(dirname "$ENV_PREFIX_nfcore")"
mkdir -p "$ENV_DIR_nfcore" || { echo "ERROR: cannot create $ENV_DIR_nfcore (permissions?)" >&2; exit 1; }

if [[ ! -d "$ENV_PREFIX_nfcore/conda-meta" ]]; then
  LOCKFILE_nfcore="$ENV_DIR_nfcore/nfcore_env.lock"
  exec 9>"$LOCKFILE_nfcore"
  flock -n 9 || {
    echo "Conda env creation already in progress by another user."
    echo "If this seems stuck, check/remove: $LOCKFILE_nfcore"
    exit 0
  }

  echo "Creating conda env at: $ENV_PREFIX_nfcore"
  mamba create -y -p "$ENV_PREFIX_nfcore" \
    -c conda-forge -c bioconda \
    nextflow=23.10.1 \
    openjdk=17 \
    git \
    jq
else
  echo "Conda env already exists at: $ENV_PREFIX_nfcore"
fi


# ----------------------------
# Activate env
# ----------------------------
conda activate "$ENV_PREFIX_nfcore"
module load apptainer

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
# 3. Define paths
# ------------------------------------
BASE_OUT="$HOME/Metabarcoding/$PROJECT/output"
CACHE_DIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/${PROJECT}_cache"
SINGULARITY_CACHE="${CACHE_DIR}/singularity"
PARAMS_FILE="$HOME/Metabarcoding/$PROJECT/params/${PROJECT}_nf-params_expanded.json"


# ------------------------------------
# 6. Set Nextflow Apptainer cache
# ------------------------------------
export NXF_APPTAINER_CACHEDIR="$SINGULARITY_CACHE"

# ------------------------------------
# 7. Run NF-core Ampliseq
# ------------------------------------
echo "Starting nf-core/ampliseq pipeline..."
        
export PROJECT="$(cat $HOME/Metabarcoding/current_project_name.txt)"
export NXF_HOME="$CACHE_DIR/$PROJECT/.nextflow"
mkdir -p "$NXF_HOME"
cd "$HOME/Metabarcoding/$PROJECT"

nextflow run nf-core/ampliseq \
    -r 2.16.1 \
    -profile apptainer \
    -work-dir "$CACHE_DIR" \
    -c <(cat <<'EOF'
apptainer {
  pullTimeout = '60m'
}
singularity {
  pullTimeout = '60m'
}
EOF
) \
    -params-file "$PARAMS_FILE" \
    -resume


echo "nf-core/ampliseq pipeline completed successfully."
