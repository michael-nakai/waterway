#!/bin/bash

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