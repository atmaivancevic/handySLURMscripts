#!/bin/bash

# Example usage:
# ./summariseJobStats.sh BWA cpu

# Note: requires R and Rscript plotJobStats.R

# Takes two command line arguments as input: process name and partition
# Note: process name should be the first few unique characters of your process name
# E.g. "BWA" is fine for BWA-GATKHPC
# If you aren't sure which partition your jobs ran on, it was probably "cpu"
# e.g. 
# $1 = BWA
# $2 = cpu

export FASTDIR=/fast/users/$USER

# go to dir that stores all slurm*.out files
cd $FASTDIR/slurmOUT

# generate list of all slurm ids
ls slurm-* | sed 's/slurm-//g' | sed 's/.out//g' > slurmIDs.txt
slurmIDList=$(cat slurmIDs.txt)

# generate job stats for each job 
for i in $slurmIDList;
do
	echo $i
	sacct --format="JobID,JobName,Partition,Elapsed,MaxRSS,UserCPU,State" -j $i > "$i"_jobStats.txt
done

# move to the jobs stats folder
mv *_jobStats.txt $FASTDIR/jobStats/
cd $FASTDIR/jobStats/

# only keep stats file if jobs have completed successfully
# ie. delete stats for failed or currently running jobs 
find . -type f -exec grep -F -L 'COMPLETED' '{}' + \
| xargs -d '\n' rm

# narrow it down to jobs from a particular process
# e.g. all BWA alignment jobs
find . -type f -exec grep -F -L ''$1'' '{}' + \
| xargs -d '\n' rm

# and narrow it down to jobs run on a particular partition
# e.g. cpu or highmem
find . -type f -exec grep -F -L ''$2'' '{}' + \
| xargs -d '\n' rm

# concatenate all remaining jobs 
cat *_jobStats.txt > "$1"_"$2"_jobs.txt

# remove redundant lines and format
# e.g. convert D-HH:MM:SS to hrs
# and convert memory from KB to GB
cat "$1"_"$2"_jobs.txt \
| grep batch \
| awk '{sub(/\K$/,"",$4);print $0}' \
| awk '{print $1 " " $2 " " $3 " " $4 " " "batch" " " $5 " " $6}' \
| sed 's/1-/ONEdays /g' | sed 's/batch ONEdays/01:/g' \
| sed 's/2-/TWOdays /g' | sed 's/batch TWOdays/02:/g' \
| sed 's/3-/THREEdays /g' | sed 's/batch THREEdays/03:/g' \
| sed 's/batch/00:/g' \
| awk '{print $1 "\t" $2$3 "\t" $4 "\t" $5$6 "\t" $7}' \
| awk '{ split($2,a,":"); print $1 "\t" (a[1]*24) + a[2] + (a[3]*(60/3600)) + (a[4]/3600) "\t" $3/1000000 "\t" $4 "\t" $5}' \
| awk '{ split($4,b,":"); print $1 "\t" $2 "\t" $3 "\t" (b[1]*24) + b[2] + (b[3]*(60/3600)) + (b[4]/3600) "\t" $5}' \
| sed $'1 i\\\nJobID\tElapsedTimeHr\tMemUsedGB\tCPUTimeHr\tState' \
> "$1"_"$2"_jobs_nr.txt

# Explanation for the above bit of garbled mess:
# first we grep batch, since this line holds both the time and mem info of the job
# then remove "K" from the memory column
# then we have to work around the fact that jobs may have diff time formats (for both elapsed and cpu time)
# e.g. D-HH:MM:SS versus HH:MM:SS
# this is super inconvenient btw 
# so we replace all 1-, 2-, 3- with a temp name
# then concatenate it to HH:MM:SS as 01:,02:,03:
# for jobs that took less than a day, we add 00: to the time col
# this results in consistent time format of DD:HH:MM:SS
# then we convert time (elapsed and cpu) and memory columns to hrs and gb, respectively
# and add a header to finish it off (woo!)

# module load R to generate scatterplot
module load R/3.3.0-foss-2016uofa

# run Rscript to make two scatterplots
# first one: mem used vs elapsed wall time
# second one: mem used vs cpu time
Rscript --vanilla $FASTDIR/GITHUBrepos/handySLURMscripts/plotJobStats.R "$1"_"$2"_jobs_nr.txt "$1"_"$2"_jobs_MEMvsElapsedTime.pdf "$1"_"$2"_jobs_MEMvsCPUTime.pdf

# move pdfs (and txt summary) to plots
mv "$1"_"$2"_jobs_nr.txt $FASTDIR/plots
mv "$1"_"$2"_jobs_*.pdf $FASTDIR/plots

# clear the slate
rm $FASTDIR/jobStats/*
