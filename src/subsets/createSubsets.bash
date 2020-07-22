#!/bin/bash

if [[ "$subset" = true ]] ; then

    metadata_to_filter="${projpath}filter_inputs"

    # Check to see whether filter_inputs folder exists. If not, make it and exit.
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

    # Check to see whether any .txt or .tsv files exist in $metadata_to_filter. If not, skip the filtering step
    if [ $(ls -1q ${metadata_to_filter}/*.txt | wc -l) -gt 0 ] || [ $(ls -1q ${metadata_to_filter}/*.tsv | wc -l) -gt 0 ]; then

        # Make the main folders needed for subsets
        for repqza in ${qzaoutput}*/rep-seqs.qza
        do
            # Defining qzaoutput2
            qzaoutput2=${repqza%"rep-seqs.qza"}

            # Make directories for subsets
            talkative "Making subset folders for ${BMAGENTA}$qzaoutput2${NC}"
            mkdir ${qzaoutput2}subsets 2> /dev/null

            for fileToFilter in ${metadata_to_filter}/*
            do
                # Get the filename only
                xbase=${fileToFilter##*/}
			    filterfile=${xbase%.*}

                # Make the subset subdirectories
                talkative "Making subdirectories for subset ${BMAGENTA}${filterfile}${NC}"
                mkdir "${qzaoutput2}subsets/$filterfile" 2> /dev/null

                # Find the table/repseqs/subsetdirs
                input="${qzaoutput2}table.qza"
                repinput="${qzaoutput2}rep-seqs.qza"
                subsetdir="${qzaoutput2}subsets/$filterfile"
                
                # Filter table.qza and rep-seqs.qza for files in filter_inputs
                echolog "Starting ${CYAN}feature-table filter-samples${NC} for ${BMAGENTA}${filterfile}${NC}"

                qiime feature-table filter-samples \
                    --i-table $input \
                    --m-metadata-file $fileToFilter \
                    --o-filtered-table "${subsetdir}/table.qza"
                talkative "${GREEN}Deposited table${NC}"
                
                qiime feature-table filter-seqs \
                    --i-data $repinput \
                    --i-table "${subsetdir}/table.qza" \
                    --o-filtered-data "${subsetdir}/rep-seqs.qza"

                qiime feature-table summarize \
                    --i-table "${subsetdir}/table.qza" \
                    --m-sample-metadata-file $fileToFilter \
                    --o-visualization "${subsetdir}/table.qzv"
                
                echolog "    ${GREEN}Finished filtering for ${NC}${BMAGENTA}${filterfile}${NC}"

                # Copy over all other files created during DADA2
                echolog "Copying to ${subsetdir}"
                cp ${qzaoutput2}denoising-stats.qz* ${subsetdir} 2> /dev/null
                echolog ""
            done

            # Reset the metadata_filepath by resourcing config.txt
            source $srcpath 2> /dev/null

            # Move all files in filter_inputs to metadata/subsets
            metadata_folder=$(dirname "$metadata_filepath")
	        mkdir ${metadata_folder}/subsets 2> /dev/null
	        mv $metadata_to_filter/* ${metadata_folder}/subsets/

        done
    fi
fi
metadata_filepath=$orig_metadata_filepath