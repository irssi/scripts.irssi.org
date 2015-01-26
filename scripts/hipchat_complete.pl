# hipchat_complete.pl - (c) 2013 John Morrissey <jwm@horde.net>
#                       (c) 2014 Brock Wilcox <awwaiid@thelackthereof.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# About
# =====
#
# Adds Hipchat tab completion support.
# 
# By default, Hipchat's XMPP interface sets user nicks to their full names,
# not their "mention names," so you always have to recall and manually type
# a user's mention name so Hipchat highlights the message, sends them e-mail
# if they're away, etc.
#
# This plugin tab-completes mention names and tab-translates name-based
# nicks to their corresponding "mention names."
#
# For example, if JohnMorrissey has a mention name of @jwm, all of these
# tab complete to @jwm:
#
#   John<tab>
#   @John<tab>
#   @jw<tab>
#
#
# To use
# ======
#
# 1. Install the WebService::HipChat module from CPAN.
#
# 2. /script load hipchat_completion.pl
#
# 3. Get a Hipchat auth v2 token (hipchat.com -> Account settings -> API
#    access). In irssi:
#
#    /set hipchat_auth_token some-hex-value
#
# 4. If your Hipchat server isn't in the "bitlbee" chatnet (the 'chatnet'
#    parameter in your irssi server list for the IRC server you use to
#    connect to Hipchat), specify the name of the chatnet:
#
#    /set hipchat_chatnet some-chatnet-name

use strict;

use Irssi;
use WebService::HipChat;

our $VERSION = '2.0';
our %IRSSI = (
	authors => 'John Morrissey',
	contact => 'jwm@horde.net',
	name => 'hipchat_complete',
	description => 'Translate nicks to HipChat "mention names"',
	license => 'BSD',
);

my %NICK_TO_MENTION;
my $LAST_MAP_UPDATED = 0;

sub get_hipchat_people {
	my $auth_token = Irssi::settings_get_str('hipchat_auth_token');
	if (!$auth_token) {
		return;
	}
	my $hc = WebService::HipChat->new(auth_token => $auth_token);

	my $hipchat_users = $hc->get_users->{items};
	foreach my $user (@{$hipchat_users}) {
		my $name = $user->{name};
		$name =~ s/[^A-Za-z]//g;
		$NICK_TO_MENTION{$name} = $user->{mention_name};
	}
	$LAST_MAP_UPDATED = time();
}

sub sig_complete_hipchat_nick {
	my ($complist, $window, $word, $linestart, $want_space) = @_;

	my $wi = Irssi::active_win()->{active};
	return unless ref $wi and $wi->{type} eq 'CHANNEL';
	return unless $wi->{server}->{chatnet} eq
		Irssi::settings_get_str('hipchat_chatnet');

	# Reload the nick -> mention name map periodically,
	# so we pick up new users.
	if (($LAST_MAP_UPDATED + 4 * 60 * 60) < time()) {
		get_hipchat_people();
	}

	if ($word =~ /^@/) {
		$word =~ s/^@//;
	}
	foreach my $nick ($wi->nicks()) {
		if ($nick->{nick} =~ /^\Q$word\E/i) {
			push(@$complist, "\@$NICK_TO_MENTION{$nick->{nick}}");
		}
	}
	foreach my $mention (values %NICK_TO_MENTION) {
		if ($mention =~ /^\Q$word\E/i) {
			push(@$complist, "\@$mention");
		}
	}

	# If there's a mention name completion that begins with $word,
	# prefer that over a channel nick/fullname.
	@$complist = sort {
		return $a =~ /^\@\Q$word\E(.*)$/i ? 0 : 1;
	} @$complist;
}

Irssi::settings_add_str('hipchat_complete', 'hipchat_auth_token', '');
Irssi::settings_add_str('hipchat_complete', 'hipchat_chatnet', 'bitlbee');
get_hipchat_people();
Irssi::signal_add('complete word', \&sig_complete_hipchat_nick);
