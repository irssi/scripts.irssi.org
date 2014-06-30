use strict;
use warnings;

BEGIN {
    *CORE::GLOBAL::exit = sub (;$) {
	require Carp;
	Carp::croak("script tried to call exit @_");
    };
}

my $CURRENT_SCRIPT = $ENV{CURRENT_SCRIPT};
my $PWD = $ENV{PWD};
my $SWD = "$PWD/../..";
Irssi::command('^window log on');
Irssi::command("script load $CURRENT_SCRIPT");
Irssi::command('^window log off');

my ($package) = grep { !/^_/ } keys %Irssi::Script::;

require YAML::Tiny;
require Module::CoreList;
require CPAN::Meta::Requirements;
require Perl::PrereqScanner;
my $prereq_results = Perl::PrereqScanner->new->scan_file("$SWD/scripts/$CURRENT_SCRIPT.pl");
my @modules = grep {
    $_ ne 'perl' &&
	$_ ne 'Irssi' && $_ ne 'Irssi::UI' && $_ ne 'Irssi::TextUI' && $_ ne 'Irssi::Irc'
	&& !Module::CoreList->first_release($_)
} sort keys %{ $prereq_results->as_string_hash };

my (%info, $version);
unless (defined $package) {
    my %fail = (failed => 1, name => $CURRENT_SCRIPT);
    $fail{modules} = \@modules if @modules;
    { open my $ef, '>:utf8', "failed.yml";
      print $ef YAML::Tiny::Dump([\%fail]); }
    # Grep for the code instead
    require PPI;
    require PPIx::XPath;
    require Tree::XPathEngine;
    my $xp = Tree::XPathEngine->new;
    my $doc = PPI::Document->new("$SWD/scripts/$CURRENT_SCRIPT.pl");
    my ($version_code) = $xp->findnodes(q{//*[./Token-Symbol[1] = "$VERSION" and ./Token-Operator = "="]}, $doc);
    my ($irssi_code)   = $xp->findnodes(q{//*[./Token-Symbol[1] = "%IRSSI" and ./Token-Operator = "="]}, $doc);
    $version = eval "no strict; package DUMMY; undef; $version_code";
    %info    = eval "no strict; package DUMMY; (); $irssi_code";
}
else {
    %info = do { no strict 'refs'; %{"Irssi::Script::${package}IRSSI"} };
    $version = do { no strict 'refs'; ${"Irssi::Script::${package}VERSION"} };
}
delete $info{''};
for my $rb (keys %info) {
    delete $info{$rb} if $rb =~ /\(0x[[:xdigit:]]+\)$/;
    delete $info{$rb} unless defined $info{$rb};
}

if (!%info || !defined $info{name}) {
    open my $ef, '>>', "perlcritic.log";
    print $ef 'No %IRSSI header in script or name not given. (Severity: 6)', "\n";
    $info{name} //= $CURRENT_SCRIPT;
}
if (!defined $version) {
    open my $ef, '>>', "perlcritic.log";
    print $ef 'Missing $VERSION in script. (Severity: 6)', "\n";
}
else {
    $info{version} = $version;
}
chomp(my $loginfo = `git log 2d0759e6... -1 --format=%ai -- "$SWD/scripts/$CURRENT_SCRIPT.pl"`);
if ($loginfo) {
    my ($date, $time) = split ' ', $loginfo;
    $info{modified} = "$date $time";
}
$info{modules} = \@modules if @modules;
$info{default_package} = $package =~ s/::$//r if $package;
{ open my $ef, '>:utf8', "info.yml";
  print $ef YAML::Tiny::Dump([\%info]); }
