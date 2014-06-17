use strict;
use warnings;
use Irssi;
Irssi::command('^window log on');
Irssi::command("script load $ENV{PWD}/../scripts/$ENV{CURRENT_SCRIPT}.pl");
Irssi::command('^window log off');

my %core_mods;
if (open my $cm, '<', '_coremods-cache') {
    while (my $mod = <$cm>) {
	chomp $mod;
	$core_mods{$mod} = 1;
    }
}


my @modules = grep {
    chomp;
    if ($_ ne 'Irssi' && $_ ne 'Irssi::UI' && $_ ne 'Irssi::TextUI' && $_ ne 'Irssi::Irc'
	    && !/^Irssi~/
	    && !$core_mods{$_}) {
	my $info = `corelist "$_"`;
	if ($info =~ / was not in CORE/) {
	    1
	}
	else {
	    $core_mods{$_} = 1;
	    undef
	}
    }
    else {
	undef
    }
} `scan-perl-prereqs "$ENV{PWD}/../scripts/$ENV{CURRENT_SCRIPT}.pl"`;

{ open my $cm, '>', '_coremods-cache';
  print $cm join "\n", (keys %core_mods), '';
}

my ($package) = grep { !/^_/ } keys %Irssi::Script::;

unless (defined $package) {
    open my $ef, '>', "$ENV{CURRENT_SCRIPT}:failed";
    print $ef '1', "\n";
    exit;
}

no strict 'refs';
my %info = %{"Irssi::Script::${package}IRSSI"};
if (!%info || !defined $info{name}) {
    open my $ef, '>>', "$ENV{CURRENT_SCRIPT}:perlcritic.log";
    print $ef 'No %IRSSI header in script or name not given. (Severity: 6)', "\n";
    $info{name} //= $ENV{CURRENT_SCRIPT};
}
my $version = ${"Irssi::Script::${package}VERSION"};
if (!defined $version) {
    open my $ef, '>>', "$ENV{CURRENT_SCRIPT}:perlcritic.log";
    print $ef 'Missing $VERSION in script. (Severity: 6)', "\n";
}
else {
    $info{version} = $version;
}
chomp(my $loginfo = `git log 2d0759e6... -1 --format=%ai -- ../scripts/$ENV{CURRENT_SCRIPT}.pl`);
if ($loginfo) {
    my ($date, $time) = split ' ', $loginfo;
    $info{modified} = "$date $time";
}
$info{modules} = \@modules if @modules;
$info{default_package} = $package =~ s/::$//r;
open my $ef, '>', "$ENV{CURRENT_SCRIPT}:info.yml";
require YAML::Tiny;
print $ef YAML::Tiny::Dump([\%info]);
