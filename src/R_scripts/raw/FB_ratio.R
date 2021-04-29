#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(phyloseq))
suppressPackageStartupMessages(library(data.table))
library('tidyverse')
library('phyloseq')

# This function imports a phyloseq object and calculates the F:B ratio for all samples, then adds it to a new metadata column
# INPUTS ------------
# 1. finalOutputPath   <-- The path to the folder that the all outputs should be stored in (including a final slash)
# 2. rdataPath         <-- The path to phyloseq_object.RData
# 3. rawMetadataCols      <-- a comma-separated string of categorical metadata columns to compare F:B ratios between

# Helper empty function for TODO sections
pass <- function(asdf){
    invisible()
}

# Assign the args (list starts from 1)
args <- commandArgs(trailingOnly = TRUE)
finalOutputPath <- args[1]
rdataPath <- args[2]
rawMetadataCols <- args[3]


### CALCULATING F:B RATIOS AND CREATING AN AGGLOMERATED MATRIX ---------------------

# Load the RData containing phyloseq_object
load(rdataPath)

# Glom the phyloseq to a phylum level
phyloseq_object_phylum <- tax_glom(phyloseq_object, taxrank = rank_names(phyloseq_object)[2])

# Extract the OTU table and taxonomy table as matrix objects
mTaxTab <- as(tax_table(phyloseq_object_phylum), "matrix")
mOTUTab <- as(otu_table(phyloseq_object_phylum), "matrix")

# Merge the two tables, so each row corresponds to one phylum
mergedTables <- merge(mTaxTab, mOTUTab, by=0, all=TRUE)

# Rename the first column to SampleHash
colnames(mergedTables)[1] <- "SampleHash"

# Make a filtered table of the above, removing the columns all non-needed taxonomic ranks
filteredMergedTable <- subset(mergedTables, select = -c(Class,Order,Family,Genus,Species))

# Find row number containing "Firmicutes" and "Bacteroidetes" in the Phylum column, and the col number of the Phylum column
firmicutesRow <- which(grepl("Firmicutes", filteredMergedTable$Phylum))
bacteroidetesRow <- which(grepl("Bacteroidetes", filteredMergedTable$Phylum))
phylumCol <- which(colnames(filteredMergedTable) == "Phylum")

# Pre-allocate a vector of the same length as filteredMergedTable (MUCH faster than appending to vector after every calculation)
fbratios <- vector(mode = "numeric", length = ncol(filteredMergedTable))

# Loop over all columns, with the main code block starting execution at phylumCol + 1
reachedPhyCol = FALSE
for (columnName in colnames(filteredMergedTable)) {
    
    # This executes starting on the column after "Phylum"
    if (reachedPhyCol) {

        # Figure out what colnum we're on
        currentColNum <- which(colnames(filteredMergedTable) == columnName)

        # Retrieve the firmicutes and bacteroidetes numbers
        fNum <- filteredMergedTable[firmicutesRow, currentColNum]
        bNum <- filteredMergedTable[bacteroidetesRow, currentColNum]

        # Calculate the ratio and modify the fbratios vector at the currentColNum position with the ratio
        fbratios[currentColNum] <- fNum/bNum
    }

    if (columnName == "Phylum") {
        reachedPhyCol=TRUE
    }
}

# Add the fbratios vector at the bottom of filteredMergedTable, and set the SampleHash of the row to "F:B Ratio"
newfbratios <- as(t(fbratios), "matrix")
colnames(newfbratios) <- colnames(filteredMergedTable)
finalTable <- rbind(filteredMergedTable, fbratios)
finalTable[nrow(finalTable), 1] <- "F:B Ratio"


### FIND SAMPLES PER METADATA COL AND STORE THEM ---------------------

# Convert and store the metadata as a matrix
metaMatrix <- as(sample_data(phyloseq_object_phylum), "matrix")

# Make the comma separated string rawMetadataCols into a vector where each element is a metadata col
metadataCols <- unlist(strsplit(rawMetadataCols, ","))

# Create a blank list with n elements to store the group lists in, where n = length(metadataCols)
bigMetaGroups <- vector("list", length = length(metadataCols))

# Initialize a blank list to store fbvectors
fbVectorList <- list()

# Loop through metadataCols
for (metaColName in metadataCols) {

    # To keep track of the index we're doing
    x = 1

    # Get the unique values in metaMatrix[, metaColName] as a vector with SampleID as colnames
    uniquevals <- unique(metaMatrix[, metaColName])

    # Initialize a vector of size n, where n = ncols(finalTable)
    avgFBvector <- vector(mode = "numeric", length = ncols(uniquevals))

    # Loop over each val in uniquevals
    for (val in uniquevals) {

        # First make a vector containing their sampleIDs called namesmatrix
        filtermatrix <- metaMatrix[, metaColName] == val
        origmatrix <- metaMatrix[, metaColName]
        finalmatrix <- origmatrix[filtermatrix]
        namesmatrix <- names(finalmatrix)

        i = 1
        # Loop over sampleIDs in namesmatrix
        for (sample in namesmatrix) {
            
            # Initialize an empty vector with a size of length(namesmatrix)
            fbvector <- vector(mode = "numeric", length = length(namesmatrix))

            # Find the column with the sample ID, then find the F:B ratio associated with it and add it to fbvector at position i
            fbvector[i] <- finalTable[nrow(finalTable), sample]

            # Increment i
            i = i + 1

        }

        # Calculate average F:B in the metadata group and add the average to avgFBvector at position x, then increment x
        avgFBvector[x] <- mean(fbvector)
        x = x + 1

        # Add the finished fbvector into fbVectorList using metaColName_val as an identifier/position name
        storename <- paste(metaColName, "_", val, sep = "")
        fbVectorList[[storename]] <- fbvector

    }

    # Label avgFBvector using uniquevals as the label vector
    names(avgFBvector) <- uniquevals

    # Store the labelled avgFBvector in bigMetaGroups using metaColName as an identifier/position name
    bigMetaGroups[[metaColName]] <- avgFBvector

}

### RUN STATISTICAL TESTS ON F:B RATIOS ---------------------

# Initialize an empty list for later
resultList <- list()

for (metaColName in metadataCols) {

    # Make uniquevals available to use
    uniquevals <- unique(metaMatrix[, metaColName])

    # Run t-test between values IF length of bigMetaGroups[[metaColName]] is equal to 2
    if (length(bigMetaGroups[[metaColName]]) == 2) {
        
        # Initialize a temporary list to add each vector to
        templist <- list()
        x = 1

        for (val in uniquevals){

            # Retrieve the fbvectors for the two groups from fbVectorList
            storename <- paste(metaColName, "_", val, sep = "")
            templist[[x]] <- fbVectorList[[storename]]
            x = x + 1
        }

        # Do the t-test, and record which val is x and y
        tTestResult <- t.test(templist[[1]], templist[[2]], var.equal = FALSE)
        tTestResult$x <- uniquevals[1]
        tTestResult$y <- uniquevals[2]
        
        # Store the t-test in resultList
        resultList[[metaColName]] <- tTestResult

    }

    #-- TODO
    # Run ANOVA between values IF length of bigMetaGroups[[metaColName]] is greater than 2
    if (length(bigMetaGroups[[metaColName]]) > 2) {
        pass()
    }

}

### VISUALIZE: F:B RATIO DIFFERENCES