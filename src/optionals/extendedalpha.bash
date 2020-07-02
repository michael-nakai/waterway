#!/bin/bash

if [ "$extended_alpha" = true ]; then
	for fl in ${qzaoutput}*/table.qza
	do
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		mkdir "${qzaoutput2}alpha_diversities" 2> /dev/null
		mkdir "${qzaoutput2}alpha_diversities/Vectors" 2> /dev/null
		mkdir "${qzaoutput2}alpha_diversities/Visualizations" 2> /dev/null
		
		nophylogroups=('ace' 'berger_parker_d' 'brillouin_d' 'chao1' 'chao1_ci' 'dominance' 'doubles' 'enspie' 'esty_ci' 'fisher_alpha' 'gini_index' 'goods_coverage' 'heip_e' 'kempton_taylor_q' 'lladser_ci' 'lladser_pe' 'margalef' 'mcintosh_d' 'mcintosh_e' 'menhinick' 'observed_otus' 'osd' 'pielou_e' 'robbins' 'shannon' 'simpson' 'simpson_e' 'singles' 'strong')
		
		for group in ${nophylogroups[@]}
		do
		
			echolog "Generating ${CYAN}alpha_diversity${NC} using method: ${BMAGENTA}${group}${NC}"
			
			qiime diversity alpha \
				--i-table "${qzaoutput2}table.qza" \
				--p-metric $group \
				--o-alpha-diversity "${qzaoutput2}alpha_diversities/Vectors/${group}_vector.qza"
				
			echolog "${CYAN}Visualizing...${NC}"
			
			qiime diversity alpha-group-significance \
				--i-alpha-diversity "${qzaoutput2}alpha_diversities/Vectors/${group}_vector.qza" \
				--m-metadata-file $metadata_filepath \
				--o-visualization "${qzaoutput2}alpha_diversities/Visualizations/${group}_significance.qzv"
			
		done
		
		echolog "Generating ${CYAN}alpha_diversity${NC} using method: faith_pd"
			
		qiime diversity alpha-phylogenetic \
			--i-table "${qzaoutput2}table.qza" \
			--i-phylogeny "${qzaoutput2}rooted-tree.qza"
			--p-metric 'faith_pd' \
			--o-alpha-diversity "${qzaoutput2}alpha_diversities/Vectors/faith_pd_vector.qza"
			
		echolog "${CYAN}Visualizing...${NC}"
		
		qiime diversity alpha-group-significance \
			--i-alpha-diversity "${qzaoutput2}alpha_diversities/Vectors/faith_pd_vector.qza" \
			--m-metadata-file $metadata_filepath \
			--o-visualization "${qzaoutput2}alpha_diversities/Visualizations/faith_pd_significance.qzv"
		
		echolog "${GREEN}    Finished extended alpha-diversity analysis{NC}"
	done
fi