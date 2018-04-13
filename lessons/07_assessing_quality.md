---
title: "Quality control using FASTQC"
author: "Mary Piper, Radhika Khetani"
date: Wednesday, September 20, 2017
duration: 85 minutes
---

## Learning Objectives:

* Evaluate the quality of your NGS data using FastQC
* Create and run a job submission script to automate quality assessment

## Quality Control of FASTQ files

<img src="../img/RNAseqWorkflow.png" width="400">

The first step in the RNA-Seq workflow is to take the FASTQ files received from the sequencing facility and assess the quality of the sequence reads. 

### Unmapped read data (FASTQ)

The [FASTQ](https://en.wikipedia.org/wiki/FASTQ_format) file format is the defacto file format for sequence reads generated from next-generation sequencing technologies. This file format evolved from FASTA in that it contains sequence data, but also contains quality information. Similar to FASTA, the FASTQ file begins with a header line. The difference is that the FASTQ header is denoted by a `@` character. For a single record (sequence read) there are four lines, each of which are described below:

|Line|Description|
|----|-----------|
|1|Always begins with '@' and then information about the read|
|2|The actual DNA sequence|
|3|Always begins with a '+' and sometimes the same info in line 1|
|4|Has a string of characters which represent the quality scores; must have same number of characters as line 2|

Let's use the following read as an example:

```
@HWI-ST330:304:H045HADXX:1:1101:1111:61397
CACTTGTAAGGGCAGGCCCCCTTCACCCTCCCGCTCCTGGGGGANNNNNNNNNNANNNCGAGGCCCTGGGGTAGAGGGNNNNNNNNNNNNNNGATCTTGG
+
@?@DDDDDDHHH?GH:?FCBGGB@C?DBEGIIIIAEF;FCGGI#########################################################
```

As mentioned previously, line 4 has characters encoding the quality of each nucleotide in the read. The legend below provides the mapping of quality scores (Phred-33) to the quality encoding characters. ** *Different quality encoding scales exist (differing by offset in the ASCII table), but note the most commonly used one is fastqsanger* **

 ```
 Quality encoding: !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHI
                   |         |         |         |         |
    Quality score: 0........10........20........30........40                                
```
 
Using the quality encoding character legend, the first nucelotide in the read (C) is called with a quality score of 31 and our Ns are called with a score of 2. **As you can tell by now, this is a bad read.** 

Each quality score represents the probability that the corresponding nucleotide call is incorrect. This quality score is logarithmically based and is calculated as:

	Q = -10 x log10(P), where P is the probability that a base call is erroneous

These probabaility values are the results from the base calling algorithm and dependent on how much signal was captured for the base incorporation. The score values can be interpreted as follows:

|Phred Quality Score |Probability of incorrect base call |Base call accuracy|
|:-------------------|:---------------------------------:|-----------------:|
|10	|1 in 10 |	90%|
|20	|1 in 100|	99%|
|30	|1 in 1000|	99.9%|
|40	|1 in 10,000|	99.99%|
|50	|1 in 100,000|	99.999%|
|60	|1 in 1,000,000|	99.9999%|

Therefore, for the first nucleotide in the read (C), there is less than a 1 in 1000 chance that the base was called incorrectly. Whereas, for the the end of the read there is greater than 50% probabaility that the base is called incorrectly.

## Assessing quality with FastQC

Now we understand what information is stored in a FASTQ file, the next step is to examine quality metrics for our data.

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) provides a simple way to do some quality control checks on raw sequence data coming from high throughput sequencing pipelines. It provides a modular set of analyses which you can use to give a quick impression of whether your data has any problems of which you should be aware before doing any further analysis.

The main functions of FastQC are:

* Import of data from BAM, SAM or FastQ files (any variant)
* Providing a quick overview to tell you in which areas there may be problems
* Summary graphs and tables to quickly assess your data
* Export of results to an HTML based permanent report
* Offline operation to allow automated generation of reports without running the interactive application

### Run FastQC  

Before we run FastQC, let's start an interactive session on the cluster (if you don't already have one going):

```bash
% srun --pty -p defq --qos=interactive --mem 8G bash
```

***An interactive session is very useful to test tools, workflows, run jobs that open new interactive windows (X11-forwarding) and so on.***

Once your interactive job starts, notice that the command prompt has changed; this is because we are working on a compute node now, not on a login node. Change directories to `raw_data`.

```bash
% cd ~/unix_lesson/rnaseq/raw_data
```  

Before we start using software, we have to load the environments for each software package. On the cluster here, this is done using an **LMOD** system. 

If we check which modules we currently have loaded, we should not see FastQC.

```bash
% module list
```

This is because the FastQC program is not in our $PATH (i.e. its not in a directory that unix will automatically check to run commands/programs).

```bash
% echo $PATH
```

To run the FastQC program, we first need to load the appropriate module, so it puts the program into our path. To find the FastQC module to load we need to search the versions available:

```bash
% module spider
```

Then we can load the FastQC module:

```bash
% module load fastqc
```

Once a module for a tool is loaded, you have essentially made it directly available to you like any other basic UNIX command.

```bash
% module list

% echo $PATH
```

FastQC will accept multiple file names as input, so we can use the `*.fq` wildcard.

```bash
% fastqc *.fq
```

*Did you notice how each file was processed serially? How do we speed this up?*

Exit the interactive session and start a new one with 6 cores, and use the multi-threading functionality of FastQC to run 6 jobs at once.

```bash
% exit  #exit the current interactive session

% srun --pty -p defq -n 6 --mem 8G --qos=interactive bash    #start a new one with 6 cpus (-n 6)

% module load fastqc  #reload the module for the new session

% cd ~/unix_lesson/rnaseq/raw_data

% fastqc -t 6 *.fq  #note the extra parameter we specified for 6 threads
```

How did I know about the -t argument for FastQC?

```bash
% fastqc --help      # check usage and version number
```

Now, let's create a home for our results

```bash
% mkdir ~/unix_lesson/rnaseq/results/fastqc
```

...and move them there (recall, we are still in `~/unix_lesson/rnaseq/raw_data/`)

```bash
% mv *fastqc* ~/unix_lesson/rnaseq/results/fastqc/
```

### Performing quality assessment using job submission scripts
So far in our FASTQC analysis, we have been directly submitting commands to the cluster using an interactive session (`srun ...`). However, there are many more partitions available on the cluster than just the interactive partition. We can submit commands or series of commands to these partitions using job submission scripts. 

**Job submission scripts** for the cluster are just regular scripts, but contain the the cluster **options/directives** for job submission, such as *number of cores, name of partition, runtime limit, etc*. We can submit these scripts to whichever partition we specify in the script using the `sbatch` command as follows:

```bash
# DO NOT RUN THIS
% sbatch job_submission_script.run
```

Submission of the script using the `sbatch` command allows SLURM to run your job when its your turn. Let's create a job submission script to load the FASTQC module, run FASTQC on all of our fastq files, and move the files to the appropriate directory.

Change directories to `~/unix_lesson/rnaseq/scripts`, and create a script named `mov10_fastqc.run` using `vim`.

```bash
% cd ~/unix_lesson/rnaseq/scripts

% vim mov10_fastqc.run
```

The first thing we need in our script is the **shebang line**:

```bash
#!/bin/bash
```

Following the shebang line are the Orchestra options. For the script to run, we need to include options for **queue/partition (-p) and runtime limit (-t)**. To specify our options, we precede the option with `#SBATCH`, which tells the cluster that the line contains options for job submission to SLURM. 

```bash
#SBATCH -p defq 		# partition name
#SBATCH --qos=short
#SBATCH -n 6 		# number of cores requested -- this needs to be greater than or equal to the number of cores you plan to use to run your job
#SBATCH --job-name rnaseq_mov10_fastqc 		# Job name
#SBATCH -o %j.out			# File to which standard out will be written
#SBATCH -e %j.err 		# File to which standard err will be written
```
Now in the body of the script, we can include any commands we want run:

```bash
## Changing directories to where the fastq files are located
cd ~/unix_lesson/rnaseq/raw_data

## Loading modules required for script commands
module load fastqc

## Running FASTQC
fastqc -t 6 *.fq

## Moving files to our results directory
mv *fastqc* ../results/fastqc/
```

Save and quit the script. Now, let's submit the job to the SLURM:

```bash
% sbatch mov10_fastqc.run
```

You can check on the status of your job with:

```bash
% sacct
```

```bash
% ls -lh ../results/fastqc/
```
There should also be standard error (`.err`) and standard out (`.out`) files from the job listed in `~/unix_lesson/rnaseq/scripts`. You can move these over to your `logs` directory and give them more intuitive names:

```bash
% mv *.err ../logs/fastqc.err
% mv *.out ../logs/fastqc.out
```

***

**Exercise**

How would you change the `mov10_fastqc.run` script if you had 9 fastq files you wanted to run in parallel.

***

### FastQC Results
   
Let's take a closer look at the files generated by FastQC:
   
```bash
% ls -lh ~/unix_lesson/rnaseq/results/fastqc/
```

#### HTML reports
The .html files contain the final reports generated by fastqc, let's take a closer look at them. Transfer the file for `Mov10_oe_1.subset.fq` over to your laptop using the instructions we will give in class.

> #### Unable to open the HTML file locally?
> If you can't transfer over the HTML, we have [linked the report](https://www.dropbox.com/s/2p27dwhtomn3toc/Irrel_kd_2.subset_fastqc.html?dl=1) here for you. Download the HTML and open in your browser to follow along. 
	
***FastQC is just an indicator of what's going on with your data, don't take the "PASS"es and "FAIL"s too seriously.***

FastQC has a really well documented [manual page](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) with [more details](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/) about all the plots in the report. We recommend looking at [this post](http://bioinfo-core.org/index.php/9th_Discussion-28_October_2010) for more information on what bad plots look like and what they mean for your data.

Below are two of the most important analysis modules in FastQC, the **"Per base sequence quality"** plot and the **"Overrepresented sequences"** table. 

The **"Per base sequence quality"** plot provides the distribution of quality scores across all bases at each position in the reads.

![FastQC_seq_qual](../img/FastQC_seq_qual.png)

The **"Overrepresented sequences"** table displays the sequences (at least 20 bp) that occur in more than 0.1% of the total number of sequences. This table aids in identifying contamination, such as vector or adapter sequences. 

![FastQC_contam](../img/FastQC_contam.png)

We will go over the remaining plots in class. Remember, our report only represents a subset of reads (chromosome 1) for `Mov10_oe_1.subset.fq`, which can skew the QC results. We encourage you to look at the [full set of reads](https://hbctraining.github.io/Intro-to-rnaseq-hpc-O2/fastqc/Mov10oe_1-fastqc_report.html) and note how the QC results differ when using the entire dataset.
   
> **_NOTE:_** 
>The other output of FastQC is a zip archive, which when decompressed contains all of the information contained in the report but in text files and image file formats. These zip archives need to be unpacked with the `unzip` program. However, if we try to unzip them all at once (i.e. `unzip *.fq`), it won't work.
>
> We could decompress the files one at a time, but if we had many files this would be cumbersome. Instead we can create a for loop to iteratively go through each of our files and unzip them:
>
>```bash
>% for zip in *.zip
> do
> unzip $zip
> done
>```
>This will run unzip once for each file (whose name is stored in the $zip variable). The contents of each file will be unpacked into a separate directory by the unzip program.
> 


---
*This lesson has been developed by members of the teaching team at the [Harvard Chan Bioinformatics Core (HBC)](http://bioinformatics.sph.harvard.edu/). These are open access materials distributed under the terms of the [Creative Commons Attribution license](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0), which permits unrestricted use, distribution, and reproduction in any medium, provided the original author and source are credited.*

* *The materials used in this lesson was derived from work that is Copyright © Data Carpentry (http://datacarpentry.org/). 
All Data Carpentry instructional material is made available under the [Creative Commons Attribution license](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0).*
