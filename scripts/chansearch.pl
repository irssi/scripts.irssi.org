#!/usr/bin/perl
#
# by Stefan 'tommie' Tomanek <stefan@pico.ruhr.de>

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2.3';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek, bw1',
    contact     => 'bw1@aol.at',
    name        => 'ChanSearch',
    description => 'searches for specific channels',
    license     => 'GPLv2',
    url         => 'http://scripts.irssi.org/',
    changed     => $VERSION,
    selfcheckcmd=> '/chansearch -check',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Description%9
  $IRSSI{description}
%9Usage%9
  /chansearch [-network|-n <networkname>] [searchstring]
  /chansearch -help|-h
  /chansearch -check
%9Settings%9
  /set ChanSearch_default_network freenode
  /set ChanSearch_max_results 50
  /set ChanSearch_max_columns 0
%9See also%9
  https://netsplit.de/
END

use utf8;
use Irssi 20020324;
use open qw/:std :utf8/;
use LWP::UserAgent;
use LWP::Protocol::https;
use HTML::Entities;
use JSON::PP;
use Getopt::Long qw(GetOptionsFromString);
use POSIX;

use vars qw($forked);

$forked = 0;
my $footer;
my ($default_network, $max_results, $max_columns);
my ($max_columns2);
my (@results, $resultcount);

# ! for the fork
my (@clist, $t, $rcount);

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
    $text =~ s/<.*?>//g;
    return $text;
}

sub get_entries_count {
    $t =~ m/(\d+) matching results/;
    return $1;
}

sub html_to_list {
    utf8::decode($t);
    while (length($t) > 0) {
	my %h;
	if ($t =~ m#<span class="cs-channel">(.*?)</span>#p) {
	    $h{channel}= dehtml($1);
	    $' =~ m#<span class="cs-network">(.*?)</span>#p;
	    $h{network}= dehtml($1);
	    #$' =~ m#<span class="cs-users">(.*?)</span>#p;
	    #$' =~ m#<span class="cs-details">Chat Room.*?(\d+).*?</span>#p;
	    $' =~ m#<span class="cs-details">Chat Room - (\d+) users - </span>#p;
	    my $u=$1;
	    #$' =~ m#class="cs-time">.*?</span>(.*?)<span class="cs-category"#p;
	    $' =~ m#(current topic:|No topic)(.*?)<br>#p;
	    $t= $';
	    $h{topic}=dehtml($2);
	    $u =~ m/(\d+)/;
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
	#my $data = encode_json( \@clist );
	my $data = encode_json( { clist=>[ @clist ], rcount=>$rcount } );
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

    my $res= decode_json( $data );
    @results = @{ $res->{clist} };
    $resultcount = $res->{rcount};

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
	    $_->{network}, $_->{channel}, $_->{users},  substr($_->{topic},0,
		$max_columns2-$lnet-$lchan));
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
    my $help;
    my ($re, $ar) = GetOptionsFromString($args,
	'network=s' => \$net,
	'n=s' => \$net,
	'help' => \$help,
	'h' => \$help,
	'check' => \&self_check_init,
    );
    if ($max_columns==0) {
	$max_columns2 = Irssi::active_win()->{width} -15;
    }
    if (!defined $help) {
	fork_search($ar->[0], $net);
    } else {
	cmd_help($IRSSI{name}, $server, $witem);
    }
}

sub self_check_init {
    $max_results=30;
    fork_search('linux','Freenode');
    Irssi::timeout_add_once(5*1000, 'sig_self_check','');
}

sub self_check_quit {
    my ( $s )=@_;
    Irssi::command("selfcheckhelperscript $s");
}

sub sig_self_check {
    my ($min, $max);
    # min result
    $min=20;
    if ( scalar @results >= $min) {
	print "Results: ",scalar @results," check";
    } else {
	print "Results: ",scalar @results," <$min fail";
    	self_check_quit("Error: self check fail (result)");
    }
    # result more pages
    if ( $resultcount == scalar @results || $max_results == scalar @results ) {
    	print "Resultscount: $resultcount check";
    } else {
	print "Resultscount: $resultcount  fail";
    	self_check_quit("Error: self check fail (pages)");
    }
    $max_results= Irssi::settings_get_int($IRSSI{name}.'_max_results');
    # topic
    $min= 1000;
    $max= 0;
    foreach my $n ( @results ) {
	my $l = length ( $n->{topic} );
	$min = $l if ($l < $min);
	$max = $l if ($l > $max);
    }
    if ( $min != $max && $max >200 ) {
	print "Topic min:$min max:$max check"; 
    } else {
	print "Topic min:$min max:$max"; 
    	self_check_quit("Error: self check fail (topic)");
    }
    # users
    $min= 10000;
    $max= 0;
    foreach my $n ( @results ) {
	my $l =  $n->{users} ;
	$min = $l if ($l < $min);
	$max = $l if ($l > $max);
    }
    if ( $min != $max && $max >200 ) {
	print "Users min:$min max:$max check"; 
    } else {
	print "Users min:$min max:$max"; 
    	self_check_quit("Error: self check fail (users)");
    }
    self_check_quit('ok');
}

sub sig_setup_changed {
    $default_network= Irssi::settings_get_str($IRSSI{name}.'_default_network');
    $max_results= Irssi::settings_get_int($IRSSI{name}.'_max_results');
    $max_columns= Irssi::settings_get_int($IRSSI{name}.'_max_columns');
}

sub cmd_help {
    my ($args, $server, $witem)=@_;
    $args=~ s/\s+//g;
    if (lc($IRSSI{name}) eq lc($args)) {
	Irssi::print($help, MSGLEVEL_CLIENTCRAP);
	Irssi::signal_stop();
    }
}

Irssi::settings_add_str($IRSSI{name}, $IRSSI{name}.'_default_network', 'freenode' );
Irssi::settings_add_int($IRSSI{name}, $IRSSI{name}.'_max_results', 50 );
Irssi::settings_add_int($IRSSI{name}, $IRSSI{name}.'_max_columns', 0 );

Irssi::signal_add('setup changed', "sig_setup_changed");

Irssi::command_bind('chansearch', \&cmd_chansearch);
Irssi::command_set_options('chansearch', 'network check');
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';

# vim:set sw=4 ts=8:
