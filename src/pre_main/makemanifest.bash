#!/bin/bash

if [[ "$make_manifest" = true ]] ; then
	# Get list of R1/R2 files
	R1_list=(${filepath}/*${Fpattern}*fastq.gz)
	R2_list=(${filepath}/*${Rpattern}*fastq.gz)
	
	talkative "R1_list = ${R1_list[@]}"
	talkative "R2_list = ${R2_list[@]}"
	
	# Write headers to manifest.tsv
	echo -e "#SampleID\tforward-absolute-filepath\treverse-absolute-filepath" > manifest.tsv

	x=0
	for fl in ${R1_list[@]}; do
		if [[ "$log" = true ]]; then
			echo "Starting $(basename $fl)"
		fi
		ID=$(basename $fl)
		ID=${ID%%_*}
		echo -e "${ID}\t${fl}\t${R2_list[x]}" >> manifest.tsv
		x=$((x+1))
	done
	
	echolog "${BMAGENTA}manifest.tsv${NC} created"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	exit 0
fi