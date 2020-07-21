#!/bin/bash

if [ "$run_songbird_native" = true ] && [ "$subset" = true ]; then

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
		
		# Export the table to a biom file
		echo "Exporting table.qza to a .biom file"
		qiime tools export --input-path "${qzaoutput2}table.qza" --output-path "${qzaoutput2}exported_files"
		
		# Run Songbird
		echolog "Running ${CYAN}Songbird multinomial model building${NC}"

		songbird multinomial \
			--input-biom "${qzaoutput2}exported_files/feature-table.biom" \
			--metadata-file $songbird_metadata_filepath \
			--formula $songbird_formula \
			--epochs $songbird_epochs \
			--differential-prior $songbird_differential_prior \
			--training-column $songbird_training_col \
			--summary-interval $songbird_summary_interval \
			--summary-dir ${qzaoutput2}songbird_outputs
		
		echolog "${GREEN}    Finished model building${NC}"
		echolog "${GREEN}    Finished Songbird for ${qzaoutput2}${NC}"
	done
	metadata_filepath=$orig_metadata_filepath
else
	talkative "${YELLOW}Either run_songbird (native) is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Songbird analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
	talkative ""
fi