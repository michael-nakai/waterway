#!/bin/bash

if [[ "$do_fastqc" = true ]] ; then
	mkdir ${projpath}fastq_reports 2> /dev/null
	fastqc ${filepath}/*.fastq.gz
	mv ${filepath}/*.zip ${filepath}/*.html ${projpath}fastq_reports
	multiqc ${projpath}fastq_reports/*
fi