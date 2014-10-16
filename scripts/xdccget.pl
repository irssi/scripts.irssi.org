# Original version by Stefan "tommie" Tomanek <stefan@kann-nix.org>
# Enhanced with max. download limits, retries, pausing, searching and other neat stuff by Obfuscoder (obfuscoder@obfusco.de)
# You can find the script on GitHub: https://github.com/obfuscoder/irssi_scripts
# Please report bugs to https://github.com/obfuscoder/irssi_scripts/issues

use strict;
use warnings;

use vars qw($VERSION %IRSSI);
$VERSION = "20141016";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek, Obfuscoder",
    contact     => "obfuscoder\@obfusco.de",
    name        => "xdccget",
    description => "enhanced downloading, queing, searching from XDCC bots",
    license     => "GPLv2",
    changed     => "$VERSION",
    commands    => "xdccget"
);

use Irssi 20020324;

use vars qw(@queue @completed %offers $timer $debug %lists);

Irssi::settings_add_str($IRSSI{'name'}, 'xdccget_config_path', "$ENV{HOME}/.irssi");
Irssi::settings_add_int($IRSSI{'name'}, 'xdccget_max_downloads', 2);
Irssi::settings_add_int($IRSSI{'name'}, 'xdccget_retry_time', 5);

$debug=0;
my $config_path = Irssi::settings_get_str('xdccget_config_path');
my $max_downloads = Irssi::settings_get_int('xdccget_max_downloads');
my $queue_file = "$config_path/xdccget.queue";
sub saveQueue {
    if (!open (QUEUE, q{>}, $queue_file)) {
        print CLIENTCRAP "XDCCGET - ERROR! Cannot open queue file for saving at $queue_file. $!";
        return;
    }
    foreach (@queue) {
        print QUEUE $_->{net}."\t".$_->{nick}."\t".$_->{pack}."\t".$_->{filename}."\t".$_->{xdcc}."\n";
    }
    if (!close QUEUE) {
        print CLIENTCRAP "XDCCGET - ERROR! Could not close queue file after saving at $queue_file. $!";
    }
}

sub loadQueue {
    @queue = ();
    if (!open (QUEUE, q{<}, $queue_file)) {
        print CLIENTCRAP "XDCCGET - Warning: Could open queue file for loading from $queue_file: $!";
        return;
    }
    while (<QUEUE>) {
        chomp;
        my ($net, $nick, $pack, $desc, $xdcc) = split (/\t/);
        if ($xdcc eq "") {
            $xdcc = "xdcc";
        }
        my %transfer = (
            'nick'     => $nick,
            'pack'     => $pack,
            'status'   => 'waiting',
            'net'      => $net,
            'pos'      => 0,
            'try'      => 0,
            'etr'      => 0,
            'timer'    => undef,
            'xdcc'     => $xdcc,
            'filename' => $desc,
        );
        push @queue, \%transfer;
    }
    if (!close QUEUE) {
        print CLIENTCRAP "XDCCGET - ERROR! Could not close queue file after loading at $queue_file. $!";
    }
}

sub debugFunc {
    return unless ($debug);
    my $funcname = shift (@_);
    print CLIENTCRAP "XDCC-DEBUG - $funcname (". join(",",@_).")\n";
}

sub show_help() {
    my $help="XDCCget $VERSION
  Commands:

  /xdccget queue <nickname> <number> [[-xdcc=<method>] <description>]
      Queue the specified pack of the currently selected server and 'Nickname'.
      The description will be shown in the queue.
      With -xdcc=<method> it is possible to specify the method to be used in the request.
      Default is 'xdcc' as in /msg <nickname> xdcc send <number>

  /xdccget stat
  /xdccget
  /xdccget -l
      List the download queue

  /xdccget list <nickname>
      Request the XDCC list of <nickname>

  /xdccget cancel <number>
      Cancel the download if currently downloading, request to being removed from queue
      if queued by the XDCC offerer, or remove pack <number> from the download queue

  /xdccget pause <number>
      Pause pack <number> within the local queue. Resume with reset

  /xdccget reset <number>
      Reset pack <number> so that it is unpaused and --
      if download slots are still available -- triggers a download request

  /xdccget offers [<options>] <description search pattern>
      Display all the announced offers matching the given pattern or options.
      The announcements are continuously monitored by this script throughout all joined channels.

      Options:
      One or more of the following options can be used. Each option must start with a '-':

      -server=<server pattern>     only show offers announced by bots on servers matching this pattern
      -channel=<channel pattern>   only show offers announced by bots on channels matching this pattern
      -nick=<nick pattern>         only show offers announced by bots with nicks matching this pattern

      Examples:
         /xdccget offers iron.*bluray
         /xdccget offers -nick=bot iron.*bluray
         /xdccget offers -channel=beast-xdcc iron.*bluray

      Regular expressions are used to match each of the parameters.

  /xdccget help
      Display this help

  You can also simply use /x instead of /xdccget ;-)

  Configuration:

  xdccget_config_path
      Path where this script is storing its files (queue and finished downloads).
      Default is '\$HOME/.irssi'.

  xdccget_max_downloads
      Maximum number of parallel downloads. Default is 2. A download request which is queued
      by the XDCC offer bot does not count against the limit. The next item in the download queue
      is being requested as long as download slots are available. Also other downloads not controlled
      by this script do not count either. It is also possible to exceed this limit if a bot sends the
      previously requested and queued file while there are downloads running already. 

  xdccget_retry_time
      Time in minutes between retries. Default is 5. Retries are necessary for full
      offer queues of bots, bots being/becoming offline, or not getting the requested download or any
      understandable message regarding the request. Please DO NOT set this value to less than 300
      (5 minutes) or risk being banned from the channels for spamming the bots.

  Please report bugs to https://github.com/obfuscoder/irssi_scripts/issues
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
    if (defined($text)) {
        foreach (split(/\n/, $text)) {
            $box .= '%R|%n '.$_."\n";
        }
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
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
    debugFunc ("event_message_irc_notice", @_);
    my ($server, $msg, $nick, $address, $target) = @_;
    my $i;
    $_ = $msg;
    for ($i=0; $i<= $#queue; $i++) {
        if ($queue[$i] && lc($nick) eq lc($queue[$i]->{'nick'})) {
            if (/Closing Connection/) {
                print CLIENTCRAP "%R>>%n XDCC-Transfer closed";
                # Is it a canceled transfer?
                if ($queue[$i]->{'status'} eq 'canceling') {
                    $queue[$i]->{'status'} = 'cancelled';
                } elsif ($queue[$i]->{'status'} ne 'paused') {
                    # We should try again unless we paused the queue item
                    $queue[$i]->{'status'} = 'waiting';
                }
            } elsif (/Transfer Completed/i) {
                print CLIENTCRAP "%R>>%n XDCC-Transfer completed";
                # Mark the transfer as completed
                $queue[$i]->{'status'} = 'completed';
            } elsif (/You already requested that pack/i) {
                $queue[$i]->{'status'} = 'transferring';
            } elsif (/You already have that item queued/i) {
                $queue[$i]->{'status'} = 'queued';
            } elsif (/Sending (?:You|u) (?:Your Queued )?Pack/i) {
                $queue[$i]->{'status'} = 'transferring';
                print CLIENTCRAP "%R>>%n XDCC-Transfer starting";
            } elsif (/All Slots Full, Added (|you to the main )queue in position ([0-9]*)/i) {
                $queue[$i]->{'pos'} = $2;
                $queue[$i]->{'etr'} = 0;
                $queue[$i]->{'status'} = 'queued';
            } elsif (/You have been queued for ([0-9]*?) hr ([0-9]*?) min, currently in main queue position ([0-9]*?) of ([0-9]*?)\.  Estimated remaining time is ([0-9]*?) hr ([0-9]*?) min or (less|more)\./i) {
                $queue[$i]->{'pos'} = $3;
                $queue[$i]->{'etr'} = time() + (($5*60)+$6)*60;
                $queue[$i]->{'status'} = 'queued';
            } elsif (/You have been queued for ([0-9]*?) hours ([0-9]*?) minutes, currently in main queue position ([0-9]*?) of ([0-9]*?)\./i) {
                $queue[$i]->{'pos'} = $3;
                $queue[$i]->{'status'} = 'queued';
            } elsif (/You have been queued for ([0-9]*?) minutes, currently in main queue position ([0-9]*?) of ([0-9]*?)\./i) {
                $queue[$i]->{'status'} = 'queued';
                # FIXME unite somehow with regexp above
                $queue[$i]->{'pos'} = $2;
            } elsif (/It has been placed in queue slot #(\d+), it will send when sends are available/i) {
                $queue[$i]->{'pos'} = $1;
                $queue[$i]->{'status'} = 'queued';
            } elsif (/Invalid Pack Number/i) {
                $queue[$i]->{'status'} = 'invalid';
            } elsif (/The Owner Has Requested That No New Connections Are Made/i ||
                /All Slots Full,( Main)? queue of size [0-9]* is Full, Try Again Later/i ||
                /You can only have 1 transfer at a time/i ||
                /you must be on a known channel/i) {
                print CLIENTCRAP "Retrying ....\n";
                my $retry = Irssi::settings_get_int('xdccget_retry_time')*60000;
                $queue[$i]->{'status'} = 'retrying';
                $queue[$i]->{'timer'} = Irssi::timeout_add($retry, 'retry_transfer', $i);
                $queue[$i]->{'etr'} = time()+$retry/1000;
            } elsif (/must be on a known channel/i) {
                $server->command("WHOIS $nick");
                $queue[$i]->{'status'} = 'joining';
            } else { Irssi::print($_) if ($debug); }
            process_queue();
            last;
        }
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
    debugFunc ("process_queue", @_);
    my ($i, $j, $numdls);
    $numdls = 0;
    my $process;
    unless (scalar(@queue) > 0) {return 0};
    for ($i=0; $i<= $#queue; $i++) {
        debugFunc (" - Item: $i -> ".$queue[$i]{'status'});
        if ($queue[$i]{'status'} eq 'completed' ||
            $queue[$i]{'status'} eq 'cancelled') {
            push (@completed, $queue[$i]);
            my $done_file = "$config_path/xdccdone.txt";
            if (!open (DONEFILE, q{>>}, $done_file)) {
                print CLIENTCRAP "XDCCGET - Warning: Could not open file for appending done queue entry at $done_file. $!";
            } else {
                print DONEFILE $queue[$i]{net}."\t".$queue[$i]{nick}."\t".$queue[$i]{pack}."\t".$queue[$i]{filename}."\t".$queue[$i]{'status'}."\n";
                if (!close (DONEFILE)) {
                    print CLIENTCRAP "XDCCGET - Warning: Could not close file after appending done queue entry at $done_file. $!";
                }
            }
            splice (@queue, $i, 1);
        } else {
            if ($queue[$i]{'status'} eq 'waiting') {
                $process = 1;
                for ($j=0; $j<$i; $j++) {
                    if ($queue[$i]{'nick'} eq $queue[$j]{'nick'}) {
                        $process = 0;
                    }
                }
                if ($numdls >= $max_downloads) {
                    $process = 0;
                }
                if ($process) {
                    my $server = Irssi::server_find_tag($queue[$i]{'net'});
                    if (defined($server)) {
                        $server->command('MSG '.$queue[$i]{'nick'}.' '.$queue[$i]{'xdcc'}.' send '.$queue[$i]{'pack'});
                        print CLIENTCRAP "%R>>%n XDCC Requesting queue item ".($i+1);
                        $queue[$i]->{'try'}++;
                        $queue[$i]->{'status'} = 'requested';
                    }
                }
            }
            if ($queue[$i]{'status'} eq 'requested' ||
                $queue[$i]{'status'} eq 'transferring') {
                $numdls ++;
            }
        }
    }
    saveQueue();
}

sub retry_transfer {
    my ($numdls,$i);
    $numdls = 0;
    for ($i=0; $i<= $#queue; $i++) {
        if ($queue[$i]{'status'} eq 'requested' ||
            $queue[$i]{'status'} eq 'transferring') {
            $numdls ++;
        }
        if (defined ($queue[$i]->{'timer'})) {
            Irssi::timeout_remove($queue[$i]->{'timer'});
            undef ($queue[$i]->{'timer'});
            if ($queue[$i]->{'status'} eq 'retrying' && $numdls < $max_downloads) {
                $queue[$i]->{'status'} = 'waiting';
                process_queue();
            }
        }
    }
}

sub queue_pack {
    debugFunc ("queue_pack", @_);
    my ($args, $server, $witem) = @_;
    my @args = split(/ /, $args, 3);
    my $xdcc = "xdcc";
    my ($nick, $pack, $desc);
    if (ref $witem && $witem->{type} eq 'QUERY' && $args[0] =~ /^\d+$/) {
        ($nick, $pack, $desc) = ($witem->{name}, $args[0], $args[1]);
    } else {
        ($nick, $pack, $desc) = @args;
    }
    if ($desc =~ /^-xdcc=(.+?) (.+)$/) {
        $xdcc = $1;
        $desc = $2;
    }
    my $status = 'waiting';
    my $chatnet = $server->{tag};
    my %transfer = ('nick'    => $nick,
        'pack'    => $pack,
        'status'  => $status,
        'net'     => $chatnet,
        'pos'     => 0,
        'try'     => 0,
        'etr'     => 0,
        'timer'   => undef,
        'xdcc'    => $xdcc
    );
    if (defined $server->{tag} && defined $lists{lc $server->{tag}} && defined $lists{lc $server->{tag}}{lc $nick}{$_}) {
        $transfer{filename} = $lists{lc $server->{tag}}{lc $nick}{$_};
    }
    if (defined ($desc)) {
        $transfer{filename} = $desc;
    }
    push @queue, \%transfer;
    process_queue();
}

sub list_xdcc_queue {
    my $text;
    my $i = 1;
    foreach (@queue) {
        my $current = $_;
        my $botname = $current->{'nick'};
        my $ircnet = $current->{'net'};
        my $pack = $current->{'pack'};
        my $status = $current->{'status'};
        my $info = '';
        my $etr = '';
        if ($current->{'status'} eq 'queued') {
            my $time = $current->{'etr'}-time();
            my $hours = int($time / (60*60));
            my $minutes = int( ($time-($hours*60*60))/60 );
            my $seconds = int( ($time-($hours*60*60)-($minutes*60))  );

            $etr = '('.$hours.' hours, '.$minutes.' minutes and '.$seconds.' seconds remaining)' if ($current->{'etr'} > 0);
            $info = "[".$current->{'pos'}."]".' '.$etr;
        } elsif ($current->{'status'} eq 'retrying') {
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
        my $item = $queue[$_-1];
        next if (!defined($item));

        if ($item->{'status'} eq 'queued') {
            # Remove the request from the bots queue
            my $server = Irssi::server_find_tag($item->{'net'});
            $server->command('MSG '.$item->{'nick'}.' xdcc remove');
            print CLIENTCRAP "%R>>>%n Removing pack ".$_." from server queue";
            $item->{'status'} = 'canceling';
            #splice(@queue, $_,$_+1);
        } elsif ($item->{'status'} eq 'transferring') {
            $item->{'status'} = 'cancelled';
            Irssi::command('dcc close get '.$item->{'nick'});
            print CLIENTCRAP "%R>>>%n Transfer aborted";

        } else {
            debugFunc ("splice", $_);
            splice(@queue, $_-1,1);
        }
        process_queue();
    }
}

sub reset_pack {
    foreach (@_) {
        next if ($#queue < $_ || $_ < 0);
        $queue[$_-1]->{'status'} = 'waiting';
    }
    process_queue();
}

sub pause_pack {
    my $server = shift;
    foreach (@_) {
        next if ($#queue < $_ || $_ < 0);
        if ($queue[$_-1]->{'status'} eq 'queued') {
            $server->command('msg '.$queue[$_-1]->{'nick'}.' xdcc remove');
        } elsif ($queue[$_-1]->{'status'} eq 'transferring') {
            Irssi::command('dcc close get '.$queue[$_-1]->{'nick'});
        }
        $queue[$_-1]->{'status'} = 'paused';
    }
    process_queue();
}

sub list_packs ($$) {
    my ($server, $bot) = @_;
    $server->command('MSG '.$bot.' xdcc list');
    $lists{lc $server->{tag}}{lc $bot} = {};
}

sub cmd_xdccget {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);

    if ((scalar(@arg) == 0) or ($arg[0] eq '-l') or ($arg[0] eq 'stat')) {
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
    } elsif ($arg[0] eq 'reset') {
        shift @arg;
        reset_pack(@arg);
    } elsif ($arg[0] eq 'pause') {
        shift @arg;
        pause_pack($server, @arg);
    } elsif ($arg[0] eq 'help') {
        show_help();
    } elsif ($arg[0] eq 'offers') {
        shift @arg;
        show_offers(@arg);
    }
}

sub event_private_message {
    debugFunc ("event_private_message", @_);
    my ($server, $text, $nick, $address) = @_;
    event_message_irc_notice($server, $text, $nick, $address, undef);
}

sub event_no_such_nick {
    debugFunc ("event_private_message", @_);
    my ($server, $args, $sender_nick, $sender_address) = @_;
    my ($myself, $nick) = split(/ /, $args, 3);

    my $i;
    for ($i=0; $i<= $#queue; $i++) {
        if ($nick eq $queue[$i]->{'nick'}) {
            if ($queue[$i]->{'status'} eq 'requested' || $queue[$i]->{'status'} eq 'joining') {
                my $retry = Irssi::settings_get_int('xdccget_retry_time')*60000;
                $queue[$i]->{'status'} = 'retrying';
                $queue[$i]->{'timer'} = Irssi::timeout_add($retry, 'retry_transfer', $i);
                $queue[$i]->{'etr'} = time()+$retry/1000;
            }
        }
        process_queue();
    }
}

sub event_server_connected {
    my ($server) = @_;
    debugFunc ("SERVER CONNECTED: " . $server->{'tag'});

    my $i;
    for ($i=0; $i<= $#queue; $i++) {
        $queue[$i]->{'status'} = 'waiting' if (lc($queue[$i]->{'net'}) eq lc($server->{'tag'}));
    }
    process_queue();
}

sub event_server_disconnected {
    my ($server) = @_;
    debugFunc ("SERVER DISCONNECTED: " . $server->{'tag'});

    my $i;
    for ($i=0; $i<= $#queue; $i++) {
        $queue[$i]->{'status'} = 'waiting' if (lc($queue[$i]->{'net'}) eq lc($server->{'tag'}));
    }
    process_queue();
}

sub show_offers {
    my $server;
    my $channel;
    my $nick;
    my $desc;
    foreach (@_) {
        if (/^-server=(.*?)$/) {
            $server = $1;
        } elsif (/^-channel=(.*?)$/) {
            $channel = $1;
        } elsif (/^-nick=(.*?)$/) {
            $nick = $1;
        } else {
            $desc = $_;
        }
    }
    my $text;
    $text = "";
    foreach my $s (keys %offers) {
        next unless (!defined($server) || $s =~ /$server/i);
        foreach my $c (keys %{$offers{$s}}) {
            next unless (!defined($channel) || $c =~ /$channel/i);
            foreach my $n (keys %{$offers{$s}{$c}}) {
                next unless (defined($offers{$s}{$c}{$n}{'numpacks'}));
                next unless (!defined($nick) || $n =~ /$nick/i);
                my $text1 = "";
                $text1 .= "$s $c $n - #$offers{$s}{$c}{$n}{'numpacks'}, Slots: $offers{$s}{$c}{$n}{'freeslots'}/$offers{$s}{$c}{$n}{'numslots'}";
                $text1 .= ", Q: $offers{$s}{$c}{$n}{'posqueue'}/$offers{$s}{$c}{$n}{'numqueue'}" if (defined($offers{$s}{$c}{$n}{'posqueue'}));
                $text1 .= ", Min: $offers{$s}{$c}{$n}{'minspeed'}" if (defined($offers{$s}{$c}{$n}{'minspeed'}));
                $text1 .= ", Max: $offers{$s}{$c}{$n}{'maxspeed'}" if (defined($offers{$s}{$c}{$n}{'maxspeed'}));
                $text1 .= ", Rec: $offers{$s}{$c}{$n}{'recspeed'}" if (defined($offers{$s}{$c}{$n}{'recspeed'}));
                $text1 .= ", BW: $offers{$s}{$c}{$n}{'bwcurrent'}" if (defined($offers{$s}{$c}{$n}{'bwcurrent'}));
                $text1 .= ", Rec: $offers{$s}{$c}{$n}{'bwrecord'}" if (defined($offers{$s}{$c}{$n}{'bwrecord'}));
                $text1 .= ", Cap: $offers{$s}{$c}{$n}{'bwcapacity'}" if (defined($offers{$s}{$c}{$n}{'bwcapacity'}));
                $text1 .= "\n";
                my $text2 = "";
                foreach my $p (sort {$a <=> $b} keys %{$offers{$s}{$c}{$n}{'packs'}}) {
                    next unless (!defined($desc) || $offers{$s}{$c}{$n}{'packs'}{$p}{'desc'} =~ /$desc/i);
                    $text2 .= "    #$p x$offers{$s}{$c}{$n}{'packs'}{$p}{'numdl'} [$offers{$s}{$c}{$n}{'packs'}{$p}{'size'}] $offers{$s}{$c}{$n}{'packs'}{$p}{'desc'}\n";
                }
                next if (length($text2) == 0);
                $text .= $text1.$text2;
            }
        }
    }
    print CLIENTCRAP draw_box("XDCCget", $text, "offers", 1);
}

sub event_message_public {
    my ($server, $msg, $nick, $address, $target) = @_;

    if ($msg =~ /.*?\*\*.*? (\d+) packs? .*?\*\*.*?  (\d+) of (\d+) slots? open(?:, Queue: (\d+)\/(\d+))?(?:, Min: ((?:\d+|\.)+KB\/s))?(?:, Max: ((?:\d+|\.)+KB\/s))?(?:, Record: ((?:\d|\.)+KB\/s))?/i) {
        $offers{$server->{'tag'}} = {} unless (defined($offers{$server->{'tag'}}));
        $offers{$server->{'tag'}}{$target} = {} unless (defined($offers{$server->{'tag'}}{$target}));
        $offers{$server->{'tag'}}{$target}{$nick} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}));
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}{'packs'}));
        $offers{$server->{'tag'}}{$target}{$nick}{'numpacks'} = $1 if (defined($1));
        $offers{$server->{'tag'}}{$target}{$nick}{'freeslots'} = $2 if (defined($2));
        $offers{$server->{'tag'}}{$target}{$nick}{'numslots'} = $3 if (defined($3));
        $offers{$server->{'tag'}}{$target}{$nick}{'posqueue'} = $4 if (defined($4));
        $offers{$server->{'tag'}}{$target}{$nick}{'numqueue'} = $5 if (defined($5));
        $offers{$server->{'tag'}}{$target}{$nick}{'minspeed'} = $6 if (defined($6));
        $offers{$server->{'tag'}}{$target}{$nick}{'maxspeed'} = $7 if (defined($7));
        $offers{$server->{'tag'}}{$target}{$nick}{'recspeed'} = $8 if (defined($8));
    }
    if ($msg =~ /.*?\*\*.*? Bandwidth Usage .*?\*\*.*? Current: ((?:\d|\.)+KB\/s)(?:, Cap: ((?:\d|\.)+KB\/s))?(?:, Record: ((?:\d|\.)+KB\/s))?/) {
        $offers{$server->{'tag'}} = {} unless (defined($offers{$server->{'tag'}}));
        $offers{$server->{'tag'}}{$target} = {} unless (defined($offers{$server->{'tag'}}{$target}));
        $offers{$server->{'tag'}}{$target}{$nick} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}));
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}{'packs'}));
        $offers{$server->{'tag'}}{$target}{$nick}{'bwcurrent'} = $1 if (defined($1));
        $offers{$server->{'tag'}}{$target}{$nick}{'bwcapacity'} = $2 if (defined($2));
        $offers{$server->{'tag'}}{$target}{$nick}{'bwrecord'} = $3 if (defined($3));
    }

    if ($msg =~ /\.*?#(\d+).*?\s+(\d+)x\s+\[\s*?((?:\d|\.)*(?:M|K|G))\]\s+(.+)/) {
        $offers{$server->{'tag'}} = {} unless (defined($offers{$server->{'tag'}}));
        $offers{$server->{'tag'}}{$target} = {} unless (defined($offers{$server->{'tag'}}{$target}));
        $offers{$server->{'tag'}}{$target}{$nick} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}));
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}{'packs'}));
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'}{$1} = {} unless (defined($offers{$server->{'tag'}}{$target}{$nick}{'packs'}{$1}));
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'}{$1}{'numdl'} = $2;
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'}{$1}{'size'} = $3;
        $offers{$server->{'tag'}}{$target}{$nick}{'packs'}{$1}{'desc'} = $4;
    }
}

Irssi::command_bind('xdccget', \&cmd_xdccget);

loadQueue();

foreach my $cmd ('queue', 'cancel', 'list', 'help', 'stat','reset','offers', 'pause') {
    Irssi::command_bind('xdccget '.$cmd => sub {
        cmd_xdccget("$cmd ".$_[0], $_[1], $_[2]);
    });
}

Irssi::signal_add('message public', 'event_message_public');
Irssi::signal_add('message irc notice', 'event_message_irc_notice');
Irssi::signal_add("message private", "event_private_message");
Irssi::signal_add("event 401", "event_no_such_nick");
Irssi::signal_add("event connected", "event_server_connected");
Irssi::signal_add("server disconnected", "event_server_disconnected");

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /xdccget help for help';

print "Configuration files are stored in $config_path";

if ($#queue >= 0) {
    process_queue();
}
