## Irssi's Script Repository

This repository contains scripts available at
[scripts.irssi.org](http://scripts.irssi.org).

![Build Status](https://github.com/irssi/scripts.irssi.org/actions/workflows/test.yml/badge.svg?branch=master&event=push)

### Contributing

To add or modify a script do the following:

1. Fork this repository on Github.
2. Create a feature branch for your set of patches using `git checkout -b foobar`.
3. Add or modify your script in the repository. Remember to add it to Git using `git add`.
4. If you are modifying a script, remember to increase the version number and update the last modification date.
5. If the script has a ChangeLog, remember to include your modifications.
6. Commit your changes to Git and push them to Github.
7. Submit pull request.
8. [Review the Script Check report](script_check_report.markdown) once it is done.
9. Await review of your changes by one of our developers.

Optionally, to run tests locally, see more information under [_testing](_testing).

### Version Numbering

To increase the version numbering, take the following conditions into account:

1. Do not create explicit minor revision numbers if they are not present (1.3 becomes 1.4 or 2.1, not 1.3.1)
2. When modifying an existing feature, increase the minor revision number (1.3 becomes 1.4, not 2.1)
3. When adding a new feature, increase the major revision number (1.3 becomes 2.1, not 1.4)
