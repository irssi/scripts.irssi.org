#!/bin/zsh
echo $(git log --format=%H -1 _testing .github) __ARTEFACTS_CI__>old-artefacts/new-changed-info
for f (scripts/*.pl(N) scripts/*.py(N)) {
    echo $(git hash-object $f) ${f:t} >>old-artefacts/new-changed-info
}
grep -sxFf old-artefacts/new-changed-info old-artefacts/changed-info >old-artefacts/can-use-cache
if { ! grep -q __ARTEFACTS_CI__ old-artefacts/can-use-cache } {
    :>|old-artefacts/can-use-cache
}
