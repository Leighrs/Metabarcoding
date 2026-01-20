# ===============================
# DSP 12S Contaminant Removal Pipeline
# Outputs all metrics to a single Excel file
# ===============================

message("Starting DSP 12S Contaminant Removal Pipeline")

# ===============================
# 1. Extract ASV counts and metadata
# ===============================
asv_matrix <<- as(otu_table(ps), "matrix")           # Convert OTU table from phyloseq to matrix
metadata_matrix <<- as(sample_data(ps), "data.frame") # Extract sample metadata as data frame

message("ASV matrix dimensions: ", dim(asv_matrix)[1], " ASVs x ", dim(asv_matrix)[2], " samples")
message("Metadata matrix dimensions: ", dim(metadata_matrix)[1], " samples x ", dim(metadata_matrix)[2], " metadata fields")

# ===============================
# 2. Identify control and sample reads
# ===============================
control_names_vec <- rownames(metadata_matrix[metadata_matrix[[sample_type_col]] == control_label, ])  # Identify control sample names
control_reads <- asv_matrix[, control_names_vec]  # Extract ASV counts for control samples

sample_names_vec <<- rownames(metadata_matrix[metadata_matrix[[sample_type_col]] == sample_label, ])    # Identify regular sample names
sample_reads <- asv_matrix[, sample_names_vec]  # Extract ASV counts for regular samples

message("   Controls identified: ", length(control_names_vec))
message("   Environmental samples identified: ", length(sample_names_vec))

# ===============================
# 3. Map control assignments
# ===============================
control_assign <- metadata_matrix[[assigned_controls]]   # Extract control assignments from metadata
names(control_assign) <- rownames(metadata_matrix) # Name vector elements by sample names

# ===============================
# 4. Helper function to split multiple control IDs
# ===============================
split_ids <- function(x) {                    # Define function to split comma-separated control IDs
  if (is.na(x) || x == "") return(character(0))      # Return empty character vector if input is NA or blank
  ids <- unlist(str_split(x, ","))                   # Split the string by commas
  ids <- str_trim(ids)                               # Trim whitespace from each ID
  ids[ids != ""]                                     # Remove any empty strings from result
}

# ===============================
# 5. Copy ASV matrix to a clean version
# ===============================
asv_matrix_clean <- asv_matrix   # Make a copy of ASV matrix to modify for contaminant removal

# ===============================
# 6. Create decontamination metrics table
# ===============================
metric <- data.frame(
  Sample = sample_names_vec,                             # Column for sample names
  NumAssignedControls = integer(length(sample_names_vec)), # Column for number of assigned controls
  NumASVsReduced = integer(length(sample_names_vec)),     # Column for number of ASVs reduced per sample
  ReadsBefore = numeric(length(sample_names_vec)),        # Column for total reads before cleaning
  ReadsAfter = numeric(length(sample_names_vec)),         # Column for total reads after cleaning
  stringsAsFactors = FALSE                            # Do not convert strings to factors
)

# ===============================
# 7. Loop through samples and subtract contaminant reads
# ===============================

for (i in seq_along(sample_names_vec)) {           # Iterate over each sample
  s <- sample_names_vec[i]                        # Get current sample name
  metric$ReadsBefore[i] <- sum(asv_matrix_clean[, s])       # Record total reads before contaminant removal
  
  assigned_ids <- split_ids(control_assign[s])             # Split assigned control IDs for this sample
  
  if (length(assigned_ids) == 0) {                        # If no controls assigned
    metric$NumAssignedControls[i] <- 0                      # Set number of assigned controls to 0
    metric$NumASVsReduced[i] <- 0                           # Set number of ASVs reduced to 0
    metric$ReadsAfter[i] <- sum(asv_matrix_clean[, s])      # Reads after remain unchanged
    next                                                   # Skip to next iteration
  }
  
  # Find actual control samples matching these IDs
  assigned_control_samples <- rownames(metadata_matrix)[
    metadata_matrix[["Control_Assign"]] %in% assigned_ids &  # Filter rows where Control_Assign matches
      metadata_matrix[["Sample_or_Control"]] == "Control"    # Only keep controls
  ]
  
  metric$NumAssignedControls[i] <- length(assigned_control_samples) # Record number of matched controls
  
  if (length(assigned_control_samples) == 0) {            # If no matching control samples found
    warning(sprintf(
      "Sample %s: no control samples found matching Control_Assign IDs: %s",
      s, paste(assigned_ids, collapse = ",")
    ))                                                    # Show warning
    metric$NumASVsReduced[i] <- 0                           # No ASVs reduced
    metric$ReadsAfter[i] <- sum(asv_matrix_clean[, s])      # Reads remain unchanged
    next
  }
  
  # Sum control counts per ASV
  control_sums <- rowSums(asv_matrix[, assigned_control_samples, drop = FALSE]) # Sum counts across assigned controls
  
  # Subtract control counts from sample
  before_vec <- asv_matrix_clean[, s]       # Store original counts
  after_vec <- before_vec - control_sums    # Subtract control counts
  after_vec[after_vec < 0] <- 0             # Ensure no negative counts
  
  # Store decontamination metrics and update cleaned matrix
  metric$NumASVsReduced[i] <- sum(before_vec != after_vec) # Count how many ASVs changed
  asv_matrix_clean[, s] <- after_vec                     # Update cleaned matrix
  metric$ReadsAfter[i] <- sum(asv_matrix_clean[, s])      # Record reads after subtraction
}

# ===============================
# 8. Update phyloseq object with cleaned ASV counts
# ===============================
otu_new <- asv_matrix_clean                    # Assign cleaned ASV matrix
ps_clean <- ps         # Make a copy of phyloseq object
taxa_rows <- taxa_are_rows(ps)     # Check if taxa are rows
otu_table(ps_clean) <- otu_table(otu_new, taxa_are_rows = taxa_rows) # Update OTU table

# ===============================
# 8b. Identify and prune taxa with zero counts
# ===============================
taxa_zero <- taxa_names(ps_clean)[taxa_sums(ps_clean) == 0] # Find taxa with zero total counts
message("   Number of ASVs completely removed from study: ", length(taxa_zero))

if(length(taxa_zero) > 0){
  removed_taxa_df <- as.data.frame(tax_table(ps)[taxa_zero, ]) # Extract taxonomy of removed taxa
  removed_taxa_df$Sequence <- taxa_zero                  # Add sequence column
  removed_taxa_df$ASV_ID <- taxa_zero                    # Add ASV ID column
} else {
  removed_taxa_df <- data.frame(
    Note = "No ASV completely removed from study. Check per-sample removals." # Message if no taxa removed
  )
}

# Prune taxa with zero counts across all samples
ps_clean <- prune_taxa(taxa_sums(ps_clean) > 0, ps_clean)

# ===============================
# 8c. Track which taxa were completely removed per sample
# ===============================
taxa_removed_matrix <- (asv_matrix_clean[, sample_names_vec] == 0) & (asv_matrix[, sample_names_vec] > 0) # Logical matrix for removed ASVs

removed_per_sample <- lapply(seq_along(sample_names_vec), function(i) {   # Loop over samples
  sample_name <- sample_names_vec[i]                                        # Get sample name
  removed_taxa <- rownames(asv_matrix)[taxa_removed_matrix[, i]]        # Get removed taxa for this sample
  if (length(removed_taxa) == 0) return(NA)                             # Return NA if none removed
  paste(removed_taxa, collapse = ", ")                                   # Combine into string
})

removed_per_sample_df <- data.frame(
  Sample = sample_names_vec,                                # Column for sample names
  Completely_Removed_Taxa = unlist(removed_per_sample), # Column for removed taxa
  stringsAsFactors = FALSE                              # Do not convert to factors
)

# ===============================
# 8d. Remove control samples from cleaned phyloseq object
# ===============================
ps_clean <- prune_samples(
  !(sample_names(ps_clean) %in% control_names_vec), 
  ps_clean
)

# ===============================
# 9. Prepare assigned controls table for Excel
# ===============================
assigned_controls_df <- data.frame(
  Sample = sample_names_vec,                                # Column for sample names
  Assigned_Control_IDs = sapply(sample_names_vec, function(s) {  # Get assigned control IDs
    ids <- split_ids(control_assign[s])                   # Split IDs
    if (length(ids) == 0) return(NA)                      # Return NA if none
    paste(ids, collapse = ", ")                           # Combine into string
  }),
  Assigned_Control_Samples = sapply(sample_names_vec, function(s) { # Get matching control samples
    ids <- split_ids(control_assign[s])                     # Split IDs
    if (length(ids) == 0) return(NA)                        # Return NA if none
    matched_controls <- rownames(metadata_matrix)[
      metadata_matrix[["Control_Assign"]] %in% ids &
        metadata_matrix[["Sample_or_Control"]] == "Control"
    ]
    if (length(matched_controls) == 0) return(NA)           # Return NA if no match
    paste(matched_controls, collapse = ", ")               # Combine into string
  }),
  stringsAsFactors = FALSE                                  # Do not convert to factors
)

# ===============================
# 10. Prepare summary table for Excel
# ===============================
summary_df <- data.frame(
  Metric = c(
    "Total Samples Processed",                            # Metric: total number of samples
    "Total Controls",                                     # Metric: total number of controls
    "Total Reads Before Removal",                          # Metric: total reads before removal
    "Total Reads After Removal",                           # Metric: total reads after removal
    "Total ASVs Reduced",                                  # Metric: total ASVs reduced
    "Average Reads Per Sample Before",                     # Metric: average reads per sample before
    "Average Reads Per Sample After",                      # Metric: average reads per sample after
    "Average ASVs Reduced Per Sample"                      # Metric: average ASVs reduced per sample
  ),
  Value = c(
    length(sample_names_vec),                                  # Calculate total samples
    length(control_names_vec),                                 # Calculate total controls
    sum(metric$ReadsBefore),                                 # Sum reads before removal
    sum(metric$ReadsAfter),                                  # Sum reads after removal
    sum(metric$NumASVsReduced),                               # Sum ASVs reduced
    mean(metric$ReadsBefore),                                 # Average reads before removal
    mean(metric$ReadsAfter),                                  # Average reads after removal
    mean(metric$NumASVsReduced)                                # Average ASVs reduced
  ),
  stringsAsFactors = FALSE                                  # Do not convert to factors
)
message("   Decontamination metrics and summary tables prepared")

# ===============================
# 11. Prepare reads matrices with taxonomy
# ===============================
tax_info <- as.data.frame(tax_table(ps))          # Extract taxonomy info
tax_info$Sequence <- rownames(otu_table(ps))      # Add sequence column
tax_info$ASV_ID <- rownames(otu_table(ps))        # Add ASV ID column

control_reads_df <- cbind(tax_info, as.data.frame(control_reads))                  # Combine taxonomy with control reads
sample_reads_before_df <- cbind(tax_info, as.data.frame(sample_reads))            # Combine taxonomy with sample reads before
sample_reads_after_df <- cbind(tax_info, as.data.frame(asv_matrix_clean[, sample_names_vec])) # Combine taxonomy with cleaned sample reads

# Rename columns J and K for clarity
colnames(control_reads_df)[10:11] <- c("Sequence", "ASV_ID")                 # Rename 10th and 11th columns
colnames(sample_reads_before_df)[10:11] <- c("Sequence", "ASV_ID")           # Rename 10th and 11th columns
colnames(sample_reads_after_df)[10:11] <- c("Sequence", "ASV_ID")            # Rename 10th and 11th columns

# ===============================
# 12. Create per-sample removed taxa table with taxonomy
# ===============================
removed_list <- list()                              # Initialize list to store removed taxa info

for (s in sample_names_vec) {                            # Loop through each sample
  removed_taxa <- rownames(asv_matrix)[(asv_matrix[, s] > 0) & (asv_matrix_clean[, s] == 0)] # Find ASVs removed
  
  if (length(removed_taxa) > 0) {                  # If any ASVs removed
    tax_info_removed <- as.data.frame(tax_table(ps)[removed_taxa, ]) # Extract taxonomy
    tax_info_removed$Sequence <- removed_taxa      # Add sequence column
    tax_info_removed$ASV_ID <- removed_taxa        # Add ASV ID column
    tax_info_removed$Sample <- s                    # Add sample column
    removed_list[[s]] <- tax_info_removed          # Store in list
  }
}

removed_per_sample_df <- do.call(rbind, removed_list) # Combine list into a single data frame

if (nrow(removed_per_sample_df) == 0) {               # If no rows, create placeholder
  removed_per_sample_df <- data.frame(
    Note = "No taxa completely removed in any sample"
  )
}

# Move column M (13th) to the far left
if (!is.null(removed_per_sample_df) && nrow(removed_per_sample_df) > 0 && ncol(removed_per_sample_df) >= 13) {
  removed_per_sample_df <- removed_per_sample_df[, c(13, setdiff(seq_len(ncol(removed_per_sample_df)), 13))] # Reorder columns
}

# Rename column K to "Sequence" and remove column L if present
if (!is.null(removed_per_sample_df) && nrow(removed_per_sample_df) > 0 && ncol(removed_per_sample_df) >= 12) {
  colnames(removed_per_sample_df)[11] <- "Sequence" # Rename 11th column
  removed_per_sample_df <- removed_per_sample_df[, -12] # Remove 12th column
}

# ===============================
# 13. Remove column L (12th column) from specific sheets before writing
# ===============================
if (ncol(control_reads_df) >= 12) {                 # If 12th column exists
  control_reads_df <- control_reads_df[, -12]       # Remove it
}

if (ncol(sample_reads_before_df) >= 12) {           # If 12th column exists
  sample_reads_before_df <- sample_reads_before_df[, -12] # Remove it
}

if (ncol(sample_reads_after_df) >= 12) {            # If 12th column exists
  sample_reads_after_df <- sample_reads_after_df[, -12] # Remove it
}

# ===============================
# 14. Write Excel file with all decontamination metrics
# ===============================
message("   Writing decontamination metrics to Excel at: ", here(output_dir, paste0("1_",project_name, "_decontam_applied.xlsx")))

write_xlsx(
  list(
    Control_Reads = control_reads_df,                # Sheet: control reads
    Sample_Reads_Before = sample_reads_before_df,   # Sheet: sample reads before cleaning
    Sample_Reads_After = sample_reads_after_df,     # Sheet: sample reads after cleaning
    Decontamination_metrics = metric,                              # Sheet: per-sample decontamination metrics
    Assigned_Controls = assigned_controls_df,        # Sheet: assigned controls
    Summary = summary_df,                             # Sheet: summary metrics
    Removed_ASVs = removed_taxa_df,                  # Sheet: ASVs removed completely
    Removed_Per_Sample = removed_per_sample_df       # Sheet: removed taxa per sample
  ),
  path = here(output_dir, paste0("1_",project_name, "_decontam_applied.xlsx")) # Output Excel file path
)

# ===============================
# 15. Save cleaned phyloseq object
# ===============================
ps_clean1 <- ps_clean # Save cleaned phyloseq object under new name and save to global env so other scripts can use it.
ps_clean1 <<- ps_clean1 
message("   Cleaned phyloseq object saved to 'ps_clean1' in global environment")
# The object 'ps_clean1' now contains cleaned ASV counts

# ===============================
# 16. Pipeline completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    " Contaminant removal pipeline completed successfully! \n",
    "--------------------------------------------------------------------")  # Print completion message


