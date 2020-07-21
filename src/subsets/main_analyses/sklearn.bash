#!/bin/bash

if [ "$subset" = true ]; then
	
	# Check whether classifier path refers to an actual file or not
	if [ ! -f $classifierpath ] ; then
		echo -e "${RED}File does not exist at the classifier path${NC}"
		echo -e "${RED}Please change classifier path in config.txt${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 14
	fi

	for repqza in ${qzaoutput}*/subsets/*/rep-seqs.qza
	do

		# Change metadata_filepath to point to the proper subset metadata file
		# We assume that one of these exist (even if they don't) to allow subsequent commands to run for other subsets which might have valid metadata files
		metadata_filepath=$orig_metadata_filepath
        if [ -f "${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).txt" ]; then
			metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).txt"
		else
			metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).tsv"
		fi
		
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		# Check if taxonomy.qza exists. If not, run the taxonomic analysis block
		if [ ! -f ${qzaoutput2}taxonomy.qza ]; then

			echolog "Starting taxonomic analysis block"
			echolog "Starting ${CYAN}classify-sklearn${NC} for ${BMAGENTA}${qzaoutput2}${NC}"
			talkative "Metadata used: ${YELLOW}${metadata_filepath}${NC}"

			# Sklearn here
			qiime feature-classifier classify-sklearn \
				--i-classifier $classifierpath \
				--i-reads "${qzaoutput2}rep-seqs.qza" \
				--o-classification "${qzaoutput2}taxonomy.qza"
				
			echolog "${GREEN}    Finished classify-sklearn ${NC}"
			echolog "Starting ${CYAN}qiime metadata tabulate${NC}"

			# Summarize and visualize
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
		
		fi
	done
	
	echolog "${GREEN}    Finished taxonomic analysis block${NC}"
	echolog ""
	
	# This is needed for optional_analyses to continue (deprecated for subset analysis)
	sklearn_done=true
	metadata_filepath=$orig_metadata_filepath
fi