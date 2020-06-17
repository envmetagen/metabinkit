#!/bin/env bash
# =========================================================
# Copyright 2020
#
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
#
#
# =========================================================
# useful functions
metabinkit_version="0.1.8"

function print_metabinkit_version {
    echo "metabinkit version: $metabinkit_version"
}

function check_blast_version {
    min_version_required="2.9.0"
    
    local BLAST_VERSION=$(blastn -version | tail -n 1 | cut -f 4 -d\ |sed "s/,$//")
    IFS='.' read -ra BLAST_VERSION_A <<< "$BLAST_VERSION"
    local BLAST_MAJOR=${BLAST_VERSION_A[0]}
    local BLAST_MINOR=${BLAST_VERSION_A[1]}
    local BLAST_PATCH=${BLAST_VERSION_A[2]}
    let cur_version=$BLAST_MAJOR*100000+$BLAST_MINOR*100+$BLAST_PATCH
    IFS='.' read -ra MBLAST_VERSION_A <<< "$min_version_required"
    local MBLAST_MAJOR=${MBLAST_VERSION_A[0]}
    local MBLAST_MINOR=${MBLAST_VERSION_A[1]}
    local MBLAST_PATCH=${MBLAST_VERSION_A[2]}
    let min_version=$MBLAST_MAJOR*100000+$MBLAST_MINOR*100+$MBLAST_PATCH
    if [ $cur_version -lt $min_version ]; then
	echo "ERROR: blast version is $BLAST_VERSION but expected $min_version_required or above"
	exit 1
    fi
}
