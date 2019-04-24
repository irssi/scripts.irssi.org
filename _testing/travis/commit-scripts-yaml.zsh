#!/bin/zsh

[[ -z $REPO_LOGIN_TOKEN ]] && exit
[[ -z $TRAVIS_REPO_SLUG ]] && exit

echo "https://${REPO_LOGIN_TOKEN}:x-oauth-basic@github.com" > "$HOME/.git-credentials"

git config user.email "scripts@irssi.org"
git config user.name "Irssi Scripts Helper"
git config credential.helper store
git config remote.origin.url "https://github.com/$TRAVIS_REPO_SLUG"
git checkout "$TRAVIS_BRANCH"

if [[ "$(git log -1 --format=%an)" != "$(git config user.name)" &&
      "$(git log -1 --format=%cn)" != "$(git config user.name)" ]] {
    git add _data/scripts.yaml
    git commit -m "automatic scripts database update for $TRAVIS_COMMIT

[skip ci]"
    git config push.default simple
    git push origin
}
