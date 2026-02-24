#!/bin/bash
set -euo pipefail

SBATCH_SCRIPT="$HOME/Metabarcoding/scripts_do_not_alter/run_nf-core_ampliseq.slurm"

LOGDIR="$HOME/Metabarcoding/Logs_archive"
mkdir -p "$LOGDIR"

sbatch \
  --chdir="$HOME" \
  --output="$LOGDIR/%x_%j.out" \
  --error="$LOGDIR/%x_%j.err" \
  "$SBATCH_SCRIPT"