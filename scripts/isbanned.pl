use Irssi;
use strict;
use warnings;
use bignum;
use Socket;
use vars qw($VERSION %IRSSI);

%IRSSI =
(
	name => "isbanned",
	description => "freenode-specific script that checks whether someone is banned on some channel",
	commands => "isbanned ismuted islisted isreset",
	authors => "mniip",
	contact => "mniip \@ freenode",
	license => "Public domain",
	modified => "2015-09-14"
);
$VERSION = "0.7.0";

#	Commands:
#		/isbanned <channel> <user>
#			Check whether <user> is banned on <channel>
#		/ismuted <channel> <user>
#			Check whether <user> is muted on <channel>
#		/islisted <channel> <mode> <user>
#			Check whether <user> is listed in <channel>'s
#			<mode> list (can be b, q, e, or I)
#		/isreset
#			If something screws up, this resets the state to inactive
#
#	<user> can either be a nickname, or a hostmask in the form
#		nick!ident@host#gecos$account
#	where some parts can be omitted. Strictly speaking the form is
#		[nick] ['!' ident] ['@' host] ['#' gecos] ['$' account]
#	If any part is omitted, it is assumed to be empty string, except for
#	account: if the account part is omitted the user is assumed to be
#	unidentified (as opposed to identified as empty string)
#
#	Supports all kinds of features, misfeatures, and quirks freenode uses.
#	Supports $a, $j, $r, $x, and $z extbans, and any edge cases of those.
#	Supports CIDR bans, both IPv4 and IPv6, and the misfeature by which
#	an invalid IP address is not parsed and zeroes are matched instead.
#	Supports the +ikmrS modes. Supports the RFC2812 casemapping in patterns,
#	which are, by the way, parsed without backtracking and thus effeciently.
#
#	Changelog:
#		0.6.0 (2015.01.12)
#			Ported from the hexchat script version 0.6
#
#		0.6.1 (2015.01.13)
#			Fixed a few porting issues: the original host is now included
#			in the hosts list too. Fixed IPv6 parsing. Fixed $x and $~x.
#
#		0.6.2 (2015.01.13)
#			Fixed a few warnings.
#
#		0.6.3 (2015.01.16)
#			Improve command argument parsing. Display usage on incorrect use.
#			Support multiple modes at once in islisted.
#
#		0.6.4 (2015.03.22)
#			Fix translation from python: fix bans containing the letter Z not matching
#
#		0.7.0 (2015.09.14)
#			Support trailing characters in CIDR bans.

my $active = 0;
my $user;
my $channel;
my $orig_list;
my $modes;
my @whois;
my $lists_left;
my @bans;

sub parse_ipv6_word
{
	my ($w) = @_;
	return hex $w if $w =~ /^0*[0-9a-fA-F]{1,4}$/;
	die "Invalid IPv6 word";
}

sub parse_ip
{
	my ($ip, $strict) = @_;
	if($ip =~ /:/)
	{
		if($ip =~ /::/)
		{
			my $edge = ($ip =~ /::$/) || ($ip =~ /^::/);
			$ip = $ip . "0" if $ip =~ /::$/;
			$ip = "0" . $ip if $ip =~ /^::/;
			my ($head, $tail) = split /::/, $ip, 2;
			my @headwords = split /:/, $head, 8;
			my @tailwords = split /:/, $tail, 8;
			if(@headwords + @tailwords <= ($edge ? 8 : 7))
			{
				my $result;
				eval
				{
					@headwords = map { parse_ipv6_word($_) } @headwords;
					@tailwords = map { parse_ipv6_word($_) } @tailwords;
					my @words = (@headwords, (0) x (8 - @headwords - @tailwords), @tailwords);
					$result = 0;
					for(my $i = 0; $i < 8; $i++)
					{
						$result |= $words[$i] << ((7 - $i) * 16);
					}
				};
				return $result if defined $result;
			}
		}
		else
		{
			my @words = split /:/, $ip, 8;
			if(scalar @words == 8)
			{
				my $result;
				eval
				{
					@words = map { parse_ipv6_word($_) } @words;
					$result = 0;
					for(my $i = 0; $i < 8; $i++)
					{
						$result |= $words[$i] << ((7 - $i) * 16);
					}
				};
				return $result if defined $result;
			}
		}
		die "Invalid IPv6" if $strict;
		return 0;
	}
	else
	{
		if($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/)
		{
			my ($o1, $o2, $o3, $o4) = (0 + $1, 0 + $2, 0 + $3, 0 + $4);
			return $o1 << 24 | $o2 << 16 | $o3 << 8 | $o4
				if $o1 < 256 && $o2 < 256 && $o3 < 256 && $o4 < 256;
		}
		die "Invalid IPv4" if $strict;
		return 0;
	}
}

my %char_classes =
	(
		"[" => "[\[{]",
		"{" => "[{\[]",
		"|" => "[|\\]",
		"\\" => "[\\|]",
		"]" => "[\]}]",
		"}" => "[}\]]",
		"~" => "[~^]",
		"?" => "."
	);
$char_classes{$_} = $_ foreach split //, '-_`^0123456789';
for(my $c = 0; $c <= 25; $c++)
{
	my $lc = chr($c + ord "a");
	my $uc = chr($c + ord "A");
	$char_classes{$lc} = "[$lc$uc]";
	$char_classes{$uc} = "[$uc$lc]";
}

sub match_pattern
{
	my ($string, $pattern) = @_;
	$string = "" if !defined $string;
	$pattern =~ s|[?*]+|"?" x ($& =~ tr/?/?/) . ($& =~ /\*/ ? "*" : "")|ge;

	my $last_pos = 0;
	my @pieces = split /\*/, $pattern;
	push @pieces, "" if $pattern =~ /\*$/;
	push @pieces, "" if $pattern eq "*";
	for(my $i = 0; $i < scalar @pieces; $i++)
	{
		my $regex = "";
		$regex .= "^" if !$i;
		$regex .= defined $char_classes{$_} ? $char_classes{$_} : "\\$_" for split //, $pieces[$i];
		$regex .= "\$" if $i == $#pieces;
		if((substr $string, $last_pos) =~ qr/$regex/)
		{
			$last_pos += $+[0];
		}
		else
		{
			return 0;
		}
	}
	return 1;
}

my @found_modes;
sub add_ban
{
	push @found_modes, "\x0302$_[1] $_[0]\x0F in \x0306$_[2]\x0F set by \x0310$_[3]\x0F on \x0308" . (scalar localtime $_[4]) . "\x0F"; 
}

sub analyze
{
	$active = 0;
	my ($nick, $ident, $host, $gecos, $account, $ssl) = @whois;
	@found_modes = ();
	my @hostile_modes = ();
	for my $c(split //, $modes)
	{
		push @hostile_modes, $c if $orig_list eq "b" && ($c eq "i" || ($c eq "r" && !$account) || ($c eq "S" && !$ssl));
		push @hostile_modes, $c if $orig_list eq "q" && ($c eq "m" || ($c eq "r" && !$account));
	}
	push @found_modes, ("\x0302+" . join("", @hostile_modes) . "\x0F in \x0306$channel\x0F") if(@hostile_modes);
	for my $b(@bans)
	{
		my ($ban) = split /(?<!^)\$/, $b->[0], 2;
		if($ban =~ /^\$/)
		{
			add_ban(@$b) if $ban eq '$a' && $account;
			if($ban =~ /^\$a:(.*)$/)
			{
				add_ban(@$b) if $account && nick_eq($account, $1);
			}
			add_ban(@$b) if $ban eq '$~a' && !$account;
			if($ban =~ /^\$~a:(.*)$/)
			{
				add_ban(@$b) if !$account || !nick_eq($account, $1);
			}
			add_ban(@$b) if $ban =~ /^\$~j:/;
			if($ban =~ /^\$r:(.*)$/)
			{
				add_ban(@$b) if match_pattern($gecos, $1);
			}
			if($ban =~ /^\$~r:(.*)$/)
			{
				add_ban(@$b) if !match_pattern($gecos, $1);
			}
			if($ban =~ /^\$x:(.*)$/)
			{
				for my $h(@$host)
				{
					if(match_pattern("$nick!$ident\@$h#$gecos", $1))
					{
						add_ban(@$b);
						last;
					}
				}
			}
			if($ban =~ /^\$~x:(.*)$/)
			{
				my $found = 0;
				for my $h(@$host)
				{
					if(match_pattern("$nick!$ident\@$h#$gecos", $1))
					{
						$found = 1;
						last;
					}
				}
				add_ban(@$b) if !$found;
			}
			add_ban(@$b) if $ban eq '$z' && $ssl;
			add_ban(@$b) if $ban eq '$~z' && !$ssl;
		}
		else
		{
			my ($v, $bhost) = split /@/, $ban, 2;
			my ($bnick, $bident) = split /!/, $v, 2;
			if(match_pattern($nick, $bnick) && match_pattern($ident, $bident))
			{
				my $found = 0;
				for my $h(@$host)
				{
					if(match_pattern($h, $bhost))
					{
						$found = 1;
						add_ban(@$b);
						last;
					}
				}
				if(!$found)
				{
					my ($ip, $width) = split /\//, $bhost, 2;
					if(defined $width)
					{
						$width =~ s/^([0-9]*).*/$1/g;
						$width = int("0" . $width);
						if($width > 0)
						{
							my $is_v4 = !($ip =~ /:/);
							$width = ($is_v4 ? 32 : 128) - $width;
							$width = 0 if $width < 0;
							$ip = parse_ip($ip);
							for my $h(@$host)
							{
								if(!($h =~ /:/) == $is_v4)
								{
									my $last;
									eval
									{
										my $h = parse_ip($h, 1);
										if(($ip >> $width) == ($h >> $width))
										{
											add_ban(@$b);
											$last = 1;
										}
									};
									last if $last;
								}
							}
						}
					}
				}
			} # omg so many }
		}
	}
	if(@found_modes)
	{
		if($orig_list eq "b")
		{
			Irssi::print("The following are preventing \x0310$user\x0F from joining \x0306$channel\x0F:");
		}
		elsif($orig_list eq "q")
		{
			Irssi::print("The following are preventing \x0310$user\x0F from speaking in \x0306$channel\x0F:");
		}
		else
		{
			Irssi::print("The following \x0302+$orig_list\x0F modes affect \x0310$user\x0F in \x0306$channel\x0F:");
		}
		Irssi::print($_) for(@found_modes);
	}
	else
	{
		if($orig_list eq "b")
		{
			Irssi::print("Nothing is preventing \x0310$user\x0F from joining \x0306$channel\x0F");
		}
		elsif($orig_list eq "q")
		{
			Irssi::print("Nothing is preventing \x0310$user\x0F from speaking in \x0306$channel\x0F");
		}
		else
		{
			Irssi::print("No \x0302+$orig_list\x0F modes affect \x0310$user\x0F in \x0306$channel\x0F");
		}
	}
}

sub reset
{
	$active = 0;
}

sub lookup_host
{
	my ($host) = @_;
	$host = "" if !defined $host;
	Irssi::print("\x0302Resolving <$host>");
	my @addresses = gethostbyname($host);
	if(@addresses)
	{
		@addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
		my %seen;
		@addresses = grep { !$seen{$_}++ } (@addresses, $host);
		Irssi::print("\x0302IPs: <@addresses>");
		return @addresses;
	}
	else
	{
		Irssi::print("\x0302Found nothing, will use <$host>");
		return $host;
	}
}

sub query_list
{
	my ($server, $channel, $mode) = @_;
	$server->command("quote MODE $channel");
	for my $m(split //, $mode)
	{
		$lists_left++;
		$server->command("quote MODE $channel $m");
	}
}

sub query_whois
{
	my ($server, $nick) = @_;
	$nick =~ s/\s+//g;
	$server->command("quote WHOIS $nick");
}

sub ignored
{
	Irssi::signal_stop() if $active;
}

sub nick_eq
{
	my ($n1, $n2) = @_;
	$n1 = lc $n1;
	$n1 =~ tr/[]\\/{}|/;
	$n2 = lc $n2;
	$n2 =~ tr/[]\\/{}|/;
	return $n1 eq $n2;
}

sub modes
{
	if($active)
	{
		my ($server, $data, $nick, $address) = @_;
		my @w = split / /, $data;
		Irssi::print("\x0302Channel $w[1] is +s, report may be incomplete") if $w[2] =~ /s/;
		if(nick_eq($w[1], $channel))
		{
			$modes = $w[2];
			analyze() if !$lists_left && @whois;
		}
		Irssi::signal_stop();
	}
}


sub list_entry_b { list_entry("+b", @_); }
sub list_entry_q { list_entry("+q", @_); }
sub list_entry_I { list_entry("+I", @_); }
sub list_entry_e { list_entry("+e", @_); }

sub list_entry
{
	if($active)
	{
		my ($u, $server, $data, $nick, $address) = @_;
		my @w = split / /, $data;
		splice @w, 2, 1 if $u eq "+q";
		if(nick_eq($w[1], $channel) && $w[2] =~ /^\$j:(.*)$/)
		{
			query_list($server, $1 =~ s/\$.*$//r, "b")
		}
		else
		{
			push @bans, [$w[2], $u, $w[1], $w[3], $w[4]];
		}
		Irssi::signal_stop();
	}
}

sub list_end
{
	if($active)
	{
		$lists_left--;
		analyze() if !$lists_left && @whois && $modes;
		Irssi::signal_stop();
	}
}

sub no_modes
{
	if($active)
	{
		Irssi::print("\x0304Attempted to get modes for a nickname, did you put the arguments in the wrong order?");
		if(!$modes)
		{
			$modes = "+";
		}
		else
		{
			$lists_left--;
			analyze() if !$lists_left && @whois;
		}
		Irssi::signal_stop();
	}
}

sub mode_error
{
	if($active)
	{
		Irssi::print("\x0304Something went wrong with the modes, report may be incomplete");
		if(!$modes)
		{
			$modes = "+";
			analyze() if !$lists_left && @whois;
		}
		else
		{
			$lists_left--;
			analyze() if !$lists_left && @whois;
		}
		Irssi::signal_stop();
	}
}

sub no_list
{
	if($active)
	{
		my ($server, $data, $nick, $address) = @_;
		my @w = split / /, $data;
		Irssi::print("\x0304Could not obtain modes for $w[1], report may be incomplete");
		if(nick_eq($w[1], $channel) && !$modes)
		{
			$modes = "+";
			analyze() if !$lists_left && @whois;
		}
		else
		{
			$lists_left--;
			analyze() if !$lists_left && @whois && $modes;
		}
		Irssi::signal_stop();
	}
}

my @wh;
my $ac;
my $ssl;

sub whois_start
{
	if($active)
	{
		my ($server, $data, $nick, $address) = @_;
		my @w = split / /, $data;
		@wh = ($w[1], $w[2], [lookup_host($w[3])], substr((join " ", @w[5 .. $#w]), 1));
		undef $ac;
		undef $ssl;
		Irssi::signal_stop();
	}
}

sub whois_ssl
{
	if($active)
	{
		$ssl = 1;
		Irssi::signal_stop();
	}
}

sub whois_account
{
	if($active)
	{
		my ($server, $data, $nick, $address) = @_;
		my @w = split / /, $data;
		$ac = $w[2];
		Irssi::signal_stop();
	}
}

sub whois_end
{
	if($active)
	{
		my ($server, $data, $nick, $address) = @_;
		if(@wh)
		{
			@whois = (@wh, $ac, $ssl);
			@wh = ();
			analyze() if !$lists_left && $modes;
		}
		else
		{
			Irssi::print("\x0304Whois failed, aborting!");
			$active = 0;
		}
		Irssi::signal_stop();
	}
}

sub start_search
{
	my ($server, $ch, $u, $mode) = @_;
	@whois = ();
	$orig_list = $mode;
	$channel = $ch;
	$user = $u;
	if($user =~ /[!@#\$]/)
	{
		my ($account, $rname, $host, $nick, $ident, $v);
		($v, $account) = split /\$/, $user, 2;
		($v, $rname) = split /#/, $v, 2;
		($v, $host) = split /@/, $v, 2;
		($nick, $ident) = split /!/, $v, 2;
		@whois = ($nick, $ident, [lookup_host($host)], $rname, $account, 0);
	}
	undef $modes;
	$lists_left = 0;
	@bans = ();
	$active = 1;
	query_list($server, $channel, $mode);
	query_whois($server, $user) if !@whois;
}

sub isbanned
{
	my ($arg, $server, $witem) = @_;
	if($arg =~ /^\s*(\S+)\s+(.*\S)\s*/)
	{
		my $chan = $1;
		my $user = $2;
		return start_search($server, $chan, $user, "b") if $chan ne "" && $user ne "";
	}
	Irssi::print("Usage: /isbanned <channel> <user>");
}

sub ismuted
{
	my ($arg, $server, $witem) = @_;
	my ($chan, $user) = split / /, $arg, 2;
	if($arg =~ /^\s*(\S+)\s+(.*\S)\s*/)
	{
		my $chan = $1;
		my $user = $2;
		if($chan ne "" && $user ne "")
		{
			start_search($server, $chan, $user, "q");
			query_list($server, $chan, "b");
			return;
		}
	}
	Irssi::print("Usage: /ismuted <channel> <user>");
}

sub islisted
{
	my ($arg, $server, $witem) = @_;
	my ($chan, $mode, $user) = split / /, $arg, 3;
	if($arg =~ /^\s*(\S+)\s+(\S+)\s+(.*\S)\s*/)
	{
		my $chan = $1;
		my $mode = $2;
		my $user = $3;
		$mode =~ s/\+//g;
		return start_search($server, $chan, $user, $mode) if $chan ne "" && $mode ne "" && $user ne "";
	}
	Irssi::print("Usage: /islisted <channel> <mode> <user>");
}

Irssi::signal_add("event 329", \&ignored);
Irssi::signal_add("event 276", \&ignored);
Irssi::signal_add("event 317", \&ignored);
Irssi::signal_add("event 378", \&ignored);
Irssi::signal_add("event 319", \&ignored);
Irssi::signal_add("event 312", \&ignored);
Irssi::signal_add("event 324", \&modes);
Irssi::signal_add("event 367", \&list_entry_b);
Irssi::signal_add("event 728", \&list_entry_q);
Irssi::signal_add("event 346", \&list_entry_I);
Irssi::signal_add("event 348", \&list_entry_e);
Irssi::signal_add("event 368", \&list_end);
Irssi::signal_add("event 729", \&list_end);
Irssi::signal_add("event 347", \&list_end);
Irssi::signal_add("event 349", \&list_end);
Irssi::signal_add("event 502", \&no_modes);
Irssi::signal_add("event 221", \&no_modes);
Irssi::signal_add("event 472", \&mode_error);
Irssi::signal_add("event 501", \&mode_error);
Irssi::signal_add("event 403", \&no_list);
Irssi::signal_add("event 482", \&no_list);
Irssi::signal_add("event 311", \&whois_start);
Irssi::signal_add("event 671", \&whois_ssl);
Irssi::signal_add("event 330", \&whois_account);
Irssi::signal_add("event 318", \&whois_end);
Irssi::command_bind("isbanned", \&isbanned);
Irssi::command_bind("ismuted", \&ismuted);
Irssi::command_bind("islisted", \&islisted);
Irssi::command_bind("isreset", \&reset);
