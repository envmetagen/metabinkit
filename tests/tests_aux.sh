
let num_failed=0
let num_tests=0

function must_fail {
    cmd=$*
    STATUS=PASSED
    bash -c "$cmd" 2> /dev/null
    if [ 0 -eq $? ];  then      
        STATUS=FAILED
        let num_failed=num_failed+1
    fi
    let num_tests=num_tests+1
    echo $STATUS $cmd
}

function must_succeed {
    cmd=$*
    STATUS=PASSED
    bash -c "$cmd" 2> /dev/null
    if [ 0 -ne $? ];  then      
        STATUS=FAILED
        bash -c "$cmd"
        let num_failed=num_failed+1
    fi
    let num_tests=num_tests+1
    echo $STATUS $cmd
}

