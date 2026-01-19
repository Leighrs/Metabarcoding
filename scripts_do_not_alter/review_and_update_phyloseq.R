#!/usr/bin/env Rscript

Sys.setenv(TZ = "UTC")  # or your preferred timezone

suppressPackageStartupMessages({
  library(dplyr) # data manipulation
  library(stringr)
  library(phyloseq)
  library(openxlsx) #read/write excel without java.
})

# ----------------------------
# Define Helper Functions
# ----------------------------

# Blank = approved. Any recognized "no" = disapproved. Unknown nonblank = disapproved (conservative).
norm_decision <- function(x) { # Rule for approvals/dissapprovals
  x0 <- trimws(as.character(x)) # coerce to string and remove whitespaces
  if (is.na(x0) || x0 == "") return("approved") # blank or NA means approved

  x <- tolower(x0) # returns lowercase
  if (x %in% c("n","no","disapprove","disapproved","reject","rejected","false","f","0")) return("disapproved") # recognized disapprove values
  if (x %in% c("y","yes","approve","approved","true","t","1")) return("approved") # recognized approved values

  "disapproved" # if anything else, then disapproved
}

# Blank = keep; "yes" = remove
norm_remove <- function(x) { # Rule for ASV removals
  x0 <- trimws(as.character(x))
  if (is.na(x0) || x0 == "") return("keep")
  x <- tolower(x0)
  if (x %in% c("y","yes","remove","removed","true","t","1")) return("remove")
  "keep"
}

stop_if_missing <- function(x, name) {
  if (is.null(x) || !nzchar(x)) stop("Missing required env var: ", name, call. = FALSE) # If x is null or x is empty, then halt script, and print an error. But don't print full function error.
}

# Return first matching colname from candidates
pick_first_col <- function(cols, candidates) { # From a list of acceptable names for a column, return the first one that actually exists. otherwise return NA.
  hit <- candidates[candidates %in% cols][1] # Returns the first acceptable name, if there were multiple.
  if (is.na(hit) || !nzchar(hit)) return(NA_character_)
  hit
}

# Columns we should NOT create Override_* for, and should NOT blank to unknown.
is_excluded_override_col <- function(colname) {
  cn <- tolower(colname)
  cn %in% c("confidence", "sequence", "asv_sequence")
}

# ----------------------------
# Inputs via environment variables
# ----------------------------
PROJECT_NAME <- Sys.getenv("PROJECT_NAME", unset = "") #unset returns an empty string "" if the variable does not exist.
stop_if_missing(PROJECT_NAME, "PROJECT_NAME")

PROJECT_DIR <- Sys.getenv("PROJECT_DIR", unset = file.path(Sys.getenv("HOME"), "Metabarcoding", PROJECT_NAME))

BLAST_FILE <- Sys.getenv( #If there is no LCTR_TSV variable found, return this .tsv file.
  "LCTR_TSV",
  unset = file.path(PROJECT_DIR, "output", "BLAST", paste0(PROJECT_NAME, "_final_LCTR_taxonomy_with_ranks.tsv"))
)

PHYLOSEQ_RDS <- Sys.getenv("PHYLOSEQ_RDS", unset = "")
stop_if_missing(PHYLOSEQ_RDS, "PHYLOSEQ_RDS")

OUT_DIR <- Sys.getenv("REVIEW_OUTDIR", unset = "")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
stop_if_missing(OUT_DIR, "REVIEW_OUTDIR")

review_xlsx <- file.path(OUT_DIR, paste0(PROJECT_NAME, "_final_LCTR_taxonomy_with_ranks.REVIEW.xlsx")) #Concatenates file path with new file name
reviewed_assignments_tsv <- file.path(OUT_DIR, paste0(PROJECT_NAME, "_reviewed_assignments.tsv"))
updated_phyloseq_rds <- file.path(OUT_DIR, paste0(PROJECT_NAME, "_phyloseq_UPDATED_reviewed_taxonomy.rds"))

is_resume <- file.exists(review_xlsx)

user <- Sys.getenv("USER", unset = "") # Used later to print custom scp instructions to user
stop_if_missing(user, "USER")

host <- trimws(tryCatch(system("hostname -f", intern = TRUE), error = function(e) ""))

# If it looks like farm.farm.hpc..., collapse the duplicate first label
host <- sub("^([^.]+)\\.\\1\\.", "\\1.", host)

if (!nzchar(host)) {
  stop("Could not determine hostname for scp instructions.", call. = FALSE)
}


if (!file.exists(BLAST_FILE)) stop("Cannot find BLAST taxonomy file: ", BLAST_FILE, call. = FALSE)
if (!file.exists(PHYLOSEQ_RDS)) stop("Cannot find phyloseq RDS: ", PHYLOSEQ_RDS, call. = FALSE)

# ----------------------------
# Step 0: Load phyloseq early to get tax_table columns
# ----------------------------
ps <- readRDS(PHYLOSEQ_RDS)
if (!inherits(ps, "phyloseq")) stop("Loaded object is not a phyloseq object: ", PHYLOSEQ_RDS, call. = FALSE) # Confirms the object is of the phyloseq class.

tax <- tax_table(ps)
tax_mat <- as(tax, "matrix")
tax_cols_all <- colnames(tax_mat)

# Rank/taxon columns that we WILL set to unknown when needed and allow overrides for.
# This excludes Confidence + Sequence columns.
tax_cols_rank <- tax_cols_all[!vapply(tax_cols_all, is_excluded_override_col, logical(1))] # !vapply creates a logical vector for whether a column should be included, amd tax_cols_all[...] keeps all TRUE columns.

# Identify Species column (required). When a BLAST assignment is approved, the BLAST final taxon assignment will be written specifically into the Species column, so this code chuck helps us identify that column.
SPECIES_COL <- pick_first_col(tax_cols_all, c("Species", "species", "SPECIES"))
if (is.na(SPECIES_COL)) {
  stop("Could not find a Species column in tax_table(ps). Columns are: ",
       paste(tax_cols_all, collapse = ", "), # prints all columns that do exist
       call. = FALSE)
}

# Confidence + sequence columns (optional)
CONF_COL <- pick_first_col(tax_cols_all, c("Confidence", "confidence", "CONFIDENCE"))
SEQ_COL  <- pick_first_col(tax_cols_all, c("ASV_sequence", "asv_sequence", "Sequence", "sequence"))


# Override columns are created ONLY for taxon rank columns (not confidence/sequence)
override_cols <- paste0("Override_", tax_cols_rank)

# ----------------------------
# Step 1: Read original TSV and build a new spreadsheet for review
# ----------------------------
df <- read.delim(
  BLAST_FILE,
  sep = "\t", # columns are separated by tabs
  header = TRUE, # first row contains column names
  check.names = FALSE, # preserves exact column names. sometimes R can rename them to make syntactically valid.
  stringsAsFactors = FALSE # treats the text as text instead of categorical codes.
)

required_cols <- c("ASV", "Final_Taxon") # Checks that the input .tsv file contains the ASV and Final_Taxon column, and stops if either is missing.
missing_cols <- setdiff(required_cols, names(df)) # Checks which column names are 'not' present in the dataframe.
if (length(missing_cols) > 0) {
  stop("Input TSV is missing required columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

if (!("Approve" %in% names(df))) df$Approve <- "" # if the column 'Approve' does not exist in the list of current column names, create it and fills its rows with a blank string.
if (!("Disapprove_Reason" %in% names(df))) df$Disapprove_Reason <- ""
if (!("Remove_ASV" %in% names(df))) df$Remove_ASV <- ""

for (oc in override_cols) { # for each override column name, if it doesn't exist, create it as a blank column.
  if (!(oc %in% names(df))) df[[oc]] <- ""
}

preferred_front <- intersect(c("ASV", "ASV_sequence", "Final_Taxon", "Final_Taxon_Rank"), names(df))
rest <- setdiff(names(df), c(preferred_front, "Approve", "Disapprove_Reason", "Remove_ASV", override_cols)) # computes all current columns expcept the ones we plan to put at the front.
df <- df[, unique(c(preferred_front, "Approve", "Disapprove_Reason", "Remove_ASV", override_cols, rest))] # reorders columns for review spreadsheet.

# ----------------------------
# Step 1b: Write Excel with validation + highlighting
# ----------------------------
wb <- createWorkbook()
addWorksheet(wb, "Review")
writeData(wb, "Review", df, withFilter = TRUE)

freezePane(wb, "Review", firstRow = TRUE)
setColWidths(wb, "Review", cols = 1:ncol(df), widths = "auto")

headerStyle <- createStyle(textDecoration = "bold")
addStyle(wb, "Review", style = headerStyle, rows = 1, cols = 1:ncol(df), gridExpand = TRUE)

wrap_cols <- intersect(c("Explanation", "Disapprove_Reason", "stitle"), names(df))
if (length(wrap_cols) > 0) {
  wrapStyle <- createStyle(wrapText = TRUE, valign = "top")
  wrap_idx <- match(wrap_cols, names(df))
  addStyle(
    wb, "Review", wrapStyle,
    rows = 2:(nrow(df) + 1),
    cols = wrap_idx,
    gridExpand = TRUE,
    stack = TRUE
  )
}

approve_col <- match("Approve", names(df))
reason_col  <- match("Disapprove_Reason", names(df))
remove_col  <- match("Remove_ASV", names(df))

approve_letter <- if (!is.na(approve_col)) openxlsx::int2col(approve_col) else NA_character_
reason_letter  <- if (!is.na(reason_col))  openxlsx::int2col(reason_col)  else NA_character_
remove_letter  <- if (!is.na(remove_col))  openxlsx::int2col(remove_col)  else NA_character_

if (!is.na(approve_col)) {
  dataValidation(
    wb, "Review",
    cols = approve_col,
    rows = 2:(nrow(df) + 1),
    type = "list",
    value = '"no"',
    allowBlank = TRUE,
    showInputMsg = TRUE
  )
}
if (!is.na(remove_col)) {
  dataValidation(
    wb, "Review",
    cols = remove_col,
    rows = 2:(nrow(df) + 1),
    type = "list",
    value = '"yes"',
    allowBlank = TRUE,
    showInputMsg = TRUE
  )
}

redRowStyle     <- createStyle(fgFill = "#F8D7DA")
yellowCellStyle <- createStyle(fgFill = "#FFF3CD")
orangeCellStyle <- createStyle(fgFill = "#FFE5B4")
grayRowStyle    <- createStyle(fgFill = "#E2E3E5")

row_cols <- 1:ncol(df)
row_rows <- 2:(nrow(df) + 1)

if (!is.na(approve_letter)) {
  conditionalFormatting(
    wb, "Review",
    cols = row_cols, rows = row_rows,
    type = "expression",
    rule = paste0("=$", approve_letter, "2=\"no\""),
    style = redRowStyle
  )
}
if (!is.na(remove_letter)) {
  conditionalFormatting(
    wb, "Review",
    cols = row_cols, rows = row_rows,
    type = "expression",
    rule = paste0("=$", remove_letter, "2=\"yes\""),
    style = grayRowStyle
  )
}
if (!is.na(approve_letter) && !is.na(reason_col) && !is.na(reason_letter)) {
  conditionalFormatting(
    wb, "Review",
    cols = reason_col, rows = row_rows,
    type = "expression",
    rule = paste0("=AND($", approve_letter, "2=\"no\",LEN(TRIM($", reason_letter, "2))=0)"),
    style = yellowCellStyle
  )
}

override_col_indices <- match(override_cols, names(df))
override_col_indices <- override_col_indices[!is.na(override_col_indices)]
override_letters <- vapply(override_col_indices, openxlsx::int2col, character(1))

if (!is.na(approve_letter) && length(override_col_indices) > 0) {
  for (i in seq_along(override_col_indices)) {
    col_idx <- override_col_indices[i]
    col_letter <- override_letters[i]
    conditionalFormatting(
      wb, "Review",
      cols = col_idx, rows = row_rows,
      type = "expression",
      rule = paste0("=AND($", approve_letter, "2=\"no\",LEN(TRIM($", col_letter, "2))=0)"),
      style = orangeCellStyle
    )
  }
}


if (!is_resume) {
  saveWorkbook(wb, review_xlsx, overwrite = TRUE)
  message("Project: ", PROJECT_NAME)
  message("BLAST taxonomy file: ", BLAST_FILE)
  message("Phyloseq input RDS: ", PHYLOSEQ_RDS)
  
  message("\n============================================================")
  message("MANUAL REVIEW STEP (HPC is headless; Excel won't open here)")
  message("============================================================")
  message("Review file created at:")
  message("  ", review_xlsx)

  message("\nDownload locally:")
  message("  scp ", user, "@", host, ":", review_xlsx, " .")

  message("\nEdit in Excel, then upload back:")
  message("  scp ", basename(review_xlsx), " ", user, "@", host, ":", dirname(review_xlsx), "/")
  
  message("\nRules:")
  message("- Approve: blank = approved; 'no' = disapproved.")
  message("- Remove_ASV: blank = keep; 'yes' = remove from dataset.")
  message("- Disapproved + no taxon rank overrides => all rank columns will set to 'unknown`.")
  message("- Disapproved + any overrides => apply those overrides, confidence set to 'overridden'.")
  
  message("After re-uploading edited spreadsheet, run THIS SAME COMMAND to continue.")
  message("============================================================\n")

  quit(save = "no", status = 0)
}

  message("Detected an .xlsx spreadsheet, script must be in second run.")
  message("Project: ", PROJECT_NAME, " resumed")
  
# ----------------------------
# Step 2: Read review Excel
# ----------------------------
rev <- read.xlsx(review_xlsx, sheet = "Review", detectDates = FALSE)

needed_base <- c("ASV", "Final_Taxon", "Approve", "Disapprove_Reason", "Remove_ASV")
missing_base <- setdiff(needed_base, names(rev))
if (length(missing_base) > 0) stop("Review XLSX missing columns: ", paste(missing_base, collapse = ", "), call. = FALSE)

missing_override <- setdiff(override_cols, names(rev))
if (length(missing_override) > 0) {
  stop("Review XLSX missing override columns: ", paste(missing_override, collapse = ", "), call. = FALSE)
}

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

flag_reason <- rev %>%
  filter(Decision == "disapproved" & (is.na(Disapprove_Reason) | str_trim(Disapprove_Reason) == "")) %>%
  pull(ASV)
if (length(flag_reason) > 0) warning("Disapproved ASVs missing reason: ", paste(flag_reason, collapse = ", "))

write.table(rev, reviewed_assignments_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

# ----------------------------
# Step 3: Update phyloseq + prune taxa
# ----------------------------
tax_mat <- as(tax_table(ps), "matrix")

in_both <- intersect(rownames(tax_mat), rev$ASV)
if (length(in_both) == 0) stop("No overlapping ASV IDs between review and phyloseq tax_table.", call. = FALSE)

to_remove <- character(0)

for (asv in in_both) {
  row <- rev[rev$ASV == asv, , drop = FALSE]
  if (nrow(row) != 1) next

  decision <- row$Decision[[1]]
  blast_taxon <- as.character(row$Final_Taxon[[1]])
  any_override <- isTRUE(row$Override_Any[[1]])
  remove_action <- row$Remove_Action[[1]]

  if (remove_action == "remove") to_remove <- c(to_remove, asv)

  if (decision == "approved") {
    tax_mat[asv, SPECIES_COL] <- blast_taxon
    next
  }

  # disapproved:
  # Always mark confidence overridden if column exists
  if (!is.na(CONF_COL)) tax_mat[asv, CONF_COL] <- "overridden"

  if (!any_override) {
    # Set ONLY rank columns to unknown; leave sequence untouched; confidence already set above.
    tax_mat[asv, tax_cols_rank] <- "unknown"
    next
  }

  # Apply per-level overrides (rank columns only)
  for (lvl in tax_cols_rank) {
    oc <- paste0("Override_", lvl)
    val <- row[[oc]][[1]]
    val <- str_trim(ifelse(is.na(val), "", as.character(val)))
    if (nzchar(val)) {
      tax_mat[asv, lvl] <- val
    }
  }
}

tax_table(ps) <- tax_table(tax_mat)

to_remove <- intersect(unique(to_remove), taxa_names(ps))
if (length(to_remove) > 0) {
  message("Removing ", length(to_remove), " ASVs from phyloseq object (Remove_ASV == yes).")
  ps <- prune_taxa(setdiff(taxa_names(ps), to_remove), ps)
}

saveRDS(ps, updated_phyloseq_rds)
message("Saved updated phyloseq object: ", updated_phyloseq_rds)

message("Done.")

