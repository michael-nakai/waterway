#!/bin/bash

if [ "$run_beta_continuous" = true ]; then
	
	# Make all the folders first
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		qzaoutput2=${fl%"rep-seqs.qza"}
		mkdir "${qzaoutput2}rerun_beta_continuous" 2> /dev/null
		mkdir "${qzaoutput2}rerun_beta_continuous/outputs" 2> /dev/null
		mkdir "${qzaoutput2}rerun_beta_continuous/filtered_metadata" 2> /dev/null
		
		for group in "${continuous_group[@]}"
		do
			mkdir "${qzaoutput2}rerun_beta_continuous/${group}" 2> /dev/null
		done
	done
	
	# Initial metadata filtering here
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		qzaoutput2=${fl%"rep-seqs.qza"}
		echolog "Starting ${CYAN}metadata filtering${NC}"
		conda deactivate
		unset R_HOME
		middlepart='rerun_beta_continuous/filtered_metadata/'
		Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${rscript_path} $metadata_filepath $qzaoutput2 $missing_samples $middlepart
		conda activate $condaenv
		echolog "${GREEN}    Finished metadata filtering${NC}"
	done

	for group in "${continuous_group[@]}"
	do
		for fl in ${qzaoutput}*/rep-seqs.qza
		do
			# Defining qzaoutput2
			qzaoutput2=${fl%"rep-seqs.qza"}
			
			unweightedDistance="${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza"
			weightedDistance="${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza"
			
			talkative "group = $group"
			talkative "fl = $fl"
			talkative "qzaoutput2 = $qzaoutput2"
			
			echolog "Starting ${CYAN}qiime metadata distance-matrix${NC}"
			
			qiime metadata distance-matrix \
				--m-metadata-file "${qzaoutput2}rerun_beta_continuous/filtered_metadata/${group}-filtered.tsv" \
				--m-metadata-column $group \
				--o-distance-matrix "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza"
			
			echolog "${GREEN}    Finished qiime metadata distance-matrix${NC}"
			echolog "Starting unweighted ${CYAN}qiime diversity mantel${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime diversity mantel \
				--i-dm1 "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza" \
				--i-dm2 $unweightedDistance \
				--p-method $correlation_method \
				--p-label1 "${group}_distance_matrix" \
				--p-label2 "unweighted_unifrac_distance_matrix" \
				--p-intersect-ids \
				--o-visualization "${qzaoutput2}rerun_beta_continuous/${group}/${group}_unweighted_beta_div_cor"
			
			echolog "${GREEN}    Finished unweighted qiime diversity mantel${NC}"
			echolog "Starting weighted ${CYAN}qiime diversity mantel${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime diversity mantel \
				--i-dm1 "${qzaoutput2}rerun_beta_continuous/${group}/${group}_distance_matrix.qza" \
				--i-dm2 $weightedDistance \
				--p-method $correlation_method \
				--p-label1 "${group}_distance_matrix" \
				--p-label2 "weighted_unifrac_distance_matrix" \
				--p-intersect-ids \
				--o-visualization "${qzaoutput2}rerun_beta_continuous/${group}/${group}_weighted_beta_div_cor"
			
			echolog "${GREEN}    Finished weighted qiime diversity mantel${NC}"
			
			unout="${qzaoutput2}rerun_beta_continuous/${group}/${group}_unweighted_beta_div_cor.qzv"
			weout="${qzaoutput2}rerun_beta_continuous/${group}/${group}_weighted_beta_div_cor.qzv"
			
			cp $unout $weout "${qzaoutput2}rerun_beta_continuous/outputs/" 2> /dev/null
			
		done
	done
fi