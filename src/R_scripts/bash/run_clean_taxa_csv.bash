#!/bin/bash

# A phyloseq object will be saved if sklearn is done, and if the phyloseq .RData file doesn't exist
for repqza in ${qzaoutput}*/rep-seqs.qza
do
    if [ "$sklearn_done" = true ] && [ "$cleanup_csv_for_LEFse" = true ]; then

        # Define qzaoutput2
        qzaoutput2=${repqza%"rep-seqs.qza"}

        if [ ! -d "${projpath}csv_for_LEFse" ]; then
	
            mkdir "${projpath}csv_for_LEFse"
            
            echo -e ""
            echo -e "The folder ${BMAGENTA}csv_for_LEFse${NC} was created in your project"
            echo -e "directory. Please put your csv files downloaded from taxa-bar-plots.qza"
            echo -e "into this folder, then rerun this command."
            echo -e ""
        
            logger "No csv_for_LEFse folder was found at the projpath"
            logger "Created csv_for_LEFse directory"
            
            if [[ "$log" = true ]]; then
                replace_colorcodes_log ${name}.out
            fi
		    exit 0
	    fi
        
        talkative "Found folder, starting formatting"
        echolog "Starting ${CYAN}csv formatting for LEFse${NC}"

        # Get ready for Rscript activation
        conda deactivate
        unset R_HOME

        # Set all vars to pass to Rscript
        script_path="${scriptdir}/src/R_scripts/raw/clean_taxa_csv.R"
        finalOutputPath="${projpath}csv_for_LEFse/"

        # Run Rscript, passing all vars as args
        for csvfile in ${projpath}csv_for_LEFse/* ; do
            xbase=${csvfile##*/}
            xpref=${xbase%.*}
            talkative "group_to_compare = ${LEFse_group_to_compare}"
            talkative "xpref = ${xpref}"
            Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${script_path} $csvfile $LEFse_group_to_compare $finalOutputPath $xpref
        done

        # Reactivate the conda env
        conda activate $condaenv
        echolog "${GREEN}    Finished LEFse table generation${NC}"
        echolog "${GREEN}    Outputs are in ${projpath}csv_for_LEFse/${NC}"
    fi
done