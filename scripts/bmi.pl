use strict;
use vars qw($VERSION %IRSSI);
use Irssi qw(command_bind command_runsub);

$VERSION = '2002121801';
%IRSSI = (
    authors	=> 'Daniel K. Gebhart, Marcus Rückert',
    contact	=> 'dkg@con-fuse.org, darix@irssi.org',
    name	=> 'BMI Calculator',
    description	=> 'a simple body mass index calculator for depression ;)',
    license	=> 'GPLv2',
    url		=> 'http://dkg.con-fuse.org/irssi/scripts/',
    changed	=> $VERSION,
);

sub bmi_help () {
    print ( CLIENTCRAP "\nBMI <weigth_in_kg> <height_in_cm> [<precision>]\n" );
    print ( CLIENTCRAP "please specify weight in kilograms (10-999kg) and height in cm (10-999cm). you can use decimal places. output precision (0-9).\n" );
    print ( CLIENTCRAP "The optimal BMI is 19-24 for women and 20-25 for men.\n" );
}

command_bind 'bmi help' => sub { bmi_help(); };

command_bind 'bmi' => sub {
    my ($data, $server, $item) = @_;
    $data =~ s/\s+$//g;
    $data =~ s/,/./g;
    if ($data eq '') {
        bmi_help();
    }
    elsif ( $data =~ m/^help/i ) {
        command_runsub ( 'bmi', $data, $server, $item );
    }
    else {
        if ( $data =~ m/^(\d{2,3}(\.\d+)?)\s+(\d{2,3}(\.\d+)?)(\s+(\d))?$/ ) {
            my ($kg, $cm) = ($1, $3);
            my $precision = ( defined ($6) ) ? $6 : 2;
            print ( CRAP "with $kg kg at $cm cm you have a bmi of " . sprintf("%." . $precision . "f", ( ( $kg/$cm**2 ) *10000 ) ) );
        }
        else {
            print ( CRAP "please specify weight in kilograms (10-999kg) and height in cm (10-999cm). you can use decimal places. output precision (0-9)." );
            print ( CRAP "params were: $data" );
        }
    }
};
