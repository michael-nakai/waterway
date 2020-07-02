#!/bin/bash

# NCV for categorical data
if [ "$run_classify_samples_categorical" = true ] && [ "$NCV" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical" 2> /dev/null
		
		for group in ${metadata_column[@]}
		do
			
			mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}NCV classification${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier classify-samples-ncv \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file $metadata_filepath \
				--m-metadata-column $group \
				--p-estimator $estimator_method \
				--p-n-estimators $number_of_trees_to_grow \
				--p-random-state $random_seed \
				--p-missing-samples 'ignore' \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--o-probabilities "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--o-feature-importance "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qza"
			
			echolog "${GREEN}    Finished NCV sample classification${NC}"
			echolog "Starting ${CYAN}confusion-matrix generation${NC} to calculate classifier accuracy"
			
			qiime sample-classifier confusion-matrix \
				--i-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--i-probabilities "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--m-truth-file $metadata_filepath \
				--m-truth-column $group \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/ncv_confusion_matrix.qzv"
				
			echolog "${GREEN}    Finished confusion matrix generation${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-probabilities-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-predictions-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Categorical/${group}/${group}-importance-ncv.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
			
		done
	done
fi

# NCV for continuous data
if [ "$run_classify_samples_continuous" = true ] && [ "$NCV_continuous" = true ] && [ "$sklearn_done" = true ]; then

	# Filter the metadata files and tables first
	for fl in ${qzaoutput}*/rep-seqs.qza
	do
		# Defining qzaoutput2
		qzaoutput2=${fl%"rep-seqs.qza"}
		
		# Make the files first
		talkative "Making folders in ${qzaoutput2}supervised_learning_classifier"
		mkdir "${qzaoutput2}supervised_learning_classifier" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_metadata" 2> /dev/null
		mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_tables" 2> /dev/null
		talkative "${GREEN}    Finished making folders${NC}"
		
		# Filter the metadata
		echolog "Starting ${CYAN}metadata filtering${NC}"
		conda deactivate
		unset R_HOME
		middlepart='supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_metadata/'
		Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${rscript_path} $metadata_filepath $qzaoutput2 $missing_samples $middlepart
		conda activate $condaenv
		echolog "${GREEN}    Finished metadata filtering${NC}"
		
		# Filter the tables
		echolog "Starting ${CYAN}table filtering${NC}"
		for group in ${metadata_column_continuous[@]}
		do
			qiime feature-table filter-samples \
				--i-table "${qzaoutput2}table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_metadata/${group}-filtered.tsv" \
				--o-filtered-table "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_tables/${group}-filtered-table.qza"
		done
		echolog "${GREEN}    Finished table filtering${NC}"
	done

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		# Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		for group in ${metadata_column_continuous[@]}
		do
			
			mkdir "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}" 2> /dev/null
			
			echolog "Starting ${CYAN}NCV regressor classification${NC} for ${BMAGENTA}${group}${NC}"
			
			qiime sample-classifier regress-samples-ncv \
				--i-table "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_tables/${group}-filtered-table.qza" \
				--m-metadata-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_metadata/${group}-filtered.tsv" \
				--m-metadata-column $group \
				--p-estimator $estimator_method_continuous \
				--p-n-estimators $number_of_trees_to_grow_continuous \
				--p-random-state $random_seed_continuous \
				--o-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--o-feature-importance "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qza"
			
			echolog "${GREEN}    Finished regressor classification${NC}"
			echolog "Starting ${CYAN}scatterplot generation${NC} to calculate regressor accuracy"
			
			qiime sample-classifier scatterplot \
				--i-predictions "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--m-truth-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/filtered_metadata/${group}-filtered.tsv" \
				--m-truth-column $group \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-scatter.qzv"
			
			echolog "${GREEN}    Finished scatterplot generation${NC}"
			echolog "Starting ${CYAN}summarization${NC} of output files"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-predictions-ncv.qzv"
			
			qiime metadata tabulate \
				--m-input-file "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qza" \
				--o-visualization "${qzaoutput2}supervised_learning_classifier/Nested_Cross_Validation_Continuous/${group}/${group}-importance-ncv.qzv"
			
			echolog "${GREEN}    Finished summarization${NC}"
		done
	done
fi