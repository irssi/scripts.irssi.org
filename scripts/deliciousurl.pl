########################################################################################################
##
## Log URL's and post them to del.icio.us
##
########################################################################################################

BEGIN { $ENV{HARNESS_ACTIVE} = 1 }

use IO::Handle;
use Irssi;
use Irssi::Irc;
use Net::Delicious;
use URI::Find::Rule;
use POSIX;
use Log::Dispatch;
use Log::Dispatch::File;

use vars qw($VERSION %IRSSI $FINDER $WARNING_PRINTED);

$VERSION = "0.5";
%IRSSI = (
	authors => "Benjamin Reed",
	contact => 'ranger@befunk.com',
	name => "deliciousurl",
	description => "Logs URLs and posts them to del.icio.us",
	license => "GPLv2",
	url => "http://ranger.befunk.com/",
);

# === Version History ===
# 2007-01-19: version 0.5, minor logging/UI tweaks
# 2005-10-25: released version 0.4
# 2005-10-25: fork post_to_delicious so we don't have to wait for a response (holy crap, I
#             can't believe it was broken this long without noticing!)
# 2005-08-24: added channel ignore, thanks to Rev. Jeffrey Paul

Irssi::settings_add_str('deliciousurl', 'delicious_username', '');
Irssi::settings_add_str('deliciousurl', 'delicious_password', '');
Irssi::settings_add_int('deliciousurl', 'delicious_post_privmsg', 0);
Irssi::settings_add_int('deliciousurl', 'delicious_strip_trailing_slash', 1);
Irssi::settings_add_str('deliciousurl', 'delicious_blacklist_regexp', '(tubgirl|goatse\.cx)');
Irssi::settings_add_str('deliciousurl', 'delicious_default_tag', 'irc');
Irssi::settings_add_str('deliciousurl', 'delicious_ignore_chan', '');

sub post_to_delicious
{
	my ($channel, $data, $nick) = @_;

	my $username = Irssi::settings_get_str('delicious_username');
	my $password = Irssi::settings_get_str('delicious_password');

	if (not defined $username or not defined $password and not $WARNING_PRINTED)
	{
		if (not $WARNING_PRINTED)
		{
			Irssi::print("username or password are not set!");
			$WARNING_PRINTED++;
		}
		return;
	}

	my $pid = fork();

	if ($pid) {
		Irssi::pidwait_add($pid);
		return;
	} else {
		my $blacklist = Irssi::settings_get_str('delicious_blacklist_regexp');

		eval {
			$data =~ /$blacklist/ and die "blacklist matched!";
		};
		if ($@)
		{
			#Irssi::print("skipped in $channel (blacklist): $data");
			POSIX::_exit(0);
		}

		$channel =~ s/^#//;

		my @igc = split(
			/\s+/,
			Irssi::settings_get_str('delicious_ignore_chan')
			);
		for (@igc) {
			s/^#//;
			POSIX::_exit(0) if lc($_) eq lc($channel);
		}

		my $del = Net::Delicious->new({
			user => $username,
			pswd => $password,
		});

		my @posts = $del->posts({ tag => Irssi::settings_get_str('delicious_default_tag') });

		my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
		$year += 1900;
		$mon  += 1;

		my $dt = sprintf('%04d-%02d-%02dT%02d:%02d:%02dZ', $year, $mon, $mday, $hour, $min, $sec);

		my @urls = URI::Find::Rule->in($data);
		POSIX::_exit(0) unless (@urls);

		for my $url (@urls) {
			$url = $url->[1];
			$url =~ s/\/*$// if (Irssi::settings_get_int('delicious_strip_trailing_slash'));
			my $tags = Irssi::settings_get_str('delicious_default_tag') . ' ' . $channel . ' ' . $nick;
			#my $text = sprintf('%04d-%02d-%02d %02d:%02d:%02d <%s> %s', $year, $mon, $mday, $hour, $min, $sec, $nick, $data);
			my $text = sprintf('<%s> %s', $nick, $data);

			if (my ($post) = grep { $_->href eq $url } @posts)
			{
				my @tags = split(/\s+/, $post->tag);
				if (not grep { $_ eq $channel } split(/\s+/, $post->tag))
				{
					$tags = $post->tag . ' ' . $channel;
				}
				#$text = $post->extended . "\n" . $text;
			}

			my $return = $del->add_post({
				url => $url,
				description => $url,
				extended => $text,
				tags => $tags,
				dt => $dt,
			});
		}
		POSIX::_exit(0);
	}
}

sub del_public
{
	my ($server, $data, $nick, $mask, $target) = @_;
	post_to_delicious($target, $data, $nick);
}

sub del_private
{
	my ($server, $data, $nick, $address) = @_;
	if (Irssi::settings_get_int('delicious_post_privmsg') > 0)
	{
		post_to_delicious($server->{'nick'}, $data, $nick);
	}
}

sub del_own
{
	my ($server, $data, $target) = @_;
	post_to_delicious($target, $data, $server->{'nick'});
}

sub del_topic
{
	my ($server, $target, $data, $nick, $mask) = @_;
	post_to_delicious($target, $data, $nick);
}


Irssi::signal_add_last('message public', 'del_public');
Irssi::signal_add_last('message private', 'del_private');
Irssi::signal_add_last('message own_public', 'del_own');
Irssi::signal_add_last('message topic', 'del_topic');

Irssi::print("deliciousurl $VERSION ready");
