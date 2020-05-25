#!/usr/bin/env bash

PATH2SCRIPT=$(dirname "${BASH_SOURCE[0]}" )

set -u
source $PATH2SCRIPT/../tests_aux.sh

echo "*** taxonkit_children"

set +xe
must_fail "taxonkit_children.sh"
must_fail "taxonkit_children.sh ifile2"
must_fail "taxonkit_children.sh ifile2 ofile "
must_fail "taxonkit_children.sh ifile2 ofile nodb"

cat <<EOF > ifile
1136698
1524213
1524214
EOF

must_succeed "[ `taxonkit_children.sh ifile ofile && cat ofile |wc -l` \> 10 ]"

echo Failed tests: $num_failed
echo Number of tests: $num_tests
exit $num_failed

