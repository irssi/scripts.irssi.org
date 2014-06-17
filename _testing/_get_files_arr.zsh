filelist=(scripts/*.pl)
if [[ $TRAVIS_PULL_REQUEST != false ]] {
    local -a scriptfiles
    OIFS=$IFS; IFS=$'\n'
    scriptfiles=($(git diff --numstat $TRAVIS_BRANCH|cut -f3|grep '^scripts/.*\.pl'))
    IFS=$OIFS
    if [[ $#scriptfiles -gt 0 ]] {
	filelist=($scriptfiles)
    }
}
