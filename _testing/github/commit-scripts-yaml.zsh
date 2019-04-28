#!/bin/zsh

[[ -z $GITHUB_TOKEN ]] && exit

git config user.email "scripts@irssi.org"
git config user.name "Irssi Scripts Helper"
git checkout master
git config -l --show-origin

if [[ "$(git log -1 --format=%an)" != "$(git config user.name)" &&
      "$(git log -1 --format=%cn)" != "$(git config user.name)" ]] {
    git add _data/scripts.yaml
    git commit -m "automatic scripts database update for $GITHUB_SHA

[skip ci]"
    git config push.default simple
    git push --set-upstream origin master
}
