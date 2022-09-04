use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '1.00';
%IRSSI = (
    authors     => 'Pascal Hakim',
    contact     => 'pasc@redellipse.net',
    name        => 'topic-diff',
    description => 'This script shows you changes in the topic. ',
    license     => 'GPL'
);

my %topics;

sub new_channel {
    my ($channel) = @_;
    $topics{$channel->{server}->{tag}."_".$channel->{name}} = $channel->{topic};
}

sub new_topic {
    my ($server, $channel, $topic, $user, $real) = @_;
    my $i;
    my $diff;
    my $i = 0;
    my $j = 0;
    my $k = 0;
    
#    $server->print ($channel, $server->{tag});

    if ($topics{$server->{tag}."_".$channel}) {
	$topics{$server->{tag}."_".$channel} =~ s/^ +| +$//g;
	$topic =~ s/^ +| +$//g;
	my @original = split /\s*\|\s*|\s+-\s+/, $topics{$server->{tag}."_".$channel};
	my @modified = split /\s*\|\s*|\s+-\s+/, $topic;
	
	
      outer: while( $i <= $#original) {
	  if ($j <= $#modified && $original[$i] eq $modified[$j]) {
	      $modified[$j] = '';
	      $i += 1;
	      $j += 1;
	      next;
	      
	  }  else {
	      # First two don't match, check the rest of the list
	      for ($k = $j ; $k <= $#modified; $k++) {
		  if ($modified[$k] eq $original[$i])
		  {       
		      $modified[$k] = '';
		      $i += 1;
		      next outer;
		  }
	      }
	      $diff = ($diff ? $diff." | " : "").$original[$i];
	      $i += 1;
	  }
      }
	
	
	if ($diff ne '') { $server->print ($channel, "Topic: -: ".$diff);}
	
	$diff = join " | ", (grep {$_ ne ''} @modified);

	if ($diff ne '') { $server->print ($channel, "Topic: +: ".$diff);}
	
    }
    $topics{$server->{tag}."_".$channel} = $topic;

}


# Start by reading all the channels currently opened, and recording their topic

my @channels = Irssi::channels () ;

foreach my $channel (@channels) {
	$topics{$channel->{server}->{tag}."_".$channel->{name}} = $channel->{topic};
}

# Topic has changed
Irssi::signal_add 'message topic' => \& new_topic;

# We've joined a new channel
Irssi::signal_add 'channel joined' => \& new_channel;
