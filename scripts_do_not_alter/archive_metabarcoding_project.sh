#!/usr/bin/env bash
set -euo pipefail

# --------- Config ---------
PROJECT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"
LOGDIR="/group/ajfingergrp/Metabarcoding/intermediates_logs_cache/slurm_logs"
ARCHIVE_BASE="/group/ajfingergrp/Metabarcoding/Past_Runs_Archive/Run_By_${USER}"
SRC_BASE="/group/ajfingergrp/Metabarcoding/Project_Runs"

mkdir -p "$LOGDIR"

# --------- Get project name ---------
if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "ERROR: No project defined."
  echo "Run setup_metabarcoding_directory.sh first."
  exit 1
fi

PROJECT_NAME="$(tr -d '[:space:]' < "$PROJECT_FILE")"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: PROJECT_NAME is empty in $PROJECT_FILE"
  exit 1
fi

SRC_DIR="$SRC_BASE/$PROJECT_NAME"
DEST_DIR="$ARCHIVE_BASE/$PROJECT_NAME"

echo ""
echo "Project:  $PROJECT_NAME"
echo "Source:   $SRC_DIR"
echo "Archive:  $DEST_DIR"
echo ""

# --------- Sanity checks ---------
if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: Source project directory not found:"
  echo "  $SRC_DIR"
  exit 1
fi

# --------- Determine resume ---------
RESUME_FLAG="no"
if [[ -d "$DEST_DIR" ]]; then
  echo "Archive destination already exists:"
  echo "  $DEST_DIR"
  echo ""
  read -rp "Resume previous archive into this folder? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    RESUME_FLAG="yes"
  else
    echo "Exiting to avoid overwriting an existing archive."
    exit 1
  fi
fi

# --------- Determine delete-original ---------
DELETE_FLAG="no"
echo ""
read -rp "After successful archive + verification, delete the ORIGINAL project folder? [y/N]: " delans
if [[ "$delans" =~ ^[Yy]$ ]]; then
  DELETE_FLAG="yes"
fi

echo ""
echo "Submitting archive job to SLURM..."
echo ""

JOB_ID="$(
sbatch --parsable \
  --account=millermrgrp \
  --partition=bmh \
  --job-name="archive_${PROJECT_NAME}" \
  --ntasks=1 \
  --cpus-per-task=1 \
  --mem=4G \
  --time=48:00:00 \
  --output="$LOGDIR/archive_${PROJECT_NAME}_%j.out" \
  --error="$LOGDIR/archive_${PROJECT_NAME}_%j.err" <<EOF
#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="$PROJECT_NAME"
SRC_DIR="$SRC_DIR"
DEST_DIR="$DEST_DIR"
DEST_BASE="$ARCHIVE_BASE"
RESUME_FLAG="$RESUME_FLAG"
DELETE_FLAG="$DELETE_FLAG"

echo "User:      \$(whoami)"
echo "Node:      \$(hostname)"
echo "Start:     \$(date)"
echo "Project:   \$PROJECT_NAME"
echo "Source:    \$SRC_DIR"
echo "Dest:      \$DEST_DIR"
echo "Resume:    \$RESUME_FLAG"
echo "Delete:    \$DELETE_FLAG"
echo ""

command -v rsync >/dev/null 2>&1 || { echo "ERROR: rsync not found" >&2; exit 1; }

if [[ ! -d "\$SRC_DIR" ]]; then
  echo "ERROR: Source project directory not found: \$SRC_DIR" >&2
  exit 1
fi

mkdir -p "\$DEST_BASE"

if [[ -d "\$DEST_DIR" && "\$RESUME_FLAG" != "yes" ]]; then
  echo "ERROR: Destination exists and resume was not approved: \$DEST_DIR" >&2
  exit 1
fi

mkdir -p "\$DEST_DIR"

echo "Running rsync..."
rsync -a --partial --info=progress2 --human-readable \
  "\$SRC_DIR/" "\$DEST_DIR/"

echo ""
echo "Archive copy completed at: \$(date)"
echo "Verifying archive by file count..."

SRC_COUNT=\$(find "\$SRC_DIR" -type f | wc -l)
DEST_COUNT=\$(find "\$DEST_DIR" -type f | wc -l)

echo "Source files:  \$SRC_COUNT"
echo "Archive files: \$DEST_COUNT"

if [[ "\$SRC_COUNT" -ne "\$DEST_COUNT" ]]; then
  echo "ERROR: File counts differ. Original project will NOT be deleted." >&2
  exit 1
fi

echo "Verification passed."

if [[ "\$DELETE_FLAG" == "yes" ]]; then
  echo "Deleting original project directory..."
  rm -rf "\$SRC_DIR"
  echo "? Original project removed."
else
  echo "Original project retained."
fi

echo ""
echo "Done: \$(date)"
echo "Archived project: \$DEST_DIR"
EOF
)"

echo ""
echo "Submitted job: $JOB_ID"
echo "Logs:"
echo "  $LOGDIR/archive_${PROJECT_NAME}_${JOB_ID}.out"
echo "  $LOGDIR/archive_${PROJECT_NAME}_${JOB_ID}.err"
echo ""