#
## metabinkit
[![Dockerhub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/nunofonseca/fastq_utils/tags/) [![License](http://img.shields.io/badge/license-GPL%203-brightgreen.svg?style=flat)](http://www.gnu.org/licenses/gpl-3.0.html) 


### Programs

#### metabin -

Usage: metabin -i xxx ...

##### Expected file formats and contents

##### Examples

#### metabinblast -

### Installation

A docker image with metabinkit is avalilable at DockerHub (). Alternatively you may install the software from source following the instructions provided next. A  64bit computer with an up to date Linux OS installed will be required.

#### Building from source

##### Dependencies

##### Getting sources

Option 1: download the latest source release tarball from https://github.com/envmetagen/metabinkit/releases, and then from your download directory type:

    tar xzf mtabinkit-x.x.x.tar.gz
    cd metabinkit-x.x.x

Option 2: to use git to download the repository  with the entire code history, type:

    git clone https://github.com/envmetagen/metabinkit.git
    cd metabinkit


##### Installing metabinkit and some dependencies

A script (install.sh) is provided to facilitate the installation of
metabinkit and some dependencies, namely a few R packages, taxonkit,
BLAST and taxonomy database (from NCBI).

To install metabinkit, type:

    ./install.sh  -i $HOME

to install the software to the home folder. A file metabinkit_env.sh will be created on the toplevel installation folder ($HOME in the above example) with the configuration setup for the shell. To enable the configuration is necessary to load the configuration with the source command, e.g., 

    source $HOME/metabinkit_env.sh

or add the above line to the $HOME/.bash_profile file.



