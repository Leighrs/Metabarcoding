#!/bin/bash

# Read project name
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

# Default FASTQ directory (home/local)
DEFAULT_FASTQ_DIR="$HOME/Metabarcoding/$PROJECT_NAME/input/fastq"

# Pointer file (exists only if user chose group storage in setup)
FASTQ_PTR_FILE="$HOME/Metabarcoding/$PROJECT_NAME/input/fastq_storage_path.txt"

# Decide FASTQ_DIR
if [[ -f "$FASTQ_PTR_FILE" ]]; then
    FASTQ_DIR="$(cat "$FASTQ_PTR_FILE")"
else
    FASTQ_DIR="$DEFAULT_FASTQ_DIR"
fi


# Output file
OUTPUT_FILE="$HOME/Metabarcoding/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt"

# Basic validation
if [[ -z "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ_DIR is empty (this should never happen)."
    exit 1
fi

if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ directory not found: $FASTQ_DIR"
    echo "Expected either:"
    echo "  - $DEFAULT_FASTQ_DIR"
    echo "  - or a valid path in $FASTQ_PTR_FILE"
    exit 1
fi

echo "Using FASTQ directory: $FASTQ_DIR"

#################################
#  ASK USER ABOUT MULTIPLE RUNS
#################################
echo "Did you sequence samples using multiple sequencing runs? [yes/no]"
read multi_runs

if [[ "$multi_runs" =~ ^([Nn][Oo])$ ]]; then
    RUN_VALUE="A"
    echo "All samples will be assigned to run 'A'."
elif [[ "$multi_runs" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
    RUN_VALUE=""
    echo "NOTE: You will need to manually edit the 'run' column in the samplesheet."
    echo "Use letters (e.g., A, B, etc.) to distinguish sequencing runs."
else
    echo "Invalid response. Please answer yes or no."
    exit 1
fi

#################################
#  HEADER
#################################
echo -e "sampleID\tforwardReads\treverseReads\trun" > "$OUTPUT_FILE"

##############################################
# ASK USER HOW TO PARSE sampleID FROM FASTQ  #
##############################################
echo
echo "How should sampleID be extracted from FASTQ filenames?"
echo "  1) Text before the first underscore (e.g., B12A1_02_4... -> B12A1)"
echo "  2) First TWO underscore-separated fields (e.g., B12A1_02_4... -> B12A1_02)"
echo "  3) Custom awk fields (advanced; e.g. '{print \$1\"_\"\$2\"_\"\$3}')"
read -rp "Choose [1/2/3] (default 1): " PARSE_CHOICE
PARSE_CHOICE="${PARSE_CHOICE:-1}"

CUSTOM_AWK_EXPR=""
if [[ "$PARSE_CHOICE" == "3" ]]; then
  echo "Enter an awk print expression (do NOT include -F'_')."
  echo "Example: {print \$1\"_\"\$2}"
  read -rp "awk expression: " CUSTOM_AWK_EXPR
  if [[ -z "$CUSTOM_AWK_EXPR" ]]; then
    echo "ERROR: custom awk expression cannot be empty."
    exit 1
  fi
fi

extract_sample_id() {
    local filename="$1"

    # Remove read suffix (works for *_R1_001.fastq.gz)
    local base="${filename%_R1_001.fastq.gz}"

    case "$PARSE_CHOICE" in
      1)
        # First field before first underscore
        echo "$base" | awk -F'_' '{print $1}'
        ;;
      2)
        # First TWO underscore-separated fields
        echo "$base" | awk -F'_' '{print $1"_"$2}'
        ;;
      3)
        # Custom awk expression
        echo "$base" | awk -F'_' "$CUSTOM_AWK_EXPR"
        ;;
      *)
        echo "ERROR: Invalid parsing choice: $PARSE_CHOICE" >&2
        exit 1
        ;;
    esac
}


#################################
#  PROCESS FASTQ FILES
#################################
shopt -s nullglob # Sometimes bash shell can print literal name, with wildcards, if no files match. With this, if no files match, the patter expands to nothing.
for fwd in "$FASTQ_DIR"/*_R1_001.fastq.gz; do
    fname=$(basename "$fwd")
    sampleID=$(extract_sample_id "$fname")

    sample_prefix="${fname%_R1_001.fastq.gz}"
    rev="$FASTQ_DIR/${sample_prefix}_R2_001.fastq.gz"

    if [[ ! -f "$rev" ]]; then
        rev=""
    fi

    echo -e "${sampleID}\t$fwd\t$rev\t${RUN_VALUE}" >> "$OUTPUT_FILE"
done
shopt -u nullglob # Restore bash

#################################
#  VALIDATE + OPTIONAL AUTO-FIX SAMPLE IDs
#################################
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# Collect issues
bad_start=$(awk -F'\t' 'NR>1 && $1 !~ /^[A-Za-z]/ {print $1}' "$OUTPUT_FILE" | sort -u)
dups=$(awk -F'\t' 'NR>1 {print $1}' "$OUTPUT_FILE" | sort | uniq -d)

FIX_INVALID="none"   # strip | prefix | none
FIX_DUPS="no"        # yes | no

if [[ -n "$bad_start" ]]; then
  echo
  echo "WARNING: Sample IDs must start with a letter (A-Z/a-z). These samples do not:"
  echo "$bad_start" | sed 's/^/  - /'
  echo
  echo "Choose how to fix these:"
  echo "  1) Strip leading non-letters until the ID starts with a letter (e.g. 12ABC -> ABC)"
  echo "  2) Add the prefix 'A_' to any ID that does not start with a letter (e.g. 12ABC -> A_12ABC)"
  echo "  3) Abort and let me fix filenames/parsing"
  read -rp "Choice [1/2/3] (default 1): " c
  c="${c:-1}"
  case "$c" in
    1) FIX_INVALID="strip" ;;
    2) FIX_INVALID="prefix" ;;
    3) echo "Aborting."; exit 1 ;;
    *) echo "Invalid choice."; exit 1 ;;
  esac
fi


if [[ -n "$dups" ]]; then
  echo
  echo "WARNING: Sample IDs must be unique. These duplicate sample IDs were detected:"
  echo "$dups" | sed 's/^/  - /'
  echo
  echo "Choose how to proceed:"
  echo "  1) Automatically make them unique by appending (_1, _2, _3, ...) (e.g. Sample, Sample -> Sample, Sample_1)"
  echo "  2) Abort and let me fix filenames/parsing"
  read -rp "Choice [1/2] (default 1): " d
  d="${d:-1}"
  case "$d" in
    1) FIX_DUPS="yes" ;;
    2)
       echo "Aborting so you can adjust parsing or filenames."
       exit 1
       ;;
    *)
       echo "Invalid choice."
       exit 1
       ;;
  esac
fi

# If nothing to fix, skip
if [[ "$FIX_INVALID" == "none" && "$FIX_DUPS" == "no" ]]; then
  : # no-op
else
  echo
  echo "Applying fixes to sampleIDs..."

  awk -F'\t' -v OFS='\t' \
      -v fix_invalid="$FIX_INVALID" \
      -v fix_dups="$FIX_DUPS" \
  '
  NR==1 { print; next }

  {
    id = $1

    # ---- Fix IDs that do not start with a letter ----
    if (fix_invalid == "strip") {
      sub(/^[^A-Za-z]+/, "", id)       # remove leading non-letters
      # If stripping removed everything or still not starting with a letter, prefix A_
      if (id == "" || id !~ /^[A-Za-z]/) id = "A_" id
    } else if (fix_invalid == "prefix") {
      if (id !~ /^[A-Za-z]/) id = "A_" id
    }

    # Track invalid-after-fix
    if (id !~ /^[A-Za-z]/) bad[id] = 1

    # ---- Ensure uniqueness if requested ----
    if (fix_dups == "yes") {
      base = id
      new  = id
      if (new in used) {
        i = 1
        while ((base "_" i) in used) i++
        new = base "_" i
      }
      used[new] = 1
      id = new
    } else {
      # if not fixing duplicates here, just track them
      if (id in used) dup[id] = 1
      used[id] = 1
    }

    $1 = id
    print
  }

  END {
    # If we still have bad starts after fixing, exit nonzero
    for (k in bad) { exitcode = 2 }
    # If duplicates remain and we didnt fix them, exit nonzero
    for (k in dup) { exitcode = 3 }
    exit exitcode
  }
  ' "$OUTPUT_FILE" > "$tmpfile"

  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "ERROR: Could not safely fix sampleIDs."
    echo "Some IDs may still be invalid or duplicates remain."
    echo "No changes were written."
    exit 1
  fi

  mv "$tmpfile" "$OUTPUT_FILE"
fi

# Final re-check (must be letter-start + unique)
bad_start2=$(awk -F'\t' 'NR>1 && $1 !~ /^[A-Za-z]/ {print $1}' "$OUTPUT_FILE" | sort -u)
dups2=$(awk -F'\t' 'NR>1 {print $1}' "$OUTPUT_FILE" | sort | uniq -d)

if [[ -n "$bad_start2" ]]; then
  echo "ERROR: After fixing, some sampleIDs still do not start with a letter:"
  echo "$bad_start2" | sed 's/^/  - /'
  exit 1
fi

if [[ -n "$dups2" ]]; then
  echo "ERROR: After fixing, duplicate sampleIDs still exist:"
  echo "$dups2" | sed 's/^/  - /'
  exit 1
fi


echo "Sample sheet written to: $OUTPUT_FILE"
