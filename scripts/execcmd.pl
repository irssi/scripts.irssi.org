use strict;
use warnings;
use Text::ParseWords;
use Irssi;

our $VERSION = '0.1'; # 4d6028fb2f92d73
our %IRSSI = (
    authors     => 'unknown, Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'execcmd',
    description => 'Permit to use /EXEC with arbitrary irssi commands.',
   );

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^exec\s*$/i) {
        print CLIENTCRAP <<HELP
(Script: Execute arbitrary client commands with exec.)

EXEC [-] [-nosh] -cmd <irssi command> [-name <name>] <cmd line>

    -cmd:            The client command to run.

Example: /EXEC -cmd "me is running:" lsb_release -ds

HELP

    }
}

my %cmd_processes;
sub cmd_execcmd {
    my @args = parse_line(qr/\s+/, 'delimiters', $_[0]);
    my $newargs = '';
    my $execcmd;
    return unless grep /^-cmd$/i, @args;
    while (@args) {
	for ($args[0]) {
	    if (/^-(?:na|m|no|in|l)/i) {
		for (0..3) { $newargs .= $args[0]//''; shift @args; }
	    }
	    elsif (/^-cmd$/i) {
		$execcmd = $args[2];
		for (0..3) { shift @args; }
	    }
	    else { $newargs .= $_; shift @args; }
	}
    }
    if (defined $execcmd) {
	my @args = parse_line(qr/\s+/, '', $execcmd);
	local our $EXECCMD = "@args";
	Irssi::signal_continue($newargs, @_[1..$#_]);
    }
}

sub exec_new_ {
    if (defined our $EXECCMD) {
	$cmd_processes{ $_[0]->{_irssi} } = $EXECCMD;
    }
}

sub exec_remove_ {
    delete $cmd_processes{ $_[0]->{_irssi} };
}

sub ir_ps {
    my $w = shift;
    if (ref $w && ref $w->{active}) { $w->{active}->parse_special(@_) }
    elsif (ref $w && ref $w->{active_server}) { $w->{active_server}->parse_special(@_) }
    else { &Irssi::parse_special(@_) }
}

sub exec_input_ {
    if (exists $cmd_processes{ $_[0]->{_irssi} }) {
	my $cmd = $cmd_processes{ $_[0]->{_irssi} };
	if ($cmd =~ /\$/) { $cmd = ir_ps($_[0]{target_win}, $cmd, $_[1]) }
	else { $cmd .= ' '.$_[1] }
	if ($_[0]{target_win}) {
	    $_[0]{target_win}->command($cmd);
	}
	else {
	    Irssi::command($cmd);
	}
	Irssi::signal_stop;
    }
}

Irssi::signal_add_first('command exec' => 'cmd_execcmd');
Irssi::signal_add({
    'exec new'	  => 'exec_new_',
    'exec remove' => 'exec_remove_',
    'exec input'  => 'exec_input_'
   });
Irssi::command_bind_last 'help' => 'cmd_help';

