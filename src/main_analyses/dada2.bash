#!/bin/bash

if [ "$dada2_done" = false ]; then
	echolog ""
	echolog "Starting Dada2 block..."

	# Break here if Dada2 options haven't been set
	if [ ${#truncF[@]} -eq 0 ]; then 
		errorlog "${RED}Forward read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 10
	fi
	if [ ${#truncR[@]} -eq 0 ]; then
		errorlog "${RED}Backwards read truncation not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 11
	fi
	
	# Make dirs for all combinations of truncF and truncR so dada2 can output in them
	for e in ${truncF[@]}
	do
		for e2 in ${truncR[@]}
		do
			mkdir "${qzaoutput}${e}-${e2}" 2> /dev/null
		done
	done

	# This will take the demux-paired-end.qza from multiplex_seq_import.bash and push it through dada2 denoise-paired
	for element in ${truncF[@]}
	do
		for element2 in ${truncR[@]}
		do
		
			echolog "Starting ${CYAN}qiime dada2 denoise-paired${NC}"
			
			qiime dada2 denoise-paired \
				--i-demultiplexed-seqs $demuxpairedendpath \
				--p-trim-left-f $trimF \
				--p-trim-left-r $trimR \
				--p-trunc-len-f $element \
				--p-trunc-len-r $element2 \
				--o-table "${qzaoutput}${element}-${element2}/table.qza" \
				--o-representative-sequences "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-denoising-stats "${qzaoutput}${element}-${element2}/denoising-stats.qza"
			
			echolog "${GREEN}Dada2 of ${element}-${element2} done, progressing to filtering${NC}"

			mv "${qzaoutput}${element}-${element2}/table.qza" "${qzaoutput}${element}-${element2}/oldtable.qza"

			qiime feature-table filter-features \
  				--i-table "${qzaoutput}${element}-${element2}/oldtable.qza" \
  				--p-min-frequency 2 \
  				--o-filtered-table "${qzaoutput}${element}-${element2}/oldtable2.qza"

			qiime feature-table filter-features \
				--i-table "${qzaoutput}${element}-${element2}/oldtable2.qza" \
				--p-min-samples 2 \
				--o-filtered-table "${qzaoutput}${element}-${element2}/table.qza"

			echolog "${GREEN}Finished removing singletons and features only seen in one sample${NC}"
			echolog "Starting ${CYAN}feature-table summarize, tabulate-seqs, and metadata tabulate${NC}"

			qiime feature-table summarize \
				--i-table "${qzaoutput}${element}-${element2}/table.qza" \
				--m-sample-metadata-file $metadata \
				--o-visualization "${qzaoutput}${element}-${element2}/table.qzv"

			qiime feature-table tabulate-seqs \
				--i-data "${qzaoutput}${element}-${element2}/rep-seqs.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/rep-seqs.qzv"

			qiime metadata tabulate \
				--m-input-file "${qzaoutput}${element}-${element2}/denoising-stats.qza" \
				--o-visualization "${qzaoutput}${element}-${element2}/denoising-stats.qzv"

			# Checks if denoising worked or whether pairing up ends failed due to low overlap
			if [ ! -f "${qzaoutput}${element}-${element2}/rep-seqs.qza" ]; then
				echo "No output" > "${qzaoutput}${element}-${element2}/NoOutput.txt"
				
				errorlog "${YELLOW}No output for ${element}-${element2}${NC}"
			fi
			
			echolog "${GREEN}Summarization of ${element}-${element2} done${NC}"
		done
	done

	echolog "${GREEN}Dada2 block done${NC}"
fi