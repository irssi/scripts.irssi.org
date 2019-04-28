#!/bin/zsh
local base_path="`pwd`"
local test_script="$base_path/_testing/_irssi_test.pl"

. ./_testing/_get_files_arr.zsh

for scriptfile ($filelist) {
    rm -rf "Test/${scriptfile:t:r}"
    mkdir -p "Test/${scriptfile:t:r}"
    if [[ ! -f scripts/${scriptfile:t:r}.pl ]] {
	{echo "command not found: script ${scriptfile:t:r}";echo "test skipped"} >"Test/${scriptfile:t:r}/perlcritic.log"
	continue
    }
    perlcritic --theme certrule --exclude RequireEndWithOne -2 scripts/${scriptfile:t:r}.pl >"Test/${scriptfile:t:r}/perlcritic.log" 2>&1
    pushd Test
    rm -fr .home
    mkdir .home
    ln -s ../../scripts .home
    local filename="$base_path/$scriptfile"
    <<STARTUP>.home/startup
^set settings_autosave off
^set use_status_window off
^set autocreate_windows off
^set -clear autocreate_query_level
^set autoclose_windows off
^set reuse_unused_windows on
^set -clear log_close_string
^set -clear log_day_changed
^set -clear log_open_string
^set log_timestamp * 
^load perl
^script exec \$\$^W = 1
run ${(qqq)test_script}
^quit
STARTUP
    pushd ${scriptfile:t:r}
    env TERM=xterm CURRENT_SCRIPT="$scriptfile:t:r" irssi --home="$base_path/Test/.home" >/dev/null 2>stderr.log
    if [[ ! -s stderr.log ]] { rm -f stderr.log }
    popd
    printf . >&2
    popd
    logs=(~/irc.log.*(N))
    if [[ $#logs -gt 0 ]] {
        perl -i -pe 's,\Q$ENV{PWD}/Test/.home/scripts/\E,,g;s,\Q$ENV{PWD}/Test/.home\E,..,g;s,\Q$ENV{PWD}\E,...,g;s,\(\@INC contains:.*? \.\),,g' $logs
        mv $logs "Test/${scriptfile:t:r}/irssi.log"
    } \
    elif [[ -f stderr.log ]] {
        cat stderr.log
    }
}
exit 0
