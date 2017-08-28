#!/bin/bash

# Example usage:
# OUTPREFIX=26537 WORKDIR=/data/neurogenetics/alignments/Illumina/WES/ExomesMarch2014 sbatch callVariantsGATK.sh

#SBATCH -J BWA-GATKHC

#SBATCH -A robinson
#SBATCH -p batch
#SBATCH -N 1
#SBATCH -n 8
#SBATCH --time=1-00:00 # change this to 3 days for real set
#SBATCH --mem=70GB

# Notification configuration 
#SBATCH --mail-type=END                                         
#SBATCH --mail-type=FAIL                                        
#SBATCH --mail-user=atma.ivancevic@adelaide.edu.au

# load modules
module load BWA/0.7.15-foss-2017a
module load Java/1.8.0_121
module load HTSlib/1.3.1-GCC-5.3.0-binutils-2.25
module load SAMtools/1.3.1-GCC-5.3.0-binutils-2.25
### module load GATK 3.7
### module load picard/2.6.0 or higher

# run pipeline to call variants using the GATK v3.x best practices 

# Variables that usually don't need changing once set for your system
gVcfFolder=/data/neurogenetics/gVcfDumpingGround/Exomes # A place to dump gVCFs for later genotyping
BWAINDEXPATH=/data/neurogenetics/RefSeq/BWA/hg19_1stM_unmask_ran_all # Your genome reference path for BWA
BWAINDEX=hg19_1stM_unmask_ran_all.fa # name of the genome reference
GATKPATH=/data/neurogenetics/executables/GenomeAnalysisTK-3.7 # Where the GATK program.  Be mindful that GATK is under rapid development so things may change over time!
GATKREFPATH=/data/neurogenetics/RefSeq/GATK #Refseq index library locations
GATKINDEX=$BWAINDEX # Base name of GATK indexes (usually the same as the $BWAINDEX)
ChrIndexPath=$GATKREFPATH/$BWAINDEX.chridx #Location of index bed files
IndexBedFiles=01.hg19-M1.bed,02.hg19-2-3.bed,03.hg19-4-5.bed,04.hg19-6-7.bed,05.hg19-8-10.bed,06.hg19-11-13.bed,07.hg19-14-17.bed,08.hg19-18etc.bed # A comma separated array of names of index files
arrIndexBedFiles=$(echo $IndexBedFiles | tr "," "\n")
PICARDPATH=/data/neurogenetics/executables/Picard-2.9.2 # Where the picard program is.  Picard is also under rapid development so may change over time.
DBSNP=dbsnp_138.hg19.vcf
BUILD=$(echo $BWAINDEX | awk '{print substr($1, 1, length($1) - 3)}') # Genome build used = $BWAINDEX less the .fa, this will be incorporated into file names.

usage()
{
echo "# Script for processing and mapping Illumina 100bp pair-end sequence data and optionally plotting coverage for an interval
# Requires: BWA 0.7.x, Picard, samtools, GATKv3.x, BWA-Picard-GATK-CleanUp.sh.  
# 
#
# Usage $0 -p file_prefix -s /path/to/sequences [ -o /path/to/output] [-L LibraryName][-I ID][-i /path/to/bedfile.bed] | [ - h | --help ]
#
# Options
# OUTPREFIX	A prefix to your sequence files of the form PREFIX_R1.fastq.gz
# WORKDIR	Path to where you want to find your file output (if not specified current directory is used)
# -h or --help	Prints this message.  Or if you got one of the options above wrong you'll be reading this too!
# 
# System variables currently set:
# gVcfFolder=$gVcfFolder
# BWAINDEXPATH=$BWAINDEXPATH
# BWAINDEX=$BWAINDEX
# ChrIndexPath=$ChrIndexPath
# IndexBedFiles=$IndexBedFiles
# GATKPATH=$GATKPATH
# GATKREFPATH=$GATKREFPATH
# GATKINDEX=$GATKINDEX
# PICARDPATH=$PICARDPATH
# SCRIPTPATH=$SCRIPTPATH
# BUILD=$BUILD
# 
# Original: Derived from Illumina-Phred33-PE-FASTX-BWA-Picard-GATKv2.sh by Mark Corbett, 17/03/2014
# Contact: mark.corbett@adelaide.edu.au
# Modified: (Date; Name; Description)
# 18/09/2014; Mark Corbett; Update GATK version 3.2-2
# 21/11/2014; Mark Corbett; Incorporate GATKv3.x.HC.by.Quarters.HPC.sh 
# 03/12/2014; Mark Corbett; Update to use tizard Picard installation
# 15/01/2015; Mark Corbett; Put in temp file saves on GATK error
# 21/04/2016; Mark Corbett; Bring up to date with GATK current best practices
# 09/05/2017; Atma Ivancevic; Translating for Phoenix
# 28/8/17; Atma Ivancevic; Extracting just the GATK step
#
"
}

if [ -z "$OUTPREFIX" ]; then # If no file prefix specified then do not proceed
	usage
	echo "#ERROR: You need to specify a file prefix (PREFIX) referring to your sequence files eg. PREFIX_R1.fastq.gz."
	exit 1
fi
if [ -z "$WORKDIR" ]; then # If no output directory then use current directory
	WORKDIR=$(pwd)
	echo "Using current directory as the working directory"
fi
if [ -z "$SAMPLE" ]; then # If sample name not specified then use "OUTPREFIX"
	SAMPLE=$OUTPREFIX
	echo "Using $OUTPREFIX for sample name"
fi
if [ -z "$LB" ]; then # If library not specified then use "IlluminaExome"
	LB=IlluminaExome
	echo "Using \"IlluminaExome\" for library name"
fi
if [ -z "$INTERVAL" ]; then # If no interval set then 
	IntervalCoverage=false # Don't run coverage calculation
	else
	IntervalCoverage=true # If it is set then run the coverage calculation
fi
if [ ! -d $gVcfFolder ]; then
        mkdir -p $gVcfFolder
fi
tmpDir=/tmp/$USER/$OUTPREFIX # Use a tmp directory in tmp for all of the GATK and samtools temp files
if [ ! -d $tmpDir ]; then
	mkdir -p $tmpDir # -p means the parent directories will also be created if they don't exist
fi

# For the next steps split the bams into bits based on the IndexBedFiles
# First make tmp dirs
for bed in $arrIndexBedFiles; do
	mkdir -p $tmpDir/$bed
done

# Move to tmpDir
cd $tmpDir

# As of GATK v3.x you can now run the haplotype caller directly on a single bam
# Run haplotype caller in gVCF mode
for bed in $arrIndexBedFiles; do
	java -Xmx4g -Djava.io.tmpdir=$tmpDir/$bed -jar $GATKPATH/GenomeAnalysisTK.jar \
	-I $WORKDIR/$OUTPREFIX.realigned.recal.sorted.bwa.$BUILD.bam \
	-R $GATKREFPATH/$GATKINDEX \
	-T HaplotypeCaller \
	-L $ChrIndexPath/$bed \
	--dbsnp $GATKREFPATH/$DBSNP \
	--min_base_quality_score 20 \
	--emitRefConfidence GVCF \
	-o $tmpDir/$bed.$OUTPREFIX.snps.g.vcf > $tmpDir/$bed.$OUTPREFIX.pipeline.log 2>&1 &
done
wait

cat *.$OUTPREFIX.pipeline.log >> $WORKDIR/$OUTPREFIX.pipeline.log
ls | grep $OUTPREFIX.snps.g.vcf$ > $OUTPREFIX.gvcf.list.txt
sed 's,^,-V '"$tmpDir"'\/,g' $OUTPREFIX.gvcf.list.txt > $OUTPREFIX.inputGVCF.txt

java -cp $GATKPATH/GenomeAnalysisTK.jar org.broadinstitute.gatk.tools.CatVariants \
-R $GATKREFPATH/$GATKINDEX \
-out $OUTPREFIX.snps.g.vcf \
$(cat $OUTPREFIX.inputGVCF.txt) \
--assumeSorted >> $WORKDIR/$OUTPREFIX.pipeline.log  2>&1

bgzip $OUTPREFIX.snps.g.vcf
tabix $OUTPREFIX.snps.g.vcf.gz

mv $OUTPREFIX.snps.g.vcf.gz $gVcfFolder/$OUTPREFIX.snps.g.vcf.gz
mv $OUTPREFIX.snps.g.vcf.idx $gVcfFolder/$OUTPREFIX.snps.g.vcf.idx
mv $OUTPREFIX.snps.g.vcf.gz.tbi $gVcfFolder/$OUTPREFIX.snps.g.vcf.gz.tbi

## Other optional metrics ##
# Coverage for an interval
if $IntervalCoverage ; then
	samtools depth -b $INTERVAL $WORKDIR/$OUTPREFIX.realigned.recal.sorted.bwa.$BUILD.bam > $OUTPREFIX.Coverage.$BUILD.txt
	gzip $OUTPREFIX.Coverage.$BUILD.txt > $WORKDIR/$OUTPREFIX.Coverage.$BUILD.txt.gz
fi

## Check for bad things and clean up
grep ERROR $WORKDIR/$OUTPREFIX.pipeline.log > $WORKDIR/$OUTPREFIX.pipeline.ERROR.log
if [ -z $(cat $WORKDIR/$OUTPREFIX.pipeline.ERROR.log) ]; then
	rm $WORKDIR/$OUTPREFIX.pipeline.ERROR.log $OUTPREFIX.marked.sort.bwa.$BUILD.bam $OUTPREFIX.marked.sort.bwa.$BUILD.bai
	rm -r $tmpDir
else 
	echo "Some bad things went down while this script was running please see $OUTPREFIX.pipeline.ERROR.log and prepare for disappointment."
fi
