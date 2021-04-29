#!/bin/bash

if [[ "$run_ancom" = true && "$sklearn_done" = true ]] ; then
	
	echolog ""
	echolog "Starting ANCOM analysis..."
	
	# Make the directories here
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		qzaoutput2=${fl%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}ancom_outputs" 2> /dev/null
		mkdir "${qzaoutput2}ancom_outputs/all_qzvfiles" 2> /dev/null
		mkdir "${qzaoutput2}ancom_outputs/filtered_tables" 2> /dev/null
	done
	
	# Filtering only needs to be run once on the original table
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		echolog "Starting ${CYAN}filter-table generation${NC} for ANCOM analyses"
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		qiime feature-table filter-features \
			--i-table "${qzaoutput2}table.qza" \
			--p-min-samples 2 \
			--o-filtered-table "${qzaoutput2}ancom_outputs/filtered_tables/temp.qza"
		
		qiime feature-table filter-features \
			--i-table "${qzaoutput2}ancom_outputs/filtered_tables/temp.qza" \
			--p-min-frequency 10 \
			--o-filtered-table "${qzaoutput2}ancom_outputs/filtered_tables/filtered_table.qza"
			
		rm "${qzaoutput2}ancom_outputs/filtered_tables/temp.qza" 2> /dev/null
			
		echolog "${GREEN}    Finished feature table filtering${NC}"

		# Collapsing taxa is level-specific, so needs to be looped over $collapse_taxa_to_level[@]
		# Pseudocounts need to be added to all collapsed tables, and so are included in the loop
		for element in "${collapse_taxa_to_level[@]}"
		do

			echolog "${CYAN}qiime taxa collapse${NC} starting"

			qiime taxa collapse \
				--i-table "${qzaoutput2}ancom_outputs/filtered_tables/filtered_table.qza" \
				--i-taxonomy "${qzaoutput2}taxonomy.qza" \
				--p-level $element \
				--o-collapsed-table "${qzaoutput2}ancom_outputs/filtered_tables/taxa_level_${element}.qza"
			
			echolog "${GREEN}    Finished taxa collapsing to level ${element}${NC}"
			echolog "Starting ${CYAN}qiime composition add-pseudocount${NC}"
			
			qiime composition add-pseudocount \
				--i-table "${qzaoutput2}ancom_outputs/filtered_tables/taxa_level_${element}.qza" \
				--o-composition-table "${qzaoutput2}ancom_outputs/filtered_tables/added_pseudo_level_${element}.qza"
			
			echolog "${GREEN}    Finished pseudocount adding for level ${element}${NC}"
		done

		# Run the ANCOM, per $group, per collapsed level
		# Remember, $group_to_compare is an ARRAY, while $group is a single ELEMENT of the array (I was an idiot)
		for group in "${group_to_compare[@]}"
		do
			for element in "${collapse_taxa_to_level[@]}"
			do
				echolog "Starting composition rerun for ${BMAGENTA}${group}${NC}"

				mkdir "${qzaoutput2}ancom_outputs/${group}" 2> /dev/null
			
				echolog "Starting ${CYAN}qiime composition ancom${NC}"
				
				qiime composition ancom \
					--i-table "${qzaoutput2}ancom_outputs/filtered_tables/added_pseudo_level_${element}.qza" \
					--m-metadata-file $metadata_filepath \
					--m-metadata-column $group \
					--o-visualization "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${element}.qzv"
				
				cp "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${element}.qzv" "${qzaoutput2}ancom_outputs/all_qzvfiles/"
			
				echolog "${GREEN}    Finished ancom composition and the ancom block for ${group}${NC}"
			done
		done
	done

else
	talkative "${YELLOW}Either run_ancom is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Ancom analysis${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
fi