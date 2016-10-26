#DEMONENS SCROLLER SCRIPT!
#scroller.pl

#This script will create a small 10-character scroller on the irssi status bar.
#It is pretty much useless.
#I use it to remind myself about meetings, phonecalls I'm supposed to make etc
#
#Enjoy to the extent possible.
#
# -Demonen
#
#To make it show up in irrsi, do this:
# 1) put scroller.pl in ~/.irssi/scripts
#    This is where irssi expects to find scripts
#
# 2) in irssi, give the command /script load scroller
#    Some stuff will appear in your status window.
#
# 3) in irssi, give the command /statusbar window add -after more -alignment right scroller
#    This will enable the scroller element on the status bar.
#
# 4) in irssi, give the command /set scrollerText <something>
#    This will scroll the text <something>
#
# 5) in irssi, give the command /set scrollerSpeed <something>
#    This is the delay in milliseconds before it cycles to the next character.
#    I use 200 here, but anything above 10 is just fine.


use Irssi;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION="0.01";
%IRSSI = (
	authors=> 'Demonen',
	contact=> 'demmydemon@gmail.com',
	name=> 'scroller',
	description=> 'Scrolls specified text on the status bar',
	license=> 'Public Domain',
);


my ($scalarSize, $subset, $start, $end, $timeout, $count, $time, $scalar);


sub scrollerStatusbar() {
    my ($item, $get_size_only) = @_;
        $item->default_handler($get_size_only, "{sb ".$subset."}", undef, 1);
}


sub scrollerTimeout() {
    if ($count > $scalarSize){
        $count = 0;
    }else{
        $count++;
    }
    $start = $count;
    $end   = 10;
    $subset = (substr $scalar, $start, $end);    
    Irssi::statusbar_items_redraw('scroller');
}


sub scrollerUpdate() {
    $scalar = Irssi::settings_get_str('scrollerText');
    $scalar = "- - - ->".$scalar."- - - ->";
    print "Scrolling: \" $scalar \"";
    $scalarSize = length($scalar) -11;
    $count = 0;
    Irssi::timeout_remove($timeout);
    if (Irssi::settings_get_int('scrollerSpeed') < 10){
        Irssi::settings_set_int('scrollerSpeed', 10);
        print "Sorry, minimum delay for timeouts in irssi is 10 ms.  Delay set to 10 ms.";
    }
    $timeout = Irssi::timeout_add(Irssi::settings_get_int('scrollerSpeed'), 'scrollerTimeout' , undef);
}


sub scrollerStart() {
    Irssi::settings_add_str('misc', 'scrollerText', 'Scrolling text not defined.  Use "/set scrollerText <something>" to define it');
    Irssi::settings_add_int('misc', 'scrollerSpeed', 200);
    $timeout = Irssi::timeout_add(Irssi::settings_get_int('scrollerSpeed'), 'scrollerTimeout' , undef);
    Irssi::statusbar_item_register('scroller', '$0', 'scrollerStatusbar');
    Irssi::command_bind scrollthis => \&scrollthis;
    Irssi::signal_add('setup changed', 'scrollerUpdate');
    &scrollerUpdate();
}


&scrollerStart();
print "Use \"/set scrollerText <something>\" to scroll <something>";
print "Use \"/set scrollerSpeed <int>\" to set the delay in milliseconds";
