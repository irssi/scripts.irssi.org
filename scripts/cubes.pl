use strict;
use warnings;
use Irssi 20140603;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Irssi staff',
    contact     => 'staff@irssi.org',
    url         => 'https://irssi.org',
    name        => 'cubes',
    description => '256 colour test script for Irssi.',
    license     => 'Public Domain',
);

Irssi::command_bind 'cubes' => sub {
    my $w = Irssi::active_win;
    my $C = MSGLEVEL_CLIENTCRAP;
    my $N = MSGLEVEL_NEVER | $C;
    my $P = sub {
	$w->print(@_)
    };
    $P->("%_bases", $C);
    $P->( do {
	join '', map { "%x0${_}0$_" } '0' .. '9', 'A' .. 'F'
    }, $N);
    $P->("%_cubes", $C);
    $P->( do {
	my $y = $_*6;
	join '', map {
	    my $x = $_;
	    map { "%x$x$_$x$_" } @{['0' .. '9', 'A' .. 'Z']}[$y .. $y+5]
	} 1 .. 6
    }, $N)
	for 0 .. 5;
    $P->("%_grays", $C);
    $P->( do {
	join '', map { "%x7${_}7$_" } 'A' .. 'X'
    }, $N);
    $P->("%_mIRC extended colours", $C);
    my $x;
    $x .= sprintf "\cC99,%02d%02d", $_, $_
	for 0 .. 15;
    $P->($x, $N);
    for my $z (0 .. 6) {
	my $x;
	$x .= sprintf "\cC99,%02d%02d", $_, $_
	    for 16 + ($z * 12) .. 16 + ($z * 12) + 11;
	$P->($x, $N);
    }
};
