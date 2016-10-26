use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '0.1';
%IRSSI = (
    authors     => 'Kimmo Lehto',
    contact     => 'kimmo@a-men.org' ,
    name        => 'Paste-KimmoKe',
    description => 'Provides /start, /stop, /play <-nopack> <-nospace> paste mechanism - start and stop recording and then replay without linebreaks. Also /see to view what was recorded.',
    license     => 'Public Domain',
    changed	=> 'Wed Mar 27 14:51 EET 2002'
);

my $_active = undef;
my @_record = undef;
my $_recorded_stuff = undef;
my $_nospace = undef;
my $_nopack = undef;

sub cmd_start
{
	my ($arg, $server, $witem) = @_;
	
	if ($_active)
	{
		Irssi::print("ERROR - Already recording.");
		return 0;
	}

	$_active = 1;
	Irssi::print("Recording, enter /stop to end...");
	@_record = ();
	Irssi::signal_add_first("send text", "record");
}
	
sub cmd_stop
{
	my ($arg, $server, $witem) = @_;
	
	if (!$_active)
	{
		Irssi::print("ERROR - Not recording.");
		return 0;
	}

	$_active = undef;
	Irssi::signal_remove("send text", "record");
		
	Irssi::print('Recording ended. ' . ($#_record + 1) . ' lines captured. Use /see to see and /play to play recording without linefeeds (-help for reformatting options).');
}

sub record {
        my ($data) = @_;
	push @_record, $data;
	Irssi::signal_stop();
}

	

sub reformat {
	my ($arg) = @_;
	my $data;

        if ($arg =~ /\-nospace/)
        {
		$data = join("", @_record);
        }
	else
	{
		$data = join(" ", @_record);
	}
        if ($arg !~ /\-nopack/)
        {
		$data =~ s/\s+|\t+/ /g;
	}
        if ($arg =~ /help/i)
        {
                return("You can use -nospace if you wish to join the input lines without replacing linefeeds with spaces, or -nopack if you don\'t want to replace multiple spaces with only one space.");
        }
	return $data;
}

sub cmd_see {
        my ($arg, $server, $witem) = @_;

	@_record && Irssi::print(reformat($arg)); 
	Irssi::print("End of recorded input.");
}

sub cmd_play {
	my ($arg, $server, $witem) = @_;
	if ($arg =~ /help/i) { Irssi::print(reformat($arg)); return 0; }
	if (@_record)
	{
		Irssi::signal_emit("send text", reformat($arg), $server, $witem);
	}
	else
	{
		Irssi::print("ERROR - Nothing to play.");
	}
}
	
Irssi::command_bind('start', 'cmd_start');
Irssi::command_bind('stop', 'cmd_stop');
Irssi::command_bind('see', 'cmd_see');
Irssi::command_bind('play', 'cmd_play');



