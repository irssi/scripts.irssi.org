# smshi - sends highlights via SMS, using Twilio
# CC0 https://creativecommons.org/publicdomain/zero/1.0/

use strict;
use warnings;

use Irssi;
use vars qw($VERSION %IRSSI);

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

$VERSION = "1.0";
$ua->agent("irssi+SMSHi/$VERSION ");
%IRSSI = (
	authors     => "John Runyon",
	name        => "smshi",
	description => "send highlights via Twilio sms",
	license     => 'CC0',
	url         => 'https://github.com/zonidjan/irssi-scripts',
	contact     => 'https://github.com/zonidjan/irssi-scripts/issues'
);

sub got_print {
	return unless Irssi::settings_get_bool('smshi_active');

	my ($dest, $text, $stripped) = @_;
	my $server = $dest->{server};
	my $mynick = $server->{nick};
	return unless ($dest->{level} & MSGLEVEL_HILIGHT) # continue if hilight...
	           or ($dest->{level} & MSGLEVEL_MSGS && index($stripped, $mynick) != -1); # or if it's a PM containing my nick
	return if $stripped =~ /<.?\Q$mynick\E>/; # avoid people quoting me
	return if (!$server->{usermode_away} && Irssi::settings_get_bool('smshi_away_only')); # and obey away_only

	my $msg = '';
	for my $c (split //, $stripped) {
		if (ord($c) > 31 && ord($c) < 127) {
			$msg .= $c;
		} else {
			$msg .= '\\x'.sprintf("%02x", ord($c));
		}
	}

	my $chname = $dest->{window}->get_active_name();
	my $sms = $server->{tag}."/".$chname.$msg;
	_send_sms($sms);
}
sub test_sms {
	_send_sms("This is an SMS test.");
}
sub _send_sms {
	my $sms = shift;

	my $sid = Irssi::settings_get_str('smshi_sid');
	my $token = Irssi::settings_get_str('smshi_token');
	my $from = Irssi::settings_get_str('smshi_from');
	my $to = Irssi::settings_get_str('smshi_to');

	my $url = "https://$sid:$token\@api.twilio.com/2010-04-01/Accounts/$sid/Messages.json";
	my $req = HTTP::Request->new('POST', $url);
	$req->content_type('application/x-www-form-urlencoded');
	$req->content("To=$to&From=$from&Body=$sms");

	my $res = $ua->request($req);
	return unless Irssi::settings_get_bool('smshi_debug');
	if ($res->is_success) {
		print "Good. Sent to $to from $from: $sms";
	} else {
		print "Bad!";
		print $req->url;
		print $req->content;
		print $res->status_line;
		print $res->content;
	}
}

Irssi::settings_add_bool('smshi', 'smshi_active', 0);    # master switch
Irssi::settings_add_bool('smshi', 'smshi_away_only', 1); # send only when away?
Irssi::settings_add_bool('smshi', 'smshi_debug', 0);     # show debugging info
Irssi::settings_add_str('smshi', 'smshi_sid', '');       # Twilio SID
Irssi::settings_add_str('smshi', 'smshi_token', '');     # Twilio token
Irssi::settings_add_str('smshi', 'smshi_from', '');      # From number (+12022345678)
Irssi::settings_add_str('smshi', 'smshi_to', '');        # To number (+12022345678)

Irssi::signal_add('print text', 'got_print');
Irssi::command_bind('testsms', 'test_sms');
Irssi::print('%G>>%n '.$IRSSI{name}.' '.$VERSION.' loaded');
