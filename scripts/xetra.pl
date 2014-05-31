# by Stefan 'tommie' Tomanek <stefan@pico.ruhr.de>
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "20030208";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "Xetra",
    description => "brings the stock exchanges of the world to your irssi",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands	=> "xetra"
);


use Irssi 20020324;
use Irssi::TextUI;
use LWP::Simple;
use vars qw($forked @ticker $shift $timer);

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub show_help() {
    my $help=$IRSSI{name}." ".$VERSION."
/xetra update
    Retrieve new stock information for ticker
/xetra get WKN/EXC
    Retrieve data for stock <WKN> at stock exchange <EXC>
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}." help", $text, "help", 1) ;
}

sub stock ($) {
    if ($_[0] =~ /^(.*?)\/(.*?)$/) {
	return $_[0];
    } elsif ($_[0] =~ /^(.*?)\.(.*?)$/) {
	return $_[0].'/'.$2;
    } else {
	my $exchange = Irssi::settings_get_str('xetra_default_stock_exchange');
	return $_[0].'/'.$exchange if ($_[0] =~ /^\d+$/);
	return $_[0].'.'.$exchange.'/'.$exchange;
    }
}

sub get_stock ($$) {
    my ($wkn, $exchange) = @_;
    #my $data = get('http://informer2.comdirect.de/de/default/_pages/fokus/main.html?sSymbol='.$symbol);
    my $data = get('http://informer2.comdirect.de/de/suche/main.html?nop=0&searchButton=Exakt&searchfor='.$wkn.'&XsearchBoersen='.$exchange);
    my $stock;
    if ($data =~ /&nbsp;WKN:&nbsp;(.*?)&nbsp;/) {
	$stock->{wkn} = $1;
    }
    if ($data =~ /<th class="right">(&nbsp;|<img src="\/_common\/images\/pfeil_.*?\.gif" width=11 height=10 alt="">)&nbsp;(.*?)<\/th>/) {
	$stock->{current} = $2;
    }
    if ($data =~ /<td align="right"><b><div class="color.*?"><nobr>&nbsp;(.*?)&nbsp;<\/nobr><\/div><\/b><\/td>/) {
	$stock->{change} = $1;
    }
    if ($data =~ /Symbol:&nbsp;(.*?)</) {
	$stock->{symbol} = $1;
    }
    if ($data =~ /B&ouml;rse:&nbsp;(.*?)&nbsp;/) {
	$stock->{exchange} = $1;
    }
    if ($data =~ /<nobr>&nbsp;([0-9,+-]+\%)&nbsp;<\/nobr>/) {
	$stock->{percent} = $1;
    }
    if ($data =~ /<td align="right">(\d+)\.(\d+)\.&nbsp;<\/td><td align="right">(\d+):(\d+)&nbsp;<\/td>/) {
	$stock->{date} = $1.'.'.$2.'.';
	$stock->{time} = $3.':'.$4;
    }
    return $stock;
}

sub bg_fetch ($$) {
    my ($symbols, $job) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    return if $forked > 3;
    $forked++;
    my $pid = fork();
    if ($pid > 0) {
        close $wh;
        Irssi::pidwait_add($pid);
        my ($pipetag);
        my @args = ($rh, \$pipetag, $job);
        $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	my $result;
	foreach (@$symbols) {
	    $_ = stock($_);
	    my ($wkn, $exchange) = split('/', $_);
	    my $item = get_stock($wkn, $exchange);
	    push @$result, $item;
	}
	my $dumper = Data::Dumper->new([$result]);
	$dumper->Purity(1)->Deepcopy(1);
	my $data = $dumper->Dump;
	print($wh $data);
	close($wh);
	POSIX::_exit(1);
    }
}

sub pipe_input ($$$) {
    my ($rh, $pipetag, $job) = @{$_[0]};
    $forked--;
    my $text;
    $text .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    return unless($text);
    no strict;
    my $result = eval "$text";
    return unless ref $result;
    if ($job eq 'ticker') {
	@ticker = @$result;
	Irssi::statusbar_items_redraw('xetra');
    } elsif ($job eq 'get') {
	foreach (@$result) {
	    show_stock($_);
	}
    }
}

sub show_stock ($) {
    my ($stock) = @_;
    my $text;
    $text .= '%9WKN:%9     '.$stock->{wkn}." (".$stock->{exchange}.")\n";
    $text .= '%9Current:%9 '.$stock->{current}."\n";
    $text .= '%9Change:%9  '.$stock->{change}.' ('.$stock->{percent}.")\n\n";
    $text .= $stock->{date}.", ".$stock->{time}."\n";
    print CLIENTCRAP &draw_box('Xetra stockinfo', $text, $stock->{symbol}, 1);
}

sub update_ticker {
    my @stocks = split(/ /, Irssi::settings_get_str('xetra_ticker_stocks'));
    bg_fetch(\@stocks, 'ticker');
}

sub show_ticker ($$) {
    my ($item, $get_size_only) = @_; 
    $shift = 0 if $shift+1 > scalar(@ticker);
    return unless defined $ticker[$shift];
    my $tape;
    $_ = $ticker[$shift];
    $tape .= $_->{symbol}.': ';
    $tape .= $_->{current}.' ';
    if ($_->{change} =~ /^\+/) {
	$tape .= '%g';
    } elsif ($_->{change} =~ /^\-/) {
	$tape .= '%r';
    }
    $tape .= $_->{change}.'%n';
    
    $shift++ unless $get_size_only;
    my $format = "{sb ".$tape."}";
    $item->{min_size} = $item->{max_size} = length($tape);
    $item->default_handler($get_size_only, $format, 0, 1);
    Irssi::timeout_remove($timer);
    $timer = Irssi::timeout_add(Irssi::settings_get_int('xetra_ticker_interval')*1000, 'update_ticker', undef);
}

sub cmd_xetra ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    return unless defined $arg[0];
    if ($arg[0] eq 'get' && defined $arg[1]) {
	shift(@arg);
	bg_fetch(\@arg, 'get');
    } elsif ($arg[0] eq 'update') {
	update_ticker();
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

Irssi::statusbar_item_register('xetra', 0, 'show_ticker');

Irssi::settings_add_str($IRSSI{name}, 'xetra_default_stock_exchange', 'ETR');
Irssi::settings_add_str($IRSSI{name}, 'xetra_ticker_stocks', '');
Irssi::settings_add_int($IRSSI{name}, 'xetra_ticker_interval', 3);

Irssi::command_bind('xetra' => \&cmd_xetra);
foreach my $cmd ('get', 'update', 'help') {
    Irssi::command_bind('xetra '.$cmd => sub { cmd_xetra("$cmd ".$_[0], $_[1], $_[2]);});
}

$timer = Irssi::timeout_add(Irssi::settings_get_int('xetra_ticker_interval')*1000, 'update_ticker', undef);
update_ticker();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /xetra help for help';
