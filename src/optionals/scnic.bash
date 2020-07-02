#!/bin/bash

if [ "$run_SCNIC" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		# Run Songbird
		echolog "Running ${CYAN}SCNIC${NC}"

		# TODO: Add SCNIC analysis here
		
		echolog "${GREEN}    Finished SCNIC${NC}"
		echolog "${GREEN}    Finished SCNIC for ${qzaoutput2}${NC}"
	done
else
	errorlog "${YELLOW}Either run_songbird is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Songbird analysis${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi