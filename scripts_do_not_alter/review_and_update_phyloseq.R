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

normalize_tax_table_schema <- function(ps) {
  tax_mat <- as(tax_table(ps), "matrix")
  tax_mat <- as.matrix(tax_mat)

  # keep ASV/taxa IDs intact
  rn <- rownames(tax_mat)
  if (is.null(rn) || length(rn) != ntaxa(ps)) {
    stop("tax_table rownames are missing or wrong length.", call. = FALSE)
  }

  rename_map <- c(
    Domain = "Kingdom",
    Superkingdom = "Kingdom",
    Division = "Phylum"
  )

  for (from in names(rename_map)) {
    to <- rename_map[[from]]
    if (from %in% colnames(tax_mat) && !(to %in% colnames(tax_mat))) {
      colnames(tax_mat)[colnames(tax_mat) == from] <- to
    }
  }

  if ("sequence" %in% colnames(tax_mat) && !("ASV_sequence" %in% colnames(tax_mat))) {
    colnames(tax_mat)[colnames(tax_mat) == "sequence"] <- "ASV_sequence"
  }

  required <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species","Common")
  missing <- setdiff(required, colnames(tax_mat))

  if (length(missing) > 0) {
    add_mat <- matrix(
      "",
      nrow = nrow(tax_mat),
      ncol = length(missing),
      dimnames = list(rn, missing)
    )
    tax_mat <- cbind(tax_mat, add_mat)
  }

  rownames(tax_mat) <- rn

  # force exact same taxa order as the phyloseq object
  tax_mat <- tax_mat[taxa_names(ps), , drop = FALSE]

  tax_table(ps) <- phyloseq::tax_table(tax_mat)
  ps
}

is_plant_like <- function(x) {
  x <- tolower(trimws(as.character(x)))
  if (is.na(x) || !nzchar(x)) return(FALSE)

  plant_patterns <- c(
    # broad plant terms
    "viridiplantae", "plantae", "embryophyta", "streptophyta",
    "tracheophyta", "spermatophyta",

    # major clades (VERY important in your data)
    "angiosperm", "mesangiospermae", "pentapetalae",
    "asterid", "rosid", "fabid", "lamiid", "irl clade",

    # classes
    "liliopsida", "magnoliopsida",

    # common plant families in your data
    "poaceae", "brassicaceae", "rosaceae", "fabaceae",
    "asteraceae", "cactaceae", "cupressaceae",
    "convolvulaceae", "salicaceae", "lactucinae",

    # very common plant genera in your dataset
    "geranium", "medicago", "trifolium", "lathyrus",
    "prunus", "solanum", "citrus", "olea",
    "hibiscus", "vaccinium", "vicia", "lonicera",
    "ipomoea", "convolvulus", "brassica", "arabidopsis",
    "populus", "salix", "juniperus", "cupressus",
    "magnolia", "daucus", "lactuca", "centaurea",

    # crops / grasses
    "oryza", "hordeum", "aegilops", "triticum",
    "saccharum", "poa", "festuca",

    # generic signals
    "plant", "chloroplast",
    
    # species
    "Silene wilfordii", "Psittacanthus sonorae", " Psittacanthus palmeri",
    "Sassafras randaiense", "Persea americana", "Actinodaphne obovata",
    "Machilus bonii", "Phoebe hungmoensis", "Machilus thunbergii",
    "Licaria capitata"
  )

  grepl(paste(plant_patterns, collapse = "|"), x, ignore.case = TRUE)
}

is_fungal_like <- function(x) {
  x <- tolower(trimws(as.character(x)))
  if (is.na(x) || !nzchar(x)) return(FALSE)

  fungal_patterns <- c(
    "fungi", "fungal", "ascomyc", "basidiomyc",
    "dothideomyc", "dothideomycetidae", "dothideomyceta",
    "chaetothyr", "chaetothyriomycetidae",
    "eurotiales", "eurotiomycetes", "hypocreales", "helotiales",
    "leotiomyc", "sordariomyc", "nectriaceae", "sclerotiniaceae",
    "orbiliaceae", "entomophthoraceae", "arthoniaceae",
    "aspergill", "aspergillaceae", "penicill", "fusarium", "trichoderma",
    "cladospor", "ramularia", "epichloe", "emericellopsis",
    "capronia", "micarea", "lecanora", "lecania",
    "lecanoraceae", "lecanorineae", "xanthoria",
    "candelariella", "bacidia", "bacidina", "arthonia",
    "verrucaria", "verrucariaceae", "lichenostigma",
    "buell", "teloschistaceae", "phaeococcomycetaceae",
    "trichomerium", "scolecobasidium", "podosphaera",
    "myriangium", "cyphellophora", "coccomyces",
    "dactylellina", "diplotomma", "corticifraga",
    "scorias", "knufia", "abrothallus", "antarctolichenia",
    "chrysothrix", "cistella", "dichoporis", "dioszegia",
    "lichenicolous",
    "sterigmatomyces", "naetrocymbe", "psoroglaena", "recurvomyces",
    "resinoscypha", "sarocladium", "sclerococcum",
    "scopulariopsis", "stictis", "vandijckella",
    "pilidium", "mollisia", "meristemomyces",
    "microascus", "microcera", "neopestalotiopsis",
    "phaeococcomyces", "botryosphaeria", "botryosphaeriaceae",
    "leuconeurospora", "lichenostigmatales", "thelebolus",
    "exobasidium", "albugo", "pleospor", "rhytismat", "xylari", "cephalotrichum",
    "physcia", "ploettnerulaceae", "oculimacula yallundae", "rhynchosporium graminicola",
    "cladonia", "ramalinaceae", "apiospora arundinis", "biatora vacciniicola", "leptogium palmatum",   
    "bryochiton monascus", "amandinea punctata", "cudoniella clavus", "herpotrichiellaceae",
    "acremonium", "lecanoropsis saligna", "letharia columbiana", "constantinomyces virgultus"
  )

  grepl(paste(fungal_patterns, collapse = "|"), x, ignore.case = TRUE)
}

is_too_broad_assignment <- function(x) {
  x <- tolower(trimws(as.character(x)))
  if (is.na(x) || !nzchar(x)) return(FALSE)

  patterns <- c(
    "tied hits agree on species uncultured organism",
    "tied hits agree on species unidentified",
    "tied hits agree on species uncultured microorganism",
    "tied hits agree on species uncultured eukaryote",
    "tied hits agree on species uncultured diatom",
    "tied hits agree on species uncultured archaeon",
    "Lowest shared taxon: environmental samples",
    "tied hits agree on species uncultured phototrophic eukaryote"
  )

  grepl(paste(patterns, collapse = "|"), x, ignore.case = TRUE)
}

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
  if (x %in% c("y","yes","remove","removed","true","t","1","ues","tes","ye","yse","yas","yws","yez","yex","ys","yess","yds","yss","tes","y3s")) return("remove")
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

is_bacterial_like <- function(x) {
  x <- tolower(trimws(as.character(x)))
  if (is.na(x) || !nzchar(x)) return(FALSE)

  strong_bacterial_patterns <- c(
    "uncultured bacterium",
    "bacterium",
    "bacteria",
    "uncultured prokaryote",
    "prokaryote",
    "prokaryotic",
    "cyanobacter",
    "actinomyc",
    "actinomy",
    "actinoplan",
    "actinacidiphila",
    "acidiphilium",
    "acetatifactor",
    "adlercreutzia",
    "aerococc",
    "aeromicrobium",
    "aeromonad",
    "agrococcus",
    "agromyces",
    "akkermansia",
    "algoriphagus",
    "aurantimonas",
    "alcaligen",
    "alicycliphilus",
    "alistipes",
    "alkaligen",
    "acetivibrio",
    "acholeplasma",
    "acidisoma",
    "acidisphaera",
    "acidothermus",
    "aequorivita",
    "alkanindiges",
    "alloactinosynnema",
    "alysiella",
    "amycolatopsis",
    "anaerospora",
    "anaerovorax",
    "arthrocatena",
    "aureimonas",
    "bacill",
    "barnesiella",
    "bartonella",
    "bdellovibr",
    "blautia",
    "blastopirellula",
    "bythopirellula",
    "bosea",
    "boudabousia",
    "bradyrhizob",
    "brevundimonas",
    "brucell",
    "buchnera",
    "burkholder",
    "butyricicoccus",
    "butyrivibrio",
    "caldimonas",
    "cellulomon",
    "cellulosimicrobium",
    "cellulosilytic",
    "cellvibrio",
    "chlamyd",
    "chloroflex",
    "chroococc",
    "chthoniobacter",
    "chthonomonas",
    "clostrid",
    "corallococcus",
    "croceicoccus",
    "candidatus hepatincola",
    "kosakonia arachidis",
    "candidatus xiphinematobacter",
    "cytophag",
    "delftia",
    "desulfovibr",
    "devosia",
    "dyella",
    "dielma",
    "enterococcus",
    "enterorhabdus",
    "erwinia",
    "facklamia",
    "fischerella",
    "francisell",
    "frondihabitans",
    "galbitalea",
    "gemmata",
    "gemmatimon",
    "georgenia",
    "glycomycet",
    "haliangium",
    "halomon",
    "hyphomicrob",
    "iamia",
    "ignatzschineria",
    "isoptericola",
    "jatrophihabitans",
    "kingella",
    "kineococcus",
    "kineospori",
    "kocuria",
    "lachnospir",
    "lactiplantibacillus",
    "lactobacill",
    "legionell",
    "leifsonia",
    "leptolyngbya",
    "leuconostoc",
    "lewinell",
    "limibaculum",
    "luteimonas",
    "mammaliicoccus",
    "marinomonas",
    "martelella",
    "marininema",
    "marinococcus",
    "marmoricola",
    "mesomycoplasma",
    "micrococc",
    "micromonospora",
    "microvirga",
    "minicystis",
    "mordavella",
    "moraxella",
    "morganell",
    "muricoccus",
    "mycoplas",
    "myroides",
    "myxococc",
    "nakamurella",
    "nannocystis",
    "neisseri",
    "nitrosomonas",
    "nocardia",
    "nocardio",
    "nocardiopsis",
    "nostoc",
    "nostocales",
    "novosphingob",
    "mucilaginibacter",
    "oceanisphaera",
    "parabacteroides",
    "ohtaekwangia",
    "phragmitibacter",
    "psychrobacter",
    "sanguibacter",
    "sedimentibacter",
    "streptococcus",
    "streptomyces",
    "caedibacter",
    "acinetobacter",
    "adhaeribacter",
    "angustibacter",
    "bacteroides",
    "bryobacter",
    "candidatus Solibacter",
    "caulobacter",
    "conexibacter",
    "edaphobacter",
    "citrobacter",
    "konicacronema",
    "coleofasciculus",
    "leptospira",
    "flavisolibacter",
    "helicobacter",
    "hymenobacter",
    "granulicella",
    "actinotalea",
    "anabaena",
    "lysobacter",
    "oscillibacter",
    "parabacteroides",
    "patulibacter",
    "actinobaculum",
    "bacteroides",
    "conexibacter",
    "adhaeribacter",
    "rodentibacter",
    "sanguibacter",
    "streptomyces",
    "hydrotalea",
    "pedobacter",
    "peredibacter",
    "peredibacter",
    "ramlibacter",
    "prosthecobacter",
    "pseudoramibacter",
    "rubrobacter",
    "segetibacter",
    "solirubrobacter",
    "streptococcus parauberis",
    "campylobacter",
    "pseudaminobacter",
    "verminephrobacter",
    "hungatella hathewayi",
    "gordonibacter faecis",
    "candidatus korobacter",
    "brenneria goodwinii",
    "endosaccharibacter",
    "dyadobacter",
    "arcticibacter",
    "bisgaard taxon 44",
    "ammoniphilus",
    "candidatus soleaferrea",
    "candidatus onthousia faecigallinarum",
    "luteolibacter",
    "leucobacter",
    "bacteriovorax",
    "helcococcus",
    "ilyomonas",
    "candidatus aschnera chinzeii",
    "candidatus hepatoplasma vulgare",
    "pontibacter",
    "opitutus",
    "oscillospira",
    "paenalcaligenes",
    "paraburkholder",
    "paracoccus",
    "pasteurell",
    "pasteuria",
    "pediococcus",
    "pelistega",
    "peptostrept",
    "phocaeicola",
    "phycisphaera",
    "planctomyc",
    "planococcus",
    "porphyromonas",
    "prevotella",
    "prokary",
    "proteus",
    "providencia",
    "pseudanabaenaceae",
    "pseudescherichia",
    "pseudokineococcus",
    "pseudomon",
    "pusillimonas",
    "qipengyuania",
    "raoultella",
    "ralstonia",
    "rhizob",
    "rhodococcus",
    "rhodospirill",
    "riemerella",
    "roseburia",
    "roseomonas",
    "roseovarius",
    "rothia",
    "rubellimicrobium",
    "rubripirellula",
    "ruminococcus",
    "salinibacterium",
    "serratia",
    "shewanella",
    "shigella",
    "singulisphaera",
    "skermanella",
    "soehngenia",
    "sphingobacter",
    "sphingomon",
    "sphingopyx",
    "spiroplasma",
    "spirosoma",
    "sporosarcina",
    "staphyl",
    "teichococcus",
    "terriglobus",
    "tetragenococcus",
    "tissierella",
    "tomitella",
    "ureaplasma",
    "vagococcus",
    "variovorax",
    "veillonella",
    "velocimicrobium",
    "verrucomicrobi",
    "vitreoscilla",
    "weissella",
    "williamsia",
    "wolbach",
    "xanthomon",
    "xenorhabdus",
    "yaniella",
    "yersinia",
    "zavarzinella"
  )

  grepl(paste(strong_bacterial_patterns, collapse = "|"), x, ignore.case = TRUE)
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
  "  - Excluded_by_BLAST: ASVs that were BLASTed but did not meet thresholds and will be removed unless manually rescued.",
  "  - Excluded_by_Reviewer: ASVs removed after review (Remove_ASV == yes OR incomplete taxonomy after review).",
  "",
  "For_Review Tab Contents:",
  "  - Current_* columns:",
  "      - Existing taxonomic assignments from your phyloseq object or nf-core/ampliseq output.",
  "      - These reflect the taxonomy prior to BLAST review.",
  "",
  "  - Proposed_* columns:",
  "      - Taxonomic assignments derived from BLAST results.",
  "      - These serve as a suggested starting point for review.",
  "",
  "  - Approve:",
  "      - Do you agree with the BLAST assignment?",
  "      - Leave blank or enter 'yes' to approve.",
  "      - Enter 'no' to disapprove.",
  "",
  "  - Disapprove_Reason:",
  "      - Recommended if Approve = no. Good for record keeping.",
  "      - Briefly explain why the BLAST assignment is incorrect or too specific.",
  "",
  "  - Remove_ASV:",
  "      - Enter 'yes' to remove this ASV from the final phyloseq object.",
  "      - Leave blank to keep the ASV.",
  "",
  "  - Override_* columns:",
  "      - Manual taxonomy assignments.",
  "      - These columns correspond to ALL available taxonomic ranks.",
  "      - You MUST fill every Override_* column for ASVs you intend to keep.",
  "          - Use a valid taxon name OR 'NA'.",
  "          - For easier viewing, the Override cells that MUST be filled in if you want to KEEP that ASV are highlighted RED",
  "      - If any Override_* column is left blank (and Remove_ASV is not 'yes'), the script will STOP and require completion.",
  "",
  "      - Behavior:",
  "          - If Approve = yes or blank:",
  "              - BLAST assignment is used as the base.",
  "              - Override_* values replace any ranks you specify.",
  "          - If Approve = no:",
  "              - If NO overrides are provided ? all ranks will be set to 'unknown'.",
  "              - If SOME overrides are provided ? ALL Override_* columns must be filled.",
  "",
  "      - Autofill behavior:",
  "          - If BLAST assigns at a higher rank (e.g., Family), lower ranks are auto-filled as '<Final_Taxon> spp'.",
  "          - You can override these values if needed.",
  "",
  "Additional Notes:",
  "  - Taxonomic ranks are dynamic and depend on your reference database (e.g., Supergroup, Subdivision, etc.).",
  "  - All ranks present in your phyloseq object will be included.",
  "  - ASVs with incomplete taxonomy after review will be removed automatically.",
  "  - ASVs in Excluded_by_BLAST can be manually rescued using that tab.",
  "  - Confidence values are set to 'overridden' if manual edits are applied after disapproval."
)

# ----------------------------
# Inputs (env vars)
# ----------------------------
PROJECT_NAME <- Sys.getenv("PROJECT_NAME", unset = "")
stop_if_missing(PROJECT_NAME, "PROJECT_NAME")

BASE_DIR <- Sys.getenv(
  "BASE_DIR",
  unset = "/group/ajfingergrp/Metabarcoding/Project_Runs"
)

PROJECT_DIR <- Sys.getenv(
  "PROJECT_DIR",
  unset = file.path(BASE_DIR, PROJECT_NAME)
)

if (!dir.exists(PROJECT_DIR)) {
  stop("PROJECT_DIR does not exist: ", PROJECT_DIR, call. = FALSE)
}

TREAT_BACTERIA <- tolower(Sys.getenv("TREAT_BACTERIA", "FALSE")) == "true"
TREAT_FUNGI    <- tolower(Sys.getenv("TREAT_FUNGI", "FALSE")) == "true"
TREAT_PLANTS   <- tolower(Sys.getenv("TREAT_PLANTS", "FALSE")) == "true"

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

ASV_FASTA <- Sys.getenv(
  "ASV_FASTA",
  unset = file.path(PROJECT_DIR, "output", "dada2", "ASV_seqs.fasta")
)

ASV_TABLE_TSV <- Sys.getenv(
  "ASV_TABLE_TSV",
  unset = file.path(PROJECT_DIR, "output", "dada2", "DADA2_table.tsv")
)

RUN_MODE <- tolower(trimws(Sys.getenv("REVIEW_RUN_MODE", unset = "")))
if (!RUN_MODE %in% c("first", "second", "reprocess")) {
  stop(
    "Invalid or missing REVIEW_RUN_MODE. Expected one of: first, second, reprocess",
    call. = FALSE
  )
}

xlsx_exists <- file.exists(review_xlsx)

user <- Sys.getenv("USER", unset = "")
stop_if_missing(user, "USER")

host <- "farm.hpc.ucdavis.edu"

if (!file.exists(BLAST_FILE)) stop("Cannot find BLAST taxonomy file: ", BLAST_FILE, call. = FALSE)

# ----------------------------
# Load or create phyloseq
# ----------------------------

phyloseq_source <- if (file.exists(PHYLOSEQ_RDS)) "existing" else "created_from_dada2"

if (phyloseq_source == "created_from_dada2") {
  METADATA_TSV <- Sys.getenv("METADATA_TSV", unset = "")

  stop_if_missing(ASV_TABLE_TSV, "ASV_TABLE_TSV")
  stop_if_missing(METADATA_TSV, "METADATA_TSV")

  message("PHYLOSEQ_RDS not found. Creating phyloseq from DADA2 table + metadata...")
  ps <- make_phyloseq_from_dada2_table(ASV_TABLE_TSV, METADATA_TSV)

} else {
  message("Loading existing phyloseq object without modifying original: ", PHYLOSEQ_RDS)
  ps <- readRDS(PHYLOSEQ_RDS)

  if (!inherits(ps, "phyloseq")) {
    stop("Loaded object is not a phyloseq object: ", PHYLOSEQ_RDS, call. = FALSE)
  }
}
ps <- normalize_tax_table_schema(ps)

tax <- tax_table(ps)
tax_mat <- as(tax, "matrix")
tax_cols_all <- colnames(tax_mat)

extra_tax_ranks <- strsplit(Sys.getenv("EXTRA_TAX_RANKS", unset = ""), ",")[[1]]
extra_tax_ranks <- trimws(extra_tax_ranks)
extra_tax_ranks <- extra_tax_ranks[nzchar(extra_tax_ranks)]

for (cc in extra_tax_ranks) {
  if (!(cc %in% colnames(tax_mat))) {
    tax_mat <- cbind(
      tax_mat,
      matrix("", nrow = nrow(tax_mat), ncol = 1,
             dimnames = list(rownames(tax_mat), cc))
    )
  }
}

tax_table(ps) <- phyloseq::tax_table(tax_mat)
tax <- tax_table(ps)
tax_mat <- as(tax, "matrix")
tax_cols_all <- colnames(tax_mat)

non_editable_tax_cols <- c("confidence", "Confidence", "CONFIDENCE",
                           "sequence", "Sequence",
                           "ASV_sequence", "asv_sequence")

standard_rank_order <- c("Kingdom","Supergroup","Phylum","Subdivision",
                         "Class","Order","Family","Genus","Species",
                         "Common")

editable_cols <- intersect(
  unique(c(standard_rank_order, extra_tax_ranks, tax_cols_all)),
  tax_cols_all
)

editable_cols <- setdiff(editable_cols, non_editable_tax_cols)

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
rank_order <- get_rank_order(tax_cols_rank)

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

standard_review_cols <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species","Common")

current_cols <- intersect(
  unique(c(colnames(taxm0), standard_review_cols, extra_tax_ranks)),
  colnames(taxm0)
)

current_cols <- setdiff(current_cols, c("confidence", "ASV_sequence", "sequence"))

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
  proposed_cols <- editable_cols
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

# Detect fungal-like entries only if enabled
fungal_rows <- rep(FALSE, nrow(df))
if (TREAT_FUNGI) {
  if ("Explanation" %in% names(df)) {
    fungal_rows <- fungal_rows | vapply(df[["Explanation"]], is_fungal_like, logical(1))
  }
  if ("Final_Taxon" %in% names(df)) {
    fungal_rows <- fungal_rows | vapply(df[["Final_Taxon"]], is_fungal_like, logical(1))
  }
}

# Detect bacterial-like entries only if enabled
bacterial_rows <- rep(FALSE, nrow(df))
if (TREAT_BACTERIA) {
  if ("Explanation" %in% names(df)) {
    bacterial_rows <- bacterial_rows | vapply(df[["Explanation"]], is_bacterial_like, logical(1))
  }
  if ("Final_Taxon" %in% names(df)) {
    bacterial_rows <- bacterial_rows | vapply(df[["Final_Taxon"]], is_bacterial_like, logical(1))
  }
}

# Detect plant-like entries only if enabled
plant_rows <- rep(FALSE, nrow(df))
if (TREAT_PLANTS) {
  if ("Explanation" %in% names(df)) {
    plant_rows <- plant_rows | vapply(df[["Explanation"]], is_plant_like, logical(1))
  }
  if ("Final_Taxon" %in% names(df)) {
    plant_rows <- plant_rows | vapply(df[["Final_Taxon"]], is_plant_like, logical(1))
  }
}

# If both fungal and bacterial signatures occur, remove the ASV
mixed_microbe_rows <- rep(FALSE, nrow(df))
if (TREAT_BACTERIA && TREAT_FUNGI) {
  mixed_microbe_rows <- fungal_rows & bacterial_rows
}

if (any(mixed_microbe_rows)) {
  if ("Remove_ASV" %in% names(df)) {
    cur_remove <- ifelse(is.na(df[["Remove_ASV"]]), "", as.character(df[["Remove_ASV"]]))
    df[["Remove_ASV"]][mixed_microbe_rows & !nzchar(trimws(cur_remove))] <- "yes"
  }

  if ("Disapprove_Reason" %in% names(df)) {
    cur_reason <- ifelse(is.na(df[["Disapprove_Reason"]]), "", as.character(df[["Disapprove_Reason"]]))
    df[["Disapprove_Reason"]][mixed_microbe_rows & !nzchar(trimws(cur_reason))] <- "Conflicting fungal and bacterial taxa assignment."
  }

  if ("Approve" %in% names(df)) {
    cur_approve <- ifelse(is.na(df[["Approve"]]), "", as.character(df[["Approve"]]))
    df[["Approve"]][mixed_microbe_rows & !nzchar(trimws(cur_approve))] <- "no"
  }

  for (oc in override_cols) {
    if (oc %in% names(df)) {
      df[[oc]][mixed_microbe_rows] <- "NA"
    }
  }
}

# If plant and fungal/bacterial signatures both occur, remove the ASV
mixed_plant_microbe_rows <- rep(FALSE, nrow(df))
if (TREAT_PLANTS && (TREAT_BACTERIA || TREAT_FUNGI)) {
  mixed_plant_microbe_rows <- plant_rows & (bacterial_rows | fungal_rows)
}

if (any(mixed_plant_microbe_rows)) {
  if ("Remove_ASV" %in% names(df)) {
    cur_remove <- ifelse(is.na(df[["Remove_ASV"]]), "", as.character(df[["Remove_ASV"]]))
    df[["Remove_ASV"]][mixed_plant_microbe_rows & !nzchar(trimws(cur_remove))] <- "yes"
  }

  if ("Disapprove_Reason" %in% names(df)) {
    cur_reason <- ifelse(is.na(df[["Disapprove_Reason"]]), "", as.character(df[["Disapprove_Reason"]]))
    df[["Disapprove_Reason"]][mixed_plant_microbe_rows & !nzchar(trimws(cur_reason))] <- "Conflicting plant and microbial taxa assignment."
  }

  if ("Approve" %in% names(df)) {
    cur_approve <- ifelse(is.na(df[["Approve"]]), "", as.character(df[["Approve"]]))
    df[["Approve"]][mixed_plant_microbe_rows & !nzchar(trimws(cur_approve))] <- "no"
  }

  for (oc in override_cols) {
    if (oc %in% names(df)) {
      df[[oc]][mixed_plant_microbe_rows] <- "NA"
    }
  }
}

# Remove mixed rows from autofill
fungal_rows <- fungal_rows & !mixed_microbe_rows & !mixed_plant_microbe_rows
bacterial_rows <- bacterial_rows & !mixed_microbe_rows & !mixed_plant_microbe_rows
plant_rows <- plant_rows & !mixed_plant_microbe_rows

# Autofill plant rows
plant_only <- plant_rows & !bacterial_rows & !fungal_rows

if (TREAT_PLANTS && any(plant_only)) {
  if ("Override_Kingdom" %in% names(df)) {
    cur <- ifelse(is.na(df[["Override_Kingdom"]]), "", as.character(df[["Override_Kingdom"]]))
    df[["Override_Kingdom"]][plant_only & !nzchar(trimws(cur))] <- "Plantae"
  }

  for (oc in c("Override_Phylum", "Override_Class", "Override_Order",
               "Override_Family", "Override_Genus", "Override_Species",
               "Override_Common")) {
    if (oc %in% names(df)) {
      cur <- ifelse(is.na(df[[oc]]), "", as.character(df[[oc]]))
      df[[oc]][plant_only & !nzchar(trimws(cur))] <- "Plant spp"
    }
  }
}

# Autofill fungal rows
if (TREAT_FUNGI && any(fungal_rows)) {
  if ("Override_Kingdom" %in% names(df)) {
    cur <- ifelse(is.na(df[["Override_Kingdom"]]), "", as.character(df[["Override_Kingdom"]]))
    df[["Override_Kingdom"]][fungal_rows & !nzchar(trimws(cur))] <- "Fungi"
  }

  for (oc in c("Override_Phylum", "Override_Class", "Override_Order",
               "Override_Family", "Override_Genus", "Override_Species",
               "Override_Common")) {
    if (oc %in% names(df)) {
      cur <- ifelse(is.na(df[[oc]]), "", as.character(df[[oc]]))
      df[[oc]][fungal_rows & !nzchar(trimws(cur))] <- "Fungi spp"
    }
  }
}

# Autofill bacterial rows
if (TREAT_BACTERIA && any(bacterial_rows)) {
  if ("Override_Kingdom" %in% names(df)) {
    cur <- ifelse(is.na(df[["Override_Kingdom"]]), "", as.character(df[["Override_Kingdom"]]))
    df[["Override_Kingdom"]][bacterial_rows & !nzchar(trimws(cur))] <- "Bacteria"
  }

  for (oc in c("Override_Phylum", "Override_Class", "Override_Order",
               "Override_Family", "Override_Genus", "Override_Species",
               "Override_Common")) {
    if (oc %in% names(df)) {
      cur <- ifelse(is.na(df[[oc]]), "", as.character(df[[oc]]))
      df[[oc]][bacterial_rows & !nzchar(trimws(cur))] <- "Bacteria spp"
    }
  }
}


# Mark vague/too-broad explanation rows for removal
if ("Explanation" %in% names(df)) {
  broad_rows <- vapply(df[["Explanation"]], is_too_broad_assignment, logical(1))

  if (any(broad_rows)) {

    # --- Remove_ASV ---
    if ("Remove_ASV" %in% names(df)) {
      cur_remove <- ifelse(is.na(df[["Remove_ASV"]]), "", as.character(df[["Remove_ASV"]]))
      df[["Remove_ASV"]][broad_rows & !nzchar(trimws(cur_remove))] <- "yes"
    }

    # --- Disapprove reason ---
    if ("Disapprove_Reason" %in% names(df)) {
      cur_reason <- ifelse(is.na(df[["Disapprove_Reason"]]), "", as.character(df[["Disapprove_Reason"]]))
      df[["Disapprove_Reason"]][broad_rows & !nzchar(trimws(cur_reason))] <- "Taxa assignment unclear/too broad"
    }

    # --- Force disapproval ---
    if ("Approve" %in% names(df)) {
      cur_approve <- ifelse(is.na(df[["Approve"]]), "", as.character(df[["Approve"]]))
      df[["Approve"]][broad_rows & !nzchar(trimws(cur_approve))] <- "no"
    }

    # --- NEW: Set all override columns to NA ---
    for (oc in override_cols) {
      if (oc %in% names(df)) {
        df[[oc]][broad_rows] <- "NA"
      }
    }
  }
}

# Build excluded_by_blast_df for the workbook:
# all ASVs in ASV_FASTA that are not present in the review table,
# with total read abundance from DADA2_table.tsv

# Decide which FASTA defines the review universe
phyloseq_existed_at_start <- file.exists(PHYLOSEQ_RDS)

review_universe_fasta <- if (
  phyloseq_existed_at_start &&
  file.exists(UNASSIGNED_FASTA)
) {
  UNASSIGNED_FASTA
} else {
  ASV_FASTA
}

# Build abundance table from DADA2_table.tsv (keep per-sample counts)
asv_abundance <- numeric(0)
asv_counts_df <- NULL

if (file.exists(ASV_TABLE_TSV)) {
  dada_tab <- read.delim(
    ASV_TABLE_TSV,
    sep = "\t",
    header = TRUE,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  if (!("ASV_ID" %in% names(dada_tab))) {
    stop("DADA2_table.tsv must contain an 'ASV_ID' column.", call. = FALSE)
  }

  non_count_cols <- intersect(c("ASV_ID", "sequence"), names(dada_tab))
  count_cols <- setdiff(names(dada_tab), non_count_cols)

  if (length(count_cols) > 0) {
    count_mat <- as.data.frame(dada_tab[, count_cols, drop = FALSE], stringsAsFactors = FALSE)
    count_mat[] <- lapply(count_mat, function(x) suppressWarnings(as.numeric(x)))
    count_mat[is.na(count_mat)] <- 0

    # store full table (per-sample)
    asv_counts_df <- count_mat
    rownames(asv_counts_df) <- as.character(dada_tab$ASV_ID)

    # keep total abundance with names
    asv_abundance <- rowSums(as.matrix(count_mat))
    names(asv_abundance) <- as.character(dada_tab$ASV_ID)
  }
}

if (file.exists(review_universe_fasta)) {
  all_asv_seqs <- tryCatch(
    readDNAStringSet(review_universe_fasta, format = "fasta"),
    error = function(e) NULL
  )

  if (!is.null(all_asv_seqs) && length(all_asv_seqs) > 0) {
    all_asv_ids <- names(all_asv_seqs)
    all_asv_ids <- all_asv_ids[nzchar(all_asv_ids)]

    review_ids <- if ("ASV" %in% names(df)) as.character(df$ASV) else character(0)
    review_ids <- review_ids[nzchar(review_ids)]

    excluded_ids <- setdiff(all_asv_ids, review_ids)

    if (length(excluded_ids) > 0) {
      excluded_seqs <- all_asv_seqs[excluded_ids]

      abund_vals <- asv_abundance[excluded_ids]
      abund_vals[is.na(abund_vals)] <- 0

excluded_by_blast_df <- data.frame(
  ASV = excluded_ids,
  `Include?` = "",

  Override_Kingdom = "",
  Override_Phylum = "",
  Override_Class = "",
  Override_Order = "",
  Override_Family = "",
  Override_Genus = "",
  Override_Species = "",
  Override_Common = "",

  Query_Cover = "",
  E_value = "",
  Per_Identity = "",
  NCBI_Accession = "",

  Read_Abundance = as.numeric(abund_vals),
  Sequence = as.character(excluded_seqs),
  Length = nchar(as.character(excluded_seqs)),

  stringsAsFactors = FALSE
)

# --- NEW: add per-sample abundances ---
if (!is.null(asv_counts_df)) {
  sample_counts <- asv_counts_df[excluded_ids, , drop = FALSE]
  sample_counts[is.na(sample_counts)] <- 0

  excluded_by_blast_df <- cbind(
    excluded_by_blast_df,
    sample_counts
  )
}

      excluded_by_blast_df <- excluded_by_blast_df[order(-excluded_by_blast_df$Read_Abundance), , drop = FALSE]
    }
  }
}

override_and_review_cols <- c(
  "Include?",
  "Override_Kingdom",
  "Override_Phylum",
  "Override_Class",
  "Override_Order",
  "Override_Family",
  "Override_Genus",
  "Override_Species",
  "Override_Common",
  "Query_Cover",
  "E_value",
  "Per_Identity",
  "NCBI_Accession"
)

for (cc in intersect(override_and_review_cols, names(excluded_by_blast_df))) {
  excluded_by_blast_df[[cc]][trimws(as.character(excluded_by_blast_df[[cc]])) == ""] <- "NA"
}

if (RUN_MODE == "first") {
  if (xlsx_exists) {
    stop(
      "Review workbook already exists:\n  ", review_xlsx, "\n",
      "Use REVIEW_RUN_MODE=reprocess to overwrite it, or REVIEW_RUN_MODE=second to continue.",
      call. = FALSE
    )
  }
}

if (RUN_MODE == "reprocess") {
  message("Reprocessing first run: rebuilding review workbook and overwriting existing file if present.")
}

if (RUN_MODE %in% c("first", "reprocess")) {
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
  addStyle(wb, "For_Review", style = createStyle(textDecoration = "bold"),
           rows = 1, cols = 1:ncol(df), gridExpand = TRUE)

  # ----------------------------
# Conditional formatting: highlight Override_* if Proposed_* is blank
# ----------------------------
red_style <- createStyle(bgFill = "#FFC7CE")

for (oc in override_cols) {
  pc <- sub("^Override_", "Proposed_", oc)

  if (!(pc %in% names(df))) next

  col_override <- match(oc, names(df))
  col_proposed <- match(pc, names(df))

  if (is.na(col_override) || is.na(col_proposed)) next

  col_proposed_letter <- int2col(col_proposed)

  conditionalFormatting(
    wb,
    sheet = "For_Review",
    cols = col_override,
    rows = 2:(nrow(df) + 1),
    rule = paste0("$", col_proposed_letter, "2=\"\""),
    style = red_style,
    type = "expression"
  )
}

  addWorksheet(wb, "Excluded_by_BLAST")

  if (nrow(excluded_by_blast_df) == 0) {
    writeData(
      wb, "Excluded_by_BLAST",
      x = data.frame(
  Message = "ALL ASVs met BLAST thresholds. None were removed at this stage.",
  stringsAsFactors = FALSE
),
      colNames = FALSE
    )
    setColWidths(wb, "Excluded_by_BLAST", cols = 1, widths = 80)
    addStyle(
      wb, "Excluded_by_BLAST",
      style = createStyle(textDecoration = "bold", wrapText = TRUE, valign = "top"),
      rows = 1, cols = 1, gridExpand = TRUE
    )
  } else {
    writeData(wb, "Excluded_by_BLAST", excluded_by_blast_df, withFilter = TRUE)
    freezePane(wb, "Excluded_by_BLAST", firstRow = TRUE)
    setColWidths(wb, "Excluded_by_BLAST", cols = 1:ncol(excluded_by_blast_df), widths = "auto")
    addStyle(
      wb, "Excluded_by_BLAST",
      style = createStyle(textDecoration = "bold"),
      rows = 1, cols = 1:ncol(excluded_by_blast_df), gridExpand = TRUE
    )

    if ("Sequence" %in% names(excluded_by_blast_df) && nrow(excluded_by_blast_df) > 0) {
      wrapStyle <- createStyle(wrapText = TRUE, valign = "top")
      seq_col_idx <- match("Sequence", names(excluded_by_blast_df))
      addStyle(
        wb, "Excluded_by_BLAST", wrapStyle,
        rows = 2:(nrow(excluded_by_blast_df) + 1),
        cols = seq_col_idx, gridExpand = TRUE, stack = TRUE
      )
    }
  }

  saveWorkbook(wb, review_xlsx, overwrite = TRUE)

  message("Project: ", PROJECT_NAME)
  message("Review file created at:\n  ", review_xlsx)
  message("\nDownload locally:\n  scp ", user, "@", host, ":", review_xlsx, " .")
  message("\nEdit in Excel, then upload back:\n  scp ", basename(review_xlsx), " ", user, "@", host, ":", dirname(review_xlsx), "/")
  message("\nAfter re-uploading edited spreadsheet, run again in SECOND mode to continue.\n")

  quit(save = "no", status = 0)
}

if (RUN_MODE == "second") {
  if (!xlsx_exists) {
    stop(
      "Second-run mode selected but review workbook does not exist:\n  ",
      review_xlsx,
      call. = FALSE
    )
  }
  message("Running second-stage review processing.")
}
# ----------------------------
# Step 2: Read review Excel
# ----------------------------
rev <- read.xlsx(review_xlsx, sheet = "For_Review", detectDates = FALSE)

needed_base <- c("ASV", "Final_Taxon", "Approve", "Disapprove_Reason", "Remove_ASV")
missing_base <- setdiff(needed_base, names(rev))
if (length(missing_base) > 0) stop("Review XLSX missing columns: ", paste(missing_base, collapse = ", "), call. = FALSE)

missing_override <- setdiff(override_cols, names(rev))
if (length(missing_override) > 0) stop("Review XLSX missing override columns: ", paste(missing_override, collapse = ", "), call. = FALSE)

# Determine rows where overrides are required
approve_vals <- tolower(trimws(as.character(rev$Approve)))
disapproved <- approve_vals %in% c("n","no","disapprove","disapproved","false","f","0")

override_matrix <- rev[, override_cols, drop = FALSE]
override_matrix[] <- lapply(override_matrix, function(x) trimws(as.character(x)))

any_override <- apply(override_matrix, 1, function(r) any(nzchar(r)))

# Only enforce completeness if:
#  - NOT removed
#  - AND (approved OR has partial overrides)
active_rows <- !tolower(trimws(as.character(rev$Remove_ASV))) %in%
  c("y","yes","remove","removed","true","t","1")

rows_requiring_full_override <- active_rows & (!disapproved | any_override)

blank_mat <- is.na(override_matrix) | override_matrix == ""

if (any(blank_mat[rows_requiring_full_override, , drop = FALSE])) {
  bad <- which(rows_requiring_full_override)[
    rowSums(blank_mat[rows_requiring_full_override, , drop = FALSE]) > 0
  ]

  stop(
    "Some ASVs require complete Override_* values but have blanks.\n",
    "Fill all Override_* columns with a value or 'NA', or remove the ASV.\n",
    call. = FALSE
  )
}

# ----------------------------
# Safety check: stop if active rows have blank override cells
# ----------------------------
active_rows <- !tolower(trimws(as.character(rev$Remove_ASV))) %in%
  c("y", "yes", "remove", "removed", "true", "t", "1")

blank_override <- rev[active_rows, override_cols, drop = FALSE]
blank_override[] <- lapply(blank_override, function(x) trimws(as.character(x)))

blank_mat <- is.na(blank_override) | blank_override == ""

if (any(blank_mat)) {
  bad <- which(active_rows)[rowSums(blank_mat) > 0]

  examples <- paste0(
    "  ASV ", rev$ASV[bad],
    ": missing ",
    apply(blank_mat[rowSums(blank_mat) > 0, , drop = FALSE], 1, function(x) {
      paste(names(blank_override)[x], collapse = ", ")
    }),
    collapse = "\n"
  )

  stop(
    "Review workbook still has blank Override_* cells for ASVs not marked for removal.\n\n",
    "Please fill every Override_* cell with the correct taxon value or 'NA'.\n",
    "Rows marked Remove_ASV = yes are allowed to remain blank.\n\n",
    "Examples:\n",
    examples,
    "\n",
    call. = FALSE
  )
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
# Apply overrides from Excluded_by_BLAST for rescued ASVs
# ----------------------------
tmp_blast <- NULL
rescued_asvs <- character(0)

wb_loaded_for_rescue <- tryCatch(loadWorkbook(review_xlsx), error = function(e) NULL)
if (!is.null(wb_loaded_for_rescue) && "Excluded_by_BLAST" %in% names(wb_loaded_for_rescue)) {
  tmp_blast <- tryCatch(
    read.xlsx(review_xlsx, sheet = "Excluded_by_BLAST", detectDates = FALSE),
    error = function(e) NULL
  )
}

if (!is.null(tmp_blast) && "ASV" %in% names(tmp_blast) && "Include?" %in% names(tmp_blast)) {
  include_flag <- tolower(trimws(as.character(tmp_blast[["Include?"]])))
  rescued_asvs <- as.character(tmp_blast$ASV[include_flag %in% c("yes", "y", "true", "1")])
  rescued_asvs <- rescued_asvs[nzchar(rescued_asvs)]

  rescued_in_ps <- intersect(rescued_asvs, rownames(tax_mat))

  if (length(rescued_in_ps) > 0) {
    for (asv in rescued_in_ps) {
      row <- tmp_blast[tmp_blast$ASV == asv, , drop = FALSE]
      if (nrow(row) < 1) next
      row <- row[1, , drop = FALSE]

      # apply rank overrides
      for (lvl in tax_cols_rank) {
        oc <- paste0("Override_", lvl)
        if (!oc %in% names(row)) next
        val <- str_trim(ifelse(is.na(row[[oc]][[1]]), "", as.character(row[[oc]][[1]])))
        if (nzchar(val)) {
          tax_mat[asv, lvl] <- val
        }
      }

      # apply common-name override if present in tax table
      if ("Common" %in% colnames(tax_mat) && "Override_Common" %in% names(row)) {
        common_val <- str_trim(ifelse(is.na(row[["Override_Common"]][[1]]), "", as.character(row[["Override_Common"]][[1]])))
        if (nzchar(common_val)) {
          tax_mat[asv, "Common"] <- common_val
        }
      }

      # mark confidence as overridden if that column exists
      if (!is.na(CONF_COL) && CONF_COL %in% colnames(tax_mat)) {
        tax_mat[asv, CONF_COL] <- "overridden"
      }
    }
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

rescued_asvs <- character(0)
if (exists("tmp_blast") && !is.null(tmp_blast) && "Include?" %in% names(tmp_blast)) {
  include_flag <- tolower(trimws(as.character(tmp_blast[["Include?"]])))
  rescued_asvs <- as.character(tmp_blast$ASV[include_flag %in% c("yes", "y", "true", "1")])
  rescued_asvs <- rescued_asvs[nzchar(rescued_asvs)]
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
# Remove rescued ASVs from BLAST exclusion
blast_excluded_in_ps <- setdiff(blast_excluded_in_ps, rescued_asvs)

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

