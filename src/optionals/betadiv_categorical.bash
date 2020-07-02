#!/bin/bash

if [ "$rerun_beta_analysis" = true ]; then

	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${fl%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}beta_div_reruns" 2> /dev/null
	done

	for group in "${rerun_group[@]}"
	do
		for fl in ${qzaoutput}*/rep-seqs.qza
		do
			#Defining qzaoutput2
			qzaoutput2=${fl%"rep-seqs.qza"}
			
			talkative "group = $group"
			talkative "fl = $fl"
			talkative "qzaoutput2 = $qzaoutput2"
			
			return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1
			echo $(return_unused_filename "${qzaoutput2}beta_div_reruns" rerun1)
			mkdir "${qzaoutput2}beta_div_reruns/rerun_${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}beta-group-significance${NC} for ${group}"
			
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
fi