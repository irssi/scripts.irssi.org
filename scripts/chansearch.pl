#!/usr/bin/perl
#
# by Stefan 'tommie' Tomanek <stefan@pico.ruhr.de>

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2.0';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek, bw1',
    contact     => 'bw1@aol.at',
    name        => 'ChanSearch',
    description => 'searches for specific channels',
    license     => 'GPLv2',
    url         => 'http://scripts.irssi.org/',
    changed     => $VERSION,
);

use utf8;
use Irssi 20020324;
use open qw/:std :utf8/;
use LWP::UserAgent;
use HTML::Entities;
use JSON::PP;
use Getopt::Long qw(GetOptionsFromString);
use POSIX;

use vars qw($forked);

$forked = 0;
my $footer;
my $default_network;
my $max_results;
my @results;

# ! for the fork
my @clist;
my $t;

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

sub dehtml {
    my ($text) =@_;
    $text =decode_entities($text);
    utf8::decode($text);
    $text =~ s/<.*?>//g;
    return $text;
}

sub get_entries_count {
    $t =~ m/(\d+) matching entries found/;
    return $1;
}

sub html_to_list {
    while (length($t) > 0) {
	my %h;
	if ($t =~ m#<span class="cs-channel">(.*?)</span>#p) {
	    $h{channel}= dehtml($1);
	    $' =~ m#<span class="cs-network">(.*?)</span>#p;
	    $h{network}= dehtml($1);
	    $' =~ m#<span class="cs-users">(.*?)</span>(.*?)<span class="cs-category"#p;
	    $t= $';
	    $h{topic}=dehtml($2);
	    $_=$1;
	    $_ =~ m/(\d+)/;
	    $h{users}=$1;
	    push @clist, {%h};
	} else {
	    $t='';
	}
    }
}

sub fork_search {
    my ($query,$net) = @_;
    $footer="$net $query";
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
	search_channels($query,$net);
	my $data = encode_json( \@clist );
	print($wh $data);
	close($wh);
	POSIX::_exit(1);
   }
}

sub pipe_input ($$) {
    my ($rh, $pipetag) = @{$_[0]};
    my $data;
    {
	select($rh);
	local $/;
	select(CLIENTCRAP);
	$data = <$rh>;
	close($rh);
    }
    Irssi::input_remove($$pipetag);
    return unless($data);

    @results = @{ decode_json( $data ) };

    my $lnet=0;
    my $lchan=0;
    foreach (@results) {
	$lnet =length($_->{network}) if ($lnet <length($_->{network}));
	$lchan =length($_->{channel}) if ($lchan <length($_->{channel}));
    }
    $lnet++;
    $lchan++;

    my $text;
    foreach (@results) {
	$text .= sprintf("%-".$lnet."s%-".$lchan."s %4i %s\n",
	    $_->{network}, $_->{channel}, $_->{users},  substr($_->{topic},0,65-$lnet-$lchan));
    }

    $forked = 0;
    print CLIENTCRAP draw_box('ChanSearch', $text, $footer, 1);
}

sub search_channels ($) {
    my ($query,$net) = @_;
    my $ua = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
    $ua->agent('Irssi Chansearch');
    # http://irc.netsplit.de/channels/?net=IRCnet&chat=linux&num=10
    my $num='';
    my $count=0;
    my $rcount;
    do {
	my $page = "http://irc.netsplit.de/channels/?net=$net&chat=$query$num";
	my $result = $ua->get($page);
	return undef unless $result->is_success();
	$t = $result->content();
	$rcount = get_entries_count();
	html_to_list();
	$count += 10;
	$num ="&num=$count";
    } while ( $count < $rcount  && $count < $max_results );
}

sub cmd_chansearch ($$$) {
    my ($args, $server, $witem) = @_;
    my $net= $default_network;
    my ($re, $ar) = GetOptionsFromString($args,
	'network=s' => \$net,
	'n=s' => \$net,
	'check' => \&self_check_init,
    );
    fork_search($ar->[0], $net);
}

sub self_check_init {
    fork_search('linux','IRCnet');
    Irssi::timeout_add_once(5*1000, 'sig_self_check','');
    Irssi::command_bind('quit', \&cmd_quit_self_check);
}

sub sig_self_check {
    my $min=10;
    if ( scalar @results > $min) {
	print "Results: ",scalar @results," check";
    } else {
	print "Results: ",scalar @results," <$min fail";
	die("Error: self check fail");
    }
}

sub sig_setup_changed {
    $default_network= Irssi::settings_get_str($IRSSI{name}.'_default_network');
    $max_results= Irssi::settings_get_int($IRSSI{name}.'_max_results');
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_default_network', 'freenode' );
Irssi::settings_add_int($IRSSI{name}, $IRSSI{name}.'_max_results', 50 );

Irssi::signal_add('setup changed', "sig_setup_changed");

Irssi::command_bind('chansearch', \&cmd_chansearch);
Irssi::command_set_options('chansearch', 'network check');

sig_setup_changed();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';

# vim:set sw=4 ts=8:
