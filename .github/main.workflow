# workflow "Check Scripts(M)" {
#   on = "push"
#   resolves = ["update-scripts"]
# }

# workflow "Check Scripts" {
#   on = "push"
#   resolves = ["result"]
# }

action "On Master Branch" {
  uses = "actions/bin/filter@master"
  args = "branch master"
}

action "On Pull Request" {
  uses = "actions/bin/filter@master"
  args = "not branch master"
}

action "run-test(m)" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["On Master Branch"]
  args = "before_install global_env install before_script"
}

action "run-test" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["On Pull Request"]
  args = "before_install global_env install before_script"
}

action "report-test" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["run-test"]
  args = "global_env script"
}

action "report-test(m)" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["run-test(m)"]
  args = "global_env script"
}

action "update-scripts" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["report-test(m)"]
  args = "global_env after_script"
  secrets = ["GITHUB_TOKEN"]
}

action "show-failures" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["report-test"]
  args = "global_env after_script"
}

action "result" {
  uses = "irssi-import/actions-irssi/check-irssi-scripts@master"
  needs = ["show-failures"]
  args = "global_env script_result"
}
