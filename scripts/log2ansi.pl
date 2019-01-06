#! /usr/bin/perl
#
#    $Id: log2ansi,v 1.10 2010/02/13 13:59:47 peder Exp $
#
# Copyright (C) 2002, 2003, 2010 by Peder Stray <peder@ninja.no>
#
#    This is a standalone perl program and not intended to run within
#    irssi, it will complain if you try to...

use strict;
use Getopt::Long;
use Encode;

use vars qw(%ansi %base %attr %old);
use vars qw(@bols @nums @mirc @irssi @mc @mh @ic @ih @cn);
use vars qw($class $oldclass);

use vars qw{$VERSION %IRSSI};
($VERSION) = ' $Revision: 1.10 $ ' =~ / (\d+\.\d+) /;
%IRSSI = (
          name        => 'log2ansi',
          authors     => 'Peder Stray',
          contact     => 'peder@ninja.no',
          url         => 'http://ninja.no/irssi/log2ansi',
          license     => 'GPL',
          description => 'convert mirc color and irssi interal formatting to ansi colors, useful for log filtering',
         );

if (__PACKAGE__ =~ /^Irssi/) {
    # we are within irssi... die!
    Irssi::print("%RWarning:%n log2ansi should not run from within irssi");
    die "Suicide to prevent loading\n";
}

my $opt_clear = 0;
my $opt_html = 0;
my $opt_utf8 = 0;

GetOptions(
	   'clear!' => \$opt_clear,
	   'html!' => \$opt_html,
	   'utf8!' => \$opt_utf8,
	  );

for (@ARGV) {
    if (/\.bz2$/) {
	$_ = "bunzip2 < '$_' |";
    } elsif (/\.gz$/) {
        $_ = "gunzip < '$_' |";
    }
}

my($n) = 0;
%ansi = map { $_ => $n++ } split //, 'krgybmcw';

@bols = qw(bold underline blink reverse fgh bgh);
@nums = qw(fgc bgc);

@base{@bols} = qw(1 4 5 7 1 5);
@base{@nums} = qw(30 40);

@mirc  = split //, 'WkbgRrmyYGcCBMKw';
@irssi = split //, 'kbgcrmywKBGCRMYW';

@mc = map {$ansi{lc $_}} @mirc;
@mh = map {$_ eq uc $_} @mirc;

@ic = map {$ansi{lc $_}} @irssi;
@ih = map {$_ eq uc $_} @irssi;

@cn = qw(black dr dg dy db dm dc lgray dgray lr lg ly lb lm lc white);

sub defc {
    my($attr) = shift || \%attr;
    $attr->{fgc} = $attr->{bgc} = -1;
    $attr->{fgh} = $attr->{bgh} = 0;
}

sub defm {
    my($attr) = shift || \%attr;
    $attr->{bold} = $attr->{underline} = 
      $attr->{blink} = $attr->{reverse} = 0;
}

sub def {
    my($attr) = shift || \%attr;
    defc($attr);
    defm($attr);
}

sub setold {
    %old = %attr;
}

sub emit {
    my($str) = @_;
    my(%elem,@elem);

    if ($opt_clear) {
	# do nothing
    }
    else {
	
	if ($opt_html) {
	    my %class;
	    
	    for (@bols) {
		$class{$_}++ if $attr{$_};
	    }

	    for (qw(fg bg)) {
		my $h = delete $class{"${_}h"};
		my $n = $attr{"${_}c"};
		next unless $n >= 0;
		$class{"$_$cn[$n + 8 * $h]"}++;
	    }

	    $class = join " ", sort keys %class;

	    print qq{</span>} if $oldclass;
	    print qq{<span class="$class">} if $class;
	    $oldclass = $class;
	}
	else {
	    my(@clear) = ( (grep { $old{$_} > $attr{$_} } @bols),
			   (grep { $old{$_}>=0 && $attr{$_}<0 } @nums)
			 );

	    $elem{0}++ if @clear;
	
	    for (@bols) {
		$elem{$base{$_}}++ 
		  if $attr{$_} && ($old{$_} != $attr{$_} || $elem{0});
	    }
	    
	    for (@nums) {
		$elem{$base{$_}+$attr{$_}}++
		  if $attr{$_} >= 0 && ($old{$_} != $attr{$_} || $elem{0});
	    }
	    
	    @elem = sort {$a<=>$b} keys %elem;
	    
	    if (@elem) {
		@elem = () if @elem == 1 && !$elem[0];
		printf "\e[%sm", join ";", @elem;
	    }
	}
    }

    if ($opt_html) {
	for ($str) {
	    s/&/&amp;/g;
	    s/</&lt;/g;
	    s/>/&gt;/g;
	}
    }

    print $str;

    setold;
}

if ($opt_html) {
    print qq{<div class="loglines">\n};
}

if ($opt_utf8) {
    binmode STDIN, ':bytes'; #encoding(cp1252)';
    binmode STDOUT, ':utf8';
}

while (<>) {
    if ($opt_utf8) {
	my $line;
	while (length) {
	    $line .= decode("utf8", $_, Encode::FB_QUIET);
	    $line .= substr $_, 0, 1, "";
	}
	$_ = $line;
    }

    chomp;

    def;
    setold;

    if ($opt_html) {
	printf qq{<div class="logline">};
    }

    while (length) {
	if (s/^\cB//) {
	    # toggle bold
	    $attr{bold} = !$attr{bold};
	
	} elsif (s/^\cC//) {
	    # mirc colors

	    if (/^[^\d,]/) {
		defc;
	    } else {
		
		if (s/^(\d\d?)//) {
		    $attr{fgc} = $mc[$1 % 16];
		    $attr{fgh} = $mh[$1 % 16];
		}

		if (s/^,//) {
		    if (s/^(\d\d?)//) {
			$attr{bgc} = $mc[$1 % 16];
			$attr{bgh} = $mh[$1 % 16];
		    } else {
			$attr{bgc} = -1;
			$attr{bgh} = 0;
		    }
		}
	    }

	} elsif (s/^\cD//) {
	    # irssi format

	    if (s/^a//) {
		$attr{blink} = !$attr{blink};
	    } elsif (s/^b//) {
		$attr{underline} = !$attr{underline};
	    } elsif (s/^c//) {
		$attr{bold} = !$attr{bold};
	    } elsif (s/^d//) {
		$attr{reverse} = !$attr{reverse};
	    } elsif (s/^e//) {
		# indent
	    } elsif (s/^f([^,]*),//) {
		# indent_func
	    } elsif (s/^g//) {
		def;
	    } elsif (s/^h//) {
		# cleol
	    } elsif (s/^i//) {
		# monospace
	    } else {
		s/^(.)(.)//;
		my($f,$b) = map { ord($_)-ord('0') } $1, $2;
		if ($f<0) {
#		    $attr{fgc} = -1; $attr{fgh} = 0;
		} else {
		    # c>7 => bold, c -= 8 if c>8
		    $attr{fgc} = $ic[$f];
		    $attr{fgh} = $ih[$f];
		}
		if ($b<0) {
#		    $attr{bgc} = -1; $attr{bgh} = 0;
		} else {
		    # c>7 => blink, c -= 8
		    $attr{bgc} = $ic[$b];
		    $attr{bgh} = $ih[$b];
		}
	    }

	} elsif (s/^\cF//) {
	    # blink
	    $attr{blink} = !$attr{blink};

	} elsif (s/^\cO//) {
	    def;

	} elsif (s/^\cV//) {
	    $attr{reverse} = !$attr{reverse};

	} elsif (s/^\c[\[([^m]*)m//) {
	    my(@ansi) = split ";", $1;
	    my(%a);

	    push @ansi, 0 unless @ansi;

	    for my $code (@ansi) {
		if ($code == 0) {
		    def(\%a);
		} elsif ($code == $base{bold}) {
		    $a{bold} = 1;
		} elsif ($code == $base{underline}) {
		    $a{underline} = 1;
		} elsif ($code == $base{blink}) {
		    $a{underline} = 1;
		} elsif ($code == $base{reverse}) {
		    $a{reverse} = 1;
		} elsif ($code => 30 && $code <= 37) {
		    $a{fgc} = $code - 30;
		} elsif ($code => 40 && $code <= 47) {
		    $a{bgc} = $code - 40;
		} else {
		    $a{$code} = 1;
		}
	    }

	    if ($a{fgc} >= 0 && $a{bold}) {
		$a{fgh} = 1;
		$a{bold} = 0;
	    }

	    if ($a{bgc} >= 0 && $a{blink}) {
		$a{bgh} = 1;
		$a{blink} = 0;
	    }

	    for my $key (keys %a) {
		$attr{$key} = $a{$key};
	    }

	} elsif (s/^\c_//) {
	    $attr{underline} = !$attr{underline};

	} else {
	    s/^(.[^\cB\cC\cD\cF\cO\cV\c[\c_]*)//;
	    emit $1;
	}
    }

    def;
    emit "";
    if ($opt_html) {
	print "</div>";
    }
    print "\n";
}

if ($opt_html) {
    print "</div>\n";
}
