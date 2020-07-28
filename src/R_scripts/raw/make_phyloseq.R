#!/usr/bin/env Rscript

suppressPackageStartupMessages(library('phyloseq'))
suppressPackageStartupMessages(library('qiime2R'))
library('phyloseq')
library('qiime2R')

# This function uses qiime2R to make a phyloseq object, then saves it as an .RData file for other scripts to use.
# INPUTS ------------
# 1. finalOutputPath   <-- The path to the folder that the .RData should be stored in (including a final slash)
# 2. dTablePath        <-- The path to table.qza that the phyloseq object should contain
# 3. dRootedTree       <-- The path to rooted-tree.qza that the phyloseq object should contain
# 4. dMetadataPath     <-- The path to the tab-delimited metadata file that the phyloseq object should contain
# 5. dTaxPath          <-- The path to taxonomy.qza that the phyloseq object should contain

# Assign the args (list starts from 1)
args <- commandArgs(trailingOnly = TRUE)
finalOutputPath <- args[1]
dTablePath <- args[2]
dRootedTree <- args[3]
dMetadataPath <- args[4]
dTaxPath <- args[5]

# Make the phyloseq object
phyloseq_object <- qza_to_phyloseq(features = dTablePath, tree = dRootedTree, metadata = dMetadataPath, taxonomy = dTaxPath)

# Save the phyloseq object as phyloseq_object.RData
savepath <- paste(finalOutputPath, "phyloseq_object.RData", sep = "")
save(phyloseq_object, file = savepath)