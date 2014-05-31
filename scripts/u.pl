use vars qw($VERSION %IRSSI);

use Irssi 20020120;
$VERSION = "1.2";
%IRSSI = (
    authors	=> "Michiel",
    contact	=> "michiel\@dotgeek.org",
    name	=> "List nicks in channel",
    description	=> "BitchX /u clone. Use /u <regex> to show all nicks (including ident\@host) matching regex in the current channel.",
    license	=> "GNU GPL",
    url		=> "http://otoria.freecode.nl/~michiel/u.pl",
    changed	=> "Thu Jun  3 11:04:27 CEST 2004",
);


sub cmd_u
{
	my ($data, $server, $channel) = @_;
	my @nicks;
	my $space;
	my $msg;
	my $match;
	my $nick;

	if ($channel->{type} ne "CHANNEL")
	{
		Irssi::print("You are not on a channel");
		return;
	}

	@nicks = $channel->nicks();

	$space = ' 'x50;

	foreach $nick (@nicks)
	{

		# user status?
		$msg = ($nick->{serverop} ? '[*' : '[ ');
		$msg .= ($nick->{other} ? chr($nick->{other}) : ($nick->{op} ? '@' : ($nick->{halfop} ? '%' : ($nick->{voice} ? '+' : ' '))));

		# if nick is too long, cut it off
		if (length($nick->{nick}) > 10)
		{
			$msg .= substr($nick->{nick}, 0, 10)."] ";
		}
		else # if it is too short, add some spaces
		{
			$msg .= $nick->{nick}.substr($space, 0, 10-length($nick->{nick}))."] ";
		}

		# if host is too long, cut it off
		if (length($nick->{host}) > 50)
		{
			$msg .= '['.substr($nick->{host}, 0, 50).']';
		}
		else # if it is too short, add some spaces
		{
			$msg .= '['.$nick->{host}.substr($space, 0, 50-length($nick->{host})).']';
		}
		
		$match = $nick->{nick}.'!'.$nick->{host}; # For regexp matching

		$channel->print($msg) if $match =~ /$data/i;
		
	}
}

Irssi::command_bind('u','cmd_u');
