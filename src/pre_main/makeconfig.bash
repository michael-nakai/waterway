#!/bin/bash

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
	
	echo -e "#Fill these out if creating a manifest file" >> config.txt
	echo -e "Fpattern=_R1" >> config.txt
	echo -e "Rpattern=_R2\n" >> config.txt
	
	echo -e "#Fill these out if using a manifest file" >> config.txt
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
	
	echo -e "#Input what your missing samples are marked with (if anything)" >> config.txt
	echo -e "missing_samples="
	
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