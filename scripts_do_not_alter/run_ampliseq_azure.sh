#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------
# Paths and directories (inside WSL)
# ------------------------------------
METABARCODING="$HOME/Metabarcoding"
mkdir -p "$METABARCODING/Logs_archive"
PROJECT_FILE="$METABARCODING/current_project_name.txt"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: No project defined"
  exit 1
fi

PROJECT="$(cat "$PROJECT_FILE")"
echo "Running project: $PROJECT"

PARAMS_FILE="${METABARCODING}/${PROJECT}/scripts/${PROJECT}_nf-params_expanded.json"
if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "ERROR: Params file not found: $PARAMS_FILE"
  exit 1
fi

# ------------------------------------
# Azure settings
# ------------------------------------
AZ_LOCATION="westus2"

# Store log files locally
export NXF_LOG_FILE="${METABARCODING}/Logs_archive/nextflow_${PROJECT}_$(date +%Y%m%d_%H%M%S).log"

NF_CONFIG="$HOME/azure_esm_ampliseq.config"
if [[ ! -f "$NF_CONFIG" ]]; then
  echo "ERROR: Nextflow config not found: $NF_CONFIG"
  exit 1
fi

NF_KEYS="$HOME/config"

if [[ ! -f "$NF_KEYS" ]]; then
  echo "ERROR: Nextflow config not found: $NF_KEYS"
  exit 1
fi



# ------------------------------------
# Run ampliseq on Azure Batch
# ------------------------------------

nextflow run nf-core/ampliseq \
    -r 2.15.0 \
    -profile azurebatch,docker \
    -c "$NF_KEYS" \
    -c "$NF_CONFIG" \
    -params-file "$PARAMS_FILE" \
    --az_location "$AZ_LOCATION"
