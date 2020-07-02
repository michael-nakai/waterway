#!/bin/bash

if [ "$divanalysis_done" = false ]; then

	#Break here if sampling_depth is 0
	if [ $sampling_depth -eq 0 ] ; then
		errorlog "${RED}Sampling depth not set${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 12
	fi

	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echolog "Starting ${CYAN}core-metrics phylogenetic${NC}"
		
		#Passing the rooted-tree.qza generated through core-metrics-phylogenetic
		qiime diversity core-metrics-phylogenetic \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--output-dir "${qzaoutput2}core-metrics-results"
			
		echolog "${GREEN}    Finished core-metrics-phylogenetic for ${qzaoutput2}${NC}"
		echolog "Starting ${CYAN}alpha-group-significance${NC} and ${CYAN}alpha-rarefaction${NC}"

		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}core-metrics-results/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}core-metrics-results/faith-pd-group-significance.qzv"

		qiime diversity alpha-rarefaction \
			--i-table "${qzaoutput2}table.qza" \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
			--p-max-depth $sampling_depth \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}alpha-rarefaction.qzv"
		
		echolog "${GREEN}    Finished alpha-group-significance and alpha-rarefaction${NC}"
		
		mkdir "${qzaoutput2}beta-rarefactions"
		
		metric_list=('unweighted_unifrac' 'weighted_unifrac')
		for thing in ${metric_list[@]}
		do
			echolog "Starting ${CYAN}beta-rarefaction${NC} type: ${BMAGENTA}${thing}${NC}"
			
			qiime diversity beta-rarefaction \
				--i-table "${qzaoutput2}table.qza" \
				--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
				--p-metric $thing \
				--p-clustering-method 'upgma' \
				--m-metadata-file $metadata_filepath \
				--p-sampling-depth $sampling_depth \
				--p-iterations 20 \
				--o-visualization "${qzaoutput2}beta-rarefactions/${thing}.qzv"
		done
		echolog "${GREEN}    Finished beta-rarefaction${NC}"
		echolog "Starting ${CYAN}beta-group-significance${NC}"
		
		qiime diversity beta-group-significance \
			--i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $beta_diversity_group \
			--o-visualization "${qzaoutput2}core-metrics-results/unweighted-unifrac-beta-significance.qzv" \
			--p-pairwise
			
		qiime diversity beta-group-significance \
			--i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $beta_diversity_group \
			--o-visualization "${qzaoutput2}core-metrics-results/weighted-unifrac-beta-significance.qzv" \
			--p-pairwise
		
		echolog "${GREEN}    Finished beta diversity analysis${NC}"
		echolog "${GREEN}    Finished diversity analysis for ${qzaoutput2}${NC}"
		
	done

	echolog "${GREEN}    Finished diversity block${NC}"
	
fi