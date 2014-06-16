if [[ $TRAVIS == true ]] {
    . ./_testing/travis/_get_files_arr.zsh
} \
else {
    filelist=($@)
}
