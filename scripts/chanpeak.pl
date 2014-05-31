#####
# chanpeak.pl (last update 05/09/2001)
#
#      by Bjoern 'fuchs' Krombholz
#     for irssi v0.7.99
#
# History:
#   * 0.2.1  remove spaces from /chanpeak arg's end
#   * 0.2.0  !-channel support
#   * 0.1.3  bug fix args evaluation
#   * 0.1.2  bad bug with delimiters in file
#   * 0.1.1  automatically choose active channel; use strict
#   * 0.1.0  initial release
#
# TODO:
#   * delete records
#####

use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = "0.2.2";
%IRSSI = (
		  authors     => "Bjoern \'fuchs\' Krombholz",
		  contact     => "bjkro\@gmx.de",
		  name        => "chanpeak",
		  license     => "Public Domain",
		  description => "Log maximum number of people ever been in a channel",
		  changed     => "Wed Jun  2 17:00:00 CET 2002",
		  changes     => "added header, removed debugging outputs"
		 );


# path to peak data file
my $peakfile = "$ENV{HOME}/.irssi/peak.data";
# automatically save peak data file on every new peak
my $peak_autosave = 1;
# just for debugging purposes
my $peak_DEBUG = 0;

#################################################

my %chanpeak;


###
# Remove channel ID for !-channels
sub sub_chan {
    my $chan = @_[0];
    $chan =~ s/^\!\w{5}?/\!/;
    return $chan;
}

###
# Print some help
sub help_chanpeak {
    Irssi::print("No peak record found");
    Irssi::print("\nCHANPEAK [<channel>[@<chatnet>]]\n", MSGLEVEL_CLIENTCRAP);
    Irssi::print("Shows user peak for <channel>.\n", MSGLEVEL_CLIENTCRAP);
    Irssi::print("If your current window is a channel window,\n".
				 "print this channel's peak if <channel>\nomitted.",
				 MSGLEVEL_CLIENTCRAP);
    Irssi::print("Prints matching <channel> peaks of all\n".
				 "ChatNets if <chatnet> omitted.\n", MSGLEVEL_CLIENTCRAP);
}


###
# Output requested peak
sub cmd_chanpeak {
    my ($data, $server, $channel) = @_;
    my ($chan, $tag) = split(/@/, lc($data));
    $chan =~ s/ *$//;
    my $key;

    $chan = sub_chan($chan);
    if ($chan eq "" && Irssi::active_win()->{active}->{type} eq "CHANNEL") {
		$chan = sub_chan( lc(Irssi::active_win()->{active}->{name}) );
		$tag = lc(Irssi::active_win()->{active}->{server}->{tag});
		Irssi::active_win()->{active}->print("Peak for ".$chan."@".$tag.": ".
											 $chanpeak{$chan}{$tag}{peak}." (".
											 localtime($chanpeak{$chan}{$tag}{date}).")");
		return 0;
    } elsif (exists $chanpeak{$chan}) {
		foreach $key (keys %{$chanpeak{$chan}}) {
			if ($key eq $tag || $tag eq "") {
				Irssi::print("Peak for ".$chan."@".$key.": ".
							 $chanpeak{$chan}{$key}{peak}." (".
							 localtime($chanpeak{$chan}{$key}{date}).")");
			}
		}
		return 0;
    } else {
		help_chanpeak();
		return 0;
    }
}

###
# Save peak records to file
sub cmd_savepeak {
    my ($chan, $key, $tag);

    if ( !open(PEAKDATA, '>', $peakfile) ) {
		Irssi::print("Chanpeak: Could not create datafile ".$peakfile);
		return 1;
    }
    foreach $chan (keys %chanpeak) {
		foreach $tag (keys %{$chanpeak{$chan}}) {
			print (PEAKDATA $chan." ".$tag." ".$chanpeak{$chan}{$tag}{peak}." ".
				   $chanpeak{$chan}{$tag}{date}."\n");
		}
    }
    Irssi::print("Chanpeak: Saved peak data to ".$peakfile) if ( $peak_DEBUG );
    close PEAKDATA;
}

###
# Update peak record
sub update_peakrec {
    my $channel = @_[0];
    my $chan = lc($channel->{name});
    my $tag = lc($channel->{server}->{tag});
    my @nicks = $channel->nicks();
    my $peak = @nicks;

    $chan = sub_chan($chan);
    if (!exists $chanpeak{$chan}{$tag}{peak}
		|| $peak > $chanpeak{$chan}{$tag}{peak}) {
		$chanpeak{$chan}{$tag}{peak} = $peak;
		$chanpeak{$chan}{$tag}{date} = time();
		Irssi::print("New peak in ".$chan."@".$tag." : ".$peak);
		if ($peak_autosave) {
			cmd_savepeak();
		}
    }
}

###
# Read data file and initialize already joined channels
sub init_chanpeak {
    my ($chan, $channel, $date, $line, $peak, $tag);

    if ( !open(PEAKDATA, '<', $peakfile) ) {
		Irssi::print('Chanpeak: datafile not found, creating...');
		if ( !open(PEAKDATA, '>', $peakfile) ) {
			Irssi::print('Chanpeak: Couldn\'t create datafile `'.$peakfile.'\'!');
			return 1;
		}
		close PEAKDATA;
    } else {
		my @lines = <PEAKDATA>;
		foreach $line (@lines) {
			if ($line eq "\n") {
				next;
			}
			$line =~ s/\n//;
			($chan, $tag, $peak, $date) = split(/ /, $line, 4);
			$chanpeak{$chan}{$tag}{peak} = $peak;
			$chanpeak{$chan}{$tag}{date} = $date;
		}
		close PEAKDATA;
    }

    foreach $channel (Irssi::channels()) {
		$chan = lc($channel->{name});
		update_peakrec($channel);
    }
}

init_chanpeak();

Irssi::signal_add('channel sync', 'update_peakrec');
Irssi::signal_add_last('massjoin', 'update_peakrec');

Irssi::command_bind('chanpeak', 'cmd_chanpeak', 'chanpeak commands');
Irssi::command_bind('savepeak', 'cmd_savepeak', 'chanpeak commands');
Irssi::command_bind('quit', 'cmd_savepeak');
Irssi::command_bind('save', 'cmd_savepeak');

Irssi::print("chanpeak.pl loaded...");
