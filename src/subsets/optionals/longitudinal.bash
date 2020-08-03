#! /bin/bash

if [ "$run_longitudinal" = true ] && [ "$sklearn_done" = true ] && [ "$subsets" = true ]; then

	for repqza in ${qzaoutput}*/subsets/*/rep-seqs.qza
	do
        # Change metadata_filepath to point to the proper subset metadata file
		# We assume that one of these exist (even if they don't) to allow subsequent commands to run for other subsets which might have valid metadata files
        metadata_filepath=$orig_metadata_filepath
        if [ -f "${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).txt" ]; then
			metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).txt"
		else
			metadata_filepath="${metadata_filepath%"$metadata_basename"}subsets/$(basename ${repqza%"rep-seqs.qza"}).tsv"
		fi
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}q2_longitudinal_outputs" 2> /dev/null
        mkdir "${qzaoutput2}q2_longitudinal_outputs/all_outputs" 2> /dev/null

        # Pairwise differences and distances for each metadata group specified, using shannon alpha diversity
        for group in ${group_to_compare_longitudinal[@]}
        do

            mkdir "${qzaoutput2}q2_longitudinal_outputs/${group}" 2> /dev/null
		
            echolog "Running ${CYAN}pairwise differences${NC} using ${BMAGENTA}shannon diversity${NC}"

            qiime longitudinal pairwise-differences \
                --m-metadata-file $metadata_filepath \
                --m-metadata-file "${qzaoutput2}core-metrics-results/shannon_vector.qza" \
                --p-metric shannon \
                --p-group-column $group \
                --p-state-column $time_column \
                --p-state-1 $initial_time \
                --p-state-2 $final_time \
                --p-individual-id-column $sample_id_column_name \
                --p-replicate-handling "random" \
                --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${group}/${group}-pairwise-differences-shannon.qzv"
            
            echolog "${GREEN}Finished pairwise differences${NC}"
            echolog "Running ${CYAN}pairwise distances${NC} using ${BMAGENTA}shannon diversity${NC}"

            qiime longitudinal pairwise-distances \
                --i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
                --m-metadata-file $metadata_filepath \
                --p-group-column $group \
                --p-state-column $time_column \
                --p-state-1 $initial_time \
                --p-state-2 $final_time \
                --p-individual-id-column $sample_id_column_name \
                --p-replicate-handling "random" \
                --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${group}/${group}-unweighted-pairwise-distances-shannon.qzv"
            
            logger "Finished unweighted pairwise distances"

            qiime longitudinal pairwise-distances \
                --i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
                --m-metadata-file $metadata_filepath \
                --p-group-column $group \
                --p-state-column $time_column \
                --p-state-1 $initial_time \
                --p-state-2 $final_time \
                --p-individual-id-column $sample_id_column_name \
                --p-replicate-handling "random" \
                --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${group}/${group}-weighted-pairwise-distances-shannon.qzv"

            echolog "    ${GREEN}Finished pairwise distances for ${group}${NC}"
        done

        echolog "Running ${CYAN}linear mixed effect model generation${NC} using ${BMAGENTA}shannon diversity${NC}"

        if [ "$random_effects_groups" = '' ]; then
            qiime longitudinal linear-mixed-effects \
            --m-metadata-file $metadata_filepath \
            --m-metadata-file "${qzaoutput2}core-metrics-results/shannon_vector.qza" \
            --p-metric "shannon" \
            --p-group-columns $linear_mixed_effects_groups \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --o-visualization "${qzaoutput2}q2_longitudinal_outputs/linear-mixed-effects.qzv"

        else
            qiime longitudinal linear-mixed-effects \
                --m-metadata-file $metadata_filepath \
                --m-metadata-file "${qzaoutput2}core-metrics-results/shannon_vector.qza" \
                --p-metric "shannon" \
                --p-group-columns $linear_mixed_effects_groups \
                --p-random-effects $random_effects_groups \
                --p-state-column $time_column \
                --p-individual-id-column $sample_id_column_name \
                --o-visualization "${qzaoutput2}q2_longitudinal_outputs/linear-mixed-effects.qzv"
        fi
        
        echolog "    ${GREEN}Finished linear model generation${NC}"

        # Volatility analysis per group
        for group in ${group_to_compare_longitudinal[@]}
        do

            echolog "Running ${CYAN}volatility analysis${NC} for ${BMAGENTA}${group}${NC}"

            qiime longitudinal volatility \
                --m-metadata-file $metadata_filepath \
                --m-metadata-file "${qzaoutput2}core-metrics-results/shannon_vector.qza" \
                --p-default-metric "shannon" \
                --p-default-group-column $group \
                --p-state-column $time_column \
                --p-individual-id-column $sample_id_column_name \
                --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${group}/${group}-volatility.qzv"

            echolog "    ${GREEN}Finished volatility analysis for ${group}${NC}"
        
        done

        # First differences and distances for shannon, unweighted, and weighted.
        echolog "Running ${CYAN}first differences${NC}"

        qiime longitudinal first-differences \
            --m-metadata-file $metadata_filepath \
            --m-metadata-file "${qzaoutput2}core-metrics-results/shannon_vector.qza" \
            --p-state-column $time_column \
            --p-metric "shannon" \
            --p-individual-id-column $sample_id_column_name \
            --p-replicate-handling "random" \
            --o-first-differences "${qzaoutput2}q2_longitudinal_outputs/first-differences-shannon.qza"

        talkative "    ${GREEN}Finished generating first-differences-shannon${NC}"
        talkative "Running ${CYAN}first distances${NC} for ${BMAGENTA}unweighted unifrac${NC}"

        qiime longitudinal first-distances \
            --i-distance-matrix "${qzaoutput2}core-metrics-results/unweighted_unifrac_distance_matrix.qza" \
            --m-metadata-file $metadata_filepath \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --p-replicate-handling "random" \
            --o-first-distances "${qzaoutput2}q2_longitudinal_outputs/first-differences-unweighted.qza"

        talkative "    ${GREEN}Finished generating first-differences-unweighted${NC}"
        talkative "Running ${CYAN}first distances${NC} for ${BMAGENTA}weighted unifrac${NC}"

        qiime longitudinal first-distances \
            --i-distance-matrix "${qzaoutput2}core-metrics-results/weighted_unifrac_distance_matrix.qza" \
            --m-metadata-file $metadata_filepath \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --p-replicate-handling "random" \
            --o-first-distances "${qzaoutput2}q2_longitudinal_outputs/first-differences-weighted.qza"
        
        echolog "    ${GREEN}Finished generating first difference and distance files${NC}"
        echolog "${CYAN}Visualizing first differences and distances${NC}"

        qiime longitudinal linear-mixed-effects \
            --m-metadata-file "${qzaoutput2}q2_longitudinal_outputs/first-differences-shannon.qza" \
            --m-metadata-file $metadata_filepath \
            --p-metric "Distance" \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --o-visualization "${qzaoutput2}q2_longitudinal_outputs/first-differences-shannon.qza"

        talkative "    ${GREEN}Finished visualizing shannon LME${NC}"
        talkative "${CYAN}Visualizing unweighted unifrac LME${NC}"
        
        saveable_mixed_effects_groups="${linear_mixed_effects_groups//,/-}"
        logger "saveable_mixed_effects_groups = $saveable_mixed_effects_groups"

        qiime longitudinal linear-mixed-effects \
            --m-metadata-file "${qzaoutput2}q2_longitudinal_outputs/first-differences-unweighted.qza" \
            --m-metadata-file $metadata_filepath \
            --p-metric "Distance" \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --p-group-columns $linear_mixed_effects_groups \
            --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${saveable_mixed_effects_groups}_unweighted-first-distances-LME.qzv"
        
        talkative "    ${GREEN}Finished visualizing unweighted unifrac LME${NC}"
        talkative "${CYAN}Visualizing weighted unifrac LME${NC}"

        qiime longitudinal linear-mixed-effects \
            --m-metadata-file "${qzaoutput2}q2_longitudinal_outputs/first-differences-weighted.qza" \
            --m-metadata-file $metadata_filepath \
            --p-metric "Distance" \
            --p-state-column $time_column \
            --p-individual-id-column $sample_id_column_name \
            --p-group-columns $linear_mixed_effects_groups \
            --o-visualization "${qzaoutput2}q2_longitudinal_outputs/${saveable_mixed_effects_groups}_weighted-first-distances-LME.qzv"
        
        echolog "    ${GREEN}Finished visualizing${NC}"
        logger "Copying files to all_outputs folder"
        cp "${qzaoutput2}q2_longitudinal_outputs/*/*.qzv" "${qzaoutput2}q2_longitudinal_outputs/all_outputs/"
        logger "Copying finished"
        echolog "    ${GREEN}Finished q2-longitudinal analysis"
        echolog ""

        metadata_filepath=$orig_metadata_filepath
    done
fi