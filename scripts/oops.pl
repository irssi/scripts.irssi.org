use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '20180707';
%IRSSI = (
    authors     => 'bw1 and others',
    contact     => 'bw1@aol.at',
    name        => 'oops',
    description =>
    'turns \'ll\' and \'ls\' in the beginning of a sent line into the names or whois commands',
    license => 'Public Domain',
    );

my @words;
my $wordonly;
my $warn_msg;
my $help = <<eof;
%9Settings:%9
  $IRSSI{name}_words
    a list of words separated by a whitespace
  $IRSSI{name}_wordonly
    match if the word stand alone 
  $IRSSI{name}_warn_msg
    output only a warning message
eof

sub send_text {
    #"send text", char *line, SERVER_REC, WI_ITEM_REC
    my ( $data, $server, $witem ) = @_;

    my $find='';
    if ($wordonly) {
        foreach (@words) {
            if ( $data =~ m/^$_$/ ) {
                $find=$_;
            }
        }
    } else {
        foreach (@words) {
            if ( $data =~ m/^$_(\s|$)/ ) {
                $find=$_;
            }
        }
    }

    if($find && defined $witem) {
        if ($warn_msg) {
            $witem->print("%r$IRSSI{name}:%n warning before word '$find'",MSGLEVEL_CRAP);
            Irssi::signal_stop();
        } else {
            if($witem->{type} eq "CHANNEL")
            {
                $witem->command("names $witem->{name}");
                Irssi::signal_stop();
            }
            elsif($witem->{type} eq "QUERY")
            {
                $witem->command("whois $witem->{name}");
                Irssi::signal_stop();
            }
        }
    }
}

sub cmd_help {
    if ($_[0] eq $IRSSI{name} ) {
        Irssi::print($help, MSGLEVEL_CLIENTCRAP);
        Irssi::signal_stop;
    }
}

sub reload_settings {
    @words= split /\s+/,Irssi::settings_get_str($IRSSI{name}."_words");
    $wordonly=Irssi::settings_get_bool($IRSSI{name}."_wordonly");
    $warn_msg=Irssi::settings_get_bool($IRSSI{name}."_warn_msg");
}

Irssi::settings_add_str($IRSSI{name},$IRSSI{name}."_words", "ls");
Irssi::settings_add_bool($IRSSI{name},$IRSSI{name}."_wordonly", "off");
Irssi::settings_add_bool($IRSSI{name},$IRSSI{name}."_warn_msg", "off");

Irssi::signal_add('setup changed', \&reload_settings);
Irssi::signal_add 'send text' => 'send_text';

Irssi::command_bind('help', \&cmd_help );

reload_settings();

# vim:set sw=4 expandtab:
