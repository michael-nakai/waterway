#!/bin/bash

# TODO: Add check to see if filter_inputs folder is here

if [[ "$make_subsets" = true ]] ; then

    metadata_to_filter="${projpath}filter_inputs"

    # Check to see whether the folder exists. If not, exit.
    if [ ! -d "${metadata_to_filter}" ]; then
	
		mkdir $metadata_to_filter
		
		echo -e ""
		echo -e "The folder ${BMAGENTA}filter_inputs${NC} was created in your project"
		echo -e "directory. Please put your filtered metadata files in that folder, then"
		echo -e "rerun this command."
		echo -e ""
	
		logger "No filter_inputs folder was found in the metadata filepath"
		logger "Created metadata/filter_inputs"
		
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		
		exit 0
	fi

    # Make the main folders needed for subsets
    for repqza in ${qzaoutput}*/rep-seqs.qza
	do
        # Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}

        # Make directories for subsets
        talkative "Making subset folders for ${BMAGENTA}$qzaoutput2${NC}"
        mkdir ${qzaoutput2}subsets

        for filterfile in ${metadata_to_filter}/*
        do
            # Make the subset subdirectories
            talkative "Making subdirectories for subset ${BMAGENTA}${filterfile}${NC}"
            mkdir "${qzaoutput2}subsets/$filterfile"
            subsetdir="${qzaoutput2}subsets/$filterfile"

            # Find the table/repseqs
            input="${qzaoutput2}table.qza"
            repinput="${qzaoutput2}rep-seqs.qza"
			
            # Filter table.qza and rep-seqs.qza for files in filter_inputs
			echolog "Starting ${CYAN}feature-table filter-samples${NC} for ${BMAGENTA}${filterfile}${NC}"

            qiime feature-table filter-samples \
				--i-table $input \
				--m-metadata-file $filterfile \
				--o-filtered-table "${subsetdir}table.qza"
            talkative "${GREEN}Deposited table${NC}"
			
			qiime feature-table filter-seqs \
				--i-data $repinput \
				--i-table "${subsetdir}table.qza" \
				--o-filtered-data "${subsetdir}rep-seqs.qza"
            
            echolog "    ${GREEN}Finished filtering for${NC}${BMAGENTA}${filterfile}${NC}"

            # Copy over all other files created during DADA2
            echolog "Copying to ${subsetdir}"
            cp denoising-stats.qz* ${subsetdir}
        done
    done
fi