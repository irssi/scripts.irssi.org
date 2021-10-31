# SETUP INSTRUCTIONS:
#
###  Step 1. Install the perl dependencies.
#
# This script requires the perl modules "HTML::Entities" and
# "WWW::Telegram::BotAPI" to function.
#
# To set this up, run the following in a shell:
#
#     cpan -i HTML::Entities WWW::Telegram::BotAPI
#
# (Might require sudo.)
#
###  Step 2. Install the script
#
# Place the script in `.irssi/scripts` and run
#
#     /script load telegram-notify.pl
#
# Or see https://scripts.irssi.org for instructions on loading scripts.
#
###  Step 3. Create the bot account on Telegram
#
# Message @BotFather on Telegram to set up a new bot. This should provide you
# with an authentication token.
#
# Configure the script to use the token by typing the following into irssi:
#
#     /set telegram-notify_auth-token <TOKEN-HERE>
#
###  Step 4. Configure the script
#
# Configure who the script should notify by typing the following into irssi:
#
#     /set telegram-notify_username <username>
#
# (With or without @ in front.)
#
###  Step 5. Activate the bot
#
# In Telegram, enter the username of the bot into the search field, and activate
# the bot by selecting the bot and clicking "Start" (or writing /start).
#
# When you have done so, inside of Irssi, type:
#
#     /telegram-notify-activate
#
###  Step 6. Finalize the setup
#
# In irssi, write
#
#     /save
#
# to persist your settings, and the setup is complete.
#

use utf8;
use 5.016;
use Irssi;

use Data::Dumper;
use HTML::Entities qw(encode_entities);
use WWW::Telegram::BotAPI;

our $VERSION = "1.00";
our %IRSSI = (
    authors     => 'Sebastian Paaske Tørholm',
    contact     => 'sebbe@cpan.org',
    name        => 'telegram-notify',
    description => 'Send notifications of highlighted messages over Telegram',
    license     => 'MIT',
);

sub debug {
    my $msg = shift;
    $msg = join("\n", map { "[telegram-notify] $_" } split(/\n/, $msg));
    Irssi::print($msg, MSGLEVEL_CLIENTCRAP);
}

sub setting_name { return sprintf('telegram-notify_%s', shift); }

Irssi::settings_add_str('telegram-notify', setting_name('chatid'), '');
Irssi::settings_add_str('telegram-notify', setting_name('auth-token'), '');
Irssi::settings_add_str('telegram-notify', setting_name('username'), '');

sub get_api {
    my $token = Irssi::settings_get_str(setting_name('auth-token'));
    unless ($token) {
        debug("Please configure an auth token.");
        return;
    }

    my $api = WWW::Telegram::BotAPI->new(token => $token);

    return $api;
}

sub notify {
    my $message = shift;

    my $api = get_api;
    return unless $api;

    my $chatid = Irssi::settings_get_str(setting_name('chatid'));
    unless ($chatid) {
        debug("Please activate the bot by messaging it on Telegram, and running `/telegram-notify-activate` in irssi.");
        return;
    }

    $api->sendMessage({
        chat_id    => $chatid,
        text       => encode_entities($message),
        parse_mode => 'HTML',
    });
}

sub private_message {
    my ($server, $msg, $nick, $address) = @_;

    notify("PM from $nick: $msg");
}

sub general_message {
    my ($dest, $text, $stripped_text) = @_;

    return unless $dest->{server};
    return unless $dest->{level} & MSGLEVEL_HILIGHT;

    notify( sprintf("(%s) %s", $dest->{target}, $stripped_text) );
}

sub cmd_activate {
    my $args = shift;

    my $api = get_api;

    my $updates = $api->getUpdates;

    my $username = Irssi::settings_get_str(setting_name('username'));
    $username =~ s/^\@//;

    my $update = 0;

    if ($updates->{ok}) {
        for my $res (@{ $updates->{result} }) {
            next unless $res->{message};

            my $chat = $res->{message}->{chat};
            next unless $chat;

            if (fc($chat->{username}) eq fc($username)) {
                Irssi::settings_set_str(setting_name('chatid'), $chat->{id});
                $update = 1;
            }
        }
    }

    if ($update) {
        debug("Bot successfully configured. Sending test message.");
        notify("Bot successfully configured. Hello from irssi!");
    } else {
        debug("Unable to find chat session. Please send '/start' to the bot on Telegram and try again.");
    }
}

Irssi::signal_add('message private', \&private_message);
Irssi::signal_add('print text', \&general_message);

Irssi::command_bind('telegram-notify-activate', \&cmd_activate);


=encoding utf-8

=pod

Copyright 2020 Sebastian Paaske Tørholm

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
