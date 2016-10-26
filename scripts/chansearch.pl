#!/usr/bin/perl
#
# by Stefan 'tommie' Tomanek <stefan@pico.ruhr.de>

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '20021019';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'ChanSearch',
    description => 'searches for specific channels',
    license     => 'GPLv2',
    url         => 'http://scripts.irssi.org/',
    changed     => $VERSION,
    modules     => 'Data::Dumper LWP::UserAgent POSIX',
);

use Irssi 20020324;
use LWP::UserAgent;
use Data::Dumper;
use POSIX;

use vars qw($forked);

$forked = 0;

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

sub fork_search ($) {
    my ($query) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    return if $forked;
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	close($wh);
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
	print CLIENTCRAP "%R>>%n Please wait...";
    } else {
	my %result;
	$result{query} = $query;
	$result{result} = search_channels($query);
	my $dumper = Data::Dumper->new([\%result]);
	$dumper->Purity(1)->Deepcopy(1);
	my $data = $dumper->Dump;
	print($wh $data);
	close($wh);
	POSIX::_exit(1);
   }
}

sub pipe_input ($$) {
    my ($rh, $pipetag) = @{$_[0]};
    my $data;
    $data .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    return unless($data);
    no strict;
    my %result = %{ eval "$data" };
    my $text;
    foreach (sort keys %{ $result{result} }) {
        $text .= '%9'.$_.'%9, '.$result{result}{$_}->{nicks}." nicks\n";
        $text .= '   "'.$result{result}{$_}->{topic}.'"'."\n" if $result{result}{$_}->{topic};
    }
    $forked = 0;
    print CLIENTCRAP draw_box('ChanSearch', $text, $result{query}, 1);
}

sub search_channels ($) {
    my ($query) = @_;
    my $ua = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
    $ua->agent('Irssi Chansearch');
    my $page = 'http://www.ludd.luth.se/irc/bin/csearch.cgi';
    my %form = ( topic => "channels",
                 hits => "all",
                 min  => 2,
		 max  => "infinite",
		 sort => "in alphabetic order.",
		 pattern => $query
		);
    my $result = $ua->post($page, \%form);
    return undef unless $result->is_success();
    my %channels;
    foreach ( split(/\n/, $result->content()) ) {
	if (/^<LI><STRONG>(.*?)<\/STRONG> <I>(\d+)<\/I><BR>(.*).$/) {
	    $channels{$1} = { topic => $3, nicks => $2 };
	}
    }
    return \%channels;
}

sub cmd_chansearch ($$$) {
    my ($args, $server, $witem) = @_;
    fork_search($args);
}

Irssi::command_bind('chansearch', \&cmd_chansearch);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';
