# spotify.pl - lookup spotify resources
#
# Copyright (c) 2009-2014 Örjan Persson <o@42mm.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = '1.1';
%IRSSI = (
	authors     => 'Örjan Persson',
	contact     => 'o@42mm.org',
	name        => 'spotify',
	description => 'Lookup spotify uris',
	license     => 'GPLv2',
	url         => 'https://github.com/op/irssi-spotify'
);

use Irssi;

use Encode;
use HTTP::Request::Common;
use HTTP::Request;
use JSON;
use LWP::UserAgent;
use POSIX;
use URI;

sub cmd_spotify_help {
	Irssi::print(<<'EOF', MSGLEVEL_CLIENTCRAP);
SPOTIFY [-a | auto] [-l | lookup] [...]

    -a, auto: see SPOTIFY AUTO
    -l, lookup: see SPOTIFY LOOKUP

Lookup spotify uris to get information on tracks, albums, artists and
playlists. You can configure it to do automatic lookup when someone sends it in
a channel or privately.

Playlist requests require authentication. Get credentials from
https://developer.spotify.com.

/SET spotify_client_id <string>
/SET spotify_client_secret <string>

Output format is customizable.

/SET spotify_header_format <string>
    Header message above lookup result. Available variables:
        %%uri            requested uri

/SET spotify_album_format <string>
    Format for album results. Available variables:
        %%name           name of the album
        %%artist         album artists
        %%year           year the album was released
        %%popularity     album popularity
        %%territories    territories the album is available in

/SET spotify_artist_format <string>
    Format for artist results. Available variables:
        %%name           name of the artist
        %%popularity     artist popularity

/SET spotify_track_format <string>
    Format for track results. Available variables:
        %%name           name of the track
        %%album          name of the album
        %%artist         track artists
        %%popularity     track popularity

/SET spotify_playlist_format <string>
    Format for playlist results. Available variables:
        %%name           name of the playlist
        %%owner          name of the owner

See /SPOTIFY <section> help for more information.

EOF
}

sub cmd_spotify_help_lookup {
	Irssi::print(<<'EOF', MSGLEVEL_CLIENTCRAP);
SPOTIFY LOOKUP [-p | public] <resource>

    -p, public: return result to current window
    -h, help:   show this help

Lookup the given resource and return the result. If the public
argument is given, the result is returned to the current window.
EOF
}

sub cmd_spotify_help_auto {
	Irssi::print(<<'EOF', MSGLEVEL_CLIENTCRAP);
SPOTIFY AUTO [-p | public] [-i | info] [-e | enable] [-d | disable] [-w | whitelist] [-b | blacklist]

    -p, public: see SPOTIFY AUTO PUBLIC
    -i, info: display current settings for SPOTIFY AUTO
    -e, enable: enable automatic lookup
    -d, disable: disable automatic lookup

Configure automatic features. The public section is for
automatic return results in the window the Spotify resource
was sent in.

Info will display settings for all automatic features and
you can use enable or disable to turn automatic functions
on or off.
EOF
}

sub cmd_spotify_help_auto_public {
	Irssi::print(<<'EOF', MSGLEVEL_CLIENTCRAP);
SPOTIFY AUTO PUBLIC [OPTION...]

    -a, add: add nick or channel to auto list
    -d, del: delete nick or channel from auto list
    -n, nick: use command on nick list
    -c, channel: use command on channel list

    -i, info: display current settings for SPOTIFY AUTO
    -w, whitelist: treaten list as a whitelist
    -b, blacklist: treaten list as a blacklist

Add a nick or channel to search from when matching
Configure automatic features. The public section is for
automatic return results in the window the Spotify resource
was sent in.

Info will display settings for all automatic features and
you can use enable or disable to turn automatic functions
on or off.

You can also set if you want the list of nicks and channels
to be interpretted as a whitelist or blacklist.
EOF
}

sub cmd_help {
	my ($args, $server, $window) = @_;

	if ($args =~ /^spotify\s*$/) {
		cmd_spotify_help();
	} elsif ($args =~ /^spotify lookup\s*$/i) {
		cmd_spotify_help_lookup();
	} elsif ($args =~ /^spotify auto\s*$/i) {
		cmd_spotify_help_auto();
	} elsif ($args =~ /^spotify auto public\s*$/i) {
		cmd_spotify_help_auto_public();
	}
}

sub cmd_spotify_lookup {
	my ($args, $server, $window) = @_;
	my @argv = split(/ /, $args);

	my $public = 0;

	# Simple parse arguments (debian still has an old version of irssi..)
	my $i;
	for ($i = 0; $i <= $#argv; $i++) {
		if ($argv[$i] eq '-p' || $argv[$i] eq 'public') { $public = 1; }
		elsif ($argv[$i] eq '-h' || $argv[$i] eq 'help') {
			return Irssi::command_runsub('spotify lookup', $args, $server, $window);
		}
		else { last; }
	}

	# Treat the rest as data argument
	my $data = join(' ', @argv[$i..$#argv]);

	# Make sure we actually have a window reference and check if we can write
	if ($public) {
		if (!$window) {
			Irssi::active_win()->print("Must be run run in a valid window (CHANNEL|QUERY)");
			return;
		}
	} else {
		$window = Irssi::active_win();
	}

	# Dispatch the work to be done
	my @worker_args = ($data, 1);
	my @output_args = ($server->{tag}, $window->{name}, $public ? $window->{name} : 0);
	dispatch(\&spotify_lookup, \@worker_args, \@output_args);
}

sub cmd_spotify_auto {
	my ($args, $server, $window) = @_;

	if ($args eq 'info' || $args eq '-i') {

		my $lookup = Irssi::settings_get_str('spotify_automatic_lookup');
		my $lookup_public = Irssi::settings_get_str('spotify_automatic_lookup_public');
		my $lookup_public_blacklist = Irssi::settings_get_str('spotify_automatic_lookup_public_blacklist');
		my $lookup_public_channels = Irssi::settings_get_str('spotify_automatic_lookup_public_channels');
		my $lookup_public_nicks = Irssi::settings_get_str('spotify_automatic_lookup_public_nicks');
		my $policy = $lookup_public_blacklist eq 'yes' ? 'disable' : 'enable';
		Irssi::print(<<"EOF", MSGLEVEL_CLIENTCRAP);
Spotify automatic settings:
 automatic lookup: %_${lookup}%_
 automatic lookup to public: %_${lookup_public}%_
 interpret list of channels and nicks as blacklist: %_${lookup_public_blacklist}%_
 ${policy} lookup for channels: %_${lookup_public_channels}%_
 ${policy} lookup for nicks: %_${lookup_public_nicks}%_
EOF
	} elsif ($args eq 'enable' || $args eq '-e') {
		Irssi::settings_set_bool('spotify_automatic_lookup', 1);
		cmd_spotify_auto('info', $server, $window);
	} elsif ($args eq 'disable' || $args eq '-d') {
		Irssi::settings_set_bool('spotify_automatic_lookup', 0);
		cmd_spotify_auto('info', $server, $window);
	} else {
		Irssi::command_runsub('spotify auto', $args, $server, $window);
	}
}

sub cmd_spotify_auto_public {
	my ($args, $server, $window) = @_;

	if ($args eq 'info' || $args eq '-i') {
		cmd_spotify_auto('info', $server, $window);
	} elsif ($args eq 'whitelist' || $args eq '-w') {
		Irssi::settings_set_bool('spotify_automatic_lookup_public_blacklist', 0);
		cmd_spotify_auto('info', $server, $window);
	} elsif ($args eq 'blacklist' || $args eq '-b') {
		Irssi::settings_set_bool('spotify_automatic_lookup_public_blacklist', 1);
		cmd_spotify_auto('info', $server, $window);
	} elsif ($args eq 'enable' || $args eq '-e') {
		Irssi::settings_set_bool('spotify_automatic_lookup_public', 1);
		cmd_spotify_auto('info', $server, $window);
	} elsif ($args eq 'disable' || $args eq '-d') {
		Irssi::settings_set_bool('spotify_automatic_lookup_public', 0);
		cmd_spotify_auto('info', $server, $window);
	} else {
		Irssi::command_runsub('spotify auto public', $args, $server, $window);
	}
}

sub cmd_spotify_auto_public_add {
	my ($args, $server, $window) = @_;

	my @argv = split(/ /, $args);
	my $type = shift(@argv);

	if ($type eq 'channel' || $type eq '-c') {
		$type = 'channel';
	} elsif ($type eq 'nick' || $type eq '-n') {
		$type = 'nick';
	} else {
		return Irssi::command_runsub('spotify auto public add', $args, $server, $window);
	}

	my @array = settings_get_array("spotify_automatic_lookup_public_${type}s");
	foreach my $arg (@argv) {
		push(@array, $arg);
	}
	settings_set_array("spotify_automatic_lookup_public_${type}s", @array);
	cmd_spotify_auto('info', $server, $window);
}

sub cmd_spotify_auto_public_del {
	my ($args, $server, $window) = @_;

	my @argv = split(/ /, $args);
	my $type = shift(@argv);

	if ($type eq 'channel' || $type eq '-c') {
		$type = 'channel';
	} elsif ($type eq 'nick' || $type eq '-n') {
		$type = 'nick';
	} else {
		return Irssi::command_runsub('spotify auto public del', $args, $server, $window);
	}

	my @array = settings_get_array("spotify_automatic_lookup_public_${type}s");
	foreach my $arg (@argv) {
		for (my $i = 0; $i <= $#array; $i++) {
			if ($array[$i] eq $arg) {
				splice(@array, $i, 1);
				last;
			}
		}
	}
	settings_set_array("spotify_automatic_lookup_public_${type}s", @array);
	cmd_spotify_auto('info', $server, $window);
}

sub event_message_topic {
	my ($server, $channel, $topic, $nick, $address) = @_;

	if ($server->{nick} ne $nick) {
		event_message($server, $topic, $nick, $address, $channel);
	}

}

sub event_message {
	my ($server, $text, $nick, $address, $target) = @_;

	if (!Irssi::settings_get_bool('spotify_automatic_lookup')) {
		return;
	}

	# Retrieve window object and decide wether to do lookup public or not
	my ($window, $public);
	if (!$server->ischannel($target)) {
		$window = Irssi::window_item_find($nick);
		$public = public_lookup_permitted($nick);
		$target = $nick;
	} else {
		$window = Irssi::window_item_find($target);
		$public = public_lookup_permitted($nick, $target);
	}

	# Dispatch a lookup for each matching uri
	my @output_args = ($server->{tag}, $window->{name}, $public ? $target : 0);
	while ($text =~ m{(https?://(play|open)\.spotify\.com/|spotify:)[^\s<>\[\]()?]+}g) {
		my @worker_args = ($&, 0);
		dispatch(\&spotify_lookup, \@worker_args, \@output_args);
	}
}

sub dispatch {
	my $action = shift;
	my @writer_args = @{$_[0]};
	my @reader_args = @{$_[1]};

	# Create communication between child and main process
	my ($reader, $writer);
	pipe($reader, $writer);

	# Create child process
	my $pid = fork();
	if ($pid > 0) {
		# Main process, close writer and add child pid to waiting list
		close($writer);
		Irssi::pidwait_add($pid);

		# Add reader and input pipe tag to arguments and pass it to
		# dispatch_reader when finished
		my $input_tag;
		unshift(@reader_args, $pid);
		unshift(@reader_args, \$input_tag);
		unshift(@reader_args, $reader);

		# Wait for child to finish and send result to input_reader
		$input_tag = Irssi::input_add(fileno($reader), INPUT_READ,
		                              'input_reader', \@reader_args);
	} elsif ($pid == 0) {
		# Child process, close reader and do the work to be done
		close($reader);
		my $rc = $action->($writer, \@writer_args) || 0;
		close($writer);
		POSIX::_exit($rc);
	} else {
		# Fork error, something nasty must have happened
		Irssi::print('spotify: failed to fork(), aborting $cmd.', MSGLEVEL_CLIENTCRAP);
		close($reader);
		close($writer);
	}
}

sub input_reader {
	my ($reader, $input_tag, $pid, $server, $window, $target) = @{$_[0]};
	my @data = <$reader>;

	# Cleanup before doing anything else
	close($reader);
	Irssi::input_remove($$input_tag);

	# Get exit code from child and force non-public output on error
	while (waitpid($pid, POSIX::WNOHANG) == 0) {
		sleep 1;
	}
	my $rc = POSIX::WEXITSTATUS($?);
	if ($rc) { $target = 0; }

	# Find output window
	$server = Irssi::server_find_tag($server);
	$window = $server ? $server->window_item_find($window) : undef;

	if (!defined($window)) {
		$window = Irssi::active_win();
	}

	# Handle result from child
	foreach my $line (@data) {
		chomp($line);
		if ($target) {
			# Remove any trace of colors (could probably break things)
			$line =~ s/%[krgybmpcwn:|#_]//ig;
			$window->command("/NOTICE $target " . $line);
		}
		else { $window->print($line); }
	}
}

sub spotify_lookup {
	my $writer = shift;
	my ($uri, $manual) = @{$_[0]};

	# Remove any leading whitespace and trailing whitespace and dots
	$uri =~ s/^\s+//g;
	$uri =~ s/[\s\.]+$//g;

	# Unify how we look at the path, removing leading / to match how path looks
	# for URIs with : where the path never starts with a :.
	my $u = URI->new($uri)->path;
	$u =~ s/^\///;
	my @parts = split /[\/:]/, $u;

	my $path;
	my $auth;
	if ($parts[0] =~ /^(track|album|artist)$/ && @parts == 2) {
		$path = "v1/$parts[0]\s/$parts[1]";
	} elsif ($parts[0] eq 'user' && @parts == 2) {
		$path = "v1/users/$parts[1]";
	} elsif ($parts[0] eq 'user' && @parts == 4 && $parts[2] == 'playlist') {
		$path = "v1/users/$parts[1]/playlists/$parts[3]";
		$auth = 1;
	} else {
		print($writer "spotify: unsupported URI: $uri");
		return 1;
	}

	my $ua = new LWP::UserAgent(
		agent => "spotify.pl/$VERSION",
		timeout => 10
	);
	$ua->env_proxy();

	# Fetch access token when needed. The token could be cached and re-used where
	# possible. Since we're in a forked process, it's not trivial and probably
	# not worth the effort.
	my $token;
	if ($auth) {
		my $request = POST 'https://accounts.spotify.com/api/token', [
			grant_type => 'client_credentials',
			client_id => Irssi::settings_get_str('spotify_client_id'),
			client_secret => Irssi::settings_get_str('spotify_client_secret')
		];
		my $response = $ua->request($request);
		my $content_type = $response->header('Content-Type');
		if (index($content_type, 'application/json') == -1) {
			my $body = substr $response->decoded_content(), 0, 128;
			print($writer "Unsupported content type: $content_type (" . $response->code . "): $body");
			return 1;
		}
		my $result = from_json($response->decoded_content(), {utf8 => 1});
		if (defined $result->{error}) {
			my $error = $result->{error_description} || $result->{error};
			print($writer "Authorization failed: $error (" . $response->code . ")");
			return 1;
		}
		$token = $result->{access_token};
	}

	my $request = GET 'https://api.spotify.com/' . $path;
	if ($token) {
		$request->header('Authorization' => 'Bearer ' . $token);
	}
	my $response = $ua->request($request);
	my $content_type = $response->header('Content-Type');
	if (index($content_type, 'application/json') == -1) {
		my $body = substr $response->decoded_content(), 0, 128;
		print($writer "Unsupported content type: $content_type (" . $response->code . "): $body");
		return 1;
	}
	my $result = from_json($response->decoded_content(), {utf8 => 1});
	if (defined $result->{error}) {
		print($writer "Lookup failed: $result->{error}->{message} (" . $response->code . ")");
		return 1;
	}

	my $message = undef;
	my %data;
	if ($result->{type} eq 'track') {
		$data{'name'} = $result->{name};
		$data{'artist'} = artists_str($result->{artists});
		$data{'album'} = $result->{album}->{name};
		$data{'popularity'} = popularity_str($result->{popularity});
		$message = Irssi::settings_get_str('spotify_track_format');
		$message =~ s/%(name|artist|album|popularity)/$data{$1}/ge;
	} elsif ($result->{type} eq 'album') {
		$data{'name'} = $result->{name};
		$data{'artist'} = artists_str($result->{artists});
		$data{'year'} = substr $result->{release_date}, 0, 4;
		$data{'popularity'} = popularity_str($result->{popularity});
		$data{'territories'} = join ', ', $result->{available_markets};
		$message = Irssi::settings_get_str('spotify_album_format');
		$message =~ s/%(name|artist|year|popularity|territories)/$data{$1}/ge;
	} elsif ($result->{type} eq 'artist') {
		$data{'name'} = $result->{name};
		$data{'popularity'} = popularity_str($result->{popularity});
		$message = Irssi::settings_get_str('spotify_artist_format');
		$message =~ s/%(name|popularity)/$data{$1}/ge;
	} elsif ($result->{type} eq 'user') {
		$data{'user'} = $result->{id};
		$message = Irssi::settings_get_str('spotify_user_format');
		$message =~ s/%(user)/$data{$1}/ge;
	} elsif ($result->{type} eq 'playlist') {
		$data{'name'} = $result->{name};
		$data{'owner'} = $result->{owner}->{id};
		$message = Irssi::settings_get_str('spotify_playlist_format');
		$message =~ s/%(name|owner)/$data{$1}/ge;
	} else {
		print($writer "spotify: unhandled result type: " . $result->{type});
		return 1;
	}

	my $charset = Irssi::settings_get_str('term_charset');
	if ($charset =~ /^utf-8/i) {
		binmode $writer, ':utf8';
	} else {
		Encode::from_to($message, "utf-8", Irssi::settings_get_str('term_charset'));
	}

	# Only write header for manual lookups
	if ($manual) {
		my $header = Irssi::settings_get_str('spotify_header_format');
		$header =~ s/%uri/$uri/ge;
		if ($header ne "") { print($writer $header . "\n"); }
	}

	print($writer $message);

	return 0;
}

sub artists_str {
	my $artists = shift;
	my @names;
	foreach my $artist(@{$artists}) {
		push(@names, $artist->{name});
	}
	return join ', ', @names;
}

sub popularity_str {
	my $popularity = shift;
	my $str = '';
	for (my $i = 0; $i < 100; $i += 20) {
		if ($i <= $popularity) {
			$str .= '*';
		} else {
			$str .= '-';
		}
	}
	return $str;
}

sub settings_get_array {
	my $key = shift;
	my $value = Irssi::settings_get_str($key);
	return split(/[ :;,]/, $value);
}

sub settings_set_array {
	my ($key, @value) = @_;
	my $str = join(' ', @value);
	Irssi::settings_set_str($key, $str);
}

sub public_lookup_permitted {
	my ($nick, $channel) = @_;

	if (!Irssi::settings_get_bool('spotify_automatic_lookup_public')) {
		return 0;
	}

	# Default lookup policy can either be deny or allow, and matching will
	# invert the default result. If this is True, the policy list will be used
	# as a blacklist. If this is False, the policy list is a whitelist.
	my $blacklist = Irssi::settings_get_bool('spotify_automatic_lookup_public_blacklist');

	sub in_array {
		my ($type, $target) = @_;

		my @array = settings_get_array("spotify_automatic_lookup_public_${type}s");
		foreach my $item (@array) {
			if ($item eq $target) { return 1; }
		}
		return 0;
	}

	if (defined($channel) && in_array('channel', $channel)) {
		return $blacklist ? 0 : 1;
	}
	if (defined($nick) && in_array('nick', $nick)) {
		return $blacklist ? 0 : 1;
	}

	return $blacklist ? 1 : 0;
}

### Signals
Irssi::signal_add_last('message public',  'event_message');
Irssi::signal_add_last('message private', 'event_message');
Irssi::signal_add_last('message topic', 'event_message_topic');

### Commands
Irssi::command_bind('spotify' => sub {
	my ($args, $server, $window) = @_;
	$args =~ s/\s+$//g;
	Irssi::command_runsub('spotify', $args, $server, $window);
});

Irssi::command_bind('spotify help', \&cmd_spotify_help);
Irssi::command_bind('help', \&cmd_help);

Irssi::command_bind('spotify lookup', \&cmd_spotify_lookup);
Irssi::command_bind('spotify -l', \&cmd_spotify_lookup);
Irssi::command_bind('spotify lookup help', \&cmd_spotify_help_lookup);
Irssi::command_bind('spotify lookup -h', \&cmd_spotify_help_lookup);
Irssi::command_bind('spotify lookup public', \&cmd_spotify_lookup);
Irssi::command_bind('spotify lookup -p', \&cmd_spotify_lookup);

Irssi::command_bind('spotify auto', \&cmd_spotify_auto);
Irssi::command_bind('spotify -a', \&cmd_spotify_auto);
Irssi::command_bind('spotify auto help', \&cmd_spotify_help_auto);
Irssi::command_bind('spotify auto -h', \&cmd_spotify_help_auto);
Irssi::command_bind('spotify auto info', \&cmd_spotify_auto_info);
Irssi::command_bind('spotify auto -i', \&cmd_spotify_auto);
Irssi::command_bind('spotify auto enable', \&cmd_spotify_auto);
Irssi::command_bind('spotify auto -e', \&cmd_spotify_auto);
Irssi::command_bind('spotify auto disable', \&cmd_spotify_auto);
Irssi::command_bind('spotify auto -d', \&cmd_spotify_auto);

Irssi::command_bind('spotify auto public', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto -p', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public help', \&cmd_spotify_help_auto_public);
Irssi::command_bind('spotify auto public -h', \&cmd_spotify_help_auto_public);
Irssi::command_bind('spotify auto public info', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public -i', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public enable', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public -e', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public disable', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public -d', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public whitelist', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public -w', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public blacklist', \&cmd_spotify_auto_public);
Irssi::command_bind('spotify auto public -b', \&cmd_spotify_auto_public);

Irssi::command_bind('spotify auto public add', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public -a', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public add nick', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public add -n', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public add channel', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public add -c', \&cmd_spotify_auto_public_add);
Irssi::command_bind('spotify auto public del', \&cmd_spotify_auto_public_del);
Irssi::command_bind('spotify auto public -d', \&cmd_spotify_auto_public_del);
Irssi::command_bind('spotify auto public del nick', \&cmd_spotify_auto_public_del);
Irssi::command_bind('spotify auto public del -n', \&cmd_spotify_auto_public_del);
Irssi::command_bind('spotify auto public del channel', \&cmd_spotify_auto_public_del);
Irssi::command_bind('spotify auto public del -c', \&cmd_spotify_auto_public_del);

### Settings
Irssi::settings_add_bool('spotify', 'spotify_automatic_lookup', 1);
Irssi::settings_add_bool('spotify', 'spotify_automatic_lookup_public', 0);
Irssi::settings_add_bool('spotify', 'spotify_automatic_lookup_public_blacklist', 0);

Irssi::settings_add_str('spotify', 'spotify_client_id', '');
Irssi::settings_add_str('spotify', 'spotify_client_secret', '');

Irssi::settings_add_str('spotify', 'spotify_header_format',         'Lookup result for %_%uri%_:');
Irssi::settings_add_str('spotify', 'spotify_track_format',          '%_%name%_ by %_%artist%_ (from %album) [%_%popularity%_]');
Irssi::settings_add_str('spotify', 'spotify_album_format',          '%_%name%_ by %_%artist%_ (%year) [%_%popularity%_]');
Irssi::settings_add_str('spotify', 'spotify_artist_format',         '%_%name%_ [%_%popularity%_]');
Irssi::settings_add_str('spotify', 'spotify_playlist_format',       '%_%name%_ by %_%owner%_');
Irssi::settings_add_str('spotify', 'spotify_user_format',           'Username: %_%user%_');

Irssi::settings_add_str('spotify', 'spotify_automatic_lookup_public_channels', '');
Irssi::settings_add_str('spotify', 'spotify_automatic_lookup_public_nicks', '');
