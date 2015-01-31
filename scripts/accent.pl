#to run it if it is here (but in this case it will run automagically when
#irssi will start):
#
#/script load ~/.irssi/scripts/autorun/accent.pl
#
#you can simply remove the script:
#
#/script unload accent
#
#and it will strips your incoming and outgoing hungarian accents
#but you can:
#
#/set accent_strip_in  <on|off> -- strips the incoming accents (on) or not (off)
#/set accent_strip_out <on|off> -- strips the outgoing accents (on) or not (off)
#
#/set accent_tag_in  <string, default: [A]> indicates the incoming msg filtered 
#/set accent_tag_out <string, default: [A]> indicates the outgoing msg filtered
#
#/set accent_latin <string, default: iso 8859-2: A',a',E',e',I',i',O',o',O:,o:,O",o",U',u',U:,u:,U",u"> which to strip
#/set accent_ascii <string, default: AaEeIiOoOoOoUuUuUu> will be the stripped
#
#be careful, accent_latin and accent_latin must be charlist and must have
#the same length to be matched as a pair.
#
#/set accent_debug <on|off> -- if you have a problem try to turn this on

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
($VERSION) = '$Id: accent.pl,v 1.34 2003/03/27 15:54:25 toma Exp $' =~ / (\d+\.\d+) /;
%IRSSI = (
	authors     => 'Tamas SZERB',
	contact     => 'toma@rulez.org',
	name        => 'accent',
	description => 'This script strips the hungarian accents.',
	license     => 'GPL',
);

my $stripped_out = 0;
my $stripped_in  = 0;

sub accent_out {
	if(Irssi::settings_get_bool('accent_strip_out') && !$stripped_out) {
		my $accent_tag = Irssi::settings_get_str('accent_tag_out');

		my $debug=Irssi::settings_get_bool('accent_debug');
		
		my $accent_latin = Irssi::settings_get_str('accent_latin');
		my $accent_ascii = Irssi::settings_get_str('accent_ascii');
		if (length($accent_latin) != length($accent_ascii)) {
			if ($debug) {
				Irssi::print("`$accent_latin' and `$accent_ascii' hasn't same length");
			}
		}
		else {
			my $emitted_signal = Irssi::signal_get_emitted();
			my ($msg, $dummy1, $dummy2) = @_;

			if ($debug) {
				Irssi::print("signal emitted: $emitted_signal");
			}

			if ( $msg =~ /[$accent_latin]/ ) {
				if ($debug) {
					Irssi::print("outgoing contains accent: $msg");
				}
				eval "\$msg =~ tr/$accent_latin/$accent_ascii/;";
				$msg = $msg . ' ' . $accent_tag;
				$stripped_out=1;
				
				Irssi::signal_emit("$emitted_signal", $msg, $dummy1, $dummy2 );
				Irssi::signal_stop();
				$stripped_out=0;
			}
		}
	}
}

sub accent_in {
	if(Irssi::settings_get_bool('accent_strip_in') && !$stripped_in) {
		my $accent_tag = Irssi::settings_get_str('accent_tag_in');

		my $debug=Irssi::settings_get_bool('accent_debug');
		
		my $accent_latin = Irssi::settings_get_str('accent_latin');
		my $accent_ascii = Irssi::settings_get_str('accent_ascii');
		if (length($accent_latin) != length($accent_ascii)) {
			if ($debug) {
				Irssi::print("`$accent_latin' and `$accent_ascii' hasn't same length");
			}
		}
		else {
			my $emitted_signal = Irssi::signal_get_emitted();

			my ($dummy0, $text, $dummy3, $dummy4, $dummy5) = @_;
			if ($debug) {
				Irssi::print("signal emitted: $emitted_signal");
			}
			if ( $text =~ /[$accent_latin]/ ) {
				if ($debug) {
					Irssi::print("incoming contains accent: $text");
				}
				if ($debug) {
					Irssi::print("text=$text");
				}
				#no idea why w/o eval doesn't work:
				eval "\$text =~ tr/$accent_latin/$accent_ascii/;";
				$text = $text . ' ' . $accent_tag;
				$stripped_in=1;

				if ($debug) {
					Irssi::print("text=$text");
				}
				Irssi::signal_emit("$emitted_signal", $dummy0, $text, $dummy3, $dummy4, $dummy5 );
				Irssi::signal_stop();
				$stripped_in=0;
			}
		}
	}
}

#main():

#default settings /set accent_in && accent_out ON:
Irssi::settings_add_bool('lookandfeel', 'accent_strip_in', 1);
Irssi::settings_add_bool('lookandfeel', 'accent_strip_out', 1);

#define the default tags for the filtered text:
Irssi::settings_add_str('lookandfeel', 'accent_tag_in', '[Ai]');
Irssi::settings_add_str('lookandfeel', 'accent_tag_out', '[Ao]');

#define which chars will be changed:
#iso 8859-2: A',a',E',e',I',i',O',o',O:,o:,O",o",U',u',U:,u:,U",u"
Irssi::settings_add_str('lookandfeel', 'accent_latin', "\301\341\311\351\315\355\323\363\326\366\325\365\332\372\334\374\333\373");
Irssi::settings_add_str('lookandfeel', 'accent_ascii', "AaEeIiOoOoOoUuUuUu");

#define wheather debug or not (default OFF):
Irssi::settings_add_bool('lookandfeel', 'accent_debug', 0);

#filters:
#incoming filters:
Irssi::signal_add_first('server event', 'accent_in');

#output filters:
Irssi::signal_add_first('send command', 'accent_out');
#Irssi::signal_add_first('message own_public', 'accent_out');
#Irssi::signal_add_first('message own_private', 'accent_out');

#startup info:
Irssi::print("Hungarian accent stripper by toma * http://scripts.irssi.org/scripts/accent.pl");
Irssi::print("Version: $VERSION");

