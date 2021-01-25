#!/bin/zsh
if [[ -z $GITHUB_REPOSITORY ]] { exit 1 }
autoload -Uz zargs

pushd artefacts
git config user.email "scripts@irssi.org"
git config user.name "Irssi Scripts Helper"

git rm -qrf .

echo "This branch stores the Github Actions results for $GITHUB_REPOSITORY
See [the testing read-me](../master/_testing/) for details." > README.markdown
pushd ..
MARKDOWN_REPORT=1 ./_testing/report-test.zsh >> artefacts/README.markdown
popd
echo >> README.markdown
echo "$GITHUB_SHA | $(date -Ins)" >> README.markdown

mv ../Test .
rm -fr Test/.home
zargs -r -- Test/*/passed(N) -- rm
if [[ $USE_ARTEFACTS_CACHE == yes ]] {
    mv ../old-artefacts/new-changed-info changed-info
}

git add .
git commit -q -m "ci artefacts for $GITHUB_SHA

[ci skip]"

git push -u origin ci-artefacts
