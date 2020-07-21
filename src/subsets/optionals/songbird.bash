#!/bin/bash

if [ "$run_songbird" = true ] && [ "$subset" = true ]; then

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
		
		mkdir "${qzaoutput2}songbird_outputs" 2> /dev/null
		
		# Run Songbird
		echolog "Running ${CYAN}Songbird multinomial model building${NC}"

		qiime songbird multinomial \
			--i-table "${qzaoutput2}table.qza" \
			--m-metadata-file $songbird_metadata_filepath \
			--p-formula $songbird_formula \
			--p-epochs $songbird_epochs \
			--p-differential-prior $songbird_differential_prior \
			--p-training-column $songbird_training_col \
			--p-summary-interval $songbird_summary_interval \
			--o-differentials "${qzaoutput2}songbird_outputs/differentials.qza" \
			--o-regression-stats "${qzaoutput2}songbird_outputs/regression-stats.qza" \
			--o-regression-biplot "${qzaoutput2}songbird_outputs/regression-biplot.qza"
		
		echolog "${GREEN}    Finished model building${NC}"
		echolog "Creating ${CYAN}summary of model${NC}"
		
		qiime songbird summarize-single \
			--i-regression-stats "${qzaoutput2}songbird_outputs/regression-stats.qza" \
			--o-visualization "${qzaoutput2}songbird_outputs/regression-summary.qzv"
		
		echolog "${GREEN}    Finished creating biplot${NC}"
		echolog "${GREEN}    Finished Songbird for ${qzaoutput2}${NC}"
	done
	metadata_filepath=$orig_metadata_filepath
else
	talkative "${YELLOW}Either run_songbird is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Songbird analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
	talkative ""
fi