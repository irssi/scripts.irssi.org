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

my (@packages) = grep { !/^_/ } keys %Irssi::Script::;
my $tp = $CURRENT_SCRIPT; $tp =~ s/^.*\///; $tp =~ s/\W/_/g; my @tmp;
if ((@tmp = grep /^\Q$tp\E::/, @packages) or (@tmp = grep /^\Q$tp\E/, @packages)) {
    @packages = @tmp;
}
my ($package) = @packages;

require Carp;
$Carp::CarpInternal{ 'Irssi::Core' }++;
$Carp::Internal{ (__PACKAGE__) }++;
$Carp::Internal{ 'Perl::PrereqScanner' }++;
$Carp::MaxEvalLen = 3;

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
require Module::CoreList;
require CPAN::Meta::Requirements;
require Perl::PrereqScanner;
my $prereq_results = Perl::PrereqScanner->new->scan_file("$SWD/scripts/$CURRENT_SCRIPT.pl");
my @modules = grep {
    $_ ne 'perl' &&
        $_ ne 'Irssi' && $_ ne 'Irssi::UI' && $_ ne 'Irssi::TextUI' && $_ ne 'Irssi::Irc'
        && !Module::CoreList->first_release($_)
} sort keys %{ $prereq_results->as_string_hash };

my (%info, $version, @commands);
unless (defined $package) {
    my %fail = (failed => 1, name => $CURRENT_SCRIPT);
    $fail{modules} = \@modules if @modules;
    YAML::Tiny::DumpFile("failed.yml", [\%fail]);
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
    @commands = sort map { $_->{cmd} } grep { $_->{category} eq "Perl scripts' commands" } Irssi::commands;
}
delete $info{''};
for my $rb (keys %info) {
    delete $info{$rb} if $rb =~ /\(0x[[:xdigit:]]+\)$/;
    delete $info{$rb} unless defined $info{$rb};
}

if (!%info || !defined $info{name}) {
    open my $ef, '>>', "perlcritic.log";
    print $ef "scripts/$CURRENT_SCRIPT.pl: ", 'No %IRSSI header in script or name not given. (Severity: 6)', "\n";
    $info{name} //= $CURRENT_SCRIPT;
}
if (!defined $version) {
    open my $ef, '>>', "perlcritic.log";
    print $ef "scripts/$CURRENT_SCRIPT.pl: ", 'Missing $VERSION in script. (Severity: 6)', "\n";
}
else {
    $info{version} = $version;
}
chomp(my $loginfo = `git log 2d0759e6... -1 --format=%ai -- "$SWD/scripts/$CURRENT_SCRIPT.pl" 2>/dev/null ||
git log -1 --format=%d%m%ai -- "$SWD/scripts/$CURRENT_SCRIPT.pl" | grep -v grafted | cut -d'>' -f2`);
if ($loginfo) {
    my ($date, $time) = split ' ', $loginfo;
    $info{modified} = "$date $time";
}
$info{modules} = \@modules if @modules;
$info{commands} = \@commands if @commands;
$info{default_package} = $package =~ s/::$//r if $package;
$info{language} = 'Perl';
YAML::Tiny::DumpFile("info.yml", [\%info]);
Irssi::command('^window log off');
