use strict;
require LWP::UserAgent;
use Irssi;
use HTTP::Request::Common;
use vars qw($VERSION %IRSSI);

$VERSION = "20180123";
%IRSSI = (
	authors		=> "Carsten Otto",
	contact		=> "c-otto\@gmx.de",
	name		=> "mldonkey bandwidth script",
	description	=> "Shows your mldonkey's current down- and upload rate",
	license		=> "GPLv2",
	url		=> "http://www.c-otto.de",
	changed		=> "$VERSION",
	commands	=> "mlbw"
);

Irssi::settings_add_str('mldonkey_bandwidth', 'mldonkey_bandwidth_host' ,'127.0.0.1:4080');
my $host = Irssi::settings_get_str('mldonkey_bandwidth_host');

sub cmd_mlbw
{
	my ($args, $server, $target) = @_;
	my $ua = LWP::UserAgent->new(timeout => 5);
	my $req = GET "http://$host/submit?q=bw_stats";
	my $resp = $ua->request($req);
	my $output = $resp->content();
	my $down = $output;
	my $up = $output;
	$down =~ s/.*Down: ([0-9]*\.*[0-9]) KB.*/$1/s;
	$up =~ s/.*Up: ([0-9]*\.*[0-9]) KB.*/$1/s;
	if ($down eq "") { $down = "(off)"; }
	if ($up eq "") { $up = $down; }
	$output = "-MLdonkey bandwidth stats- Down: $down - Up: $up";
	if (!$server || !$server->{connected} || !$target)
	{
		Irssi::print $output;
	} else
	{
		Irssi::active_win() -> command('say ' . $output);
	}
}

sub cmd_changed
{
	$host = Irssi::settings_get_str('mldonkey_bandwidth_host');
}

Irssi::command_bind('mlbw', 'cmd_mlbw');
Irssi::signal_add('setup changed', 'cmd_changed'); 
