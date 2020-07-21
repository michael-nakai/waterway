#!/bin/bash

if [ "$run_deicode" = true ] && [ "$subset" = true ]; then

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
		
		# TODO: How the fuck do I get the biplot to show Taxon Classification instead of feature ID for the bacteria
		# WORKAROUND: Manually edit the thing in any .svg label editor, like Inkscape (this sucks)
		qiime emperor biplot \
			--i-biplot "${qzaoutput2}deicode_outputs/ordination.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}deicode_outputs/biplot.qzv" \
			--p-number-of-features $num_of_features
		
		echolog "${GREEN}    Finished creating biplot${NC}"
		
		# Make a PERMANOVA comparison to see if $group explains the clustering in biplot.qzv
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
	metadata_filepath=$orig_metadata_filepath
else
	talkative "${YELLOW}Either run_deicode is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Deicode analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
	talkative ""
fi