# This script imports a csv file outputted from taxa-bar-plots.qzv and cleans up the taxa names for use with LEFse (http://huttenhower.org/galaxy/)
# It should have the following inputs:
#     1. path_to_csv = args[1]
#     2. group_to_compare = args[2]
#     3. pre_save_path = args[3] (should be specified as the output path in waterway, ending with a slash)
#     4. nameOfFile = args[4]
#     5. dbtype = args[5] (GreenGenes or SILVA, specified in config.txt)
# It should do the following:
#     1. Replace all semicolons with pipes ( ; --> | ) in colnames that have k__ in them
#     2. Remove all taxa level underscores (e.g. k__ , o__ , g__ , etc.)
#     3. Replace the column "index" with "sample_id"
#     4. Move the column with the group specified in args[2] to the first column
#     5. Remove all unused metadata columns
# It should output the following:
#     1. A .tsv file containing the table as modified above
# The following non-successful exit codes are present:
#     2 -- group_to_compare was not found within the column names (first row in origTable) in the csv file.

# Known problem: too many pipes are inserted, not just for the taxalabels

# Load libraries
suppressMessages(library(tidyverse))

# Turn off warnings for this script
oldw <- getOption("warn")
options(warn = -1)

# Assign vars
args <- commandArgs(trailingOnly = TRUE)
path_to_csv <- args[1]
group_to_compare <- args[2]
pre_save_path <- args[3]
nameOfFile <- args[4]
dbtype <- args[5]

# I don't know why, but read.csv turns all semicolons into periods if you put them in the colnames, so I put them as the first row. [1,]
# It's not documented anywhere. Why, R, why would you do this???
origTable <- read.csv(path_to_csv, quote = "", header = FALSE)

# Check that the group_to_compare exists in the first row. If not, error out
if (! (group_to_compare %in% origTable[1,])) {
    message("The group ", group_to_compare, " was not found in the metadata file as a column name.")
    message("Please check that the name specified as group_to_compare in optional_analyses.txt")
    message("is exactly the same as the metadata column that you'd like to compare. This is caps sensitive.")
    quit(save = "no", status = 2) # Quit with an exit code of 2
}

# Objective 1/2/3 completed here
if (dbtype == 'GreenGenes') {
    taxalabels <- c("k__", "p__", "c__", "o__", "f__", "g__", "s__")
    starting <- "k__"
    } else if (dbtype == 'SILVA') {
    taxalabels <- c("D_0__", "D_1__", "D_2__", "D_3__", "D_4__", "D_5__", "D_6__")
    starting <- "D_0__"
}

i = 1
filledRemovedColFlag <- FALSE
for (value in origTable[1,]) {
    if (grepl(starting, value, fixed = TRUE) && grepl(";", value, fixed = TRUE)) { # Check if value includes a k__ and a semicolon, which all taxa have
        newvalue <- gsub(";__", "|", value, fixed = TRUE)
        newvalue <- gsub(";", "|", newvalue, fixed = TRUE) # Replace all semicolons with pipes
        newvalue <- gsub("[", "", newvalue, fixed = TRUE) # Remove all brackets
        newvalue <- gsub("]", "", newvalue, fixed = TRUE) # Brackets are for non-formalized specie/genus names, but we don't care
        newvalue <- gsub("(", "", newvalue, fixed = TRUE) # Remove those rounded brackets too
        newvalue <- gsub(")", "", newvalue, fixed = TRUE)
        newvalue <- gsub(".", "", newvalue, fixed = TRUE) # No periods!
        
        for (prefix in taxalabels){       # Replace the first match of each element in taxalabels with nothing
            newvalue <- sub(prefix, "", newvalue, fixed = TRUE)
        }

        newvalue <- gsub("\\|{2,20}", "|", newvalue) # Replace all multiple pipes with one pipe
        origTable[1,i] <- newvalue

    } else if (grepl("index", value, fixed = TRUE)) {
        origTable[1,i] <- "sample_id"

    } else {
        if (!filledRemovedColFlag){
            columns_to_remove <- i - 1 # Currently gives the last column num that has taxa read numbers
            filledRemovedColFlag <- TRUE
        }
    }
    i <- i + 1
}

# Helper function for objective 4
header.true <- function(df) {
names(df) <- as.character(unlist(df[1,]))
df[-1,]
}

# Objective 4 completed here
#aggr <- as.data.frame(do.call(cbind, by(t(origTable),INDICES=names(origTable),FUN=colSums))) # TODO: THIS DOESNT WORK. Merge identically named columns
# Set subTable as all columns that have taxa read info, aka origTable[,2:columns_to_remove], then delete those cols from origTable
subTable <- origTable[,2:columns_to_remove]
origTable <- origTable[-c(2:columns_to_remove)]
origTable <- header.true(origTable) # Move row 1 to the colnames
subTable <- header.true(subTable) # Move row 1 to the colnames
subTable <- as.data.frame(sapply(subTable, as.numeric)) # Turn all cols into numeric type, so we can add together
aggr <- as.data.frame(lapply(split.default(subTable, names(subTable)), function(x) Reduce(`+`, x))) # Sum the duplicate rows together, FINALLY jfc
i = 1 # Fix the periods that are introduced into the colnames (why the hell would they do this)
for (title in colnames(aggr)) {
    newvalue <- gsub(".", "|", title, fixed = TRUE)
    colnames(aggr)[i] <- newvalue
    i <- i + 1
}

newTable <- cbind(aggr, origTable)
newTable <- newTable %>%
    select(which(colnames(newTable)=="sample_id"), all_of(everything())) # Do the moving of "sample_id" to column 1
newTable <- newTable %>%
    select(which(colnames(newTable)==group_to_compare), all_of(everything())) # Do the moving of group_to_compare to column 1

i = 1
filledRemovedColFlag <- FALSE

# Find the new columns_to_remove here
for (value in colnames(newTable)) {
    if (grepl("|", value, fixed = TRUE)) {
    } else if (grepl("sample_id", value, fixed = TRUE) || (grepl(group_to_compare, value, fixed = TRUE))) {
    } else {
        if (!filledRemovedColFlag){
            columns_to_remove <- i # Currently gives the first metadata colnum
            filledRemovedColFlag <- TRUE
        }
    }
    i <- i + 1
}

# Objective 5 completed here
finalTable <- newTable %>% 
    select(-c(all_of(columns_to_remove):ncol(newTable)))

# Save the file
save_path <- paste0(pre_save_path, nameOfFile, "_", group_to_compare, "_LEFse_table.txt")
write.table(finalTable, file = save_path, row.names = FALSE, col.names = TRUE, sep = "\t", na = "", quote = FALSE)

# Turn warnings back on
options(warn = oldw)