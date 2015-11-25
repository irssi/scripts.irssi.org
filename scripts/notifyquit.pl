=pod

=head1 NAME

notifyquit.pl

=head1 DESCRIPTION

A script intended to alert people to the fact that their conversation partners
have quit or left the channel, especially useful in high-traffic channels, or
where you have C<JOINS PARTS QUITS> ignored.

=head1 INSTALLATION

This script requires that you have first installed and loaded F<uberprompt.pl>

Uberprompt can be downloaded from:

L<https://github.com/shabble/irssi-scripts/raw/master/prompt_info/uberprompt.pl>

and follow the instructions at the top of that file or its README for installation.

If uberprompt.pl is available, but not loaded, this script will make one
attempt to load it before giving up.  This eliminates the need to precisely
arrange the startup order of your scripts.

Copy into your F<~/.irssi/scripts/> directory and load with
C</SCRIPT LOAD F<notifyquit.pl>>.

=head1 SETUP

This script provides a single setting:

C</SET notifyquit_exceptions>, which defaults to "C</^https?/ /^ftp/>"

The setting is a space-separated list of regular expressions in the format
C</EXPR/>. If the extracted nickname matches any of these patterns, it isa
assumed to be a false-positive match, and is sent to the channel with no
further confirmation.

=head1 USAGE

When responding to users in a channel in the format C<$theirnick: some message>
(where the C<:> is not necessarily a colon, but the value of your
C<completion_char> setting), this script will check that the nickname still
exists in the channel, and will prompt you for confirmation if they have
since left.

It is intended for use for people who ignore C<JOINS PARTS QUITS>, etc, and
try to respond to impatient people, or those with a bad connection.

To send the message once prompted, either hit C<enter>, or C<y>.  Pressing C<n>
will abort sending, but leave the message in your input buffer just in case
you want to keep it.

=head1 AUTHORS

Original Copyright E<copy> 2011 Jari Matilainen C<E<lt>vague!#irssi@freenodeE<gt>>

Some extra bits
Copyright E<copy> 2011 Tom Feist C<E<lt>shabble+irssi@metavore.orgE<gt>>

=head1 LICENCE

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=head1 BUGS

I<None known.>

Please report any problems to L<https://github.com/shabble/irssi-scripts/issues/new>
or moan about it in C<#irssi@Freenode>.

=head1 TODO

=over 4

=item * Keep a watchlist of nicks in the channel, and only act to confirm if
they quit shortly before/during you typing a response.

keep track of the most recent departures, and upon sending, see if one of them
is your target. If so, prompt for confirmation.

So, add them on quit/kick/part, and remove them after a tiemout.

=back

=cut

###
#
# Parts of the script pertaining to uberprompt borrowed from
# shabble (shabble!#irssi/@Freenode), thanks for letting me steal from you :P
#
###

use strict;
use warnings;
use Irssi;
use Carp qw( croak );
use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = "0.3";
%IRSSI = (
              authors     => "Jari Matilainen",
              contact     => 'vague!#irssi@freenode on irc',
              name        => "notifyquit",
              description => "Notify if user has left the channel",
              license     => "Public Domain",
              url         => "http://gplus.to/vague",
              changed     => "24 Nov 16:00:00 CET 2015",
         );

my $active = 0;
my $permit_pending = 0;
my $pending_input = {};
my $verbose = 0;
my @match_exceptions;
my $watchlist = {};

sub script_is_loaded {
    return exists($Irssi::Script::{$_[0] . '::'});
}

if (script_is_loaded('uberprompt')) {
    app_init();
} else {
    print "This script requires 'uberprompt.pl' in order to work. "
      . "Attempting to load it now...";

    Irssi::signal_add('script error', 'load_uberprompt_failed');
    Irssi::command("script load uberprompt.pl");

    unless(script_is_loaded('uberprompt')) {
        load_uberprompt_failed("File does not exist");
    }
    app_init();
}

sub load_uberprompt_failed {
    Irssi::signal_remove('script error', 'load_uberprompt_failed');

    print "Script could not be loaded. Script cannot continue. "
        . "Check you have uberprompt.pl installed in your scripts directory and "
        .  "try again.  Otherwise, it can be fetched from: ";
    print "https://github.com/shabble/irssi-scripts/raw/master/"
        . "prompt_info/uberprompt.pl";

    croak "Script Load Failed: " . join(" ", @_);
}

sub extract_nick {
    my ($str) = @_;

    my $completion_char
      = quotemeta(Irssi::settings_get_str("completion_char"));

    # from BNF grammar at http://www.irchelp.org/irchelp/rfc/chapter2.html
    # special := '-' | '[' | ']' | '\' | '`' | '^' | '{' | '}'

    my $pattern = qr/^( [[:alpha:]]         # starts with a letter
                         (?: [[:alpha:]]         # then letter
                         | \d                # or number
                         | [\[\]\\`^\{\}-])  # or special char
                         *? )                # any number of times
                     $completion_char/x;     # followed by completion char.

    if ($str =~ m/$pattern/) {
        return $1;
    } else {
        return undef;
    }

}

sub check_nick_exemptions {
    my ($nick) = @_;
    foreach my $except (@match_exceptions) {
        _debug("Testing nick $nick against $except");
        if ($nick =~ $except) {
            _debug( "Failed match $except");
            return 0;           # fail
        }
    }
    _debug("match ok");

    return 1;
}

sub sig_send_text {
    my ($data, $server, $witem) = @_;

    return unless($witem);

    return unless ref $witem && $witem->{type} eq 'CHANNEL';

    # shouldn't need escaping, but it doesn't hurt to be paranoid.
    my $target_nick = extract_nick($data);

    if ($target_nick) {
        if (check_watchlist($target_nick, $witem->{name}, $server)
            and not $witem->nick_find($target_nick)) {

            return unless check_nick_exemptions($target_nick);

            if ($permit_pending) {
                $pending_input = {};
                $permit_pending = 0;
                Irssi::signal_continue(@_);
            } else {
                return unless check_watchlist($target_nick, $witem->{name}, $server);
                return unless check_watchlist($target_nick, '***', $server);

                my $text
                  = "$target_nick isn't in this channel, send anyway? [Y/n]";
                $pending_input
                  = {
                     text     => $data,
                     server   => $server,
                     win_item => $witem,
                    };

                Irssi::signal_stop();
                require_confirmation($text);
            }
        }
    }
}

sub sig_gui_keypress {
    my ($key) = @_;

    return if not $active;

    my $char = chr($key);

    # Enter, y, or Y.
    if ($char =~ m/^y?$/i) {
        $permit_pending = 1;
        Irssi::signal_stop();
        Irssi::signal_emit('send text',
                           $pending_input->{text},
                           $pending_input->{server},
                           $pending_input->{win_item});
        $active = 0;
        set_prompt('');

    } elsif ($char =~ m/^n?$/i or $key == 3 or $key == 7) {
        # we support n, N, Ctrl-C, and Ctrl-G for no.

        Irssi::signal_stop();
        set_prompt('');

        $permit_pending = 0;
        $active         = 0;
        $pending_input  = {};

    } else {
        Irssi::signal_stop();
        return;
    }
}


sub add_to_watchlist {
    my ($nick, $channel, $server, $type, $opts) = @_;
    my $tag = $server->{tag};
    _debug("Adding $nick to $channel/$tag");

    $watchlist->{$tag}->{$channel}->{$nick} = {
                                                timestamp => time(),
                                                type      => $type,
                                                options   => $opts,
                                              };
}

sub check_watchlist {
    my ($nick, $channel, $server) = @_;
    my $tag = $server->{tag};

    my $check = exists ($watchlist->{$tag}->{$channel}->{$nick});
    _debug("Check for $nick in $channel/$tag is " .( $check ? 'true' : 'false'));

    # check the server-wide list if the channel-specific one fails.
    if (not $check) {
        $check = exists ($watchlist->{$tag}->{'***'}->{$nick});
        _debug("Check for $nick in ***/$tag is " .( $check ? 'true' : 'false'));
    }

    return $check;
}

sub remove_from_watchlist {
    my ($nick, $channel, $server) = @_;
    my $tag = $server->{tag};

    if (exists($watchlist->{$tag}->{$channel}->{$nick})) {
        delete($watchlist->{$tag}->{$channel}->{$nick});
        _debug("Deleted $nick from $channel/$tag");
    }
}

sub cleanup_watchlist {
  my ($channel, $server) = @_;
  my $tag = $server->{tag};

  if(!keys %{$watchlist->{$tag}->{$channel}}) {
    delete($watchlist->{$tag}->{$channel});
    _debug("Cleanup $channel/$tag");
  }
  if(!keys %{$watchlist->{$tag}}) {
    delete($watchlist->{$tag});
    _debug("Cleanup $tag");
  }
}

sub start_watchlist_expire_timer {
    my ($nick, $channel, $server, $callback) = @_;

    my $tag = $server->{tag};
    my $timeout = Irssi::settings_get_time('notifyquit_timeout');

    Irssi::timeout_add_once($timeout,
                            $callback,
                            { nick => $nick,
                              channel => $channel,
                              server => $server,
                            });
}

sub sig_message_quit {
    my ($server, $nick, $address, $reason) = @_;

    my $tag = $server->{tag};

    _debug( "$nick quit from $tag");
    add_to_watchlist($nick, "***", $server, 'quit', undef);

    my $quit_cb = sub {

        # remove from all channels.
        foreach my $chan (keys %{ $watchlist->{$tag} }) {
            # if (exists $chan->{$nick}) {
            #     delete $watchlist->{$tag}->{$chan}->{$nick};
            # }
            remove_from_watchlist($nick, $chan, $server);
            cleanup_watchlist($chan, $server);
        }
    };

    start_watchlist_expire_timer($nick, '***', $server, $quit_cb);
}

sub sig_message_part {
    my ($server, $channel, $nick, $address, $reason) = @_;

    my $tag = $server->{tag};

    _debug( "$nick parted from $channel/$tag");
    add_to_watchlist($nick, $channel, $server, 'part', undef);
    my $part_cb = sub {
        remove_from_watchlist($nick, $channel, $server);
        cleanup_watchlist($channel, $server);
    };

    start_watchlist_expire_timer($nick, $channel, $server, $part_cb);
}

sub sig_message_kick {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
    _debug( "$nick kicked from $channel by $kicker");

    my $tag = $server->{tag};
    add_to_watchlist($nick, $channel, $server, 'kick', undef);

    my $kick_cb = sub {
        remove_from_watchlist($nick, $channel, $server);
        cleanup_watchlist($channel, $server);
    };

    start_watchlist_expire_timer($nick, $channel, $server, $kick_cb);
}

sub sig_message_nick {
    my ($server, $newnick, $oldnick, $address) = @_;
    my $tag = $server->{tag};

    _debug("$oldnick changed nick to $newnick ($tag)");
    #_debug( "Not bothering with this for now.");
    add_to_watchlist($oldnick, '***', $server, 'nick', $newnick);

    my $nick_cb = sub { 
        remove_from_watchlist($oldnick, '***', $server);
        cleanup_watchlist('***', $server);
    };

    start_watchlist_expire_timer($oldnick, '***', $server, $nick_cb);
}

sub app_init {
    Irssi::signal_add('setup changed'         => \&sig_setup_changed);
    Irssi::signal_add_first('message quit'    => \&sig_message_quit);
    Irssi::signal_add_first('message part'    => \&sig_message_part);
    Irssi::signal_add_first('message kick'    => \&sig_message_kick);
    Irssi::signal_add_first('message nick'    => \&sig_message_nick);
    Irssi::signal_add_first("send text"       => \&sig_send_text);
    Irssi::signal_add_first('gui key pressed' => \&sig_gui_keypress);
    Irssi::settings_add_str($IRSSI{name}, 'notifyquit_exceptions', '/^https?/ /^ftp/');
    Irssi::settings_add_bool($IRSSI{name}, 'notifyquit_verbose', 0);
    Irssi::settings_add_time($IRSSI{name}, 'notifyquit_timeout', '30s');

    # horrible name, but will serve.
    Irssi::command_bind('notifyquit_show_exceptions', \&cmd_show_exceptions);
    Irssi::command_bind('notifyquit_show_watchlist', \&cmd_show_watchlist);

    sig_setup_changed();
}

sub cmd_show_exceptions {
    foreach my $e (@match_exceptions) {
        print "Exception: $e";
    }
}

sub cmd_show_watchlist {
    Irssi::print(Dumper($watchlist));
}

sub sig_setup_changed {

    my $except_str = Irssi::settings_get_str('notifyquit_exceptions');
    $verbose = Irssi::settings_get_bool('notifyquit_verbose');
    my @except_list = split( m{(?:^|(?<=/))\s+(?:(?=/)|$)}, $except_str);

    @match_exceptions = ();

    foreach my $except (@except_list) {

        _debug("Exception regex str: $except");
        $except =~ s|^/||;
        $except =~ s|/$||;

        next if $except =~ m/^\s*$/;

        my $regex;

        eval {
            $regex = qr/$except/i;
        };

        if ($@ or not defined $regex) {
            print "Regex failed to parse: \"$except\": $@";
        } else {
            _debug("Adding match exception: $regex");
            push @match_exceptions, $regex;
        }
    }
}


sub require_confirmation {
    $active = 1;
    set_prompt(shift);
}

sub set_prompt {
    my ($msg) = @_;
    $msg = ': ' . $msg if length $msg;
    Irssi::signal_emit('change prompt', $msg, 'UP_INNER');
}

sub _debug {

    return unless $verbose;

    my ($msg, @params) = @_;
    my $str = sprintf($msg, @params);
    print $str;

}
