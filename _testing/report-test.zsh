#!/bin/zsh
echo '============================== TEST REPORT ============================='
printf "%32s  LOAD  HDR  CRIT  SCORE  PASS\n"
local passmark="\e[32m✔\e[0m"
local failmark="\e[31m✘\e[0m"
local failed=0

. ./_testing/_get_files_arr.zsh

for scriptfile ($filelist) {
    printf "%32s " $scriptfile:t:r
    local pass=0
    if [[ -f "Test/${scriptfile:t:r}:failed" ]] { print -n '  '$failmark'   ' } \
    else { print -n '  '$passmark'   '; ((++pass)) }
    if { grep -q 'Severity: 6' "Test/${scriptfile:t:r}:perlcritic.log" } || [[ $pass -lt 1 ]]  { print -n '  '$failmark'   ' } \
    else { print -n '  '$passmark'   '; ((++pass)) }
    if { grep -q 'Code before strictures are enabled\|Two-argument "open" used' "Test/${scriptfile:t:r}:perlcritic.log" }  { print -n '  '$failmark'   ' } \
    else { print -n '  '$passmark'   '; ((++pass)) }
    perl -ne '$score += $1 -1 if /Severity: (\d+)/; END { printf "%3d", $score }' "Test/${scriptfile:t:r}:perlcritic.log"
    print -n '   '
    if [[ $pass -lt 3 ]]  { print -n '  '$failmark'   '; if [[ $failed -lt 254 ]] { ((++failed)) }; } \
    else { print -n '  '$passmark'   '; ((++pass)) }
    echo
}
exit $failed
