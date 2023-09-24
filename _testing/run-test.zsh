#!/bin/zsh
local base_path="`pwd`"
local test_script="$base_path/_testing/_irssi_test.pl"
local test_script_py="$base_path/_testing/_irssi_test_py.pl"

if [[ $(perl -MEncode -e'print $Encode::VERSION') == 2.88 ]] {
   echo "Broken Encode version (2.88). Please update the Perl Encode module."
   exit 4
}

. ./_testing/_get_files_arr.zsh

COMMON_STARTUP='^set settings_autosave off
^set use_status_window off
^set autocreate_windows off
^set -clear autocreate_query_level
^set autoclose_windows off
^set reuse_unused_windows on
^set -clear log_close_string
^set -clear log_day_changed
^set -clear log_open_string
^set log_timestamp * 
^load irc
^load dcc
^load flood
^load notifylist'

test_common() {
    pushd ${scriptfile:t:r}
    env TERM=xterm CURRENT_SCRIPT="$scriptfile:t:r" irssi --home="$base_path/Test/.home" >/dev/null 2>stderr.log
    if [[ ! -s stderr.log ]] { rm -f stderr.log }
    popd
    printf . >&2
    if [[ -n $GITHUB_ACTION ]] {
        echo /$scriptfile >&2
    }
    popd
    perl -i -pe '
s,\Q$ENV{PWD}/Test/.home/scripts/\E,,g;
s,\Q$ENV{PWD}/Test/.home\E,..,g;
s,\Q$ENV{PWD}\E,...,g;
s,\(\@INC contains: .*?\),,g' "Test/${scriptfile:t:r}/stderr.log" 2>/dev/null
    logs=(~/irc.log.*(N))
    if [[ $#logs -gt 0 ]] {
        perl -i -pe '
s,\Q$ENV{PWD}/Test/.home/scripts/\E,,g;
s,\Q$ENV{PWD}/Test/.home\E,..,g;
s,\Q$ENV{PWD}\E,...,g;
s,\(\@INC contains: .*?\),,g' $logs
        mv $logs "Test/${scriptfile:t:r}/irssi.log"
    } \
    elif [[ -f stderr.log ]] {
        cat stderr.log
    }
}

test_perl() {
    perlcritic --theme certrule --exclude RequireEndWithOne -2 --verbose 5 scripts/${scriptfile:t:r}.pl >"Test/${scriptfile:t:r}/perlcritic.log" 2>&1
    pushd Test
    rm -fr .home
    mkdir .home
    ln -s ../../scripts .home
    local filename="$base_path/$scriptfile"
    <<STARTUP>.home/startup
$COMMON_STARTUP
^load perl
^load otr
^script exec \$\$^W = 1
run ${(qqq)test_script}
^quit
STARTUP
    test_common
}

test_python() {
    flake8 --exit-zero --max-complexity=10 --max-line-length=127 --statistics --show-source scripts/${scriptfile:t:r}.py >"Test/${scriptfile:t:r}/flake8.log" 2>&1
    pushd Test
    rm -fr .home
    mkdir .home
    mkdir .home/scripts
    cat ../scripts/${scriptfile:t:r}.py > .home/scripts/${scriptfile:t:r}.py
    <<CB>>.home/scripts/${scriptfile:t:r}.py

# added by run-test.zsh for _irssi_test_py.pl
import json as __test_json
import irssi as __test_irssi
__test_irssi.command(b'^_irssi_test_py_cb ' + __test_json.dumps({'IRSSI': globals().get('IRSSI'), 'VERSION': globals().get('__version__'), 'package': globals().get('__name__')}).encode('utf-8'))

CB
    local filename="$base_path/$scriptfile"
    <<STARTUP>.home/startup
$COMMON_STARTUP
^load perl
^load python
^load otr
run ${(qqq)test_script_py}
^quit
STARTUP
    test_common
}

for scriptfile ($filelist) {
    if [[ -f scripts/${scriptfile:t:r}.pl ]] && [[ -f scripts/${scriptfile:t:r}.py ]] {
        echo "cannot have both ${scriptfile:t:r}.pl and ${scriptfile:t:r}.py" >&2
        exit 1
    }
    rm -rf "Test/${scriptfile:t:r}"
    mkdir -p "Test/${scriptfile:t:r}"
    if [[ -f scripts/${scriptfile:t:r}.pl ]] {
        test_perl
    } \
    elif [[ -f scripts/${scriptfile:t:r}.py ]] {
        test_python
    } \
    else {
        {echo "command not found: script ${scriptfile:t:r}";echo "test skipped"} >"Test/${scriptfile:t:r}/perlcritic.log"
        continue
    }
}
exit 0
