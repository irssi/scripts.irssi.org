use strict;
use warnings;

our $VERSION = '0.2'; # 89b09c06774210c
our %IRSSI = (
    name	=> 'nickcolor_gay',
    description	=> 'colourise nicks',
    license	=> 'ISC',
   );

use Hash::Util qw(lock_keys);
use Irssi;


{ package Irssi::Nick }

my @action_protos = qw(irc silc xmpp);
my $lastnick;

sub msg_line_tag {
    my ($srv, $msg, $nick, $addr, $targ) = @_;
    my $obj = $srv->channel_find($targ);
    clear_ref(), return unless $obj;
    my $nickobj = $obj->nick_find($nick);
    $lastnick = $nickobj ? $nickobj->{nick} : undef;
}

sub msg_line_tag_xmppaction {
    clear_ref(), return unless @_;
    my ($srv, $msg, $nick, $targ) = @_;
    msg_line_tag($srv, $msg, $nick, undef, $targ);
}

sub msg_line_clear {
    clear_ref();
}

{my %m; my $i = 16; for my $l (
qw(E T A O I N S H R D L C U M W F G Y P B V K J X Q Z),
qw(0 1 2 3 4 5 6 7 8 9),
qw(e t a o i n s h r d l c u m w f g y p b v k j x q z),
qw(_ - [ ] \\ ` ^ { } ~),
) {
    $m{$l}=$i++;
}

sub rainbow {
    my $nick = shift;
    $nick =~ s/(.)/exists $m{$1} ? sprintf "\cC%02d%s", $m{$1}, $1 : $1/ge;
    $nick
}
}

sub prnt_clear_public {
    return unless defined $lastnick;
    my ($dest, $txt) = @_;
    if ($dest->{level} & MSGLEVEL_PUBLIC) {
	my @nick_reg;
	unshift @nick_reg, quotemeta substr $lastnick, 0, $_ for 1 .. length $lastnick;
	for my $nick_reg (@nick_reg) {
	    if ($txt =~ s/($nick_reg)/rainbow($1)/e) {
		Irssi::signal_continue($dest, $txt, $_[2]);
		last;
	    }
	}
	clear_ref();
    }
}

sub prnt_format_clear_public {
    return unless defined $lastnick;
    my ($theme, $module, $dest, $format, $nick, @args) = @_;
    if ($dest->{level} & MSGLEVEL_PUBLIC) {
	$nick = rainbow($nick);
	Irssi::signal_continue($theme, $module, $dest, $format, $nick, @args);
	clear_ref();
    }
}

sub clear_ref {
    $lastnick = undef;
}

Irssi::signal_add({
    'message public'	 => 'msg_line_tag',
    'message own_public' => 'msg_line_clear',
    (map { ("message $_ action"     => 'msg_line_tag',
	    "message $_ own_action" => 'msg_line_clear')
       } qw(irc silc)),
    "message xmpp action"     => 'msg_line_tag_xmppaction',
    "message xmpp own_action" => 'msg_line_clear',
});
if ((Irssi::parse_special('$abiversion')||0) >= 28) {
Irssi::signal_add({
    'print format'	 => 'prnt_format_clear_public',
});
} else {
Irssi::signal_add({
    'print text'	 => 'prnt_clear_public',
});
}
