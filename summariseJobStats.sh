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
	sacct --format="JobID,JobName,Partition,Elapsed,MaxRSS,State" -j $i > "$i"_jobStats.txt
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
# e.g. convert HH:MM:SS to hrs
# and convert memory from KB to GB
cat "$1"_"$2"_jobs.txt \
| grep batch \ # only grab the line which has time AND mem input of the job
| awk '{sub(/\K$/,"",$4);print $0}' \ # remove "K" from the memory column
| sed 's/1-/ONEdays /g' | sed 's/batch ONEdays/01:/g' \ # getaround for jobs that took over a day and have inconvenient format
| sed 's/2-/TWOdays /g' | sed 's/batch TWOdays/02:/g' \ # ditto for jobs that took over two days
| sed 's/3-/THREEdays /g' | sed 's/batch THREEdays/03:/g' \ # ditto for jobs that took over three days
| sed 's/batch/00:/g' \ # jobs that took less than a day don't have a day field, so make one
| awk '{print $1 "\t" $2$3 "\t" $4 "\t" $5}' \ # concatenate the day and HH:MM:SS fields
| awk '{ split($2,a,":"); print $1 "\t" (a[1]*24) + a[2] + (a[3]*(60/3600)) + (a[4]/3600) "\t" $3/1000000 "\t" $4}' \ # convert time and mem column to hrs and gb, resp.
| sed $'1 i\\\nJobID\tElapsedTimeHr\tMemUsedGB\tState' \ # add a header
> "$1"_"$2"_jobs_nr.txt

# module load R to generate scatterplot
module load R/3.3.0-foss-2016uofa

# run Rscript to make scatterplot
Rscript --vanilla $FASTDIR/GITHUBrepos/handySLURMscripts/plotJobStats.R "$1"_"$2"_jobs_nr.txt "$1"_"$2"_jobs.pdf

# move pdf (and txt summary) to plots
mv "$1"_"$2"_jobs.pdf $FASTDIR/plots
mv "$1"_"$2"_jobs_nr.txt $FASTDIR/plots

# clear the slate
rm $FASTDIR/jobStats/*
