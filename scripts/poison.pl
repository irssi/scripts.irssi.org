# by  Stefan 'tommie' Tomanek
#
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003020801";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "Poison",
    description => "equips Irssi with an interface to giFT",
    license     => "GPLv2",
    changed     => "$VERSION",
    modules     => "IO::Socket::INET Data::Dumper",
    commands	=> "poison"
);

use vars qw($forked %ids);
use IO::Socket::INET;
use Data::Dumper;
use Irssi;
use POSIX;

sub show_help() {
    my $help = $IRSSI{name}." $VERSION
/poison
    List current downloads
/poison search <query>
    Search for files on the network
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box($IRSSI{name}, $text, "help", 1);
}

sub giftconnect {
    my $host = Irssi::settings_get_str('poison_host');
    my $port = Irssi::settings_get_int('poison_port');
    my $sock = IO::Socket::INET->new(PeerAddr => $host,
       				     PeerPort => $port,
	     			     Proto    => 'tcp');
    return $sock;
}

sub draw_box ($$$$) {                                                               my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
	$box .= '%R|%n '.$_."\n";
    }       
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    unless ($colour) { 
        $box =~ s/%(.)/$1 eq '%'?$1:''/eg;
    }   
    return $box;    
}               

sub round ($$) {
    return $_[0] unless Irssi::settings_get_bool('poison_round_filesize');
    if ($_[1] > 100000) {
        return sprintf "%.2fMB", $_[0]/1024/1024;
    } else {
        return sprintf "%.2fKB", $_[0]/1024;
    }
}

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $text .= $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1) unless ($_ == scalar(@$line)-1);
        }
        $text .= "\n";
    }
    return $text;
}

sub bg_do ($$) {
    my ($id, $sub) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    return if $forked;
    $forked = 1;
    my $pid = fork();
    if ($pid > 0) {
        close $wh;
        Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($rh, \$pipetag);                                                    $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my $result;
	    $result->{$id} = &$sub();
	    my $dumper = Data::Dumper->new([$result]);
            $dumper->Purity(1)->Deepcopy(1);
            my $data = $dumper->Dump;
            print($wh $data);
            close($wh);
	};
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    my ($rh, $pipetag) = @{$_[0]};
    my $text;
    $text .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    $forked = 0;
    return unless($text);
    no strict;
    my $result = eval "$text";
    return unless ref $result;
    print_results($result->{search}) if defined $result->{search};
    print CLIENTCRAP '%R>>%n Added '.$result->{sources}.' source(s) for download' if defined $result->{sources};
}

sub search_file ($) {
    my ($query) = @_;
    my $sock = giftconnect();
    return unless $sock;
    $sock->print("SEARCH query(".$query.");\n");
    my %results;
    my %item;
    my $meta = 0;
    while ($_ = $sock->getline()) {
	if ((not $meta) && / *(.*?)\((.*?)\)[^;]/) {
    	    my ($key, $value) = ($1, $2);
	    $value =~ s/\\(.)/$1/g;
	    $item{$key} = $value;
	} elsif (/META/) {
	    $meta = 1;
	} elsif (/ITEM;/) {
	    $sock->close();
	    last;
	} elsif (/;/) {
	    $meta = 0;
	    my %foo = %item;
	    %item = ();
	    $results{$foo{hash}} = \%foo;
	}
    }
    return \%results;
}

sub get_file ($) {
    my ($id) = @_;
    return unless $ids{$id};
    my $data = $ids{$id};
    add_source($data);
    bg_do('sources', sub { retrieve_sources($data->{hash}) } );
}

sub retrieve_sources ($) {
    my ($hash) = @_;
    my %sources;
    foreach (@{ find_sources($hash) }) {
	add_source($_);
	$sources{$_->{user}} = 1;
    }
    return scalar keys %sources;
}

sub add_source (\%) {
    my ($data) = @_; 
    my $sock = giftconnect();
    return unless $sock;
    my @bar = split('/', $data->{url});
    my $file = $bar[-1];

    my $line = "ADDSOURCE ";
    $line .= "user(".$data->{user}.") ";
    $line .= "hash(".$data->{hash}.") ";
    $line .= "size(".$data->{size}.") ";
    $line .= "url(".$data->{url}.") ";
    $line .= "save(".$file.");";
    $sock->print($line."\n");
    $sock->close();
}

sub find_sources ($) {
    my ($hash) = @_;
    my $sock = giftconnect();
    return unless $sock;
    $sock->print("LOCATE query(".$hash.");\n");
    my %item;
    my @sources;
    my $meta = 0;
    while ($_ = $sock->getline()) {
        if ((not $meta) && (/ *(.*?)\((.*?)\)[^;]/)) {
            my ($key, $value) = ($1, $2);
	    #print $key." => ".$value;
            $value =~ s/\\(.)/$1/g;
            $item{$key} = $value;
        } elsif (/META/) {
            $meta = 1;
        } elsif (/ITEM;/) {
            $sock->close();
            last;
        } elsif (/;/) {
            $meta = 0;
            my %foo = %item;
            %item = ();
            push @sources, \%foo;
        }
    }
    return \@sources;
}

sub get_downloads {
    my %downloads;
    my $sock = giftconnect();
    return unless $sock;
    $sock->print("ATTACH client(".$IRSSI{name}.") version(".$VERSION."); DETACH;");
    my %downloads;
    my ($add, $source) = (0,0);
    my %item;
    while ($_ = $sock->getline()) {
	if (/^DOWNLOAD_ADD\((\d+)\)/) {
	    $add = 1;
	    $item{sessionid} = $1;
	} elsif (/SOURCE/) {
	    $source = 1;
	} elsif (/};/) {
	    $source = 0;
	    $add = 0;
	    my %foo = %item;
	    $downloads{$foo{file}} = \%foo;
	} else {
	    if (($add && not $source) && /^  (.*?)\((.*?)\)$/) {
		my ($key, $value) = ($1, $2);
		$value =~ s/\\(.)/$1/g;
		$item{$key} = $value;
	    }
	}
    }
    return \%downloads;
}

sub print_results ($) {
    my ($results) = @_;
    my @array;
    %ids = ();
    my $i = 1;
    foreach (sort {uc($a) cmp uc($b)} keys %$results) {
	my @bar = split('/', $results->{$_}{url});
	my $file = $bar[-1];
	$file =~ s/%20/ /g;
	$file =~ s/%/%%/g;
	my @line;
	push @line, "%9".$i."%9";
	push @line, "%9".$file."%9";
	push @line, $results->{$_}{size};
	push @line, $results->{$_}{availability};
	push @array, \@line;
	$ids{$i} = $results->{$_};
	$i++;
    }
    my $text = array2table(@array);
    print CLIENTCRAP draw_box("Poison", $text, "Results", 1) if $text;
}

sub print_downloads ($) {
    my ($downloads) = @_;
    my $text;
    foreach (sort {uc($a) cmp uc($b)} keys %$downloads) {
	if ($downloads->{$_}{state} eq 'Active') {
	    $text .= '%bo%n';
	} elsif ($downloads->{$_}{state} eq 'Paused') {
	    $text .= '%yo%n';
	}
	my $percent = $downloads->{$_}{size} > 0 ? ($downloads->{$_}{transmit} / $downloads->{$_}{size}) * 100 : 0;
	my $file = $_;
        $file =~ s/%20/ /g;
        $file =~ s/%/%%/g;
	$text .= " %9".$file."%9";
	$text .= "\n";
	$text .= '     ';
	$text .= round($downloads->{$_}{transmit}, $downloads->{$_}{size}).'/';
	$text .= round($downloads->{$_}{size}, $downloads->{$_}{size});
	$percent =~ s/(\..).*/$1/g;
	$text .= " (".$percent."%%)";
	$text .= "\n"
    }
    print CLIENTCRAP draw_box("Poison", $text, "Downloads", 1);
}



sub cmd_poison ($$$) {
    my ($args, $server, $witem) = @_;
    my @args = split(/ /, $args);
    if (@args == 0) {
	print_downloads(get_downloads());
    } elsif ($args[0] eq 'search') {
	shift @args;
	if ($forked) {
	    print CLIENTCRAP '%R>>%n Already searching...';
	} else {
	    print CLIENTCRAP '%R>>%n Search in progress...';
	}
	bg_do 'search', sub { search_file(join(' ', @args)) }; 
	#print_results search_file(join(' ', @args));
    } elsif ($args[0] eq 'get' && $args[1]) {
	get_file($args[1]);
    } elsif ($args[0] eq 'help') {
	show_help();
    }
}

Irssi::settings_add_str('poison', 'poison_host', 'localhost');
Irssi::settings_add_int('poison', 'poison_port', 1213);
Irssi::settings_add_bool('poison', 'poison_round_filesize', 1);

Irssi::command_bind('poison', \&cmd_poison);

foreach my $cmd ('help', 'search', 'get') {
    Irssi::command_bind('poison '.$cmd => sub {
        cmd_poison("$cmd ".$_[0], $_[1], $_[2]); });
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded, /poison help';

