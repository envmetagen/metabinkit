#!/usr/bin/env bash
#######################################################################
# Nuno A. Fonseca (nuno dot fonseca at gmail dot com)
#
# This is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
########################################################################

set -e -o pipefail

## default installation folder
INSTALL_DIR=/opt/

###########################################

ALL_TOOLS="taxonkit blast metabinkit R_packages taxonomy_db"

SYSTEM_DEPENCIES="R bash"

blast_VERSION=2.10.0
blast_URL=ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-${blast_VERSION}+-x64-linux.tar.gz

TAXONKIT_VERSION=0.6.0
TAXONKIT_URL=https://github.com/shenwei356/taxonkit/releases/download/v${TAXONKIT_VERSION}/taxonkit_linux_amd64.tar.gz

###########################################
#
function pinfo {
    echo "[INFO] $*"
}

###########################################
# 

function check_system_deps {
    local bin
    pinfo "Checking dependencies..."
    local MISSING=0
    for bin in $SYSTEM_DEPS; do
        local PATH2BIN=`which $bin 2> /dev/null`
        if [ "$PATH2BIN-" == "-" ]; then
            pinfo " $bin not found!"
            #
            MISSING=1
        else
            pinfo " $bin found: $PATH2BIN"
        fi
    done
    pinfo "Checking dependencies...done."
    if [ $MISSING == 1 ]; then
        pinfo "ERROR: Unable to proceed"
        exit 1
    fi

}

check_system_deps

###########################################

function install_taxonkit {
    pinfo "Installing taxonkit.."
    rm -f tmp.tar.gz
    wget -c  $TAXONKIT_URL -O tmp.tar.gz
    tar xzvf tmp.tar.gz
    mkdir -p $INSTALL_DIR/bin
    chmod +x taxonkit
    mv taxonkit $INSTALL_DIR/bin
    rm -f tmp.tar.gz
    pinfo "Installing taxonkit..done."
}

function install_taxonomy_db {
    pinfo "Installing taxonomy database..."
    rm -f taxdump.tar.gz
    wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz
    mkdir -p $INSTALL_DIR/db
    tar xzvf taxdump.tar.gz -C $INSTALL_DIR/db
    echo Downloaded `date` > $INSTALL_DIR/db/taxonomy.info
    rm -f taxdump.tar.gz
    pinfo "Installing taxonomy database...done"
}

function install_blast {
	pinfo "Installing blast to $BLAST_IDIR..."
	pushd $TMP_DIR
	rm -f tmp.tar.gz
	set +e
	if [ ! -e $BLAST_IDIR/bin ]; then
	    mkdir -p $BLAST_IDIR/bin
	fi
	if [ ! -e $BLAST_IDIR/db ]; then
	    mkdir -p $BLAST_IDIR/db
	fi
	set -e
	wget -c $blast_URL -O tmp.tar.gz
	tar zxvpf tmp.tar.gz
	rm -f tmp.tar.gz
	cp ncbi-blast-${blast_VERSION}+/bin/* $BLAST_IDIR/bin
	## taxonomy
	wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
	mv taxdb.tar.gz $BLAST_IDIR/db
	pushd $BLAST_IDIR/db
	tar xzvf taxdb.tar.gz
	rm -f taxdb.tar.gz
	popd
	popd
	##      
	pinfo "Installing blast...done."
}


function install_R_packages {
    pinfo "Installing R packages to $INSTALL_DIR/Rlibs ..."
    mkdir -p $INSTALL_DIR/Rlibs
    R_LIBS_USER=$INSTALL_DIR/Rlibs R --vanilla <<EOF
repo<-"http://www.stats.bris.ac.uk/R/"

########################
# Check if version is ok
version <- getRversion()
currentVersion <- sprintf("%d.%d", version\$major, version\$minor)
message("R version:",version)
usebiocmanager<-TRUE
if ( version\$major < 3 || (version\$major>=3 && version\$minor<5) ) {
  cat("ERROR: R version should be 3.5 or above\n")
  q(status=1)
}

########################
# Where to install the packages
assign(".lib.loc",.libPaths()[1],envir=environment(.libPaths))

message("Using library: ", .libPaths()[1])
##print(.libPaths())

message("_____________________________________________________")

if (version\$major > 3 || (version\$major == 3 && version\$minor>5)) {
   if (!requireNamespace("BiocManager", quietly = TRUE))
       install.packages("BiocManager",repo=repo)
   BiocManager::install()
} else {
   usebiocmanager<-FALSE
   source("http://bioconductor.org/biocLite.R")
} 

message("_____________________________________________________")

message("Installing packages")
packages2install<-c("Matrix","data.table","optparse")

for (p in packages2install ) {
  message("PACKAGE:",p,"\n")
  if ( usebiocmanager ) BiocManager::install(p,ask=FALSE)
  else  biocLite(p,ask=FALSE)
}


EOF

    pinfo "Installing R packages to $INSTALL_DIR/Rlibs ...done."
}


function create_metabinkit_env {
    pinfo "Creating $INSTALL_DIR/metabinkit_env.sh..."
    cat <<EOF  > $INSTALL_DIR/metabinkit_env.sh
export PATH=$BLAST_IDIR/bin:\$PATH
export PATH=$INSTALL_DIR/python/bin/:$INSTALL_DIR/bin:$INSTALL_DIR/exe:\$PATH
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:\$LD_LIBRARY_PATH
export R_LIBS_USER=$INSTALL_DIR/Rlibs:$R_LIBS_USER
export BLASTDB=$BLAST_IDIR/db
EOF

cat <<EOF 
You may want to consider adding the following line to your .bash_profile file.

source $INSTALL_DIR/metabinkit_env.sh




EOF
    pinfo "Creating $INSTALL_DIR/metabinkit_env.sh...done."
}

function install_metabinkit {
    pinfo "Installing metabinkit..."
    cp -vrua R exe $INSTALL_DIR
    create_metabinkit_env
    pinfo "Installing metabinkit...done."    
}

function usage {
    echo "Usage: install.sh [-i toplevel_folder_to_install_mbk -x soft name -h -H]
Options:
  -C     - Conda installation mode
  -T     - skip installation of taxonkit
  -h     - print this help information"
}

## by default install all software
MODE=all
DEBUG=0
SKIP_taxonkit=0
SKIP_R_packages=0
CONDA_INSTALL=0

while getopts "i:x:CThH"  Option
do
    case $Option in
	i ) INSTALL_DIR=$OPTARG;;
	x ) MODE=$OPTARG;;
	T ) SKIP_taxonkit=1;;
	C ) CONDA_INSTALL=1;;
	h ) usage; exit;;
	H ) usage; exit;;
	* ) usage; exit 1;;
    esac
done

if [ ! -e  $INSTALL_DIR ]; then
    echo "Creating $INSTALL_DIR..."
    mkdir -p $INSTALL_DIR
    echo "Creating $INSTALL_DIR...done."
fi
INSTALL_DIR=$(readlink -f $INSTALL_DIR)

TMP_DIR=$(mktemp -d)
mkdir -p $TMP_DIR

#BLAST_IDIR=$INSTALL_DIR/blast/${blast_VERSION}
BLAST_IDIR=$INSTALL_DIR

if [ "$CONDA_INSTALL-" == "1-" ]; then
    SKIP_taxonkit=1
    SKIP_R_packages=1
fi

if [ "$MODE-" == "all-" ]; then
    for t in $ALL_TOOLS; do
	if [ $t == "taxonkit" ] && [ $SKIP_taxonkit == 1 ]; then
	    echo "skipping installation of $t "
	else
	    if [ $t == "R_packages" ] && [ $SKIP_R_packages == 1 ]; then
		echo "skipping installation of $t "
	    else
		
		install_$t
	    fi
	fi
    done
else
    install_$MODE
fi


echo "---------------------------------------------------"
echo "metabinkit and dependecies installed on $INSTALL_DIR"
echo "All done."
exit 0
