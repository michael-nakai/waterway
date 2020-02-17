#!/bin/bash
#SBATCH --job-name=d2_pipe
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

#Setting very basic arguments (srcpath is located here)
scriptdir=`dirname "$0"`
srcpath="${scriptdir}/config.txt"

if [ ! -f $srcpath ] ; then
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
	echo -e "#Choose how much to trim/trunc here. All combinations of trim/trunc will be done (Dada2)" >> config.txt
	echo -e "trimF=0" >> config.txt
	echo -e "trimR=0" >> config.txt
	echo -e "truncF=() #Trunc combinations here. Ex: (250 240 230)" >> config.txt
	echo -e "truncR=() #Trunc combinations here. Ex: (200 215 180)\n" >> config.txt
	echo -e "#Determine your sampling depth for core-metrics-phylogenetic here. You do not want to exclude too many samples" >> config.txt
	echo -e "sampling_depth=0\n" >> config.txt
	echo -e "#Determine your max depth for the alpha rarefaction here." >> config.txt
	echo -e "alpha_depth=0\n" >> config.txt
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
	echo -e 'demuxpairedendpath=${qzaoutput}imported_seqs.qza\n' >> config.txt
	exit 11
fi

source $srcpath


#---------------------------------------------------------------------------------------------------
#------------------------------------------Function Start-------------------------------------------
#---------------------------------------------------------------------------------------------------


#>>>>>>>>>>>>OPTIONS BLOCK>>>>>>>>>>>>>
verbose=false
log=false
tst=false
hlp=false
manifest_status=false
show_functions=false
train_classifier=false

#Let's set the option flags here
for op
do
	if [ "$op" == "-v" ] ; then
		verbose=true
	fi
	if [ "$op" == "-l" ] ; then
		log=true
	fi
	if [ "$op" == "-m" ] ; then
		manifest_status=true
	fi
	if [ "$op" == "-t" ] ; then
		tst=true
	fi
	if [ "$op" == "-h" ] || [ "$op" == "--help" ] ; then
		hlp=true
	fi
	if [ "$op" == "-f" ] ; then
		show_functions=true
	fi
	if [ "$op" == "-c" ] || [ "$op" == "--train_classifier" ] ; then
		train_classifier=true
	fi
done

#If help was set, show help and exit
if [[ "$hlp" = true ]] ; then
	echo ""
	echo "DESCRIPTION"
	echo "-------------------"
	echo "This script runs the Qiime2 pipeline (without extensive analysis)"
	echo "and outputs core-metrics-phylogenetic and taxa-bar-plots. It "
	echo "pulls variables from a config file specified in Master.txt."
	echo ""
	echo "OPTIONS"
	echo "-------------------"
	echo -e "-m\tUse manifest file to import sequences, as specified in the config file"
	echo -e "-v\tVerbose script output"
	echo -e "-t\tTest the progress flags and exit before executing any qiime commands"
	echo -e "-l\tEnable logging to a log file that is made where this script is"
	echo -e "-f\tShow the exact list of functions used in this script and their output files"
	echo -e "-t\tTrain a greengenes 13_5 99% coverage otu classifier."
	echo -e "-h\tShow this help dialogue"
	echo ""
	exit 101
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
	exit 102
fi
	
# Everything below these two codeblocks will go to a logfile
name=log_pipeline
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

#>>>>>>>>>>>>TESTING BLOCK>>>>>>>>>>>>>
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

#<<<<<<<<<<<<<END TESTING BLOCK<<<<<<<<<<<<<


#>>>>>>>>>>>>VERBOSE/TEST VARIABLES>>>>>>>>>>>>>

echo ""

#Find if tst or verbose is true, and run the codeblock if true
if [ "$tst" = true ] || [ "$verbose" = true ]; then
	echo "manifest_status is $manifest_status"
	if [[ "$manifest_status" = true ]]; then
		echo "manifest is $manifest"
	fi
	echo "train_classifier is $train_classifier"
	echo "download greengenes is $download_greengenes_files_for_me"
	echo "import_done is $import_done"
	echo "importvis_done is $importvis_done"
	echo "dada2_done is $dada2_done"
	echo "tree_done is $tree_done"
	echo "divanalysis_done is $divanalysis_done"
	echo "sklearn_done is $sklearn_done"
	
	if [[ "$log" = true ]]; then
		echo "manifest_status is $manifest_status" >&3
		if [[ "$manifest_status" = true ]]; then
			echo "manifest is $manifest" >&3
		fi
		echo "train_classifier is $train_classifier" >&3
		echo "download greengenes is $download_greengenes_files_for_me" >&3
		echo "import_done is $import_done" >&3
		echo "importvis_done is $importvis_done" >&3
		echo "dada2_done is $dada2_done" >&3
		echo "tree_done is $tree_done" >&3
		echo "divanalysis_done is $divanalysis_done" >&3
		echo "sklearn_done is $sklearn_done" >&3
	fi
	
	#If -t was set, exit here
	if [[ "$tst" = true ]]; then
		exit 100
	fi
fi

#<<<<<<<<<<<<<END VERBOSE BLOCK<<<<<<<<<<<<<


#>>>>>>>>>>>>TRAINING CLASSIFIER BLOCK>>>>>>>>>>>>>

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
		echo "NOTE: min_read_length OR max_read_length IS LEFT AT DEFAULT"
		if [[ "$log" = true ]]; then
			echo ""
			echo "NOTE: min_read_length OR max_read_length IS LEFT AT DEFAULT" >&3
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
	
	#Run the import commands
	echo "Running initial file imports..."
	if [[ "$log" = true ]]; then
		echo "Running initial file imports..." >&3
	fi
	
	qiime tools import \
		--type 'FeatureData[Sequence]' \
		--input-path $ggfasta \
		--output-path "99_otus.qza"
	
	qiime tools import \
		--type 'FeatureData[Taxonomy]' \
		--input-format HeaderlessTSVTaxonomyFormat \
		--input-path $ggtaxonomy \
		--output-path "ref-taxonomy.qza"
	
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
	
	sed -i '/classifierpath=/c\classifierpath='"${scriptdir}/classifier.qza" "$srcpath"
	if [ -d "${greengenes_path%?}" ]; then
		cp classifier.qza "${greengenes_path}classifier.qza"
		sed -i '/classifierpath=/c\classifierpath='"${greengenes_path}classifier.qza" "$srcpath"
	fi
	
	echo "Changed the classifier path in the config file"
	if [[ "$log" = true ]]; then
		echo "Changed the classifier path in the config file" >&3
	fi
	
	
	exit 60
fi

#<<<<<<<<<<<<<END TRAINING CLASSIFIER BLOCK<<<<<<<<<<<<<


#####################################################################################################
#---------------------------------------------------------------------------------------------------#
#---------------------------------------------Main--------------------------------------------------#
#---------------------------------------------------------------------------------------------------#
#####################################################################################################

#>>>>>>>>>>>>IMPORT>>>>>>>>>>>>>

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
			--input-format PairedEndFastqManifestPhred33V2 \
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

#<<<<<<<<<<<<<END IMPORT BLOCK<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>DADA2>>>>>>>>>>>>>

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
			mkdir "${qzaoutput}${e}-${e2}"
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
				--o-visualization "${qzaoutput}${element}-${element2}/table.qzv"

			qiime feature-table tabulate-seqs \
				--i-data "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/rep-seqs.qzv"

			qiime metadata tabulate \
				--m-input-file "${qzaoutput}${element}-${element2}/denoising-stats.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/denoising-stats.qzv"

			#Checks if denoising worked or whether pairing up ends failed due to low overlap
			if [ ! -f "${qzaoutput}${element}-${element2}/rep-seqs.qza" ]; then
				"No output" > "${qzaoutput}${element}-${element2}/NoOutput.txt"
				
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

#<<<<<<<<<<<<<END DADA2 BLOCK<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>DIVERSITY>>>>>>>>>>>>>

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

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}table.qza" \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--p-max-depth $alpha_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}alpha-rarefaction.qzv"
			
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

#<<<<<<<<<<<<<END DIVERSITY<<<<<<<<<<<<<
#---------------------------------------------------------------------------------------------------
#>>>>>>>>>>>>SK_LEARN>>>>>>>>>>>>>

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
fi

if [ "$sklearn_done" = false ]; then
	echo "Finished taxonomic analysis block"
	if [[ "$log" = true ]]; then
		echo "Finished taxonomic analysis block" >&3
	fi
fi

#<<<<<<<<<<<<<END SK_LEARN<<<<<<<<<<<<<

echo "Successful execution"
if [[ "$log" = true ]]; then
	echo "Successful execution" >&3
fi

exit 0