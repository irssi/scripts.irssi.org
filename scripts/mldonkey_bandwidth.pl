require LWP::UserAgent;
use Irssi;
use HTTP::Request::Common;
use strict;
use vars qw($VERSION %IRSSI);
######################
my $ip = "127.0.0.1";
#enter mldonkey's IP here and make sure you are allowed to connect!
######################
$VERSION = "20030712";
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
sub cmd_mlbw
{
	my ($args, $server, $target) = @_;
	my $ua = LWP::UserAgent->new(timeout => 5);
	my $req = GET "http://$ip:4080/submit?q=bw_stats";
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

Irssi::command_bind('mlbw', 'cmd_mlbw');
