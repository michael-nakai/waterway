#!/bin/bash

if [ "$run_SCNIC" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		# Run SCNIC
		echolog "Running ${CYAN}SCNIC${NC}"

		# TODO: Add SCNIC analysis here
		
		echolog "${GREEN}    Finished SCNIC${NC}"
		echolog "${GREEN}    Finished SCNIC for ${qzaoutput2}${NC}"
	done
#else
	#talkative "${YELLOW}Either run_songbird is set to false, or taxonomic analyses${NC}"
	#talkative "${YELLOW}have not been completed on the dataset. Songbird analysis${NC}"
	#talkative "${YELLOW}will not proceed.${NC}"
	#talkative ""
fi