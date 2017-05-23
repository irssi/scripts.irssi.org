use strict;
use warnings;

use Irssi;
use vars qw($VERSION %IRSSI %config);
use LWP::UserAgent;
use Scalar::Util qw(looks_like_number);

$VERSION = '0.0.1';

%IRSSI = (
    authors => 'Kevin Siml',
    contact => 'kevinsiml@googlemail.com',
    name => 'pushsafer',
    description => 'Push hilights and private messages when away by the pushsafer.com API',
    license => 'BSD',
    url => 'https://www.pushsafer.com',
    changed => "2017-03-31"
);

my $pushsafer_ignorefile;


sub cmd_help {
    my $out = <<'HELP_EOF';
PUSHIGNORE LIST
PUSHIGNORE ADD <hostmask>
PUSHIGNORE REMOVE <number>

The mask matches in the format ident@host. Notice that no-ident responses puts
a tilde in front of the ident.

Examples:
  Will match foo@test.bar.de but *not* ~foo@test.bar.se.
    /PUSHIGNORE ADD foo@*.bar.de  
  Use the list-command to show a list of ignores and the number in front
  combined with remove to delete that mask.
    /PUSHIGNORE REMOVE 2

For a list of available settings, run:
  /set pushsafer
HELP_EOF
    chomp $out;
    Irssi::print($out, MSGLEVEL_CLIENTCRAP);
}
sub read_settings {
    $pushsafer_ignorefile = Irssi::settings_get_str('pushsafer_ignorefile');
}

sub debug {
    return unless Irssi::settings_get_bool('pushsafer_debug');
    my $text = shift;
    my @caller = caller(1);
    Irssi::print('From '.$caller[3].': '.$text);
}

sub send_push {
    my $private_key = Irssi::settings_get_str('pushsafer_key');
    if (!$private_key) {
        debug('Missing Pushsafer.com private or alias_key.');
        return;
    }

    debug('Sending notification.');
    my ($channel, $text) = @_;
    my $resp = LWP::UserAgent->new()->post(
        'https://www.pushsafer.com/api', [
            k => $private_key,
            m => $text,
            d => Irssi::settings_get_str('pushsafer_device'),
            s => Irssi::settings_get_str('pushsafer_sound'),
            i => Irssi::settings_get_str('pushsafer_icon'),
            v => Irssi::settings_get_str('pushsafer_vibration'),
            u => Irssi::settings_get_str('pushsafer_url'),
            ut => Irssi::settings_get_str('pushsafer_urltitle'),
            l => Irssi::settings_get_str('pushsafer_time2live'),
            t => $channel
        ]
    );

    if ($resp->is_success) {
        debug('Notification successfully sent.');
    }
    else {
        debug('Notification not sent: '.$resp->decoded_content);
    }
}

sub msg_pub {
    my ($server, $data, $nick, $address, $target) = @_;
    my $safeNick = quotemeta($server->{nick});

    if(check_ignore_channels($target)) {
        return;
    }

    if(check_ignore($address) || check_away($server)) {
        return;
    }

    if ($data =~ /$safeNick/i) {
        debug('Got pub msg.');
        send_push($target, $nick.': '.Irssi::strip_codes($data));
    }
}

sub msg_print_text {
    my ($dest, $text, $stripped) = @_;
    my $server = $dest->{server};
    my $target = $dest->{target};

    return if (!$server || !($dest->{level} & MSGLEVEL_HILIGHT));

    if(check_ignore_channels($target)) {
        return;
    }

    if(check_away($server)) {
        return;
    }

    debug('Got nick highlight');
    $stripped =~ s/^\s+|\s+$//g;
    send_push($target, $stripped);
}

sub msg_pri {
    my ($server, $data, $nick, $address) = @_;

    if(check_ignore($address) || check_away($server)) {
        return;
    }
    debug('Got priv msg.');
    send_push('Priv, '.$nick, Irssi::strip_codes($data));
}

sub msg_kick {
    my ($server, $channel, $nick, $kicker, $address, $reason) = @_;

    if(check_ignore($address) || check_away($server)) {
        return;
    }

    if ($nick eq $server->{nick}) {
        debug('Was kicked.');
        send_push('Kicked: '.$channel, 'Was kicked by: '.$kicker.'. Reason: '.Irssi::strip_codes($reason));
    }
}

sub msg_test {
   my ($data, $server, $item) = @_;
   $data =~ s/^([\s]+).*$/$1/;
   my $orig_debug = Irssi::settings_get_bool('pushsafer_debug');
   Irssi::settings_set_bool('pushsafer_debug', 1);
   debug("Sending test message :" . $data);
   send_push("Test Message", Irssi::strip_codes($data));
   Irssi::settings_set_bool('pushsafer_debug', $orig_debug);
}

# check our away status & pushsafer_only_if_away. returns 0 if it's ok to send a message. 
sub check_away {
    my ($server) = @_;
    my $msg_only_if_away = Irssi::settings_get_bool('pushsafer_only_if_away');
    if ($msg_only_if_away && $server->{usermode_away} != '1') {
        debug("Only sending messages if we're marked as away, and we're not");
        return 1;
    }
    return 0;
}

sub check_ignore {
    return 0 unless(Irssi::settings_get_bool('pushsafer_ignore'));
    my @ignores = read_file();
    return 0 unless(@ignores);
    my ($mask) = @_;

    foreach (@ignores) {
        $_ =~ s/\./\\./g;
        $_ =~ s/\*/.*?/g;
        if ($mask =~ m/^$_$/i) {
            debug('Ignore matches, not pushing.');
            return 1;
        }
    }
    return 0;
}

sub check_ignore_channels {
    my ($target) = @_;
    my @ignore_channels = split(' ', Irssi::settings_get_str('pushsafer_ignorechannels'));
    return 0 unless @ignore_channels;
    if (grep {lc($_) eq lc($target)} @ignore_channels) {
        debug("$target set as ignored channel.");
        return 1;
    }
    return 0;
}

sub ignore_handler {
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub('pushignore', $data, $server, $item);
}

sub ignore_unknown {
    cmd_help();
    Irssi::signal_stop(); # Don't print 'no such command' error.
}

sub ignore_list {
    my @data = read_file();
    if (@data) {
        my $i = 1;
        my $out;
        foreach(@data) {
            $out .= $i++.". $_\n";
        }
        chomp $out;
        Irssi::print($out, MSGLEVEL_CLIENTCRAP);
    }
}

sub ignore_add {
    my ($data, $server, $item) = @_;
    $data =~ s/^([\s]+).*$/$1/;
    return Irssi::print("No hostmask given.", MSGLEVEL_CLIENTCRAP) unless($data ne "");

    my @ignores = read_file();
    push(@ignores, $data);
    write_file(@ignores);
    Irssi::print("Successfully added '$data'.", MSGLEVEL_CLIENTCRAP);
}

sub ignore_remove {
    my($num, $server, $item) = @_;
    $num =~ s/^(\d+).*$/$1/;
    return Irssi::print("List-number is needed when removing", MSGLEVEL_CLIENTCRAP) unless(looks_like_number($num));
    my @ignores = read_file();
    
    # Index out of range
    return Irssi::print("Number was out of range.", MSGLEVEL_CLIENTCRAP) unless(scalar(@ignores) >= $num);
    delete $ignores[$num-1];
    write_file(@ignores); 
}

sub write_file {
    read_settings();
    my $fp;
    if (!open($fp, ">", $pushsafer_ignorefile)) {
        Irssi::print("Error opening ignore file", MSGLEVEL_CLIENTCRAP);
        return;
    }
    print $fp join("\n", @_);
    close $fp;
}

sub read_file {
    read_settings();
    my $fp;
    if (-e $pushsafer_ignorefile) {
        if (!open($fp, "<", $pushsafer_ignorefile)) {
            Irssi::print("Error opening ignore file", MSGLEVEL_CLIENTCRAP);
            return;
        }
    }

    my @out;
    while (<$fp>) {
        chomp;
        next if $_ eq '';
        push(@out, $_);
    }
    close $fp;

    return @out;
}

Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_key', '');
Irssi::settings_add_bool($IRSSI{'name'}, 'pushsafer_debug', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushsafer_ignore', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'pushsafer_only_if_away', 0);
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_ignorefile', Irssi::get_irssi_dir().'/pushsafer_ignores');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_ignorechannels', '');

# Check the Pushsafer.com API > https://www.pushsafer.com/en/pushapi for replacing params
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_sound', '21');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_device', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_icon', '25');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_vibration', '0');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_url', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_urltitle', '');
Irssi::settings_add_str($IRSSI{'name'}, 'pushsafer_time2live', '');

Irssi::command_bind('help pushignore', \&cmd_help);
Irssi::command_bind('pushignore help', \&cmd_help);
Irssi::command_bind('pushignore add', \&ignore_add);
Irssi::command_bind('pushignore remove', \&ignore_remove);
Irssi::command_bind('pushignore list', \&ignore_list);
Irssi::command_bind('pushignore', \&ignore_handler);
Irssi::command_bind('pushtest', \&msg_test);
Irssi::signal_add_first("default command pushignore", \&ignore_unknown);


#Irssi::signal_add_last('message public', 'msg_pub');
Irssi::signal_add_last('print text', 'msg_print_text');
Irssi::signal_add_last('message private', 'msg_pri');
Irssi::signal_add_last('message kick', 'msg_kick');

Irssi::print('%Y>>%n '.$IRSSI{name}.' '.$VERSION.' loaded.');
if (!Irssi::settings_get_str('pushsafer_key')) {
    Irssi::print('%Y>>%n '.$IRSSI{name}.' Pushsafer.com private or alias key is not set, set it with /set pushsafer_key YourPrivateOrAliasKey');
}
