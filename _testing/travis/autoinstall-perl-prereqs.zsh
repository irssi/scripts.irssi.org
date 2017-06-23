#!/bin/zsh

mkdir -p auto

. ./_testing/_get_files_arr.zsh

echo -n ... >&2
scan-perl-prereqs $filelist > auto/cpanfile

typeset -A broken_mods
broken_mods=($(perl -MYAML::Tiny=LoadFile -e'print "$_ 1 " for @{LoadFile(+shift)->{cpan}{broken_modules}}' _testing/config.yml))

typeset -a sed_del_broken
for mod (${(k)broken_mods}) { sed_del_broken+=(-e '/^'"$mod"'$/d') }

sed -i \
    -e '/^Irssi~/d' \
    -e '/^Irssi::/d' \
    $sed_del_broken \
    -e 's,^,'"'"',g' \
    -e 's,$,'"'"',g' \
    -e 's,^,requires ,g' \
    -e 's,$,;,g' \
    auto/cpanfile

exit 0
