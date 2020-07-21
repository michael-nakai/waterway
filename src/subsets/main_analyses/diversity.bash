#!/bin/bash

if [ "$subset" = true ]; then

	# Break here if sampling_depth is 0
	if [ $sampling_depth -eq 0 ] ; then
		errorlog "${RED}Sampling depth not set${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 12
	fi

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

		talkative "Metadata used: ${BMAGENTA}$metadata_filepath${NC}"
	
		# Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		# Check if core-metrics-results folder has been created. If not, run core-metrics-phylogenetic.
		if [ ! -d ${qzaoutput2}core-metrics-results ]; then

			echolog "Starting ${CYAN}core-metrics phylogenetic${NC} for subset ${BMAGENTA}$(dirname ${fl})${NC}..."
			
			# Passing the rooted-tree.qza generated through core-metrics-phylogenetic
			qiime diversity core-metrics-phylogenetic \
				--i-phylogeny "${qzaoutput2}rooted-tree.qza" \
				--i-table "${qzaoutput2}table.qza" \
				--p-sampling-depth $sampling_depth \
				--m-metadata-file $metadata_filepath \
				--output-dir "${qzaoutput2}core-metrics-results"
				
			echolog "${GREEN}    Finished core-metrics-phylogenetic${NC}"

		fi

		# Check if faith-pd-group-significance exists. If not, then run alpha-group-significance and alpha-rarefaction.
		if [ ! -f ${qzaoutput2}core-metrics-results/faith-pd-group-significance.qzv ]; then

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
		
		fi
		
		mkdir "${qzaoutput2}beta-rarefactions" 2> /dev/null
		metric_list=('unweighted_unifrac' 'weighted_unifrac')

		# Check if beta-rarefactions folder exists. If not, run beta-rarefaction.
		if [ ! -d ${qzaoutput2}beta-rarefactions ]; then
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
		fi

		# The first pass of beta group significance is removed for subset analysis, as it's easier to force the categorical/mantel beta significance analysis in optional_analyses.txt
		
	done

	echolog "${GREEN}    Finished diversity block${NC}"
	metadata_filepath=$orig_metadata_filepath
fi