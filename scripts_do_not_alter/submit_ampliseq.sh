#!/bin/bash
set -euo pipefail

SBATCH_SCRIPT="$HOME/Metabarcoding/scripts_do_not_alter/run_nf-core_ampliseq.slurm"

LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
mkdir -p "$LOGDIR"

RESUME_RUN="0"

if [[ -t 0 ]]; then
  while true; do
    read -r -p "Resume an existing Nextflow run? [y/n]: " ans
    case "${ans,,}" in
      y|yes) RESUME_RUN="1"; break ;;
      n|no)  RESUME_RUN="0"; break ;;
      *)     echo "Please answer y or n." ;;
    esac
  done
fi

sbatch \
  --chdir="$HOME" \
  --output="$LOGDIR/%x_%j.out" \
  --error="$LOGDIR/%x_%j.err" \
  --export=ALL,RESUME_RUN="$RESUME_RUN" \
  "$SBATCH_SCRIPT"