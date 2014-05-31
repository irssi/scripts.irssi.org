
# by Stefan 'tommie' Tomanek
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2003020801';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'topics',
    description => 'records a topic history and locks the channel topic',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    changed     => $VERSION,
    commands     => 'topics'
);

use Irssi 20020324;
use vars qw(%topics);

sub show_help() {
    my $help = "$IRSSI{name} $VERSION
/topics
    List all topics that have been set in the current channel
/topics <num>
    Restore topic <num>
/topics lock
    Lock the current topic
/topics unlock
    Unlock the channeltopic
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("Topics", $text, "topics help", 1);
}


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

sub sig_channel_topic_changed ($) {
    my ($channel) = @_;
    my $ircnet = $channel->{server}->{tag};
    my $name = $channel->{name};
    my $data = {'topic'      => $channel->{topic}, 
                'topic_by'   => $channel->{topic_by},
		'topic_time' => $channel->{topic_time}
    };
    push @{$topics{$ircnet}{$name}{list}}, $data;
    if ($topics{$ircnet}{$name}{lock}) {
	my $topic = $topics{$ircnet}{$name}{lock}{topic};
	return if ($topic eq $channel->{topic});
	$channel->print("%B>>%n Restoring locked topic...", MSGLEVEL_CLIENTCRAP);
	$channel->command("TOPIC -- ".$topic);
    }
}

sub cmd_topics ($$$) {
    my ($args, $server, $witem) = @_;
    my @args = split / /, $args;
    if ($args[0] =~ /^\d+$/) {
	return unless (ref $witem && $witem->{type} eq 'CHANNEL');
	my $ircnet = $server->{tag};
	my $name = $witem->{name};
	if (defined $topics{$ircnet}{$name}{list}->[$args]) {
	    $witem->print("%B>>%n Restoring Topic ".$args, MSGLEVEL_CLIENTCRAP);
	    my $topic = $topics{$ircnet}{$name}{list}->[$args]->{topic};
	    $witem->command("TOPIC -- ".$topic);
	}
    } elsif ($args[0] eq 'lock') {
	return unless (ref $witem && $witem->{type} eq 'CHANNEL');
	my $ircnet = $server->{tag};
	my $name = $witem->{name};
	my $data = {'topic'      => $witem->{topic},
		    'topic_by'   => $witem->{topic_by},
		    'topic_time' => $witem->{topic_time}
	};
	$topics{$ircnet}{$name}{lock} = $data;
	$witem->print("%B>>%n %ro-m%n Topic locked", MSGLEVEL_CLIENTCRAP);
    } elsif ($args[0] eq 'unlock') {
	return unless (ref $witem && $witem->{type} eq 'CHANNEL');
	my $ircnet = $server->{tag};
	my $name = $witem->{name};
	delete $topics{$ircnet}{$name}{lock};
	$witem->print("%B>>%n %gø-m%n Topic unlocked", MSGLEVEL_CLIENTCRAP);
    } elsif ($args[0] eq 'help') {
	show_help();
    } else {
        return unless (ref $witem && $witem->{type} eq 'CHANNEL');
        my $ircnet = $server->{tag};
        my $name = $witem->{name};
	my $i = 0;
	my $text;
	foreach (@{$topics{$ircnet}{$name}{list}}) {
	    $text .= "%r[".$i."]%n ".$_->{topic_time}." (by ".$_->{topic_by}.")\n";
	    my $topic = $_->{topic};
	    $topic =~ s/%/%%/g;
	    $text .= '     "'.$topic.'"'."\n";
	    $i++;
	}
	$witem->print($_, MSGLEVEL_CLIENTCRAP) foreach (split(/\n/, draw_box('Topics', $text, $name, 1)));
    }
}

Irssi::signal_add('channel topic changed', \&sig_channel_topic_changed);
sig_channel_topic_changed($_) foreach (Irssi::channels());

Irssi::command_bind('topics', \&cmd_topics);
foreach my $cmd ('lock', 'unlock', 'help') {
    Irssi::command_bind('topics '.$cmd => sub {
			cmd_topics("$cmd ".$_[0], $_[1], $_[2]); });
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /topics help for help';
