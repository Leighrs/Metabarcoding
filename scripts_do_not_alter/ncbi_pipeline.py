#!/usr/bin/env python3
import os
import csv
from time import sleep
from multiprocessing import Pool, cpu_count

import pandas as pd
from Bio import Entrez, SeqIO

# ============================================================
# Global Entrez configuration (needed for multiprocessing)
# ============================================================
Entrez.email = "lrsanders@ucdavis.edu"
Entrez.api_key = "38300632ab9ee8d7af3a8b2e0f230bbb0d09"


def chunks(lst, n):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i+n]


def clean_lineage(l):
    if pd.isna(l):
        return []
    return [x.strip() for x in str(l).split(";") if x.strip()]


def fetch_rank(name):
    """Fetch NCBI rank for a given taxon name."""
    try:
        s = Entrez.esearch(db="taxonomy", term=name, retmode="xml")
        res = Entrez.read(s)
        if not res["IdList"]:
            return name, "not_found"

        taxid = res["IdList"][0]
        f = Entrez.efetch(db="taxonomy", id=taxid, retmode="xml")
        rec = Entrez.read(f)[0]
        sleep(0.7)  # be nice to NCBI
        return name, rec.get("Rank", "unknown")
    except Exception:
        return name, "lookup_error"


def main():
    # ============================================================
    # Pull environment variables passed from Bash
    # ============================================================
    PROJECT            = os.environ["PROJECT_NAME"]
    INPUT_FILE         = os.environ["INPUT_FILE"]
    FASTA_FILE         = os.environ["FASTA_FILE"]
    OUTPUT_FILE        = os.environ["OUTPUT_FILE"]
    MERGED_OUTPUT      = os.environ["MERGED_OUTPUT"]
    BEST_OUTPUT        = os.environ["BEST_OUTPUT"]
    LCTR_OUTPUT        = os.environ["LCTR_OUTPUT"]
    LCTR_RANK_OUTPUT   = os.environ["LCTR_RANK_OUTPUT"]
    RANK_CACHE_FILE    = os.environ["RANK_CACHE_FILE"]

    print(f"Project: {PROJECT}")
    print(f"Saving outputs to: {os.path.dirname(OUTPUT_FILE)}")

    # ============================================================
    # STEP 1 - Extract all TaxIDs from BLAST results
    # ============================================================
    print(f"Reading BLAST file: {INPUT_FILE}")
    taxids = set()
    with open(INPUT_FILE, "r") as f:
        for line in f:
            fields = line.strip().split("\t")
            if fields and fields[-1].isdigit():
                taxids.add(fields[-1])

    taxids = list(taxids)
    print("Found", len(taxids), "unique TaxIDs")

    # ============================================================
    # STEP 2 - Fetch taxonomy from NCBI
    # ============================================================
    taxonomy_data = []
    print("Fetching taxonomy from NCBI...")
    for batch in chunks(taxids, 50):
        ids_str = ",".join(batch)
        try:
            handle = Entrez.efetch(db="taxonomy", id=ids_str, retmode="xml")
            records = Entrez.read(handle)
            for r in records:
                taxonomy_data.append({
                    "TaxID": r.get("TaxId", ""),
                    "ScientificName": r.get("ScientificName", ""),
                    "Rank": r.get("Rank", ""),
                    "Lineage": r.get("Lineage", "")
                })
            sleep(0.4)  # rate limiting
        except Exception as e:
            print("Warning fetching:", ids_str, "error:", e)

    with open(OUTPUT_FILE, "w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["TaxID", "ScientificName", "Rank", "Lineage"],
            delimiter="\t"
        )
        writer.writeheader()
        writer.writerows(taxonomy_data)

    print("Saved taxonomy info ->", OUTPUT_FILE)

    # ============================================================
    # STEP 3 - Merge BLAST + taxonomy
    # ============================================================
    print("Merging BLAST results with taxonomy...")
    blast_cols = [
        "qseqid","qcovs","sseqid","pident","length","qlen","slen",
        "mismatch","gapopen","qstart","qend","sstart","send",
        "evalue","bitscore",
        "stitle","sscinames","sblastnames","scomnames","TaxID"
    ]

    blast_df = pd.read_csv(INPUT_FILE, sep="\t", header=None, names=blast_cols)
    taxonomy_df = pd.read_csv(OUTPUT_FILE, sep="\t")

    blast_df["TaxID"] = blast_df["TaxID"].astype(str)
    taxonomy_df["TaxID"] = taxonomy_df["TaxID"].astype(str)

    merged_df = pd.merge(blast_df, taxonomy_df, on="TaxID", how="left")
    merged_df.to_csv(MERGED_OUTPUT, sep="\t", index=False)
    print("Saved merged file ->", MERGED_OUTPUT)

    # ============================================================
    # STEP 4 - Add ASV sequences
    # ============================================================
    print(f"Reading ASV FASTA: {FASTA_FILE}")
    seq_dict = SeqIO.to_dict(SeqIO.parse(FASTA_FILE, "fasta"))
    seq_lookup = {k: str(v.seq) for k, v in seq_dict.items()}
    merged_df["ASV_sequence"] = merged_df["qseqid"].map(seq_lookup)

    # ============================================================
    # STEP 5 - Filter BLAST hits with qcovs = 100
    # ============================================================
    print("Filtering BLAST hits to qcovs == 100...")
    merged_df = merged_df[merged_df["qcovs"] == 100]

    # ============================================================
    # STEP 6 - Best hits per ASV
    # ============================================================
    print("Selecting best hit per ASV...")
    sorted_df = merged_df.sort_values(
        by=["qseqid","pident","bitscore","evalue"],
        ascending=[True, False, False, True]
    )

    best_hits = sorted_df.drop_duplicates("qseqid", keep="first")
    best_hits.to_csv(BEST_OUTPUT, sep="\t", index=False)
    print("Saved best hits ->", BEST_OUTPUT)

    # ============================================================
    # STEP 7 - LCTR determination
    # ============================================================
    print("Determining LCTR (lowest common taxonomic rank)...")
    final_rows = []

    for asv, group in merged_df.groupby("qseqid"):
        max_pid = group["pident"].max()
        tied = group[group["pident"] == max_pid]

        max_bits = tied["bitscore"].max()
        tied = tied[tied["bitscore"] == max_bits]

        min_eval = tied["evalue"].min()
        tied = tied[tied["evalue"] == min_eval]

        # unanimous species case
        species_names = tied["sscinames"].unique()
        ranks = tied["Rank"].unique()

        if len(species_names) == 1 and len(ranks) == 1 and ranks[0] == "species":
            final_taxon = species_names[0]
            explanation = f"All {len(tied)} tied hits agree on species {final_taxon}."
        else:
            lineages = [clean_lineage(l) for l in tied["Lineage"]]
            common = lineages[0]
            for lin in lineages[1:]:
                common = [a for a, b in zip(common, lin) if a == b]

            if not common:
                final_taxon = "unresolved"
                conflicts = "; ".join(tied["sscinames"].unique())
                explanation = (
                    f"Lineages conflict above family level. "
                    f"Conflicting taxa: {conflicts}"
                )
            else:
                final_taxon = common[-1]
                unique_species = tied["sscinames"].unique()
                if len(unique_species) > 1:
                    conflicts = "; ".join(unique_species)
                    explanation = (
                        f"{len(tied)} tied hits. "
                        f"Lowest shared taxon: {final_taxon}. "
                        f"Conflicts among: {conflicts}"
                    )
                else:
                    explanation = (
                        f"{len(tied)} tied hits. "
                        f"Lowest shared taxon: {final_taxon}."
                    )

        final_rows.append({
            "ASV": asv,
            "ASV_sequence": seq_lookup.get(asv, ""),
            "Final_Taxon": final_taxon,
            "Explanation": explanation
        })

    lctr_df = pd.DataFrame(final_rows)
    lctr_df.to_csv(LCTR_OUTPUT, sep="\t", index=False)
    print("Saved LCTR ->", LCTR_OUTPUT)

    # ============================================================
    # STEP 8 - NCBI Rank lookup (cached + multiprocessing)
    # ============================================================
    print("Looking up NCBI ranks (with cache + multiprocessing)...")

    rank_cache = {}
    # load existing cache
    if os.path.exists(RANK_CACHE_FILE):
        try:
            df_cache = pd.read_csv(RANK_CACHE_FILE, sep="\t")
            rank_cache = dict(zip(df_cache["Taxon"], df_cache["Rank"]))
            print(
                f"Loaded rank cache from {RANK_CACHE_FILE} "
                f"({len(rank_cache)} entries)."
            )
        except Exception as e:
            print("Warning: could not load rank cache:", e)

    unique_taxa = sorted(set(lctr_df["Final_Taxon"]) - {"unresolved"})
    to_lookup = [t for t in unique_taxa if t not in rank_cache]

    if to_lookup:
        print(f"Need to look up {len(to_lookup)} taxa...")
        nproc = min(2, cpu_count())
        print(f"Using {nproc} processes for Entrez rank lookup.")
        with Pool(nproc) as pool:
            for name, rank in pool.map(fetch_rank, to_lookup):
                rank_cache[name] = rank
    else:
        print("No new taxa to look up; using cached ranks only.")

    # save updated cache
    pd.DataFrame(
        [{"Taxon": t, "Rank": r} for t, r in sorted(rank_cache.items())]
    ).to_csv(RANK_CACHE_FILE, sep="\t", index=False)
    print("Saved updated rank cache ->", RANK_CACHE_FILE)

    # map ranks back to LCTR table
    def map_rank(x):
        if x == "unresolved":
            return "unresolved"
        return rank_cache.get(x, "not_found")

    lctr_df["Final_Taxon_Rank"] = lctr_df["Final_Taxon"].map(map_rank)

    # reorder columns
    lctr_df = lctr_df[[
        "ASV", "ASV_sequence", "Final_Taxon", "Final_Taxon_Rank", "Explanation"
    ]]

    lctr_df.to_csv(LCTR_RANK_OUTPUT, sep="\t", index=False)
    print("Saved final ranked LCTR ->", LCTR_RANK_OUTPUT)


if __name__ == "__main__":
    main()
