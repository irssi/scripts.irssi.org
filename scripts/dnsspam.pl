use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
use integer;

### REQUIREMENTS
#
# You need spamcalc from http://spamcalc.net/ installed on your system in
# the perl path or in ~/.irssi/scripts/spamcalc
#
# The data directory (below) should be set to the spamcalc dir
#
# It should work afterwards
#

require spamcalc::SpamCalc;

my $irssidir = Irssi::get_irssi_dir();
my $datafilesdir = $irssidir . "/scripts/spamcalc/data";

my($debug) = 0;
my $calc;

################################################################################

$VERSION = "1.0.0";
%IRSSI = (
    authors => "Pieter-Bas IJdens",
    contact => "irssi-scripts\@nospam.mi4.org.uk",
    name    => "dnsspam",
    description => "Checks for DNS Spam on JOIN",
    license => "GPLv2 or later",
    url     => "http://pieter-bas.ijdens.com/irssi/",
    changed => "2005-03-10"
);

################################################################################

sub register_messages
{
    Irssi::theme_register([
        'sc_spam_certain',
            '%RSPAMCALC:%n {channick_hilight $0} from {hilight $1}'.
            ' spam level: {hilight $2} on {channel $3}',
        'sc_spam_probable',
            '%YSPAMCALC:%n {channick_hilight $0} from {hilight $1}'.
            ' spam level: {hilight $2} on {channel $3}',
        'sc_spam_clean',
            '%GSPAMCALC:%n {channick_hilight $0} from {hilight $1}'.
            ' spam level: {hilight $2} on {channel $3}'
    ]);
}

################################################################################

sub run_spamcalc
{
    my($host) = @_;

    # Don't do anything for unresolved ipv6 ips
    if ($host =~ /:/) {
            return 0;
    }

    # Don't do anything for unresolved ipv4 ips
    if ($host =~ /[0-9]$/) {
            return 0;
    }

    my $score = $calc->get_host_score($host);

    return $score;
}

################################################################################

sub event_join
{
    my ($server, $channame, $nick, $host) = @_;

    return if $server->{chat_type} ne "IRC";

    my $chanrec = $server->channel_find($channame);

    if ($chanrec)
    {
    	my($username, $hostname) = split('@', $host);

        my ($level) = run_spamcalc($hostname);

        if ($level > 100)
        {
            $chanrec->printformat(
                MSGLEVEL_JOINS,
                'sc_spam_certain',
                $nick,
                "*!*@". $hostname,
                $level,
                $channame
                );
        }
        elsif ($level > 50)
        {
            $chanrec->printformat(
                MSGLEVEL_JOINS,
                'sc_spam_probable',
                $nick,
                "*!*@". $hostname,
                $level,
                $channame
                );
        }
        elsif ($debug > 0)
        {
            $chanrec->printformat(
                MSGLEVEL_JOINS,
                'sc_spam_clean',
                $nick,
                "*!*@". $hostname,
                $level,
                $channame
                );
        }
    }
    else
    {
        Irssi::print("%RDNSSPAM:%n Chanrec not found for $channame%N");
    }

    return;
}

################################################################################

sub event_load_settings
{
    return;
}

################################################################################

sub cmd_spamcalc
{
    my ($data, $server, $item) = @_;
    my ($level);

    $level = run_spamcalc($data);

    Irssi::print("SPAMCALC: $level ($data)");
}

################################################################################

$calc = SpamCalc->new();
$calc->load_datafiles($datafilesdir);

################################################################################
 
register_messages();

################################################################################

Irssi::signal_add({
    'message join'                  => \&event_join,
    'setup changed'                 => \&event_load_settings
});

################################################################################

Irssi::command_bind("sc", \&cmd_spamcalc);
