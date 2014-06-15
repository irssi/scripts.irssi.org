use Irssi 20020101.0250 ();
$VERSION = "2";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'servercomplete',
    description => 'Tab complete servers and userhosts (irc. -> irc server, user@ -> user@host). Useful for lazy ircops for /squit and so on :)',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.cx/',
);

use strict;
my %servers;

sub sig_complete {
  my ($complist, $window, $word, $linestart, $want_space) = @_;
  my $tag = $window->{active_server}->{tag};

  if($word =~ /[!*@]/) {
	 my $wi = Irssi::active_win()->{active};
	 return unless ref $wi and $wi->{type} eq 'CHANNEL';
	 my $server = $wi->{server};
	 return unless ref $server;

	 my($nick,$ident,$host) = ('','','');

	 $nick = $1 if $word =~ /([^!]+)!/ && $1;
	 $ident = $1 if $word !~ /!$/ && $word =~ /!?([^@]+)(@|$)/ && $1;
	 $host = $1 if $word =~ /@(.*)$/ && $1;

	 for my $n ($wi->nicks()) {
		next if not_wild($nick) and $n->{nick} !~ /^\Q$nick\E/i;

		my($user,$addr) = split(/@/, $n->{host});

		next if not_wild($ident) and $user !~ /^\Q$ident\E/i;
		next if not_wild($host) and $addr !~ /^\Q$host\E/i;

		if($word =~ /!/) {
		   push @$complist, get_match($n->{nick}, $nick) . '!' . get_match($user, $ident) . '@' . get_match($addr,$host);
		}else{
		   push @$complist, get_match($user, $ident) . '@' . get_match($addr,$host);
		}
	 }
  }
  
  return unless $servers{$tag};
  for (keys %{$servers{$tag}}) {
	 push @$complist, $_ if /^\Q$word\E/;
  }
}

sub get_match {
   my($match, $thing) = @_;
   return $thing eq '*' ? '*' : $match;
}

sub not_wild {
   return 0 if($_[0] eq '*' || $_[0] eq '');
   1;
}

sub add_server {
   my($tag,$data,$offset) = @_;
   $servers{$tag}{(split(/ /,$data))[$offset]} = 1;
}

Irssi::signal_add_last('complete word', 'sig_complete');

Irssi::signal_add('event 352', sub {
   my($server,$data) = @_;
   add_server($server->{tag}, $data, 4);
} );

Irssi::signal_add('event 312', sub { 
   my($server,$data) = @_;
   add_server($server->{tag}, $data, 2);
} );

Irssi::signal_add('event 364', sub { 
   my($server,$data) = @_;
   add_server($server->{tag}, $data, 1);
   add_server($server->{tag}, $data, 2);
} );

