#!/bin/bash

# Example usage:
# ./summariseJobStats.sh BWA cpu

# Note: requires R and Rscript plotJobStats.R

# Takes two command line arguments as input: process name and partition
# If you aren't sure which partition your jobs ran on, it was probably "cpu"
# e.g. 
# $1 = BWA
# $2 = cpu

export FASTDIR=/fast/users/$USER

# go to dir that stores all slurm*.out files
cd $FASTDIR/scripts

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
| grep -v "-" \
| grep -v JobID \
| grep -v "$2" \
| awk '{sub(/\K$/,"",$4);print $0}' \
| awk '{ split($3,a,":"); print $1 "\t" ((a[1]*3600)+(a[2]*60)+a[3])/3600 "\t" $4/1000000 "\t" $5}' \
| sed $'1 i\\\nJobID\tElapsedTimeHr\tMemUsedGB\tState' \
> "$1"_"$2"_jobs_nr.txt

# module load R to generate scatterplot
module load R/3.3.0-foss-2016uofa

# run Rscript to make scatterplot
Rscript --vanilla $FASTDIR/scripts/plotJobStats.R "$1"_"$2"_jobs_nr.txt "$1"_"$2"_jobs.pdf

# move pdf (and txt summary) to plots
mv "$1"_"$2"_jobs.pdf $FASTDIR/plots
mv "$1"_"$2"_jobs_nr.txt $FASTDIR/plots

# clear the slate
rm $FASTDIR/jobStats/*
