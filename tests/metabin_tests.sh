#!/usr/bin/env bash

PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )

set -u
source $PATH2SCRIPT/tests_aux.sh


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
must_succeed "metabin --version"
must_succeed "metabin -v"

echo woodiana > list1.lst
echo elongatulus >> list1.lst


must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --no_mbk --TopSpecies 1 --SpeciesNegFilter list1.lst "

must_succeed " [ $(grep -c 'woodiana' .metabin.test.out.tsv ) == 0 ]"
must_succeed " [ $(grep -c 'elongatulus' .metabin.test.out.tsv ) == 0 ]"

must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --no_mbk --TopSpecies 1"
# check output
must_succeed "diff -q <(tail -n +2 .metabin.test.out.tsv|sort -k 1,1h) <(tail -n +2  tests/test_files/out1.tsv|sort -k1,1h ) "


# metabin  -i ex0.tsv -o .ex0 -S 99.0 -G 97.0 -F 95.0 -A 93.0 --TopSpecies 1
# metabin  -i ex1.tsv -o .ex0 -S 99.0 -G 93.0 -F 92.0 -A 91.0 --TopSpecies 100 --TopGenus 10
# lca

must_succeed "metabin -M -i tests/test_files/in2.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0  --no_mbk --TopSpecies 1"
must_succeed "diff -q <(tail -n +2 .metabin.test.out.tsv|sort) <(tail -n +2  tests/test_files/out2.tsv|sort ) "

must_succeed "metabin -M -i tests/test_files/in0.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0"

must_succeed "metabin -M -i tests/test_files/in3.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0  --no_mbk --TopSpecies 1"

must_succeed "metabin -M -i tests/test_files/in3_missing_taxids.blast.tsv -o .metabin.test2.out -S 99.0 -G 97.0 -F 95.0 -A 93.0  --no_mbk --TopSpecies 1"

## Previous two runs should produce a table with the same number of lines
must_succeed "[ $(cat .metabin.test.out.tsv|wc -l) == $(cat .metabin.test2.out.tsv|wc -l) ]"

must_succeed "metabin -i tests/test_files/in4.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_sp --sp_discard_num --sp_discard_mt2w -M "

must_succeed "metabin -i tests/test_files/in4.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_sp -M "

must_succeed "metabin -i tests/test_files/in4.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_num -M "

must_succeed "metabin -i tests/test_files/in4.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_mt2w -M  --no_mbk --TopSpecies 1"


# check output
must_succeed "diff -q <(tail -n +2 .metabin.test.out.tsv|sort) <(tail -n +2  tests/test_files/out4.tsv|sort ) "

must_succeed "metabin -i tests/test_files/in5.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_mt2w -M  --no_mbk --TopSpecies 1 --rm_predicted saccver"

# min_pident defined for mbk:tnf mbk:lca
must_succeed "metabin -i tests/test_files/in5.blast.tsv -o .metabin.test.out -S 98 -G 95 -F 92 -A 80 --sp_discard_mt2w    --TopSpecies 1 --rm_predicted saccver"

#############################
## blacklisting
# familiesBL: Bivalvia
must_fail "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FamilyBL tests/test_files/disabled.taxa.txt"

must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FamilyBL tests/test_files/families2exclude.txt"
must_succeed "[ `grep -c "Unionidae" .metabin.test.out.tsv ` == 0 ]"

must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --GenusBL tests/test_files/genera2exclude.txt"

#1069815 Sinanodonta woodiana
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --SpeciesBL tests/test_files/ids2exclude.txt"
must_succeed "[ `grep -c 'Sinanodonta woodiana' .metabin.test.out.tsv` == 0 ]"

# GeneraBL=Corbicula
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --SpeciesBL tests/test_files/ids2exclude.txt --GenusBL tests/test_files/genera2exclude.txt"
must_succeed "[ `grep -c 'Sinanodonta woodiana' .metabin.test.out.tsv` == 0 ]"

## FilterFile and FilterCol
echo 45949 > ./blacklist.txt
must_succeed "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol taxids"
must_succeed "[ $(cat .metabin.test.out.tsv|grep -c "Corbicula fluminea") == 0 ]"

## File not present or not given
must_fail "metabin -i tests/test_files/in1.blast.tsv --Filter   &> /dev/null"
must_fail "metabin -i tests/test_files/in1.blast.tsv --Filter  _file_does_not_exist  &> /dev/null"

must_fail "metabin -i tests/test_files/in1.blast.short.tsv -o .metabin.test.out  --FilterFile tests/test_files/in1.blast.short.excludeIDs.txt &> /dev/null"

must_succeed "metabin -i tests/test_files/in1.blast.short.tsv --FilterFile tests/test_files/in1.blast.short.excludeIDs.txt -o .metabin.test.out --FilterCol saccver"

must_succeed "[ $(grep -c -E 'query1\s' .metabin.test.out.tsv) == 0 ]"

must_succeed "metabin -i tests/test_files/in1.blast.short.tsv --FilterFile tests/test_files/in1.blast.short.exclude_single_ID.txt -o .metabin.test.out --FilterCol saccver"

must_succeed "[ $(grep -c -E 'query1\s' .metabin.test.out.tsv) == 1 ]"

must_succeed "[ $(grep -c -E 'query18\s' .metabin.test.out.tsv) == 0 ]"


# column not present
must_fail "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol taxids_typo"
must_fail "metabin -M -i tests/test_files/in1.blast.tsv -o .metabin.test.out -S 99.0 -G 97.0 -F 95.0 -A 93.0 --FilterFile ./blacklist.txt --FilterCol "

echo Failed tests: $num_failed
echo Number of tests: $num_tests
exit $num_failed

