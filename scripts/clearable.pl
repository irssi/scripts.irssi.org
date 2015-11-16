use strict;
use warnings;

our $VERSION = '0.1'; # 5ef9502616f1301
our %IRSSI = (
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name	=> 'clearable',
    description	=> 'make some command output clearable',
    license	=> 'ISC',
   );

use Irssi 20140701;

sub cmd_help {
    return unless $_[0] =~ /^clearable\s*$/i;
    print CLIENTCRAP <<HELP
%9Syntax:%9

CLEARABLE <command>

%9Description:%9

    Runs command and tags each line of immediate output with the
    lastlog-flag so it can be cleared with /LASTLOG -clear

%9Example:%9

    /CLEARABLE NAMES
    /LASTLOG -clear

%9See also:%9 LASTLOG, SCROLLBACK CLEAR
HELP
}

my %refreshers;

sub sig_prt {
    my $win = $_[0]{window};
    my $view = $win && $win->view;
    return unless $view;
    my $llp = $view->{buffer}{cur_line}{_irssi}//0;
    &Irssi::signal_continue;
    $view = $win->view;
    my $l2 = $view->{buffer}{cur_line};
    return unless ($l2 && $l2->{_irssi} != $llp);
    for (my $line = $l2; $line && $line->{_irssi} != $llp; ) {
	$win->gui_printtext_after($line->prev, $line->{info}{level} | MSGLEVEL_NEVER | MSGLEVEL_LASTLOG, $line->get_text(1)."\n", $line->{info}{time});
	my $ll = $win->last_line_insert;
	$view->remove_line($line);
	$line = $ll && $ll->prev;
	$refreshers{ $win->{refnum} } //= $view->{bottom};
    }
}

sub cmd_clearable {
    my ($data, $server, $item) = @_;
    Irssi::signal_add_first('print text' => 'sig_prt');
    Irssi::signal_emit('send command'	 => Irssi::parse_special('$k').$data, $server, $item);
    Irssi::signal_remove('print text'	 => 'sig_prt');
    for my $refnum (keys %refreshers) {
	my $bottom = delete $refreshers{$refnum};
	my $win = Irssi::window_find_refnum($refnum) // next;
	my $view = $win->view;
	$win->command('^scrollback end') if $bottom && !$view->{bottom};
	$view->redraw;
    }
}

Irssi::command_bind('clearable' => 'cmd_clearable');
Irssi::command_bind_last('help' => 'cmd_help');
