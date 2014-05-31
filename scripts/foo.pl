use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind signal_add signal_emit signal_stop);

$VERSION = '3.00';
%IRSSI = (
    authors	=> 'Juerd, Shiar',
    contact	=> 'juerd@juerd.nl, shiar@shiar.org',
    name	=> 'UeberRot encryption',
    description	=> 'Rot n+i encryption and decryption',
    license	=> 'Public Domain',
    url		=> 'http://juerd.nl/site.plp/irssi',
    changed	=> 'Tue Jan 21 01:40 CET 2003',
);

my $char1 = "\xC0-\xCF\xD2-\xD6\xD8-\xDD";
my $char2 = "\xE0-\xF6\xF8-\xFF";

sub rot {
    my ($dir, $rotABC, $rot123, $rotshift, $msg) = @_;
    my $i = 0;
    for (0 .. length $msg) {
	my $char = \substr $msg, $_, 1;
	$i += $rotshift;
	$$char =~ tr/a-zA-Z/b-zaB-ZA/ for 1..abs $dir *26 - ($rotABC + $i) % 26;
	$$char =~ tr/0-9/1-90/        for 1..abs $dir *10 - ($rot123 + $i) % 10;
    }
    return $msg;
}

sub sig_message {
    my $signal = shift;
    my $msg = \$_[1];
    return unless $$msg =~ s/^\cO(\cB+)\cO(\cB+)\cO(\cO*)//;
    my $orig = $$msg;
    $$msg = "\cB" . rot 1, length $1, length $2, length $3, $$msg;
    $$msg =~ s{\c_\c_\cO([a-zA-Z])}<
	my $char = $1;
	eval qq{
	    \$char =~ tr/A-Z/$char1/;
	    \$char =~ tr/a-z/$char2/;
	};
	$char;
    >ego;
    signal_stop;
    signal_emit($signal, $_[0], $orig, @_[2..$#_]);
    signal_emit($signal, @_);
}

command_bind rot => sub {
    my ($data, $server, $window) = @_;
    $data =~ s/([$char1$char2])/\c_\c_\cO$1/og;
    eval qq{
        \$data =~ tr/$char1/A-Z/;
        \$data =~ tr/$char2/a-z/;
    };
    my $rotABC   = 1 +     int rand 13;
    my $rot123   = 1 + 2 * int rand 4;
    my $rotshift = 1 +     int rand 10;
    $window->command(
	sprintf "say \cO%s\cO%s\cO%s%s",
	"\cB" x $rotABC,
	"\cB" x $rot123,
        "\cO" x $rotshift,
	rot 0, $rotABC, $rot123, $rotshift, $data
    );
};

signal_add {
    'message private'     => sub { sig_message 'message private'     => @_ },
    'message public'      => sub { sig_message 'message public'      => @_ },
    'message own_private' => sub { sig_message 'message own_private' => @_ },
    'message own_public'  => sub { sig_message 'message own_public'  => @_ },
};
