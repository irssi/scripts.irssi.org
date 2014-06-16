#!/bin/zsh

. ./_testing/_get_files_arr.zsh

if [[ $TRAVIS_PULL_REQUEST == false ]] {
    filelist=(scripts)
}

for mod ($(scan-perl-prereqs $filelist)) {
    if [[ $(corelist $mod) == *" not in CORE"* && $mod != Irssi* ]] {
	mod=${mod%\~*}
	if { ! perl -M$mod -E1 2>/dev/null } {
	    local skip_test=
	    if { grep -sqF $mod _testing/cpan-broken-tests } {
	        skip_test=--notest
		echo Skipping broken test on $mod
	    }
	    if { grep -sqF $mod _testing/cpan-broken-modules } {
	        echo SKIPPING AUTOINSTALL OF BROKEN MODULE $mod
	    } \
	    else {
	        echo Auto-installing $mod
	        sudo cpanm -q --skip-satisfied $skip_test $mod
	    }
	}
    }
}
