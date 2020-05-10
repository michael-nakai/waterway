#!/bin/bash
#SBATCH --job-name=waterway
#SBATCH --account=dw30
#SBATCH --time=168:00:00
#SBATCH --partition=m3a
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --cpus-per-task=8
#SBATCH --qos=normal

#Created by Michael Nakai, 22/01/2019 for command line Bash or use with the SLURM job management software

export LC_ALL="en_US.utf-8"
export LANG="en_US.utf-8"

#Setting color variables for echos (need -e, remember to NC after a color)
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BMAGENTA='\033[1;35m'
NC='\033[0m'

LBLUE='\033[1;36m' #Only used for -n
LGREEN='\033[1;32m' #Only used for -n
LGREY='\033[0;37m' #Only used for -n

#Check that a Qiime2 environment is active
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

#Version number here
version="2.1.1d"

#Finding Qiime2 version number
q2versionnum=$(qiime --version)
q2versionnum=${q2versionnum:14:9} 
q2versionnum=${q2versionnum%.*} #if echo'd, it's something like "2019.10" or "2020.2"

#Setting very basic arguments (srcpath is located here)
exitnow=false
if [ -z "$1" ]; then
	#see if argument exists to waterway, then use that dir and find configs
	#if argument doesnt exist, use current working dir
	srcpath="./config.txt"
	analysis_path="./optional_analyses.txt"
	rename_path="./patterns_to_rename.txt"
	scriptdir=`dirname "$0"`
else
	#see if last char in $1 is '/', and if it is, trim it
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

#Useful helper functions here
#Use with two arguments (str to dirname to be surveyed, str of name that should be returned), with one optional third argument (file extension)
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

#A group of sed commands to strip the color codes from the log file. First argument should be log filename with extension
function replace_colorcodes_log {
	sed -i -r 's+\[0;31m++g' $1
	sed -i -r 's+\[0;32m++g' $1
	sed -i -r 's+\[0;36m++g' $1
	sed -i -r 's+\[1;33m++g' $1
	sed -i -r 's+\[1;35m++g' $1
	sed -i -r 's+\[0m++g' $1
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
single_end_reads=false #Currently does nothing
graphs=false #Currently does nothing

#Let's set the option flags here
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
		single_end_reads=true #Currently does nothing
	fi
	if [ "$op" == "-g" ] || [ "$op" == "--graphs" ] ; then
		graphs=true #Currently does nothing
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
done

#If help was set, show help and exit
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
	echo -e "-h\tShow this help dialogue"
	echo ""
	exit 0
fi

#If show_functions was set, show the sequence of functions as below:
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

#Install picrust and deicode here if the install options were added
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

#See if configs exist
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
	echo -e "Fpattern=_R1_" >> config.txt
	echo -e "Rpattern=_R2_" >> config.txt
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
	
	echo -e "#Phyloseq and alpha rarefaction" >> optional_analyses.txt
	echo -e "rerun_phylo_and_alpha=false\n" >> optional_analyses.txt
	
	echo -e "#Beta analysis" >> optional_analyses.txt
	echo -e "rerun_beta_analysis=false" >> optional_analyses.txt
	echo -e "rerun_group=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "#Ancom analysis" >> optional_analyses.txt
	echo -e "run_ancom=false" >> optional_analyses.txt
	echo -e "make_collapsed_table=false" >> optional_analyses.txt
	echo -e "collapse_taxa_to_level=6" >> optional_analyses.txt
	echo -e "group_to_compare=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "#Picrust2 Analysis (Picrust2 must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_picrust=false" >> optional_analyses.txt
	echo -e "hsp_method=mp #Default value, shouldnt need to change" >> optional_analyses.txt
	echo -e "max_nsti=2 #Default value, shouldnt need to change\n" >> optional_analyses.txt
	
	echo -e "#PCoA Biplot Analysis" >> optional_analyses.txt
	echo -e "run_biplot=false" >> optional_analyses.txt
	echo -e "number_of_dimensions=20\n" >> optional_analyses.txt
	
	echo -e "#DEICODE analysis (DEICODE must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_deicode=false" >> optional_analyses.txt
	echo -e "num_of_features=8" >> optional_analyses.txt
	echo -e "min_feature_count=2" >> optional_analyses.txt
	echo -e "min_sample_count=100" >> optional_analyses.txt
	echo -e "beta_rerun_group=('Group1' 'Group2' 'etc...') #Put the metadata columns here\n" >> optional_analyses.txt
	
	echo -e "#Gneiss gradient-clustering analyses" >> optional_analyses.txt
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

#Updates the analysis file from the old version (changes variable names)
sed -i -r 's+run_ancom_composition+make_collapsed_table+g' $analysis_path 2> /dev/null 

source $srcpath 2> /dev/null
source $analysis_path 2> /dev/null

demuxpairedendpath=${qzaoutput}imported_seqs.qza

#Putting in flexibility in filepath inputs for projpath, filepath, and qzaoutput
#see if last char in filepath is '/', and if it is, trim it
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
	#see if last char in e is '/', and if not, add it
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
#if -M was set, source config.txt and make a manifest file
if [[ "$make_manifest" = true ]] ; then
	# Get list of R1/R2 files
	R1_list=(${filepath}/*${Fpattern}*fastq.gz)
	R2_list=(${filepath}/*${Rpattern}*fastq.gz)
	
	if [[ "$log" = true ]]; then
		echo "R1_list = ${R1_list[@]}"
		echo "R2_list = ${R2_list[@]}"
	fi
	
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
	echo -e "${BMAGENTA}manifest.tsv${NC} created"
	if [[ "$log" = true ]]; then
		echo -e "${BMAGENTA}manifest.tsv${NC} created"
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi

#<<<<<<<<<<<<<<<<<<<<END MANIFEST BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>START RENAME BLOCK>>>>>>>>>>>>>>>>>>>>
if [[ "$rename_files" = true ]] ; then

	#Check if patterns_to_rename.txt exists. If not, make it and exit.
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
			echo -e "${CYAN}Renaming${NC} ${BMAGENTA}${fl}"
			rename "s/${form}*/${new}/" $fl
		done
		echo ""
	done

	echo -e "Going back to ${BMAGENTA}$origfold${NC}"
	cd $origfold
	echo -e "${GREEN}Renaming done${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi
#>>>>>>>>>>>>>>>>>>>>END RENAME BLOCK>>>>>>>>>>>>>>>>>>>>

#>>>>>>>>>>>>>>>>>>>>>>>>>>TESTING BLOCK>>>>>>>>>>>>>>>>>>>>>>>
#Figuring out where in the process we got to
import_done=false
importvis_done=false
dada2_done=false
tree_done=false
divanalysis_done=false
sklearn_done=false

echo ""

#Testing to see if import is done
if test -f "${qzaoutput}imported_seqs.qza"; then
	import_done=true
	echo -e "${GREEN}Previously completed: Import step${NC}"
fi

#Testing to see if the import visualization is done
if test -f "${qzaoutput}imported_seqs.qzv"; then
	importvis_done=true
	echo -e "${GREEN}Previously completed: Import visualization step${NC}"
fi

#Testing to see if the Dada2 step has outputed a table or NoOutput.txt per combination
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
		echo -e "${GREEN}Previously completed: Dada2${NC}"
	fi
fi

#Testing to see if the diversity analysis step has outputted the rooted tree per combination
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
		echo -e "${GREEN}Previously completed: Rooted tree${NC}"
	fi
fi

#Testing to see if the diversity analysis step has outputted the alpha_rarefaction.qzv per combination
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
		echo -e "${GREEN}Previously completed: Alpha rarefaction${NC}"
	fi
fi

#Testing to see if the sklearn step outputted taxa-bar-plots.qzv per folder
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
		echo -e "${GREEN}Previously completed: Sklearn step${NC}"
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END TESTING BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>VERBOSE/TEST VARIABLES>>>>>>>>>>>>>>>>

echo ""

#Find if tst or verbose is true, and run the codeblock if true
if [ "$tst" = true ] || [ "$verbose" = true ]; then
	echo -e "projpath = ${BMAGENTA}${projpath}${NC}"
	echo -e "filepath = ${BMAGENTA}${filepath}${NC}"
	echo -e "qzaoutput = ${BMAGENTA}${qzaoutput}${NC}"
	echo -e "metadata = ${BMAGENTA}${metadata_filepath}${NC}"
	echo -e ""
	echo -e "manifest_status is ${BMAGENTA}$manifest_status"
	if [[ "$manifest_status" = true ]]; then
		echo -e "manifest is ${BMAGENTA}${manifest}${NC}"
	fi
	echo -e "train_classifier is ${BMAGENTA}${train_classifier}${NC}"
	echo -e "download greengenes is ${BMAGENTA}${download_greengenes_files_for_me}${NC}"
	echo -e ""
	echo -e "import_done is ${BMAGENTA}${import_done}${NC}"
	echo -e "importvis_done is ${BMAGENTA}${importvis_done}${NC}"
	echo -e "dada2_done is ${BMAGENTA}${dada2_done}${NC}"
	echo -e "tree_done is ${BMAGENTA}${tree_done}${NC}"
	echo -e "divanalysis_done is ${BMAGENTA}${divanalysis_done}${NC}"
	echo -e "sklearn_done is ${BMAGENTA}${sklearn_done}${NC}"
	echo -e ""
	
	if [[ "$log" = true ]]; then
		echo -e "manifest_status is ${BMAGENTA}$manifest_status" >&3
		if [[ "$manifest_status" = true ]]; then
			echo "manifest is $manifest" >&3
		fi
		echo -e "train_classifier is ${BMAGENTA}${train_classifier}${NC}" >&3
		echo -e "download greengenes is ${BMAGENTA}${download_greengenes_files_for_me}${NC}" >&3
		echo "" >&3
		echo -e "import_done is ${BMAGENTA}${import_done}${NC}" >&3
		echo -e "importvis_done is ${BMAGENTA}${importvis_done}${NC}" >&3
		echo -e "dada2_done is ${BMAGENTA}${dada2_done}${NC}" >&3
		echo -e "tree_done is ${BMAGENTA}${tree_done}${NC}" >&3
		echo -e "divanalysis_done is ${BMAGENTA}${divanalysis_done}${NC}" >&3
		echo -e "sklearn_done is ${BMAGENTA}${sklearn_done}${NC}" >&3
		echo "" >&3
	fi
	
	#If -t was set, exit here
	if [[ "$tst" = true ]]; then
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 0
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END VERBOSE BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>RERUN BLOCK>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#TODO: Make so that more than one analyses can be rerun at a time.
#Maybe nest the "exit 0" into an if block (if number of reruns run == number of true vars in analyses_to_rerun.txt, then exit).

if [ "$rerun_phylo_and_alpha" = true ]; then
	for fl in "${qzaoutput}*/core-metrics-phylogenetic/weighted_unifrac_distance_matrix.qza"
	do
		#Defining qzaoutput2
		qzaoutput2=${fl%"core-metrics-phylogenetic/weighted_unifrac_distance_matrix.qza"}
		
		mkdir "${qzaoutput2}rerun_alpha" 2> /dev/null
		
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}rerun_alpha/core-metrics-results"
			
		echo -e "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}" >&3
		fi

		if [[ "$verbose" = true ]]; then
			echo -e "Starting ${CYAN}alpha-group-significance${NC} and ${CYAN}alpha-rarefaction${NC}"
		fi

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
		
		if [[ "$verbose" = true ]]; then
			echo -e "${GREEN}    Finished alpha rarefaction and group significance${NC}"
		fi
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished alpha rarefaction and group significance${NC}" >&3
		fi
	done
fi

if [ "$rerun_beta_analysis" = true ]; then
	for group in "${rerun_group[@]}"
	do
		for fl in ${qzaoutput}*/rep-seqs.qza
		do
			#Defining qzaoutput2
			qzaoutput2=${fl%"rep-seqs.qza"}
			
			if [ "$verbose" = true ]; then
				echo "group = $group"
				echo "fl = $fl"
				echo "qzaoutput2 = $qzaoutput2"
			fi
			
			mkdir "${qzaoutput2}beta_div_reruns" 2> /dev/null
			return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1
			echo $(return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1)
			mkdir "${qzaoutput2}beta_div_reruns/rerun_${group}"
			
			echo -e "Starting ${CYAN}beta-group-significance${NC} for ${group}"
			
			#For unweighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $rerun_group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/unweighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			#For weighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $rerun_group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/weighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			echo -e "${GREEN}    Finished beta diversity analysis for $group${NC}"
		done
	done
fi

#<<<<<<<<<<<<<<<<<<<<END RERUN BLOCK<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>TRAINING CLASSIFIER BLOCK>>>>>>>>>>>>>>>>>>>>>>>

if [[ "$train_classifier" == true ]]; then
	echo ""
	echo "Starting classifier training on greengenes database..."
	if [[ "$log" = true ]]; then
		echo "Starting classifier training on greengenes database..." >&3
	fi
	
	#Check to see whether variables have been inputted or changed from defaults
	if [ "${forward_primer}" = "GGGGGGGGGGGGGGGGGG" ] || [ "${reverse_primer}" = "AAAAAAAAAAAAAAAAAA" ]; then 
		echo -e "${RED}Forward or reverse primer not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 2
	fi
	
	if [ ${min_read_length} -eq "100" ] || [ ${max_read_length} -eq "400" ]; then
		echo ""
		echo -e "${YELLOW}WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT${NC}"
		if [[ "$log" = true ]]; then
			echo ""
			echo -e "${YELLOW}WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT${NC}" >&3
		fi
	fi

	#Check to see if the greengenes files are downloaded at greengenes_path
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -d "${greengenes_path%?}" ]; then
		echo -e "${RED}greengenes_path does not refer to a directory and download_greengenes_files_for_me is false${NC}"
		echo -e "${RED}Please either fix the greengenes_path in the config file, or set${NC}"
		echo -e "${RED}download_greengenes_files_for_me to true${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${RED}greengenes_path does not refer to a directory and download_greengenes_files_for_me is false${NC}" >&3
			echo -e "${RED}Please either fix the greengenes_path in the config file, or set${NC}" >&3
			echo -e "${RED}download_greengenes_files_for_me to true${NC}" >&3
			replace_colorcodes_log ${name}.out
		fi
		exit 20
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5.fasta.gz" ]; then
		echo -e "${RED}You are missing gg_13_5.fasta.gz${NC}"
		echo -e "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		echo -e "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${RED}You are missing gg_13_5.fasta.gz${NC}" >&3
			echo -e "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}" >&3
			echo -e "${RED}or rename your files to these names if already downloaded.${NC}" >&3
			replace_colorcodes_log ${name}.out
		fi
		exit 21
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		echo -e "${RED}You are missing either gg_13_5_taxonomy.txt.gz${NC}"
		echo -e "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		echo -e "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${RED}You are missing gg_13_5_taxonomy.txt.gz${NC}" >&3
			echo -e "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}" >&3
			echo -e "${RED}or rename your files to these names if already downloaded.${NC}" >&3
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
	
	if [ "$verbose" = true ]; then
		echo -e "usepath = ${BMAGENTA}${usepath}${NC}"
		echo "ggfastaGZ_exists = $ggfastaGZ_exists"
		echo "ggfasta_exists = $ggfasta_exists"
		echo "ggtaxGZ_exists = $ggtaxGZ_exists"
		echo "ggtax_exists = $ggtax_exists"
	fi
	
	if [ "$download_greengenes_files_for_me" = true ]; then
		urllink="https://gg-sg-web.s3-us-west-2.amazonaws.com/downloads/greengenes_database/gg_13_5/gg_13_5.fasta.gz"
		if [ "$usepath" = true ]; then
			if [ "$ggfastaGZ_exists" = false ] && [ "$ggfasta_exists" = false ]; then
				wget $urllink -o "${greengenes_path}/gg_13_5.fasta.gz"
				ggfastaGZ_exists=true
			fi
			if [ "$ggfastaGZ_exists" = true ] && [ "$ggfasta_exists" = false ]; then
				echo "Decompressing gg_13_5.fastq.gz..."
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
				echo "Decompressing gg_13_5.fastq.gz..."
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
				echo "decompressing gg_13_5_taxonomy.txt.gz..."
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
				echo "decompressing gg_13_5_taxonomy.txt.gz..."
				gunzip -k "${scriptdir}/gg_13_5_taxonomy.txt.gz"
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
			if [ "$ggtax_exists" = true ]; then
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
		fi
	fi
	
	if [ "$verbose" = true ]; then
		echo -e "ggfasta is ${BMAGENTA}${ggfasta}${NC}"
		echo -e "ggtaxonomy is ${BMAGENTA}${ggtaxonomy}${NC}"
	fi
	
	if [ "$ggfasta" == "" ] || [ "$ggtaxonomy" == "" ]; then
		echo -e "${RED}There was a problem with setting the fasta/taxonomy path. Please report this bug.${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${RED}There was a problem with setting the fasta/taxonomy path. Please report this bug.${NC}"
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
	
	if [[ "$verbose" = true ]]; then
		echo -e "qzaflag=${BMAGENTA}${qzaflag}${NC}"
		echo -e "lateflag=${BMAGENTA}${lateflag}${NC}"
	fi
	
	if [[ "$lateflag" = true && "$qzaflag" = true ]] ; then
		#Run the import commands
		echo ""
		echo "Running initial file imports..."
		if [[ "$log" = true ]]; then
			echo "Running initial file imports..." >&3
		fi
		
		echo "Importing ggfasta..."
		if [[ "$log" = true ]]; then
			echo "Importing ggfasta..." >&3
		fi
		qiime tools import \
			--type 'FeatureData[Sequence]' \
			--input-path $ggfasta \
			--output-path "99_otus.qza"
		
		echo -e "${GREEN}    Finished importing ggfasta${NC}"
		
		echo "Importing ggtax..."
		if [[ "$log" = true ]]; then
			echo "Importing ggtax..." >&3
		fi
		qiime tools import \
			--type 'FeatureData[Taxonomy]' \
			--input-format HeaderlessTSVTaxonomyFormat \
			--input-path $ggtaxonomy \
			--output-path "ref-taxonomy.qza"
		
		echo -e "${GREEN}    Finished importing ggtaxonomy${NC}"
	fi
	
	if [ ! -f "extracted-reads.qza" ] && [ ! -f "classifier.qza" ]; then
		#Run the extractions
		echo "Running read extractions..."
		if [[ "$log" = true ]]; then
			echo "Running read extractions..." >&3
		fi
		
		qiime feature-classifier extract-reads \
			--i-sequences "99_otus.qza" \
			--p-f-primer $forward_primer \
			--p-r-primer $reverse_primer \
			--p-min-length $min_read_length \
			--p-max-length $max_read_length \
			--o-reads "extracted-reads.qza"
			
		echo -e "${GREEN}    Finished read extractions{NC}"
	fi
	
	if [ ! -f "classifier.qza" ]; then
		#Train the classifier
		echo "Training the naive bayes classifier..."
		if [[ "$log" = true ]]; then
			echo "Training the naive bayes classifier..." >&3
		fi
		
		qiime feature-classifier fit-classifier-naive-bayes \
			--i-reference-reads "extracted-reads.qza" \
			--i-reference-taxonomy "ref-taxonomy.qza" \
			--o-classifier classifier.qza
		
		echo -e "${GREEN}    Finished training the classifier as classifier.qza${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished training the classifier as classifier.qza${NC}" >&3
		fi
	fi
	
	if [ -f "classifier.qza" ]; then
		echo -e "${RED}A classifier file already exists as classifier.qza, and has been overwritten.${NC}"
		echo -e "${RED}Please rename the current classifier file if you want a new classifier to be made.${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${RED}A classifier file already exists as classifier.qza, and has been overwritten.${NC}" >&3
			echo -e "${RED}Please rename the current classifier file if you want a new classifier to be made.${NC}" >&3
			replace_colorcodes_log ${name}.out
		fi
		exit 24
	fi
	
	sed -i '/classifierpath=/c\classifierpath='"${scriptdir}/classifier.qza" "$srcpath"
	if [ -d "${greengenes_path%?}" ]; then
		mv classifier.qza "${greengenes_path}classifier.qza"
		sed -i '/classifierpath=/c\classifierpath='"${greengenes_path}classifier.qza" "$srcpath"
	fi
	
	echo -e "${GREEN}Changed the classifier path in the config file${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}Changed the classifier path in the config file${NC}" >&3
	fi
	
	echo -e "${GREEN}Classifier block has     Finished${NC}"
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
	echo ""
	echo "Starting import block..."
	if [[ "$log" = true ]]; then
		echo "Starting import block..." >&3
	fi
fi

if [ "$import_done" = false ]; then
	
	#If no manifest file, we import via normal filepath
	echo -e "Starting ${CYAN}qiime tools import${NC}"
	if [[ "$log" = true ]]; then
		echo -e "Starting ${CYAN}qiime tools import${NC}" >&3
	fi
	
	if [ "$manifest_status" = false ]; then
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $filepath \
			--input-format CasavaOneEightSingleLanePerSampleDirFmt \
			--output-path ${qzaoutput}imported_seqs.qza
			
		if [[ "$verbose" = true ]]; then
			echo -e "${GREEN}    Finished importing from ${filepath}${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}    Finished importing from ${filepath}${NC}" >&3
			fi
		fi
	fi
	
	#If manifest was set to true, we import via the manifest path
	if [ "$manifest_status" = true ]; then
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $manifest \
			--input-format $manifest_format \
			--output-path ${qzaoutput}imported_seqs.qza
			
		if [[ "$verbose" = true ]]; then
			echo -e "${GREEN}    Finished importing from ${manifest}${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}    Finished importing from ${manifest}${NC}" >&3
			fi
		fi
	fi
fi

if [ "$import_done" = false ]; then
	echo -e "${GREEN}    Finished importing to qza${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished importing to qza${NC}" >&3
	fi
fi

#This will output a sequence quality visualization based on 10,000 randomly selected reads
if [ "$importvis_done" = false ]; then
	echo -e "Starting ${CYAN}qiime demux summarize${NC}"
	if [[ "$log" = true ]]; then
		echo -e "Starting ${CYAN}qiime demux summarize${NC}" >&3
	fi

	qiime demux summarize \
		--i-data ${qzaoutput}imported_seqs.qza \
		--o-visualization ${qzaoutput}imported_seqs.qzv
	
	if [[ "$verbose" = true ]]; then
		echo -e "${GREEN}    Finished summarization of ${qzaoutput}imported_seqs.qza${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished summarization of ${qzaoutput}imported_seqs.qza${NC}" >&3
		fi
	fi
fi

if [ "$importvis_done" = false ]; then
	echo -e "${GREEN}    Finished summarizing imported data to qzv${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished summarizing imported data to qzv${NC}" >&3
	fi

	echo -e "${GREEN}    Finished import block"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished import block${NC}" >&3
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END IMPORT BLOCK<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>DADA2>>>>>>>>>>>>>>>>>>>>>>>

if [ "$dada2_done" = false ]; then
	echo ""
	echo "Starting Dada2 block..."
	if [[ "$log" = true ]]; then
		echo "Starting Dada2 block..." >&3
	fi
fi

#Make dirs for all combinations of truncF and truncR so dada2 can output in them
if [ "$dada2_done" = false ]; then

	#Break here if Dada2 options haven't been set
	if [ ${#truncF[@]} -eq 0 ]; then 
		echo -e "${RED}Forward read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 10
	fi
	if [ ${#truncR[@]} -eq 0 ]; then
		echo -e "${RED}Backwards read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 11
	fi
	
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
			echo -e "Starting ${CYAN}qiime dada2 denoise-paired${NC}"
			if [[ "$log" = true ]]; then
				echo -e "Starting ${CYAN}qiime dada2 denoise-paired${NC}" >&3
			fi
			
			qiime dada2 denoise-paired \
				--i-demultiplexed-seqs $demuxpairedendpath \
				--p-trim-left-f $trimR \
				--p-trim-left-r $trimF \
				--p-trunc-len-f $element \
				--p-trunc-len-r $element2 \
				--o-table "${qzaoutput}${element}-${element2}/table.qza" \
				--o-representative-sequences "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-denoising-stats "${qzaoutput}${element}-${element2}/denoising-stats.qza"
			
			echo -e "${GREEN}Dada2 of ${element}-${element2} done, progressing to summarization${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}Dada2 of ${element}-${element2} done, progressing to summarization${NC}" >&3
			fi

			echo -e "Starting ${CYAN}feature-table summarize, tabulate-seqs, and metadata tabulate${NC}"
			if [[ "$log" = true ]]; then
				echo -e "Starting ${CYAN}feature-table summarize, tabulate-seqs, and metadata tabulate${NC}" >&3
			fi

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
				
				echo -e "${YELLOW}No output for ${element}-${element2}${NC}"
				if [[ "$log" = true ]]; then
					echo -e "${YELLOW}No output for ${element}-${element2}${NC}" >&3
				fi
			fi
			
			echo -e "${GREEN}Summarization of ${element}-${element2} done${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}Summarization of ${element}-${element2} done${NC}" >&3
			fi
		done
	done
fi

if [ "$dada2_done" = false ]; then
	echo -e "${GREEN}Dada2 block done${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}Dada2 block done${NC}" >&3
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END DADA2 BLOCK<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>DIVERSITY>>>>>>>>>>>>>>>>>>>>>>>

if [ "$tree_done" = false ]; then
	echo ""
	echo "Starting diversity block..."
	if [[ "$log" = true ]]; then
		echo "Starting diversity block..." >&3
	fi
fi

if [ "$tree_done" = false ]; then
	
	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echo -e "Starting ${CYAN}align-to-tree-mafft-fasttree${NC}..."
		if [[ "$log" = true ]]; then
			echo -e "Starting ${CYAN}align-to-tree-mafft-fasttree${NC}..." >&3
		fi
		
		#First we generate the trees for use in later diversity measurements
		qiime phylogeny align-to-tree-mafft-fasttree \
			--i-sequences "${qzaoutput2}rep-seqs.qza" \
			--o-alignment "${qzaoutput2}aligned-rep-seqs.qza" \
			--o-masked-alignment "${qzaoutput2}masked-aligned-rep-seqs.qza" \
			--o-tree "${qzaoutput2}unrooted-tree.qza" \
			--o-rooted-tree "${qzaoutput2}rooted-tree.qza"
	done
fi

if [ "$tree_done" = false ]; then
	echo -e "${GREEN}    Finished trees${NC}"
	echo -e "Starting ${CYAN}core-metrics-phylogenetic${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished trees${NC}" >&3
		echo -e "${CYAN}Starting core-metrics-phylogenetic${NC}" >&3
	fi
fi

if [ "$divanalysis_done" = false ]; then

	#Break here if sampling_depth is 0
	if [ $sampling_depth -eq 0 ] ; then
		echo -e "${RED}Sampling depth not set${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 12
	fi

	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echo -e "Starting ${CYAN}core-metrics phylogenetic${NC}"
		if [[ "$log" = true ]]; then
			echo -e "Starting ${CYAN}core-metrics phylogenetic${NC}" >&3
		fi
		
		#Passing the rooted-tree.qza generated through core-metrics-phylogenetic
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}core-metrics-results"
			
		echo -e "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}" >&3
		fi

		if [[ "$verbose" = true ]]; then
			echo -e "Starting ${CYAN}alpha-group-significance${NC} and ${CYAN}alpha-rarefaction${NC}"
		fi
		if [[ "$log" = true ]]; then
			echo "Starting alpha-group-significance and alpha-rarefaction"
		fi

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
		
		if [[ "$verbose" = true ]]; then
			echo -e "${GREEN}    Finished alpha-group-significance and alpha-rarefaction${NC}"
		fi
		if [[ "$log" = true ]]; then
			echo "    Finished alpha-group-significance and alpha-rarefaction"
		fi
		
		echo -e "Starting ${CYAN}beta-group-significance${NC}"
		if [[ "$log" = true ]]; then
			echo -e "Starting ${CYAN}beta-group-significance${NC}" >&3
		fi
		
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
		
		echo -e "${GREEN}    Finished beta diversity analysis${NC}"
		if [[ "$verbose" = true ]]; then
			echo -e "${GREEN}    Finished beta diversity analysis${NC}"
		fi
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished beta diversity analysis${NC}" >&3
		fi

		echo -e "${GREEN}    Finished diversity analysis for ${qzaoutput2}${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished diversity analysis for ${qzaoutput2}${NC}" >&3
		fi
	done
fi

if [ "$tree_done" = false ]; then
	echo -e "${GREEN}    Finished diversity block${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished diversity block${NC}" >&3
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END DIVERSITY<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>SK_LEARN>>>>>>>>>>>>>>>>>>>>>>>

if [ "$sklearn_done" = false ]; then
	echo ""
	echo "Starting taxonomic analysis block"
	if [[ "$log" = true ]]; then
		echo "Starting taxonomic analysis block" >&3
	fi
fi

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
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		echo -e "Starting ${CYAN}classify-sklearn${NC} for ${BMAGENTA}$repqza${NC}"
		if [[ "$log" = true ]]; then
			echo -e "Starting ${CYAN}classify-sklearn${NC} for ${BMAGENTA}$repqza${NC}" >&3
		fi

		#Sklearn here
		qiime feature-classifier classify-sklearn \
			--i-classifier $classifierpath \
			--i-reads "${qzaoutput2}rep-seqs.qza" \
			--o-classification "${qzaoutput2}taxonomy.qza"
			
		echo -e "${GREEN}    Finished classify-sklearn ${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished classify-sklearn ${NC}" >&3
		fi

		#Summarize and visualize
		qiime metadata tabulate \
			--m-input-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}taxonomy.qzv"

		qiime taxa barplot \
			--i-table "${qzaoutput2}table.qza" \
			--i-taxonomy "${qzaoutput2}taxonomy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}taxa-bar-plots.qzv"
			
		echo -e "${GREEN}    Finished metadata_tabulate and taxa_barplot${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished metadata_tabulate and taxa_barplot${NC}" >&3
		fi
	done
	echo -e "${GREEN}    Finished taxonomic analysis block${NC}"
	echo ""
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished taxonomic analysis block${NC}" >&3
	fi
	sklearn_done=true
fi

#<<<<<<<<<<<<<<<<<<<<END SK_LEARN<<<<<<<<<<<<<<<<<<<<



#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#------------------------------------------Optionals------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################


###ALL CODE AFTER THIS POINT WILL EXECUTE ONLY AFTER THE MAIN CODE BLOCK HAS BEEN RUN###


#>>>>>>>>>>>>>>>>>>>>>>>>>>ANCOM>>>>>>>>>>>>>>>>>>>>>>>

if [[ ( "$run_ancom" = true && "$sklearn_done" = true ) || ( "$make_collapsed_table" = true && "$sklearn_done" = true ) ]] ; then
	
	echo ""
	echo "Starting ANCOM analysis..."
	if [[ "$log" = true ]]; then
		echo "Starting ANCOM analysis..." >&3
	fi
	
	for group in "${group_to_compare[@]}"
	do
		
		for repqza in ${qzaoutput}*/rep-seqs.qza
		do
			
			if [ "$make_collapsed_table" = true ]; then
			
				echo -e "Starting composition rerun for ${BMAGENTA}${group}${NC}"
				if [[ "$log" = true ]]; then
					echo -e "Starting composition rerun for ${BMAGENTA}${group}${NC}" >&3
				fi
			
				#Defining qzaoutput2
				qzaoutput2=${repqza%"rep-seqs.qza"}
				
				mkdir "${qzaoutput2}ancom_outputs" 2> /dev/null
				mkdir "${qzaoutput2}ancom_outputs/${group}" 2> /dev/null
				mkdir "${qzaoutput2}ancom_outputs/all_qzvfiles" 2> /dev/null
				
				echo -e "${CYAN}feature-table filter-features${NC} starting for ${BMAGENTA}${group}${NC}"
				if [[ "$log" = true ]]; then
					echo -e "${CYAN}feature-table filter-features${NC} starting for ${BMAGENTA}${group}${NC}" >&3
				fi
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}table.qza" \
					--p-min-samples 2 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/temp.qza"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}ancom_outputs/${group}/temp.qza" \
					--p-min-frequency 10 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza"
					
				rm "${qzaoutput2}ancom_outputs/${group}/temp.qza" 2> /dev/null
					
				echo -e "${GREEN}    Finished feature table filtering${NC}"
				echo -e "${CYAN}qiime taxa collapse${NC} starting"
				if [[ "$log" = true ]]; then
					echo -e "${GREEN}    Finished feature table filtering${NC}" >&3
					echo -e "${CYAN}qiime taxa collapse${NC} starting" >&3
				fi
			
				qiime taxa collapse \
					--i-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza" \
					--i-taxonomy "${qzaoutput2}taxonomy.qza" \
					--p-level $collapse_taxa_to_level \
					--o-collapsed-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza"
				
				echo -e "${GREEN}    Finished taxa collapsing${NC}"
				echo -e "Starting ${CYAN}qiime composition add-pseudocount${NC}"
				if [[ "$log" = true ]]; then
					echo -e "${GREEN}    Finished taxa collapsing${NC}" >&3
					echo -e "Starting ${CYAN}qiime composition add-pseudocount${NC}" >&3
				fi
				
				qiime composition add-pseudocount \
					--i-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza" \
					--o-composition-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza"
				
				echo -e "${GREEN}    Finished pseudocount adding${NC}"
				if [[ "$log" = true ]]; then
					echo -e "${GREEN}    Finished pseudocount adding${NC}" >&3
				fi
			fi
			
			echo -e "Starting ${CYAN}qiime composition ancom${NC}"
			if [[ "$log" = true ]]; then
				echo -e "Starting ${CYAN}qiime composition ancom${NC}" >&3
			fi
			
			qiime composition ancom \
				--i-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group_to_compare \
				--o-visualization "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv"
			
			cp "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv" "${qzaoutput2}ancom_outputs/all_qzvfiles/"
		
			echo -e "${GREEN}    Finished ancom composition and the ancom block for ${group}${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}    Finished ancom composition and the ancom block for ${group}${NC}" >&3
			fi
		done
	done

else
	echo -e "${YELLOW}Either run_ancom is set to false, or taxonomic analyses${NC}"
	echo -e "${YELLOW}have not been completed on the dataset. Ancom analysis${NC}"
	echo -e "${YELLOW}will not proceed.${NC}"
	if [[ "$log" = true ]]; then
		echo -e "${YELLOW}Either run_ancom is set to false, or taxonomic analyses${NC}" >&3
		echo -e "${YELLOW}have not been completed on the dataset. Ancom analysis${NC}" >&3
		echo -e "${YELLOW}will not proceed.${NC}" >&3
	fi
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
		
		echo -e "Creating rarefied table via ${CYAN}qiime feature-table rarefy${NC}"
		if [[ "$log" = true ]]; then
			echo -e "Creating rarefied table via ${CYAN}qiime feature-table rarefy${NC}" >&3
		fi
		
		qiime feature-table rarefy \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--o-rarefied-table "${qzaoutput2}biplot_outputs/rarefied_table.qza"
		
		echo -e "Creating a braycurtis distance matrix via ${CYAN}qiime diversity beta${NC}"
		if [[ "$log" = true ]]; then
			echo "    Finished making rarefied table"
			echo -e "Creating a braycurtis distance matrix via ${CYAN}qiime diversity beta${NC}" >&3
		fi
		
		qiime diversity beta \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--p-metric braycurtis \
			--o-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza"
		
		echo -e "Creating a PCoA via ${CYAN}qiime diversity pcoa${NC}"
		if [[ "$log" = true ]]; then
			echo "    Finished creating a braycurtis distance matrix"
			echo -e "Creating a PCoA via ${CYAN}qiime diversity pcoa${NC}" >&3
		fi
		
		qiime diversity pcoa \
			--i-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza" \
			--p-number-of-dimensions $number_of_dimensions \
			--o-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza"
		
		echo -e "Starting relative frequency table generation via ${CYAN}qiime feature-table relative-frequency${NC}"
		if [[ "$log" = true ]]; then
			echo "    Finished creating a PCoA"
			echo -e "Starting relative frequency table generation via ${CYAN}qiime feature-table relative-frequency${NC}" >&3
		fi
		
		qiime feature-table relative-frequency \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--o-relative-frequency-table "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza"
			
		echo -e "Making the biplot for unweighted UniFrac via ${CYAN}qiime diversity pcoa-biplot${NC}"
		if [[ "$log" = true ]]; then
			echo "    Finished creating a relative frequency table"
			echo -e "Making the biplot for unweighted UniFrac via ${CYAN}qiime diversity pcoa-biplot${NC}" >&3
		fi
		
		qiime diversity pcoa-biplot \
			--i-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza" \
			--i-features "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza" \
			--o-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza"
			
		echo -e "Producing an emperor plot via ${CYAN}qiime emperor biplot${NC}"
		if [[ "$log" = true ]]; then
			echo "    Finished creating a biplot"
			echo -e "Producing an emperor plot via ${CYAN}qiime emperor biplot${NC}" >&3
		fi
		
		qiime emperor biplot \
			--i-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}biplot_outputs/unweighted_unifrac_emperor_biplot.qzv"
			
		echo -e "${GREEN}    Finished producing the emperor plot${NC}"
		echo -e "${GREEN}PCoA biplot analysis     Finished${NC}"
		echo ""
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished producing the emperor plot${NC}" >&3
			echo -e "${GREEN}PCoA biplot analysis     Finished${NC}" >&3
		fi
	done
else
	echo -e "${YELLOW}Either run_biplot is set to false, or taxonomic analyses${NC}"
	echo -e "${YELLOW}have not been completed on the dataset. Biplot production${NC}"
	echo -e "${YELLOW}will not proceed.${NC}"
	echo -e ""
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
		
		echo -e "Running beta diversity ordination files via ${CYAN}qiime deicode rpca${NC}"
		if [[ "$log" = true ]]; then
			echo -e "Running beta diversity ordination files via ${CYAN}qiime deicode rpca${NC}" >&3
		fi

		qiime deicode rpca \
			--i-table "${qzaoutput2}table.qza" \
			--p-min-feature-count $min_feature_count \
			--p-min-sample-count $min_sample_count \
			--o-biplot "${qzaoutput2}deicode_outputs/ordination.qza" \
			--o-distance-matrix "${qzaoutput2}deicode_outputs/distance.qza"
		
		echo -e "${GREEN}    Finished beta diversity ordination files${NC}"
		echo -e "Creating biplot via ${CYAN}qiime emperor biplot${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished beta diversity ordination files${NC}" >&3
			echo -e "Creating biplot via ${CYAN}qiime emperor biplot${NC}" >&3
		fi
		
		#TODO: How the fuck do I get the biplot to show Taxon Classification instead of feature ID for the bacteria
		qiime emperor biplot \
			--i-biplot "${qzaoutput2}deicode_outputs/ordination.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}deicode_outputs/biplot.qzv" \
			--p-number-of-features $num_of_features
		
		echo -e "${GREEN}    Finished creating biplot${NC}"
		if [[ "$log" = true ]]; then
			echo -e "    Finished creating biplot..." >&3
		fi
		
		#Make a PERMANOVA comparison to see if $group explains the clustering in biplot.qzv
		mkdir "${qzaoutput2}deicode_outputs/PERMANOVAs" 2>/dev/null
		for group in "${beta_rerun_group[@]}"
		do
			echo -e "Starting ${CYAN}beta-group-significance${NC}: ${BMAGENTA}${group}${NC}"
			if [[ "$log" = true ]]; then
				echo -e "Starting ${CYAN}beta-group-significance${NC}: ${BMAGENTA}${group}${NC}" >&3
			fi
			
			if [ "$verbose" = true ]; then
				echo "group = ${BMAGENTA}${group}${NC}"
				echo "qzaoutput2 = ${BMAGENTA}${qzaoutput2}${NC}"
			fi
			
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}deicode_outputs/distance.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-method permanova \
				--o-visualization "${qzaoutput2}deicode_outputs/PERMANOVAs/${group}-permanova.qzv"
			
			echo -e "${GREEN}    Finished beta group: ${group}${NC}"
			if [[ "$log" = true ]]; then
				echo -e "${GREEN}    Finished beta group: ${group}${NC}" >&3
			fi
		done
		
		echo -e "${GREEN}    Finished DEICODE for ${repqza}${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished DEICODE for ${repqza}${NC}" >&3
		fi 
		
	done
else
	echo -e "${YELLOW}Either run_deicode is set to false, or taxonomic analyses${NC}"
	echo -e "${YELLOW}have not been completed on the dataset. Deicode analysis${NC}"
	echo -e "${YELLOW}will not proceed.${NC}"
	echo ""
fi


#<<<<<<<<<<<<<<<<<<<<END DEICODE<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>START PICRUST2>>>>>>>>>>>>>>>>>>>>>>>

#TODO: Check if picrust2 component is installed for current version. If not, exit

if [ "$run_picrust" = true ] && [ "$sklearn_done" = true ]; then
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		echo -e "Starting the picrust pipeline for: ${BMAGENTA}${qzaoutput2}${NC}"
		if [[ "$log" = true ]]; then
			echo echo -e "Starting the picrust pipeline for: ${BMAGENTA}${qzaoutput2}${NC}" >&3
		fi
		
		qiime picrust2 full-pipeline \
			--i-table "${qzaoutput2}table.qza" \
			--i-seq "${qzaoutput2}rep-seqs.qza" \
			--output-dir "${qzaoutput2}q2-picrust2_output" \
			--p-hsp-method $hsp_method \
			--p-max-nsti $max_nsti \
			--verbose
		
		echo -e "${GREEN}    Finished an execution of the picrust pipeline${NC}"
		echo -e "Starting feature table summarization of ${BMAGENTA}pathway_abundance.qza${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished an execution of the picrust pipeline${NC}" >&3
			echo -e "Starting feature table summarization of ${BMAGENTA}pathway_abundance.qza${NC}" >&3
		fi
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/pathway_abundance.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ko_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ko_metagenome.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ec_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ec_metagenome.qzv"
		
		echo -e "${GREEN}    Finished feature table summarization${NC}"
		echo -e "Starting generation of ${CYAN}core-metrics${NC} using the outputted ${BMAGENTA}pathway_abundance.qza${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished feature table summarization${NC}" >&3
			echo -e "Starting generation of ${CYAN}core-metrics${NC} using the outputted ${BMAGENTA}pathway_abundance.qza${NC}" >&3
		fi
		
		qiime diversity core-metrics \
		   --i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
		   --p-sampling-depth $sampling_depth \
		   --m-metadata-file $metadata_filepath \
		   --output-dir "${qzaoutput2}q2-picrust2_output/pathabun_core_metrics"
		
		echo -e "${GREEN}    Finished core-metrics generation${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished core-metrics generation${NC}" >&3
		fi
		
	done
	
	echo -e "${GREEN}    Finished the picrust pipeline block${NC}"
	if [[ "$log" = true ]]; then
		echo "${GREEN}    Finished the picrust pipeline block${NC}" >&3
	fi
else
	echo -e "${YELLOW}Either run_picrust is set to false, or taxonomic analyses${NC}"
	echo -e "${YELLOW}have not been completed on the dataset. Picrust2 production${NC}"
	echo -e "${YELLOW}will not proceed.${NC}"
	echo ""
fi

#<<<<<<<<<<<<<<<<<<<<END PICRUST2<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>GNEISS GRADIENT CLUSTERING>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_gneiss" = true ] && [ "$sklearn_done" = true ]; then
	
	echo "Starting Gneiss gradient-clustering analysis block..."
	if [[ "$log" = true ]]; then
		echo "Starting Gneiss gradient-clustering analysis block..." >&3
	fi
	if [[ "$verbose" = true ]]; then
		echo "gradient_column is $gradient_column"
		echo -e "metadata_filepath is ${BMAGENTA}${metadata_filepath}${NC}"
		echo "gradient_column_categorical is $gradient_column_categorical"
		echo "taxa_level is $taxa_level"
		echo "balance_name is $balance_name"
	fi
		
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}gneiss_outputs" 2> /dev/null
		
		if [ "$use_correlation_clustering" = true ]; then
			
			echo -e "Using ${CYAN}correlation-clustering${NC} for gneiss analysis"
			if [[ "$log" = true ]]; then
				echo -e "Using ${CYAN}correlation-clustering${NC} for gneiss analysis" >&3
			fi

			qiime gneiss correlation-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
			
		fi
		
		if [ "$use_gradient_clustering" = true ]; then
			
			echo -e "Using ${CYAN}gradient-clustering${NC} for gneiss analysis"
			if [[ "$log" = true ]]; then
				echo -e "Using ${CYAN}gradient-clustering${NC} for gneiss analysis" >&3
			fi

			qiime gneiss gradient-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--m-gradient-file $metadata_filepath \
				--m-gradient-column $gradient_column \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
		
		fi
		
		echo -e "${GREEN}    Finished clustering${NC}"
		echo -e "Producing balances via ${CYAN}qiime gneiss ilr-hierarchical${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished clustering${NC}" >&3
			echo -e "Producing balances via ${CYAN}qiime gneiss ilr-hierarchical${NC}" >&3
		fi
		
		qiime gneiss ilr-hierarchical \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/hierarchy.qza" \
			--o-balances "${qzaoutput2}gneiss_outputs/balances.qza"
		
		echo -e "${GREEN}    Finished balance production${NC}"
		echo -e "Producing regression via ${CYAN}qiime gneiss ols-regression${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished balance production${NC}" >&3
			echo -e "Producing regression via ${CYAN}qiime gneiss ols-regression${NC}" >&3
		fi
		
		qiime gneiss ols-regression \
			--p-formula $gradient_column \
			--i-table "${qzaoutput2}gneiss_outputs/balances.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}gneiss_outputs/regression_summary_pCG.qzv"
		
		echo -e "${GREEN}    Finished regression${NC}"
		echo -e "Producing heatmap via ${CYAN}qiime gneiss dendrogram-heatmap${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished regression${NC}" >&3
			echo -e "Producing heatmap via ${CYAN}qiime gneiss dendrogram-heatmap${NC}" >&3
		fi

		qiime gneiss dendrogram-heatmap \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--p-color-map $heatmap_type \
			--o-visualization "${qzaoutput2}gneiss_outputs/heatmap_pCG.qzv"
		
		echo -e "${GREEN}    Finished heatmap${NC}"
		echo -e "Creating gneiss output via ${CYAN}qiime gneiss balance-taxonomy${NC}"
		if [[ "$log" = true ]]; then
			echo -e "${GREEN}    Finished heatmap${NC}" >&3
			echo -e "Creating gneiss output via ${CYAN}qiime gneiss balance-taxonomy${NC}" >&3
		fi

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
	echo -e "${GREEN}    Finished Gneiss gradient-clustering analysis block${NC}"
	echo ""
	if [[ "$log" = true ]]; then
		echo -e "${GREEN}    Finished Gneiss gradient-clustering analysis block${NC}" >&3
	else
		echo -e "${YELLOW}Either run_gneiss is set to false, or taxonomic analyses"
		echo -e "${YELLOW}have not been completed on the dataset. Gneiss analysis"
		echo -e "${YELLOW}will not proceed."
		if [[ "$log" = true ]]; then
			echo -e "${YELLOW}Either run_gneiss is set to false, or taxonomic analyses" >&3
			echo -e "${YELLOW}have not been completed on the dataset. Gneiss analysis" >&3
			echo -e "${YELLOW}will not proceed." >&3
		fi
	fi
fi


#<<<<<<<<<<<<<<<<<<<<END GNEISS GRADIENT CLUSTERING<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>SORT AND OUTPUT>>>>>>>>>>>>>>>>>>>>>>>


#Add all qza and qzv files produced to two different folders inside the truncF-truncR folders
#TODO

#<<<<<<<<<<<<<<<<<<<<END SORT AND OUTPUT<<<<<<<<<<<<<<<<<<<<

echo "waterway has finished successfully"
echo ""
if [[ "$log" = true ]]; then
	echo "waterway has finished successfully" >&3
	replace_colorcodes_log ${name}.out
fi

exit 0
