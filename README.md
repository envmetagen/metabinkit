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

To install metabinkit to the home folder, type:

    ./install.sh  -i $HOME

A file metabinkit_env.sh will be created on the toplevel installation folder ($HOME in the above example) with the configuration setup for the shell. To enable the configuration is necessary to load the configuration with the source command, e.g., 

    source $HOME/metabinkit_env.sh

This needs to be run each time a terminal is opened, or add the above line to the $HOME/.bash_profile file.

To only install certain programs/dependencies use the `-x` argument, e.g.

`./install.sh  -i $HOME -x taxonkit`

Available options for `-x` are: `taxonkit`, `blast`, `metabinkit`, `R_packages`, `taxonomy_db`

### Programs

#### metabin

Usage: metabin -i xxx ...

run `metabin -h` for a list of all options and defaults

##### Expected file formats and contents

The minimum required input for metabin is:
`-i, --input`: a tab-separated file with two compulsory columns: `qseqid` and `pident`; as well as a single column `taxids` OR seven columns `K`,`P`,`C`,`O`,`F`,`G`,`S`
 - `qseqid`: id of the query sequence
 - `pident`: the percentage identity of the alignment
 - `taxids`: NCBI taxid of the database subject sequence        
 - `K`,`P`,`C`,`O`,`F`,`G`,`S`: kingdom, pylum, class, order, family, genus, species of the database subject sequence 
 
 Other columns may be present and will be ignored, unless specified by the `--FilterCol` argument (see **How it Works**)
 
 
##### How it works

1. The `-i, --input` file is loaded and the headers are checked.
2. (optional) If a `FilterFile` was provided to the `--FilterFile` argument, all rows in the `-i, --input` file containing the corresponding values are removed. The values are searched for in the column of the `-i, --input` file specified by `--FilterCol` [default=sseqid].
   - This is useful, for example, to remove any known or suspected erroneous database entries by their Accession Number.
3. Check if the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns are provided. If not, create them using the `taxids` column and the NCBI taxonomy folder (specified by `-D, --db`, installed by metabinkit by default).
4. (optional) Blacklisting
   - If a `species.blacklist` file was provided to the `--SpeciesBL` argument, remove all rows that contain this species.
   - If a `genus.blacklist` file was provided to the `--GenusBL` argument, remove all rows that contain this genus.
   - If a `family.blacklist` file was provided to the `--FamilyBL` argument, remove all rows that contain this family.
     - Useful to exclude particular taxa that are present in alignment results, but are known *for certain* not to occur in the DNA samples.
     **but see issues**
5. Binning at species rank
    - Remove alignments that do not contain species rank information for the database reference alignment (i.e. where column `S`="unknown").   
    - Remove alignments below the `-S, --Species` %identity threshold.
    - (optional) If each of the following are true:
      - `--sp_discard_sp` Discard species with sp. in the name
      -	`--sp_discard_mt2w` Discard species with more than two words in the name
      -	`--sp_discard_num` Discard species with numbers in the name
      - These are useful to avoid final species-level bins such as "Rana sp.", "Rana isolate X4". For example, [GenBank: AB714021.1](https://www.ncbi.nlm.nih.gov/nuccore/385251100) has the taxid 1176287, which equates to Metazoa, Nematoda, unknown, unknown, unknown, unknown, Nematoda sp. ZTSP69 in the classical seven-rank taxonomy. 
    - Remove alignments below the `--TopSpecies` %identity threshold (for more on the "Top.." arguments see **below**). The default is 100, which effectively means it is not used.
    - For each query, get the lowest common ancestor of all alignments that passed the previous filters.
    - If the lowest common ancestor is at the species rank, this will be the final bin, otherwise carry over to genus-level binning.
 6. Binning at genus, family and above_family ranks. For each rank:
    - Apply only to queries that were not already binned at previous rank.
    - Remove alignments that do not contain the respective rank information for the database reference alignment
    - Remove alignments below the respective %identity threshold;`-G, --Genus`,`-F, --Family`,`-A, --AboveF`.
    - Remove alignments below the respective "Top" %identity threshold;`--TopGenus`,`--TopFamily`,`--TopAF`.  
    - For each query, get the lowest common ancestor of all alignments passing the filters.
    - If the lowest common ancestor is at the respective binning rank, consider complete, otherwise carry over to the next binning.
    - For the final, above_family, binning, report the lowest common ancestor, regardless of the rank.  
 7. The output is saved in file specified by `-o, --out` and comprises the columns:
    - `qseqid`: id of the query sequence
    - `pident`: the maximum %identity of alignments used to generate the lowest common ancestor 
    - `min_pident`: the minimum %identity of alignments used to generate the lowest common ancestor 	
    - `K`,`P`,`C`,`O`,`F`,`G`,`S`: kingdom, pylum, class, order, family, genus, species of the assigned bin
    - (optional) If the `-M, --minimal_cols` argument is TRUE, only `qseqid` and `K`,`P`,`C`,`O`,`F`,`G`,`S` columns will be ouput
    - **will need to add desigations (mbk:lca, mbk:npf etc..)**
 8. A second output is created, called FILENAME.info.tsv, where FILENAME = `-o, --out` containing summary information.
 
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

run metabin **rerun once new defaults for tops have been updated**

`$ metabin -i metabinkit/tests/test_files/in0.blast.tsv -o out0.bins`

Explanation: Do not filter any alignments based on Accession Number or blacklisted taxa. Do not apply any "Top.." thresholds. Attempt to bin alignments with the following %identity thresholds: species-96%, genus-96%, family-90%, above family-89%. Use `taxids` column to retrieve taxonomy.

screen output (stderr)

```
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
[info] binned table written to out0.bins.tsv
[info] information stats written to out0.bins.info.tsv
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

view results

```
$ head -4 out0.bins.tsv 
qseqid	pident	min_pident	K	P	C	O	F	G	S
6fcff7c8-2031-4e3a-a8f0-72dc2da71c79_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD11-A-UNIO-RUN7	97.015	-2.985	Eukaryota	Mollusca	Bivalvia	Unionida	Unionidae	Sinanodonta	Sinanodonta woodiana
d36ef3ba-f3d5-4952-b683-301f1a959cfa_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD11-A-UNIO-RUN7	100	0	Eukaryota	Mollusca	Bivalvia	Unionida	Unionidae	Sinanodonta	Sinanodonta woodiana
9ef96e73-a5b6-4c4f-bc59-2b8238281d77_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD24-A-UNIO-RUN7	97.059	-2.941	Eukaryota	Mollusca	Bivalvia	Unionida	Unionidae	Sinanodonta	Sinanodonta woodiana
```

Example 2. Custom settings

Inputs:

```
$ head -n 4 metabinkit/tests/test_files/in1.blast.tsv 
taxids	qseqid	pident	qcovs	saccver	staxid	ssciname	old_taxids	K	P	C	O	F	G	S
6573	2a8b3c1d-018b-4b9b-933f-eacb26617c02_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD27-A-UNIO-RUN7	68.868	98	XM_021507581.16573	Mizuhopecten yessoensis	6573	Eukaryota	Mollusca	Bivalvia	Pectinoida	Pectinidae	Mizuhopecten	Mizuhopecten yessoensis
6579	6636e6bc-8729-4013-a303-858d07e783d5_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD23-A-UNIO-RUN7	63.736	99	LR736849.1	6579	Pecten maximus	6579	Eukaryota	Mollusca	Bivalvia	Pectinoida	Pectinidae	Pecten	Pecten maximus
6579	5ea8b133-7a4c-479d-9211-7fe0392e1b05_runid=407cb32920f83b2252d840c6a949244d8c2a3bb9_ss_sample_id=Mussels-ITD24-A-UNIO-RUN7	64.828	99	LR736843.1	6579	Pecten maximus	6579	Eukaryota	Mollusca	Bivalvia	Pectinoida	Pectinidae	Pecten	Pecten maximus
```

From previous experience we have identified a sequence in genbank that appears erroneous, so we provide that in a file.

6573

run metabin **rerun once new defaults for tops have been updated**

`$ metabin -i in1.blast.tsv -o out1.bins -S 99 -G 97 -F 95 -A 90 --SpeciesBL testspecies2exclude.txt --FilterFile acc2exclude.tsv --FilterCol saccver --TopSpecies 2 --TopGenus 2 --TopFamily 2 --TopAF 2 --sp_discard_sp --sp_discard_mt2w --sp_discard_num`

Explanation: First remove any alignments that have the erroneuos Accession Number. During species-level binning remove any species that we have blacklisted. Furthermore, during species-level binning do not consider species with "sp.", more than two spaces, or numbers in their names. Apply a "Top.." threshold of 2 for all binning rounds. Attempt to bin alignments with the following %identity thresholds: species-99%, genus-97%, family-95%, above family-90%. Use the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns as the taxonomy.

screen output (stderr)

**not complete**

#### metabinkit_blast

Usage: metabinkit_blast -i xxx ...

run `metabin -h` for a list of all options and defaults

#### metabinkit_blastgendb

### FAQs

#### How do "Top.." thresholds work and what are their effects?

The main %identity thresholds (`-S, --Species`,`-G, --Genus`,`_F, --Family`,`-A, --AboveF`) are absolute minimum thresholds. In contrast, the "Top.." %identity thresholds (`--TopSpecies`,`--TopGenus`,`--TopFamily`,`--TopAF`) are relative minimum thresholds, applied after the main %identity. For each query, the "Top.." threshold is the %identity of the best hit minus the "Top.." value. In the example below, a "Top.." of 2 corresponds to 97.8 and alignments below this are discarded prior to binning. A "Top.." of 5 corresponds to 94.8, so alignments below this are discarded.    

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

Using a very low "Top.." threshold, e.g. 0.001, unless justified, is likely prone to over-classifying the sequence to the incorrect taxonomy, as many very similar alignments will be discarded. Nevertheless, if the best alignment for a query has e.g. a %identity of 85, and the family level threshold (`-F, --Family`) is low e.g. 70%, it is reasonable to apply a `--TopFamily` threshold to only consider alignments within a certain range of the best alignment, increasing the likelihood of binning at family level.

#### Why is only the classical seven-rank taxonomy considered?

1. This is the usual format used in this field of research, and can be extracted from most databases
2. Version 2 will be extended to include subspecies
3. Catering for all potential ranks would produce different outputs which would complicate downstream analyses

#### Why are binning thresholds specifically implemented at species, genus and family ranks, but for above family are combined? 

1. `metabin` will report the final bins obtained for all ranks, even if they could not be assigned at family rank.
2. In the classical seven rank taxonomy, the NCBI taxonomy almost always has information at the species, genus and family ranks, but is often missing this information for phylum, class and order rank, making it difficult to apply thresholds at every level. For example, the NCBI taxid 570251, a species of Platyhelminthes, *Catenula turgida*, has the taxonomy  Eukaryota, Platyhelminthes, Catenulida, unknown, Catenulidae, Catenula, Catenula turgida
3. The `--TopAF` argument is effectively an order-level threshold, and `metabin` will assign at order rank where possible (i.e. the lowest common ancestor is at the order rank and this order is not "unknown"). Where order-level assignation fails it will report the lowest common ancestor regardless of the rank.   

#### I have performed alignments, but do not have NCBI taxids, how can I use metabin?

1. Providing the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns in the `-i, --input` file will avoid using the NCBI taxonomy
2. If you have neither the NCBI taxids nor the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns and only have taxon names, NCBI taxids can be generated from these using the [NCBI TaxIdentifier](https://www.ncbi.nlm.nih.gov/Taxonomy/TaxIdentifier/tax_identifier.cgi). Be careful to double check the results make sense, and understand the error codes (e.g. duplicates, not found etc.). Or consider using [taxonkit](https://bioinf.shenwei.me/taxonkit/)
3. Consider using `metabinblast` to align sequences to your reference database. This will output the taxids of the reported alignments.  

#### How do I choose thresholds?

`metabin` is not a classifer, in that it does not attempt to find optimal binning thresholds. All settings are user-defined. The thresholds should be based on an analysis of the target DNA region. It is possible that a future version of metabinkit will include classifer functionality. For further reading consider exploring:

- [Alberdi et al. 2017 Scrutinizing key steps for reliable metabarcoding of environmental samples](https://doi.org/10.1111/2041-210X.12849)
- [Richardson et al. 2016 Evaluating and optimizing the performance of software commonly used for the taxonomic classification of DNA metabarcoding sequence data](https://doi.org/10.1111/1755-0998.12628)
- [Elbrecht et al. 2017 PrimerMiner : an r package for development and in silico validation of DNA metabarcoding primers](https://doi.org/10.1111/2041-210X.12687)
- [Ficetola et al. 2010 An In silico approach for the evaluation of DNA barcodes](https://doi.org/10.1186/1471-2164-11-434)
- [Riaz et al. 2011 ecoPrimers: inference of new DNA barcode markers from whole genome sequence analysis](https://doi.org/10.1093/nar/gkr732)







