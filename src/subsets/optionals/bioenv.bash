#!/bin/bash

if [ "$run_bioenv" = true ] && [ "$subset" = true ]; then
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
	metadata_filepath=$orig_metadata_filepath
else
	talkative "${YELLOW}Either bioenv is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Bioenv analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
fi