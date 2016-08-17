#!/bin/zsh
if [[ -z $REPO_LOGIN_TOKEN || -z $TRAVIS_REPO_SLUG ]] { exit 1 }
autoload -Uz zargs

if { ! git clone -b ci-artefacts https://github.com/$TRAVIS_REPO_SLUG artefacts } {
    mkdir artefacts && git init artefacts
    pushd artefacts
    git remote add origin https://github.com/$TRAVIS_REPO_SLUG
    git checkout -b ci-artefacts
    popd
}

pushd artefacts
git config user.email "scripts@irssi.org"
git config user.name "Irssi Scripts Helper"
git config credential.helper store

git rm -qrf .

echo "This branch stores the travis-ci results for $TRAVIS_REPO_SLUG
See [the testing read-me](../master/_testing/) for details." > README.markdown
pushd ..
MARKDOWN_REPORT=1 ./_testing/report-test.zsh >> artefacts/README.markdown
popd
echo >> README.markdown
echo "$TRAVIS_COMMIT | $TRAVIS_BUILD_NUMBER" >> README.markdown

mv ../Test .
rm -fr Test/.home
zargs -r -- Test/*/passed(N) -- rm
if [[ $USE_ARTEFACTS_CACHE == yes ]] {
    mv ../old-artefacts/new-changed-info changed-info
}

git add .
git commit -q -m "ci artefacts for $TRAVIS_COMMIT

[skip ci]"

git push -u origin ci-artefacts
