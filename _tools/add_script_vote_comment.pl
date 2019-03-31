#!/usr/bin/perl

# This script will post a comment on GitHub with the script name and
# description. The Javascript on https://scripts.irssi.org will
# download all issue comments from the repo and show the GitHub
# "Comment Votes" as votes for the script.

# Requirements:

# - cpan Mojolicious
#
# - Credentials for the GitHub website must be stored in a file
#   `../.votes.pass' with the following format:
#
#   pass: your-github-personal-access-token-abcdef
#   user: github-username

# Usage example:

# Many *manual* steps are required.
#
# 1. The issue must already exist on GitHub.
#
# 2. It should be closed.
#
# 3. Its title should be "votes".
#
# 4. It should not contain more than 72 comments (= scripts)
#
# 5. At the end of every issue, manually post a "follow-up issue" link.
#    Example: (in issue #41)
#    Comment: #42
#
# 6. Run the script:
#    ./_tools/add_script_vote_comment.pl scriptassist.pl 41
#
#    If the script ran successfully, it will output:
#
#    scriptassist.pl
#    201
#
#
# 7. The "follow-up issue" link must be manually delete and re-created
#    after running the script, so that it stays the very last comment.


use strict;
use warnings;
use v5.24;
use utf8;
use ojo;
use YAML::Tiny qw(LoadFile);

die "syntax: $0 scriptfile issueno\n"
    unless @ARGV == 2;
my ($file, $issue) = @ARGV;

my %cred = %{LoadFile("../.votes.pass")};
my $x = LoadFile("_data/scripts.yaml") ;
my $i = 0;
my $start;
for my $sc (sort { $a->{modified} cmp $b->{modified} } @$x) {
    #say $sc->{filename} ;
    #if ($sc->{filename} eq $ARGV[0]) { $start = 1; next; }
    #next unless $start;
    next unless $sc->{filename} eq $file;
    say $sc->{filename} ;
    my %sc = %$sc;
    #sleep 1;
    my $res = p("https://$cred{user}:$cred{pass}\@api.github.com/repos/$cred{user}/scripts.irssi.org/issues/$issue/comments"
		=> {Accept => "*/*"}
		=> json
		=> {
		    body => "$sc{filename}\n---\n$sc{description}\n\nClick on ![+😃](https://user-images.githubusercontent.com/5665186/52212818-af6a7480-288d-11e9-9e48-4822b0a8efce.png) :+1: :-1: to add your votes"
		}
	       );
    say $res->code;
    unless ($res->code == 201) { say $res->body; exit 1; }
    exit;
}
exit 1;
