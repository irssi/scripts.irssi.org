if [[ -n $GITHUB_ACTION ]] {
    . ./_testing/github/_get_files_arr.zsh
} \
else {
    filelist=($@)
}
