filelist=(scripts/*.pl)
if [[ $GITHUB_REF != refs/heads/master ]] {
    local -a scriptfiles
    OIFS=$IFS; IFS=$'\n'
    scriptfiles=($(git diff --numstat --no-renames origin/master|cut -f3|grep '^scripts/.*\.pl'))
    IFS=$OIFS
    if [[ $#scriptfiles -gt 0 ]] {
	filelist=($scriptfiles)
    }
} \
elif [[ $USE_ARTEFACTS_CACHE = yes ]] {
    local -a cache_allowed
    OIFS=$IFS; IFS=$'\n'
    cache_allowed=(scripts/${^$(grep -v __ARTEFACTS_CI__ old-artefacts/can-use-cache | cut -f2- -d\  )})
    IFS=$OIFS

    if [[ $REPORT_STAGE == yes ]] {
        autoload -Uz zargs
        mkdir -p Test
        { zargs -r -- old-artefacts/Test/${^cache_allowed:t:r} -- mv -nt Test } 2>/dev/null
        cached_run=($cache_allowed)
    } \
    else {
        # is-at-least 5.0.0
        filelist=(${filelist:|cache_allowed})
    }
}
