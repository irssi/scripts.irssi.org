use strict;
use warnings;

my $CURRENT_SCRIPT = $ENV{CURRENT_SCRIPT};
my $PWD = $ENV{PWD};
my $SWD = "$PWD/../..";

require YAML::Tiny;
YAML::Tiny->VERSION("1.59");
require Encode;
die "Broken Encode version (2.88)" if $Encode::VERSION eq '2.88';
{
    # This is an ugly hack to be `lax' about the encoding. We try to
    # read everything as UTF-8 regardless of declared file encoding
    # and fall back to Latin-1.
    my $orig = YAML::Tiny->can("_has_internal_string_value") || die("Error in ".__PACKAGE__);
    no warnings 'redefine';
    *YAML::Tiny::_has_internal_string_value = sub {
        my $ret = $orig->(@_);
        use bytes;
        $_[0] = Encode::decode_utf8($_[0], sub{pack 'U', +shift})
            unless Encode::is_utf8($_[0]);
        $ret
    }
}

my %existing_commands;
my (%info, $version, $package, @commands);
Irssi::command_bind('_irssi_test_py_cb' => sub {
		      my ($data, $server, $witem) = @_;
		      use JSON::PP;
		      my $doc = decode_json("$data");
		      eval { %info = %{$doc->{'IRSSI'}} };
		      eval { $version = $doc->{'VERSION'} };
		      eval { $package = $doc->{'package'} };
		      @commands = sort grep { !$existing_commands{$_} } map { $_->{cmd} } Irssi::commands;
		    });

%existing_commands = map { ($_->{cmd} => 1) } Irssi::commands;

Irssi::command('^window log on');
Irssi::command("py load $CURRENT_SCRIPT");

unless (defined $package) {
    my %fail = (failed => 1, name => $CURRENT_SCRIPT);
    YAML::Tiny::DumpFile("failed.yml", [\%fail]);
    # TODO: Grep for the code instead
}
delete $info{''};
for my $rb (keys %info) {
    delete $info{$rb} unless defined $info{$rb};
}

if (!%info || !defined $info{name}) {
    open my $ef, '>>', "perlcritic.log";
    print $ef "scripts/$CURRENT_SCRIPT.py: ", 'No IRSSI header in script or name not given. (Severity: 6)', "\n";
    $info{name} //= $CURRENT_SCRIPT;
}
if (!defined $version) {
    open my $ef, '>>', "perlcritic.log";
    print $ef "scripts/$CURRENT_SCRIPT.py: ", 'Missing __version__ in script. (Severity: 6)', "\n";
}
else {
    $info{version} = $version;
}
chomp(my $loginfo = `git log 2d0759e6... -1 --format=%ai -- "$SWD/scripts/$CURRENT_SCRIPT.py" 2>/dev/null ||
git log -1 --format=%d%m%ai -- "$SWD/scripts/$CURRENT_SCRIPT.py" | grep -v grafted | cut -d'>' -f2`);
if ($loginfo) {
    my ($date, $time) = split ' ', $loginfo;
    $info{modified} = "$date $time";
}
#$info{modules} = \@modules if @modules;
$info{commands} = \@commands if @commands;
$info{default_package} = $package if $package;
$info{language} = 'Python';
YAML::Tiny::DumpFile("info.yml", [\%info]);
Irssi::command('^window log off');
