#!/bin/zsh
if { ! git clone -q --depth 1 -b ci-artefacts git://github.com/$GITHUB_REPOSITORY.git old-artefacts } {
   mkdir old-artefacts
}
echo $(git log --format=%H -1 _testing .github) __ARTEFACTS_CI__>old-artefacts/new-changed-info
for f (scripts/*.pl) {
    echo $(git hash-object $f) ${f:t} >>old-artefacts/new-changed-info
}
grep -sxFf old-artefacts/new-changed-info old-artefacts/changed-info >old-artefacts/can-use-cache
if { ! grep -q __ARTEFACTS_CI__ old-artefacts/can-use-cache } {
    :>|old-artefacts/can-use-cache
}
