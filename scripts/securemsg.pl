# Thanks to Geert and Karl "Sique" Siegemund on their work on the whitelist.pl script that is the basis for my work.
# 
# Supports multiple servers
#
# /set securemsg_nicks phyber etc
# nicks that are allowed to msg us (whitelist checks for a valid nick before a valid host)
#
# /set securemsg_hosts *!*@*isp.com *!ident@somewhere.org
# Hosts that are allowed to message us, space delimited
#
# /sm add nick <list of nicks>
# puts new nicks into the whitelist_nicks list
#
# /sm add host <list of hosts>
# puts new hosts into the whitelist_hosts list
#
# /sm del nick <list of nicks>
# removes the nicks from whitelist_nicks
#
# /sm del host <list of hosts>
# removes the hosts from whitelist_hosts
#
# /sm nicks
# shows the current whitelist_nicks
#
# /sm hosts
# shows the current whitelist_hosts
#
# /sm accept <nick> [message]
# accept chat from nick
#
# /sm reject <nick> [message]
# reject chat from nick
#
# /sm clear <nick>
# clears messages from nick without ignoring
#
##

use strict;
use Irssi;
use Irssi::Irc;
use Irssi::UI;
use Irssi::TextUI;


use vars qw($VERSION %IRSSI);
$VERSION = "2.1";
my $APPVERSION = "Securemsg v2.1";
%IRSSI = (
	  authors	=> "Jari Matilainen, a lot of code borrowed from whitelist.pl by David O\'Rourke and Karl Siegemund",
	  contact	=> "vague`!#irssi\@freenode on irc ",
	  name		=> "securemsg",
	  description	=> "An irssi adaptation of securequery.mrc found in the Acidmax mIRC script. :), now with multiserver support",
	  license	=> "GPLv2",
	  changed	=> "10.09.2007 11:30pm GST"
);

my $whitenick;
my $whitehost;
my $tstamp;
my %messages = ();

# A mapping to convert simple regexp (* and ?) into Perl regexp
my %htr = ( );
foreach my $i (0..255) {
    my $ch = chr($i);
    $htr{$ch} = "\Q$ch\E";
}
$htr{'?'} = '.';
$htr{'*'} = '.*';

# A list of settings we can use and change
my %types = ( 'nicks'    => 'securemsg_nicks',
	      'hosts'    => 'securemsg_hosts' );

sub lc_host($) {
    my ($host) = @_;
    $host =~ s/(.+)\@(.+)/sprintf("%s@%s", $1, lc($2));/eg;
    return $host;
}

sub timestamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my @timestamp = ($year+1900,$mon+1,$mday,$hour,$min,$sec);
    if($timestamp[1]<10) {
        $timestamp[1] = "0".$timestamp[1];
    }
    if($timestamp[2]<10) {
        $timestamp[2] = "0".$timestamp[2];
    }
    if($timestamp[3]<10) {
        $timestamp[3] = "0".$timestamp[3];
    }
    if($timestamp[4]<10) {
        $timestamp[4] = "0".$timestamp[4];
    }
    $tstamp = "$timestamp[0]/$timestamp[1]/$timestamp[2] $timestamp[3]:$timestamp[4] ";
}

# This one gets called from IRSSI if we get a private message (PRIVMSG)
sub securemsg_check {
    my ($server, $msg, $nick, $address) = @_;
    my $nicks         = Irssi::settings_get_str('securemsg_nicks');
    my $hosts         = Irssi::settings_get_str('securemsg_hosts');
    my $mmsg          = Irssi::settings_get_str('securemsg_customhold');
    my $hostmask      = "$nick!$address";
    $nick = lc($nick);
    return if $server->ignore_check($nick,"","","",MSGLEVEL_MSGS);

    # Are we already talking?
    return if $server->query_find($nick);
    return if $server->{nick} eq $nick;

    # Nicks are the easiest to handle with the least computational effort.
    # So do them before hosts and networks.
    foreach my $whitenick (split(/\s+/, "$nicks")) {
        $nick = lc($nick);
        $whitenick = lc($whitenick);
	# Simple check first: Is the nick itself whitelisted?
	return if ($nick eq $whitenick);
    }
    
    # Hostmasks are somewhat more sophisticated, because they allow wildcards
    foreach my $whitehost (split(/\s+/, "$hosts")) {
	# Allow if the hostmask matches
	return if $server->mask_match_address($whitehost,"*",$hostmask);
    }

    # stop if the message isn't from a whitelisted address
    # print a notice if that setting is enabled
    # this could flood your status window if someone is flooding you with messages

    if ((!defined $mmsg) || ($mmsg eq " ") || ($mmsg eq "")) {
        $mmsg = "Please standby for acknowledgement. I am using «$APPVERSION» for irssi. You will be notified if accepted. Until then your messages will be ignored.";
    }
    else {
	$mmsg = $mmsg." «$APPVERSION»";
    }

    $server->command("^NOTICE $nick $mmsg") if(!exists $messages{$nick}{$server->{tag}});

    #Save message from $nick
    timestamp();
    my $channel;
    my @channels = $server->channels();
    foreach my $chan (@channels) {
        if($chan->nick_find_mask($nick)) {
            $channel = $chan;
            last;
        }
    }
    
    my $tmpmsg = $tstamp."<".$nick."!".(($channel)?$channel->{name}:"none")."@".lc($server->{tag})."> ".$msg;
    push @{$messages{$nick}{lc($server->{tag})}{messages}},$tmpmsg;

    refresh_securemsg();
    Irssi::command_bind("sm accept $nick",\&cmd_accept);
    Irssi::command_bind("sm reject $nick",\&cmd_reject);
    Irssi::command_bind("sm accept $nick net",\&cmd_accept);
    Irssi::command_bind("sm reject $nick net",\&cmd_reject);
    Irssi::command_bind("sm accept $nick net ".lc($server->{tag}),\&cmd_accept);
    Irssi::command_bind("sm reject $nick net ".lc($server->{tag}),\&cmd_reject);
    Irssi::command_bind("sm show $nick",\&cmd_show);
    Irssi::command_bind("sm show $nick net ",\&cmd_show);
    Irssi::command_bind("sm show $nick net ".lc($server->{tag}),\&cmd_show);
    Irssi::signal_stop();
    return;
}

sub usage {
    print("Usage: sm add|del <nick>|<host> list of nicks/hosts | sm nicks|hosts | sm accept|reject <nick> [net <chatnet>] [message] | sm show <nick> [net <chatnet>] | sm help");
}

sub cmd_accept {
    my ($args, $active_server, $witem) = @_;
    my ($nick, $rest) = split /\s+/, $args, 2;
    my ($arg, $net);
    my $server;
    my $mmsg          = Irssi::settings_get_str('securemsg_customaccept');
    my $msg;

    if($rest =~ /^net/) {
	($arg, $net, $rest) = split /\s+/, $rest, 3;
    }

    $nick = lc($nick);
    $net = lc($net);

    if((!defined $nick) || ($nick eq "")) {
	usage;
	return;
    }

    return if(!exists $messages{$nick});

    if((!defined $rest) || ($rest eq " ") || ($rest eq "")) {
	if((!defined $mmsg) || ($mmsg eq " ") || ($mmsg eq "")) {
            $rest = "Hold on, I'm switching windows...";
	}
	else {
	    $rest = $mmsg;
	}
    }

    if(defined $net && !(($net eq " ") || ($net eq ""))) {
	foreach (keys %{$messages{$nick}}) {
	    if(lc($_) eq $net) {
		$server = Irssi::server_find_tag($_);
		last;
	    }
	}
    }
    elsif(keys(%{$messages{$nick}}) == 1) {
	foreach (keys %{$messages{$nick}}) {
	    $server = Irssi::server_find_tag($_);
	}
    }
    else {
	print("You have to specify a chatnet, for example /sm accept john net EFNet");
	return;
    }

    $server->command("MSG $nick $rest");

    my $query = $server->query_find($nick);
    $query->set_active();
    foreach $msg (@{$messages{$nick}{lc($server->{tag})}{messages}}) {
        $query->print("%B-%W!%B-%n $msg", MSGLEVEL_CLIENTCRAP);
    }

    if(keys(%{$messages{$nick}}) > 1) {
        delete $messages{$nick}{lc($server->{tag})};
    }
    else {
        delete $messages{$nick};
    }

    Irssi::command_unbind("sm accept $nick",\&cmd_accept);
    Irssi::command_unbind("sm reject $nick",\&cmd_reject);
    Irssi::command_unbind("sm accept $nick net",\&cmd_accept);
    Irssi::command_unbind("sm reject $nick net",\&cmd_reject);
    Irssi::command_unbind("sm accept $nick net ".lc($server->{tag}),\&cmd_accept);
    Irssi::command_unbind("sm reject $nick net ".lc($server->{tag}),\&cmd_reject);
    Irssi::command_unbind("sm show $nick",\&cmd_show);
    Irssi::command_unbind("sm show $nick net ",\&cmd_show);
    Irssi::command_unbind("sm show $nick net ".lc($server->{tag}),\&cmd_show);
    refresh_securemsg();
}

sub cmd_reject {
    my ($args, $active_server, $winit) = @_;
    my ($nick, $rest) = split /\s+/, $args, 2;
    my $time          = Irssi::settings_get_str('securemsg_ignoretime');
    my ($arg, $net);
    my $server;

    if($rest =~ /^net/) {
        ($arg, $net, $rest) = split /\s+/, $rest, 3;
    }

    if((!defined $time) || ($time eq "") || ($time eq " ")) {
	$time = "600";
    }

    $nick = lc($nick);
    $net = lc($net);

    if((!defined $nick) || ($nick eq "")) {
	usage;
	return;
    }

    if(defined $net && !(($net eq " ") || ($net eq ""))) {
        foreach (keys %{$messages{$nick}}) {
            if(lc($_) eq $net) {
                $server = Irssi::server_find_tag($_);
                last;
            }
        }
    }
    elsif(keys(%{$messages{$nick}}) == 1) {
        foreach (keys %{$messages{$nick}}) {
            $server = Irssi::server_find_tag($_);
        }
    }
    else {
        print("You have to specify a chatnet, for example /sm reject john net EFNet");
        return;
    }

    if((defined $rest) && !(($rest eq " ") || ($rest eq ""))) {
        $server->command("^NOTICE $nick $rest");
    }

    if(keys(%{$messages{$nick}}) > 1) {
	delete $messages{$nick}{lc($server->{tag})};
    }
    else {
	delete $messages{$nick};
    }

    Irssi::command_unbind("sm accept $nick",\&cmd_accept);
    Irssi::command_unbind("sm reject $nick",\&cmd_reject);
    Irssi::command_unbind("sm accept $nick net",\&cmd_accept);
    Irssi::command_unbind("sm reject $nick net",\&cmd_reject);
    Irssi::command_unbind("sm accept $nick net ".lc($server->{tag}),\&cmd_accept);
    Irssi::command_unbind("sm reject $nick net ".lc($server->{tag}),\&cmd_reject);
    Irssi::command_unbind("sm show $nick",\&cmd_show);
    Irssi::command_unbind("sm show $nick net ",\&cmd_show);
    Irssi::command_unbind("sm show $nick net ".lc($server->{tag}),\&cmd_show);
    $server->command("^IGNORE -time $time $nick MSGS DCCMSGS NOTICES");
    refresh_securemsg();
}

sub cmd_add {
    my ($args, $server, $witem) = @_;
    my $str = '';
    my @list = ( );
    my ($type, $rest) = split /\s+/, $args, 2;

    # What type of settings we want to change?
    if (($type eq "nick") || ($type eq "host")) {
        $type = $type."s";
    } 
    my $settings = $types{$type};

    # If we didn't get a syntactically correct command, put out an error
    if(!defined $settings && defined $type) {
        usage;
        return;
    }

    # Get the current value of the setting we want to change
    my $str = Irssi::settings_get_str($settings) if defined $settings;
    # What are we doing?
    # Add the list to the end
    $str .= " $rest";
    # Convert into an array
    @list = split /\s+/, $str;
    # Make the array unique (see Perl FAQ)
    undef my %saw;
    @list = grep(!$saw{$_}++, @list);
    # Put the array together
    $str = join ' ', @list;

    print "SecureMsg ${type}: $str";
    Irssi::settings_set_str($settings, $str);
}

sub cmd_del {
    my ($args, $server, $witem) = @_;
    my @list = ( );
    my ($type, $rest) = split /\s+/, $args, 2;

    # What type of settings we want to change?
    if (($type eq "nick") || ($type eq "host")) {
        $type = $type."s";
    }
    my $settings = $types{$type};

    # If we didn't get a syntactically correct command, put out an error
    if(!defined $settings && defined $type) {
        usage;
        return;
    }

    my $str = Irssi::settings_get_str($settings);

    # Convert the list into an array
    @list = split /\s+/, $str;
    # Escape all letters to protect the Perl Regexp special characters
    $rest =~ s/(.)/$htr{$1}/g;
    # Convert the removal list into a Perl regexp
    $rest =~ s/\s+/$|^/g;
    # Use grep() to filter out all occurences of the removal list
    $str = join(' ', grep {!/^$rest$/} @list);

    print "SecureMsg ${type}: $str";
    Irssi::settings_set_str($settings, $str);
}

sub cmd_nicks {
    print "SecureMsg nicks: ".Irssi::settings_get_str($types{nicks});
}

sub cmd_hosts {
    print "SecureMsg hosts: ".Irssi::settings_get_str($types{hosts});
}

sub cmd_help {
#    usage;
    print ( <<EOF
Commands:
SM HELP                                    - SHOWS THIS HELP
SM ADD NICK|HOST <nicks>|<hosts>           - ADDS/DELETES A SPACE SEPARATED LIST OF NICKS OR HOSTS
SM NICKS|HOSTS                             - DISPLAYS THE CURRENT WHITELISTED NICKS OR HOSTS
SM ACCEPT <nick> [net <chatnet>] [message] - ALLOWS MSG'S FROM nick
SM REJECT <nick> [net <chatnet>] [message] - DOESN'T ALLOW MESSAGES FROM nick
SM SHOW <nick> [net <chatnet>]             - SHOWS CURRENT MESSAGES FROM nick WITHOUT ACCEPTING OR REJECTING nick
EOF
    );
}

sub cmd_show {
    my ($args, $server, $witem) = @_;
    my ($nick, $rest) = split /\s+/, $args, 2;
    my ($arg, $net);
    my $server;

    if($rest =~ /^net/) {
        ($arg, $net) = split /\s+/, $rest, 2;
    }

    $net = lc($net);

    if((!defined $nick) || (!exists $messages{$nick})) {
	usage;
	return;
    }

    if(defined $net && !(($net eq " ") || ($net eq ""))) {
        foreach (keys %{$messages{$nick}}) {
            if($_ eq $net) {
                $server = Irssi::server_find_tag($_);
                last;
            }
        }
    }
    elsif(keys(%{$messages{$nick}}) == 1) {  
        foreach (keys %{$messages{$nick}}) {
            $server = Irssi::server_find_tag($_);
        }
    }
    else {
        print("You have to specify a chatnet, for example /sm reject john net EFNet");
        return;
    }

    foreach my $msg (@{$messages{$nick}{lc($server->{tag})}{messages}}) {
        print CLIENTCRAP "%B-%W!%B-%n $msg";
    }
}

sub securemsg {
    my ($item,$get_size_only) = @_;
    my $result = 0;
    my $nicks = "";
    foreach my $nick (keys %messages) {
	foreach my $tag (keys %{$messages{$nick}}) {
	    if ($nicks eq "") {
		if(keys %{$messages{$nick}} > 1) {
		    $nicks = $nick."@".$tag;
		}
		else {
		    $nicks = $nick;
		}
	    }
	    else {
		if(keys %{$messages{$nick}} > 1) {
		    $nicks = $nicks.", ".$nick."@".$tag;
		}
		else {
		    $nicks = $nicks.", ".$nick;
		}
	    }
	    $result++;
	}
    }
    if ($result ne 0) {
        $result = $result." - \%_$nicks\%_";
    }
    $item->default_handler($get_size_only, undef, $result, 0);
}

sub refresh_securemsg {
  Irssi::statusbar_items_redraw('securemsg');
}

foreach (keys(%types)) {
    Irssi::settings_add_str('SecureMsg', $types{$_}, '');
}

Irssi::settings_add_str('Securemsg', 'securemsg_customhold', '');
Irssi::settings_add_str('Securemsg', 'securemsg_customaccept', '');
Irssi::settings_add_str('Securemsg', 'securemsg_ignoretime', '');

Irssi::signal_add_first('message private', \&securemsg_check);
Irssi::statusbar_item_register('securemsg', '{sb msgs: $0-}', 'securemsg');

Irssi::command_bind 'sm' => sub {
    my ( $data, $server, $item ) = @_;
    $data =~ s/\s+$//g;
    Irssi::command_runsub ('sm', $data, $server, $item ) ;
};
Irssi::command_bind('sm add',\&cmd_add);
Irssi::command_bind('sm del',\&cmd_del);
Irssi::command_bind('sm nicks',\&cmd_nicks);
Irssi::command_bind('sm hosts',\&cmd_hosts);
Irssi::command_bind('sm show',\&cmd_show);
Irssi::command_bind('sm accept',\&cmd_accept);
Irssi::command_bind('sm reject',\&cmd_reject);
Irssi::command_bind('sm help',\&cmd_help);
Irssi::command_bind('sm add host',\&cmd_add);
Irssi::command_bind('sm add nick',\&cmd_add);
Irssi::command_bind('sm del host',\&cmd_del);
Irssi::command_bind('sm del nick',\&cmd_del);

refresh_securemsg();
