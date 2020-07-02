#!/bin/bash

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