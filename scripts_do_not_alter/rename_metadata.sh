#!/usr/bin/env bash
set -euo pipefail

PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: Project name file not found: $PROJECT_FILE"
  exit 1
fi

PROJECT_NAME=$(<"$PROJECT_FILE")
PROJECT_NAME="${PROJECT_NAME//$'\r'/}"

if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: Project name is empty"
  exit 1
fi

FASTQ_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/${PROJECT_NAME}/input/fastq"

if [[ ! -d "$FASTQ_DIR" ]]; then
  echo "ERROR: FASTQ directory not found: $FASTQ_DIR"
  exit 1
fi

mapfile -t CSV_FILES < <(find "$FASTQ_DIR" -maxdepth 1 -type f -name "*.csv")

if [[ ${#CSV_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No CSV file found in $FASTQ_DIR"
  exit 1
elif [[ ${#CSV_FILES[@]} -gt 1 ]]; then
  echo "ERROR: Multiple CSV files found in $FASTQ_DIR"
  printf '%s\n' "${CSV_FILES[@]}"
  exit 1
fi

CSV="${CSV_FILES[0]}"
EXECUTE=false

case "${1:-}" in
  --execute)
    EXECUTE=true
    ;;
  "")
    ;;
  -h|--help)
    echo "Usage: bash $0 [--execute]"
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: bash $0 [--execute]"
    exit 1
    ;;
esac

cd "$FASTQ_DIR"

echo "Using project: $PROJECT_NAME"
echo "FASTQ directory: $FASTQ_DIR"
echo "CSV file: $CSV"

if [[ "$EXECUTE" == true ]]; then
  echo "Mode: EXECUTE - files will be renamed"
else
  echo "Mode: DRY RUN - no files will be renamed"
  echo "Run with --execute to actually rename files"
fi
echo

while IFS=, read -r old new rest; do
  old="${old//$'\r'/}"
  new="${new//$'\r'/}"

  [[ -z "$old" && -z "$new" ]] && continue
  [[ "$old" == "old" && "$new" == "new" ]] && continue

  if [[ -z "$old" || -z "$new" ]]; then
    echo "SKIP malformed row: old='$old' new='$new'"
    continue
  fi

  for readnum in R1 R2; do
    candidates=(
      "${old}_${readnum}.fastq.gz"
      "${old}_${readnum}_001.fastq.gz"
    )

    found=false

    for src in "${candidates[@]}"; do
      if [[ -f "$src" ]]; then
        found=true

        suffix="${src#${old}_}"
        dest="${new}_${suffix}"

        if [[ "$src" == "$dest" ]]; then
          echo "SKIP same name: $src"
          continue
        fi

        if [[ -e "$dest" ]]; then
          echo "SKIP destination exists: $dest"
          continue
        fi

        if [[ "$EXECUTE" == true ]]; then
          mv -- "$src" "$dest"
          echo "RENAMED: $src -> $dest"
        else
          echo "DRY RUN: mv -- '$src' '$dest'"
        fi
      fi
    done

    if [[ "$found" == false ]]; then
      echo "MISSING: ${old}_${readnum}.fastq.gz or ${old}_${readnum}_001.fastq.gz"
    fi
  done
done < "$CSV"

echo
echo "Done."