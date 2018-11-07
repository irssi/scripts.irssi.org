use strict;
use warnings;
use Irssi 20171006;
use Irssi::UI;

our $VERSION = '1.0'; # 7775fccf37d60a5
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'savecmdhist',
    description => 'Saves the commands you typed in the input prompt to a history file, so that they persist across /upgrade and restart.',
    license     => 'ISC',
   );

# Usage
# =====
# Put the script in autorun if you want the history to be loaded on
# start.

my $histfile = Irssi::get_irssi_dir()."/cmdhistory";

sub loadcmdhist {
    my %R = ("n" => "\n", "\\" => "\\", ";" => ";");
    my $fh;
    unless (open $fh, '<', $histfile) {
	warn "Could not open history file ($histfile) for readin: $!\n"
	    if -e $histfile;
	return;
    }
    my @hist;
    while (defined(my $line = <$fh>)) {
	chomp $line;
	if ($line =~ /^: (\d*):(\d*):(.*?) :;(.*)$/) {
	    push @hist, +{
		time	=> $1,
		window	=> length $2 ? $2 : undef,
		history => length $3 ? $3 : undef,
	    };
	    $hist[-1]{text} = $4 =~ s/\\(\\|;|n)/$R{$1}/gmsr;
	}
    }
    my $he1 = @{[Irssi::UI::Window::get_history_entries(undef)]};
    Irssi::UI::Window::load_history_entries(undef, @hist) if @hist && $he1 <= 1;
}

sub savecmdhist {
    my %R = ("\n" => "\\n", "\\" => "\\\\", " :;" => " :\\;");
    my $old_umask =
	umask 0077;
    my $fh;
    unless (open $fh, '>', $histfile) {
	umask $old_umask;
	warn "Could not open history file ($histfile) for writing: $!\n";
	return;
    }
    umask $old_umask;
    no warnings 'uninitialized';
    for my $hist (Irssi::UI::Window::get_history_entries(undef)) {
	my $text = $hist->{text} =~ s/(\n|\\| :;)/$R{$1}/gmsr;
	print $fh ": $hist->{time}:$hist->{window}:$hist->{history} :;$text\n";
    }
    close $fh;
}

Irssi::signal_add 'gui exit' => sub {
    savecmdhist() if Irssi::settings_get_bool('settings_autosave');
};

Irssi::signal_add 'command save' => 'savecmdhist';

loadcmdhist();
