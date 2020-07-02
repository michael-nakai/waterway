#!/bin/bash

if [ "$tree_done" = false ]; then
	echolog ""
	echolog "Starting diversity block..."
	
	for fl in ${qzaoutput}*/table.qza
	do
	
		#Defining qzaoutput2
		qzaoutput2=${fl%"table.qza"}
		
		echolog "Starting ${CYAN}align-to-tree-mafft-fasttree${NC}..."
		
		#First we generate the trees for use in later diversity measurements
		qiime phylogeny align-to-tree-mafft-fasttree \
			--i-sequences "${qzaoutput2}rep-seqs.qza" \
			--o-alignment "${qzaoutput2}aligned-rep-seqs.qza" \
			--o-masked-alignment "${qzaoutput2}masked-aligned-rep-seqs.qza" \
			--o-tree "${qzaoutput2}unrooted-tree.qza" \
			--o-rooted-tree "${qzaoutput2}rooted-tree.qza"
	done

	echolog "${GREEN}    Finished trees${NC}"
	
fi