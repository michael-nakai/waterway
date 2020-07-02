#!/bin/bash

if [[ "$filter" = true ]] ; then
	
	metadata_to_filter="${projpath}filter_inputs"
	
	# Check if the metadata to filter folder was made yet
	if [ ! -d "${metadata_to_filter}" ]; then
	
		mkdir $metadata_to_filter
		
		echo -e ""
		echo -e "The folder ${BMAGENTA}filter_inputs${NC} was created in your project"
		echo -e "directory. Please put your filtered metadata files in that folder, then"
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
		mkdir "${qzaoutput2}tables" 2> /dev/null
		mkdir "${qzaoutput2}rep-seqs" 2> /dev/null
		
		for file in ${metadata_to_filter}/*
		do
			
			xbase=${file##*/}
			xpref=${xbase%.*}
			
			echolog "Starting ${CYAN}feature-table filter-samples${NC} for ${BMAGENTA}${file}${NC}"
			
			qiime feature-table filter-samples \
				--i-table $input \
				--m-metadata-file $file \
				--o-filtered-table "${qzaoutput2}tables/${xpref}-table.qza"
			
			qiime feature-table filter-seqs \
				--i-data $repinput \
				--i-table "${qzaoutput2}tables/${xpref}-table.qza" \
				--o-filtered-data "${qzaoutput2}rep-seqs/${xpref}-rep-seqs.qza"
			
		done
	done
	
	echolog "${GREEN}Finished table and rep-seq filtering${NC}"

	metadata_folder=$(dirname "$metadata_filepath")
	mkdir ${metadata_folder}/subsets

	mv $metadata_to_filter/* ${metadata_folder}/subsets/
	
	exit 0
fi