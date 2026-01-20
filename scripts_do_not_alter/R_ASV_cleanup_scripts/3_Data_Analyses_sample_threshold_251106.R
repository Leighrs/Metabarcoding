message("Starting Per-Sample ASV Threshold Pipeline")
message("  Threshold set to: ", sample_thres, ifelse(sample_thres < 1, " (proportion)", " (absolute reads)"))

# ===============================
# Per-Sample ASV Threshold Pipeline
# Outputs the presence and absence of species in samples before and after per-sample ASV threshold.
# ===============================

# ===============================
# 1. Prepare ASV matrices
# ===============================
asv_matrix_cleaned <- as(otu_table(ps_clean1), "matrix") # Extract ASV counts from cleaned phyloseq object as matrix
taxa_rows <- taxa_are_rows(ps_clean1)                     # Check if taxa are rows in the OTU table
if (!taxa_rows) { asv_matrix_cleaned <- t(asv_matrix_cleaned) }       # If taxa are columns, transpose matrix so taxa are rows

asv_matrix_before_thresh <- asv_matrix_cleaned                        # Make a copy for "before threshold" data
sample_sums <- colSums(asv_matrix_cleaned)                             # Calculate total reads per sample
message("  ASV matrix extracted from ps_clean1:")
message("     Dimensions (ASVs x samples): ", dim(asv_matrix_cleaned)[1], " x ", dim(asv_matrix_cleaned)[2])


# ===============================
# 2. Apply threshold
# ===============================
threshold <- sample_thres                                              # Define threshold
compute_sample_threshold <- function(threshold, sample_total) {         # Helper function to accomadate whether threshold is proportion or absolute read count.
  if (threshold < 1) {
    # Threshold <1  proportion
    return(round(sample_total * threshold, 0))
  } else {
    # Threshold >=1  absolute reads
    return(threshold)
  }
}
asv_matrix_after_thresh <- asv_matrix_cleaned                          # Make a copy for "after threshold" data

for (s in colnames(asv_matrix_cleaned)) {                               # Loop over each sample
  min_reads <- compute_sample_threshold(threshold, sample_sums[s])                   # Calculate amount of total sample reads, rounded
  asv_matrix_after_thresh[, s] <- asv_matrix_cleaned[, s] - min_reads   # Subtract threshold reads from each ASV
}
asv_matrix_after_thresh[asv_matrix_after_thresh < 0] <- 0               # Replace any negative counts with 0
num_asvs_changed <- sum(asv_matrix_before_thresh != asv_matrix_after_thresh)
message("  Threshold applied. Total ASV counts changed across all samples: ", num_asvs_changed)

# ===============================
# 3. Taxonomy info
# ===============================
tax_info <- as.data.frame(as(tax_table(ps_clean1), "matrix")) # Extract taxonomy from phyloseq object
tax_info$Sequence <- rownames(otu_table(ps_clean1))                # Add Sequence column with row names
tax_info$ASV_ID <- rownames(otu_table(ps_clean1))                  # Add ASV_ID column with row names

# Ensure order matches the ASV matrices (very important)
tax_info <- tax_info[rownames(asv_matrix_cleaned), , drop = FALSE]

# ===============================
# 4. Sample Reads sheets
# ===============================
sample_reads_before_thresh_df <- cbind( # Combine taxonomy with counts before threshold
  tax_info,
  as.data.frame(asv_matrix_before_thresh[, sample_names_vec, drop = FALSE])
) 

sample_reads_after_thresh_df <- cbind( # Combine taxonomy with counts after threshold
  tax_info,
  as.data.frame(asv_matrix_after_thresh[, sample_names_vec, drop = FALSE])
)


# Rename columns J -> "Sequence" and K -> "ASV_ID"
# Ensure exact column names
names(sample_reads_before_thresh_df)[names(sample_reads_before_thresh_df) == "Sequence"] <- "Sequence"
names(sample_reads_before_thresh_df)[names(sample_reads_before_thresh_df) == "ASV_ID"] <- "ASV_ID"
names(sample_reads_after_thresh_df)[names(sample_reads_after_thresh_df) == "Sequence"] <- "Sequence"
names(sample_reads_after_thresh_df)[names(sample_reads_after_thresh_df) == "ASV_ID"] <- "ASV_ID"

colnames(sample_reads_before_thresh_df)[10] <- "Sequence"                # Rename 10th column to "Sequence"
colnames(sample_reads_before_thresh_df)[11] <- "ASV_ID"                  # Rename 11th column to "ASV_ID"
colnames(sample_reads_after_thresh_df)[10] <- "Sequence"                 # Rename 10th column to "Sequence"
colnames(sample_reads_after_thresh_df)[11] <- "ASV_ID"                   # Rename 11th column to "ASV_ID"

# Remove 12th column if present
if (ncol(sample_reads_before_thresh_df) >= 12) sample_reads_before_thresh_df <- sample_reads_before_thresh_df[, -12] # Drop 12th column if exists
if (ncol(sample_reads_after_thresh_df) >= 12)  sample_reads_after_thresh_df  <- sample_reads_after_thresh_df[, -12] # Drop 12th column if exists

# ===============================
# 5. Sample_Threshold_Metrics
# ===============================

# Calculate threshold reads per sample
threshold_reads_per_sample <- round(sample_sums * threshold, 0)  # Named vector: sample -> threshold reads

metric_thresh <- data.frame(
  Sample = sample_names_vec,                                                      # Column for sample names
  ReadsBeforeThreshold = colSums(asv_matrix_before_thresh[, sample_names_vec]),    # Total reads per sample before threshold
  SampleThresholdReadsSubtractedFromEachASV       = threshold_reads_per_sample[sample_names_vec],            # Threshold reads per sample
  ReadsAfterThreshold  = colSums(asv_matrix_after_thresh[, sample_names_vec]),     # Total reads per sample after threshold
  NumASVsReducedByThreshold = sapply(seq_along(sample_names_vec), function(i) {   # Count ASVs reduced per sample
    sum(asv_matrix_after_thresh[, sample_names_vec[i]] != asv_matrix_before_thresh[, sample_names_vec[i]]) # Compare before vs after
  }),
  stringsAsFactors = FALSE                                                    # Do not convert strings to factors
)


# ===============================
# 6. Summary
# ===============================
summary_thresh_df <- data.frame(
  Metric = c(
    "Total Samples Processed",                                           # Total number of samples
    "Total Reads Before Threshold",                                      # Sum of reads before threshold
    "Total Reads After Threshold",                                       # Sum of reads after threshold
    "Average Reads Per Sample Before Threshold",                         # Average reads before threshold
    "Average Reads Per Sample After Threshold",                          # Average reads after threshold
    "Total ASVs Reduced by Threshold",                                   # Total number of ASVs reduced across all samples
    "Average ASVs Reduced Per Sample"                                    # Average ASVs reduced per sample
  ),
  Value = c(
    length(sample_names_vec),                                                # Compute total samples
    sum(metric_thresh$ReadsBeforeThreshold),                               # Sum reads before
    sum(metric_thresh$ReadsAfterThreshold),                                # Sum reads after
    mean(metric_thresh$ReadsBeforeThreshold),                               # Mean reads before
    mean(metric_thresh$ReadsAfterThreshold),                                # Mean reads after
    sum(metric_thresh$NumASVsReducedByThreshold),                          # Sum of ASVs reduced
    mean(metric_thresh$NumASVsReducedByThreshold)                           # Mean ASVs reduced per sample
  ),
  stringsAsFactors = FALSE                                               # Do not convert strings to factors
)
message("  Per-sample threshold metrics computed for ", length(sample_names_vec), " samples")
message("     Total reads before threshold: ", sum(metric_thresh$ReadsBeforeThreshold))
message("     Total reads after threshold:  ", sum(metric_thresh$ReadsAfterThreshold))
message("     Total ASVs reduced by threshold: ", sum(metric_thresh$NumASVsReducedByThreshold))
# ===============================
# 7. Removed_ASVs tab
# ===============================
taxa_removed_after_thresh <- rownames(asv_matrix_before_thresh)[
  rowSums(asv_matrix_before_thresh[, sample_names_vec, drop = FALSE]) > 0 &   # ASVs present before threshold
    rowSums(asv_matrix_after_thresh[, sample_names_vec, drop = FALSE]) == 0   # ASVs gone after threshold
]

if (length(taxa_removed_after_thresh) > 0) {                              # If any ASVs were completely removed
  tax_cols <- intersect(c("Kingdom","Phylum","Class","Order","Family","Genus"), colnames(tax_info)) # Columns to keep for taxonomy
  
  removed_df <- tax_info[taxa_removed_after_thresh, tax_cols, drop = FALSE] # Extract taxonomy for removed ASVs
  
  # Add Common (species name), Sequence, ASV_ID
  common_map   <- setNames(sample_reads_before_thresh_df[, "Species"], sample_reads_before_thresh_df$ASV_ID) # Map ASV_ID  Species
  sequence_map <- setNames(sample_reads_before_thresh_df$Sequence, sample_reads_before_thresh_df$ASV_ID)    # Map ASV_ID  Sequence
  
  removed_df$Common   <- common_map[rownames(removed_df)]   # Add Common column
  removed_df$Sequence <- sequence_map[rownames(removed_df)] # Add Sequence column
  removed_df$ASV_ID   <- rownames(removed_df)               # Add ASV_ID column
  
  # Reorder columns: taxonomy (A-G), H=Common, I=Sequence, J=ASV_ID
  removed_df <- removed_df[, c(tax_cols, "Common", "Sequence", "ASV_ID")]
  rownames(removed_df) <- NULL
} else {
  removed_df <- data.frame(Note = "No ASV completely removed from study by per-sample ASV threshold. Check for ASVs removed from individual samples in next tab.") # Placeholder if no ASVs removed
}
message("   Total ASVs completely removed from study: ", nrow(removed_df))

# ===============================
# 8. Removed_Per_Sample tab
# ===============================
removed_per_sample_list <- list()                                     # Initialize list to store per-sample removals

for (s in sample_names_vec) {                                              # Loop through samples
  removed_asvs <- rownames(asv_matrix_before_thresh)[
    asv_matrix_before_thresh[, s] > 0 &                               # ASVs present before threshold
      asv_matrix_after_thresh[, s] == 0                                # ASVs removed after threshold
  ]
  
  if (length(removed_asvs) > 0) {                                     # If any ASVs removed in this sample
    tax_cols <- intersect(c("Kingdom","Phylum","Class","Order","Family","Genus"), colnames(tax_info)) # Taxonomy columns
    df <- tax_info[removed_asvs, tax_cols, drop = FALSE]              # Extract taxonomy info
    
    # Add Common, Sequence, ASV_ID, Sample
    df$Common   <- common_map[removed_asvs]                            # Species name
    df$Sequence <- sequence_map[removed_asvs]                           # DNA sequence
    df$ASV_ID   <- removed_asvs                                        # ASV ID
    df$Sample   <- s                                                   # Sample name
    
    # Reorder columns: Sample (leftmost), taxonomy, Common, Sequence, ASV_ID
    df <- df[, c("Sample", tax_cols, "Common", "Sequence", "ASV_ID")]
    
    removed_per_sample_list[[s]] <- df                                   # Store in list
  }
}

if (length(removed_per_sample_list) > 0) {                               # If any samples had ASVs removed
  removed_per_sample_df <- do.call(rbind, removed_per_sample_list)       # Combine all into one data frame
  rownames(removed_per_sample_df) <- NULL
} else {
  removed_per_sample_df <- data.frame(Note = "No ASVs completely removed from any sample by per-sample ASV threshold.") # Placeholder if none
}
num_samples_with_removals <- length(removed_per_sample_list)
message("   Number of samples with at least one ASV removed by threshold: ", num_samples_with_removals)


# ===============================
# 9. Write threshold-only Excel workbook
# ===============================
threshold_excel_path <- here(output_dir, paste0("3_",project_name, "_sample_threshold_applied.xlsx")) # Define output file path

message("   Writing threshold workbook to: ", threshold_excel_path)

write_xlsx(
  list(
    Sample_Reads_Before_Threshold = sample_reads_before_thresh_df,     # Sheet: reads before threshold
    Sample_Reads_After_Threshold  = sample_reads_after_thresh_df,      # Sheet: reads after threshold
    PerSample_ASV_Threshold_Metrics                   = metric_thresh,                       # Sheet: Sample_Threshold_Metrics
    Summary                       = summary_thresh_df,                 # Sheet: summary metrics
    Removed_ASVs                  = removed_df,                        # Sheet: removed ASVs completely
    Removed_Per_Sample            = removed_per_sample_df              # Sheet: removed ASVs per sample
  ),
  path = threshold_excel_path                                           # Write workbook to file
)

# ===============================
# 11. Create new phyloseq object after threshold
# ===============================

# Create a copy of the cleaned phyloseq object and save to global env
ps_thresh <<- ps_clean1 

# Update the OTU table with ASV counts after threshold
otu_table(ps_thresh) <<- otu_table(asv_matrix_after_thresh, taxa_are_rows = taxa_are_rows(ps_thresh))
message("   Phyloseq object 'ps_thresh' updated with thresholded ASV counts and saved to global environment")

# ===============================
# 12. Print completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    " Per-Sample ASV Threshold pipeline completed successfully! \n",
    "--------------------------------------------------------------------")

