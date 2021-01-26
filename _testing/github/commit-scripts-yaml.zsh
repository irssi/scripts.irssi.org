#!/bin/zsh

[[ -z $GITHUB_ACTION ]] && exit

git config user.email "scripts@irssi.org"
git config user.name "Irssi Scripts Helper"
git checkout master

if [[ "$(git log -1 --format=%an)" != "$(git config user.name)" &&
      "$(git log -1 --format=%cn)" != "$(git config user.name)" ]] {
    git add _data/scripts.yaml
    git commit -m "automatic scripts database update for $GITHUB_SHA

[ci skip]"
    git config push.default simple
    git push --set-upstream origin master
}
