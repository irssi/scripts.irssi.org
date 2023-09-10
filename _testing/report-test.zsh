#!/bin/zsh

local failmark="\e[31m✘\e[0m"
local passmark="\e[32m✔\e[0m"
local skipmark="\e[33m☡\e[0m"
local failed=0
local T=
local Q=

if [[ $MARKDOWN_REPORT == 1 ]] {
    echo '## Irssi Scripts Test Report'
    # github started to block excess use of emojis
    #failmark=:x:
    #passmark=:white_check_mark:
    #skipmark=:construction:
    failmark=✘
    passmark=✔
    skipmark=☡
    T="|"
    Q="\\"
} \
else {
    echo '============================== TEST REPORT ============================='
}
printf "%-32s $T LOAD $T HDR $T CRIT $T SCORE $T PASS\n" "$Q"
if [[ $MARKDOWN_REPORT == 1 ]] {
 echo "----: $T :--: $T :-: $T :--: $T ----: $T :---:"
}
typeset -a cached_run
cached_run=()
REPORT_STAGE=yes
. ./_testing/_get_files_arr.zsh

typeset -A allow_fail
allow_fail=($(perl -MYAML::Tiny=LoadFile -e'print "$_ 1 " for @{LoadFile(+shift)->{whitelist}}' _testing/config.yml))

for scriptfile ($filelist) {
    if [[ $MARKDOWN_REPORT == 1 ]] { print -n '[' }
    printf "%32s " $scriptfile:t:r
    if [[ $MARKDOWN_REPORT == 1 ]] { print -n '](Test/'$scriptfile:t:r'/)' }
    print -n $T
    local pass=0

    # LOAD
    if [[ -f "Test/${scriptfile:t:r}/failed.yml" ]] { print -n '  '$failmark'   ' } \
    elif [[ -f "Test/${scriptfile:t:r}/info.yml" ]] { print -n '  '$passmark'   '; ((++pass)) } \
    else { print -n '  '$skipmark'   '; }; print -n $T

    # HDR
    if { grep -qs 'Severity: 6' "Test/${scriptfile:t:r}/perlcritic.log" } { print -n '  '$failmark'   ' } \
    elif { grep -qs 'command not found:' "Test/${scriptfile:t:r}/perlcritic.log" } { print -n '  '$skipmark'   ' } \
    else { print -n '  '$passmark'   '; ((++pass)) }; print -n $T

    # CRIT
    if { grep -qs 'Code before strictures are enabled\|Two-argument "open" used' "Test/${scriptfile:t:r}/perlcritic.log" }  { print -n '  '$failmark'   ' } \
    elif { grep -qs ': \(E9\|F63\|F7\|F82\)' "Test/${scriptfile:t:r}/flake8.log" }  { print -n '  '$failmark'   ' } \
    elif { grep -qs 'command not found:' "Test/${scriptfile:t:r}/perlcritic.log" } { print -n '  '$skipmark'   ' } \
    else { print -n '  '$passmark'   '; ((++pass)) }; print -n $T

    # SCORE
    perl -ne 'BEGIN { @fl = ("E9|F63|F7|F82" => 5, "F[0-9]" => 4, "E[0-9]" => 3, "[CW][0-9]" => 2, "N[0-9]" => 1) }
        $score += $1 -1 if /Severity: (\d+)/;
        for ($i = 0; $i < @fl; $i += 2) { if (/\d: $fl[$i]/) { $score += $fl[$i + 1]; last } }
    END { printf "%3d", $score }' "Test/${scriptfile:t:r}/perlcritic.log" "Test/${scriptfile:t:r}/flake8.log" 2>/dev/null
    print -n '   '$T
    if [[ $pass -lt 3 ]]  {
        if [[ -n $allow_fail[$scriptfile:t:r] ]] || { [[ ! -f scripts/${scriptfile:t:r}.pl ]] && [[ ! -f scripts/${scriptfile:t:r}.py ]] } {
            print -n '  '$skipmark'   '
        } \
        else {
            print -n '  '$failmark'   '
            if [[ $failed -lt 254 ]] { ((++failed)) }
        }
    } \
    else {
        print -n '  '$passmark'   '; ((++pass))
        echo 1>"Test/${scriptfile:t:r}/passed"
    }
    if [[ $+cached_run[(r)$scriptfile] -gt 0 ]] {
        print -n $T' (c)'
    }
    echo
}
exit $failed
