#!/bin/bash
set -euo pipefail

PIPELINE_DIR="/group/ajfingergrp/Metabarcoding/GVL_ampliseq_scripts/scripts_do_not_alter"
SBATCH_SCRIPT="$PIPELINE_DIR/blast_cleanup.slurm"

LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
mkdir -p "$LOGDIR"

echo ""
echo "Submitting NCBI taxonomy job to organize raw BLAST results."
echo ""

sbatch \
  --output="$LOGDIR/%x_%j.out" \
  --error="$LOGDIR/%x_%j.err" \
  "$SBATCH_SCRIPT"