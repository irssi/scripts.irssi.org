#!/bin/zsh

. ./_testing/_get_files_arr.zsh

root_script() {
    perl -p -e 's{ at ([^/\s]*) line (\d+)}{ at scripts/$1 line $2}g'
}

if [[ $GITHUB_REF != refs/heads/master ]] {
    echo '======== INTEGRATION REPORT ========='
    for scriptfile ($filelist) {
        echo '--- '$scriptfile:t
        if [[ -f "Test/${scriptfile:t:r}/failed.yml" ]] {
            echo "FATAL: SCRIPT FAILED TO LOAD  "
        }
        cat "Test/${scriptfile:t:r}/stderr.log" 2>/dev/null | root_script
        cat "Test/${scriptfile:t:r}/irssi.log" | root_script
        echo
        echo 'Source code critic:'
        cat "Test/${scriptfile:t:r}/perlcritic.log" 2>/dev/null
        cat "Test/${scriptfile:t:r}/flake8.log" 2>/dev/null
        echo
    }
    echo
    echo '======== YAML DATABASE ========'
    for scriptfile ($filelist) {
        if [[ ! -f "Test/${scriptfile:t:r}/failed.yml" ]] {
            cat "Test/${scriptfile:t:r}/info.yml"
        }
    }
} \
else {
    echo '============= DETAILED FAILURE REPORTS ============='
    for scriptfile ($filelist) {
        if [[ -f "Test/${scriptfile:t:r}/failed.yml" ]] {
           echo '--- '$scriptfile:t
           cat "Test/${scriptfile:t:r}/stderr.log" 2>/dev/null | root_script
           cat "Test/${scriptfile:t:r}/irssi.log" | root_script
           echo
        }
    }
}
