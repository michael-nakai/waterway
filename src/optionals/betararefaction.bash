#!/bin/bash

if [ "$rerun_beta_rarefaction" = true ]; then
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${fl%"rep-seqs.qza"}
		mkdir "${qzaoutput2}beta-rarefactions"
	
		for group in ${rarefaction_groups[@]}
		do
			mkdir "${qzaoutput2}beta-rarefactions/${group}"
			
			# Do the beta rarefaction here
			metric_list=('unweighted_unifrac' 'weighted_unifrac')
			for thing in ${metric_list[@]}
			do
				echolog "Starting ${CYAN}beta-rarefaction${NC} type: ${BMAGENTA}${thing}${NC} for ${BMAGENTA}${group}${NC}"
				
				qiime diversity beta-rarefaction \
					--i-table "${qzaoutput2}table.qza" \
					--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
					--p-metric $thing \
					--p-clustering-method 'upgma' \
					--m-metadata-file $metadata_filepath \
					--p-sampling-depth $sampling_depth \
					--p-iterations 20 \
					--o-visualization "${qzaoutput2}beta-rarefactions/${group}/${group}-${thing}.qzv"
			done
		done
		echolog "${GREEN}    Finished beta-rarefaction${NC}"
		echolog "Starting ${CYAN}beta-group-significance${NC}"
	done
fi