#!/usr/bin/perl -w
# $Id: randaway.pl,v 1.12 2003/01/10 10:47:04 lkarsten Exp lkarsten $
# Irssi script for random away-messages.
#
# adds /raway, /awayadd, /awayreasons and /awayreread.
#
# Based on simular script written by c0ffee.
# original version made public in march 2002.
#
# changelog: 
# sep/02 - kuba wszolek (hipis@linux.balta.pl) reported problems with multiple
# servers in v1.8 .. proposed fix is imported.
# jan/03 - Wouter Coekaerts (wouter@coekaerts.be) provided fix using 
# get_irssi_dir() instead of $ENV[]. imported.
#

use Irssi 20011116;
use Irssi::Irc;

$VERSION = '1.13';
%IRSSI = (
    authors	=> "Lasse Karstensen",
    contact	=> "lkarsten\@stud.ntnu.no",
    name 	=> "randaway.pl",
    description => "Random away-messages",
    license	=> "Public Domain",
    url		=> "http://www.stud.ntnu.no/~lkarsten/irssi/",
);

# file to read random reasons from. It should contain one
# reason at each line, empty lines and lines starting with # is 
# skipped.
$reasonfile = Irssi::get_irssi_dir() . "/awayreasons";

my @awayreasons;

sub readreasons {
        undef @awayreasons;
        if (-f $reasonfile) { 
                Irssi::print("=> Trying to read awayreasons from $reasonfile");
		open F, $reasonfile;

		# this actually makes the while() work like a while and not
		# like a read() .. ie, stopping at each \n.
		local $/ = "\n";
                while (<F>) {
		    $reason = $_;

		    # remove any naughty linefeeds.
		    chomp($reason);
		    
		    # skips reason if it's an empty line or line starts with #
		    if ($reason =~ /^$/ ) { next; }
		    if ($reason =~ /^#/ ) { next; }
		    
		    Irssi::print("\"$reason\"");
		    
		    # adds to array.
		    push(@awayreasons, $reason); 
                }
                close F; 
                Irssi::print("=> Read " . scalar(@awayreasons) . " reasons.");
        } else {
	    # some default away-reasons.
	    Irssi::print("Unable to find $reasonfile, no reasons loaded.");
	    push(@awayreasons, "i\'m pretty lame!");
	    push(@awayreasons, "i think i forgot something!"); 
	};  
}

sub cmd_away {
    # only do our magic if we're not away already. 
    
    if (Irssi::active_server()->{usermode_away} == 0) {
        my ($reason) = @_; 
	# using supplied reason if .. eh, supplied, else find a random one if not.
	if (!$reason) { $reason = $awayreasons[rand @awayreasons]; }
	Irssi::print("awayreason used: $reason");
        my $server = Irssi::servers();	
        $server->command('AWAY '.$reason);	
    } else {
	Irssi::print("you're already away");
    }
} 

sub add_reason {
    my ($reason) = @_;
    if (!$reason) {
        Irssi::print("Refusing to add empty reason.");
    } else {
	chomp($reason);
	# adding to current environment.
	push(@awayreasons, $reason);
	# and also saving it for later.  
	open(F, ">> $reasonsfile");
	print F $reason;
	close F;
	Irssi::print("Added: $reason");
    }
}

sub reasons {
    Irssi::print("Listing current awayreasons");
    foreach $var (@awayreasons) {
        Irssi::print("=> \"$var\""); 
    }
}

# -- main program --

readreasons();
Irssi::command_bind('raway', 'cmd_away');
Irssi::command_bind('awayreread', 'readreasons');
Irssi::command_bind('awayadd', 'add_reason');
Irssi::command_bind('awayreasons', 'reasons');

# -- end of script --
