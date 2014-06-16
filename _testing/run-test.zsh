#!/bin/zsh
mkdir -p Test
local base_path="`pwd`"
local test_script="$base_path/_testing/_irssi_test.pl"

. ./_testing/_get_files_arr.zsh

for scriptfile ($filelist) {
    rm -f "Test/${scriptfile:t:r}:"*(N)
    perlcritic --theme certrule --exclude RequireEndWithOne -2 $scriptfile >"Test/${scriptfile:t:r}:perlcritic.log"
    pushd Test
    rm -fr home
    mkdir home
    echo '^set settings_autosave off'>home/startup
    echo '^set use_status_window off'>>home/startup
    echo '^set autocreate_windows off'>>home/startup
    echo '^set -clear autocreate_query_level'>>home/startup
    echo '^set autoclose_windows off'>>home/startup
    echo '^set reuse_unused_windows on'>>home/startup
    echo '^load perl'>>home/startup
    echo '^script exec $$^W = 1'>>home/startup
    local filename="$base_path/$scriptfile"
    echo "run ${(qqq)test_script}">>home/startup
    echo '^quit'>>home/startup
    env TERM=xterm CURRENT_SCRIPT="$scriptfile:t:r" irssi --home="$base_path/Test/home" >/dev/null 2>"${scriptfile:t:r}:stderr.log"
    printf . >&2
    popd
    mv ~/irc.log.* "Test/${scriptfile:t:r}:irssi.log"
}
rm -f Test/_coremods-cache
exit 0
