use Irssi;
use strict;
use warnings;

our $VERSION = "1.0.0";
our %IRSSI = (
    authors     => 'terminaldweller',
    contact     => 'https://terminaldweller.com',
    name        => 'holes',
    description => 'gives a list of of the open sockets as an expando(this makes sense only if irssi is in a container)',
    license     => 'GPL3 or newer',
    url         => 'https://github.com/irssi/scripts.irssi.org',
);

Irssi::settings_add_int('misc', 'holes_frequency', 30000);
Irssi::settings_add_str('misc', 'holes_separator', '');
my $holes = "";
my $timeout;
my $holes_cmd = << 'HOLES_CMD';
lsof | grep socket | awk '{print $4}' | awk 'BEGIN{FS=":"}{print $2}' | tr -d [] | uniq
HOLES_CMD

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub holes_sub {
    my $result;
    Irssi::timeout_remove($timeout);
    my $output = `$holes_cmd`;
    my $sep = Irssi::parse_special(Irssi::settings_get_str('holes_separator'));
    my @lines = split /\n/, $output;
    my @lines = uniq(@lines);
    $holes = '';
    $result = @lines;
    foreach my $line (@lines) {
        if ($result == "") {
            $result = $line
        }
        $result = $result.$sep.$line
    }
    # $result =~ s/^\s+//;
    $holes= $result;
    $timeout = Irssi::timeout_add_once(Irssi::settings_get_int('holes_frequency'), 'holes_sub' , undef);
}

Irssi::expando_create('holes', sub {
  return $holes;
}, {});

$timeout = Irssi::timeout_add(Irssi::settings_get_int('holes_frequency'), 'holes_sub' , undef);
holes_sub();
