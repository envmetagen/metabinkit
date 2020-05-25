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
echo "*** metabin tests"

set +xe
must_fail "metabin &> /dev/null"
must_fail "metabin -i  &> /dev/null"
must_fail "metabin -i _file_does_not_exist  &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --SpeciesBL _file_does_not_exist  &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --GenusBL _file_does_not_exist  &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --FamilyBL _file_does_not_exist  &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --FamilyBL   &> /dev/null"


## percentage identity thresholds used
## 99 % for species level
## 97 % for genus level
## 95 % for family level
## 93 % for higher-than-family level;
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0"
# check output
must_succeed "diff -q <(tail -n +2 .metabin.test.out.tsv|sort) <(tail -n +2  tests/test_files/out1.tsv|sort ) "

must_succeed "metabin -M -i tests/test_files/in2.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0"
must_succeed "diff -q <(tail -n +2 .metabin.test.out.tsv|sort) <(tail -n +2  tests/test_files/out2.tsv|sort ) "

must_succeed "metabin -M -i tests/test_files/in0.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0"

#must_succeed "metabin -M -i tests/test_files/in3.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0"

#############################
## blacklisting
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FamilyBL tests/test_files/families2exclude.txt"
must_succeed "[ `cat .metabin.test.out.tsv|wc -l ` == 1 ]"

must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --GenusBL tests/test_files/genera2exclude.txt"

#1069815 Sinanodonta woodiana
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --SpeciesBL tests/test_files/ids2exclude.txt"
must_succeed "[ `grep -c 'Sinanodonta woodiana' .metabin.test.out.tsv` == 0 ]"

must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --SpeciesBL tests/test_files/ids2exclude.txt --GenusBL tests/test_files/genera2exclude.txt"
must_succeed "[ `grep -c 'Sinanodonta woodiana' .metabin.test.out.tsv` == 0 ]"

## FilterFile and FilterCol
echo 45949 > ./blacklist.txt
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol taxids"
must_succeed "[ $(cat .metabin.test.out.tsv|grep -c "Corbicula fluminea") == 0 ]"

## File not present or not give
must_fail "metabin -i tests/test_files/in1.blast.tsv --Filter   &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --Filter  _file_does_not_exist  &> /dev/null"

# column not present
must_fail "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol taxids_typo"
must_fail "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol "

echo Failed tests: $num_failed
echo Number of tests: $num_tests
exit $num_failed

