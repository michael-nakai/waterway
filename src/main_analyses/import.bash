#!/bin/bash

if [ "$import_done" = false ]; then

	echolog ""
	echolog "Starting import block..."
	
	#If no manifest file, we import via normal filepath
	if [ "$manifest_status" = false ]; then
		
		echolog "Starting ${CYAN}qiime tools import${NC}"
	
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $filepath \
			--input-format CasavaOneEightSingleLanePerSampleDirFmt \
			--output-path ${qzaoutput}imported_seqs.qza
			
		talkative "${GREEN}    Finished importing from ${filepath}${NC}"
		
	fi
	
	#If manifest was set to true, we import via the manifest path
	if [ "$manifest_status" = true ]; then
		
		echolog "Starting ${CYAN}qiime tools import${NC} using a manifest file"
		
		qiime tools import \
			--type 'SampleData[PairedEndSequencesWithQuality]' \
			--input-path $manifest \
			--input-format $manifest_format \
			--output-path ${qzaoutput}imported_seqs.qza
			
		talkative "${GREEN}    Finished importing from ${manifest}${NC}"
	fi
	
	echolog "${GREEN}    Finished importing to qza${NC}"
fi

#This will output a sequence quality visualization based on 10,000 randomly selected reads
if [ "$importvis_done" = false ]; then

	echolog "Starting ${CYAN}qiime demux summarize${NC}"

	qiime demux summarize \
		--i-data ${qzaoutput}imported_seqs.qza \
		--o-visualization ${qzaoutput}imported_seqs.qzv
	
	talkative "${GREEN}    Finished summarization of ${qzaoutput}imported_seqs.qza${NC}"

	echolog "${GREEN}    Finished summarizing imported data to qzv${NC}"
	echolog "${GREEN}    Finished import block"
	
fi