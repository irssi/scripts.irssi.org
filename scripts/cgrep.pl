################################################################################
#
# Usage: /cgrep <regexp>
#
# Shows all WHO records matching that regexp in a friendly yet complete format
# Works on the active channel only
#
# This is a bit like c0ffee's ls command, except it matches ALL returned data.
# Since IRSSI doe snot cache realnames properly, this script calls WHO once
# and awaits the results.
#
# Also check out 'joininfo.pl' which shows lots of WHOIS info when a person
# joins the channel.
#
# FORMAT SETTINGS:
#   cgrep_match         Matching record
#   cgrep_line          Start and end line format
#
################################################################################

use Irssi;
use vars qw($VERSION %IRSSI);
use integer;

$VERSION = "1.0.0";
%IRSSI = (
    authors => "Pieter-Bas IJdens",
    contact => "irssi-scripts\@nospam.mi4.org.uk",
    name    => "cgrep",
    description => "Lists users on the channel matching the specified regexp",
    license => "GPLv2 or later",
    url     => "http://pieter-bas.ijdens.com/irssi/",
    changed => "2005-03-10"
);

################################################################################

my($busy) = 0;
my($regexp) = "";
my($results) = 0;
my($debug) = 0;

################################################################################

sub run_who
{
    my($server, $channel) = @_;

    $server->redirect_event(
        "who",
        1,
        $channel,
        0,
        "redir who_default",
        {
            "event 352" => "redir cgrep_evt_who_result",
            "event 315" => "redir cgrep_evt_who_end",
            "" => "event empty"
        }
    );

    $server->send_raw("WHO $channel");
}

################################################################################

sub event_who_result
{
    my ($server, $data) = @_;

    if ($busy)
    {
        if ($data =~ /^(.*):([^:]{1,})$/)
        {
            $start = $1;
            $realname = $2;
        }
        else
        {
            Irssi::print("$data can't be parsed");
        }

        # my($start,$realname) = split(":", $data);

        my($me, $channel, $ident, $host, $server, $nick, $mode) =
            split(" ", $start);
        my($hops) = -1;

        if ($realname =~ /^([0-9]{1,} )(.*$)$/i)
        {
            $hops = $1;
            $realname = $2;

            $hops =~ s/[ ]{1,}$//g;
        }

        my($string) = "$nick ($ident\@$host) \"$realname\" $channel " 
                    . "($server, $hops)";

        if ($string =~ /$regexp/i)
        {
            Irssi::printformat(
                MSGLEVEL_CLIENTCRAP,
                'cgrep_match',
                $nick,
                "$ident\@$host",
                "$realname",
                $channel,
                $server,
                $hops
            );

            $results++;
        }
    }
}

################################################################################

sub event_who_end
{
    my ($server, $data) = @_;

    Irssi::printformat(
        MSGLEVEL_CLIENTCRAP,
        'cgrep_line',
        "End of list. Found $results matches."
    );

    $busy = 0;
    $regexp = "";
    $results = 0;
}

################################################################################

sub cmd_cgrep
{
    my ($data, $server, $window) = @_;

    if (!$server)
    {
        Irssi::print("Not connected to a server in this window.");
        return;
    }
    elsif ($window->{type} ne "CHANNEL")
    {
        Irssi::print("Not a channel window.");
        return;
    }
    elsif ($busy)
    {
        Irssi::print("A request seems to be in progress.");
        Irssi::print("Reload script if I'm wrong.");
    }

    $busy = 1;
    $regexp = $data;
    $results = 0;

    Irssi::printformat(
        MSGLEVEL_CLIENTCRAP,
        'cgrep_line',
        "WHO on " . $window->{name} . " filtered on '$regexp'"
    );

    run_who($server, $window->{name});
}

################################################################################

Irssi::theme_register([
    'cgrep_match',
    '%GWHO:%n {channick_hilight $0} [{hilight $1}] is "{hilight $2}"%n on {channel $3} [server: {hilight $4}, hops: {hilight $5}]',
    'cgrep_line',
    '%R------------%n {hilight $0} %R------------%n'
]);

Irssi::signal_add(
    {
    'redir cgrep_evt_who_result'    => \&event_who_result,
    'redir cgrep_evt_who_end'       => \&event_who_end
    }
);

################################################################################

Irssi::command_bind("cgrep", \&cmd_cgrep);

################################################################################
