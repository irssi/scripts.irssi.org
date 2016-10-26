#!/usr/bin/env perl

use strict;
use LWP::Simple;
use Irssi;
use vars qw($VERSION %IRSSI);
use HTML::Entities;

$VERSION = '0.9';
%IRSSI = (
    authors     => 'Marcus \'darix\' Rückert, tira, Stefan \'tommie\' Tomanek',
    contact     => 'darix@irssi.de, tira@isx.de, stefan@pico.ruhr.de',
    name        => 'stocks',
    description => 'prints the stats for german stocks',
    license     => 'Public Domain',
    url         => 'http://irssi.org/scripts/',
    sbitems     => 'stocks_ticker'
);

my %stocklist = (
    DE => 'FSE+DTB+MUN+HAM+HAN+BRE+STU+BER+ETR+DUS+FFM+FFI+FFK+FFC+DFK+FFT',
    EU =>
'LIF+LCE+MSE+MAT+LME+NLK+ZRH+SFF+EOE+ROT+MEE+MIF+BBA+PSE+ASX+BSE+MSX+HSE+MIX+ISE+WSE+KSX+SSE+OSX+ENM+POP+BAS+BRN+MOP+SQ2+LTO+PAB+ISS+SQ1+ATH+LIS+LUX',
    OTHERS =>
'FX1+IPE+CSC+FNX+TSE+PAR+TYO+OPR+IMM+FFX+IOM+SMX+HFE+TOR+TIF+OSE+MRF+MRV+TFE+TOC+BIS+TGE+CSH+ICP+NXC+IMC+CBC+HOX+OPA+CBQ+SON+MAS+RDW+BHL+AUS+SSW+ALB+COC+TOE+VSE+CBF+NAT+MBF+TWI+TGT',
    US =>
'NYS+IND+NAS+CBT+CME+KBT+WPG+NYC+NYM+CMX+NYF+SFE+MIN+ASE+MAC+CEC+FOX+FRE+DOA+BOE+NAP',
    ASE => 'ASE',
    ASX => 'ASX',
    ATH => 'ATH',
    BER => 'BER',
    BRE => 'BRE',
    BSE => 'BSE',
    C05 => 'C05',
    CBT => 'CBT',
    CME => 'CME',
    DFK => 'DFK',
    DTB => 'DTB',
    DUS => 'DUS',
    ENM => 'ENM',
    ETR => 'ETR',
    FFC => 'FFC',
    FFI => 'FFI',
    FFM => 'FFM',
    FFT => 'FFT',
    FSE => 'FSE',
    FX1 => 'FX1',
    HAM => 'HAM',
    HAN => 'HAN',
    IND => 'IND',
    ISE => 'ISE',
    ISS => 'ISS',
    MIX => 'MIX',
    MUN => 'MUN',
    NAP => 'NAP',
    NAS => 'NAS',
    NYS => 'NYS',
    PAR => 'PAR',
    PSE => 'PSE',
    SFF => 'SFF',
    SON => 'SON',
    SQ1 => 'SQ1',
    SQ2 => 'SQ2',
    SSE => 'SSE',
    STU => 'STU',
    TGT => 'TGT',
    TWI => 'TWI',
    WSE => 'WSE',
    ZRH => 'ZRH'
);

my %stockhelp = (
    DE =>
'Deutschland (FSE DTB MUN HAM HAN BRE STU BER ETR DUS FFM FFI FFK FFC DFK FFT)',
    EU =>
'Europa (LIF LCE MSE MAT LME NLK ZRH SFF EOE ROT MEE MIF BBA PSE ASX BSE MSX HSE MIX ISE WSE KSX SSE OSX ENM POP BAS BRN MOP SQ2 LTO PAB ISS SQ1 ATH LIS LUX)',
    OTHERS =>
'Andere (FX1 IPE CSC FNX TSE PAR TYO OPR IMM FFX IOM SMX HFE TOR TIF OSE MRF MRV TFE TOC BIS TGE CSH ICP NXC IMC CBC HOX OPA CBQ SON MAS RDW BHL AUS SSW ALB COC TOE VSE CBF NAT MBF TWI TGT)',
    US =>
'USA (NYS IND NAS CBT CME KBT WPG NYC NYM CMX NYF SFE MIN ASE MAC CEC FOX FRE DOA BOE NAP)',
    ASE => 'AMEX',
    ASX => 'Amsterdam',
    ATH => 'Athen',
    BER => 'Berlin',
    BRE => 'Bremen',
    BSE => 'Brüssel',
    C05 => 'LiveTrading',
    CBT => 'CBoT',
    CME => 'CME',
    DFK => 'Fonds DE',
    DTB => 'EUREX',
    DUS => 'Düsseldorf',
    ENM => 'EURO.NM',
    ETR => 'XETRA',
    FFC => 'Frankfurt',
    FFI => 'FFM Indizes 2',
    FFM => 'FFM Indizes 1',
    FFT => 'Frankfurt STOXX',
    FSE => 'Frankfurt',
    FX1 => 'FOREX',
    HAM => 'Hamburg',
    HAN => 'Hannover',
    IND => 'USA Indizes',
    ISE => 'London',
    ISS => 'London Inl.',
    MIX => 'Mailand',
    MUN => 'München',
    NAP => 'Nasdaq OTC',
    NAS => 'Nasdaq',
    NYS => 'NYSE',
    PAR => 'Int. Indizes',
    PSE => 'Paris',
    SFF => 'SOFFEX',
    SON => 'Sonderwerte',
    SQ1 => 'London Auslandsak.',
    SQ2 => 'London Auslandsak.',
    SSE => 'Stockholm',
    STU => 'Stuttgart',
    TGT => 'TD GT',
    TWI => 'TD Indizes',
    WSE => 'Wien',
    ZRH => 'Zürich'
);

my %WPArt = (
    STK => 'Aktie',
    BND => 'Anleihe',
    FND => 'Fonds',
    FUT => 'Future',
    IND => 'Index',
    OPT => 'Option',
    WNT => 'Optionsschein',
    OTC => 'Over The Counter',
    MSC => 'Sonstige',
    SPC => 'Sonderwert',
    CUR => 'Währung',
    RTE => 'Zinssatz'
);

# search
#  -boerse {eu|de|us|others|}

sub cmd_kurs {
    my $XsearchWPArt   = 'UKN';
    my $XsearchBoersen = 'UKN';
    my $params         = shift ();

    if ( $params =~ m/-help/ ) {
        if ( $params =~ m/stocks/ ) {
            Irssi::print( "\cBhelp for stocks\cB", MSGLEVEL_CRAP );
            foreach my $key ( sort keys %stockhelp ) {
                Irssi::print( "$key - $stockhelp{$key}", MSGLEVEL_CRAP );
            }
        }
        else {
            if ( $params =~ m/bonds/ ) {
                Irssi::print( "\cBhelp for kind of bonds\cB", MSGLEVEL_CRAP );
                foreach my $key ( sort keys %WPArt ) {
                    Irssi::print( "$key - $WPArt{$key}", MSGLEVEL_CRAP );
                }
            }
            else {
                Irssi::print(
"\cBSTOCKS\cB [-stocks <stocklist>] [-bonds <wplist>] <querysting>",
                    MSGLEVEL_CRAP
                );
                Irssi::print( "",                    MSGLEVEL_CRAP );
                Irssi::print( "\cBSee also:\cB",     MSGLEVEL_CRAP );
                Irssi::print( "  STOCKS -help stocks", MSGLEVEL_CRAP );
                Irssi::print( "  STOCKS -help bonds",     MSGLEVEL_CRAP );
            }
        }
        return;
    }

    while ( $params =~ m/-(\S+) (\S+)/ ) {

        #    Irssi::print($2." ".$3, MSGLEVEL_CRAP);
        my $vars   = $2;
        my $option = $1;
        if ( $option eq "stocks" ) {
            my @stocks = split ( ',', $vars );
            for my $stock (@stocks) {
                if ( exists $stocklist{$stock} ) {
                    $stock = $stocklist{$stock};
                }
                else {
                    Irssi::print( "stock $stock does not exists see /STOCKS -help stocks",
                        MSGLEVEL_CRAP );
                    return;
                }
            }
            $XsearchBoersen = join ( "+", @stocks );
        }
        else {
            if ( $option eq "bonds" ) {
                my @wps = split ( ',', $vars );
                for my $wp (@wps) {
                    if ( !exists $WPArt{$wp} ) {
                        Irssi::print( "Kind of bond $wp does not exists see /STOCKS -help bonds",
                            MSGLEVEL_CRAP );
                        return;
                    }
                }
                $XsearchWPArt = join ( "+", @wps );
            }
            else {
                Irssi::print( "unknown option $option see /STOCKS -help", MSGLEVEL_CRAP );
                return;
            }
        }
        $params =~ s/-(\S+) (\S+)//;
    }
    $params =~ s/\^s+//;

    #  Irssi::print($XsearchBoersen, MSGLEVEL_CRAP);
    #  Irssi::print($XsearchWPArt, MSGLEVEL_CRAP);
    #  Irssi::print($params, MSGLEVEL_CRAP);
    if ( $params eq "" ) {
        Irssi::print( "empty query string see /STOCKS -help", MSGLEVEL_CRAP );
        return;
    }
    my $searchfor = $params;
    $searchfor =~ s/ /\%20/g;
    my $host         = "http://informer2.comdirect.de";
    my $path         = '/de/suche/main.html?';
    my $searchButton = 'Exakt';
    my $querystring  =
"&searchButton=$searchButton&XsearchWPArt=$XsearchWPArt&XsearchBoersen=$XsearchBoersen&searchfor=$searchfor";
    
    my $content = get( $host . $path . $querystring );

    my ( $oldcompany, $comp, $nbr, $boerse ) = "";

    $searchfor =~ s/\%20/ /g;

    if ( $content =~ m/Suchbegriff/s ) {
        if ( $content =~ m/Kurszeit/ ) {
            Irssi::print( "\cB" . $searchfor . " found:\cB", MSGLEVEL_CRAP );
            $content =~ s/\&nbsp//g;
            $content =~ m/Kurszeit.*?<\/tr>(.*?)<\/table>/s;
            $content = $1;
            while ( $content =~
m/<td.*?>(.*?)<\/td>.*?<td.*?>(.*?)<\/td>.*?<td.*?>(.*?)<\/td>.*?<td.*?>(.*?)<\/td>.*?/s
              )
            {
                $comp   = $1;
                $nbr    = $3;
                $boerse = $2;
                decode_entities($comp);
                decode_entities($nbr);
                decode_entities($boerse);
                if ($comp) {
                    Irssi::print( "  " . $nbr . " " . $boerse . ": " . $comp,
                        MSGLEVEL_CRAP );
                    $oldcompany = $comp;
                }
                else {
                    Irssi::print(
                        "  " . $nbr . " " . $boerse . ": " . $oldcompany,
                        MSGLEVEL_CRAP );
                }
                $content =~ m/<tr.*?>.*?<\/tr>(.*)/s;
                $content = $1;
            }
        }
        else {
            Irssi::print( "\cBcould not find:\cB $searchfor", MSGLEVEL_CRAP );
        }
        return;
    }

    if ( $content =~
m/<th width="99%" class="news">(.*?)<\/th>.*?<td.*?>WKN.*?class="sym">(\d+)/s
      )
    {
        Irssi::print( "\c_WKN " . $2 . " - " . $1 . "\c_", MSGLEVEL_CRAP );
    }

    if ( $content =~ m/<td.*?>(Aktueller Kurs)<\/td>\s+<td>(.*?)<\/td>/s ) {
        Irssi::print( "  \cB" . $1 . ":\cB " . $2, MSGLEVEL_CRAP );
    }

    if ( $content =~ m/<td.*?>R&uuml;cknahmepreis<\/td>\s+<td>(.*?)<\/td>/s ) {
        Irssi::print( "  \cBRücknahmepreis:\cB " . $1, MSGLEVEL_CRAP );
    }

    if ( $content =~ m/<td.*?>(Ausgabepreis)<\/td>\s+<td>(.*?)<\/td>/s ) {
        Irssi::print( "  \cB" . $1 . ":\cB " . $2, MSGLEVEL_CRAP );
    }

    if ( $content =~ m/<td.*?>(Differenz)<\/td>\s+<td>(.*?)<\/td>/s ) {
        Irssi::print( "  \cB" . $1 . ":\cB " . $2, MSGLEVEL_CRAP );
    }
}


# added by Stefan 'tommie' Tomanek
use vars qw{$ticker_shift $ticker_text $update_tag $refresh_tag};

sub get_stock {
    my ($wkn, $exchange) = @_;

    my $XsearchWPArt   = 'STK';
    my $XsearchBoersen = $exchange;
    
    my $searchfor = $wkn;
    #$searchfor =~ s/ /\%20/g;
    my $host         = "http://informer2.comdirect.de";
    my $path         = '/de/suche/main.html?';
    my $searchButton = 'Exakt';
    my $querystring = "&searchfor=".$wkn."&searchButton=Exakt&XsearchWPArt=STK&XsearchBoersen=".$exchange;

    my $content = get( $host . $path . $querystring );

    my ( $oldcompany, $comp, $nbr, $boerse ) = "";

    my %stock;
    if ( $content =~
m/<th width="99%" class="news">(.*?)<\/th>.*?<td.*?>WKN.*?class="sym">(\d+)/s
      )
    {
	$stock{'wkn'} = $2;
	$stock{'company'} = $1;
    }

    if ( $content =~ m/<td.*?>(Aktueller Kurs)<\/td>\s+<td>(.*?)<\/td>/s ) {
	$stock{'price'} = $2;
	$stock{'price'} =~ s/&nbsp;<small>.*<\/small>//;
    }
    if ( $content =~ m/<td.*?>(Differenz)<\/td>\s+<td>(.*?)<\/td>/s ) {
	$stock{'diff'} = $2;
    }
    return %stock;
}

sub update_ticker {
    fork_get();
}

sub fork_get {
    my ($rh, $wh);
    pipe($rh, $wh);
    my $pid = fork();
    if ($pid > 0) {
	close $wh;
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my $data = get_ticker_data();
	    print($wh $data);
	    close($wh)
	};
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    my ($rh, $pipetag) = @{$_[0]};
    my @lines = <$rh>;
    close($rh);
    Irssi::input_remove($pipetag);
    my $text = join("", @lines);
    $ticker_text = $text;
}

sub shift_string {
    my ($string, $pos) = @_;
    my $first = substr($string, 0, $pos);
    my $middle = substr($string, $pos);
    return $middle.$first;
}

$ticker_shift = 0;
sub show_ticker {
    my ($item, $get_size_only) = @_;
    my $ticker_string = $ticker_text;
    unless ($get_size_only) {
        $ticker_shift = 0 if ($ticker_shift >= length($ticker_string));
    }
    my $max_width = Irssi::settings_get_int('stocks_ticker_max_width');
    my $ticker_text = shift_string($ticker_string, $ticker_shift);
    $ticker_text = substr($ticker_text, 0, $max_width-3) if (length($ticker_text)+2 > $max_width);
    $item->{min_size} = $item->{max_size} = length("$ticker_text")+2;
    $ticker_text =~ s/\%/\%\%/g;
    $ticker_text = '>'.$ticker_text.'%n>';
    $ticker_text =~ s/\(\-/\%R\(\-/g;
    $ticker_text =~ s/\(\+/\%G\(\+/g;
    $ticker_text =~ s/\)/\)\%n/g;
    my $format = "{sb ".$ticker_text."}";
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub ticker_redraw {
    $ticker_shift++;
    Irssi::statusbar_items_redraw('stocks_ticker');
}

sub get_ticker_data {
    my @stocks = split(/,/, Irssi::settings_get_str('stocks_ticker_stocks'));
    my $tape='';
    foreach (@stocks) {
	my ($wkn, $exchange, $name) = split(/\//, $_);
	my %stock = get_stock($wkn, $exchange);
	if ($name eq '') { $name = $stock{'company'}; };
	$tape = $tape.'| '.$name.': '.$stock{'price'}.'/'.$stock{'diff'};
    }
    return $tape;
}

sub load_config {
    Irssi::timeout_remove($update_tag);
    Irssi::timeout_remove($refresh_tag);
    $update_tag = Irssi::timeout_add(Irssi::settings_get_int('stocks_ticker_update_delay'), 'update_ticker', undef);
    $refresh_tag = Irssi::timeout_add(Irssi::settings_get_int('stocks_ticker_scroll_delay'), 'ticker_redraw', undef);
    update_ticker();
}

Irssi::statusbar_item_register('stocks_ticker', 0, 'show_ticker');
Irssi::settings_add_int('misc', 'stocks_ticker_max_width', 20);
Irssi::settings_add_int('misc', 'stocks_ticker_update_delay', 120000);
Irssi::settings_add_int('misc', 'stocks_ticker_scroll_delay', 2000);
Irssi::settings_add_str('misc', 'stocks_ticker_stocks', '');

Irssi::command_bind( 'stocks', 'cmd_kurs' );
Irssi::command_bind( 'stocks_ticker_update', 'load_config' );

load_config();
