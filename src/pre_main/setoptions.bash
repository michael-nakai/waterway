#!/bin/bash

verbose=false
log=false
tst=false
hlp=false
manifest_status=false
show_functions=false
train_classifier=false
do_fastqc=false
rename_files=false
install_deicode=false
install_picrust=false
filter=false
include_subsets=false
graphs=false # Currently does nothing
devtest=false # This is for anything I want to test

# Let's set the option flags here
for op
do
	if [ "$op" == "-v" ] || [ "$op" == "--verbose" ] ; then
		verbose=true
	fi
	if [ "$op" == "-l" ] || [ "$op" == "--log" ] ; then
		log=true
	fi
	if [ "$op" == "-m" ] || [ "$op" == "--manifest" ] ; then
		manifest_status=true
	fi
	if [ "$op" == "-t" ] || [ "$op" == "--test" ] ; then
		tst=true
	fi
	if [ "$op" == "-h" ] || [ "$op" == "--help" ] ; then
		hlp=true
	fi
	if [ "$op" == "-f" ] || [ "$op" == "--show-functions" ] ; then
		show_functions=true
	fi
	if [ "$op" == "-c" ] || [ "$op" == "--train-classifier" ] ; then
		train_classifier=true
	fi
	if [ "$op" == "-s" ] || [ "$op" == "--subsets" ] ; then
		include_subsets=true
	fi
	if [ "$op" == "-g" ] || [ "$op" == "--graphs" ] ; then
		graphs=true # Currently does nothing
	fi
	if [ "$op" == "-M" ] || [ "$op" == "--make-manifest" ] ; then
		make_manifest=true
	fi
	if [ "$op" == "-F" ] || [ "$op" == "--fastqc" ] ; then
		do_fastqc=true
	fi
	if [ "$op" == "-r" ] || [ "$op" == "--remove-underscores" ] ; then
		rename_files=true
	fi
	if [ "$op" == "-T" ] || [ "$op" == "--filter-table" ] ; then
		filter=true
	fi
	if [ "$op" == "--install-deicode" ] ; then
		install_deicode=true
	fi
	if [ "$op" == "--install-picrust" ] ; then
		install_picrust=true
	fi
	if [ "$op" == "--install-tidyverse-conda" ] ; then
		install_tidyverse=true
	fi
	if [ "$op" == "-n" ] || [ "$op" == "--version" ] ; then
		echo ""
		echo -e "Currently running ${LBLUE}waterway${NC} ${LGREY}${version}${NC}"
		echo -e "Currently running ${LGREEN}Qiime2${NC} ${LGREY}${q2versionnum}${NC}"
		echo ""
		exit 0
	fi
	if [ "$op" == "--devtest" ] ; then
		devtest=true
	fi
done