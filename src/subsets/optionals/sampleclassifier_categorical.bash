#!/bin/bash

if [ "$run_classify_samples_categorical" = true ] && [ "$NCV" = false ] && [ "$subset" = true ]; then

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
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/categorical" 2> /dev/null
		
		for group in ${metadata_column[@]}
		do
			
			echolog "Starting ${CYAN}sample-classifier classify-samples${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier classify-samples \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-test-size $test_proportion \
				--p-cv $k_cross_validations \
				--p-random-state $random_seed \
				--p-n-estimators $number_of_trees_to_grow \
				--p-optimize-feature-selection \
				--p-parameter-tuning \
				--p-missing-samples 'ignore' \
				--output-dir "${qzaoutput2}supervised_learning_classifier/categorical/${group}"
				
			echolog "${GREEN}    Finished sample-classifier classify-samples${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime sample-classifier summarize \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/categorical/${group}/sample_estimator.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-sample_estimator_summary.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/predictions.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-predictions.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/probabilities.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-probabilities.qzv"
	
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-feature_importance.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			echolog "Starting ${CYAN}feature filtering${NC} to isolate important features"
			
			qiime feature-table filter-features \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-important_feature_table.qza"
			
			echolog "${GREEN}    Finished important feature isolating${NC}"
			echolog "Starting ${CYAN}heatmap generation${NC} to find the top ${BMAGENTA}${heatmap_num}${NC} most abundant features"
			
			qiime sample-classifier heatmap \
				--i-table "${qzaoutput2}table.qza" \
				--i-importance "${qzaoutput2}supervised_learning_classifier/categorical/${group}/feature_importance.qza" \
				--m-sample-metadata-file $metadata_filepath \
				--m-sample-metadata-column $group \
				--p-group-samples \
				--p-feature-count $heatmap_num \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/categorical/${group}/important-feature-table-top-30.qza" \
				--o-heatmap "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-important-feature-heatmap.qzv"
				
			echolog "${GREEN}    Finished heatmap generation${NC}"
			echolog "Starting ${CYAN}sample-classifier predict-classification${NC}"
				
			qiime sample-classifier predict-classification \
				--i-table "${qzaoutput2}table.qza" \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/categorical/${group}/sample_estimator.qza" \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_predictions.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_probabilities.qza"
			
			echolog "${GREEN}    Finished sample-classifier predict-classification${NC}"
			
			if [ "$retraining_samples_known_value" = true ]; then
				echolog "Starting ${CYAN}confusion matrix generation${NC}"
				
				qiime sample-classifier confusion-matrix \
					--i-predictions "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_predictions.qza" \
					--i-probabilities "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_probabilities.qza" \
					--m-truth-file $metadata_filepath \
					--m-truth-column $group \
					--o-visualization "${qzaoutput2}supervised_learning_classifier/categorical/${group}/${group}-new_confusion_matrix.qzv"
				
				echolog "${GREEN}    Finished confusion matrix generation${NC}"
			fi
			echolog "${GREEN}    Finished sample-classifier (categorical) for: ${group}${NC}"
		done
	done
	metadata_filepath=$orig_metadata_filepath
else
	talkative "${YELLOW}Either run_classify_samples_categorical is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Classifier training${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
	talkative ""
fi