#!/bin/bash

import_done=false
importvis_done=false
dada2_done=false
tree_done=false
divanalysis_done=false
sklearn_done=false

echolog ""

# Testing to see if import is done
if test -f "${qzaoutput}imported_seqs.qza"; then
	import_done=true
	echolog "${GREEN}Previously completed: Import step${NC}"
fi

# Testing to see if the import visualization is done
if test -f "${qzaoutput}imported_seqs.qzv"; then
	importvis_done=true
	echolog "${GREEN}Previously completed: Import visualization step${NC}"
fi

# Testing to see if the Dada2 step has outputed a table or NoOutput.txt per combination
if [ "$importvis_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}table.qza"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		dada2_done=true
		echolog "${GREEN}Previously completed: Dada2${NC}"
	fi
fi

# Testing to see if the diversity analysis step has outputted the rooted tree per combination
if [ "$dada2_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}rooted-tree.qza"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		tree_done=true
		echolog "${GREEN}Previously completed: Rooted tree${NC}"
	fi
fi

# Testing to see if the diversity analysis step has outputted the alpha_rarefaction.qzv per combination
if [ "$tree_done" = true ]; then
	i=0
	filecount=0
	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}alpha-rarefaction.qzv"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		divanalysis_done=true
		echolog "${GREEN}Previously completed: Alpha rarefaction${NC}"
	fi
fi

# Testing to see if the sklearn step outputted taxa-bar-plots.qzv per folder
if [ "$divanalysis_done" = true ]; then
	i=0
	filecount=0

	for fl in ${qzaoutput}/*/
	do
		if test -f "${fl}taxa-bar-plots.qzv"; then
			let "filecount++"
		fi
		if test -f "${fl}NoOutput.txt"; then
			let "filecount++"
		fi
		let "i++"
	done

	if [ $i -eq $filecount ]; then
		sklearn_done=true
		echolog "${GREEN}Previously completed: Sklearn step${NC}"
	fi
fi