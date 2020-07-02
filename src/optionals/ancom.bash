#!/bin/bash

if [[ "$run_ancom" = true && "$sklearn_done" = true ]] ; then
	
	echolog ""
	echolog "Starting ANCOM analysis..."
	
	# Initial metadata filtering here
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		qzaoutput2=${fl%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}ancom_outputs" 2> /dev/null
		mkdir "${qzaoutput2}ancom_outputs/all_qzvfiles" 2> /dev/null
	done
	
	for group in "${group_to_compare[@]}"
	do
		
		for repqza in ${qzaoutput}*/rep-seqs.qza
		do
			
			if [ "$make_collapsed_table" = true ]; then
			
				echolog "Starting composition rerun for ${BMAGENTA}${group}${NC}"
			
				#Defining qzaoutput2
				qzaoutput2=${repqza%"rep-seqs.qza"}
				
				mkdir "${qzaoutput2}ancom_outputs/${group}" 2> /dev/null
				
				echolog "${CYAN}feature-table filter-features${NC} starting for ${BMAGENTA}${group}${NC}"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}table.qza" \
					--p-min-samples 2 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/temp.qza"
				
				qiime feature-table filter-features \
					--i-table "${qzaoutput2}ancom_outputs/${group}/temp.qza" \
					--p-min-frequency 10 \
					--o-filtered-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza"
					
				rm "${qzaoutput2}ancom_outputs/${group}/temp.qza" 2> /dev/null
					
				echolog "${GREEN}    Finished feature table filtering${NC}"
				echolog "${CYAN}qiime taxa collapse${NC} starting"
				
				for element in "${collapse_taxa_to_level[@]}"
				do
					qiime taxa collapse \
						--i-table "${qzaoutput2}ancom_outputs/${group}/filtered_table_level_${collapse_taxa_to_level}.qza" \
						--i-taxonomy "${qzaoutput2}taxonomy.qza" \
						--p-level $element \
						--o-collapsed-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza"
					
					echolog "${GREEN}    Finished taxa collapsing to level ${element}${NC}"
					echolog "Starting ${CYAN}qiime composition add-pseudocount${NC}"
					
					qiime composition add-pseudocount \
						--i-table "${qzaoutput2}ancom_outputs/${group}/taxa_level_${collapse_taxa_to_level}.qza" \
						--o-composition-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza"
					
					echolog "${GREEN}    Finished pseudocount adding for level ${element}${NC}"
				done
			fi
			
			for element in "${collapse_taxa_to_level[@]}"
			do
				echolog "Starting ${CYAN}qiime composition ancom${NC}"
				
				qiime composition ancom \
					--i-table "${qzaoutput2}ancom_outputs/${group}/added_pseudo_level_${collapse_taxa_to_level}.qza" \
					--m-metadata-file $metadata_filepath \
					--m-metadata-column $group_to_compare \
					--o-visualization "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv"
				
				cp "${qzaoutput2}ancom_outputs/${group}/ancom_${group}_level_${collapse_taxa_to_level}.qzv" "${qzaoutput2}ancom_outputs/all_qzvfiles/"
			
				echolog "${GREEN}    Finished ancom composition and the ancom block for ${group}${NC}"
			done
		done
	done

else
	errorlog "${YELLOW}Either run_ancom is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Ancom analysis${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
fi