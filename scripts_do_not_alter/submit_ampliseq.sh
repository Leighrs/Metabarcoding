#!/bin/bash
set -euo pipefail

SBATCH_SCRIPT="$HOME/Metabarcoding/scripts_do_not_alter/run_nf-core_ampliseq.slurm"

LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
mkdir -p "$LOGDIR"

sbatch \
  --chdir="$HOME" \
  --output="$LOGDIR/%x_%j.out" \
  --error="$LOGDIR/%x_%j.err" \
  "$SBATCH_SCRIPT"