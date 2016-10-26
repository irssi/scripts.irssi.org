# /binary huora
# tuolostaa k.o. ikkunaan huora:n sijaan 01101001 ....
#
# and modified by carl 2004-03-09

# Changelog
# Version 1: original version by nchip
# Version 1.1: added unbinary function
# Verison 1.2: added server truncate detection (requested by André, thanks for spotting the problem) and choice to have spaces in the binary or not (reqested by Tapio)


use strict;
use Irssi;
use Irssi qw(command_bind command signal_add_last signal_stop settings_get_bool settings_add_bool);

use vars qw($VERSION %IRSSI);

#%IRSSI = (
#        authors     => "Riku Voipio",
#        contact     => "riku.voipio\@iki.fi",
#        name        => "binary",
#        description => "adds /binary command that converts what you type into 2-base string representation",
#        license     => "GPLv2",
#        url         => "http://nchip.ukkosenjyly.mine.nu/irssiscripts/",
#    );

$VERSION = "1.2";
%IRSSI = (
        authors     => "Carl Fischer",
        contact     => "carl.fischer\@netcourrier.com",
        name        => "binary",
        description => "adds /binary command that converts what you type into 2-base string representation, also decodes other peoples binary automatically",
        license     => "GPLv2",
	  );


sub cmd_binary {
	$_=join(" ",$_[0]);
	$_=reverse;
	my (@r);
	if (settings_get_bool('binary_spaces')) {
	    $r[0]="/say";
	} else {
	    $r[0]="/say ";
	}
	while ($a = chop($_)) {
	    push (@r,unpack ("B*", $a));}
	
	my $window = Irssi::active_win();
	if (settings_get_bool('binary_spaces')) {
	    $window->command(join (" ",@r));
	} else {
	    $window->command(join ("",@r));
	}
    }

# here ends the original code
# some of the following was strongly inspired by the kenny script

sub cmd_unbinary {
    pop @_;
    pop @_;
    my $window = Irssi::active_win();
    $window->print(unbinary($_[0]));
}

sub unbinary {
    my $r;
    if (settings_get_bool('binary_spaces')) {
	$r=pack("B*", join ("", split(" ", @_[0])));
    } else {
	$r=pack("B*", @_[0]);
    }
    return $r;
}

sub sig_binary {
    my ($server, $msg, $nick, $address, $target) = @_;
    if (($msg=~m/^([01]{8}( [01]{8})*)( [01]{1,7})*$/ and settings_get_bool('binary_spaces')) or ($msg=~m/^([01]{8}([01]{8})*)([01]{1,7})*$/ and not settings_get_bool('binary_spaces'))) {
	my $leftover="";
	$leftover="* (truncated by server)" if $3;
	$target=$nick if $target eq "";
	# the address may _never_ be emtpy, if it is its own_public
	$nick=$server->{'nick'} if $address eq "";
	$server->window_item_find($target)->print("[binary] <$nick> " .
						  unbinary($1) . $leftover, 'MSGLEVEL_CRAP');
	signal_stop() if not settings_get_bool('show_binary_too');
    }
}

signal_add_last('message own_public',  'sig_binary');
signal_add_last('message public',      'sig_binary');
signal_add_last('message own_private', 'sig_binary');
signal_add_last('message private',     'sig_binary');

settings_add_bool('lookandfeel', 'show_binary_too', 0);
settings_add_bool('lookandfeel', 'binary_spaces', 1);

Irssi::command_bind('binary', 'cmd_binary');
Irssi::command_bind('unbinary', 'cmd_unbinary');

Irssi::print("binary obfuscator vanity script loaded");
Irssi::print("written by nchip and updated by carl");
Irssi::print("--------------------------------------");
Irssi::print("/binary message");
Irssi::print("will send binary text to the current channel");
Irssi::print("");
Irssi::print("/unbinary obfuscated_text");
Irssi::print("will print the unobfuscated equivalent to your window (and not to the channel)");
Irssi::print("");
Irssi::print("/set show_binary_too on");
Irssi::print("will make this script print the binary equivalent as well as the translation to your screen whenever someone uses binary on the channel");
Irssi::print("/set binary_spaces off");
Irssi::print("will make the binary be printed as a single word with no spaces");
