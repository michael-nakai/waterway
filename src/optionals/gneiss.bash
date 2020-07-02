#!/bin/bash

if [ "$run_gneiss" = true ] && [ "$sklearn_done" = true ]; then
	
	echolog "Starting Gneiss gradient-clustering analysis block..."
	talkative "gradient_column is $gradient_column"
	talkative "metadata_filepath is ${BMAGENTA}${metadata_filepath}${NC}"
	talkative "gradient_column_categorical is $gradient_column_categorical"
	talkative "taxa_level is $taxa_level"
	talkative "balance_name is $balance_name"
		
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		mkdir "${qzaoutput2}gneiss_outputs" 2> /dev/null
		
		if [ "$use_correlation_clustering" = true ]; then
			
			echolog "Using ${CYAN}correlation-clustering${NC} for gneiss analysis"

			qiime gneiss correlation-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
			
		fi
		
		if [ "$use_gradient_clustering" = true ]; then
			
			echolog "Using ${CYAN}gradient-clustering${NC} for gneiss analysis"

			qiime gneiss gradient-clustering \
				--i-table "${qzaoutput2}table.qza" \
				--m-gradient-file $metadata_filepath \
				--m-gradient-column $gradient_column \
				--o-clustering "${qzaoutput2}gneiss_outputs/hierarchy.qza"
		
		fi
		
		echolog "${GREEN}    Finished clustering${NC}"
		echolog "Producing balances via ${CYAN}qiime gneiss ilr-hierarchical${NC}"
		
		qiime gneiss ilr-hierarchical \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/hierarchy.qza" \
			--o-balances "${qzaoutput2}gneiss_outputs/balances.qza"
		
		echolog "${GREEN}    Finished balance production${NC}"
		echolog "Producing regression via ${CYAN}qiime gneiss ols-regression${NC}"
		
		qiime gneiss ols-regression \
			--p-formula $gradient_column \
			--i-table "${qzaoutput2}gneiss_outputs/balances.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}gneiss_outputs/regression_summary_pCG.qzv"
		
		echolog "${GREEN}    Finished regression${NC}"
		echolog "Producing heatmap via ${CYAN}qiime gneiss dendrogram-heatmap${NC}"

		qiime gneiss dendrogram-heatmap \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--p-color-map $heatmap_type \
			--o-visualization "${qzaoutput2}gneiss_outputs/heatmap_pCG.qzv"
		
		echolog "${GREEN}    Finished heatmap${NC}"
		echolog "Creating gneiss output via ${CYAN}qiime gneiss balance-taxonomy${NC}"

		qiime gneiss balance-taxonomy \
			--i-table "${qzaoutput2}table.qza" \
			--i-tree "${qzaoutput2}gneiss_outputs/gradient-hierarchy.qza" \
			--i-taxonomy "${qzaoutput2}taxonomy.qza" \
			--p-taxa-level $taxa_level \
			--p-balance-name $balance_name \
			--m-metadata-file $metadata_filepath \
			--m-metadata-column $gradient_column_categorical \
			--o-visualization "${qzaoutput2}gneiss_outputs/${balance_name}_taxa_summary_${gradient_column_categorical}_level_${taxa_level}.qzv"
	done
	echolog "${GREEN}    Finished Gneiss gradient-clustering analysis block${NC}"
	echolog ""

else
	errorlog "${YELLOW}Either run_gneiss is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Gneiss analysis${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi