#!/bin/bash
#SBATCH --job-name=waterway
#SBATCH --account=dw30
#SBATCH --time=168:00:00
#SBATCH --partition=m3a
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --cpus-per-task=8
#SBATCH --qos=normal

# Created by Michael Nakai, 22/01/2019 for command line Bash or use with the SLURM job management software

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
version="2.4"

# Finding Qiime2 version number
q2versionnum=$(qiime --version)
q2versionnum=${q2versionnum:14:9} 
q2versionnum=${q2versionnum%.*} # it'll say something like "2019.10" or "2020.2"

# Setting very basic arguments (srcpath is located here)
exitnow=false
if [ -z "$1" ]; then
	# see if argument exists to waterway, then use that dir and find configs
	# if argument doesnt exist, use current working dir
	srcpath="./config.txt"
	analysis_path="./optional_analyses.txt"
	rename_path="./patterns_to_rename.txt"
	scriptdir=`dirname "$0"`
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
	scriptdir="${str}"
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

#---------------------------------------------------------------------------------------------------
#-----------------------------------------Main Function Start---------------------------------------
#---------------------------------------------------------------------------------------------------


#>>>>>>>>>>>>>>>>>>>>>>>>>>OPTIONS BLOCK>>>>>>>>>>>>>>>>>>>>>>>
verbose=false
log=false
tst=false
hlp=false
manifest_status=false
show_functions=false
train_classifier=false
do_fastqc=false
rename_files=false
install_deicode=false
install_picrust=false
filter=false
single_end_reads=false # Currently does nothing
graphs=false # Currently does nothing
devtest=false # This is for anything I want to test

# Let's set the option flags here
for op
do
	if [ "$op" == "-v" ] || [ "$op" == "--verbose" ] ; then
		verbose=true
	fi
	if [ "$op" == "-l" ] || [ "$op" == "--log" ] ; then
		log=true
	fi
	if [ "$op" == "-m" ] || [ "$op" == "--manifest" ] ; then
		manifest_status=true
	fi
	if [ "$op" == "-t" ] || [ "$op" == "--test" ] ; then
		tst=true
	fi
	if [ "$op" == "-h" ] || [ "$op" == "--help" ] ; then
		hlp=true
	fi
	if [ "$op" == "-f" ] || [ "$op" == "--show-functions" ] ; then
		show_functions=true
	fi
	if [ "$op" == "-c" ] || [ "$op" == "--train-classifier" ] ; then
		train_classifier=true
	fi
	if [ "$op" == "-s" ] || [ "$op" == "--single-end" ] ; then
		single_end_reads=true # Currently does nothing
	fi
	if [ "$op" == "-g" ] || [ "$op" == "--graphs" ] ; then
		graphs=true # Currently does nothing
	fi
	if [ "$op" == "-M" ] || [ "$op" == "--make-manifest" ] ; then
		make_manifest=true
	fi
	if [ "$op" == "-F" ] || [ "$op" == "--fastqc" ] ; then
		do_fastqc=true
	fi
	if [ "$op" == "-r" ] || [ "$op" == "--remove-underscores" ] ; then
		rename_files=true
	fi
	if [ "$op" == "-T" ] || [ "$op" == "--filter-table" ] ; then
		filter=true
	fi
	if [ "$op" == "--install-deicode" ] ; then
		install_deicode=true
	fi
	if [ "$op" == "--install-picrust" ] ; then
		install_picrust=true
	fi
	if [ "$op" == "-n" ] || [ "$op" == "--version" ] ; then
		echo ""
		echo -e "Currently running ${LBLUE}waterway${NC} ${LGREY}${version}${NC}"
		echo -e "Currently running ${LGREEN}Qiime2${NC} ${LGREY}${q2versionnum}${NC}"
		echo ""
		exit 0
	fi
	if [ "$op" == "--devtest" ] ; then
		devtest=true
	fi
done

# If help was set, show help and exit
if [[ "$hlp" = true ]] ; then
	echo ""
	echo "DESCRIPTION"
	echo "-------------------"
	echo "This script runs the Qiime2 pipeline (without extensive analysis)"
	echo "and outputs core-metrics-phylogenetic and taxa-bar-plots. It"
	echo "pulls variables from config.txt"
	echo ""
	echo "USAGE"
	echo "-------------------"
	echo "./waterway.bash [path_to_dir_containing_config_here] {options}"
	echo "Note: the path_to_dir is mandatory when using options"
	echo ""
	echo "OPTIONS"
	echo "-------------------"
	echo -e "-M\tGenerate manifest file from files in filepath (in config.txt)"
	echo -e "-m\tUse manifest file to import sequences, as specified in the config file"
	echo -e "-v\tVerbose script output"
	echo -e "-t\tTest the progress flags and exit before executing any qiime commands"
	echo -e "-l\tEnable logging to a log file that is made where this script is"
	echo -e "-f\tShow the exact list of functions used in this script and their output files"
	echo -e "-c\tTrain a greengenes 13_5 99% coverage otu classifier."
	echo -e "-r\tReplaces underscores with hyphens from filenames that match a pattern that includes underscores to replace."
	echo -e "-F\tFilters the table.qza and rep-seqs.qza by metadata files located in metadata/filter_inputs/"
	echo -e "-h\tShow this help dialogue"
	echo ""
	exit 0
fi

# If show_functions was set, show the sequence of functions as below:
if [[ "$show_functions" = true ]] ; then
	echo -e ""
	echo -e "Functions used in this script:"
	echo -e ""
	echo -e "---Import Block---"
	echo -e "1a. qiime tools import (Paired end, Cassava 1.8)"
	echo -e "1b. qiime tools import (Paired end, from manifest with Phred33V2, only if -m is used)"
	echo -e "Both output ${BMAGENTA}imported-seqs.qza${NC}"
	echo -e ""
	echo -e "---Import Visualization Block---"
	echo -e "2. qiime demux summarize (outputs ${BMAGENTA}imported_seqs.qzv${NC})"
	echo -e ""
	echo -e "---Dada2 Block---"
	echo -e "3. qiime dada2 denoise-paired (outputs ${BMAGENTA}table.qza${NC}, ${BMAGENTA}rep-seqs.qza${NC}, ${BMAGENTA}denoising-stats.qza${NC})"
	echo -e "4. qiime feature-table summarize (outputs ${BMAGENTA}table.qzv)${NC}"
	echo -e "5. qiime feature-table tabulate-seqs (outputs ${BMAGENTA}rep-seqs.qzv)${NC}"
	echo -e "6. qiime metadata tabulate (outputs ${BMAGENTA}denoising-stats.qzv${NC})"
	echo -e ""
	echo -e "---Tree Generation Block---"
	echo -e "7. qiime phylogeny align-to-tree-mafft-fasttree (outputs a masked rep-seqs and 2 tree qza files)"
	echo -e ""
	echo -e "---Phylogeny Generation Block---"
	echo -e "8. qiime diversity core-metrics-phylogenetic (outputs ${BMAGENTA}core-metrics-results${NC} folder)"
	echo -e "9. qiime diversity alpha-rarefaction (outputs ${BMAGENTA}alpha-rarefaction.qzv${NC})"
	echo -e ""
	echo -e "---Taxonomic Assignment Block---"
	echo -e "10. qiime feature-classifier classify-sklearn (outputs ${BMAGENTA}taxonomy.qza${NC})"
	echo -e "11. qiime metadata tabulate (outputs ${BMAGENTA}taxonomy.qzv${NC})"
	echo -e "12. qiime taxa barplot (outputs ${BMAGENTA}taxa-bar-plots.qzv${NC})"
	echo -e ""
	echo -e "For more detail, visit: http://marqueslab.erc.monash.edu/home/michael/waterway_docs/QYyBgctVnjnFvSFij7qJrMul6/index.html"
	echo -e ""
	
	exit 0
fi

# Install picrust and deicode here if the install options were added
if [[ "$install-deicode" = true ]] ; then
	exitnow=true
	conda install -c conda-forge deicode
fi

if [[ "$install-picrust" = true ]] ; then
	exitnow=true
	conda install q2-picrust2 -c conda-forge -c bioconda -c gavinmdouglas
fi

if [[ "$do_fastqc" = true ]] ; then
	mkdir ${projpath}fastq_reports 2> /dev/null
	fastqc ${filepath}/*.fastq.gz
	mv ${filepath}/*.zip ${filepath}/*.html ${projpath}fastq_reports
	multiqc ${projpath}fastq_reports/*
fi

# See if configs exist
if [ ! -f $srcpath ]; then
	exitnow=true
	echo -e ""
	echo -e "A config file does not exist. Instead, a template config file "
	echo -e "(${BMAGENTA}config.txt${NC}) will be created where the script is located."
	
	touch config.txt
	echo -e "#Filepaths here" >> config.txt
	echo -e "projpath=/home/username/folder with raw-data, metadata, and outputs folders/" >> config.txt
	echo -e "filepath=/home/username/folder with raw-data, metadata, and outputs folders/raw-data" >> config.txt
	echo -e "qzaoutput=/home/username/folder with raw-data, metadata, and outputs folders/outputs/" >> config.txt
	echo -e "metadata_filepath=/home/username/folder with raw-data, metadata, and outputs folders/metadata/metadata.tsv\n" >> config.txt
	
	echo -e "#Fill these out if using a manifest file" >> config.txt
	echo -e "Fpattern=_R1" >> config.txt
	echo -e "Rpattern=_R2" >> config.txt
	echo -e "manifest=/home/username/folder with raw-data, metadata, and outputs folders/raw-data/manifest.tsv" >> config.txt
	echo -e "manifest_format=PairedEndFastqManifestPhred33V2\n" >> config.txt
	
	echo -e "#Choose how much to trim/trunc here. All combinations of trim/trunc will be done (Dada2)" >> config.txt
	echo -e "trimF=0" >> config.txt
	echo -e "trimR=0" >> config.txt
	echo -e "truncF=() #Trunc combinations here. Ex: (250 240 230)" >> config.txt
	echo -e "truncR=() #Trunc combinations here. Ex: (200 215 180)\n" >> config.txt
	
	echo -e "#Determine your sampling depth for core-metrics-phylogenetic here. You do not want to exclude too many samples" >> config.txt
	echo -e "sampling_depth=0\n" >> config.txt
	
	echo -e "#Determine what group you'd like to compare between for beta diversity. It needs to match the group name in the metadata exactly, caps sensitive." >> config.txt
	echo -e "beta_diversity_group=Group_Here\n" >> config.txt
	
	echo -e "#Path to the trained classifier for sk-learn" >> config.txt
	echo -e "classifierpath=/home/username/classifier.qza\n" >> config.txt
	
	echo -e "#Set these settings if training a classifier" >> config.txt
	echo -e "download_greengenes_files_for_me=false" >> config.txt
	echo -e "greengenes_path=/home/username/dir_containing_greengenes_files/" >> config.txt
	echo -e "forward_primer=GGGGGGGGGGGGGGGGGG" >> config.txt
	echo -e "reverse_primer=AAAAAAAAAAAAAAAAAA" >> config.txt
	echo -e "min_read_length=100" >> config.txt
	echo -e "max_read_length=400" >> config.txt
fi

if [ ! -f $analysis_path ]; then
	exitnow=true
	echo -e ""
	echo -e "An ${BMAGENTA}optional_analyses.txt${NC} file was not found, and will be created now. Please do not"
	echo -e "touch this file if this is the first time analysing your data set."
	echo -e ""
	
	touch optional_analyses.txt
	
	echo -e "### Phyloseq and alpha rarefaction" >> optional_analyses.txt
	echo -e "rerun_phylo_and_alpha=false\n" >> optional_analyses.txt
	
	echo -e "### Beta analysis for categorical variables" >> optional_analyses.txt
	echo -e "rerun_beta_analysis=false" >> optional_analyses.txt
	echo -e "rerun_group=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "### Beta analysis for continuous variables" >> optional_analyses.txt
	echo -e "run_beta_continuous=false" >> optional_analyses.txt
	echo -e "continuous_group=('Group1' 'Group2' 'etc...')" >> optional_analyses.txt
	echo -e "correlation_method='spearman'\n" >> optional_analyses.txt
	
	echo -e "### Ancom analysis" >> optional_analyses.txt
	echo -e "run_ancom=false" >> optional_analyses.txt
	echo -e "make_collapsed_table=false" >> optional_analyses.txt
	echo -e "collapse_taxa_to_level=(2 6)" >> optional_analyses.txt
	echo -e "group_to_compare=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "### Picrust2 Analysis (Picrust2 must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_picrust=false" >> optional_analyses.txt
	echo -e "hsp_method=mp #Default value, shouldnt need to change" >> optional_analyses.txt
	echo -e "max_nsti=2 #Default value, shouldnt need to change\n" >> optional_analyses.txt
	
	echo -e "### PCoA Biplot Analysis" >> optional_analyses.txt
	echo -e "run_biplot=false" >> optional_analyses.txt
	echo -e "number_of_dimensions=20\n" >> optional_analyses.txt
	
	echo -e "### DEICODE analysis (DEICODE must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_deicode=false" >> optional_analyses.txt
	echo -e "num_of_features=8" >> optional_analyses.txt
	echo -e "min_feature_count=2" >> optional_analyses.txt
	echo -e "min_sample_count=100" >> optional_analyses.txt
	echo -e "beta_rerun_group=('Group1' 'Group2' 'etc...') #Put the metadata columns here\n" >> optional_analyses.txt
	
	echo -e "### Bioenv analysis (can take a LONG time with many metadata variables)" >> optional_analyses.txt
	echo -e "run_bioenv=false" >> optional_analyses.txt
	
	echo -e "### Sample classifier and prediction (categorical)" >> optional_analyses.txt
	echo -e "run_classify_samples_categorical=false" >> optional_analyses.txt
	echo -e "metadata_column=('Group1' 'Group2' 'etc...') #Put the metadata columns here" >> optional_analyses.txt
	echo -e "heatmap_num=30" >> optional_analyses.txt
	echo -e "retraining_samples_known_value=true" >> optional_analyses.txt
	echo -e "NCV=true" >> optional_analyses.txt
	echo -e "random_seed=123 #Do not change unless needed" >> optional_analyses.txt
	echo -e "estimator_method='RandomForestClassifier' #Do not change unless needed" >> optional_analyses.txt
	echo -e "k_cross_validations=5 #Do not change unless needed" >> optional_analyses.txt
	echo -e "test_proportion=0.2 #Do not change unless needed" >> optional_analyses.txt
	echo -e "number_of_trees_to_grow=100 #Do not change unless needed" >> optional_analyses.txt
	echo -e "palette='sirocco' #Do not change unless needed\n" >> optional_analyses.txt
	
	echo -e "### Sample classifier and prediction (continuous)" >> optional_analyses.txt
	echo -e "run_classify_samples_continuous=false" >> optional_analyses.txt
	echo -e "metadata_column_continuous=('Group1' 'Group2' 'etc...') #Put the metadata columns here" >> optional_analyses.txt
	echo -e "heatmap_num_continuous=30" >> optional_analyses.txt
	echo -e "retraining_samples_known_value_continuous=true" >> optional_analyses.txt
	echo -e "NCV_continuous=true" >> optional_analyses.txt
	echo -e "estimator_method_continuous='RandomForestRegressor' #Do not change unless needed" >> optional_analyses.txt
	echo -e "k_cross_validations_continuous=5 #Do not change unless needed" >> optional_analyses.txt
	echo -e "random_seed_continuous=123 #Do not change unless needed" >> optional_analyses.txt
	echo -e "test_proportion_continuous=0.2 #Do not change unless needed" >> optional_analyses.txt
	echo -e "number_of_trees_to_grow_continuous=100 #Do not change unless needed" >> optional_analyses.txt
	echo -e "palette_continuous='sirocco' #Do not change unless needed\n" >> optional_analyses.txt
	
	echo -e "### Gneiss gradient-clustering analyses" >> optional_analyses.txt
	echo -e "run_gneiss=false" >> optional_analyses.txt
	echo -e "use_correlation_clustering=true" >> optional_analyses.txt
	echo -e "use_gradient_clustering=false" >> optional_analyses.txt
	echo -e "gradient_column='column in metadata to use here'" >> optional_analyses.txt
	echo -e "gradient_column_categorical='column in metadata that only has either 'low' or 'high''" >> optional_analyses.txt
	echo -e "heatmap_type=seismic" >> optional_analyses.txt
	echo -e "taxa_level=0" >> optional_analyses.txt
	echo -e "balance_name=none\n" >> optional_analyses.txt
fi

if [ "$exitnow" = true ]; then
	exit 0
fi

# Updates the analysis file from the old version (changes variable names)
sed -i -r 's+run_ancom_composition+make_collapsed_table+g' $analysis_path 2> /dev/null 

# Source the files
source $srcpath 2> /dev/null
source $analysis_path 2> /dev/null

demuxpairedendpath=${qzaoutput}imported_seqs.qza

# Putting in flexibility in filepath inputs for projpath, filepath, and qzaoutput
# see if last char in filepath is '/', and if it is, trim it
str=$filepath
i=$((${#str}-1)) 2> /dev/null
j=${str:$i:1} 2> /dev/null
if [[ $j == '/' ]]; then
	str=${str%?}
fi
filepath=${str}

temparray=($projpath $qzaoutput)
fuck=1
for e in ${temparray[@]}; do
	# see if last char in e is '/', and if not, add it
	str=$e
	i=$((${#str}-1)) 2> /dev/null
	j=${str:$i:1} 2> /dev/null
	if [ $j != '/' ]; then
		str="${str}/"
	fi
	
	if [ $fuck -eq 1 ]; then
		projpath=$str
	fi
	if [ $fuck -eq 2 ]; then
		qzaoutput=$str
	fi
	fuck=$(($fuck+1))
done


#>>>>>>>>>>>>>>>>>>>>START LOG BLOCK>>>>>>>>>>>>>>>>>>>>
# Everything below these two codeblocks will go to a logfile
name="waterway_log"
if [[ -e $name.out ]] ; then
    i=0
    while [[ -e $name-$i.out ]] ; do
        let i++
    done
    name=$name-$i
fi

if [[ "$log" = true ]]; then
	touch "$name".out
	exec 3>&1 4>&2
	trap 'exec 2>&4 1>&3' 0 1 2 3
	exec 1>>"${name}.out" 2>&1
fi

#<<<<<<<<<<<<<<<<<<<<END LOG BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<

#>>>>>>>>>>>>>>>>>>>>START MANIFEST BLOCK>>>>>>>>>>>>>>>>>>>>
# if -M was set, source config.txt and make a manifest file
if [[ "$make_manifest" = true ]] ; then
	# Get list of R1/R2 files
	R1_list=(${filepath}/*${Fpattern}*fastq.gz)
	R2_list=(${filepath}/*${Rpattern}*fastq.gz)
	
	talkative "R1_list = ${R1_list[@]}"
	talkative "R2_list = ${R2_list[@]}"
	
	# Write headers to manifest.tsv
	echo -e "#SampleID\tforward-absolute-filepath\treverse-absolute-filepath" > manifest.tsv

	x=0
	for fl in ${R1_list[@]}; do
		if [[ "$log" = true ]]; then
			echo "Starting $(basename $fl)"
		fi
		ID=$(basename $fl)
		ID=${ID%%_*}
		echo -e "${ID}\t${fl}\t${R2_list[x]}" >> manifest.tsv
		x=$((x+1))
	done
	
	echolog "${BMAGENTA}manifest.tsv${NC} created"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi

#<<<<<<<<<<<<<<<<<<<<END MANIFEST BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>START FILTER TABLE BLOCK>>>>>>>>>>>>>>>>>>>>
if [[ "$filter" = true ]] ; then
	
	metadata_to_filter="${metadata_filepath}/filter_inputs"
	
	# Check if the metadata to filter folder was made yet
	if [ ! -d "${metadata_to_filter}" ]; then
	
		mkdir $metadata_to_filter
		
		echo -e ""
		echo -e "The folder ${BMAGENTA}filter_inputs${NC} was created in your metadata"
		echo -e "filepath. Please put your filtered metadata files in that folder, then"
		echo -e "rerun this command."
		echo -e ""
	
		logger "No filter_inputs folder was found in the metadata filepath"
		logger "Created metadata/filter_inputs"
		
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		
		exit 0
	fi
	
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		# Find the table/repseqs
		input="${qzaoutput2}table.qza"
		repinput="${qzaoutput2}rep-seqs.qza"
		
		# Make the folders for tables/repseqs
		mkdir "${qzaoutput2}/tables" 2> /dev/null
		mkdir "${qzaoutput2}/rep-seqs" 2> /dev/null
		
		for file in "${metadata_to_filter}/*"
		do
			
			xbase=${file##*/}
			xpref=${xbase%.*}
			
			echolog "Starting ${CYAN}feature-table filter-samples${NC} for ${BMAGENTA}${file}${NC}"
			
			qiime feature-table filter-samples \
				--i-table $input \
				--m-metadata-file $file \
				--o-filtered-table "${qzaoutput2}/tables/${xpref}-table.qza"
			
			qiime feature-table filter-seqs \
				--i-data $repinput \
				--i-table "${qzaoutput2}/tables/${xpref}-table.qza" \
				--o-filtered-data "${qzaoutput2}/rep-seqs/${xpref}-rep-seqs.qza"
			
		done
	done
fi

#<<<<<<<<<<<<<<<<<<<<END FILTER TABLE BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>START RENAME BLOCK>>>>>>>>>>>>>>>>>>>>
if [[ "$rename_files" = true ]] ; then

	# Check if patterns_to_rename.txt exists. If not, make it and exit.
	if [ ! -f $rename_path ]; then
		echo -e ""
		echo -e "A ${BMAGENTA}patterns_to_rename.txt${NC} file will be made. Please include any"
		echo -e "patterns with underscores included to search for. Any files that"
		echo -e "include these patterns will have the included underscore changed to"
		echo -e "a hyphen."
		echo -e ""
	
		touch patterns_to_rename.txt
		
		echo "pattern1_to_hyphenate_" >> patterns_to_rename.txt
		echo "pattern2_to_hyphanate_" >> patterns_to_rename.txt
		
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		
		exit 0
	fi
	
	mapfile -t gform < $rename_path
	origfold=$(pwd)
	dirWithFiles="${filepath}/"
	
	cd $dirWithFiles
	echo -e "    Finished ${CYAN}cd${NC}-ing into raw-files folder"

	for form in ${gform[@]};
	do
		echo -e "Starting $form"
		formfiles=$(find . -maxdepth 1 -name "*${form}*")
		new=${form//_/-}
		
		# Trying to shorten down the filename until only the $form is left
		# Then we replace the underscores with dashes for the $new
		# Then we can rename the file by finding the $form and replacing with the $new via rename
		for fl in ${formfiles[@]}; 
		do
			talkative "${CYAN}Renaming${NC} ${BMAGENTA}${fl}"
			rename "s/${form}*/${new}/" $fl
		done
		echo ""
	done

	echolog "Going back to ${BMAGENTA}$origfold${NC}"
	cd $origfold
	echolog "${GREEN}Renaming done${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi
#>>>>>>>>>>>>>>>>>>>>END RENAME BLOCK>>>>>>>>>>>>>>>>>>>>

#>>>>>>>>>>>>>>>>>>>>>>>>>>TESTING BLOCK>>>>>>>>>>>>>>>>>>>>>>>
# Figuring out where in the process we got to
import_done=false
importvis_done=false
dada2_done=false
tree_done=false
divanalysis_done=false
sklearn_done=false

echolog ""

# Testing to see if import is done
if test -f "${qzaoutput}imported_seqs.qza"; then
	import_done=true
	echolog "${GREEN}Previously completed: Import step${NC}"
fi

# Testing to see if the import visualization is done
if test -f "${qzaoutput}imported_seqs.qzv"; then
	importvis_done=true
	echolog "${GREEN}Previously completed: Import visualization step${NC}"
fi

# Testing to see if the Dada2 step has outputed a table or NoOutput.txt per combination
if [ "$importvis_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}table.qza"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		dada2_done=true
		echolog "${GREEN}Previously completed: Dada2${NC}"
	fi
fi

# Testing to see if the diversity analysis step has outputted the rooted tree per combination
if [ "$dada2_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}rooted-tree.qza"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		tree_done=true
		echolog "${GREEN}Previously completed: Rooted tree${NC}"
	fi
fi

# Testing to see if the diversity analysis step has outputted the alpha_rarefaction.qzv per combination
if [ "$tree_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}alpha-rarefaction.qzv"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		divanalysis_done=true
		echolog "${GREEN}Previously completed: Alpha rarefaction${NC}"
	fi
fi

# Testing to see if the sklearn step outputted taxa-bar-plots.qzv per folder
if [ "$divanalysis_done" = true ]; then
	i=0
	filecount=0

	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}taxa-bar-plots.qzv"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		sklearn_done=true
		echolog "${GREEN}Previously completed: Sklearn step${NC}"
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END TESTING BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<

# Devtest block!
if [ "$devtest" = true ]; then
	echolog "This is getting echologged"
	logger "This should be only in the log"
	talkative "This is only present if we're verbose"
	errorlog "This goes to stderr"
	exit 0
fi

#>>>>>>>>>>>>>>>>>>>>>>>>>>VERBOSE/TEST VARIABLES>>>>>>>>>>>>>>>>

echolog ""

#Find if tst or verbose is true, and run the codeblock if true
if [ "$tst" = true ] || [ "$verbose" = true ]; then
	talkative "projpath = ${BMAGENTA}${projpath}${NC}"
	talkative "filepath = ${BMAGENTA}${filepath}${NC}"
	talkative "qzaoutput = ${BMAGENTA}${qzaoutput}${NC}"
	talkative "metadata = ${BMAGENTA}${metadata_filepath}${NC}"
	talkative ""
	talkative "manifest_status is ${BMAGENTA}$manifest_status${NC}"
	if [[ "$manifest_status" = true ]]; then
		echolog "manifest is ${BMAGENTA}${manifest}${NC}"
	fi
	talkative "train_classifier is ${BMAGENTA}${train_classifier}${NC}"
	talkative "download greengenes is ${BMAGENTA}${download_greengenes_files_for_me}${NC}"
	talkative ""
	talkative "import_done is ${BMAGENTA}${import_done}${NC}"
	talkative "importvis_done is ${BMAGENTA}${importvis_done}${NC}"
	talkative "dada2_done is ${BMAGENTA}${dada2_done}${NC}"
	talkative "tree_done is ${BMAGENTA}${tree_done}${NC}"
	talkative "divanalysis_done is ${BMAGENTA}${divanalysis_done}${NC}"
	talkative "sklearn_done is ${BMAGENTA}${sklearn_done}${NC}"
	talkative ""
	
	#If -t was set, exit here
	if [[ "$tst" = true ]]; then
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 0
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END VERBOSE BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>TRAINING CLASSIFIER BLOCK>>>>>>>>>>>>>>>>>>>>>>>

if [[ "$train_classifier" == true ]]; then
	echolog ""
	echolog "Starting classifier training on greengenes database..."
	
	#Check to see whether variables have been inputted or changed from defaults
	if [ "${forward_primer}" = "GGGGGGGGGGGGGGGGGG" ] || [ "${reverse_primer}" = "AAAAAAAAAAAAAAAAAA" ]; then 
		errorlog "${RED}Forward or reverse primer not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 2
	fi
	
	if [ ${min_read_length} -eq "100" ] || [ ${max_read_length} -eq "400" ]; then
		echolog ""
		errorlog "${YELLOW}WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT${NC}"
	fi

	#Check to see if the greengenes files are downloaded at greengenes_path
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -d "${greengenes_path%?}" ]; then
		errorlog "${RED}greengenes_path does not refer to a directory and download_greengenes_files_for_me is false${NC}"
		errorlog "${RED}Please either fix the greengenes_path in the config file, or set${NC}"
		errorlog "${RED}download_greengenes_files_for_me to true${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 20
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5.fasta.gz" ]; then
		errorlog "${RED}You are missing gg_13_5.fasta.gz${NC}"
		errorlog "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		errorlog "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 21
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		errorlog "${RED}You are missing either gg_13_5_taxonomy.txt.gz${NC}"
		errorlog "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		errorlog "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 22
	fi

	#Figure out what exists and what doesn't. If download_greengenes_files_for_me is true, wget the files if needed.
	
	ggfastaGZ_exists=false
	ggfasta_exists=false
	ggtaxGZ_exists=false
	ggtax_exists=false
	usepath=false
	
	if [ -f "${greengenes_path}gg_13_5.fasta.gz" ] && [ -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		usepath=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5.fasta.gz" ] || [ -f "gg_13_5.fasta.gz" ]; then
		ggfastaGZ_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5.fasta" ] || [ -f "gg_13_5.fasta" ]; then
		ggfasta_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ] || [ -f "gg_13_5_taxonomy.txt.gz" ]; then
		ggtaxGZ_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5_taxonomy.txt" ] || [ -f "gg_13_5_taxonomy.txt" ]; then
		ggtax_exists=true
	fi
	
	talkative "usepath = ${BMAGENTA}${usepath}${NC}"
	talkative "ggfastaGZ_exists = $ggfastaGZ_exists"
	talkative "ggfasta_exists = $ggfasta_exists"
	talkative "ggtaxGZ_exists = $ggtaxGZ_exists"
	talkative "ggtax_exists = $ggtax_exists"
	
	if [ "$download_greengenes_files_for_me" = true ]; then
		urllink="https://gg-sg-web.s3-us-west-2.amazonaws.com/downloads/greengenes_database/gg_13_5/gg_13_5.fasta.gz"
		if [ "$usepath" = true ]; then
			if [ "$ggfastaGZ_exists" = false ] && [ "$ggfasta_exists" = false ]; then
				wget $urllink -o "${greengenes_path}/gg_13_5.fasta.gz"
				ggfastaGZ_exists=true
			fi
			if [ "$ggfastaGZ_exists" = true ] && [ "$ggfasta_exists" = false ]; then
				echolog "Decompressing gg_13_5.fastq.gz..."
				gunzip -k "${greengenes_path}/gg_13_5.fasta.gz"
				ggfasta="${greengenes_path}/gg_13_5.fasta"
			fi
			if [ "$ggfasta_exists" = true ]; then
				ggfasta="${greengenes_path}/gg_13_5.fasta"
			fi
		else
			if [ "$ggfastaGZ_exists" = false ] && [ "$ggfasta_exists" = false ]; then
				wget $urllink
				ggfastaGZ_exists=true
			fi
			if [ "$ggfastaGZ_exists" = true ] && [ "$ggfasta_exists" = false ]; then
				echolog "Decompressing gg_13_5.fastq.gz..."
				gunzip -k "${scriptdir}/gg_13_5.fasta.gz"
				ggfasta="${scriptdir}/gg_13_5.fasta"
			fi
			if [ "$ggfasta_exists" = true ]; then
				ggfasta="${scriptdir}/gg_13_5.fasta"
			fi
		fi
	fi
	
	if [ "$download_greengenes_files_for_me" = true ]; then
		urllink="https://gg-sg-web.s3-us-west-2.amazonaws.com/downloads/greengenes_database/gg_13_5/gg_13_5_taxonomy.txt.gz"
		if [ "$usepath" = true ]; then
			if [ "$ggtaxGZ_exists" = false ] && [ "$ggtax_exists" = false ]; then
				wget $urllink -o "${greengenes_path}/gg_13_5_taxonomy.txt.gz"
				ggtaxGZ_exists=true
			fi
			if [ "$ggtaxGZ_exists" = true ] && [ "$ggtax_exists" = false ]; then
				echolog "decompressing gg_13_5_taxonomy.txt.gz..."
				gunzip -k "${greengenes_path}/gg_13_5_taxonomy.txt.gz"
				ggtaxonomy="${greengenes_path}/gg_13_5_taxonomy.txt"
			fi
			if [ "$ggtax_exists" = true ]; then
				ggtaxonomy="${greengenes_path}/gg_13_5_taxonomy.txt"
			fi
		else
			if [ "$ggtaxGZ_exists" = false ] && [ "$ggtax_exists" = false ]; then
				wget $urllink
				ggtaxGZ_exists=true
			fi
			if [ "$ggtaxGZ_exists" = true ] && [ "$ggtax_exists" = false ]; then
				echolog "decompressing gg_13_5_taxonomy.txt.gz..."
				gunzip -k "${scriptdir}/gg_13_5_taxonomy.txt.gz"
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
			if [ "$ggtax_exists" = true ]; then
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
		fi
	fi
	
	talkative "ggfasta is ${BMAGENTA}${ggfasta}${NC}"
	talkative "ggtaxonomy is ${BMAGENTA}${ggtaxonomy}${NC}"
	
	if [ "$ggfasta" == "" ] || [ "$ggtaxonomy" == "" ]; then
		errorlog -e "${RED}There was a problem with setting the fasta/taxonomy path. Please report this bug.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 150
	fi
	
	qzaflag=false
	lateflag=false
	if [[ ! -f "extracted-reads.qza" || ! -f "classifier.qza" ]] ; then
		lateflag=true
	fi
	if [[ ! -f "99_otus.qza" || ! -f "ref-taxonomy.qza" ]] ; then
		qzaflag=true
	fi
	
	talkative "qzaflag=${BMAGENTA}${qzaflag}${NC}"
	talkative "lateflag=${BMAGENTA}${lateflag}${NC}"
	
	if [[ "$lateflag" = true && "$qzaflag" = true ]] ; then
		#Run the import commands
		echolog ""
		echolog "Running initial file imports..."
		echolog "Importing ggfasta..."

		qiime tools import \
			--type 'FeatureData[Sequence]' \
			--input-path $ggfasta \
			--output-path "99_otus.qza"
		
		echolog "${GREEN}    Finished importing ggfasta${NC}"
		echolog "Importing ggtax..."
		
		qiime tools import \
			--type 'FeatureData[Taxonomy]' \
			--input-format HeaderlessTSVTaxonomyFormat \
			--input-path $ggtaxonomy \
			--output-path "ref-taxonomy.qza"
		
		echolog "${GREEN}    Finished importing ggtaxonomy${NC}"
	fi
	
	if [ ! -f "extracted-reads.qza" ] && [ ! -f "classifier.qza" ]; then
		#Run the extractions
		echolog "Running read extractions..."
		
		qiime feature-classifier extract-reads \
			--i-sequences "99_otus.qza" \
			--p-f-primer $forward_primer \
			--p-r-primer $reverse_primer \
			--p-min-length $min_read_length \
			--p-max-length $max_read_length \
			--o-reads "extracted-reads.qza"
			
		echolog "${GREEN}    Finished read extractions{NC}"
	fi
	
	if [ ! -f "classifier.qza" ]; then
		#Train the classifier
		echolog "Training the naive bayes classifier..."
		
		qiime feature-classifier fit-classifier-naive-bayes \
			--i-reference-reads "extracted-reads.qza" \
			--i-reference-taxonomy "ref-taxonomy.qza" \
			--o-classifier classifier.qza
		
		echolog "${GREEN}    Finished training the classifier as classifier.qza${NC}"
	fi
	
	if [ -f "classifier.qza" ]; then
		errorlog "${RED}A classifier file already exists as classifier.qza, and has been overwritten.${NC}"
		errorlog "${RED}Please rename the current classifier file if you want a new classifier to be made${NC}"
		errorlog "${RED}when -c is run again.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 24
	fi
	
	sed -i '/classifierpath=/c\classifierpath='"${scriptdir}/classifier.qza" "$srcpath"
	if [ -d "${greengenes_path%?}" ]; then
		mv classifier.qza "${greengenes_path}classifier.qza"
		sed -i '/classifierpath=/c\classifierpath='"${greengenes_path}classifier.qza" "$srcpath"
	fi
	
	echolog "${GREEN}Changed the classifier path in the config file${NC}"
	echolog "${GREEN}Classifier block has finished${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	
	exit 0
	
fi

#<<<<<<<<<<<<<<<<<<<<END TRAINING CLASSIFIER BLOCK<<<<<<<<<<<<<<<<<<<<


#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#---------------------------------------------Main--------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################

files_created=() #Does nothing for now

#>>>>>>>>>>>>>>>>>>>>>>>>>>IMPORT>>>>>>>>>>>>>>>>>>>>>>>

if [ "$import_done" = false ]; then
	echolog ""
	echolog "Starting import block..."
fi

if [ "$import_done" = false ]; then
	
	#If no manifest file, we import via normal filepath
	echolog "Starting ${CYAN}qiime tools import${NC}"
	
	if [ "$manifest_status" = false ]; then
	
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $filepath \
			--input-format CasavaOneEightSingleLanePerSampleDirFmt \
			--output-path ${qzaoutput}imported_seqs.qza
			
		talkative "${GREEN}    Finished importing from ${filepath}${NC}"
		
	fi
	
	#If manifest was set to true, we import via the manifest path
	if [ "$manifest_status" = true ]; then
	
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $manifest \
			--input-format $manifest_format \
			--output-path ${qzaoutput}imported_seqs.qza
			
		talkative "${GREEN}    Finished importing from ${manifest}${NC}"
	fi
	
	echolog "${GREEN}    Finished importing to qza${NC}"
fi

#This will output a sequence quality visualization based on 10,000 randomly selected reads
if [ "$importvis_done" = false ]; then

	echolog "Starting ${CYAN}qiime demux summarize${NC}"

	qiime demux summarize \
		--i-data ${qzaoutput}imported_seqs.qza \
		--o-visualization ${qzaoutput}imported_seqs.qzv
	
	talkative "${GREEN}    Finished summarization of ${qzaoutput}imported_seqs.qza${NC}"

	echolog "${GREEN}    Finished summarizing imported data to qzv${NC}"
	echolog "${GREEN}    Finished import block"
	
fi

#<<<<<<<<<<<<<<<<<<<<END IMPORT BLOCK<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>DADA2>>>>>>>>>>>>>>>>>>>>>>>

if [ "$dada2_done" = false ]; then
	echolog ""
	echolog "Starting Dada2 block..."

	#Break here if Dada2 options haven't been set
	if [ ${#truncF[@]} -eq 0 ]; then 
		errorlog "${RED}Forward read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 10
	fi
	if [ ${#truncR[@]} -eq 0 ]; then
		errorlog "${RED}Backwards read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 11
	fi
	
	#Make dirs for all combinations of truncF and truncR so dada2 can output in them
	for e in ${truncF[@]}
	do
		for e2 in ${truncR[@]}
		do
			mkdir "${qzaoutput}${e}-${e2}" 2> /dev/null
		done
	done

	#This will take the demux-paired-end.qza from multiplex_seq_import.bash and push it through dada2 denoise-paired
	for element in ${truncF[@]}
	do
		for element2 in ${truncR[@]}
		do
		
			echolog "Starting ${CYAN}qiime dada2 denoise-paired${NC}"
			
			qiime dada2 denoise-paired \
				--i-demultiplexed-seqs $demuxpairedendpath \
				--p-trim-left-f $trimR \
				--p-trim-left-r $trimF \
				--p-trunc-len-f $element \
				--p-trunc-len-r $element2 \
				--o-table "${qzaoutput}${element}-${element2}/table.qza" \
				--o-representative-sequences "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-denoising-stats "${qzaoutput}${element}-${element2}/denoising-stats.qza"
			
			echolog "${GREEN}Dada2 of ${element}-${element2} done, progressing to summarization${NC}"
			echolog "Starting ${CYAN}feature-table summarize, tabulate-seqs, and metadata tabulate${NC}"

			qiime feature-table summarize \
				--i-table "${qzaoutput}${element}-${element2}/table.qza" \
				--m-sample-metadata-file $metadata \
				--o-visualization "${qzaoutput}${element}-${element2}/table.qzv"

			qiime feature-table tabulate-seqs \
				--i-data "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/rep-seqs.qzv"

			qiime metadata tabulate \
				--m-input-file "${qzaoutput}${element}-${element2}/denoising-stats.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/denoising-stats.qzv"

			#Checks if denoising worked or whether pairing up ends failed due to low overlap
			if [ ! -f "${qzaoutput}${element}-${element2}/rep-seqs.qza" ]; then
				echo "No output" > "${qzaoutput}${element}-${element2}/NoOutput.txt"
				
				errorlog "${YELLOW}No output for ${element}-${element2}${NC}"
			fi
			
			echolog "${GREEN}Summarization of ${element}-${element2} done${NC}"
		done
	done

	echolog "${GREEN}Dada2 block done${NC}"
fi

#<<<<<<<<<<<<<<<<<<<<END DADA2 BLOCK<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>DIVERSITY>>>>>>>>>>>>>>>>>>>>>>>

if [ "$tree_done" = false ]; then
	echolog ""
	echolog "Starting diversity block..."
	
	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echolog "Starting ${CYAN}align-to-tree-mafft-fasttree${NC}..."
		
		#First we generate the trees for use in later diversity measurements
		qiime phylogeny align-to-tree-mafft-fasttree \
			--i-sequences "${qzaoutput2}rep-seqs.qza" \
			--o-alignment "${qzaoutput2}aligned-rep-seqs.qza" \
			--o-masked-alignment "${qzaoutput2}masked-aligned-rep-seqs.qza" \
			--o-tree "${qzaoutput2}unrooted-tree.qza" \
			--o-rooted-tree "${qzaoutput2}rooted-tree.qza"
	done

	echolog "${GREEN}    Finished trees${NC}"
	echolog "Starting ${CYAN}core-metrics-phylogenetic${NC}"
	
fi

if [ "$divanalysis_done" = false ]; then

	#Break here if sampling_depth is 0
	if [ $sampling_depth -eq 0 ] ; then
		errorlog -e "${RED}Sampling depth not set${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 12
	fi

	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echolog "Starting ${CYAN}core-metrics phylogenetic${NC}"
		
		#Passing the rooted-tree.qza generated through core-metrics-phylogenetic
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}core-metrics-results"
			
		echolog "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}"
		echolog "Starting ${CYAN}alpha-group-significance${NC} and ${CYAN}alpha-rarefaction${NC}"

		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}core-metrics-results/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}core-metrics-results/faith-pd-group-significance.qzv"

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}table.qza" \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--p-max-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}alpha-rarefaction.qzv"
		
		echolog "${GREEN}    Finished alpha-group-significance and alpha-rarefaction${NC}"
		
		mkdir "${qzaoutput2}beta-rarefactions"
		
		metric_list=('euclidean' 'correlation' 'weighted_normalized_unifrac' 'seuclidean' 'braycurtis' 'unweighted_unifrac' 'sqeuclidean' 'generalized_unifrac' 'aitchison' 'matching' 'weighted_unifrac' 'jaccard')
		for thing in ${metric_list[@]}
		do
			echolog "Starting ${CYAN}beta-rarefaction${NC} type: ${BMAGENTA}${thing}${NC}"
			
			qiime diversity beta-rarefaction \
				--i-table "${qzaoutput2}table.qza" \
				--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
				--p-metric $thing \
				--p-clustering-method 'upgma' \
				--m-metadata-file $metadata_filepath \
				--p-sampling-depth $sampling_depth \
				--p-iterations 20 \
				--o-visualization "${qzaoutput2}beta-rarefactions/${thing}.qzv"
		done
		echolog "${GREEN}    Finished beta-rarefaction${NC}"
		echolog "Starting ${CYAN}beta-group-significance${NC}"
		
		qiime diversity beta-group-significance \
			--i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $beta_diversity_group \
			--o-visualization "${qzaoutput2}core-metrics-results/unweighted-unifrac-beta-significance.qzv" \
			--p-pairwise
			
		qiime diversity beta-group-significance \
			--i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $beta_diversity_group \
			--o-visualization "${qzaoutput2}core-metrics-results/weighted-unifrac-beta-significance.qzv" \
			--p-pairwise
		
		echolog "${GREEN}    Finished beta diversity analysis${NC}"
		echolog "${GREEN}    Finished diversity analysis for ${qzaoutput2}${NC}"
		
	done

	echolog "${GREEN}    Finished diversity block${NC}"
	
fi

#<<<<<<<<<<<<<<<<<<<<END DIVERSITY<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>SK_LEARN>>>>>>>>>>>>>>>>>>>>>>>

#Check whether classifier path refers to an actual file or not
if [ ! -f $classifierpath ] ; then
	echo -e "${RED}File does not exist at the classifier path${NC}"
	echo -e "${RED}Please change classifier path in config.txt${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 14
fi

if [ "$sklearn_done" = false ]; then
	echolog ""
	echolog "Starting taxonomic analysis block"

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		echolog "Starting ${CYAN}classify-sklearn${NC} for ${BMAGENTA}$repqza${NC}"

		#Sklearn here
		qiime feature-classifier classify-sklearn \
			--i-classifier $classifierpath \
			--i-reads "${qzaoutput2}rep-seqs.qza" \
			--o-classification "${qzaoutput2}taxonomy.qza"
			
		echolog "${GREEN}    Finished classify-sklearn ${NC}"
		echolog "Starting ${CYAN}qiime metadata tabulate${NC}"

		#Summarize and visualize
		qiime metadata tabulate \
			--m-input-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}taxonomy.qzv"
			
		echolog "${GREEN}    Finished qiime metadata tabulate ${NC}"
		echolog "Starting ${CYAN}qiime taxa barplot${NC}"

		qiime taxa barplot \
			--i-table "${qzaoutput2}table.qza" \
			--i-taxonomy "${qzaoutput2}taxonomy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}taxa-bar-plots.qzv"
			
		echolog "${GREEN}    Finished metadata_tabulate and taxa_barplot${NC}"
		
	done
	
	echolog "${GREEN}    Finished taxonomic analysis block${NC}"
	echolog ""
	
	# This is needed for optional_analyses to continue
	sklearn_done=true
fi

#<<<<<<<<<<<<<<<<<<<<END SK_LEARN<<<<<<<<<<<<<<<<<<<<



#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#------------------------------------------Optionals------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################


###ALL CODE AFTER THIS POINT WILL EXECUTE ONLY AFTER THE MAIN CODE BLOCK HAS BEEN RUN###


#>>>>>>>>>>>>>>>>>>>>>>>>>>RERUN BLOCK>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Rerun alpha diversity (if needed for some reason)
if [ "$rerun_phylo_and_alpha" = true ]; then
	for fl in "${qzaoutput}*/core-metrics-phylogenetic/weighted_unifrac_distance_matrix.qza"
	do
		#Defining qzaoutput2
		qzaoutput2=${fl%"core-metrics-phylogenetic/weighted_unifrac_distance_matrix.qza"}
		
		mkdir "${qzaoutput2}rerun_alpha" 2> /dev/null
		
		echolog "Rerunning ${CYAN}core-metrics-phylogenetic${NC} for ${BMAGENTA}${qzaoutput2}${NC}"
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}rerun_alpha/core-metrics-results"
			
		echolog "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}"

		talkative "Starting ${CYAN}alpha-group-significance${NC} and ${CYAN}alpha-rarefaction${NC}"

		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}rerun_alpha/core-metrics-results/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}rerun_alpha/core-metrics-results/faith-pd-group-significance.qzv"

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}rerun_alpha/table.qza" \
			--i-phylogeny "${qzaoutput2}rerun_alpha/rooted-tree.qza" \
			--p-max-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}rerun_alpha/alpha-rarefaction.qzv"
		
		talkative "${GREEN}    Finished alpha rarefaction and group significance${NC}"
	done
fi

# Beta diversity (categorical data)
if [ "$rerun_beta_analysis" = true ]; then
	for group in "${rerun_group[@]}"
	do
		for fl in ${qzaoutput}*/rep-seqs.qza
		do
			#Defining qzaoutput2
			qzaoutput2=${fl%"rep-seqs.qza"}
			
			talkative "group = $group"
			talkative "fl = $fl"
			talkative "qzaoutput2 = $qzaoutput2"
			
			mkdir "${qzaoutput2}beta_div_reruns" 2> /dev/null
			return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1
			echo $(return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1)
			mkdir "${qzaoutput2}beta_div_reruns/rerun_${group}"
			
			echolog "Starting ${CYAN}beta-group-significance${NC} for ${group}"
			
			#For unweighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/unweighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			#For weighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/weighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			echolog "${GREEN}    Finished beta diversity analysis for ${group}${NC}"
		done
	done
fi

# Beta analysis (continuous data)
if [ "$run_beta_continuous" = true ]; then
	for group in "${continuous_group[@]}"
	do
		for fl in ${qzaoutput}*/rep-seqs.qza
		do
			#Defining qzaoutput2
			qzaoutput2=${fl%"rep-seqs.qza"}
			
			unweightedDistance="${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza"
			weightedDistance="${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza"
			
			mkdir "${qzaoutput2}rerun_beta_continuous" 2> /dev/null
			mkdir "${qzaoutput2}rerun_beta_continuous/${group}" 2> /dev/null
			mkdir "${qzaoutput2}rerun_beta_continuous/outputs" 2> /dev/null
			
			talkative "group = $group"
			talkative "fl = $fl"
			talkative "qzaoutput2 = $qzaoutput2"
			
			echolog "Starting ${CYAN}qiime metadata distance-matrix${NC}"
			
			qiime metadata distance-matrix \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--o-distance-matrix "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza"
			
			echolog "${GREEN}    Finished qiime metadata distance-matrix${NC}"
			echolog "Starting unweighted ${CYAN}qiime diversity mantel${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime diversity mantel \
				--i-dm1 "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza" \
				--i-dm2 $unweightedDistance \
				--p-method $correlation_method \
				--p-label1 "${group}_distance_matrix" \
				--p-label2 "unweighted_unifrac_distance_matrix" \
				--p-intersect-ids \
				--o-visualization "${qzaoutput2}rerun_beta_continuous/${group}/${group}_unweighted_beta_div_cor"
			
			echolog "${GREEN}    Finished unweighted qiime diversity mantel${NC}"
			echolog "Starting weighted ${CYAN}qiime diversity mantel${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime diversity mantel \
				--i-dm1 "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza" \
				--i-dm2 $weightedDistance \
				--p-method $correlation_method \
				--p-label1 "${group}_distance_matrix" \
				--p-label2 "weighted_unifrac_distance_matrix" \
				--p-intersect-ids \
				--o-visualization "${qzaoutput2}rerun_beta_continuous/${group}/${group}_weighted_beta_div_cor"
			
			echolog "${GREEN}    Finished weighted qiime diversity mantel${NC}"
			
			unout="${qzaoutput2}rerun_beta_continuous/${group}/${group}_unweighted_beta_div_cor.qzv"
			weout="${qzaoutput2}rerun_beta_continuous/${group}/${group}_weighted_beta_div_cor.qzv"
			
			cp $unout $weout "${qzaoutput2}rerun_beta_continuous/outputs/" 2> /dev/null
			
		done
	done
fi

#<<<<<<<<<<<<<<<<<<<<END RERUN BLOCK<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>ANCOM>>>>>>>>>>>>>>>>>>>>>>>

if [[ ( "$run_ancom" = true && "$sklearn_done" = true ) || ( "$make_collapsed_table" = true && "$sklearn_done" = true ) ]] ; then
	
	echolog ""
	echolog "Starting ANCOM analysis..."
	
	for group in "${group_to_compare[@]}"
	do
		
		for repqza in ${qzaoutput}*/rep-seqs.qza
		do
			
			if [ "$make_collapsed_table" = true ]; then
			
				echolog "Starting composition rerun for ${BMAGENTA}${group}${NC}"
			
				#Defining qzaoutput2
				qzaoutput2=${repqza%"rep-seqs.qza"}
				
				mkdir "${qzaoutput2}ancom_outputs" 2> /dev/null
				mkdir "${qzaoutput2}ancom_outputs/${group}" 2> /dev/null
				mkdir "${qzaoutput2}ancom_outputs/all_qzvfiles" 2> /dev/null
				
				echolog "${CYAN}feature-table filter-features${NC} starting for ${BMAGENTA}${group}${NC}"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}table.qza" \
					--p-min-samples 2 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/temp.qza"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}ancom_outputs/${group}/temp.qza" \
					--p-min-frequency 10 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza"
					
				rm "${qzaoutput2}ancom_outputs/${group}/temp.qza" 2> /dev/null
					
				echolog "${GREEN}    Finished feature table filtering${NC}"
				echolog "${CYAN}qiime taxa collapse${NC} starting"
				
				for element in "${collapse_taxa_to_level[@]}"
				do
					qiime taxa collapse \
						--i-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza" \
						--i-taxonomy "${qzaoutput2}taxonomy.qza" \
						--p-level $element \
						--o-collapsed-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza"
					
					echolog "${GREEN}    Finished taxa collapsing to level ${element}${NC}"
					echolog "Starting ${CYAN}qiime composition add-pseudocount${NC}"
					
					qiime composition add-pseudocount \
						--i-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza" \
						--o-composition-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza"
					
					echolog "${GREEN}    Finished pseudocount adding for level ${element}${NC}"
				done
			fi
			
			for element in "${collapse_taxa_to_level[@]}"
			do
				echolog "Starting ${CYAN}qiime composition ancom${NC}"
				
				qiime composition ancom \
					--i-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza" \
					--m-metadata-file $metadata_filepath \
					--m-metadata-column $group_to_compare \
					--o-visualization "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv"
				
				cp "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv" "${qzaoutput2}ancom_outputs/all_qzvfiles/"
			
				echolog "${GREEN}    Finished ancom composition and the ancom block for ${group}${NC}"
			done
		done
	done

else
	errorlog "${YELLOW}Either run_ancom is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Ancom analysis${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
fi


#<<<<<<<<<<<<<<<<<<<<END ANCOM<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>PCOA BIPLOT>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_biplot" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}biplot_outputs" 2> /dev/null
		
		echolog "Creating rarefied table via ${CYAN}qiime feature-table rarefy${NC}"
		
		qiime feature-table rarefy \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--o-rarefied-table "${qzaoutput2}biplot_outputs/rarefied_table.qza"
		
		echolog "${GREEN}    Finished making rarefied table${NC}"
		echolog "Creating a braycurtis distance matrix via ${CYAN}qiime diversity beta${NC}"
		
		qiime diversity beta \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--p-metric braycurtis \
			--o-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza"
		
		echolog "${GREEN}    Finished creating a braycurtis distance matrix${NC}"
		echolog "Creating a PCoA via ${CYAN}qiime diversity pcoa${NC}"
		
		qiime diversity pcoa \
			--i-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza" \
			--p-number-of-dimensions $number_of_dimensions \
			--o-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza"
		
		echolog "${GREEN}    Finished creating a PCoA${NC}"
		echolog "Starting relative frequency table generation via ${CYAN}qiime feature-table relative-frequency${NC}"
		
		qiime feature-table relative-frequency \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--o-relative-frequency-table "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza"
			
		echolog "${GREEN}    Finished creating a relative frequency table${NC}"
		echolog "Making the biplot for unweighted UniFrac via ${CYAN}qiime diversity pcoa-biplot${NC}"
		
		qiime diversity pcoa-biplot \
			--i-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza" \
			--i-features "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza" \
			--o-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza"
		
		echolog "${GREEN}    Finished creating a biplot${NC}"
		echolog "Producing an emperor plot via ${CYAN}qiime emperor biplot${NC}"

		qiime emperor biplot \
			--i-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}biplot_outputs/unweighted_unifrac_emperor_biplot.qzv"
			
		echolog "${GREEN}    Finished producing the emperor plot${NC}"
		echolog "${GREEN}PCoA biplot analysis     Finished${NC}"
		echolog ""
		
	done
else
	errorlog "${YELLOW}Either run_biplot is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Biplot production${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi


#<<<<<<<<<<<<<<<<<<<<END PCOA BIPLOT<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START DEICODE>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_deicode" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}deicode_outputs" 2> /dev/null
		
		echolog "Running beta diversity ordination files via ${CYAN}qiime deicode rpca${NC}"

		qiime deicode rpca \
			--i-table "${qzaoutput2}table.qza" \
			--p-min-feature-count $min_feature_count \
			--p-min-sample-count $min_sample_count \
			--o-biplot "${qzaoutput2}deicode_outputs/ordination.qza" \
			--o-distance-matrix "${qzaoutput2}deicode_outputs/distance.qza"
		
		echolog "${GREEN}    Finished beta diversity ordination files${NC}"
		echolog "Creating biplot via ${CYAN}qiime emperor biplot${NC}"
		
		#TODO: How the fuck do I get the biplot to show Taxon Classification instead of feature ID for the bacteria
		qiime emperor biplot \
			--i-biplot "${qzaoutput2}deicode_outputs/ordination.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}deicode_outputs/biplot.qzv" \
			--p-number-of-features $num_of_features
		
		echolog "${GREEN}    Finished creating biplot${NC}"
		
		#Make a PERMANOVA comparison to see if $group explains the clustering in biplot.qzv
		mkdir "${qzaoutput2}deicode_outputs/PERMANOVAs" 2>/dev/null
		for group in "${beta_rerun_group[@]}"
		do
			echolog "Starting ${CYAN}beta-group-significance${NC}: ${BMAGENTA}${group}${NC}"
			
			logger "group = ${BMAGENTA}${group}${NC}"
			logger "qzaoutput2 = ${BMAGENTA}${qzaoutput2}${NC}"
			
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}deicode_outputs/distance.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-method permanova \
				--o-visualization "${qzaoutput2}deicode_outputs/PERMANOVAs/${group}-permanova.qzv"
			
			echolog "${GREEN}    Finished beta group: ${group}${NC}"
			
		done
		
		echolog "${GREEN}    Finished DEICODE for ${repqza}${NC}"
		
	done
else
	errorlog "${YELLOW}Either run_deicode is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Deicode analysis${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi


#<<<<<<<<<<<<<<<<<<<<END DEICODE<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START SAMPLE CLASSIFIER (CATEGORICAL)>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_classify_samples_categorical" = true ] && [ "$NCV" = false ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/categorical" 2> /dev/null
		
		for group in ${metadata_column[@]}
		do
			
			echolog "Starting ${CYAN}sample-classifier classify-samples${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier classify-samples \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-test-size $test_proportion \
				--p-cv $k_cross_validations \
				--p-random-state $random_seed \
				--p-n-estimators $number_of_trees_to_grow \
				--p-optimize-feature-selection \
				--p-parameter-tuning \
				--p-palette $palette \
				--p-missing-samples 'ignore' \
				--output-dir "${qzaoutput2}supervised_learning_classifier/categorical/${group}"
				
			echolog "${GREEN}    Finished sample-classifier classify-samples${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime sample-classifier summarize \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/categorical/${group}/sample_estimator.qza"
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-sample_estimator_summary.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/predictions.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-predictions.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/probabilities.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-probabilities.qzv"
	
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-feature_importance.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			echolog "Starting ${CYAN}feature filtering${NC} to isolate important features"
			
			qiime feature-table filter-features \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-important_feature_table.qza"
			
			echolog "${GREEN}    Finished important feature isolating${NC}"
			echolog "Starting ${CYAN}heatmap generation${NC} to find the top ${BMAGENTA}${heatmap_num}${NC} most abundant features"
			
			qiime sample-classifier heatmap \
				--i-table "${qzaoutput2}table.qza" \
				--i-importance "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--m-sample-metadata-file $metadata_filepath \
				--m-sample-metadata-column $group \
				--p-group-samples \
				--p-feature-count $heatmap_num \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/categorical/${group}/important-feature-table-top-30.qza" \
				--o-heatmap "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-important-feature-heatmap.qzv"
				
			echolog "${GREEN}    Finished heatmap generation${NC}"
			echolog "Starting ${CYAN}sample-classifier predict-classification${NC}"
				
			qiime sample-classifier predict-classification \
				--i-table "${qzaoutput2}table.qza" \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/categorical/${group}/sample_estimator.qza" \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_predictions.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_probabilities.qza"
			
			echolog "${GREEN}    Finished sample-classifier predict-classification${NC}"
			
			if [ "$retraining_samples_known_value" = true ]; then
				echolog "Starting ${CYAN}confusion matrix generation${NC}"
				
				qiime sample-classifier confusion-matrix \
					--i-predictions "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_predictions.qza" \
					--i-probabilities "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_probabilities.qza" \
					--m-truth-file $metadata_filepath \
					--m-truth-column $group \
					--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_confusion_matrix.qzv"
				
				echolog "${GREEN}    Finished confusion matrix generation${NC}"
			fi
			echolog "${GREEN}    Finished sample-classifier (categorical) for: ${group}${NC}"
		done
	done
else
	errorlog "${YELLOW}Either run_classify_samples_categorical is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Classifier training${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi

#<<<<<<<<<<<<<<<<<<<<END SAMPLE CLASSIFIER (CATEGORICAL)<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START SAMPLE CLASSIFIER (CONTINUOUS)>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_classify_samples_continuous" = true ] && [ "$NCV_continuous" = false ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/continuous" 2> /dev/null
		
		for group in ${metadata_column_continuous[@]}
		do
			
			echolog "Starting ${CYAN}sample-classifier regress-samples${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier regress-samples \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-test-size $test_proportion_continuous \
				--p-cv $k_cross_validations_continuous \
				--p-random-state $random_seed_continuous \
				--p-n-estimators $number_of_trees_to_grow_continuous \
				--p-palette $palette_continuous \
				--p-missing-samples 'ignore' \
				--output-dir "${qzaoutput2}supervised_learning_classifier/continuous/${group}"
				
			echolog "${GREEN}    Finished sample-classifier regress-samples${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime sample-classifier summarize \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/continuous/${group}/sample_estimator.qza"
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-sample_estimator_summary.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/predictions.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-predictions.qzv"
	
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/feature_importance.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-feature_importance.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			echolog "Starting ${CYAN}feature filtering${NC} to isolate important features"
			
			qiime feature-table filter-features \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/feature_importance.qza" \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/continuous/${group}/important_feature_table.qza"
			
			echolog "${GREEN}    Finished important feature isolating${NC}"
			echolog "Starting ${CYAN}heatmap generation${NC} to find the top ${BMAGENTA}${heatmap_num}${NC} most abundant features"
			
			qiime sample-classifier heatmap \
				--i-table "${qzaoutput2}table.qza" \
				--i-importance "${qzaoutput2}supervised_learning_classifier/continuous/${group}/feature_importance.qza" \
				--m-sample-metadata-file $metadata_filepath \
				--m-sample-metadata-column $group \
				--p-group-samples \
				--p-feature-count $heatmap_num \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/continuous/${group}/important-features-top-30.qza" \
				--o-heatmap "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-important-feature-heatmap.qzv"
				
			echolog "${GREEN}    Finished heatmap generation${NC}"
			echolog "Starting ${CYAN}sample-classifier predict-classification${NC}"
				
			qiime sample-classifier predict-classification \
				--i-table "${qzaoutput2}table.qza" \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/continuous/${group}/sample_estimator.qza" \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_predictions.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_probabilities.qza"
			
			echolog "${GREEN}    Finished sample-classifier predict-classification${NC}"
			
			if [ "$retraining_samples_known_value_continuous" = true ]; then
				echolog "Starting ${CYAN}confusion matrix generation${NC}"
				
				qiime sample-classifier confusion-matrix \
					--i-predictions "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_predictions.qza" \
					--i-probabilities "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_probabilities.qza" \
					--m-truth-file $metadata_filepath \
					--m-truth-column $group \
					--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_confusion_matrix.qzv"
				
				echolog "${GREEN}    Finished confusion matrix generation${NC}"
			fi
			echolog "${GREEN}    Finished sample-classifier (continuous) for: ${group}${NC}"
		done
	done
else
	errorlog "${YELLOW}Either run_classify_samples_continuous is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Classifier training${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi

#<<<<<<<<<<<<<<<<<<<<END SAMPLE CLASSIFIER (CONTINUOUS)<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START SAMPLE CLASSIFIER (NESTED CROSS VALIDATION)>>>>>>>>>>>>>>>>>>>>>>>

# NCV for categorical data
if [ "$run_classify_samples_categorical" = true ] && [ "$NCV" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical" 2> /dev/null
		
		for group in ${metadata_column[@]}
		do
			
			mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}NCV classification${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier classify-samples-ncv \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-estimator $estimator_method \
				--p-n-estimators $number_of_trees_to_grow \
				--p-random-state $random_seed \
				--p-missing-samples 'ignore' \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--o-feature-importance "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qza"
			
			echolog "${GREEN}    Finished NCV sample classification${NC}"
			echolog "Starting ${CYAN}confusion-matrix generation${NC} to calculate classifier accuracy"
			
			qiime sample-classifier confusion-matrix \
				--i-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--i-probabilities "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--m-truth-file $metadata_filepath \
				--m-truth-column $group \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/ncv_confusion_matrix.qzv"
				
			echolog "${GREEN}    Finished confusion matrix generation${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			
		done
	done
fi

# NCV for continuous data
if [ "$run_classify_samples_continuous" = true ] && [ "$NCV_continuous" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous" 2> /dev/null
		
		for group in ${metadata_column_continuous[@]}
		do
			
			mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}NCV regressor classification${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier regress-samples-ncv \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-estimator $estimator_method_continuous \
				--p-n-estimators $number_of_trees_to_grow_continuous \
				--p-random-state $random_seed_continuous \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--o-feature-importance "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qza"
			
			echolog "${GREEN}    Finished regressor classification${NC}"
			echolog "Starting ${CYAN}scatterplot generation${NC} to calculate regressor accuracy"
			
			qiime sample-classifier scatterplot \
				--i-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--m-truth-file $metadata_filepath \
				--m-truth-column ${group} \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-scatter.qzv"
			
			echolog "${GREEN}    Finished scatterplot generation${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			
		done
	done
fi

#<<<<<<<<<<<<<<<<<<<<END SAMPLE CLASSIFIER (NCV)<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START PICRUST2>>>>>>>>>>>>>>>>>>>>>>>

#TODO: Check if picrust2 component is installed for current version. If not, exit

if [ "$run_picrust" = true ] && [ "$sklearn_done" = true ]; then
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		echolog "Starting the picrust pipeline for: ${BMAGENTA}${qzaoutput2}${NC}"
		
		qiime picrust2 full-pipeline \
			--i-table "${qzaoutput2}table.qza" \
			--i-seq "${qzaoutput2}rep-seqs.qza" \
			--output-dir "${qzaoutput2}q2-picrust2_output" \
			--p-hsp-method $hsp_method \
			--p-max-nsti $max_nsti \
			--verbose
		
		echolog "${GREEN}    Finished an execution of the picrust pipeline${NC}"
		echolog "Starting feature table summarization of ${BMAGENTA}pathway_abundance.qza${NC}"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/pathway_abundance.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ko_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ko_metagenome.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ec_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ec_metagenome.qzv"
		
		echolog "${GREEN}    Finished feature table summarization${NC}"
		echolog "Starting generation of ${CYAN}core-metrics${NC} using the outputted ${BMAGENTA}pathway_abundance.qza${NC}"
		
		qiime diversity core-metrics \
		   --i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
		   --p-sampling-depth $sampling_depth \
		   --m-metadata-file $metadata_filepath \
		   --output-dir "${qzaoutput2}q2-picrust2_output/pathabun_core_metrics"
		
		echolog "${GREEN}    Finished core-metrics generation${NC}"
		
	done
	
	echolog "${GREEN}    Finished the picrust pipeline block${NC}"
	
else
	echolog "${YELLOW}Either run_picrust is set to false, or taxonomic analyses${NC}"
	echolog "${YELLOW}have not been completed on the dataset. Picrust2 production${NC}"
	echolog "${YELLOW}will not proceed.${NC}"
	echolog ""
fi

#<<<<<<<<<<<<<<<<<<<<END PICRUST2<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>GNEISS GRADIENT CLUSTERING>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_gneiss" = true ] && [ "$sklearn_done" = true ]; then
	
	echolog "Starting Gneiss gradient-clustering analysis block..."
	talkative "gradient_column is $gradient_column"
	talkative "metadata_filepath is ${BMAGENTA}${metadata_filepath}${NC}"
	talkative "gradient_column_categorical is $gradient_column_categorical"
	talkative "taxa_level is $taxa_level"
	talkative "balance_name is $balance_name"
		
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}gneiss_outputs" 2> /dev/null
		
		if [ "$use_correlation_clustering" = true ]; then
			
			echolog "Using ${CYAN}correlation-clustering${NC} for gneiss analysis"

			qiime gneiss correlation-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
			
		fi
		
		if [ "$use_gradient_clustering" = true ]; then
			
			echolog "Using ${CYAN}gradient-clustering${NC} for gneiss analysis"

			qiime gneiss gradient-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--m-gradient-file $metadata_filepath \
				--m-gradient-column $gradient_column \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
		
		fi
		
		echolog "${GREEN}    Finished clustering${NC}"
		echolog "Producing balances via ${CYAN}qiime gneiss ilr-hierarchical${NC}"
		
		qiime gneiss ilr-hierarchical \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/hierarchy.qza" \
			--o-balances "${qzaoutput2}gneiss_outputs/balances.qza"
		
		echolog "${GREEN}    Finished balance production${NC}"
		echolog "Producing regression via ${CYAN}qiime gneiss ols-regression${NC}"
		
		qiime gneiss ols-regression \
			--p-formula $gradient_column \
			--i-table "${qzaoutput2}gneiss_outputs/balances.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}gneiss_outputs/regression_summary_pCG.qzv"
		
		echolog "${GREEN}    Finished regression${NC}"
		echolog "Producing heatmap via ${CYAN}qiime gneiss dendrogram-heatmap${NC}"

		qiime gneiss dendrogram-heatmap \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--p-color-map $heatmap_type \
			--o-visualization "${qzaoutput2}gneiss_outputs/heatmap_pCG.qzv"
		
		echolog "${GREEN}    Finished heatmap${NC}"
		echolog "Creating gneiss output via ${CYAN}qiime gneiss balance-taxonomy${NC}"

		qiime gneiss balance-taxonomy \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--i-taxonomy "${qzaoutput2}taxonomy.qza" \
			--p-taxa-level $taxa_level \
			--p-balance-name $balance_name \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--o-visualization "${qzaoutput2}gneiss_outputs/${balance_name}_taxa_summary_${gradient_column_categorical}_level_${taxa_level}.qzv"
	done
	echolog "${GREEN}    Finished Gneiss gradient-clustering analysis block${NC}"
	echolog ""

else
	errorlog "${YELLOW}Either run_gneiss is set to false, or taxonomic analyses"
	errorlog "${YELLOW}have not been completed on the dataset. Gneiss analysis"
	errorlog "${YELLOW}will not proceed."
fi


#<<<<<<<<<<<<<<<<<<<<END GNEISS GRADIENT CLUSTERING<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>START BIOENV>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_bioenv" = true ] && [ "$sklearn_done" = true ]; then
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		betaDistanceMatrices=('unweighted' 'weighted')
		for distance in $betaDistanceMatrices
		do
			echolog "Starting ${CYAN}bioenv diversity analysis${NC} for ${BMAGENTA}${distance}_unifrac${NC}"
			
			qiime diversity bioenv \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/${distance}_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--o-visualization "${qzaoutput2}core-metrics-results/${distance}_unifrac_bioenv.qzv" \
				--verbose
				
		done
		echolog "${GREEN}    Finished bioenv analysis${NC} for ${BMAGENTA}${qzaoutput2}${NC}"
	done
fi


#<<<<<<<<<<<<<<<<<<<<END BIOENV<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>SORT AND OUTPUT>>>>>>>>>>>>>>>>>>>>>>>


#Add all qza and qzv files produced to two different folders inside the truncF-truncR folders
#TODO

#<<<<<<<<<<<<<<<<<<<<END SORT AND OUTPUT<<<<<<<<<<<<<<<<<<<<

echolog "waterway has finished successfully"
echolog ""
if [[ "$log" = true ]]; then
	replace_colorcodes_log ${name}.out
fi

exit 0