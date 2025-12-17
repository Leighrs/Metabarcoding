message("🔹 Starting Minimum Sequencing Depth Threshold Pipeline")

# ===============================
# Minimum Sequencing Depth Threshold Pipeline
# Removes samples that do not reach a minimum read count and ASVs with 0 reads remaining.
# ===============================

# ===============================
# 1. Prepare ASV matrix and taxonomy from thresholded object
# ===============================
asv_matrix_cleaned2 <- as(otu_table(ps_thresh), "matrix") # Extract ASV counts from cleaned phyloseq object as matrix
taxa_rows2 <- taxa_are_rows(ps_thresh)                     # Check if taxa are rows in the OTU table
if (!taxa_rows2) { asv_matrix_cleaned2 <- t(asv_matrix_cleaned2) }       # If taxa are columns, transpose matrix so taxa are rows

asv_matrix_before_thresh2 <- asv_matrix_cleaned2                       # Make a copy for "before threshold" data
sample_sums2 <- colSums(asv_matrix_cleaned2)                             # Calculate total reads per sample
message("  → ASV matrix extracted from phyloseq object: ", nrow(asv_matrix_cleaned2), " ASVs x ", ncol(asv_matrix_cleaned2), " samples")

# ===============================
# 2. Compute total reads and threshold
# ===============================
total_reads <- sum(asv_matrix_cleaned2)
min_depth <- if(params$min_depth_thres < 1) {
  total_reads * params$min_depth_thres
} else {
  params$min_depth_thres
}


message("  → Total reads across all samples: ", total_reads)
threshold_type <- if(params$min_depth_thres < 1) "proportion of total reads" else "absolute read count"
threshold_value <- params$min_depth_thres
message("  → Minimum sequencing depth threshold type: ", threshold_type)
message("  → Threshold value: ", threshold_value)
message("  → Minimum sequencing depth calculated to be: ", min_depth, " reads")

# ===============================
# 3. Filter samples below threshold
# ===============================
samples_to_keep2 <- colSums(asv_matrix_cleaned2) >= min_depth
asv_matrix_filtered2 <- asv_matrix_cleaned2[, samples_to_keep2, drop = FALSE]
sample_names_vec_filtered2 <- colnames(asv_matrix_filtered2)
message("  → Samples retained after minimum depth filtering: ", sum(samples_to_keep2), " / ", length(samples_to_keep2))


# ===============================
# 4. Remove ASVs with 0 reads
# ===============================
asvs_to_keep2 <- rowSums(asv_matrix_filtered2) > 0
asv_matrix_filtered2 <- asv_matrix_filtered2[asvs_to_keep2, , drop = FALSE]
tax_info <- as.data.frame(tax_table(ps_thresh))
tax_info$Sequence <- rownames(asv_matrix_cleaned2)
tax_info$ASV_ID <- rownames(asv_matrix_cleaned2)
tax_info_filtered2 <- tax_info[asvs_to_keep2, , drop = FALSE]
message("  → ASVs retained after filtering: ", sum(asvs_to_keep2), " / ", nrow(asv_matrix_cleaned2))


# ===============================
# 5. Record removed samples and ASVs
# ===============================
sample_names_vec2 <- colnames(asv_matrix_cleaned2)
removed_samples2 <- sample_names_vec2[!samples_to_keep2]
if(length(removed_samples2) > 0){
  removed_samples_df2 <- data.frame(
    Sample = removed_samples2,
    TotalReads = colSums(asv_matrix_cleaned2[, removed_samples2, drop = FALSE])
  )
} else {
  removed_samples_df2 <- data.frame(Note = "No samples removed from study after minimum sequencing depth threshold.")
}

removed_asvs2 <- rownames(asv_matrix_cleaned2)[!asvs_to_keep2]
if(length(removed_asvs2) > 0){
  removed_asvs_df2 <- tax_info[removed_asvs2, , drop = FALSE]
} else {
  removed_asvs_df2 <- data.frame(Note = "No ASVs completely removed from study after minimum sequencing depth threshold. Check for ASVs removed from individual samples in next tab.")
}
if(length(removed_samples2) > 0){
  message("  → Samples removed: ", paste(removed_samples2, collapse = ", "))
}


# ===============================
# 6. Summary / min_depth_Metrics
# ===============================
metric_total_thresh2 <- data.frame(
  Metric = c(
    "Total_Samples_Before_Min_Seq_Depth_Threshold",
    "Total_Samples_After_Min_Seq_Depth_Threshold",
    "Total_Reads_Before_Min_Seq_Depth_Threshold",
    "Total_Reads_After_Min_Seq_Depth_Threshold",
    "Total_ASVs_Before_Min_Seq_Depth_Threshold",
    "Total_ASVs_After_Min_Seq_Depth_Threshold",
    "Total_Min_Seq_Depth_Threshold"
  ),
  Value = c(
    length(sample_names_vec2),
    length(sample_names_vec_filtered2),
    sum(asv_matrix_cleaned2),
    sum(asv_matrix_filtered2),
    nrow(asv_matrix_cleaned2),
    nrow(asv_matrix_filtered2),
    min_depth
  ),
  Notes = c(
    rep("", 6),  # leave empty for first six rows
    "Any sample with total ASVs below this threshold (rounded up if proportion) or ASVs with 0 reads remaining were removed from the study"
  ),
  stringsAsFactors = FALSE
)

# ===============================
# 7. Removed_Per_Sample tab (robust + aligned)
# ===============================

removed_per_sample_list2 <- list()

# Loop through all samples that existed before filtering
for (s in colnames(asv_matrix_before_thresh2)) {
  
  if (s %in% colnames(asv_matrix_filtered2)) {
    
    # Align ASVs by name to ensure matching dimensions
    shared_asvs <- intersect(rownames(asv_matrix_before_thresh2), rownames(asv_matrix_filtered2))
    before_vec  <- asv_matrix_before_thresh2[shared_asvs, s]
    after_vec   <- asv_matrix_filtered2[shared_asvs, s]
    
    # Identify ASVs that had reads before but are now absent (0)
    removed_asvs_in_sample <- shared_asvs[before_vec > 0 & after_vec == 0]
    
  } else {
    # If sample was removed completely, all ASVs with reads > 0 are "removed"
    removed_asvs_in_sample <- rownames(asv_matrix_before_thresh2)[
      asv_matrix_before_thresh2[, s] > 0
    ]
  }
  
  # Build data frame if ASVs were removed
  if (length(removed_asvs_in_sample) > 0) {
    tax_cols <- intersect(c("Kingdom","Phylum","Class","Order","Family","Genus"), colnames(tax_info))
    df <- tax_info[removed_asvs_in_sample, tax_cols, drop = FALSE]
    
    df$Sequence <- tax_info$Sequence[match(removed_asvs_in_sample, rownames(tax_info))]
    df$ASV_ID   <- removed_asvs_in_sample
    df$Sample   <- s
    df$Reads_Before_Removal <- asv_matrix_before_thresh2[removed_asvs_in_sample, s]
    
    # Reorder columns
    df <- df[, c("Sample", tax_cols, "Sequence", "ASV_ID", "Reads_Before_Removal")]
    removed_per_sample_list2[[s]] <- df
  }
}

# Combine results or fallback note
if (length(removed_per_sample_list2) > 0) {
  removed_per_sample_df2 <- do.call(rbind, removed_per_sample_list2)
  rownames(removed_per_sample_df2) <- NULL
} else {
  removed_per_sample_df2 <- data.frame(Note = "No ASVs completely removed from an individual sample after minimum sequencing depth threshold.")
}
num_samples_with_removed_asvs <- length(unique(removed_per_sample_df2$Sample))
message("  → Samples with at least one ASV removed: ", num_samples_with_removed_asvs)

# ===============================
# 8. Write Excel workbook
# ===============================

# ---- Sample_Reads_Before_Threshold ----
Sample_Reads_Before_Threshold <- cbind(tax_info, as.data.frame(asv_matrix_before_thresh2))

# Rename column J (10th) to "Sequence" and remove column K (11th) if present
if (ncol(Sample_Reads_Before_Threshold) >= 10) {
  colnames(Sample_Reads_Before_Threshold)[10] <- "Sequence"
}
if (ncol(Sample_Reads_Before_Threshold) >= 11) {
  Sample_Reads_Before_Threshold <- Sample_Reads_Before_Threshold[, -11, drop = FALSE]
}

# ---- Sample_Reads_After_Threshold ----
Sample_Reads_After_Threshold <- cbind(tax_info_filtered2, as.data.frame(asv_matrix_filtered2))

# Rename column J (10th) to "Sequence" and remove column K (11th) if present
if (ncol(Sample_Reads_After_Threshold) >= 10) {
  colnames(Sample_Reads_After_Threshold)[10] <- "Sequence"
}
if (ncol(Sample_Reads_After_Threshold) >= 11) {
  Sample_Reads_After_Threshold <- Sample_Reads_After_Threshold[, -11, drop = FALSE]
}

# ---- Removed_ASVs ----
Removed_ASVs <- removed_asvs_df2

# Rename column J (10th) to "Sequence" and remove column K (11th) if present
if (ncol(Removed_ASVs) >= 10) {
  colnames(Removed_ASVs)[10] <- "Sequence"
}
if (ncol(Removed_ASVs) >= 11) {
  Removed_ASVs <- Removed_ASVs[, -11, drop = FALSE]
}

# ---- Write Excel workbook ----
excel_path2 <- here(output_dir, paste0("5_",project_name, "_min_seq_depth_threshold_applied.xlsx"))

write_xlsx(
  list(
    Sample_Reads_Before_Threshold = Sample_Reads_Before_Threshold,
    Sample_Reads_After_Threshold          = Sample_Reads_After_Threshold,
    Removed_Samples        = removed_samples_df2,
    Removed_ASVs           = Removed_ASVs,
    Removed_Per_Sample     = removed_per_sample_df2,
    Min_Seq_Depth_Metrics            = metric_total_thresh2
  ),
  path = excel_path2
)
message("  → Excel workbook saved at: ", excel_path2)

# ===============================
# 10. Create new phyloseq object after filtering
# ===============================
ps_thresh2 <<- prune_samples(sample_names_vec_filtered2, ps_thresh)

# Prune taxa using ASV IDs, not a logical vector
asvs_to_keep_ids <<- rownames(asv_matrix_filtered2)
ps_thresh2 <<- prune_taxa(asvs_to_keep_ids, ps_thresh2)

# Export phyloseq object
saveRDS(ps_thresh2, file = here(output_dir,"dada2_phyloseq_cleaned.rds"))
message("  → Phyloseq object updated with retained samples and ASVs")
message("     • Samples: ", length(sample_names_vec_filtered2))
message("     • ASVs: ", nrow(asv_matrix_filtered2))
message("  → Phyloseq object saved as 'dada2_phyloseq_cleaned.rds'")

# ===============================
# 11. Completion message
# ===============================
cat("-------------------------------------------------------------------- \n",
    "🧬 Minimum sequencing depth threshold pipeline completed successfully! 🧬\n",
    "--------------------------------------------------------------------")

