suppressPackageStartupMessages(library(tidyverse))
library(tidyverse)

# This script imports a csv file outputted from taxa-bar-plots.qzv and cleans up the taxa names for use with LEFse (http://huttenhower.org/galaxy/)
# It should have the following inputs:
#     1. path_to_csv = args[1]
#     2. group_to_compare = args[2]
# It should do the following:
#     1. Replace all semicolons with pipes ( ; --> | )
#     2. Remove all taxa level underscores (e.g. k__ , o__ , g__ , etc.)
#     3. Replace the column "index" with "sample_id"
#     4. Insert an empty column titled "group_to_compare" before the first column
#     5. Replace the "group_to_compare" column with the group specified in args[2]
# It should output the following:
#     1. A .tsv file containing the table as modified above

args <- commandArgs(trailingOnly = TRUE)
path_to_csv <- args[1]
group_to_compare <- args[2]

origTable <- read.csv(path_to_csv)