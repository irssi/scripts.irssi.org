# $Id: users.pl,v 1.22 2003/01/11 14:54:35 jylefort Exp $

use strict;
use Irssi 20020121.2020 ();
use vars qw($VERSION %IRSSI);
$VERSION = "2.3";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCnet',
	  name        => 'users',
	  description => 'Implements /USERS',
	  license     => 'BSD',
	  changed     => '$Date: 2003/01/11 14:54:35 $ ',
);

# usage:
#
#	/USERS [<orderstring>]
#
#		<orderstring> is an optional string
#		whose format is described below.
#
# /set's:
#
#	users_sort_order
#
#		A sort order string which will be used to complete
#		the order string given as a parameter to /USERS.
#
#		Example: /set users_sort_order mnha
#
#			Command		Resulting order
#
#			/USERS		mnha
#			/USERS an	anmh
#
# sort order string format:
#
#	An order string must be composed by one or more characters from
#	the following set:
#
#		m	server and channel mode
#		n	nickname
#		h	user@hostname
#		a	away state
#
# /format's:
#
#	users		list header
#			$0	channel name
#
#	users_nick	nick
#			$0	* if IRC operator
#			$1	@ if channel operator
#			$2	% if half channel operator
#			$3	+ if voiced
#			$4	a if marked away
#			$5	nickname
#			$6	user@hostname
#
#	endofusers	end of list
#			$0	channel name
#			$1	number of nicks
#			$2	number of IRC operators
#			$3	number of channel operators
#			$4	number of half channel operators
#			$5	number of voiced
#			$6	number of marked away
#
# changes:
#
#	2003-01-11	release 2.3
#			* nick count was wrong
#
#	2003-01-09	release 2.2
#			* command char independed
#
#	2003-01-09	release 2.1
#			* minor oblivion fix
#
#	2003-01-09	release 2.0
#			* /USERS accepts a sort order argument
#			* added /set users_sort_order
#			* shows away state
#
#	2002-07-04	release 1.01
#			* command_bind uses a reference instead of a string
#
#	2002-04-25	release 1.00
#			* uses '*' instead of 'S' for IRC operators
#
#	2002-04-12	release 0.13
#			* added support for ircops
#			* changed theme
#
#	2002-01-28	release 0.12
#			* added support for halfops
#
#	2002-01-28	release 0.11
#
#	2002-01-23	initial release

### sort algorithms table #####################################################

my %cmp = (
	   m => sub { get_mode_weight($_[1]) cmp get_mode_weight($_[0]) },
	   n => sub { lc $_[0]->{nick} cmp lc $_[1]->{nick} },
	   h => sub { lc $_[0]->{host} cmp lc $_[1]->{host} },
	   a => sub { $_[1]->{gone} cmp $_[0]->{gone} }
	  );

### support functions #########################################################

sub get_mode_weight
{
  my ($nick) = @_;

  return ($nick->{serverop} * 4) + ($nick->{op} * 3) + ($nick->{halfop} * 2) + $nick->{voice};
}

sub nick_cmp
{
  my ($this, $that, @order) = @_;
  my $sort;
  
  foreach (@order)
    {
      $sort = &{$cmp{$_}}($this, $that);
      
      if ($sort)
	{
	  return $sort;
	}
    }

  return $sort;
}

sub validate_order
{
  my @order = @_;

  foreach (@order)
    {
      if (! exists($cmp{$_}))
	{
	  return "unknown character '$_'";
	}
    }
  
  return undef;
}

sub get_order
{
  my ($string) = @_;
  my @order;
  my @default;
  my $error;
  my %has;

  @order = split(//, $string);
  @default = split(//, Irssi::settings_get_str("users_sort_order"));

  $error = validate_order(@default);
  if (defined $error)
    {
      return "unable to validate users_sort_order: $error";
    }
  
  $error = validate_order(@order);
  if (defined $error)
    {
      return "unable to validate given order: $error";
    }

  foreach (@order)
    {
      $has{$_} = 1;
    }
  
  foreach (@default)
    {
      if (! exists($has{$_}))
	{
	  push(@order, $_);
	}
    }
  
  return (undef, @order);
}

### /users ####################################################################

sub users
{
  my ($args, $server, $item) = @_;
  
  if ($item && $item->{type} eq "CHANNEL")
    {
      my $error;
      my @order;
      my $window;
      my @nicks;

      my $serverop_count = 0;
      my $chanop_count = 0;
      my $halfop_count = 0;
      my $voice_count = 0;
      my $away_count = 0;

      ($error, @order) = get_order($args);
      
      if (defined $error)
	{
	  Irssi::print("Unable to compute sort order: $error", MSGLEVEL_CLIENTERROR);
	  return;
	}
      
      Irssi::command('WINDOW NEW HIDDEN');
      
      $window = Irssi::active_win();
      $window->set_name("U:$item->{name}");
      $window->printformat(MSGLEVEL_CRAP, "users", $item->{name});
      
      @nicks = $item->nicks();
      @nicks = sort { nick_cmp($a, $b, @order) } @nicks;
      
      foreach (@nicks)
	{
	  my $serverop;
	  my $chanop;
	  my $halfop;
	  my $voice;
	  my $away;

	  $serverop = $_->{serverop} ? '*' : '.';
	  $chanop = $_->{op} ? '@' : '.';
	  $halfop = $_->{halfop} ? '%' : '.';
	  $voice = $_->{voice} ? '+' : '.';
	  $away = $_->{gone} ? 'a' : '.';

	  $serverop_count++ if ($_->{serverop});
	  $chanop_count++ if ($_->{op});
	  $halfop_count++ if ($_->{halfop});
	  $voice_count++ if ($_->{voice});
	  $away_count++ if ($_->{gone});

	  $window->printformat(MSGLEVEL_CRAP, "users_nick",
			       $serverop, $chanop, $halfop, $voice, $away,
			       $_->{nick}, $_->{host});
	}
      
      $window->printformat(MSGLEVEL_CRAP, "endofusers", $item->{name},
			   scalar @nicks, $serverop_count, $chanop_count,
			   $halfop_count, $voice_count, $away_count);
    }
}

### initialization ############################################################

Irssi::theme_register([
		       "users", '{names_users Users {names_channel $0}}',
		       "users_nick", '{hilight $0$1$3$4}  $[9]5  $[50]6',
		       "endofusers", '{channel $0}: Total of {hilight $1} nicks, {hilight $2} IRC operators, {hilight $3} channel operators, {hilight $5} voiced, {hilight $6} marked away',
		      ]);

Irssi::settings_add_str("misc", "users_sort_order", "mnha");

Irssi::command_bind("users", \&users);
