use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(signal_add_last settings_add_bool settings_add_str
                             settings_get_bool settings_get_str);
$VERSION = '1.31';
%IRSSI = (
    authors     => 'Juerd (first version: Timo Sirainen)',
    contact     => 'juerd@juerd.nl',
    name        => 'Dictionary complete',
    description => 'Caching dictionary based tab completion',
    license     => 'Public Domain',
    url         => 'http://juerd.nl/irssi/',
    changed     => 'Fri Dec 6 11:12 CET 2002',
    changes     => 'Removed a silly mistake'
);

my $file = '/usr/share/dict/words'; # file must be sorted!

my @array;
my %index;

{
    my $old = '';
    my $start = 0;
    my $pointer = 0;
    open(DICT, $file) or die $!;
    while (<DICT>) {
	chomp;
	push @array, $_;
	my $letter = lc substr $_, 0, 1;
	if ($letter ne $old) {
	    $index{$old} = [ $start, $pointer - 1 ];
	    $start = $pointer;
	}
	$old = $letter;
	$pointer++;
    }
    close DICT;
    $index{$old} = [ $start, $pointer ];
}

my %cache;
sub sig_complete {
     my ($complist, $window, $word, $linestart, $want_space) = @_;
    if (defined($cache{$word})){
	push @$complist, @{$cache{$word}};
	return;
    }

    my $found;
    my $mylist = [];
    my $regex = $word =~ /[^\w-\']/;
    return unless my $index = (($word =~ /^[^\w-\']/)
	? [0, $#array]
	: $index{lc substr $word, 0, 1});
    eval {
	for ($index->[0] .. $index->[1]) {
    	    if ($array[$_] =~ /^$word/i) {
		$found = 1;
    		push @$complist, $array[$_];
	        push @$mylist, $array[$_];
            } else {
    		last if $found && not $regex;
    	    }
	}
    }; return if $@;
  
    $cache{$word} = $mylist;
    my $max = settings_get_str 'dictcomplete_display' or 20;
    $window->print(@$complist > $max ? "@$complist[0..($max-1)] ..." : "@$complist")
	unless @$complist < 2 or settings_get_bool 'dictcomplete_quiet';
}

signal_add_last 'complete word' => \&sig_complete;

settings_add_bool 'dictcomplete', 'dictcomplete_quiet'   => 0;
settings_add_str  'dictcomplete', 'dictcomplete_display' => 20;
