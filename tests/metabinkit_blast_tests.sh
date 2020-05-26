#!/usr/bin/env bash

PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )

set -u
source $PATH2SCRIPT/tests_aux.sh

function comp_tables {
    f1=$1
    f2=$2
    #t1=$(mktemp)
    #t2=$(mktemp)
    t1=$f1.tmp
    t2=$f2.tmp
    #tail -n +2 $f1|sort > $t1
    #tail -n +2 $f2|sort > $t2
    
    #rm -f $t1 $t2
}
echo "*** metabinkit_blast* tests"

set +xe


must_fail "metabinkit_blast &> /dev/null"
must_fail "metabinkit_blastgendb &> /dev/null"

must_fail "metabinkit_blast -i &> /dev/null"
must_fail "metabinkit_blastgendb -i &> /dev/null"

must_fail "metabinkit_blast -f &> /dev/null"
must_fail "metabinkit_blastgendb -f &> /dev/null"

must_fail "metabinkit_blast -f _file_does_not_exist&> /dev/null"
must_fail "metabinkit_blastgendb -f _file_does_not_exist &> /dev/null"

must_fail "metabinkit_blast -f tests/test_files/test_db.fasta &> /dev/null"

must_fail "metabinkit_blastgendb -f tests/test_files/test_db.fasta &> /dev/null"

must_fail "metabinkit_blastgendb -f tests/test_files/test_db.fasta -o &> /dev/null"


must_succeed "metabinkit_blastgendb -f tests/test_files/test_db.fasta -o test"
## test.taxid_map.tsv generated before
must_succeed "metabinkit_blastgendb -f tests/test_files/test_db.fasta -o test2 -T test.taxid_map.tsv"
must_succeed "metabinkit_blastgendb -f tests/test_files/test_db.fasta -o test2 -T test.taxid_map.tsv -n 4"


must_fail "metabinkit_blast -f tests/test_files/test_db.fasta -D test &> /dev/null"
must_succeed "metabinkit_blast -f tests/test_files/query.fasta  -D test -o res1 "
must_succeed "metabinkit_blast -f tests/test_files/query.fasta  -D test -o res2  -M 5"
echo 228297 > .postaxids.txt
must_succeed "metabinkit_blast -f tests/test_files/query2.fasta  -D test -o res1 "
must_succeed "metabinkit_blast -f tests/test_files/query2.fasta  -D test -o res1 -P .postaxids.txt"
must_succeed "[ $(cat res1|wc -l ) == 10 ]"
must_succeed "metabinkit_blast -f tests/test_files/query2.fasta  -D test -o res1 -N .postaxids.txt"
must_succeed " [ $(grep -c -f .postaxids.txt res1) == 0 ]"
must_fail "metabinkit_blast -f tests/test_files/query2.fasta  -D test -o res1 -N .postaxids.txt -P .postaxids.txt &> /dev/null"
rm -f .postaxids.txt res1 res2

echo Failed tests: $num_failed
echo Number of tests: $num_tests
exit $num_failed

