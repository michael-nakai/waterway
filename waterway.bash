#!/bin/bash
#SBATCH --job-name=waterway
#SBATCH --account=dw30
#SBATCH --time=168:00:00
#SBATCH --partition=m3a
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=4096
#SBATCH --cpus-per-task=8
#SBATCH --qos=normal

#Created by Michael Nakai, 22/01/2019 for command line Bash or SLURM on M3

export LC_ALL="en_US.utf-8"
export LANG="en_US.utf-8"

#Version number here
version="1.4.3"

#Setting very basic arguments (srcpath is located here)
exitnow=false
if [ -z "$1" ]; then
	#see if argument exists to waterway, then use that dir and find configs
	#if argument doesnt exist, use current working dir
	srcpath="./config.txt"
	analysis_path="./optional_analyses.txt"
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
rename_files=false #Currently does nothing
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
	if [ "$op" == "-f" ] || [ "$op" == "--show_functions" ] ; then
		show_functions=true
	fi
	if [ "$op" == "-c" ] || [ "$op" == "--train_classifier" ] ; then
		train_classifier=true
	fi
	if [ "$op" == "-s" ] || [ "$op" == "--single_end" ] ; then
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
	if [ "$op" == "-r" ] || [ "$op" == "--rename" ] ; then
		rename_files=true #Currently does nothing
	fi
	if [ "$op" == "-n" ] || [ "$op" == "--version" ] ; then
		echo "Currently running waterway $version"
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
	echo "pulls variables from a config file specified in Master.txt."
	echo ""
	echo "USAGE"
	echo "-------------------"
	echo "waterway.bash [path_to_dir_containing_config_here] {options}"
	echo "Note: the path_to_dir is mandatory when running options"
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
	echo -e "-h\tShow this help dialogue"
	echo ""
	exit 0
fi

#If show_functions was set, show the sequence of functions as below:
if [[ "$show_functions" = true ]] ; then
	echo ""
	echo "Functions used in this script:"
	echo ""
	echo "---Import Block---"
	echo "1a. qiime tools import (Paired end, Cassava 1.8)"
	echo "1b. qiime tools import (Paired end, from manifest with Phred33V2, only if -m is used)"
	echo ""
	echo "---Import Visualization Block---"
	echo "2. qiime demux summarize (outputs imported_seqs.qzv)"
	echo ""
	echo "---Dada2 Block---"
	echo "3. qiime dada2 denoise-paired (outputs table.qza, rep-seqs.qza, denoising-stats.qza)"
	echo "4. qiime feature-table summarize (outputs table.qzv)"
	echo "5. qiime feature-table tabulate-seqs (outputs rep-seqs.qzv)"
	echo "6. qiime metadata tabulate (outputs denoising-stats.qzv)"
	echo ""
	echo "---Tree Generation Block---"
	echo "7. qiime phylogeny align-to-tree-mafft-fasttree (outputs a masked rep-seqs and 2 tree qza files)"
	echo ""
	echo "---Phylogeny Generation Block---"
	echo "8. qiime diversity core-metrics-phylogenetic (outputs core-metrics-results folder)"
	echo "9. qiime diversity alpha-rarefaction (outputs alpha-rarefaction.qzv)"
	echo ""
	echo "---Taxonomic Assignment Block---"
	echo "10. qiime feature-classifier classify-sklearn (outputs taxonomy.qza)"
	echo "11. qiime metadata tabulate (outputs taxonomy.qzv)"
	echo "12. qiime taxa barplot (outputs taxa-bar-plots.qzv)"
	echo ""
	echo "For more detail, visit: http://marqueslab.erc.monash.edu/home/michael/waterway_docs/QYyBgctVnjnFvSFij7qJrMul6/index.html"
	echo ""
	exit 0
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
	echo ""
	echo "A config file does not exist. Instead, a template config file will"
	echo "be created where the script is located. Take note and preserve the" 
	echo "last slashes (/) ONLY IF they are present in the example."
	
	touch config.txt
	echo -e "#Filepaths here" >> config.txt
	echo -e "projpath=/home/username/folder with raw-data, metadata, and outputs folders/" >> config.txt
	echo -e "filepath=/home/username/folder with raw-data, metadata, and outputs folders/raw-data" >> config.txt
	echo -e "qzaoutput=/home/username/folder with raw-data, metadata, and outputs folders/outputs/" >> config.txt
	echo -e "metadata_filepath=/home/username/folder with raw-data, metadata, and outputs folders/metadata/metadata.tsv\n" >> config.txt
	echo -e "#If using a manifest file, use the manifest filepath here" >> config.txt
	echo -e "manifest=/home/username/folder with raw-data, metadata, and outputs folders/raw-data/manifest.tsv" >> config.txt
	echo -e "manifest_format=PairedEndFastqManifestPhred33V2\n" >> config.txt
	echo -e "#Choose how much to trim/trunc here. All combinations of trim/trunc will be done (Dada2)" >> config.txt
	echo -e "trimF=0" >> config.txt
	echo -e "trimR=0" >> config.txt
	echo -e "truncF=() #Trunc combinations here. Ex: (250 240 230)" >> config.txt
	echo -e "truncR=() #Trunc combinations here. Ex: (200 215 180)\n" >> config.txt
	echo -e "#Determine your sampling depth for core-metrics-phylogenetic here. You do not want to exclude too many samples" >> config.txt
	echo -e "sampling_depth=0\n" >> config.txt
	echo -e "#Determine your max depth for the alpha rarefaction here." >> config.txt
	echo -e "alpha_depth=0\n" >> config.txt
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
	echo -e "max_read_length=400\n\n" >> config.txt
	echo -e "#Do not change this" >> config.txt
	echo -e 'demuxpairedendpath=${qzaoutput}imported_seqs.qza' >> config.txt
fi

if [ ! -f $analysis_path ]; then
	exitnow=true
	echo ""
	echo "An optional_analyses file was not found, and will be created now. Please do not"
	echo "touch this file if this is the first time analysing your data set."
	echo ""
	
	touch optional_analyses.txt
	
	echo -e "#Phyloseq and alpha rarefaction" >> optional_analyses.txt
	echo -e "rerun_phylo_and_alpha=false\n" >> optional_analyses.txt
	echo -e "#Beta analysis" >> optional_analyses.txt
	echo -e "rerun_beta_analysis=false" >> optional_analyses.txt
	echo -e "rerun_group=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	echo -e "#Ancom analysis" >> optional_analyses.txt
	echo -e "run_ancom=false" >> optional_analyses.txt
	echo -e "collapse_taxa_to_level=6" >> optional_analyses.txt
	echo -e "group_to_compare=('Group1' 'Group2' 'etc...')" >> optional_analyses.txt
	echo -e "run_ancom_composition=false\n" >> optional_analyses.txt
	echo -e "#PCoA Biplot Analysis" >> optional_analyses.txt
	echo -e "run_biplot=false" >> optional_analyses.txt
	echo -e "number_of_dimensions=20\n" >> optional_analyses.txt
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

source $srcpath 2> /dev/null
source $analysis_path 2> /dev/null


#>>>>>>>>>>>>>>>>>>>>START MANIFEST BLOCK>>>>>>>>>>>>>>>>>>>>
#if -M was set, source config.txt and make a manifest file
if [[ "$make_manifest" = true ]] ; then
	filepath2=`ls ${filepath}/*.gz`
	export filepath
	export scriptdir
	export projpath
	export filepath2
	python - <<END
import os
data = os.environ['filepath2']
rawpath = os.environ['filepath']
scriptdir = os.environ['scriptdir']
data = data.rstrip()
data = data.split("\n")

newdata = []
IDlist = []

#Create a list of the full filenames
for element in data:
	a = element.rfind("/")
	newdata.append(element[a+1:])

#Create a list of only IDs (only take the string until the first "_")
for element in newdata:
	a = element.find("_")
	IDlist.append(element[0:a])

#Remove duplicate IDs from IDlist
IDlist = list(dict.fromkeys(IDlist))

#Make the tsv. The for loop makes the individual rows for each ID
with open("{0}/manifest.tsv".format(scriptdir), "w") as file:
	file.write("#SampleID\tforward-absolute-filepath\treverse-absolute-filepath")
	i = 0
	for element in IDlist:
		a = element
		b = "{0}/{1}".format(rawpath, newdata[i])
		i += 1
		c = "{0}/{1}".format(rawpath, newdata[i])
		i += 1
		file.write("\n{0}\t{1}\t{2}".format(a, b, c))
		
print("Ran without errors")
END
	exit 0
fi

#<<<<<<<<<<<<<<<<<<<<END MANIFEST BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<

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

#>>>>>>>>>>>>>>>>>>>>START RENAME BLOCK>>>>>>>>>>>>>>>>>>>>
# TODO: Put rename.bash into waterway, and have waterway generate gform.txt when first run.
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
	echo "Previously completed: Import step"
fi

#Testing to see if the import visualization is done
if test -f "${qzaoutput}imported_seqs.qzv"; then
	importvis_done=true
	echo "Previously completed: Import visualization step"
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
		echo "Previously completed: Dada2"
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
		echo "Previously completed: Rooted tree"
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
		echo "Previously completed: Alpha rarefaction"
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
		echo "Previously completed: Sklearn step"
	fi
fi

#<<<<<<<<<<<<<<<<<<<<END TESTING BLOCK<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>VERBOSE/TEST VARIABLES>>>>>>>>>>>>>>>>

echo ""

#Find if tst or verbose is true, and run the codeblock if true
if [ "$tst" = true ] || [ "$verbose" = true ]; then
	echo "manifest_status is $manifest_status"
	if [[ "$manifest_status" = true ]]; then
		echo "manifest is $manifest"
	fi
	echo "train_classifier is $train_classifier"
	echo "download greengenes is $download_greengenes_files_for_me"
	echo ""
	echo "import_done is $import_done"
	echo "importvis_done is $importvis_done"
	echo "dada2_done is $dada2_done"
	echo "tree_done is $tree_done"
	echo "divanalysis_done is $divanalysis_done"
	echo "sklearn_done is $sklearn_done"
	echo ""
	
	if [[ "$log" = true ]]; then
		echo "manifest_status is $manifest_status" >&3
		if [[ "$manifest_status" = true ]]; then
			echo "manifest is $manifest" >&3
		fi
		echo "train_classifier is $train_classifier" >&3
		echo "download greengenes is $download_greengenes_files_for_me" >&3
		echo "" >&3
		echo "import_done is $import_done" >&3
		echo "importvis_done is $importvis_done" >&3
		echo "dada2_done is $dada2_done" >&3
		echo "tree_done is $tree_done" >&3
		echo "divanalysis_done is $divanalysis_done" >&3
		echo "sklearn_done is $sklearn_done" >&3
		echo "" >&3
	fi
	
	#If -t was set, exit here
	if [[ "$tst" = true ]]; then
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
			
		echo "Finished core-metrics-phylogenetic for ${qzaoutput2}"
		if [[ "$log" = true ]]; then
			echo "Finished core-metrics-phylogenetic for ${qzaoutput2}" >&3
		fi

		if [[ "$verbose" = true ]]; then
			echo "Starting alpha-group-significance and alpha-rarefaction"
		fi

		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}rerun_alpha/core-metrics-results/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}rerun_alpha/core-metrics-results/faith-pd-group-significance.qzv"

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}rerun_alpha/table.qza" \
			--i-phylogeny "${qzaoutput2}rerun_alpha/rooted-tree.qza" \
			--p-max-depth $alpha_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}rerun_alpha/alpha-rarefaction.qzv"
		
		if [[ "$verbose" = true ]]; then
			echo "Finished alpha rarefaction and group significance"
		fi
	done
	exit 0
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
			
			echo "Starting beta diversity analysis for ${group}"
			
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
			
			echo "Finished beta diversity analysis for $group"
		done
	done
	exit 0
fi

#<<<<<<<<<<<<<<<<<<<<END RERUN BLOCK<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>TRAINING CLASSIFIER BLOCK>>>>>>>>>>>>>>>>>>>>>>>

if [ "$train_classifier" = true ]; then

	echo ""
	echo "Starting classifier training on greengenes database..."
	if [[ "$log" = true ]]; then
		echo "Starting classifier training on greengenes database..." >&3
	fi
	
	#Check to see whether variables have been inputted or changed from defaults
	if [ "${forward_primer}" = "GGGGGGGGGGGGGGGGGG" ] || [ "${reverse_primer}" = "AAAAAAAAAAAAAAAAAA" ]; then 
		echo "Forward or reverse primer not set, exiting..."
		exit 8
	fi
	
	if [ ${min_read_length} -eq "100" ] || [ ${max_read_length} -eq "400" ]; then
		echo ""
		echo "WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT"
		if [[ "$log" = true ]]; then
			echo ""
			echo "WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT" >&3
		fi
	fi

	#Check to see if the greengenes files are downloaded at greengenes_path
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -d "${greengenes_path%?}" ]; then
		echo "greengenes_path does not refer to a directory and download_greengenes_files_for_me is false"
		echo "Please either fix the greengenes_path in the config file, or set"
		echo "download_greengenes_files_for_me to true"
		if [[ "$log" = true ]]; then
			echo "greengenes_path does not refer to a directory and download_greengenes_files_for_me is false" >&3
			echo "Please either fix the greengenes_path in the config file, or set" >&3
			echo "download_greengenes_files_for_me to true" >&3
		fi
		exit 120
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5.fasta.gz" ]; then
		echo "You are missing gg_13_5.fasta.gz"
		echo "Please download these first, set download_greengenes_files_for_me to true in the config,"
		echo "or rename your files to these names if already downloaded."
		if [[ "$log" = true ]]; then
			echo "You are missing gg_13_5.fasta.gz" >&3
			echo "Please download these first, set download_greengenes_files_for_me to true in the config," >&3
			echo "or rename your files to these names if already downloaded." >&3
		fi
		exit 121
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		echo "You are missing either gg_13_5_taxonomy.txt.gz"
		echo "Please download these first, set download_greengenes_files_for_me to true in the config,"
		echo "or rename your files to these names if already downloaded."
		if [[ "$log" = true ]]; then
			echo "You are missing gg_13_5_taxonomy.txt.gz" >&3
			echo "Please download these first, set download_greengenes_files_for_me to true in the config," >&3
			echo "or rename your files to these names if already downloaded." >&3
		fi
		exit 122
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
		echo "usepath = $usepath"
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
				echo "decompressing gg_13_5.fastq.gz..."
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
				echo "decompressing gg_13_5.fastq.gz..."
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
		echo "ggfasta is $ggfasta"
		echo "ggtaxonomy is $ggtaxonomy"
	fi
	
	if [ "$ggfasta" == "" ] || [ "$ggtaxonomy" == "" ]; then
		echo "There was a problem with setting the fasta/taxonomy path. Please report this bug."
		exit 199
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
		echo "qzaflag=${qzaflag}, lateflag=${lateflag}"
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
		
		echo "Importing ggtax..."
		if [[ "$log" = true ]]; then
			echo "Importing ggtax..." >&3
		fi
		qiime tools import \
			--type 'FeatureData[Taxonomy]' \
			--input-format HeaderlessTSVTaxonomyFormat \
			--input-path $ggtaxonomy \
			--output-path "ref-taxonomy.qza"
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
		
		echo "Finished training the classifier as classifier.qza"
		if [[ "$log" = true ]]; then
			echo "Finished training the classifier as classifier.qza" >&3
		fi
	else
		echo "The classifier already exists as classifier.qza"
		echo "Please rename the current classifier file if you want a new"
		echo "classifier to be made"
	fi
	
	sed -i '/classifierpath=/c\classifierpath='"${scriptdir}/classifier.qza" "$srcpath"
	if [ -d "${greengenes_path%?}" ]; then
		mv classifier.qza "${greengenes_path}classifier.qza"
		sed -i '/classifierpath=/c\classifierpath='"${greengenes_path}classifier.qza" "$srcpath"
	fi
	
	echo "Changed the classifier path in the config file"
	if [[ "$log" = true ]]; then
		echo "Changed the classifier path in the config file" >&3
	fi
	
	echo "Classifier block has finished"
	
	exit 0
	
fi

#<<<<<<<<<<<<<<<<<<<<END TRAINING CLASSIFIER BLOCK<<<<<<<<<<<<<<<<<<<<


#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#---------------------------------------------Main--------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################

files_created=()

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
	if [ "$manifest_status" = false ]; then
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $filepath \
			--input-format CasavaOneEightSingleLanePerSampleDirFmt \
			--output-path ${qzaoutput}imported_seqs.qza
			
		if [[ "$verbose" = true ]]; then
			echo "Finished importing from $filepath"
			if [[ "$log" = true ]]; then
				echo "Finished importing from $filepath" >&3
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
			echo "Finished importing from $manifest"
			if [[ "$log" = true ]]; then
				echo "Finished importing from $manifest" >&3
			fi
		fi
	fi
fi

if [ "$import_done" = false ]; then
	echo "Finished importing to qza"
	if [[ "$log" = true ]]; then
		echo "Finished importing to qza" >&3
	fi
fi

#This will output a sequence quality visualization based on 10,000 randomly selected reads
if [ "$importvis_done" = false ]; then
	qiime demux summarize \
		--i-data ${qzaoutput}imported_seqs.qza \
		--o-visualization ${qzaoutput}imported_seqs.qzv
	
	if [[ "$verbose" = true ]]; then
		echo "Finished summarization of ${qzaoutput}imported_seqs.qza"
		if [[ "$log" = true ]]; then
			echo "Finished summarization of ${qzaoutput}imported_seqs.qza" >&3
		fi
	fi
fi

if [ "$importvis_done" = false ]; then
	echo "Finished summarizing imported data to qzv"
	if [[ "$log" = true ]]; then
		echo "Finished summarizing imported data to qzv" >&3
	fi

	echo "Finished import block"
	if [[ "$log" = true ]]; then
		echo "Finished import block" >&3
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
		echo "Forward read truncation not set, exiting..."
		exit 1
	fi
	if [ ${#truncR[@]} -eq 0 ]; then
		echo "Backwards read truncation not set, exiting..."
		exit 2
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
			qiime dada2 denoise-paired \
				--i-demultiplexed-seqs $demuxpairedendpath \
				--p-trim-left-f $trimR \
				--p-trim-left-r $trimF \
				--p-trunc-len-f $element \
				--p-trunc-len-r $element2 \
				--o-table "${qzaoutput}${element}-${element2}/table.qza" \
				--o-representative-sequences "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-denoising-stats "${qzaoutput}${element}-${element2}/denoising-stats.qza"
			
			echo "Dada2 of ${element}-${element2} done, progressing to summarization"
			if [[ "$log" = true ]]; then
				echo "Dada2 of ${element}-${element2} done, progressing to summarization" >&3
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
				
				echo "No output for ${element}-${element2}"
				if [[ "$log" = true ]]; then
					echo "No output for ${element}-${element2}" >&3
				fi
			fi
			
			echo "Summarization of ${element}-${element2} done"
			if [[ "$log" = true ]]; then
				echo "Summarization of ${element}-${element2} done" >&3
			fi
		done
	done
fi

if [ "$dada2_done" = false ]; then
	echo "Dada2 block done"
	if [[ "$log" = true ]]; then
		echo "Dada2 block done" >&3
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
	echo "Finished trees, starting core-metrics-phylogenetic"
	if [[ "$log" = true ]]; then
		echo "Finished trees, starting core-metrics-phylogenetic" >&3
	fi
fi

if [ "$divanalysis_done" = false ]; then

	#Break here if sampling_depth or alpha_depth are 0
	if [ $sampling_depth -eq 0 ] ; then
		echo "Sampling depth not set"
		exit 3
	fi
	if [ $alpha_depth -eq 0 ] ; then
		echo "Alpha depth not set"
		exit 4
	fi

	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echo "Starting core-metrics output"
		
		#Passing the rooted-tree.qza generated through core-metrics-phylogenetic
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}core-metrics-results"
			
		echo "Finished core-metrics-phylogenetic for ${qzaoutput2}"
		if [[ "$log" = true ]]; then
			echo "Finished core-metrics-phylogenetic for ${qzaoutput2}" >&3
		fi

		if [[ "$verbose" = true ]]; then
			echo "Starting alpha-group-significance and alpha-rarefaction"
		fi

		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}core-metrics-results/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}core-metrics-results/faith-pd-group-significance.qzv"

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}table.qza" \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--p-max-depth $alpha_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}alpha-rarefaction.qzv"
		
		if [[ "$verbose" = true ]]; then
			echo "Finished alpha-group-significance and alpha-rarefaction"
		fi
		
		echo "Starting beta diversity analysis"
		
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
		
		if [[ "$verbose" = true ]]; then
			echo "Finished beta diversity analysis"
		fi

		echo "Finished diversity analysis for ${qzaoutput2}"
		if [[ "$log" = true ]]; then
			echo "Finished diversity analysis for ${qzaoutput2}" >&3
		fi
	done
fi

if [ "$tree_done" = false ]; then
	echo "Finished diversity block"
	if [[ "$log" = true ]]; then
		echo "Finished diversity block" >&3
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
	echo "File does not exist at the classifier path"
	echo "Please change classifier path in the config file (.txt file)"
	exit 12
fi

if [ "$sklearn_done" = false ]; then
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}

		#Sklearn here
		qiime feature-classifier classify-sklearn \
			--i-classifier $classifierpath \
			--i-reads "${qzaoutput2}rep-seqs.qza" \
			--o-classification "${qzaoutput2}taxonomy.qza"
			
		echo "Finished classify-sklearn for $repqza"
		if [[ "$log" = true ]]; then
			echo "Finished classify-sklearn for $repqza" >&3
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
			
		echo "Finished metadata_tabulate and taxa_barplot for $repqza"
		if [[ "$log" = true ]]; then
			echo "Finished metadata_tabulate and taxa_barplot for $repqza" >&3
		fi
	done
	echo "Finished taxonomic analysis block"
	echo ""
	if [[ "$log" = true ]]; then
		echo "Finished taxonomic analysis block" >&3
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

if [[ ( "$run_ancom" = true && "$sklearn_done" = true ) || ( "$run_ancom_composition" = true && "$sklearn_done" = true ) ]] ; then
	
	echo ""
	echo "Starting ANCOM analysis..."
	
	for group in "${group_to_compare[@]}"
	do
		
		for repqza in ${qzaoutput}*/rep-seqs.qza
		do
			
			if [ "$run_ancom_composition" = true ]; then
			
				echo "Starting composition rerun for $group"
			
				#Defining qzaoutput2
				qzaoutput2=${repqza%"rep-seqs.qza"}
				
				mkdir "${qzaoutput2}ancom_outputs" 2> /dev/null
				mkdir "${qzaoutput2}ancom_outputs/${group}" 2> /dev/null
				
				echo "Feature table filtering starting for $group"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}table.qza" \
					--p-min-samples 2 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/temp.qza"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}ancom_outputs/${group}/temp.qza" \
					--p-min-frequency 10 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/filtered_table.qza"
					
				rm "${qzaoutput2}ancom_outputs/${group}/temp.qza" 2> /dev/null
					
				echo "Feature table filtering finished"
				echo "Taxa collapsing starting..."
			
				qiime taxa collapse \
					--i-table "${qzaoutput2}ancom_outputs/${group}/filtered_table.qza" \
					--i-taxonomy "${qzaoutput2}taxonomy.qza" \
					--p-level $collapse_taxa_to_level \
					--o-collapsed-table "${qzaoutput2}ancom_outputs/${group}/genus.qza"
				
				echo "Finished taxa collapsing"
				echo "Starting pseudocount adding"
				
				qiime composition add-pseudocount \
					--i-table "${qzaoutput2}ancom_outputs/${group}/genus.qza" \
					--o-composition-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo.qza"
				
				echo "Finished pseudocount adding"
			fi
			
			echo "Starting ancom composition"
			
			qiime composition ancom \
				--i-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group_to_compare \
				--o-visualization "${qzaoutput2}ancom_outputs/${group}/ancom_group.qzv"
		
			echo "Finished ancom composition and the ancom block for $group"
		done
	done

else
	echo "Either run_ancom is set to false, or taxonomic analyses"
	echo "have not been completed on the dataset. Ancom analysis"
	echo "will not proceed."

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
		
		echo "Creating rarefied table..."
		
		qiime feature-table rarefy \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--o-rarefied-table "${qzaoutput2}biplot_outputs/rarefied_table.qza"
		
		qiime diversity beta \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--p-metric braycurtis \
			--o-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza"
		
		qiime diversity pcoa \
			--i-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza" \
			--p-number-of-dimensions $number_of_dimensions \
			--o-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza"
		
		echo "Finished rarefied table"
		echo "Starting relative frequency table generation..."
		
		qiime feature-table relative-frequency \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--o-relative-frequency-table "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza"
			
		echo "Finished relative frequency table generation"
		echo "Making the biplot for unweighted UniFrac..."
		
		qiime diversity pcoa-biplot \
			--i-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza" \
			--i-features "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza" \
			--o-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza"
			
		echo "Finished biplot generation"
		echo "Producing an emperor plot..."
		
		qiime emperor biplot \
			--i-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}biplot_outputs/unweighted_unifrac_emperor_biplot.qzv"
			
		echo "Finished producing the emperor plot"
		echo "PCoA biplot analysis finished"
		echo ""
	done
else
	echo "Either run_biplot is set to false, or taxonomic analyses"
	echo "have not been completed on the dataset. Biplot production"
	echo "will not proceed."
	echo ""
fi


#<<<<<<<<<<<<<<<<<<<<END PCOA BIPLOT<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>GNEISS GRADIENT CLUSTERING>>>>>>>>>>>>>>>>>>>>>>>

if [ "$run_gneiss" = true ] && [ "$sklearn_done" = true ]; then
	
	echo "Starting Gneiss gradient-clustering analysis block..."
	if [[ "$log" = true ]]; then
		echo "Starting Gneiss gradient-clustering analysis block..." >&3
	fi
	if [[ "$verbose" = true ]]; then
		echo "gradient_column is $gradient_column"
		echo "metadata_filepath is $metadata_filepath"
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
			
			echo "Using correlation-clustering for gneiss analysis"

			qiime gneiss correlation-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
		
		fi
		
		if [ "$use_gradient_clustering" = true ]; then
			
			echo "Using gradient-clustering for gneiss analysis"

			qiime gneiss gradient-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--m-gradient-file $metadata_filepath \
				--m-gradient-column $gradient_column \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
		
		fi
		
		echo "Producing balances..."
		
		qiime gneiss ilr-hierarchical \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/hierarchy.qza" \
			--o-balances "${qzaoutput2}gneiss_outputs/balances.qza"
			
		echo "Producing regression..."
		
		qiime gneiss ols-regression \
			--p-formula $gradient_column \
			--i-table "${qzaoutput2}gneiss_outputs/balances.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}gneiss_outputs/regression_summary_pCG.qzv"
			
		echo "Producing heatmap..."

		qiime gneiss dendrogram-heatmap \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--p-color-map $heatmap_type \
			--o-visualization "${qzaoutput2}gneiss_outputs/heatmap_pCG.qzv"
			
		echo "Creating gneiss output..."

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
	echo "Finished Gneiss gradient-clustering analysis block"
	echo ""
	if [[ "$log" = true ]]; then
		echo "Finished Gneiss gradient-clustering analysis block" >&3
	fi
else
	echo "Either run_gneiss is set to false in optional_analyses.txt, or the taxonomic"
	echo "labelling has not been finished for your data. Gneiss analyses will not be performed."
	echo ""
fi


#<<<<<<<<<<<<<<<<<<<<END GNEISS GRADIENT CLUSTERING<<<<<<<<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>>>>>>>>>>>>>>>SORT AND OUTPUT>>>>>>>>>>>>>>>>>>>>>>>


#Add all qza and qzv files produced to two different folders inside the truncF-truncR folders
#TODO

#<<<<<<<<<<<<<<<<<<<<END SORT AND OUTPUT<<<<<<<<<<<<<<<<<<<<

echo "The script has finished successfully"
echo ""
if [[ "$log" = true ]]; then
	echo "The script has finished successfully" >&3
fi

exit 0