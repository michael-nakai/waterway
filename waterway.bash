#!/bin/bash
#SBATCH --job-name=waterway
#SBATCH --account=
#SBATCH --time=168:00:00
#SBATCH --partition=
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --cpus-per-task=8
#SBATCH --qos=normal

# Created by Michael Nakai, 22/01/2019 for command line Bash or use with the SLURM job management software on M3.
# If you are running waterway on SLURM, change the account and partition to yours respectively.

# Some SLURM setups require these lines, otherwise should be harmless
export LC_ALL="en_US.utf-8"
export LANG="en_US.utf-8"

# Setting color variables for echos (need -e, remember to NC after a color)
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BMAGENTA='\033[1;35m'
NC='\033[0m'

LBLUE='\033[1;36m' # Only used for -n
LGREEN='\033[1;32m' # Only used for -n
LGREY='\033[0;37m' # Only used for -n

# Check that a Qiime2 environment is active
if ! type "qiime" > /dev/null 2>&1; then
	echo -e "" >&2
	echo -e "A Qiime2 environment isnt activated yet." >&2
	echo -e "Please activate an environment first and make Qiime2 commands" >&2
	echo -e "available to use. If installed using conda, use the command" >&2
	echo -e "${CYAN}conda info --envs${NC} to find all installed environments, then" >&2
	echo -e "activate one using ${CYAN}conda activate ______${NC} (env name in the underlined part)" >&2
	echo -e "" >&2
	exit 1
fi

# Version number here
version="3.2.1"

# Finding Qiime2 version number
q2versionnum=$(qiime --version)
q2versionnum=${q2versionnum:14:9} 
q2versionnum=${q2versionnum%.*} # it'll say something like "2019.10" or "2020.2"

# Setting very basic arguments (srcpath is located here)
exitnow=false

scriptdir=`dirname "$0"`
rscript_path="${scriptdir}/src/R_scripts/raw/metadata_filter.R" # Legacy, haven't had time to clean up yet. Should make filter-metadata.bash
	
	
if [ -z "$1" ]; then
	# see if argument exists to waterway, then use that dir and find configs
	# if argument doesnt exist, use current working dir
	srcpath="./config.txt"
	analysis_path="./optional_analyses.txt"
	rename_path="./patterns_to_rename.txt"
else
	# see if last char in $1 is '/', and if it is, trim it
	str=$1
	i=$((${#str}-1)) 2> /dev/null
	j=${str:$i:1} 2> /dev/null
	if [ $j == '/' ]; then
		str=${str%?}
	fi
	srcpath="${str}/config.txt"
	analysis_path="${str}/optional_analyses.txt"
	rename_path="${str}/patterns_to_rename.txt"
fi

# Useful helper functions here
# Use with two arguments (str to dirname to be surveyed, str of name that should be returned), with one optional third argument (file extension)
function return_unused_filename {
	if [ $# -eq 3 ]; then
		if [[ -e "${1}/$2.$3" ]] ; then
			__temphere=$(echo `ls ${1}/{2}*.${3} | wc -l`)
			unused_name="${1}/${2}${__temphere}.${3}"
			touch $unused_name
			echo $unused_name
		fi
	elif [ $# -eq 2 ]; then
		if [[ -d "${1}/$2" ]] ; then
			__temphere=$(echo `ls ${1}/{2}*.${3} | wc -l`)
			unused_name="${1}/$2${__temphere}"
			mkdir $unused_name
			echo $unused_name
		fi
	else
		:
	fi
}

# A group of sed commands to strip the color codes from the log file. First argument should be log filename with extension
function replace_colorcodes_log {
	sed -i -r 's+\[0;31m++g' $1
	sed -i -r 's+\[0;32m++g' $1
	sed -i -r 's+\[0;36m++g' $1
	sed -i -r 's+\[1;33m++g' $1
	sed -i -r 's+\[1;35m++g' $1
	sed -i -r 's+\[0m++g' $1
}

# Echos message, then writes to log if -l was specified
function echolog {
	echo -e $1
	if [[ $log = true ]]; then
		echo -e $1 >&3
	fi
}

# Only echos message if log is true, writing it to the log, not stdout
function logger {
	if [[ $log = true ]]; then
		echo -e $1
	fi
}

# Only echos message if verbose is true. If log is true, writes to log and stdout
function talkative {
	if [[ $verbose = true ]]; then
		echo -e $1
	fi
	if [[ $log = true && $verbose = true ]]; then
		echo -e $1 >&3
	fi
}

# Echos to stderr normally, otherwise to log/output
function errorlog {
	echo -e $1 >&2
	if [[ $log = true ]]; then
		echo -e $1 >&3
	fi
}

# Export all functions to be used in child scripts
export -f return_unused_filename
export -f replace_colorcodes_log
export -f echolog
export -f logger
export -f talkative
export -f errorlog

#---------------------------------------------------------------------------------------------------
#-----------------------------------------Main Function Start---------------------------------------
#---------------------------------------------------------------------------------------------------

# Get the conda commands (because they're not exported by default for some reason, which is dumb)
condapath=$(conda info | grep -i 'base environment')
condapath=${condapath//"base environment : "}
condapath=${condapath//" (writable)"}
condapath="$(echo -e "${condapath}" | tr -d '[:space:]')" # Gets rid of whitespace

# The if and first elif are probably redundant, can remove both and just use the second elif to cover all cases 
if [ -f "/home/${USER}/miniconda3/etc/profile.d/conda.sh" ]; then # Covers miniconda on lab server
	source "/home/${USER}/miniconda3/etc/profile.d/conda.sh"
	talkative "Sourced miniconda profile.d/conda.sh"
elif [ -f "/home/${USER}/anaconda/etc/profile.d/conda.sh" ]; then # Covers anaconda on lab server
	source "/home/${USER}/anaconda/etc/profile.d/conda.sh"
	talkative "Sourced anaconda profile.d/conda.sh"
elif [ -f "${condapath}/etc/profile.d/conda.sh" ]; then
	source "${condapath}/etc/profile.d/conda.sh"
	talkative "Sourced profile.d/conda.sh"
fi

# Finding the current conda environment (used in beta analysis, continuous vars)
condaenv=$CONDA_PREFIX
talkative "condaenv = $condaenv"

# >>>>>>>>>>>>>> OPTIONS >>>>>>>>>>>>>>
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Set the option flags here
. ${scriptdir}/src/pre_main/setoptions.bash

# If help was set, show help and exit
. ${scriptdir}/src/pre_main/showhelp.bash

# If show_functions was set, show the sequence of functions as below:
. ${scriptdir}/src/pre_main/showfunctions.bash

# Install picrust and deicode here if the install options were added
. ${scriptdir}/src/pre_main/installaddons.bash

# Make fastqc and multiqc reports for all files
. ${scriptdir}/src/pre_main/fastqc.bash

# See if configs exist
. ${scriptdir}/src/pre_main/makeconfig.bash

. ${scriptdir}/src/pre_main/makeoptionalanalyses.bash

# Exit here once if configs didn't exist before, to let the user define variables and filepaths
if [ "$exitnow" = true ]; then
	exit 0
fi

# Source the files
source $srcpath 2> /dev/null
source $analysis_path 2> /dev/null

# Define "immutable" variables (they're actually mutable, but shouldn't be changed)
demuxpairedendpath=${qzaoutput}imported_seqs.qza
metadata_basename=$(basename $metadata_filepath)
orig_metadata_filepath=$metadata_filepath
files_created=() #Does nothing for now

# Putting in flexibility in filepath inputs for projpath, filepath, and qzaoutput
# see if last char in filepath is '/', and if it is, trim it
. ${scriptdir}/src/pre_main/flexiblefilepaths.bash

# <<<<<<<<<<< END OPTIONS <<<<<<<<<<<
# <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# >>>>>>>>>>>>>>>>>>>> LOGGING >>>>>>>>>>>>>>>>>>>>
# Everything below this codeblock will go to a logfile
. ${scriptdir}/src/pre_main/startlogging.bash


# >>>>>>>>>>>>>>>>>>>> MANIFEST FILE GENERATION >>>>>>>>>>>>>>>>>>>>
# if -M was set, source config.txt and make a manifest file
. ${scriptdir}/src/pre_main/makemanifest.bash


# >>>>>>>>>>>>>>>>>>>> FILTER TABLE.QZA >>>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/pre_main/filtertable.bash


# >>>>>>>>>>>>>>>>>>>> RENAME FILES >>>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/pre_main/rename.bash


# >>>>>>>>>>>>>>>>>>>> TESTING >>>>>>>>>>>>>>>>>>>>>
# Figuring out where in the pipeline we got to last time waterway was run
. ${scriptdir}/src/pre_main/testing.bash


# Devtest block, for me!
if [ "$devtest" = true ]; then
	:
fi
echolog ""


# >>>>>>>>>>>>>>> VERBOSE/TEST VARIABLES >>>>>>>>>>>>>>>>
# Find if tst or verbose is true, and run the codeblock if true
. ${scriptdir}/src/pre_main/verboseortest.bash


# >>>>>>>>>>>>> TRAINING A CLASSIFIER >>>>>>>>>>>>
. ${scriptdir}/src/pre_main/trainingclassifier.bash


#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#---------------------------------------------Main--------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################

### NORMAL EXECUTION

# >>>>>>>>>>>>>>>>>>> IMPORT >>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/main_analyses/import.bash


# >>>>>>>>>>>>>>>>> DADA2 >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/main_analyses/dada2.bash


# >>>>>>>>>>>>>>>>>>>> CREATE SUBSETS >>>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/createSubsets.bash


# >>>>>>>>>>>>>>>> DIVERSITY >>>>>>>>>>>>>>>
. ${scriptdir}/src/main_analyses/tree.bash
. ${scriptdir}/src/main_analyses/diversity.bash


#>>>>>>>>>>>>>>> SK_LEARN >>>>>>>>>>>>>>
. ${scriptdir}/src/main_analyses/sklearn.bash

#>>>>>>>>>>>>>> PHYLOSEQ OBJ >>>>>>>>>>>>>>>
. ${scriptdir}/src/R_scripts/bash/run_make_phyloseq.bash


### SUBSET EXECUTION

# >>>>>>>>>>>>>>>> DIVERSITY >>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/main_analyses/tree.bash
. ${scriptdir}/src/subsets/main_analyses/diversity.bash

#>>>>>>>>>>>>>>> SK_LEARN >>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/main_analyses/sklearn.bash

#>>>>>>>>>>>>>> PHYLOSEQ OBJ >>>>>>>>>>>>>>>
. ${scriptdir}/src/R_scripts/bash/run_make_phyloseq_subsets.bash


#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#------------------------------------------Optionals------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################


### All code after this point will only be executed after the main analyses block is completed
### ONE TIME EXECUTION

# LEFse table generation
. ${scriptdir}/src/R_scripts/bash/run_clean_taxa_csv.bash


### NORMAL EXECUTION

# Rerun alpha diversity (if needed for some reason)
. ${scriptdir}/src/optionals/extendedalpha.bash

# Beta rarefactions
. ${scriptdir}/src/optionals/betararefaction.bash

# Beta diversity (categorical data)
. ${scriptdir}/src/optionals/betadiv_categorical.bash

# Beta analysis (continuous data)
. ${scriptdir}/src/optionals/betadiv_continuous.bash

# >>>>>>>>>>>>>>> ANCOM >>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/ancom.bash

# >>>>>>>>>>>> PCOA BIPLOT >>>>>>>>>>>>>
. ${scriptdir}/src/optionals/biplot.bash

# >>>>>>>>>>>>>>>> DEICODE >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/deicode.bash

# >>>>>>>>>>>>>>>>> SONGBIRD >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/songbird.bash

# >>>>>>>>>>>>>>>> SONGBIRD (NATIVE) >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/songbird_native.bash

# >>>>>>>>>>>>>>> SCNIC >>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/scnic.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (CATEGORICAL) >>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/sampleclassifier_categorical.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (CONTINUOUS) >>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/sampleclassifier_continuous.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (NESTED CROSS VALIDATION) >>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/sampleclassifier_ncv.bash

# >>>>>>>>>>>>>>>> LONGITUDINAL >>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/longitudinal.bash

# >>>>>>>>>>>>>> PICRUST2 >>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/picrust2.bash

# >>>>>>>>>>>>>>>>> GNEISS GRADIENT CLUSTERING >>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/gneiss.bash

# >>>>>>>>>>>>>>> BIOENV >>>>>>>>>>>>>>>>
. ${scriptdir}/src/optionals/bioenv.bash


### SUBSET EXECUTION

# Rerun alpha diversity (if needed for some reason)
. ${scriptdir}/src/subsets/optionals/extendedalpha.bash

# Beta rarefactions
. ${scriptdir}/src/subsets/optionals/betararefaction.bash

# Beta diversity (categorical data)
. ${scriptdir}/src/subsets/optionals/betadiv_categorical.bash

# Beta analysis (continuous data)
. ${scriptdir}/src/subsets/optionals/betadiv_continuous.bash

# >>>>>>>>>>>>>>> ANCOM >>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/ancom.bash

# >>>>>>>>>>>> PCOA BIPLOT >>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/biplot.bash

# >>>>>>>>>>>>>>>> DEICODE >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/deicode.bash

# >>>>>>>>>>>>>>>>> SONGBIRD >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/songbird.bash

# >>>>>>>>>>>>>>>> SONGBIRD (NATIVE) >>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/songbird_native.bash

# >>>>>>>>>>>>>>> SCNIC >>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/scnic.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (CATEGORICAL) >>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/sampleclassifier_categorical.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (CONTINUOUS) >>>>>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/sampleclassifier_continuous.bash

# >>>>>>>>>>>>>>>> SAMPLE CLASSIFIER (NESTED CROSS VALIDATION) >>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/sampleclassifier_ncv.bash

# >>>>>>>>>>>>>>>> LONGITUDINAL >>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/longitudinal.bash

# >>>>>>>>>>>>>> PICRUST2 >>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/picrust2.bash

# >>>>>>>>>>>>>>>>> GNEISS GRADIENT CLUSTERING >>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/gneiss.bash

# >>>>>>>>>>>>>>> BIOENV >>>>>>>>>>>>>>>>
. ${scriptdir}/src/subsets/optionals/bioenv.bash


# >>>>>>>>>>>>>>> ENDING >>>>>>>>>>>>>>>
echolog "waterway has finished successfully"
echolog ""
if [[ "$log" = true ]]; then
	replace_colorcodes_log ${name}.out
fi

exit 0