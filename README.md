#
## metabinkit
![Docker](https://github.com/envmetagen/metabinkit/workflows/Docker/badge.svg?branch=master) [![Dockerhub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/envmetagen/metabinkit/tags/) [![DOI](https://zenodo.org/badge/265322807.svg)](https://zenodo.org/badge/latestdoi/265322807) [![License](http://img.shields.io/badge/license-GPL%203-brightgreen.svg?style=flat)](http://www.gnu.org/licenses/gpl-3.0.html) 

Set of programs to perform taxonomic binning.

1. [Overview](#Overview)
2. [Docker](#Docker)
2. [Manual installation](#Manual-installation)
3. [Metabinkit programs](#Programs)


### Overview
From metagenomic or metabarcoding data, it is often necessary to assign taxonomy to DNA sequences. This is generally performed by aligning sequences to a reference database, usually resulting in multiple database alignments for each query sequence. Using these alignment results, metabinkit assigns a single taxon to each query sequence, based on user-defined percentage identity thresholds. In essence, for each query, the alignments are filtered based on the percentage identity thresholds and the lowest common ancestor for all alignments passing the filters is determined. The metabin program is not limited to BLAST alignments, and can accept alignment results produced using any program, provided the input format is correct. However, functionality is also available to create BLAST databases and to perform BLAST alignments, which can be passed directly to metabin.  

### Docker

A docker image that includes everything required to run with metabinkit is available at DockerHub (https://hub.docker.com/r/envmetagen/metabinkit/tags/). This facilitates the setup and installation of metabinkit, makes it easy to track all software versions used in the analyses, and ensures that only dependency versions compatible with metabinkit are used. See the [Docker userguide](https://docs.docker.com/) for more details.

Alternatively you may install the software from source following the instructions provided next. A  64bit computer with an up to date Linux OS installed will be required.



### Manual installation

#### Supported OS

metabinkit is developed and tested on multiple distributions of Linux (e.g. Fedora, Ubuntu). Consider the Docker container if you use a non-supported OS or OS version.


#### Getting sources

Option 1: download the latest source release tarball from https://github.com/envmetagen/metabinkit/releases, and then from your download directory type:

    tar xzf mtabinkit-x.x.x.tar.gz
    cd metabinkit-x.x.x

Option 2: to use git to download the repository  with the entire code history, type:

    git clone https://github.com/envmetagen/metabinkit.git
    cd metabinkit


##### Installing metabinkit and dependencies

A full installation of metabinkit requires third-party components. A script (install.sh) is provided to facilitate the installation of metabinkit and some dependencies, others need to be already installed in the system (R 3.6.0 or above). 

To install metabinkit, type:

    ./install.sh  -i $HOME

to install the software to the home folder. A file metabinkit_env.sh will be created on the toplevel installation folder ($HOME in the above example) with the configuration setup for the shell. To enable the configuration is necessary to load the configuration with the source command, e.g., 

    source $HOME/metabinkit_env.sh

or add the above line to the $HOME/.bash_profile file.

### Programs

#### metabin -

Usage: metabin -i xxx ...

##### Expected file formats and contents

The minimum required input for metabin is:
`--input`: a tab-separated file with two compulsory columns: `qseqid` and `pident`; as well as a single column `taxid` OR seven columns `K`,`P`,`C`,`O`,`F`,`G`,`S`
 - `qseqid`: id of the query sequence
 - `pident`: the percentage identity of the alignment
 - `taxids`: NCBI taxid of the database subject sequence        
 - `K`,`P`,`C`,`O`,`F`,`G`,`S`: kingdom, pylum, class, order, family, genus, species of the database subject sequence 
 
 Other columns may be present and will be ignored, unless specified by the `--FilterCol` argument (see How it Works)
 
 
##### How it works

1. The `--input` file is loaded and the headers are checked.
2. (optional) If a `FilterFile` was provided to the `--FilterFile` argument, all rows in the `--input` file containing the corresponding values are removed. The values are searched for in the column of the `--input` file specified by `--FilterCol` [default=sseqid].
   - This is useful, for example, to remove any known or suspected erroneous database entries by their Accession Number.
3. Check if the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns are provided. If not, create them using the `taxids` column and the NCBI taxonomy folder (specified by `--db`, installed by metabinkit by default).
4. (optional) Blacklisting
   - If a `species.blacklist` file was provided to the `--SpeciesBL` argument, remove all rows that contain this species.
   - If a `genus.blacklist` file was provided to the `--GenusBL` argument, remove all rows that contain this genus.
   - If a `family.blacklist` file was provided to the `--FamilyBL` argument, remove all rows that contain this family.
     - Useful to exclude particular taxa that are present in alignment results, but are known *for certain* not to occur in the DNA samples.
     **but see issues**
5. Binning at species rank
    - Remove alignments below the `--Species` %identity threshold.
    - (optional) If each of the following are true:
      - `--sp_discard_sp` Discard species with sp. in the name
      -	`--sp_discard_mt2w` Discard species with more than two words in the name
      -	`--sp_discard_num` Discard species with numbers in the name
        - Useful to avoid final species-level bins such as "Rana sp.", "Rana isolate X4", ...
    - Remove alignments below the `--TopSpecies` %identity threshold (for more on the "Top.." arguments see **below**).
    - For each query, get the lowest common ancestor of all alignments that passed the previous filters.
    - If the lowest common ancestor is at the species rank, this will be the final bin, otherwise carry over to genus-level binning.
 6. Binning at genus, family and above_family ranks. For each rank:
    - Apply only to queries that were not already binned at previous rank.
    - Remove alignments below the respective %identity threshold;`--Genus`,`--Family`,`--AboveF`.
    - Remove alignments below the respective "Top" %identity threshold;`--TopGenus`,`--TopFamily`,`--TopAF`.  
    - For each query, get the lowest common ancestor of all alignments passing the filters.
    - If the lowest common ancestor is at the respective binning rank, consider complete, otherwise carry over to the next binning.
    - For the final, above_family, binning, report the lowest common ancestor, regardless of the rank.  
 7. The output is saved in file specified by `--out` and comprises the columns:
    - `qseqid`: id of the query sequence
    - `pident`: the maximum %identity of alignments used to generate the lowest common ancestor 
    - `min_pident`: the minimum %identity of alignments used to generate the lowest common ancestor 	
    - `K`,`P`,`C`,`O`,`F`,`G`,`S`: kingdom, pylum, class, order, family, genus, species of the assigned bin
    - (optional) If the `-M, --minimal_cols` argument is TRUE, only `qseqid` and `K`,`P`,`C`,`O`,`F`,`G`,`S` columns will be ouput
    - **will need to add desigations (mbk:lca, mbk:npf etc..)**
 8. A second output is created, called FILENAME.info.tsv, where FILENAME = `--out` containing summary information.
 
 ```
 total_hits	134002
total_queries	2828
blacklisted	0
species.level.sp.filter	6
binned.species.level	432
binned.genus.level	1151
binned.family.level	773
binned.htf.level	472
not.binned	0
```


##### Examples

Example 1. Default settings

Input:
```
$ head -n 4 metabinkit/tests/test_files/in0.blast.tsv 
taxids	qseqid	pident
6573	2a8b3c1d-018b-4b9b-933f-eacb26617c02_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD27-A-UNIO-RUN7	68.868
6579	6636e6bc-8729-4013-a303-858d07e783d5_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD23-A-UNIO-RUN7	63.736
6579	5ea8b133-7a4c-479d-9211-7fe0392e1b05_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD24-A-UNIO-RUN7	64.828
```

call metabin
```
$ metabin -i metabinkit/tests/test_files/in0.blast.tsv -o out0.bins.tsv
metabinkit version: 0.0.5
[info] Starting Binning
[info] Read 12259 entries from metabinkit/tests/test_files/in0.blast.tsv
 WARNING! missing columns in input table with taxonomic information:K,P,C,O,F,G,S
[info]  Trying to get taxonomic information from the database in /home/tutorial/TOOLS/metabinkit.install/exe/../db/ ...
[info]  taxonomic information retrieval complete.
[info] Entries blacklisted at species/genus/family level:0
[info] binning at species level
[info] excluding 10139 entries with pident below 96
[info] applying species top threshold of 100
[info] binned 32 sequences at species level
[info] binning at genus level
[info] excluding 8022 entries with pident below 92
[info] applying genus top threshold of 1
[info] binned 116 sequences at genus level
[info] binning at family level
[info] excluding 5934 entries with pident below 90
[info] applying family top threshold of 1
[info] binned 142 sequences at family level
[info] binning at higher-than-family level
[info] excluding 3394 entries with pident below 89
[info] applying htf top threshold of 1
[info] binned 9 sequences at higher than family level
[info] Total number of binned 299 sequences
[info] not binned 1202 sequences
[info] Complete. 12259 hits from 1501 queries processed in 1.8 mins.
[info] Note: If none of the hits for a BLAST query pass the binning thesholds, the results will be NA for all levels.
                 If the LCA for a query is above kingdom, e.g. cellular organisms or root, the results will be 'unknown' for all levels.
                 Queries that had no BLAST hits, or did not pass the filter.blast step will not appear in results.  
[info] binned table written to out0.bins.tsv.tsv
[info] information stats written to out0.bins.tsv.info.tsv
[info] Binning complete in 1.83 min
R version 3.6.0 (2019-04-26)
Platform: x86_64-pc-linux-gnu (64-bit)
Running under: Ubuntu 18.10

Matrix products: default
BLAS:   /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.8.0
LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.8.0

locale:
 [1] LC_CTYPE=pt_PT.UTF-8       LC_NUMERIC=C              
 [3] LC_TIME=pt_PT.UTF-8        LC_COLLATE=en_US.UTF-8    
 [5] LC_MONETARY=pt_PT.UTF-8    LC_MESSAGES=en_US.UTF-8   
 [7] LC_PAPER=pt_PT.UTF-8       LC_NAME=C                 
 [9] LC_ADDRESS=C               LC_TELEPHONE=C            
[11] LC_MEASUREMENT=pt_PT.UTF-8 LC_IDENTIFICATION=C       

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
[1] data.table_1.12.8 optparse_1.6.6   

loaded via a namespace (and not attached):
[1] compiler_3.6.0 magrittr_1.5   tools_3.6.0    getopt_1.20.3  stringi_1.4.6 
[6] stringr_1.4.0 
```




##### *The "Top.." thresholds*

The main %identity thresholds (`--Species`,`--Genus`,`--Family`,`--AboveF`) are absolute minimum thresholds. In contrast, the "Top.." %identity thresholds (`--TopSpecies`,`--TopGenus`,`--TopFamily`,`--TopAF`) are additional relative minimum thresholds. For each query, the "Top.." threshold is the %identity of the best hit minus the "Top.." value. In the example below, a "Top.." of 2 corresponds to 97.8 and alignments below this are discarded prior to binning. A "Top.." of 5 corresponds to 94.8, so alignments below this are discarded.    

```
qseqid taxids pident
query1 1234 99.8
query1 1234 99.6
query1 12345 97.7
query1 12345 97.6
query1 12345 97.6
query1 123456 94.8
query1 123456 94.8
query1 123456 93.6
```

"Top.." will mainly affect the resolution of the results. The lower the "Top.." value, the greater the number of alignments discarded. As is also required for the main %identity thresholds, "Top.." thresholds should be identifed empirically. Below is an illustration of how "Top.." can affect results, when using an identical main %identity. 

```
#Query1
P	C	O	F	pident
phy1	cla1	ord1	fam1	85 
phy1	cla1	ord1	fam1	84
phy1	cla1	ord1	fam1	84
phy1	cla1	ord1	fam1	83
phy1	cla1	ord1	fam2	79
phy1	cla1	ord1	fam2	78
phy1	cla1	ord2	fam3	74
phy1	cla1	ord2	fam3	70
phy1	cla2	ord3	fam4	60

settings			bin             reason
--TopFamily=1,--Family=70	fam1 alignments below 70 are removed, additionally alignments below 84 are removed
--TopFamily=2,--Family=70	fam1 alignments below 70 are removed, additionally alignments below 83 are removed
--TopFamily=5,--Family=70	fam1 alignments below 70 are removed, additionally alignments below 80 are removed
--TopFamily=8,--Family=70	ord1 alignments below 70 are removed, additionally alignments below 77 are removed
--TopFamily=10,--Family=70	ord1 alignments below 70 are removed, additionally alignments below 75 are removed
--TopFamily=15,--Family=70	cla1 alignments below 70 are removed, additionally alignments below 70 are removed
--TopFamily=30,--Family=70	phy1 alignments below 70 are removed, additionally alignments below 55 are removed

```



#### metabinblast -

