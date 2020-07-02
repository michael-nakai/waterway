#!/bin/bash

if [[ "$install_deicode" = true ]] ; then
	exitnow=true
	conda install -c conda-forge deicode
fi

if [[ "$install_picrust" = true ]] ; then
	exitnow=true
	conda install q2-picrust2 -c conda-forge -c bioconda -c gavinmdouglas
fi

if [[ "$install_tidyverse" = true ]] ; then
	exitnow=true
	conda install -c r r-tidyverse
fi