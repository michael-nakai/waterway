#!/bin/bash

# A phyloseq object will be saved if sklearn is done, and if the phyloseq .RData file doesn't exist
for repqza in ${qzaoutput}*/rep-seqs.qza
do
    if [ $sklearn_done = true ] && [ ! -f "${repqza%'rep-seqs.qza'}R_outputs/phyloseq_object/phyloseq_object.RData" ]; then

        # Define qzaoutput2
        qzaoutput2=${repqza%"rep-seqs.qza"}

        echolog "Starting ${CYAN}phyloseq_object creation${NC}"

        # Get ready for Rscript activation
        conda deactivate
        unset R_HOME

        # Make directory to save output to
        mkdir "${qzaoutput2}R_outputs" 2> /dev/null
        mkdir "${qzaoutput2}R_outputs/phyloseq_object" 2> /dev/null

        # Set all vars to pass to Rscript
        script_path="${scriptdir}/src/R_scripts/raw/make_phyloseq.R"
        finalOutputPath="${qzaoutput2}R_outputs/phyloseq_object/"
        dTablePath="${qzaoutput2}table.qza"
        dRootedTree="${qzaoutput2}rooted-tree.qza"
        dMetadataPath="${metadata_filepath}"
        dTaxPath="${qzaoutput2}taxonomy.qza"

        # Run Rscript, passing all vars as args
        Rscript --default-packages=methods,datasets,utils,grDevices,graphics,stats ${script_path} $finalOutputPath $dTablePath $dRootedTree $dMetadataPath $dTaxPath

        # Reactivate the conda env
        conda activate $condaenv
        echolog "${GREEN}    Finished phyloseq_object creation${NC}"
    else
        talkative "${YELLOW}phyloseq_object already exists for ${repqza%'rep-seqs.qza'}${NC}"
    fi
done