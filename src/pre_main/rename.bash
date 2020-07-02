#!/bin/bash

if [[ "$rename_files" = true ]] ; then

	# Check if patterns_to_rename.txt exists. If not, make it and exit.
	if [ ! -f $rename_path ]; then
		echo -e ""
		echo -e "A ${BMAGENTA}patterns_to_rename.txt${NC} file will be made. Please include any"
		echo -e "patterns with underscores included to search for. Any files that"
		echo -e "include these patterns will have the included underscore changed to"
		echo -e "a hyphen."
		echo -e ""
	
		touch patterns_to_rename.txt
		
		echo "pattern1_to_hyphenate_" >> patterns_to_rename.txt
		echo "pattern2_to_hyphanate_" >> patterns_to_rename.txt
		
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		
		exit 0
	fi
	
	mapfile -t gform < $rename_path
	origfold=$(pwd)
	dirWithFiles="${filepath}/"
	
	cd $dirWithFiles
	echo -e "    Finished ${CYAN}cd${NC}-ing into raw-files folder"

	for form in ${gform[@]};
	do
		echo -e "Starting $form"
		formfiles=$(find . -maxdepth 1 -name "*${form}*")
		new=${form//_/-}
		
		# Trying to shorten down the filename until only the $form is left
		# Then we replace the underscores with dashes for the $new
		# Then we can rename the file by finding the $form and replacing with the $new via rename
		for fl in ${formfiles[@]}; 
		do
			talkative "${CYAN}Renaming${NC} ${BMAGENTA}${fl}"
			rename "s/${form}*/${new}/" $fl
		done
		echo ""
	done

	echolog "Going back to ${BMAGENTA}$origfold${NC}"
	cd $origfold
	echolog "${GREEN}Renaming done${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi