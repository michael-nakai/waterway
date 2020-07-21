#!/bin/bash

if [ "$run_SCNIC" = true ] && [ "$subset" = true ]; then

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
		
		# Run SCNIC
		echolog "Running ${CYAN}SCNIC${NC}"

		# TODO: Add SCNIC analysis here
		
		echolog "${GREEN}    Finished SCNIC${NC}"
		echolog "${GREEN}    Finished SCNIC for ${qzaoutput2}${NC}"
	done
	metadata_filepath=$orig_metadata_filepath
#else
	#talkative "${YELLOW}Either run_songbird is set to false, or taxonomic analyses${NC}"
	#talkative "${YELLOW}have not been completed on the dataset. Songbird analysis${NC}"
	#talkative "${YELLOW}will not proceed.${NC}"
	#talkative ""
fi