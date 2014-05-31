use strict;
use vars qw($VERSION %IRSSI);

# This script assumes all windows have the same width, which will
# practically always be true.

use Irssi qw(active_win command_bind);
$VERSION = '1.20';
%IRSSI = (
    authors	=> 'Juerd',
    contact	=> 'juerd@juerd.nl',
    name	=> 'Script Information',
    description	=> 'Access script information',
    license	=> 'Public Domain',
    url		=> 'http://juerd.nl/irssi/',
    changed	=> 'Tue Mar 19 11:00 CET 2002',
);

sub iprint {
    Irssi::print(join('', @_), MSGLEVEL_CRAP);
}

command_bind 'script info' => sub {
    my ($data, $server) = @_;
    if ($data !~ /\S/) {
        iprint 'Usage: /script info <scriptname>';
        return;    
    }

    no strict 'refs';
    iprint "\c_== Script info for $data ==";

    if (not exists $Irssi::Script::{ "${data}::" }) {
        iprint 'Script is not loaded.';
        return;
    }
	
    my %info = %{ "Irssi::Script::${data}::IRSSI" };
    $info{version} = ${ "Irssi::Script::${data}::VERSION" };
	
    if (join('', values %info) eq '') {
	iprint 'Script has no $VERSION and no %IRSSI. ',
	       'Please ask the author to read ',
	       'http://juerd.nl/irssi/proposal.txt';

	return;
    }
    my $max = 0;
    length > $max and $max = length for keys %info;
    my $width = active_win->{width} - 14 - $max;
    s/([^\n]{$width})/$1\n/g      for values %info;
    s/(?<=\n)/' ' x ($max + 2)/eg for values %info;
    for (qw/name version description authors contact/) {
        if (exists $info{$_}) {
    	    iprint"\cC5$_\cC", ' ' x (2 + $max - length $_), $info{$_};
    	    delete $info{$_};
        }
    }
    for (sort keys %info) {
        iprint "\cC5$_\cC", ' ' x (2 + $max - length $_), $info{$_};
    }
};

command_bind 'script sv' => sub {
    my ($data, $server) = @_;
    if ($data !~ /\S/) {
	iprint 'Usage: /script sv <scriptname>';
        return;
    }

    no strict 'refs';
    if (not exists $Irssi::Script::{ "${data}::" }) {
        iprint 'Module is not loaded.';
        return;
    }

    my $name    = ${ "Irssi::Script::${data}::IRSSI" }{name};
    my $url     = ${ "Irssi::Script::${data}::IRSSI" }{url};
    my $version = ${ "Irssi::Script::${data}::VERSION" };

    my $text = "$name $version";
    $text .= " - $url" if $url;

    if ($text !~ /\S/) {
        iprint 'Script has no information.';
        return;
    }

    active_win->command("say $text");
};

command_bind 'script versions' => sub {
    # Actually, upgrading them would be quite easy :)
    # Update: Actually, it's possible now! use scriptadmin.pl :)
    my ($data, $server) = @_;

    no strict 'refs';
    my @modules;
    for (sort grep s/::$//, keys %Irssi::Script::) {
        my $name    = ${ "Irssi::Script::${_}::IRSSI" }{name};
	my $version = ${ "Irssi::Script::${_}::VERSION" };
	push @modules, [$_, $name, $version] if $name && $version;
    }
    my @max;
    for (@modules) {
	my $i = -1;;
	length > $max[++$i] and $max[$i] = length for @$_; 
    }
    my $i;
    my $text = join "\n", map {
        $i = 0 ||
        join ' ', map {
	    $_ . ' ' x ($max[$i++] - length)
	} @$_
    } @modules;
    iprint $text;
};    

