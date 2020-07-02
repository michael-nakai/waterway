#!/bin/bash

if [[ "$train_classifier" == true ]]; then
	echolog ""
	echolog "Starting classifier training on greengenes database..."
	
	#Check to see whether variables have been inputted or changed from defaults
	if [ "${forward_primer}" = "GGGGGGGGGGGGGGGGGG" ] || [ "${reverse_primer}" = "AAAAAAAAAAAAAAAAAA" ]; then 
		errorlog "${RED}Forward or reverse primer not set, exiting...${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 2
	fi
	
	if [ ${min_read_length} -eq "100" ] || [ ${max_read_length} -eq "400" ]; then
		echolog ""
		errorlog "${YELLOW}WARNING: min_read_length OR max_read_length HAS BEEN LEFT AT DEFAULT${NC}"
	fi

	#Check to see if the greengenes files are downloaded at greengenes_path
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -d "${greengenes_path%?}" ]; then
		errorlog "${RED}greengenes_path does not refer to a directory and download_greengenes_files_for_me is false${NC}"
		errorlog "${RED}Please either fix the greengenes_path in the config file, or set${NC}"
		errorlog "${RED}download_greengenes_files_for_me to true${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 20
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5.fasta.gz" ]; then
		errorlog "${RED}You are missing gg_13_5.fasta.gz${NC}"
		errorlog "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		errorlog "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 21
	fi
	
	if [ "$download_greengenes_files_for_me" = false ] && [ ! -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		errorlog "${RED}You are missing either gg_13_5_taxonomy.txt.gz${NC}"
		errorlog "${RED}Please download this first, or set download_greengenes_files_for_me to true in the config,${NC}"
		errorlog "${RED}or rename your files to these names if already downloaded.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 22
	fi

	#Figure out what exists and what doesn't. If download_greengenes_files_for_me is true, wget the files if needed.
	
	ggfastaGZ_exists=false
	ggfasta_exists=false
	ggtaxGZ_exists=false
	ggtax_exists=false
	usepath=false
	
	if [ -f "${greengenes_path}gg_13_5.fasta.gz" ] && [ -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ]; then
		usepath=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5.fasta.gz" ] || [ -f "gg_13_5.fasta.gz" ]; then
		ggfastaGZ_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5.fasta" ] || [ -f "gg_13_5.fasta" ]; then
		ggfasta_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5_taxonomy.txt.gz" ] || [ -f "gg_13_5_taxonomy.txt.gz" ]; then
		ggtaxGZ_exists=true
	fi
	
	if [ -f "${greengenes_path}gg_13_5_taxonomy.txt" ] || [ -f "gg_13_5_taxonomy.txt" ]; then
		ggtax_exists=true
	fi
	
	talkative "usepath = ${BMAGENTA}${usepath}${NC}"
	talkative "ggfastaGZ_exists = $ggfastaGZ_exists"
	talkative "ggfasta_exists = $ggfasta_exists"
	talkative "ggtaxGZ_exists = $ggtaxGZ_exists"
	talkative "ggtax_exists = $ggtax_exists"
	
	if [ "$download_greengenes_files_for_me" = true ]; then
		urllink="https://gg-sg-web.s3-us-west-2.amazonaws.com/downloads/greengenes_database/gg_13_5/gg_13_5.fasta.gz"
		if [ "$usepath" = true ]; then
			if [ "$ggfastaGZ_exists" = false ] && [ "$ggfasta_exists" = false ]; then
				wget $urllink -o "${greengenes_path}/gg_13_5.fasta.gz"
				ggfastaGZ_exists=true
			fi
			if [ "$ggfastaGZ_exists" = true ] && [ "$ggfasta_exists" = false ]; then
				echolog "Decompressing gg_13_5.fastq.gz..."
				gunzip -k "${greengenes_path}/gg_13_5.fasta.gz"
				ggfasta="${greengenes_path}/gg_13_5.fasta"
			fi
			if [ "$ggfasta_exists" = true ]; then
				ggfasta="${greengenes_path}/gg_13_5.fasta"
			fi
		else
			if [ "$ggfastaGZ_exists" = false ] && [ "$ggfasta_exists" = false ]; then
				wget $urllink
				ggfastaGZ_exists=true
			fi
			if [ "$ggfastaGZ_exists" = true ] && [ "$ggfasta_exists" = false ]; then
				echolog "Decompressing gg_13_5.fastq.gz..."
				gunzip -k "${scriptdir}/gg_13_5.fasta.gz"
				ggfasta="${scriptdir}/gg_13_5.fasta"
			fi
			if [ "$ggfasta_exists" = true ]; then
				ggfasta="${scriptdir}/gg_13_5.fasta"
			fi
		fi
	fi
	
	if [ "$download_greengenes_files_for_me" = true ]; then
		urllink="https://gg-sg-web.s3-us-west-2.amazonaws.com/downloads/greengenes_database/gg_13_5/gg_13_5_taxonomy.txt.gz"
		if [ "$usepath" = true ]; then
			if [ "$ggtaxGZ_exists" = false ] && [ "$ggtax_exists" = false ]; then
				wget $urllink -o "${greengenes_path}/gg_13_5_taxonomy.txt.gz"
				ggtaxGZ_exists=true
			fi
			if [ "$ggtaxGZ_exists" = true ] && [ "$ggtax_exists" = false ]; then
				echolog "decompressing gg_13_5_taxonomy.txt.gz..."
				gunzip -k "${greengenes_path}/gg_13_5_taxonomy.txt.gz"
				ggtaxonomy="${greengenes_path}/gg_13_5_taxonomy.txt"
			fi
			if [ "$ggtax_exists" = true ]; then
				ggtaxonomy="${greengenes_path}/gg_13_5_taxonomy.txt"
			fi
		else
			if [ "$ggtaxGZ_exists" = false ] && [ "$ggtax_exists" = false ]; then
				wget $urllink
				ggtaxGZ_exists=true
			fi
			if [ "$ggtaxGZ_exists" = true ] && [ "$ggtax_exists" = false ]; then
				echolog "decompressing gg_13_5_taxonomy.txt.gz..."
				gunzip -k "${scriptdir}/gg_13_5_taxonomy.txt.gz"
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
			if [ "$ggtax_exists" = true ]; then
				ggtaxonomy="${scriptdir}/gg_13_5_taxonomy.txt"
			fi
		fi
	fi
	
	talkative "ggfasta is ${BMAGENTA}${ggfasta}${NC}"
	talkative "ggtaxonomy is ${BMAGENTA}${ggtaxonomy}${NC}"
	
	if [ "$ggfasta" == "" ] || [ "$ggtaxonomy" == "" ]; then
		errorlog -e "${RED}There was a problem with setting the fasta/taxonomy path. Please report this bug.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 150
	fi
	
	qzaflag=false
	lateflag=false
	if [[ ! -f "extracted-reads.qza" || ! -f "classifier.qza" ]] ; then
		lateflag=true
	fi
	if [[ ! -f "99_otus.qza" || ! -f "ref-taxonomy.qza" ]] ; then
		qzaflag=true
	fi
	
	talkative "qzaflag=${BMAGENTA}${qzaflag}${NC}"
	talkative "lateflag=${BMAGENTA}${lateflag}${NC}"
	
	if [[ "$lateflag" = true && "$qzaflag" = true ]] ; then
		#Run the import commands
		echolog ""
		echolog "Running initial file imports..."
		echolog "Importing ggfasta..."

		qiime tools import \
			--type 'FeatureData[Sequence]' \
			--input-path $ggfasta \
			--output-path "99_otus.qza"
		
		echolog "${GREEN}    Finished importing ggfasta${NC}"
		echolog "Importing ggtax..."
		
		qiime tools import \
			--type 'FeatureData[Taxonomy]' \
			--input-format HeaderlessTSVTaxonomyFormat \
			--input-path $ggtaxonomy \
			--output-path "ref-taxonomy.qza"
		
		echolog "${GREEN}    Finished importing ggtaxonomy${NC}"
	fi
	
	if [ ! -f "extracted-reads.qza" ] && [ ! -f "classifier.qza" ]; then
		#Run the extractions
		echolog "Running read extractions..."
		
		qiime feature-classifier extract-reads \
			--i-sequences "99_otus.qza" \
			--p-f-primer $forward_primer \
			--p-r-primer $reverse_primer \
			--p-min-length $min_read_length \
			--p-max-length $max_read_length \
			--o-reads "extracted-reads.qza"
			
		echolog "${GREEN}    Finished read extractions{NC}"
	fi
	
	if [ ! -f "classifier.qza" ]; then
		#Train the classifier
		echolog "Training the naive bayes classifier..."
		
		qiime feature-classifier fit-classifier-naive-bayes \
			--i-reference-reads "extracted-reads.qza" \
			--i-reference-taxonomy "ref-taxonomy.qza" \
			--o-classifier classifier.qza
		
		echolog "${GREEN}    Finished training the classifier as classifier.qza${NC}"
	fi
	
	if [ -f "classifier.qza" ]; then
		errorlog "${RED}A classifier file already exists as classifier.qza, and has been overwritten.${NC}"
		errorlog "${RED}Please rename the current classifier file if you want a new classifier to be made${NC}"
		errorlog "${RED}when -c is run again.${NC}"
		if [[ "$log" = true ]]; then
			replace_colorcodes_log ${name}.out
		fi
		exit 24
	fi
	
	sed -i '/classifierpath=/c\classifierpath='"${scriptdir}/classifier.qza" "$srcpath"
	if [ -d "${greengenes_path%?}" ]; then
		mv classifier.qza "${greengenes_path}classifier.qza"
		sed -i '/classifierpath=/c\classifierpath='"${greengenes_path}classifier.qza" "$srcpath"
	fi
	
	echolog "${GREEN}Changed the classifier path in the config file${NC}"
	echolog "${GREEN}Classifier block has finished${NC}"
	if [[ "$log" = true ]]; then
		replace_colorcodes_log ${name}.out
	fi
	
	exit 0
	
fi