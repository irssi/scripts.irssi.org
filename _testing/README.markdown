Irssi Scripts Testing
---------------------

Here, combined with the .travis.yml in root, are the files to do some
test reports on Irssi scripts.

Main test runner is run-test.zsh. These tests are done:
* Try to load the script in irssi
* Check perlcritic report

To run tests yourself, you first need several programs installed:
* [zsh](http://zsh.sourceforge.net/)
* [irssi](https://irssi.org)
* cpan [Perl::Critic](https://metacpan.org/pod/Perl::Critic)
* cpan [Perl::PrereqScanner](https://metacpan.org/pod/Perl::PrereqScanner)
* cpan -f [Tree::XPathEngine](https://metacpan.org/pod/Tree::XPathEngine)
* cpan [PPIx::XPath](https://metacpan.org/pod/PPIx::XPath)

Then, run it like this:

    ./_testing/run-test.zsh yourscript

One "." should be printed.

Evaluation of test success is done in report-test.zsh. Currently the
following criteria lead to fail:
* Script doesn't compile/load
* Script doesn't use strict; or uses two-arg "open"
* Script doesn't define %IRSSI and $VERSION

To see the test results, run:

    ./_testing/report-test.zsh yourscript

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

To see the detailed output, run:

    ./_testing/travis/show-failures.zsh yourscript

Errors and warnings visible in the Irssi log can serve as further
pointers to both authors and reviewers.

You can also inspect the raw outputs in the following folder:

    ./Test/yourscript

The following keys are recognised in config.yml:

* cpan:
  * broken_tests: - modules where to skip tests, that would otherwise
                    hang Travis
  * broken_modules: - modules to never auto-install, for example
                      because they hang Travis
* whitelist: - list of scripts that are allowed to fail
* scripts_yaml_keys: - list of keys to copy from irssi header to scripts.dmp

To manually generate the _data/scripts.yaml file, run:

    perl ./_testing/update-scripts-yaml.pl

To download the cached test results, run:

    git fetch origin ci-artefacts:ci-artefacts
    ln -s ci-artefacts Test

