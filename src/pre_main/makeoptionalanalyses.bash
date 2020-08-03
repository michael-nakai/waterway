#!/bin/bash

if [ ! -f $analysis_path ]; then
	exitnow=true
	echo -e ""
	echo -e "An ${BMAGENTA}optional_analyses.txt${NC} file was not found, and will be created now. Please do not"
	echo -e "touch this file if this is the first time analysing your data set."
	echo -e ""
	
	touch optional_analyses.txt
	
	echo -e "### If you download a taxa_bar_plots csv for LEFse, run this first on it" >> optional_analyses.txt
	echo -e "cleanup_csv_for_LEFse=false" >> optional_analyses.txt
	echo -e "LEFse_group_to_compare=ExampleGroup\n" >> optional_analyses.txt

	echo -e "### Extended alpha diversity metrics" >> optional_analyses.txt
	echo -e "extended_alpha=false\n" >> optional_analyses.txt
	
	echo -e "### Beta rarefaction" >> optional_analyses.txt
	echo -e "rerun_beta_rarefaction=false" >> optional_analyses.txt
	echo -e "rarefaction_groups=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "### Beta analysis for categorical variables" >> optional_analyses.txt
	echo -e "rerun_beta_analysis=false" >> optional_analyses.txt
	echo -e "rerun_group=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "### Beta analysis for continuous variables" >> optional_analyses.txt
	echo -e "run_beta_continuous=false" >> optional_analyses.txt
	echo -e "continuous_group=('Group1' 'Group2' 'etc...')" >> optional_analyses.txt
	echo -e "correlation_method='spearman'\n" >> optional_analyses.txt
	
	echo -e "### Ancom analysis" >> optional_analyses.txt
	echo -e "run_ancom=false" >> optional_analyses.txt
	echo -e "collapse_taxa_to_level=(2 6)" >> optional_analyses.txt
	echo -e "group_to_compare=('Group1' 'Group2' 'etc...')\n" >> optional_analyses.txt
	
	echo -e "### Picrust2 Analysis (Picrust2 must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_picrust=false" >> optional_analyses.txt
	echo -e "hsp_method=mp #Default value, shouldnt need to change" >> optional_analyses.txt
	echo -e "max_nsti=2 #Default value, shouldnt need to change\n" >> optional_analyses.txt
	
	echo -e "### PCoA Biplot Analysis" >> optional_analyses.txt
	echo -e "run_biplot=false" >> optional_analyses.txt
	echo -e "number_of_dimensions=20\n" >> optional_analyses.txt
	
	echo -e "### Songbird Analysis" >> optional_analyses.txt
	echo -e "run_songbird=false" >> optional_analyses.txt
	echo -e "songbird_metadata_filepath=''" >> optional_analyses.txt
	echo -e "songbird_formula=''" >> optional_analyses.txt
	echo -e "songbird_epochs=10000" >> optional_analyses.txt
	echo -e "songbird_differential_prior=0.5" >> optional_analyses.txt
	echo -e "songbird_training_col='Training'" >> optional_analyses.txt
	echo -e "songbird_summary_interval=1\n" >> optional_analyses.txt
	
	echo -e "### DEICODE analysis (DEICODE must be installed as a Qiime2 plugin first)" >> optional_analyses.txt
	echo -e "run_deicode=false" >> optional_analyses.txt
	echo -e "num_of_features=8" >> optional_analyses.txt
	echo -e "min_feature_count=2" >> optional_analyses.txt
	echo -e "min_sample_count=100" >> optional_analyses.txt
	echo -e "beta_rerun_group=('Group1' 'Group2' 'etc...') #Put the metadata columns here\n" >> optional_analyses.txt
	
	echo -e "### Bioenv analysis (can take a LONG time with many metadata variables)" >> optional_analyses.txt
	echo -e "run_bioenv=false\n" >> optional_analyses.txt
	
	echo -e "### Sample classifier and prediction (categorical)" >> optional_analyses.txt
	echo -e "run_classify_samples_categorical=false" >> optional_analyses.txt
	echo -e "metadata_column=('Group1' 'Group2' 'etc...') #Put the metadata columns here" >> optional_analyses.txt
	echo -e "heatmap_num=30" >> optional_analyses.txt
	echo -e "retraining_samples_known_value=true" >> optional_analyses.txt
	echo -e "NCV=true" >> optional_analyses.txt
	echo -e "-------------------" >> optional_analyses.txt
	echo -e "random_seed=123 #Do not change unless needed" >> optional_analyses.txt
	echo -e "estimator_method='RandomForestClassifier' #Do not change unless needed" >> optional_analyses.txt
	echo -e "k_cross_validations=5 #Do not change unless needed" >> optional_analyses.txt
	echo -e "test_proportion=0.2 #Do not change unless needed" >> optional_analyses.txt
	echo -e "number_of_trees_to_grow=100 #Do not change unless needed" >> optional_analyses.txt
	echo -e "palette='sirocco' #Do not change unless needed\n" >> optional_analyses.txt
	
	echo -e "### Sample classifier and prediction (continuous)" >> optional_analyses.txt
	echo -e "run_classify_samples_continuous=false" >> optional_analyses.txt
	echo -e "metadata_column_continuous=('Group1' 'Group2' 'etc...') #Put the metadata columns here" >> optional_analyses.txt
	echo -e "heatmap_num_continuous=30" >> optional_analyses.txt
	echo -e "retraining_samples_known_value_continuous=true" >> optional_analyses.txt
	echo -e "NCV_continuous=true" >> optional_analyses.txt
	echo -e "-------------------" >> optional_analyses.txt
	echo -e "estimator_method_continuous='RandomForestRegressor' #Do not change unless needed" >> optional_analyses.txt
	echo -e "k_cross_validations_continuous=5 #Do not change unless needed" >> optional_analyses.txt
	echo -e "random_seed_continuous=123 #Do not change unless needed" >> optional_analyses.txt
	echo -e "test_proportion_continuous=0.2 #Do not change unless needed" >> optional_analyses.txt
	echo -e "number_of_trees_to_grow_continuous=100 #Do not change unless needed" >> optional_analyses.txt
	echo -e "palette_continuous='sirocco' #Do not change unless needed\n" >> optional_analyses.txt

	echo -e "### Settings for q2-longitudinal for pairwise difference and distance comparisons" >> optional_analyses.txt
	echo -e "# NOTE: the time column must only contain numbers (numeric)" >> optional_analyses.txt
	echo -e "run_longitudinal=false" >> optional_analyses.txt
	echo -e "group_to_compare_longitudinal=(group1 group2)" >> optional_analyses.txt
	echo -e "time_column=timeColumn" >> optional_analyses.txt
	echo -e "sample_id_column_name=sampleid" >> optional_analyses.txt
	echo -e "inital_time=0" >> optional_analyses.txt
	echo -e "final_time=0" >> optional_analyses.txt
	echo -e "linear_mixed_effects_groups='group1,group2,group3' # These should be fixed effects" >> optional_analyses.txt
	echo -e "random_effects_groups='group1,group2,group3'" >> optional_analyses.txt
	echo -e "\n" >> optional_analyses.txt
	
	echo -e "### Gneiss gradient-clustering analyses" >> optional_analyses.txt
	echo -e "run_gneiss=false" >> optional_analyses.txt
	echo -e "use_correlation_clustering=true" >> optional_analyses.txt
	echo -e "use_gradient_clustering=false" >> optional_analyses.txt
	echo -e "gradient_column='column in metadata to use here'" >> optional_analyses.txt
	echo -e "gradient_column_categorical='column in metadata that only has either 'low' or 'high''" >> optional_analyses.txt
	echo -e "heatmap_type=seismic" >> optional_analyses.txt
	echo -e "taxa_level=0" >> optional_analyses.txt
	echo -e "balance_name=none\n" >> optional_analyses.txt
fi