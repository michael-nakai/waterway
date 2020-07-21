#!/bin/bash

if [ "$subset" = true ]; then

	for fl in ${qzaoutput}*/subsets/*/table.qza
	do
		# Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}

		# Check if aligned-rep-seqs.qza has been generated. If not, run tree generation.
		if [ ! -f ${qzaoutput2}aligned-rep-seqs.qza ]; then
		
			echolog "Starting ${CYAN}align-to-tree-mafft-fasttree${NC} for subset ${BMAGENTA}$(dirname ${fl})${NC}..."
			
			# First we generate the trees for use in later diversity measurements
			qiime phylogeny align-to-tree-mafft-fasttree \
				--i-sequences "${qzaoutput2}rep-seqs.qza" \
				--o-alignment "${qzaoutput2}aligned-rep-seqs.qza" \
				--o-masked-alignment "${qzaoutput2}masked-aligned-rep-seqs.qza" \
				--o-tree "${qzaoutput2}unrooted-tree.qza" \
				--o-rooted-tree "${qzaoutput2}rooted-tree.qza"
			
			echolog "${GREEN}    Finished trees${NC}"
		
		fi
	done
fi