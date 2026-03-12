#!/bin/bash
set -euo pipefail

RUN_MAP_TMP=""
tmpfile=""

cleanup() {
  rm -f "${RUN_MAP_TMP:-}" "${tmpfile:-}"
}
trap cleanup EXIT

# Read project name
PROJECT_NAME=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt")

# Default FASTQ directory
FASTQ_DIR=$(cat "/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/fastq_storage_path.txt")

# Output file
OUTPUT_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input/${PROJECT_NAME}_samplesheet.txt"

# Basic validation
if [[ -z "${FASTQ_DIR:-}" ]]; then
    echo "ERROR: FASTQ_DIR is empty (this should never happen)."
    exit 1
fi

if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "ERROR: FASTQ directory not found: $FASTQ_DIR"
    exit 1
fi

echo "Using FASTQ directory: $FASTQ_DIR"

# Require gzipped FASTQ files only
if compgen -G "$FASTQ_DIR/*_R1.fastq" > /dev/null || \
   compgen -G "$FASTQ_DIR/*_R2.fastq" > /dev/null || \
   compgen -G "$FASTQ_DIR/*_R1_001.fastq" > /dev/null || \
   compgen -G "$FASTQ_DIR/*_R2_001.fastq" > /dev/null; then
    echo "ERROR: Uncompressed .fastq files were found in $FASTQ_DIR."
    echo "This pipeline requires gzipped FASTQ files ending in .fastq.gz"
    echo "Please gzip the FASTQ files and re-run."
    exit 1
fi

#################################
#  ASK USER ABOUT MULTIPLE RUNS
#################################
RUN_VALUE="A"
USE_METADATA_RUNS="no"

echo "Did you sequence samples using multiple sequencing runs? [yes/no]"
read -r multi_runs

if [[ "$multi_runs" =~ ^([Nn][Oo])$ ]]; then
    RUN_VALUE="A"
    USE_METADATA_RUNS="no"
    echo "All samples will be assigned to run 'A'."
elif [[ "$multi_runs" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
    RUN_VALUE=""
    USE_METADATA_RUNS="yes"
    echo "Multiple runs selected."
    echo "The script will attempt to auto-assign runs from a metadata file in:"
    echo "  /group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input"
    echo "Looking for a .txt or .tsv file with 'metadata' in the filename."
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
    local base=""

    if [[ "$filename" == *_R1_001.fastq.gz ]]; then
        base="${filename%_R1_001.fastq.gz}"
    elif [[ "$filename" == *_R1.fastq.gz ]]; then
        base="${filename%_R1.fastq.gz}"
    else
        echo "ERROR: Unrecognized forward-read filename format: $filename" >&2
        echo "Expected *_R1.fastq.gz or *_R1_001.fastq.gz" >&2
        return 1
    fi

    case "$PARSE_CHOICE" in
      1)
        echo "$base" | awk -F'_' '{print $1}'
        ;;
      2)
        echo "$base" | awk -F'_' '{print $1"_"$2}'
        ;;
      3)
        echo "$base" | awk -F'_' "$CUSTOM_AWK_EXPR"
        ;;
      *)
        echo "ERROR: Invalid parsing choice: $PARSE_CHOICE" >&2
        exit 1
        ;;
    esac
}

##############################################
#  METADATA RUN MAPPING (only if multi-runs) #
##############################################
META_RUN_MAP_FILE=""
META_INPUT_DIR="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME/input"

# Store a map: sampleID -> letter (A/B/C...) in this temp file
RUN_MAP_TMP="$(mktemp)"

build_run_map_from_metadata() {
  local metadir="$1"

  local meta_candidates=()
  while IFS= read -r -d '' f; do
    meta_candidates+=("$f")
  done < <(find "$metadir" -maxdepth 1 -type f \( -iname '*metadata*.txt' -o -iname '*metadata*.tsv' \) -print0 2>/dev/null)

  if [[ ${#meta_candidates[@]} -eq 0 ]]; then
    echo "WARNING: Could not find a metadata .txt/.tsv file with 'metadata' in the name in:"
    echo "  $metadir"
    return 1
  fi

  local newest=""
  newest="$(ls -t "${meta_candidates[@]}" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$newest" ]]; then
    echo "WARNING: Found metadata candidates but could not select one."
    return 1
  fi

  META_RUN_MAP_FILE="$newest"
  echo "Using metadata file for run assignment: $META_RUN_MAP_FILE"

  awk -F'\t' -v OFS='\t' '
    function trim(s){ gsub(/^[ \r]+|[ \r]+$/, "", s); return s }
    BEGIN { letters="ABCDEFGHIJKLMNOPQRSTUVWXYZ" }

    NR==1 {
      for (i=1; i<=NF; i++) {
        h  = trim($i)
        hl = tolower(h)

        if (hl == "run") run_col=i

        if (hl == "sampleid" || hl == "sample_id" || hl == "sample" || hl == "id" || hl == "sample name" || hl == "samplename") {
          if (!sid_col) sid_col=i
        }
      }

      if (!run_col) { print "MISSING_RUN_COL" > "/dev/stderr"; exit 10 }
      if (!sid_col) sid_col=1
      next
    }

    NR>1 {
      sid = trim($(sid_col))
      r   = trim($(run_col))

      if (sid=="") next

      if (r=="") {
        print "EMPTY_RUN_VALUE at sample: " sid > "/dev/stderr"
        exit 12
      }

      if (!(r in run_to_letter)) {
        idx = ++run_count
        if (idx > length(letters)) { print "TOO_MANY_RUNS" > "/dev/stderr"; exit 11 }
        run_to_letter[r] = substr(letters, idx, 1)
      }

      print sid, run_to_letter[r]
    }
  ' "$META_RUN_MAP_FILE" > "$RUN_MAP_TMP"

  local rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ $rc -eq 10 ]]; then
      echo "WARNING: Metadata file does not contain a 'Run' column. Cannot auto-assign runs."
    elif [[ $rc -eq 11 ]]; then
      echo "WARNING: Metadata has >26 distinct Run values (A-Z). Cannot auto-assign runs."
    elif [[ $rc -eq 12 ]]; then
      echo "ERROR: Metadata contains blank cells in the 'Run' column."
      echo "Please fill in all Run values."
      return 1
    else
      echo "WARNING: Failed to parse metadata for run assignment."
    fi
    return 1
  fi

  if [[ ! -s "$RUN_MAP_TMP" ]]; then
    echo "WARNING: No (sampleID, Run) pairs were extracted from metadata. Cannot auto-assign runs."
    return 1
  fi

  return 0
}

if [[ "$USE_METADATA_RUNS" == "yes" ]]; then
  if ! build_run_map_from_metadata "$META_INPUT_DIR"; then
    echo "NOTE: Falling back to a blank 'Run' column. You will need to edit runs manually by assigning samples a run ID (i.e., A, B, C, ...) in the 'Run' column of your samplesheet or fix errors and re-run."
    USE_METADATA_RUNS="no"
    RUN_VALUE=""
  else
    echo "Run assignments will be pulled from metadata and re-assigned to run IDs 'A, B, C, ...'."
  fi
fi

#################################
#  PROCESS FASTQ FILES
#################################
shopt -s nullglob

found_fastq="no"

for fwd in \
    "$FASTQ_DIR"/*_R1_001.fastq.gz \
    "$FASTQ_DIR"/*_R1.fastq.gz
do
    [[ -e "$fwd" ]] || continue
    found_fastq="yes"

    fname=$(basename "$fwd")
    sampleID=$(extract_sample_id "$fname") || exit 1

    if [[ "$fname" == *_R1_001.fastq.gz ]]; then
        sample_prefix="${fname%_R1_001.fastq.gz}"
        rev="$FASTQ_DIR/${sample_prefix}_R2_001.fastq.gz"
    elif [[ "$fname" == *_R1.fastq.gz ]]; then
        sample_prefix="${fname%_R1.fastq.gz}"
        rev="$FASTQ_DIR/${sample_prefix}_R2.fastq.gz"
    else
        echo "WARNING: Skipping unrecognized file: $fname" >&2
        continue
    fi

    if [[ ! -f "$rev" ]]; then
        echo "ERROR: Missing reverse read for forward file: $fwd" >&2
        echo "Expected reverse file: $rev" >&2
        exit 1
    fi

    run_out="$RUN_VALUE"
    if [[ "$USE_METADATA_RUNS" == "yes" ]]; then
      run_out="$(awk -F'\t' -v sid="$sampleID" '$1==sid {print $2; found=1; exit} END{ if(!found) print "" }' "$RUN_MAP_TMP")"
      if [[ -z "$run_out" ]]; then
        echo "WARNING: sampleID '$sampleID' not found in metadata run map; leaving run blank for this sample." >&2
      fi
    fi

    echo -e "${sampleID}\t$fwd\t$rev\t${run_out}" >> "$OUTPUT_FILE"
done

shopt -u nullglob

if [[ "$found_fastq" != "yes" ]]; then
    echo "ERROR: No gzipped forward FASTQ files were found in $FASTQ_DIR"
    echo "Expected files matching *_R1.fastq.gz or *_R1_001.fastq.gz"
    exit 1
fi

#################################
#  VALIDATE + OPTIONAL AUTO-FIX SAMPLE IDs
#################################
tmpfile="$(mktemp)"

# Collect issues
bad_start=$(awk -F'\t' 'NR>1 && $1 !~ /^[A-Za-z]/ {print $1}' "$OUTPUT_FILE" | sort -u)
dups=$(awk -F'\t' 'NR>1 {print $1}' "$OUTPUT_FILE" | sort | uniq -d)

FIX_INVALID="none"
FIX_DUPS="no"

if [[ -n "$bad_start" ]]; then
  echo
  echo "WARNING: Sample IDs must start with a letter (A-Z/a-z). These samples do not:"
  echo "$bad_start" | sed 's/^/  - /'
  echo
  echo "Choose how to fix these:"
  echo "  1) Strip leading non-letters until the ID starts with a letter (e.g. 12ABC -> ABC)"
  echo "  2) Add the prefix 'A_' to any ID that does not start with a letter (e.g. 12ABC -> A_12ABC)"
  echo "  3) Abort and let me fix filenames/parsing"
  read -rp "Choice [1/2/3] (default 2): " c
  c="${c:-2}"
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

if [[ "$FIX_INVALID" != "none" || "$FIX_DUPS" != "no" ]]; then
  echo
  echo "Applying fixes to sampleIDs..."

  awk -F'\t' -v OFS='\t' \
      -v fix_invalid="$FIX_INVALID" \
      -v fix_dups="$FIX_DUPS" \
  '
  NR==1 { print; next }

  {
    id = $1

    if (fix_invalid == "strip") {
      sub(/^[^A-Za-z]+/, "", id)
      if (id == "" || id !~ /^[A-Za-z]/) id = "A_" id
    } else if (fix_invalid == "prefix") {
      if (id !~ /^[A-Za-z]/) id = "A_" id
    }

    if (id !~ /^[A-Za-z]/) bad[id] = 1

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
      if (id in used) dup[id] = 1
      used[id] = 1
    }

    $1 = id
    print
  }

  END {
    for (k in bad) { exitcode = 2 }
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
  tmpfile=""
fi

# Final re-check
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