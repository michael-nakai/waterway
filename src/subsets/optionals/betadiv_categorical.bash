#!/bin/bash

if [ "$rerun_beta_analysis" = true ] && [ "$subset" = true ]; then

	for fl in ${qzaoutput}*/subsets/*/table.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		mkdir "${qzaoutput2}beta_div_reruns" 2> /dev/null
	done

	for group in "${rerun_group[@]}"
	do
		for fl in ${qzaoutput}*/subsets/*/table.qza
		do

			# Change metadata_filepath to point to the proper subset metadata file
			# We assume that one of these exist (even if they don't) to allow subsequent commands to run for other subsets which might have valid metadata files
			metadata_filepath=$orig_metadata_filepath
       		if [ -f "${metadata_filepath%"$metadata_basename"}subsets/$(basename ${fl%"table.qza"}).txt" ]; then
				metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${fl%"table.qza"}).txt"
			else
				metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${fl%"table.qza"}).tsv"
			fi

			#Defining qzaoutput2
			qzaoutput2=${fl%"table.qza"}
			
			talkative "group = $group"
			talkative "fl = $fl"
			talkative "qzaoutput2 = $qzaoutput2"
			
			return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1
			echo $(return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1)
			mkdir "${qzaoutput2}beta_div_reruns/rerun_${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}beta-group-significance${NC} for ${group}"
			talkative "Metadata used: ${YELLOW}${metadata_filepath}${NC}"
			
			#For unweighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/unweighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			#For weighted
			qiime diversity beta-group-significance \
				--i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--o-visualization "${qzaoutput2}beta_div_reruns/rerun_${group}/weighted-unifrac-beta-significance.qzv" \
				--p-pairwise
			
			echolog "${GREEN}    Finished beta diversity analysis for ${group}${NC}"
		done
	done
	metadata_filepath=$orig_metadata_filepath
fi