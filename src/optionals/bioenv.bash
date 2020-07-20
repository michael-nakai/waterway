#!/bin/bash

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
else
	talkative "${YELLOW}Either bioenv is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Bioenv analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
fi