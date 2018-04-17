#!/bin/bash/

# This script takes a fastq file of RNA-Seq data, runs FastQC and outputs a counts file for it.
# USAGE: sh rnaseq_analysis_on_input_file.sh <name of fastq file>

# initialize a variable with an intuitive name to store the name of the input fastq file

fq=$1

# grab base of filename for naming outputs

base=$(basename $fq .subset.fq)
echo "Sample name is $base"           

# specify the number of cores to use

cores=6

# directory with genome reference FASTA and index files + name of the gene annotation file

genome=grch38_chr1
genome_dir=/gstore/scratch/hpctrain/chr1_reference_gsnap
gtf=/gstore/scratch/hpctrain/chr1_reference_gsnap/chr1_grch38.gtf

# make all of the output directories
# The -p option means mkdir will create the whole path if it 
# does not exist and refrain from complaining if it does exist

mkdir -p ~/unix_workshop/rnaseq/results/fastqc/
mkdir -p ~/unix_workshop/rnaseq/results/gsnap/
mkdir -p ~/unix_workshop/rnaseq/results/counts/

# set up output filenames and locations

fastqc_out=~/unix_workshop/rnaseq/results/fastqc/
align_out=~/unix_workshop/rnaseq/results/gsnap/${base}_Aligned.sortedByCoord.out.bam
counts=~/unix_workshop/rnaseq/results/counts/${base}_featurecounts.txt

# set up the software environment

module load fastqc
module load GMAP-GSNAP
module load samtools
module load subread

echo "Processing file $fq"

# Run FastQC and move output to the appropriate folder
fastqc $fq

# Run gsnap
gsnap -d $genome -D $genome_dir -t 6 --quality-protocol=sanger \
-M 2 -n 10 -B 2 -i 1 -N 1 -w 200000 -E 1 --pairmax-rna=200000 \
-A sam $fq | samtools sort - | samtools view -bS - > $align_out

# Create BAM index
samtools index $align_out

# Count mapped reads
featureCounts -T $cores -s 2 -a $gtf -o $counts $align_out
