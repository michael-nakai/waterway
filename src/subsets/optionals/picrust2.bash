#!/bin/bash

#TODO: Check if picrust2 component is installed for current version. If not, exit

if [ "$run_picrust" = true ] && [ "$subset" = true ]; then
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
		echolog "Starting ${CYAN}export to tsv${NC}"

		qiime tools export \
			--input-path "${qzaoutput2}q2-picrust2_output/pathway_abundance.qza" \
			--output-path "${qzaoutput2}q2-picrust2_output/exported_tsv"

		biom convert \
			-i "${qzaoutput2}q2-picrust2_output/exported_tsv/feature-table.biom" \
			-o "${qzaoutput2}q2-picrust2_output/exported_tsv/feature-table.tsv" \
			--to-tsv

		echolog "${GREEN}    Finished exporting${NC}"
	done
	
	echolog "${GREEN}    Finished the picrust pipeline block${NC}"
	metadata_filepath=$orig_metadata_filepath
	
else
	talkative "${YELLOW}Either run_picrust is set to false, or taxonomic analyses${NC}"
	talkative "${YELLOW}have not been completed on the dataset. Picrust2 production${NC}"
	talkative "${YELLOW}will not proceed.${NC}"
	talkative ""
fi