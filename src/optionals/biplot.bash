#!/bin/bash

if [ "$run_biplot" = true ] && [ "$sklearn_done" = true ]; then

	for repqza in ${qzaoutput}*/rep-seqs.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${repqza%"rep-seqs.qza"}
			
		mkdir "${qzaoutput2}biplot_outputs" 2> /dev/null
		
		echolog "Creating rarefied table via ${CYAN}qiime feature-table rarefy${NC}"
		
		qiime feature-table rarefy \
			--i-table "${qzaoutput2}table.qza" \
			--p-sampling-depth $sampling_depth \
			--o-rarefied-table "${qzaoutput2}biplot_outputs/rarefied_table.qza"
		
		echolog "${GREEN}    Finished making rarefied table${NC}"
		echolog "Creating a braycurtis distance matrix via ${CYAN}qiime diversity beta${NC}"
		
		qiime diversity beta \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--p-metric braycurtis \
			--o-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza"
		
		echolog "${GREEN}    Finished creating a braycurtis distance matrix${NC}"
		echolog "Creating a PCoA via ${CYAN}qiime diversity pcoa${NC}"
		
		qiime diversity pcoa \
			--i-distance-matrix "${qzaoutput2}biplot_outputs/braycurtis_div.qza" \
			--p-number-of-dimensions $number_of_dimensions \
			--o-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza"
		
		echolog "${GREEN}    Finished creating a PCoA${NC}"
		echolog "Starting relative frequency table generation via ${CYAN}qiime feature-table relative-frequency${NC}"
		
		qiime feature-table relative-frequency \
			--i-table "${qzaoutput2}biplot_outputs/rarefied_table.qza" \
			--o-relative-frequency-table "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza"
			
		echolog "${GREEN}    Finished creating a relative frequency table${NC}"
		echolog "Making the biplot for unweighted UniFrac via ${CYAN}qiime diversity pcoa-biplot${NC}"
		
		qiime diversity pcoa-biplot \
			--i-pcoa "${qzaoutput2}biplot_outputs/braycurtis_pcoa.qza" \
			--i-features "${qzaoutput2}biplot_outputs/rarefied_table_relative.qza" \
			--o-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza"
		
		echolog "${GREEN}    Finished creating a biplot${NC}"
		echolog "Producing an emperor plot via ${CYAN}qiime emperor biplot${NC}"

		qiime emperor biplot \
			--i-biplot "${qzaoutput2}biplot_outputs/biplot_matrix_unweighted_unifrac.qza" \
			--m-sample-metadata-file $metadata_filepath \
			--m-feature-metadata-file "${qzaoutput2}taxonomy.qza" \
			--o-visualization "${qzaoutput2}biplot_outputs/unweighted_unifrac_emperor_biplot.qzv"
			
		echolog "${GREEN}    Finished producing the emperor plot${NC}"
		echolog "${GREEN}PCoA biplot analysis     Finished${NC}"
		echolog ""
		
	done
else
	errorlog "${YELLOW}Either run_biplot is set to false, or taxonomic analyses${NC}"
	errorlog "${YELLOW}have not been completed on the dataset. Biplot production${NC}"
	errorlog "${YELLOW}will not proceed.${NC}"
	errorlog ""
fi