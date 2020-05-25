#
## metabinkit
[![Dockerhub](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/nunofonseca/metabinkit/tags/) [![DOI](https://zenodo.org/badge/xxxx.svg)](https://zenodo.org/badge/latestdoi/xxxx) [![License](http://img.shields.io/badge/license-GPL%203-brightgreen.svg?style=flat)](http://www.gnu.org/licenses/gpl-3.0.html) 

Set of programs to perform taxonomic binning.

1. [Docker](#Docker)
2. [Manual installation](#Manual-installation)
3. [Metabinkit programs](#Programs)


### Docker

A docker image that includes everything required to run with metabinkit is available at DockerHub (xxxxxxxxxxxxxxxxx). This facilitates the setup and installation of metabinkit, makes it easy to track all software versions used in the analyses, and ensures that only dependency versions compatible with metabinkit are used. See the [Docker userguide](https://docs.docker.com/) for more details.

Alternatively you may install the software from source following the instructions provided next. A  64bit computer with an up to date Linux OS installed will be required.
We provide a container that wraps everything required to run a BUSCO analysis. T(v4.0.5_cv1 identifies all components at once). 


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

##### Examples

#### metabinblast -

