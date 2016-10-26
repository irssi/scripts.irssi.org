#!/usr/pkg/bin/perl
#
# $Id: porthu-irssi.pl,v 1.7 2003/06/14 21:14:46 bigmac Exp $
#
# Irssi Client for PORT.HU
# Copyright (C) 2003, Gabor Nyeki (bigmac@home.sirklabs.hu).
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the author nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use strict;
use Irssi;
use Irssi::Irc;
use IO::Socket;

use vars qw($VERSION %IRSSI); 
use vars %IRSSI;
%IRSSI = (
	authors		=> "Gabor Nyeki",
	contact		=> "bigmac\@home.sirklabs.hu",
	name		=> "tvmusor",
	description	=> "asks for the current tv-lineup from http://www.port.hu/",
	license		=> "BSDL",
	changed		=> "Tue Jun  3 18:48:02 CEST 2003"
);

my %chans = (
	m1		=> "1",
	m2		=> "2",
	dunatv		=> "6",
	tv2		=> "3",
	rtlklub		=> "5",
	viasat3		=> "21",
	fixtv		=> "96",
	spektrum	=> "9",
	hbo		=> "8",
	atv		=> "15"
);


sub tvmusor {
	my ($args) = @_;

	split / /, $args;
	my $chan = @_[0];
	my $list = @_[1];

	if (!$chan) {
		Irssi::print "Hasznalat: /tvmusor list|csatorna [lista hossza]";
		return;
	}
	if ($chan eq "list") {
		Irssi::print "Elerheto csatornak listaja:";
		foreach my $buf (sort(keys %chans)) {
			Irssi::print "-> $buf";
		}
		return;
	}

	if (!$chans{$chan}) {
		Irssi::print "$chan nem letezik!";
		return;
	}

	my $num;
	if (!$list) {
		$num = 5;
	} else {
		$num = $list;
	}


	my $sd = IO::Socket::INET->new(Proto => "tcp",
				    PeerAddr => "www.port.hu",
				    PeerPort => "80") or die;
	print $sd "GET /pls/tv/tv.prog?i_days=1&i_ch=$chans{$chan}&i_ch_nr=1 HTTP/1.0\n";
	print $sd "Host: www.port.hu\n";
	print $sd "User-Agent: Irssi\n";
	print $sd "\n";

	Irssi::print "$chan:";

	my $i = 0;
	my ($x, $y);
	while (<$sd>) {
		if ($_ =~ /<tr><td align="right" valign="top" bgcolor="/) {
			split /<strong>/, $_;

			if (@_[1] =~ /<blink>(.*)<\/blink>/) {
				$i = 1;
				$x = $1;
			} else {
				if ($i) {
					$i++;
				}
				@_[1] =~ /(.*)<\/strong>/;
				$x = $1;
			}

			if ($i eq 0) {
				next;
			}

			@_[2] =~ /(.*)<\/strong>/;
			$y = $1;

			Irssi::print "-> [$x] $y";
			if ($i eq $num) {
				last;
			}
		}
	}

	close $sd;

	if ($i ne $num) {
		Irssi::print "-> --- nincs tobb ---";
	}
}

Irssi::command_bind('tvmusor', 'tvmusor');
