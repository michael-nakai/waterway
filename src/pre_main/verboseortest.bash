#!/bin/bash

if [ "$tst" = true ] || [ "$verbose" = true ]; then
	talkative "projpath = ${BMAGENTA}${projpath}${NC}"
	talkative "filepath = ${BMAGENTA}${filepath}${NC}"
	talkative "qzaoutput = ${BMAGENTA}${qzaoutput}${NC}"
	talkative "metadata = ${BMAGENTA}${metadata_filepath}${NC}"
	talkative ""
	talkative "manifest_status is ${BMAGENTA}$manifest_status${NC}"
	if [[ "$manifest_status" = true ]]; then
		echolog "manifest is ${BMAGENTA}${manifest}${NC}"
	fi
	talkative "train_classifier is ${BMAGENTA}${train_classifier}${NC}"
	talkative "download greengenes is ${BMAGENTA}${download_greengenes_files_for_me}${NC}"
	talkative ""
	talkative "import_done is ${BMAGENTA}${import_done}${NC}"
	talkative "importvis_done is ${BMAGENTA}${importvis_done}${NC}"
	talkative "dada2_done is ${BMAGENTA}${dada2_done}${NC}"
	talkative "tree_done is ${BMAGENTA}${tree_done}${NC}"
	talkative "divanalysis_done is ${BMAGENTA}${divanalysis_done}${NC}"
	talkative "sklearn_done is ${BMAGENTA}${sklearn_done}${NC}"
	talkative ""
	
	#If -t was set, exit here
	if [[ "$tst" = true ]]; then
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 0
	fi
fi