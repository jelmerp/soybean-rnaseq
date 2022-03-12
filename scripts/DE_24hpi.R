#!/usr/bin/env Rscript

#SBATCH --account=PAS0471
#SBATCH --output=slurm_DE-24hpi_%j.out

## Report
message("## Starting script DE_24hpi.R")
Sys.time()
message()

# SET UP------------------------------------------------------------------------
## Load packages
dir.create(path = Sys.getenv("R_LIBS_USER"), showWarnings = FALSE, recursive = TRUE)
if(! "pacman" %in% installed.packages()) {
  install.packages("pacman",
                   lib = Sys.getenv("R_LIBS_USER"),
                   repos = "https://cran.rstudio.com/")
}
packages <- c("DESeq2",          # Differential expression analysis
              "tidyverse",       # Misc. data manipulation and plotting
              "argparse")        # Managing file paths
pacman::p_load(char = packages)

## Parse command-line args
parser <- ArgumentParser()

parser$add_argument("-c", "--counts",
                    type = "character", default = NULL,
                    help = "Count matrix from featureCounts (REQUIRED)")
parser$add_argument("-m", "--meta",
                    type = "character", default = NULL,
                    help = "Metadata CSV file (REQUIRED)")
parser$add_argument("-o", "--outdir",
                    type = "character", default = "results/DE",
                    help = "Output directory (default: 'results/DE'")

args <- parser$parse_args()

## Assign input and output files from command-line args
counts_file <- args$counts    # counts_file <- "results/featurecounts/counts.txt"
metadata_file <- args$meta    # metadata_file <- "metadata/metadata.csv"
outdir <- args$outdir         # outdir <- "results/DE"

## Check input
stopifnot(!is.null(counts_file))
stopifnot(!is.null(metadata_file))

## Report
message("## Counts file:       ", counts_file)
message("## Metadata file:     ", metadata_file)
message("## Output dir:        ", outdir)
message()

## Create output dir if needed
if (!dir.exists(outdir)) dir.create(outdir)

## Settings
BAMFILE_REGEX <- "results.star.(.+)_S.+"

## Define contrasts
line_contrast_list <- list(
  c("Line", "Conrad", "M92220"),
  c("Line", "Conrad", "Sloan"),
  c("Line", "Conrad", "Williams"),
  c("Line", "M92220", "Sloan"),
  c("Line", "M92220", "Williams")
)
group_contrast_list <- list(
  c("group", "Conrad_mock", "Conrad_inoculated"),
  c("group", "M92220_mock", "M92220_inoculated"),
  c("group", "Sloan_mock", "Sloan_inoculated"),
  c("group", "Williams_mock", "Williams_inoculated")
)


# CREATE DESEQ OBJECT ----------------------------------------------------------
## Load input data
count_df_raw <- read.table(counts_file,
                           sep = "\t", header = TRUE, skip = 1)
meta_df <- read.csv(metadata_file, header = TRUE)

## Extracting sample IDs from the column names
colnames(count_df_raw) <- sub(BAMFILE_REGEX, "\\1", colnames(count_df_raw))

## Remove metadata columns and store Gene IDs a rownames
count_df <- count_df_raw[, 7:ncol(count_df_raw)]
rownames(count_df) <- count_df_raw$Geneid

## Report
message("## Nr of genes in count matrix:      ", nrow(count_df_raw))
message("## Nr of samples in count matrix:    ", ncol(count_df_raw))
message("## Nr of samples in metadata file:   ", nrow(meta_df))
message()

## Make sure the metadata rows and count columns are sorted alphabetically by Sample ID
meta_df <- meta_df[order(meta_df$Sample.ID), ]
count_df <- count_df[, order(colnames(count_df))]

## Change treatments into factors
meta_df <- meta_df %>%
  mutate(Trial = as.factor(Trial),
         Line = as.factor(Line),
         Time = as.factor(Time),
         Treatment = as.factor(Treatment))

## Create DeSeq2 object
dds_raw <- DESeqDataSetFromMatrix(countData = count_df,
                                  colData = meta_df,
                                  design = ~ 1)

## Subset to timepoint 24
dds <- subset(dds_raw, select = colData(dds_raw)$Time == 24)


# FUNCTIONS --------------------------------------------------------------------
get_contrast <- function(contrast_vec, dds, model_string = "") {
  res <- results(dds, contrast = contrast_vec) %>%
    as.data.frame() %>%
    rownames_to_column("geneID") %>%
    mutate(factor = contrast_vec[1],
           level1 = contrast_vec[2],
           level2 = contrast_vec[3])
  
  nsig <- sum(res$padj < 0.05, na.rm = TRUE)
  message("## ", contrast_vec[2], " vs ", contrast_vec[3], ": ", nsig, " significant")
  
  cvec_string <- paste0(contrast_vec , collapse = "_")
  outfile <- file.path(outdir, paste0(model_string, "_", cvec_string, "_DE.txt"))
  write_tsv(res, outfile)
}


# BY INOCULATION STATUS --------------------------------------------------------
message("\n## Running analysis by inoculation status...")
## Merging factors Line & treatment into a single factor called group, and fit a univariate model with this factor
## Compare two pairwise contrast
dds_focal <- dds
dds_focal$group <- factor(paste(dds_focal$Line, dds_focal$Treatment, sep = "_"))
design(dds_focal) <- formula(~ group)
dds_focal <- DESeq(dds_focal)
walk(group_contrast_list, get_contrast,
     dds_focal, model_string = "inoc")


# BY LINE - NO MOCKS -----------------------------------------------------------
message("\n## Running analysis by line w/ only inoculation treatment...")
dds_focal <- subset(dds, select = colData(dds)$Treatment != "mock")
design(dds_focal) <- formula(~ Trial + Line)
dds_focal <- DESeq(dds_focal)
walk(line_contrast_list, get_contrast,
     dds_focal, model_string = "treatment-only")


# BY LINE - ONLY MOCKS ---------------------------------------------------------
message("\n## Running analysis by line w/ only mocks...")
dds_focal <- subset(dds, select = colData(dds)$Treatment == "mock")
design(dds_focal) <- formula(~ Trial + Line)
dds_focal <- DESeq(dds_focal)
walk(line_contrast_list, get_contrast,
     dds_focal, model_string = "mock-only")


# BY LINE WITH BOTH TREATMENTS -------------------------------------------------
message("\n## Running analysis by line w/ both treatments - additive...")
dds_focal <- dds
design(dds_focal) <- formula(~ Trial + Treatment + Line)
dds_focal <- DESeq(dds_focal)
walk(line_contrast_list, get_contrast,
     dds_focal, model_string = "fullmodel-additive")


# BY LINE - BOTH TREATMENTS W/ INTERACTION -------------------------------------
message("\n## Running analysis by line w/ both treatments - w/ interaction...")
dds_focal <- dds
design(dds_focal) <- formula(~ Trial + Treatment * Line)
dds_focal <- DESeq(dds_focal)
walk(line_contrast_list, get_contrast,
     dds_focal, model_string = "fullmodel-interaction")

## Interactions
# my_contrast <- "Treatmentmock.LineWilliams"
# res <- results(dds, name = my_contrast)
# sum(res$padj < 0.05, na.rm = TRUE) # 7
# # res %>% data.frame() %>% filter(padj < 0.05) %>% count(log2FoldChange > 0)

## Report
message("\n## Listing output files:")
system(paste("ls -lh", outdir))
message()
message("## Done with script DE_24hpi.R")
Sys.time()
message()