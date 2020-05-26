#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(data.table))
library('tidyverse')
library('data.table')

# Call and store the args:
#   [1] = metadata_filepath
#   [2] = qzaoutput2
#   [3] = missing_samples (what denotes a missing sample)

args <- commandArgs(trailingOnly = TRUE)
NAval <- args[3]

# Read the metadata file that's specified 
original_metadata <- fread(file = args[1])

# Filter the table by removing rows containing args[3] for group in colname_vector
for (group in colnames(original_metadata))
{
  savelocation <- paste(args[2],
                        "rerun_beta_continuous/filtered_metadata/",
                        group,
                        "-filtered.tsv",
                        sep = "")
  new_metadata <- original_metadata[original_metadata[[group]] != NAval , ]
  write.table(new_metadata, 
              file = savelocation, 
              quote=FALSE, 
              sep='\t', 
              col.names = TRUE,
              row.names = FALSE)
}

# Save to ${qzaoutput2}rerun_beta_continuous/filtered_metadata as ${group}-filtered.tsv

# Original, old code for testing
# original_metadata <- fread(file = '/home/michael/Projects/Francine_Marques/vicgut-qiime2/metadata/metadataNA.tsv')
# test="PlasmaAcetate"
# missing='NA'
# YES!!!! new_metadata <- original_metadata[original_metadata[[test]] != missing , ]
# new_metadata <- original_metadata[ , grep(missing, test)]
# new_metadata <- subset(original_metadata, test!="NA")
# head(new_metadata)