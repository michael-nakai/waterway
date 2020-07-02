#!/bin/bash

#TODO: Check if picrust2 component is installed for current version. If not, exit

if [ "$run_picrust" = true ] && [ "$sklearn_done" = true ]; then
	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
		
		echolog "Starting the picrust pipeline for: ${BMAGENTA}${qzaoutput2}${NC}"
		
		qiime picrust2 full-pipeline \
			--i-table "${qzaoutput2}table.qza" \
			--i-seq "${qzaoutput2}rep-seqs.qza" \
			--output-dir "${qzaoutput2}q2-picrust2_output" \
			--p-hsp-method $hsp_method \
			--p-max-nsti $max_nsti \
			--verbose
		
		echolog "${GREEN}    Finished an execution of the picrust pipeline${NC}"
		echolog "Starting feature table summarization of ${BMAGENTA}pathway_abundance.qza${NC}"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/pathway_abundance.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ko_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ko_metagenome.qzv"
		
		qiime feature-table summarize \
			--i-table "${qzaoutput2}q2-picrust2_output/ec_metagenome.qza" \
			--o-visualization "${qzaoutput2}q2-picrust2_output/ec_metagenome.qzv"
		
		echolog "${GREEN}    Finished feature table summarization${NC}"
		echolog "Starting generation of ${CYAN}core-metrics${NC} using the outputted ${BMAGENTA}pathway_abundance.qza${NC}"
		
		qiime diversity core-metrics \
		   --i-table "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
		   --p-sampling-depth $sampling_depth \
		   --m-metadata-file $metadata_filepath \
		   --output-dir "${qzaoutput2}q2-picrust2_output/pathabun_core_metrics"
		
		echolog "${GREEN}    Finished core-metrics generation${NC}"
		
	done
	
	echolog "${GREEN}    Finished the picrust pipeline block${NC}"
	
else
	echolog "${YELLOW}Either run_picrust is set to false, or taxonomic analyses${NC}"
	echolog "${YELLOW}have not been completed on the dataset. Picrust2 production${NC}"
	echolog "${YELLOW}will not proceed.${NC}"
	echolog ""
fi