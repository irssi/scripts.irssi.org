Irssi Scripts Testing
---------------------

Here, combined with the .travis.yml in root, are the files to do some
test reports on Irssi scripts.

Main test runner is run-test.zsh. These tests are done:
* Try to load the script in irssi
* Check perlcritic report

Evaluation of test success is done in report-test.zsh. Currently the
following criteria lead to fail:
* Script doesn't compile/load
* Script doesn't use strict; or uses two-arg "open"
* Script doesn't define %IRSSI and $VERSION

The output table is as follows:
- LOAD:  did the script compile/load successfully?
- HDR:   was %IRSSI and $VERSION given?
- CRIT:  did it use strict; and three-arg "open"?
- SCORE: the cumulated perlcritic score, high score *might* be an
         indication of bad code style, but this should be read with
         extreme care
- PASS:  did it pass the test as by the criteria defined above?

Detailed perlcitic report and Irssi log can be viewed from
show-failures.zsh output. It also includes the extracted .yml
definition *if* the script compiled cleanly. This can be used as a
guidance for reviewers, but a lot of perl "critic" is stupid and a
style question only.

Errors and warnings visible in the Irssi log can serve as further
pointers to both authors and reviewers.

The following keys are recognised in config.yml:

* cpan:
  * broken_tests: - modules where to skip tests, that would otherwise
                    hang Travis
  * broken_modules: - modules to never auto-install, for example
                      because they hang Travis
* whitelist: - list of scripts that are allowed to fail
* scripts_yaml_keys: - list of keys to copy from irssi header to scripts.dmp
