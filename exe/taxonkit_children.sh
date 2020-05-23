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


PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )


## taxonkit ok?
command -v taxonkit  >/dev/null 2>&1 || { echo "ERROR: $cmd  does not seem to be installed.  Aborting." >&2; exit 1; }


##
IFILE=$1
OFILE=$2
PATH2DB=$3

if [ "$OFILE-" == "-" ]; then
    echo "ERROR: missing arguments"
    echo "Usage: taxonkit_children.sh file_taxids out_file [path_to_folder_with_taxonomy]"
    echo "Note: input file with taxids should contain one taxid per line"
    exit 1
fi

set -eu -o pipefail

EXTRA=
if [ "$PATH2DB-" == "-" ]; then
    if [ -e $PATH2SCRIPT/../db/nodes.dmp ]; then
	# using this directory
	PATH2DB=$PATH2SCRIPT/../db/
    fi
fi
if [ ! -e $IFILE ]; then
    echo "File $IFILE not found"
    exit 1
fi

if [ "$PATH2DB-" != "-" ]; then
    if [ ! -e $PATH2DB ]; then
	echo "Folder $PATH2DB not found"
	exit 1
    fi

    EXTRA=" --data-dir $PATH2DB"
fi

rm -f $OFILE $OFILE.tmp ${OFILE}_i_*
# split the file into batches of 250
split -l 400 $IFILE ${OFILE}_i_

touch $OFILE.tmp
ls -1 ${OFILE}_i_* | while read f; do
    LIST=$(cat $f|tr "\n" ",")
    taxonkit list  --ids $LIST $EXTRA --indent '' --show-name | cut -f 2- -d\ >>  $OFILE.tmp
done
mv $OFILE.tmp $OFILE
rm -f ${OFILE}_i_*
exit 0
