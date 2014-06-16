#!/bin/zsh

. ./_testing/_get_files_arr.zsh

if [[ $TRAVIS_PULL_REQUEST != false ]] {
    echo '======== INTEGRATION REPORT ========='
    for scriptfile ($filelist) {
        echo '--- '$scriptfile:t
        if [[ -f "Test/${scriptfile:t:r}:failed" ]] {
	    echo "FATAL: SCRIPT FAILED TO LOAD	"
	}
        cat "Test/${scriptfile:t:r}:stderr.log"
        cat "Test/${scriptfile:t:r}:irssi.log"
	echo
	echo 'Source code critic:'
	cat "Test/${scriptfile:t:r}:perlcritic.log"
	echo
    }
    echo
    echo '======== YAML DATABASE ========'
    for scriptfile ($filelist) {
        if [[ ! -f "Test/${scriptfile:t:r}:failed" ]] {
	    cat "Test/${scriptfile:t:r}:info.yml"
	}
    }
} \
else {
    echo '============= DETAILED FAILURE REPORTS ============='
    for scriptfile ($filelist) {
        if [[ -f "Test/${scriptfile:t:r}:failed" ]] {
           echo '--- '$scriptfile:t
           cat "Test/${scriptfile:t:r}:stderr.log"
           cat "Test/${scriptfile:t:r}:irssi.log"
           echo
        }
    }
}
