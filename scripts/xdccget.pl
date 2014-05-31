#
# by Stefan "tommie" Tomanek <stefan@kann-nix.org>
#
# History:
#
# 26.02.2002
# *first release, report bugs :)
#
# 01.03.2002
# *CHanged to GPL
#
# 08.03.200
# *some bugfixes
#
# 13.04.2002
# *major improvements
# *cosmetic changes
# 
# 14.04.2002
# *internal redesign
# *feature enhancements
#
# 17.04.2002
# * improved queuing code
# * changed to $server->{tag}
# * improved communication with server
#
# 21.04.2002
# *improved ETA listing
#
# 27.04.2002
# *handling of gone bots added
#
# 28.04.2002
# *fixed handling of servers that are not in an ircnet

use strict;
#use warnings;

use vars qw($VERSION %IRSSI);
$VERSION = "20040509";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "XDCCget",
    description => "advances downloading from XDCC bots",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands	=> "xdccget"
);

use Irssi 20020324;

use vars qw(@queue $timer $debug %lists);

$debug=0;

sub show_help() {
    my $help="XDCCget $VERSION
/xdccget queue Nickname <number> <number>...
    Queue the specified packs of the server 'Nickname'
/xdccget list
    List the download queue
/xdccget cancel <number>
    Remove pack <number> from the local queue
/xdccget help
    Display this help
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("XDCCget", $text, "help", 1);
}

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    my $exp_flags = Irssi::EXPAND_FLAG_IGNORE_EMPTY | Irssi::EXPAND_FLAG_IGNORE_REPLACES;
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {                                                      $box .= '%R|%n '.$_."\n";
    }                                                                               $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub contains {
    my ($item, @list) = @_;
    foreach (@list) {
	    ($item eq $_) && return 1;
    }
    return 0;
}

sub event_message_irc_notice {
    my ($server, $msg, $nick, $address, $target) = @_;
    $_ = $msg;
    if ($queue[0] &&  $nick eq $queue[0]->{'nick'}) {
	if (/\*\*\* Closing Connection:/) {
	    print CLIENTCRAP "%R>>%n XDCC-Transfer closed";
	    # Is it a canceled transger?
	    if ($queue[0]->{'status'} == 5) {
		$queue[0]->{'status'} = 4;
	    } else {
		# We should try again
		$queue[0]->{'status'} = 0;
	    }
	} elsif (/\*\*\* Transfer Completed/i) {
    	    print CLIENTCRAP "%R>>%n XDCC-Transfer completed";
	    # Mark the transfer as completed
	    $queue[0]->{'status'} = 4;
	} elsif (/\*\*\* You already requested that pack/i) {
	    $queue[0]->{'status'} = 4;
	} elsif (/\*\*\* Sending You Pack/i || /\*\*\* Sending You Your Queued Pack|DCC Send .*? \(.*?\)/i) {
	    $queue[0]->{'status'} = 3;
	    print CLIENTCRAP "%R>>%n XDCC-Transfer starting";
	} elsif (/\*\*\* All Slots Full, Added (|you to the main )queue in position ([0-9]*)/i) {
	    $queue[0]->{'pos'} = $2;
	    $queue[0]->{'etr'} = 0;
	    $queue[0]->{'status'} = 2;
	} elsif (/You have been queued for ([0-9]*?) hr ([0-9]*?) min, currently in main queue position ([0-9]*?) of ([0-9]*?)\.  Estimated remaining time is ([0-9]*?) hr ([0-9]*?) min or (less|more)\./i) {
	    $queue[0]->{'pos'} = $3;
	    $queue[0]->{'etr'} = time() + (($5*60)+$6)*60;
	    $queue[0]->{'status'} = 2;
	} elsif (/You have been queued for ([0-9]*?) hours ([0-9]*?) minutes, currently in main queue position ([0-9]*?) of ([0-9]*?)\./i) {
	    $queue[0]->{'pos'} = $3;
	    $queue[0]->{'status'} = 2;
	} elsif (/You have been queued for ([0-9]*?) minutes, currently in main queue position ([0-9]*?) of ([0-9]*?)\./) {
	    $queue[0]->{'status'} = 2;
	    # FIXME unite somehow with regexp above
	    $queue[0]->{'pos'} = $2;
	} elsif (/It has been placed in queue slot #(\d+), it will send when sends are available/) {
	    $queue[0]->{'pos'} = $1;
	    $queue[0]->{'status'} = 2;
	} elsif (/\*\*\* Invalid Pack Number/) {
	    $queue[0]->{'status'} = 4;
	} elsif (/\*\*\* The Owner Has Requested That No New Connections Are Made/) {
	    $queue[0]->{'status'} = 4;
	} elsif (/\*\*\* All Slots Full,(| Main) queue of size [0-9]* is Full, Try Again Later/i || /\*\*\* You can only have 1 transfer at a time/i) {
	    if (Irssi::settings_get_int('xdccget_retry_time') > 0) {
		my $retry = Irssi::settings_get_int('xdccget_retry_time')*1000;
		$queue[0]->{'status'} = 6;
		$queue[0]->{'timer'} = Irssi::timeout_add($retry, 'retry_transfer', undef);
		$queue[0]->{'etr'} = time()+$retry/1000;
	    } else {
		$queue[0]->{'status'} = 4;
	    }
	} elsif (/Removed you from the queue/) {
	    $queue[0]->{'status'} = 4;
	} else { Irssi::print($_) if ($debug); }
	
	process_queue();
    }
    if (/#(\d+).+?\d+x \[ *(<?\d+.*?)\] +(.*)$/) {
	my ($pack, $size, $name) = ($1, $2, $3);
    	if (defined $lists{lc $server->{tag}}{lc $nick}) {
	    $lists{lc $server->{tag}}{lc $nick}{$pack} = $name;
	}
	foreach (@queue) {
	    next unless lc $nick eq lc $_->{nick};
	    next unless lc $server->{tag} eq lc $_->{net};
	    next unless $_->{pack} eq $pack;
	    $_->{filename} = $name;
	}
    }
}

sub process_queue {
    unless (scalar(@queue) > 0) {return 0};
    my %current = %{$queue[0]};
    shift @queue if ( $current{'status'} == 4 );
    unless (scalar(@queue) > 0) {return 0};
    %current = %{$queue[0]};
    if ( $current{'status'} == 0 ) {
	my $server = Irssi::server_find_tag($current{'net'});
    	$server->command('MSG '.$current{'nick'}.' xdcc send '.$current{'pack'});
	$queue[0]->{'try'}++;
	$queue[0]->{'status'} = 1;
    }
}

sub retry_transfer {
    if (defined $queue[0] && $queue[0]->{'status'} == 6) {
	Irssi::timeout_remove($queue[0]->{'timer'});
	#print CLIENTCRAP "%R>>%n Retrying XDCC-transfer...";
	$queue[0]->{'status'} = 0;
	process_queue();
    }
}

sub queue_pack {
    my ($args, $server, $witem) = @_;
    my @args = split(/ /, $args, 2);
    my ($nick, $packs);
    if (ref $witem && $witem->{type} eq 'QUERY' && $args[0] =~ /^\d+$/) {
	($nick, $packs) = ($witem->{name}, $args[0]);
    } else {
	($nick, $packs) = @args;
    }
    my @packs = split(/ /, $packs);
    foreach (@packs) {
	# 0: Waiting, 1: Processing, 2: Doenloading
	my $status = 0;
	my $chatnet = $server->{tag};
	my %transfer = ('nick'    => $nick,
			'pack'    => $_,
			'status'  => $status,
			'net'     => $chatnet,
			'pos'     => 0,
			'try'     => 0,
			'etr'     => 0,
			'timer'   => undef,
			);
	if (defined $lists{lc $server->{tag}}{lc $nick}{$_}) {
	    $transfer{filename} = $lists{lc $server->{tag}}{lc $nick}{$_};
	}
	push @queue, \%transfer;
    }
    process_queue()
}

sub list_xdcc_queue {
    my $text;
    my %progress = (0=>'waiting',
		    1=>'requesting',
		    2=>'queued',
		    3=>'transferring',
		    4=>'completed',
		    5=>'canceling',
		    6=>'retrying');
    my $i = 1;
    foreach (@queue) {
	my $current = $_;
	my $botname = $current->{'nick'};
	my $ircnet = $current->{'net'};
	my $pack = $current->{'pack'};
	my $status = $progress{$current->{'status'}};
	my $info = '';
	my $etr = '';
	if ($current->{'status'}==2) {
	    my $time = $current->{'etr'}-time();
            my $hours = int($time / (60*60));
            my $minutes = int( ($time-($hours*60*60))/60 );
            my $seconds = int( ($time-($hours*60*60)-($minutes*60))  );

            $etr = '('.$hours.' hours, '.$minutes.' minutes and '.$seconds.' seconds remaining)' if ($current->{'etr'} > 0);
	    $info = "[".$current->{'pos'}."]".' '.$etr;
	} elsif ($current->{'status'}==6) {
	    my $time = $current->{'etr'}-time();
	    my $hours = int($time / (60*60));
	    my $minutes = int( ($time-($hours*60*60))/60 );
	    my $seconds = int( ($time-($hours*60*60)-($minutes*60))  );
	    
	    $etr = '('.$hours.' hours, '.$minutes.' minutes and '.$seconds.' seconds remaining)' if ($current->{'etr'} > 0);
	    $info = '['.$current->{'try'}.']'.' '.$etr;
	}
	$text .= "%9".$i."%9 ".$botname."<".$ircnet.">: Pack ".$pack;
	$text .= " (".$current->{filename}.")" if defined $current->{filename};
	$text .= " => ".$status.' '.$info;
	$text .= "\n";
	$i++;
    }
    print CLIENTCRAP draw_box("XDCCget", $text, "queued packs", 1);
}

sub cancel_pack {
    my (@numbers) = @_;
    @numbers = sort {$b cmp $a} @numbers;
    foreach (@numbers) {
	my $item = @queue->[$_-1];

	if ($item->{'status'} == 2) {
	    # Remove the order from the bots queue
	    my $server = Irssi::server_find_tag($item->{'net'});
	    $server->command('MSG '.$item->{'nick'}.' xdcc remove');
	    print CLIENTCRAP "%R>>>%n Removing pack ".$_." from server queue";
	    $item->{'status'} = 5;
	    #splice(@queue, $_,$_+1);
	} elsif ($item->{'status'} == 3) {
	    $item->{'status'} = 5;
	    Irssi::command('DCC close get '.$item->{'nick'});
	    print CLIENTCRAP "%R>>>%n Transfer aborted, waiting for acknowledgement";
	} else {
	    splice(@queue, $_-1, $_);
	}
	process_queue();
    }
}

sub list_packs ($$) {
    my ($server, $bot) = @_;
    $server->command('MSG '.$bot.' xdcc list');
    $lists{lc $server->{tag}}{lc $bot} = {};
}

sub cmd_xdccget {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);

    if ((scalar(@arg) == 0) or ($arg[0] eq '-l')) {
	list_xdcc_queue();
    } elsif ($arg[0] eq 'queue') {
	# queue files
	shift @arg;
	queue_pack("@arg", $server, $witem);
    } elsif ($arg[0] eq 'list' && defined $arg[1]) {
	list_packs($server, $arg[1]);
    } elsif ($arg[0] eq 'cancel') {
	shift @arg;
	cancel_pack(@arg);
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

sub event_private_message {
    my ($server, $text, $nick, $address) = @_;
    event_message_irc_notice($server, $text, $nick, $address, undef);
}

sub event_no_such_nick {
    my ($server, $args, $sender_nick, $sender_address) = @_;
    my ($myself, $nick) = split(/ /, $args, 3);
    
    unless (scalar(@queue) == 0) {
	if ($nick eq $queue[0]->{'nick'}) {
	    if ($queue[0]->{'status'} == 1 || $queue[0]->{'status'} == 5) {
		$queue[0]->{'status'} = 4;
	    }
	}
	process_queue();
    }
}


Irssi::command_bind('xdccget', \&cmd_xdccget);
foreach my $cmd ('queue', 'cancel', 'list', 'help', 'list') {
    Irssi::command_bind('xdccget '.$cmd => sub {
                        cmd_xdccget("$cmd ".$_[0], $_[1], $_[2]); });
}


Irssi::signal_add('message irc notice', 'event_message_irc_notice');
Irssi::signal_add("message private", "event_private_message");
Irssi::signal_add("event 401", "event_no_such_nick");

Irssi::settings_add_int($IRSSI{'name'}, 'xdccget_retry_time', 30);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /xdccget help for help';
