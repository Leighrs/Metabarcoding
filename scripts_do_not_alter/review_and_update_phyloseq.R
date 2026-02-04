#!/usr/bin/env Rscript

Sys.setenv(TZ = "UTC")

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(phyloseq)
  library(openxlsx)
  library(Biostrings)
})

# ----------------------------
# Helper functions
# ----------------------------
norm_decision <- function(x) {
  x0 <- trimws(as.character(x))
  if (is.na(x0) || x0 == "") return("approved")
  x <- tolower(x0)
  if (x %in% c("n","no","disapprove","disapproved","reject","rejected","false","f","0")) return("disapproved")
  if (x %in% c("y","yes","approve","approved","true","t","1")) return("approved")
  "disapproved"
}

norm_remove <- function(x) {
  x0 <- trimws(as.character(x))
  if (is.na(x0) || x0 == "") return("keep")
  x <- tolower(x0)
  if (x %in% c("y","yes","remove","removed","true","t","1")) return("remove")
  "keep"
}

stop_if_missing <- function(x, name) {
  if (is.null(x) || !nzchar(x)) stop("Missing required env var: ", name, call. = FALSE)
}

pick_first_col <- function(cols, candidates) {
  hit <- candidates[candidates %in% cols][1]
  if (is.na(hit) || !nzchar(hit)) return(NA_character_)
  hit
}

rank_to_taxcol <- function(rank_value, tax_cols_all) {
  if (is.null(rank_value) || is.na(rank_value)) return(NA_character_)
  rv <- tolower(trimws(as.character(rank_value)))
  if (!nzchar(rv)) return(NA_character_)

  rv <- gsub("\\s+", "", rv)
  rv <- gsub("\\.", "", rv)

  if (rv %in% c("kingdom")) return(pick_first_col(tax_cols_all, c("Kingdom","kingdom","KINGDOM")))
  if (rv %in% c("phylum"))  return(pick_first_col(tax_cols_all, c("Phylum","phylum","PHYLUM")))
  if (rv %in% c("class"))   return(pick_first_col(tax_cols_all, c("Class","class","CLASS")))
  if (rv %in% c("order"))   return(pick_first_col(tax_cols_all, c("Order","order","ORDER")))
  if (rv %in% c("family"))  return(pick_first_col(tax_cols_all, c("Family","family","FAMILY")))
  if (grepl("kingdom", rv)) return(pick_first_col(tax_cols_all, c("Kingdom","kingdom","KINGDOM")))
  if (grepl("phylum",  rv)) return(pick_first_col(tax_cols_all, c("Phylum","phylum","PHYLUM")))
  if (grepl("class",   rv)) return(pick_first_col(tax_cols_all, c("Class","class","CLASS")))
  if (grepl("order",   rv)) return(pick_first_col(tax_cols_all, c("Order","order","ORDER")))
  if (grepl("family",  rv)) return(pick_first_col(tax_cols_all, c("Family","family","FAMILY")))
  if (grepl("genus",   rv)) return(pick_first_col(tax_cols_all, c("Genus","genus","GENUS")))
  if (grepl("species|\\bsp\\b", rv)) return(pick_first_col(tax_cols_all, c("Species","species","SPECIES")))
  NA_character_
}

get_rank_order <- function(tax_cols_rank) {
  preferred <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species")
  out <- character(0)
  for (p in preferred) {
    hit <- tax_cols_rank[tolower(tax_cols_rank) == tolower(p)]
    if (length(hit) > 0) out <- c(out, hit[1])
  }
  if (length(out) == 0) return(tax_cols_rank)
  out
}
# If phyloseq object is missing:

suppressPackageStartupMessages({
  library(phyloseq)
  library(Biostrings)
})

read_tsv <- function(path) {
  read.delim(path, header = TRUE, sep = "\t", check.names = FALSE, stringsAsFactors = FALSE)
}

make_phyloseq_from_dada2_table <- function(dada2_table_tsv, metadata_tsv) {
  if (!file.exists(dada2_table_tsv)) stop("Missing DADA2 table: ", dada2_table_tsv, call.=FALSE)
  if (!file.exists(metadata_tsv))    stop("Missing metadata: ", metadata_tsv, call.=FALSE)

  tab <- read_tsv(dada2_table_tsv)

  # --- require ASV_ID column ---
  if (!("ASV_ID" %in% names(tab))) {
    stop("DADA2_table.tsv must contain an 'ASV_ID' column. Found: ",
         paste(names(tab), collapse = ", "), call.=FALSE)
  }

  asv_ids <- as.character(tab$ASV_ID)
  if (any(!nzchar(asv_ids))) stop("Some ASV_ID values are empty.", call.=FALSE)

  rownames(tab) <- make.unique(asv_ids)
  tab$ASV_ID <- NULL

  # --- handle sequence column if present ---
  seqs <- NULL
  if ("sequence" %in% names(tab)) {
    seqs <- as.character(tab$sequence)
    names(seqs) <- rownames(tab)
    tab$sequence <- NULL
  }

  # remaining columns should be samples
  otu_mat <- as.matrix(tab)
  mode(otu_mat) <- "numeric"

  # --- metadata ---
meta <- read_tsv(metadata_tsv)

# Prefer an explicit ID column if present
id_col <- NULL
for (cand in c("ID", "SampleID", "Sample_ID", "sample_id", "sample", "Sample")) {
  if (cand %in% names(meta)) { id_col <- cand; break }
}

if (!is.null(id_col)) {
  rownames(meta) <- make.unique(as.character(meta[[id_col]]))
  meta[[id_col]] <- NULL
} else {
  # fallback: first column
  rownames(meta) <- make.unique(as.character(meta[[1]]))
  meta[[1]] <- NULL
}

# Trim whitespace just in case
rownames(meta) <- trimws(rownames(meta))
colnames(meta) <- trimws(colnames(meta))


  shared_samples <- intersect(colnames(otu_mat), rownames(meta))
  if (length(shared_samples) == 0) {
    stop(
      "No overlapping sample names between DADA2 table columns and metadata rownames.\n",
      "DADA2 table samples: ", paste(head(colnames(otu_mat)), collapse = ", "), "\n",
      "Metadata samples: ", paste(head(rownames(meta)), collapse = ", "),
      call.=FALSE
    )
  }

  otu_mat <- otu_mat[, shared_samples, drop = FALSE]
  meta <- meta[shared_samples, , drop = FALSE]

  ps <- phyloseq(
    otu_table(otu_mat, taxa_are_rows = TRUE),
    sample_data(meta)
  )


  # --- create placeholder taxonomy table (so your downstream code finds Species/etc.) ---
  rank_cols <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species","Common","confidence","ASV_sequence")
  tax_stub <- matrix("", nrow = ntaxa(ps), ncol = length(rank_cols))
  rownames(tax_stub) <- taxa_names(ps)
  colnames(tax_stub) <- rank_cols

  if (!is.null(seqs)) tax_stub[names(seqs), "ASV_sequence"] <- seqs

  tax_table(ps) <- tax_table(tax_stub)

  ps
}


# ----------------------------
# README text
# ----------------------------
readme_lines <- c(
  "Review Sheet (BLAST Assignments)",
  "",
  "This workbook supports manual review of BLAST-based taxonomic assignments.",
  "",
  "Tabs:",
  "  - For_Review: ASVs that met BLAST thresholds and require manual review.",
  "  - Excluded_by_BLAST: ASVs that were BLASTed but did not meet thresholds (i.e., % identity, e-value, query cov) and while be removed from your phyloseq object.",
  "  - Excluded_by_Reviewer (available after review process): ASVs removed after review (Remove_ASV == yes OR incomplete taxonomy levels after review).",
  "",
  "For_Review Tab Contents:",
  "  - Columns E-L: Current taxonomic assignments produced by the nf-core/ampliseq pipeline, using your custom RSD.",
  "    - If you did get nf-core/ampliseq to assign taxonomy, these will be blank.",
  "  - Columns M-T: Proposed taxonomic assignments generated from BLAST.",
  "  - Column U: Approval of BLAST assignmment.",
  "    - Do you agree with the BLAST taxonomic assignments (columns M-T)?",
  "      - Yes (leave blank): Use this if you agree with the assignment, even if some taxonomic levels are missing.",
  "      - No (enter 'no'): Ise this if you disagree with the assignment. For example:",
  "        - BLAST assigned the ASV as Species A, but you know it should be Species B (which may not exist in NCBI).",
  "        - BLAST assigned the ASV at the species level, but your barcode cannot reliably distinguish species and should only be assigned to genus.",
  "  - Column V: If you disapprove, provide a brief explanation here.",  
  "  - Column W: Do you want to remove this ASV from your phyloseq object?.", 
  "      - No (leave blank).",
  "      - Yes (enter 'yes').",
  "  - Columns X-AE: Manual overrides:",
  "    - You may manually override taxonomic assignments in these columns, regardless of whether you approved or disapproved of the BLAST assignment.",
  "      - Use these to fill missing taxonomic levels, add common names, or correct specific ranks.",
  "      - If any taxonomic ranks remain empty, that ASV will be removed from your phyloseq object.",
  "      - If you approved of BLAST results that are above the species level, then lower ranks will auto-fill as <Final_Taxon> spp unless you override them.",
  "        - For example, you approved of an ASV that BLAST assigned as Cottidae (family level), then the remaining genus and species level will autofill to `Cottidae spp` unless you override it.", 
  "  - Notes:",
  "    - If you dissapprove in Column U, but do not override ANY taxa levels in columns X-AE, then all rank columns will be set to 'unknown'.",
  "    - If you dissapprove in Column U, and make overrides, the condifence level for that ASV assignment will be set to 'overridden'."
  
)

# ----------------------------
# Inputs (env vars)
# ----------------------------
PROJECT_NAME <- Sys.getenv("PROJECT_NAME", unset = "")
stop_if_missing(PROJECT_NAME, "PROJECT_NAME")

PROJECT_DIR <- Sys.getenv("PROJECT_DIR", unset = file.path(Sys.getenv("HOME"), "Metabarcoding", PROJECT_NAME))

BLAST_FILE <- Sys.getenv(
  "LCTR_TSV",
  unset = file.path(PROJECT_DIR, "output", "BLAST", paste0(PROJECT_NAME, "_final_LCTR_taxonomy_with_ranks.tsv"))
)

PHYLOSEQ_RDS <- Sys.getenv("PHYLOSEQ_RDS", unset = "")
stop_if_missing(PHYLOSEQ_RDS, "PHYLOSEQ_RDS")

OUT_DIR <- Sys.getenv("REVIEW_OUTDIR", unset = "")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
stop_if_missing(OUT_DIR, "REVIEW_OUTDIR")

review_xlsx <- file.path(OUT_DIR, paste0(PROJECT_NAME, "_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx"))
reviewed_assignments_tsv <- file.path(OUT_DIR, paste0(PROJECT_NAME, "_reviewed_assignments.tsv"))
updated_phyloseq_rds <- file.path(OUT_DIR, paste0("phyloseq_", PROJECT_NAME, "_UPDATED_reviewed_taxonomy.rds"))

UNASSIGNED_FASTA <- Sys.getenv(
  "UNASSIGNED_FASTA",
  unset = file.path(PROJECT_DIR, "output", "R", paste0(PROJECT_NAME, "_DADA2_unassigned_ASVs.fasta"))
)

is_resume <- file.exists(review_xlsx)

user <- Sys.getenv("USER", unset = "")
stop_if_missing(user, "USER")

host <- farm

if (!file.exists(BLAST_FILE)) stop("Cannot find BLAST taxonomy file: ", BLAST_FILE, call. = FALSE)

# ----------------------------
# Load or create phyloseq
# ----------------------------

if (!file.exists(PHYLOSEQ_RDS)) {
  ASV_TABLE_TSV <- Sys.getenv("ASV_TABLE_TSV", unset = "")
  METADATA_TSV  <- Sys.getenv("METADATA_TSV", unset = "")

  stop_if_missing(ASV_TABLE_TSV, "ASV_TABLE_TSV")
  stop_if_missing(METADATA_TSV,  "METADATA_TSV")

  message("PHYLOSEQ_RDS not found. Creating phyloseq from DADA2 table + metadata...")
  ps <- make_phyloseq_from_dada2_table(ASV_TABLE_TSV, METADATA_TSV)

  dir.create(dirname(PHYLOSEQ_RDS), recursive = TRUE, showWarnings = FALSE)

  saveRDS(ps, PHYLOSEQ_RDS)
  message("Saved new phyloseq object to: ", PHYLOSEQ_RDS)

  message("Saved new phyloseq object to: ", PHYLOSEQ_RDS)
} else {
  ps <- readRDS(PHYLOSEQ_RDS)
  if (!inherits(ps, "phyloseq")) {
    stop("Loaded object is not a phyloseq object: ", PHYLOSEQ_RDS, call.=FALSE)
  }
}


tax <- tax_table(ps)
tax_mat <- as(tax, "matrix")
tax_cols_all <- colnames(tax_mat)

tax_cols_taxrank <- intersect(tax_cols_all, c("Kingdom","Phylum","Class","Order","Family","Genus","Species"))
editable_cols <- unique(c(tax_cols_taxrank, "Common"))
editable_cols <- intersect(editable_cols, tax_cols_all)

SPECIES_COL <- pick_first_col(tax_cols_all, c("Species", "species", "SPECIES"))
if (is.na(SPECIES_COL)) {
  stop("Could not find a Species column in tax_table(ps). Columns are: ",
       paste(tax_cols_all, collapse = ", "),
       call. = FALSE)
}

CONF_COL <- pick_first_col(tax_cols_all, c("confidence","Confidence","CONFIDENCE"))
SEQ_COL  <- pick_first_col(tax_cols_all, c("ASV_sequence", "asv_sequence", "Sequence", "sequence"))

tax_cols_rank <- editable_cols
override_cols <- paste0("Override_", editable_cols)
rank_order <- get_rank_order(tax_cols_taxrank)

# ----------------------------
# Step 1: Build the REVIEW workbook (first run only)
# ----------------------------
df <- read.delim(
  BLAST_FILE,
  sep = "\t",
  header = TRUE,
  check.names = FALSE,
  stringsAsFactors = FALSE
)

taxm0 <- as(tax_table(ps), "matrix")

current_cols <- intersect(c("Kingdom","Phylum","Class","Order","Family","Genus","Species","Common"), colnames(taxm0))
for (cc in current_cols) {
  newcol <- paste0("Current_", cc)
  if (!newcol %in% names(df)) df[[newcol]] <- ""
}

in_ps <- intersect(df$ASV, rownames(taxm0))
if (length(in_ps) > 0) {
  idx_df <- match(in_ps, df$ASV)
  for (cc in current_cols) {
    df[idx_df, paste0("Current_", cc)] <- as.character(taxm0[in_ps, cc])
  }
}
current_front <- paste0("Current_", current_cols)

# Proposed preview
if ("Final_Taxon" %in% names(df)) {
  proposed_cols <- intersect(c("Kingdom","Phylum","Class","Order","Family","Genus","Species","Common"), colnames(taxm0))
  for (pc in proposed_cols) {
    newcol <- paste0("Proposed_", pc)
    if (!newcol %in% names(df)) df[[newcol]] <- ""
  }
  for (pc in proposed_cols) df[[paste0("Proposed_", pc)]] <- df[[paste0("Current_", pc)]]

  has_rank <- "Final_Taxon_Rank" %in% names(df)
  for (i in seq_len(nrow(df))) {
    blast_taxon <- as.character(df$Final_Taxon[i])
    if (is.na(blast_taxon) || !nzchar(trimws(blast_taxon))) next

    blast_rank_col <- SPECIES_COL
    if (has_rank) {
      tmp <- rank_to_taxcol(df$Final_Taxon_Rank[i], tax_cols_all)
      if (!is.na(tmp)) blast_rank_col <- tmp
    }

    df[i, paste0("Proposed_", blast_rank_col)] <- blast_taxon

    if (blast_rank_col %in% rank_order) {
      idx <- match(blast_rank_col, rank_order)
      if (!is.na(idx) && idx < length(rank_order)) {
        lower_cols <- rank_order[(idx + 1):length(rank_order)]
        filler <- paste0(blast_taxon, " spp")
        for (lc in lower_cols) {
          cell <- df[i, paste0("Proposed_", lc)]
          cell <- ifelse(is.na(cell), "", as.character(cell))
          if (!nzchar(trimws(cell))) df[i, paste0("Proposed_", lc)] <- filler
        }
      }
    }
  }
} else {
  proposed_cols <- character(0)
}

if (!("Approve" %in% names(df))) df$Approve <- ""
if (!("Disapprove_Reason" %in% names(df))) df$Disapprove_Reason <- ""
if (!("Remove_ASV" %in% names(df))) df$Remove_ASV <- ""

for (oc in override_cols) if (!(oc %in% names(df))) df[[oc]] <- ""

proposed_front <- paste0("Proposed_", proposed_cols)

preferred_front <- intersect(
  c("ASV","ASV_sequence","Final_Taxon","Final_Taxon_Rank", current_front, proposed_front),
  names(df)
)

wanted_front <- unique(c(
  preferred_front,
  "Approve", "Disapprove_Reason", "Remove_ASV",
  override_cols
))
wanted_front <- intersect(wanted_front, names(df))
rest <- setdiff(names(df), wanted_front)
df <- df[, c(wanted_front, rest), drop = FALSE]

# Build excluded_by_blast_df for the workbook (used in both runs later)
excluded_by_blast_df <- data.frame(ASV = character(0), Sequence = character(0), Length = integer(0), stringsAsFactors = FALSE)

if (file.exists(UNASSIGNED_FASTA)) {
  unassigned_seqs <- tryCatch(readDNAStringSet(UNASSIGNED_FASTA, format = "fasta"), error = function(e) NULL)
  if (!is.null(unassigned_seqs) && length(unassigned_seqs) > 0) {
    unassigned_ids <- names(unassigned_seqs)
    unassigned_ids <- unassigned_ids[nzchar(unassigned_ids)]

    review_ids <- if ("ASV" %in% names(df)) as.character(df$ASV) else character(0)
    excluded_ids <- setdiff(unassigned_ids, review_ids)

    if (length(excluded_ids) > 0) {
      excluded_seqs <- unassigned_seqs[excluded_ids]
      excluded_by_blast_df <- data.frame(
        ASV = excluded_ids,
        Sequence = as.character(excluded_seqs),
        Length = nchar(as.character(excluded_seqs)),
        stringsAsFactors = FALSE
      )
    }
  }
}

if (!is_resume) {
  wb <- createWorkbook()

  addWorksheet(wb, "README")
  writeData(wb, "README", data.frame(README = readme_lines), colNames = FALSE)
  setColWidths(wb, "README", cols = 1, widths = 120)
  freezePane(wb, "README", firstRow = TRUE)
  addStyle(
    wb, "README",
    style = createStyle(wrapText = TRUE, valign = "top"),
    rows = 1:length(readme_lines),
    cols = 1,
    gridExpand = TRUE,
    stack = TRUE
  )

  addWorksheet(wb, "For_Review")
  writeData(wb, "For_Review", df, withFilter = TRUE)
  freezePane(wb, "For_Review", firstRow = TRUE)
  setColWidths(wb, "For_Review", cols = 1:ncol(df), widths = "auto")
  addStyle(wb, "For_Review", style = createStyle(textDecoration = "bold"), rows = 1, cols = 1:ncol(df), gridExpand = TRUE)

  approve_col <- match("Approve", names(df))
  reason_col  <- match("Disapprove_Reason", names(df))
  remove_col  <- match("Remove_ASV", names(df))

  approve_letter <- if (!is.na(approve_col)) int2col(approve_col) else NA_character_
  reason_letter  <- if (!is.na(reason_col))  int2col(reason_col)  else NA_character_
  remove_letter  <- if (!is.na(remove_col))  int2col(remove_col)  else NA_character_

  if (!is.na(approve_col)) {
    dataValidation(wb, "For_Review", cols = approve_col, rows = 2:(nrow(df)+1),
                   type = "list", value = '"no"', allowBlank = TRUE, showInputMsg = TRUE)
  }
  if (!is.na(remove_col)) {
    dataValidation(wb, "For_Review", cols = remove_col, rows = 2:(nrow(df)+1),
                   type = "list", value = '"yes"', allowBlank = TRUE, showInputMsg = TRUE)
  }

  redRowStyle     <- createStyle(fgFill = "#F8D7DA")
  yellowCellStyle <- createStyle(fgFill = "#FFF3CD")
  orangeCellStyle <- createStyle(fgFill = "#FFE5B4")
  grayRowStyle    <- createStyle(fgFill = "#E2E3E5")

  row_cols <- 1:ncol(df)
  row_rows <- 2:(nrow(df) + 1)

  if (!is.na(approve_letter)) {
    conditionalFormatting(wb, "For_Review", cols = row_cols, rows = row_rows,
                          type = "expression", rule = paste0("=$", approve_letter, "2=\"no\""), style = redRowStyle)
  }
  if (!is.na(remove_letter)) {
    conditionalFormatting(wb, "For_Review", cols = row_cols, rows = row_rows,
                          type = "expression", rule = paste0("=$", remove_letter, "2=\"yes\""), style = grayRowStyle)
  }
  if (!is.na(approve_letter) && !is.na(reason_col) && !is.na(reason_letter)) {
    conditionalFormatting(wb, "For_Review", cols = reason_col, rows = row_rows,
                          type = "expression",
                          rule = paste0("=AND($", approve_letter, "2=\"no\",LEN(TRIM($", reason_letter, "2))=0)"),
                          style = yellowCellStyle)
  }

  override_col_indices <- match(override_cols, names(df))
  override_col_indices <- override_col_indices[!is.na(override_col_indices)]
  override_letters <- vapply(override_col_indices, int2col, character(1))

  if (!is.na(approve_letter) && length(override_col_indices) > 0) {
    for (i in seq_along(override_col_indices)) {
      col_idx <- override_col_indices[i]
      col_letter <- override_letters[i]
      conditionalFormatting(wb, "For_Review", cols = col_idx, rows = row_rows,
                            type = "expression",
                            rule = paste0("=AND($", approve_letter, "2=\"no\",LEN(TRIM($", col_letter, "2))=0)"),
                            style = orangeCellStyle)
    }
  }

  # Excluded_by_BLAST tab
  addWorksheet(wb, "Excluded_by_BLAST")
  writeData(wb, "Excluded_by_BLAST", excluded_by_blast_df, withFilter = TRUE)
  freezePane(wb, "Excluded_by_BLAST", firstRow = TRUE)
  setColWidths(wb, "Excluded_by_BLAST", cols = 1:ncol(excluded_by_blast_df), widths = "auto")
  if (ncol(excluded_by_blast_df) > 0) {
    addStyle(wb, "Excluded_by_BLAST", style = createStyle(textDecoration = "bold"),
             rows = 1, cols = 1:ncol(excluded_by_blast_df), gridExpand = TRUE)
  }
  if ("Sequence" %in% names(excluded_by_blast_df) && nrow(excluded_by_blast_df) > 0) {
    wrapStyle <- createStyle(wrapText = TRUE, valign = "top")
    seq_col_idx <- match("Sequence", names(excluded_by_blast_df))
    addStyle(wb, "Excluded_by_BLAST", wrapStyle,
             rows = 2:(nrow(excluded_by_blast_df) + 1),
             cols = seq_col_idx, gridExpand = TRUE, stack = TRUE)
  }

  saveWorkbook(wb, review_xlsx, overwrite = TRUE)

  message("Project: ", PROJECT_NAME)
  message("Review file created at:\n  ", review_xlsx)
  message("\nDownload locally:\n  scp ", user, "@", host, ":", review_xlsx, " .")
  message("\nEdit in Excel, then upload back:\n  scp ", basename(review_xlsx), " ", user, "@", host, ":", dirname(review_xlsx), "/")
  message("\nAfter re-uploading edited spreadsheet, run THIS SAME COMMAND to continue.\n")
  quit(save = "no", status = 0)
}

message("Detected existing review spreadsheet; resuming (second run).")

# ----------------------------
# Step 2: Read review Excel
# ----------------------------
rev <- read.xlsx(review_xlsx, sheet = "For_Review", detectDates = FALSE)

needed_base <- c("ASV", "Final_Taxon", "Approve", "Disapprove_Reason", "Remove_ASV")
missing_base <- setdiff(needed_base, names(rev))
if (length(missing_base) > 0) stop("Review XLSX missing columns: ", paste(missing_base, collapse = ", "), call. = FALSE)

missing_override <- setdiff(override_cols, names(rev))
if (length(missing_override) > 0) stop("Review XLSX missing override columns: ", paste(missing_override, collapse = ", "), call. = FALSE)

rev <- rev %>%
  mutate(
    Decision = vapply(Approve, norm_decision, character(1)),
    Remove_Action = vapply(Remove_ASV, norm_remove, character(1)),
    Final_Taxon = as.character(Final_Taxon),
    Disapprove_Reason = as.character(Disapprove_Reason)
  )

override_matrix <- as.data.frame(rev[, override_cols, drop = FALSE], stringsAsFactors = FALSE)
override_any <- apply(override_matrix, 1, function(r) any(nzchar(str_trim(ifelse(is.na(r), "", as.character(r))))))
rev$Override_Any <- override_any

write.table(rev, reviewed_assignments_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

# ----------------------------
# Step 3: Update phyloseq taxonomy (from review)
# ----------------------------
tax_mat <- as(tax_table(ps), "matrix")

in_both <- intersect(rownames(tax_mat), rev$ASV)
if (length(in_both) == 0) stop("No overlapping ASV IDs between review and phyloseq tax_table.", call. = FALSE)

to_remove <- character(0)
has_rank_col <- "Final_Taxon_Rank" %in% names(rev)

for (asv in in_both) {
  row <- rev[rev$ASV == asv, , drop = FALSE]
  if (nrow(row) != 1) next

  decision <- row$Decision[[1]]
  blast_taxon <- as.character(row$Final_Taxon[[1]])
  any_override <- isTRUE(row$Override_Any[[1]])
  remove_action <- row$Remove_Action[[1]]

  if (remove_action == "remove") to_remove <- c(to_remove, asv)

  blast_rank_col <- SPECIES_COL
  if (has_rank_col) {
    tmp <- rank_to_taxcol(row$Final_Taxon_Rank[[1]], tax_cols_all)
    if (!is.na(tmp)) blast_rank_col <- tmp
  }

  if (decision == "approved") {
    tax_mat[asv, blast_rank_col] <- blast_taxon

    for (lvl in tax_cols_rank) {
      oc <- paste0("Override_", lvl)
      if (!oc %in% names(row)) next
      val <- str_trim(ifelse(is.na(row[[oc]][[1]]), "", as.character(row[[oc]][[1]])))
      if (nzchar(val)) tax_mat[asv, lvl] <- val
    }

    if (blast_rank_col %in% rank_order) {
      idx <- match(blast_rank_col, rank_order)
      if (!is.na(idx) && idx < length(rank_order)) {
        lower_cols <- rank_order[(idx + 1):length(rank_order)]
        filler <- paste0(blast_taxon, " spp")
        for (lc in lower_cols) {
          cur <- ifelse(is.na(tax_mat[asv, lc]), "", as.character(tax_mat[asv, lc]))
          if (!nzchar(trimws(cur))) tax_mat[asv, lc] <- filler
        }
      }
    }
    next
  }

  # disapproved
  if (!is.na(CONF_COL)) tax_mat[asv, CONF_COL] <- "overridden"

  if (!any_override) {
    tax_mat[asv, tax_cols_rank] <- "unknown"
    next
  }

  for (lvl in tax_cols_rank) {
    oc <- paste0("Override_", lvl)
    val <- str_trim(ifelse(is.na(row[[oc]][[1]]), "", as.character(row[[oc]][[1]])))
    if (nzchar(val)) tax_mat[asv, lvl] <- val
  }
}

tax_table(ps) <- tax_table(tax_mat)

# ----------------------------
# Identify removals AFTER REVIEW ONLY:
#  - reviewer requested removal
#  - incomplete taxonomy after review
# And EXCLUDE anything in Excluded_by_BLAST
# ----------------------------
removed_by_reviewer <- unique(rev$ASV[rev$Remove_Action == "remove"])
removed_by_reviewer <- intersect(removed_by_reviewer, taxa_names(ps))

taxm2 <- as(tax_table(ps), "matrix")
incomplete_asvs <- rownames(taxm2)[
  apply(taxm2[, tax_cols_taxrank, drop = FALSE], 1, function(x) any(is.na(x) | trimws(x) == ""))
]
incomplete_asvs <- intersect(incomplete_asvs, taxa_names(ps))

removed_by_incomplete <- incomplete_asvs

# Pull Excluded_by_BLAST ASVs from the workbook (authoritative, since it's already there)
blast_excluded_asvs <- character(0)
wb_loaded <- tryCatch(loadWorkbook(review_xlsx), error = function(e) NULL)
if (!is.null(wb_loaded) && "Excluded_by_BLAST" %in% names(wb_loaded)) {
  tmp_blast <- tryCatch(read.xlsx(review_xlsx, sheet = "Excluded_by_BLAST", detectDates = FALSE), error = function(e) NULL)
  if (!is.null(tmp_blast) && "ASV" %in% names(tmp_blast)) {
    blast_excluded_asvs <- unique(as.character(tmp_blast$ASV))
    blast_excluded_asvs <- blast_excluded_asvs[nzchar(blast_excluded_asvs)]
  }
}

# --- Keep "no overlap between tabs" logic for the Excluded_by_Reviewer SHEET ---
removed_by_reviewer_sheet   <- setdiff(removed_by_reviewer, blast_excluded_asvs)
removed_by_incomplete_sheet <- setdiff(removed_by_incomplete, blast_excluded_asvs)

# --- For phyloseq pruning, REMOVE anything in EITHER category ---
# Reviewer-based removals (from Remove_ASV == yes OR incomplete ranks)
review_excluded_asvs <- unique(c(to_remove, removed_by_incomplete))

# BLAST-based removals (from the workbook tab)
blast_excluded_in_ps <- intersect(blast_excluded_asvs, taxa_names(ps))

# Review-based removals (post-review) that exist in ps
review_excluded_in_ps <- intersect(review_excluded_asvs, taxa_names(ps))

# Final prune set = union
prune_asvs <- sort(unique(c(blast_excluded_in_ps, review_excluded_in_ps)))


# ----------------------------
# Capture sequences for the reviewer-removed ASVs BEFORE pruning
# ----------------------------
removed_seqs_df <- data.frame(ASV = character(0), Sequence = character(0), stringsAsFactors = FALSE)

to_remove_final <- prune_asvs  # already intersected with taxa_names(ps)

removed_seqs_df <- data.frame(ASV = character(0), Sequence = character(0), stringsAsFactors = FALSE)

if (length(to_remove_final) > 0) {
  taxm_preprune <- as(tax_table(ps), "matrix")

  if (!is.na(SEQ_COL) && SEQ_COL %in% colnames(taxm_preprune)) {
    seq_vec <- as.character(taxm_preprune[to_remove_final, SEQ_COL, drop = TRUE])
    seq_vec[is.na(seq_vec)] <- ""
    removed_seqs_df <- data.frame(ASV = to_remove_final, Sequence = seq_vec, stringsAsFactors = FALSE)
  } else {
    rs <- tryCatch(phyloseq::refseq(ps), error = function(e) NULL)
    if (!is.null(rs)) {
      rs <- rs[to_remove_final]
      removed_seqs_df <- data.frame(ASV = names(rs), Sequence = as.character(rs), stringsAsFactors = FALSE)
    }
  }
}


# ----------------------------
# Prune from phyloseq + save
# ----------------------------
if (length(to_remove_final) > 0) {
  message(
    "Pruning ", length(to_remove_final),
    " ASVs from phyloseq (union of Excluded_by_BLAST + post-review exclusions)."
  )
  ps <- prune_taxa(setdiff(taxa_names(ps), to_remove_final), ps)
}

saveRDS(ps, updated_phyloseq_rds)
message("Saved updated phyloseq object: ", updated_phyloseq_rds)

# ----------------------------
# Build Excluded_by_Reviewer sheet content (AFTER REVIEW ONLY, no BLAST overlap)
# ----------------------------
all_removed_review <- sort(unique(c(removed_by_reviewer_sheet, removed_by_incomplete_sheet)))

excluded_by_reviewer_df <- data.frame(
  ASV = all_removed_review,
  Removed_By_Reviewer = all_removed_review %in% removed_by_reviewer,
  Removed_Incomplete_Taxonomy = all_removed_review %in% removed_by_incomplete,
  Reason = vapply(all_removed_review, function(a) {
    r1 <- a %in% removed_by_reviewer
    r2 <- a %in% removed_by_incomplete
    if (r1 && r2) return("Reviewer requested removal + incomplete taxonomy")
    if (r1)       return("Reviewer requested removal")
    if (r2)       return("Incomplete taxonomy after review")
    "Removed"
  }, character(1)),
  stringsAsFactors = FALSE
)

excluded_by_reviewer_df <- left_join(excluded_by_reviewer_df, removed_seqs_df, by = "ASV")
if (!"Sequence" %in% names(excluded_by_reviewer_df)) excluded_by_reviewer_df$Sequence <- ""
excluded_by_reviewer_df$Length <- ifelse(
  nzchar(excluded_by_reviewer_df$Sequence),
  nchar(excluded_by_reviewer_df$Sequence),
  NA_integer_
)

# ----------------------------
# Step 6: Write/replace Excluded_by_Reviewer tab IN THE SAME review workbook
# ----------------------------
wb <- loadWorkbook(review_xlsx)

if ("Excluded_by_Reviewer" %in% names(wb)) removeWorksheet(wb, "Excluded_by_Reviewer")
addWorksheet(wb, "Excluded_by_Reviewer")

writeData(wb, "Excluded_by_Reviewer", excluded_by_reviewer_df, withFilter = TRUE)
freezePane(wb, "Excluded_by_Reviewer", firstRow = TRUE)
setColWidths(wb, "Excluded_by_Reviewer", cols = 1:ncol(excluded_by_reviewer_df), widths = "auto")

addStyle(
  wb, "Excluded_by_Reviewer",
  style = createStyle(textDecoration = "bold"),
  rows = 1,
  cols = 1:ncol(excluded_by_reviewer_df),
  gridExpand = TRUE
)

if ("Sequence" %in% names(excluded_by_reviewer_df) && nrow(excluded_by_reviewer_df) > 0) {
  wrapStyle <- createStyle(wrapText = TRUE, valign = "top")
  seq_col_idx <- match("Sequence", names(excluded_by_reviewer_df))
  addStyle(
    wb, "Excluded_by_Reviewer",
    wrapStyle,
    rows = 2:(nrow(excluded_by_reviewer_df) + 1),
    cols = seq_col_idx,
    gridExpand = TRUE,
    stack = TRUE
  )
}

saveWorkbook(wb, review_xlsx, overwrite = TRUE)
message("Updated review workbook with Excluded_by_Reviewer tab: ", review_xlsx)

message("Done.")

