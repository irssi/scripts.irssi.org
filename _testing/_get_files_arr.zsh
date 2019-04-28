if [[ $TRAVIS == true ]] {
    . ./_testing/travis/_get_files_arr.zsh
} \
elif [[ -n $GITHUB_ACTION ]] {
    . ./_testing/github/_get_files_arr.zsh
} \
else {
    filelist=($@)
}
