#!/bin/bash

for repqza in ${qzaoutput}*/rep-seqs.qza
do
    if [ "$sklearn_done" = true ] && [ "$generate_lefse_tables" = true ]; then

        # Define general filepaths
        qzaoutput2=${repqza%"rep-seqs.qza"}
        echolog "\nStarting ${CYAN}LEfSe table autogeneration${NC} for $qzaoutput2"

        # Main
        talkative "Making folders"
        mkdir -p ${qzaoutput2}LEfSe_tables
        mkdir -p ${qzaoutput2}temp

        talkative "Running the Qiime2 command"
        qiime tools export \
            --input-path ${qzaoutput2}taxa-bar-plots.qzv \
            --output-path ${qzaoutput2}LEfSe_tables/raw-tables
        
        # Take the csv files out of the randomly named folder (comes from Qiime2 provenance)
        talkative "Moving the files"
        mv ${qzaoutput2}LEfSe_tables/raw-tables/*.csv ${qzaoutput2}temp
        rm -r ${qzaoutput2}LEfSe_tables/raw-tables/*
        mv ${qzaoutput2}temp/* ${qzaoutput2}LEfSe_tables/raw-tables/
        rm -d ${qzaoutput2}temp

        # Get ready for Rscript activation
        talkative "Getting ready for Rscript"
        conda deactivate
        unset R_HOME
        script_path="${scriptdir}/src/R_scripts/raw/clean_taxa_csv.R"
        mkdir -p ${qzaoutput2}LEfSe_tables/Completed_tables

        for tablefile in ${qzaoutput2}LEfSe_tables/raw-tables/*
        do
            for group in ${LEfSe_groups_to_compare[@]}
            do
                talkative "Starting ${CYAN}table generation for $group${NC}"
                mkdir -p ${qzaoutput2}LEfSe_tables/Completed_tables/${group}
                finalOutputPath=${qzaoutput2}LEfSe_tables/Completed_tables/${group}/
                xbase=${tablefile##*/}
                xpref=${xbase%.*}
                talkative "group_to_compare = $group"
                talkative "xpref = ${xpref}"
                Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${script_path} $tablefile $group $finalOutputPath $xpref $database_type_used
                talkative "Finished ${BMAGENTA}$group${NC} for ${BMAGENTA}${xpref}${NC}"
            done
            
            
            echolog "Finished all groups for ${BMAGENTA}${tablefile}${NC}\n"
        done

        conda activate $condaenv
        echolog "    ${GREEN}Finished LEfSe table generation for the main dataset${NC}\n"
    fi
done