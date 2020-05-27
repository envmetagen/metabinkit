#
## metabinkit
![Docker](https://github.com/envmetagen/metabinkit/workflows/Docker/badge.svg?branch=master) [![Dockerhub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/envmetagen/metabinkit/tags/) [![DOI](https://zenodo.org/badge/265322807.svg)](https://zenodo.org/badge/latestdoi/265322807) [![License](http://img.shields.io/badge/license-GPL%203-brightgreen.svg?style=flat)](http://www.gnu.org/licenses/gpl-3.0.html) 

Set of programs to perform taxonomic binning.

1. [Overview](#Overview)
2. [Docker](#Docker)
2. [Manual installation](#Manual-installation)
3. [Metabinkit programs](#Programs)


### Overview
From metagenomic or metabarcoding data, it is often necessary to assign taxonomy to DNA sequences. This is generally performed by aligning sequences to a reference database, usually resulting in multiple database alignments for each query sequence. Using these alignment results, metabinkit assigns a single taxon to each query sequence, based on user-defined percentage identity thresholds. In essence, for each query, the alignments are filtered based on the percentage identity thresholds and the lowest common ancestor for all alignments passing the filters is determined. The metabin program is not limited to BLAST alignments, and can accept alignment results performed using any software, provided the input format is correct. However, functionality is also available to create BLAST databases and to perform BLAST alignments, which can be passed directly to metabin.  

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

##### How it works

1. The `--input` file is loaded and the headers are checked.
2. (optional) If a `FilterFile` was provided to the `--FilterFile` argument, all rows in the `--input` file containing the corresponding values are removed. The values are searched for in the column of the `--input` file specified by `--FilterCol` [default=sseqid].
   - This is useful, for example, to remove any known or suspected erroneous database entries by their Accession Number.
3. Check if the `K`,`P`,`C`,`O`,`F`,`G`,`S` columns are provided. If not, create them using the `taxids` column and the NCBI taxonomy folder (specified by `-D`, installed by metabinkit by default).
4. (optional) Blacklisting
   - If a `species.blacklist` file was provided to the `--SpeciesBL` argument, remove all rows that contain this species.
   - If a `genus.blacklist` file was provided to the `--GenusBL` argument, remove all rows that contain this genus.
   - If a `family.blacklist` file was provided to the `--FamilyBL` argument, remove all rows that contain this family.
     - Useful to exclude particular taxa that are present in alignment results, but are known *for certain* not to occur in the DNA samples.
     **but see issues**
5. Binning at species rank
    - Remove alignments below the `--Species` %identity threshold.
    - (optional) If `--discard_sp` is TRUE, remove species with "sp.", numbers or more than one space in their names.
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
    
*The "Top.." thresholds*

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
                


##### Examples

#### metabinblast -

