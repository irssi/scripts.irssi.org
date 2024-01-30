#!/bin/zsh

mkdir -p pipreqs_scan

. ./_testing/_get_files_arr.zsh

echo -n ... >&2

rfl=()
for fn ($filelist) {
    if [[ -f $fn ]] {
        rfl+=$fn
    }
}
if [[ ${#rfl} -gt 0 ]] {
    ln -rst pipreqs_scan $rfl
}
pipreqs pipreqs_scan

typeset -A broken_mods
broken_mods=($(perl -MYAML::Tiny=LoadFile -e'print "$_ 1 " for @{LoadFile(+shift)->{pip}{broken_modules}}' _testing/config.yml))

typeset -a sed_del_broken
for mod (${(k)broken_mods}) { sed_del_broken+=(-e '/^'"$mod"'=/d') }

sed -i \
    $sed_del_broken \
    pipreqs_scan/requirements.txt

exit 0
# vim:set sw=4 et:
