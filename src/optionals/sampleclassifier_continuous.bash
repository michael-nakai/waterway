#!/bin/bash

if [ "$run_classify_samples_continuous" = true ] && [ "$NCV_continuous" = false ] && [ "$sklearn_done" = true ]; then

	# Filter the metadata files first
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		# Defining qzaoutput2
		qzaoutput2=${fl%"rep-seqs.qza"}
		
		# Make the files first
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/continuous" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/continuous/filtered_metadata" 2> /dev/null
		
		# Filter the metadata
		qzaoutput2=${fl%"rep-seqs.qza"}
		echolog "Starting ${CYAN}metadata filtering${NC}"
		conda deactivate
		unset R_HOME
		middlepart='supervised_learning_classifier/continuous/filtered_metadata/'
		Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${rscript_path} $metadata_filepath $qzaoutput2 $missing_samples $middlepart
		conda activate $condaenv
		echolog "${GREEN}    Finished metadata filtering${NC}"
	done

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		for group in ${metadata_column_continuous[@]}
		do
			
			echolog "Starting ${CYAN}sample-classifier regress-samples${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier regress-samples \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/continuous/filtered_metadata/${group}-filtered.tsv" \
				--m-metadata-column $group \
				--p-test-size $test_proportion_continuous \
				--p-cv $k_cross_validations_continuous \
				--p-random-state $random_seed_continuous \
				--p-n-estimators $number_of_trees_to_grow_continuous \
				--p-missing-samples 'ignore' \
				--output-dir "${qzaoutput2}supervised_learning_classifier/continuous/${group}"
				
			echolog "${GREEN}    Finished sample-classifier regress-samples${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime sample-classifier summarize \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/continuous/${group}/sample_estimator.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-sample_estimator_summary.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/predictions.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-predictions.qzv"
	
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/feature_importance.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-feature_importance.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			echolog "Starting ${CYAN}feature filtering${NC} to isolate important features"
			
			qiime feature-table filter-features \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/continuous/${group}/feature_importance.qza" \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/continuous/${group}/important_feature_table.qza"
			
			echolog "${GREEN}    Finished important feature isolating${NC}"
			echolog "Starting ${CYAN}sample-classifier predict-classification${NC}"
				
			qiime sample-classifier predict-classification \
				--i-table "${qzaoutput2}table.qza" \
				--i-sample-estimator "${qzaoutput2}supervised_learning_classifier/continuous/${group}/sample_estimator.qza" \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_predictions.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_probabilities.qza"
			
			echolog "${GREEN}    Finished sample-classifier predict-classification${NC}"
			
			if [ "$retraining_samples_known_value_continuous" = true ]; then
				echolog "Starting ${CYAN}confusion matrix generation${NC}"
				
				qiime sample-classifier confusion-matrix \
					--i-predictions "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_predictions.qza" \
					--i-probabilities "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_probabilities.qza" \
					--m-truth-file "${qzaoutput2}supervised_learning_classifier/continuous/filtered_metadata/${group}-filtered.tsv" \
					--m-truth-column $group \
					--o-visualization "${qzaoutput2}supervised_learning_classifier/continuous/${group}/${group}-new_confusion_matrix.qzv"
				
				echolog "${GREEN}    Finished confusion matrix generation${NC}"
			fi
			echolog "${GREEN}    Finished sample-classifier (continuous) for: ${group}${NC}"
		done
	done
else
	errorlog "${YELLOW}Either run_classify_samples_continuous is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Classifier training${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi