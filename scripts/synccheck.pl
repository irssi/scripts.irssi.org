#
# usage: /sync-check [channel (servers)|-stop]
#   examples:
#		/sync-check *.de
#		/sync-check
#		/sync-check #irssi
#		/sync-check poznan.irc.pl
#		/sync-check #irssi poznan.irc.pl *.de
#		/sync-check -stop
# usage: /SET synccheck_show_all_errors [On/Off]
#

use strict;
use Irssi 20020313 ();

use vars qw($VERSION %IRSSI);
$VERSION = "0.4.9.1";
%IRSSI = (
	authors		=> 'Marcin Rozycki',
	contact		=> 'derwan@irssi.pl',
	name		=> 'sync-check',
	description	=> 'Script checking channel synchronization. Usage: /sync-check [channel (servers)|-stop]',
	license		=> 'GNU GPL v2',
	url		=> 'http://derwan.irssi.pl',
	changed		=> 'Fri Aug  9 23:00:00 CEST 2002'
);

my $synccheck = undef;

sub _print ($$$)
{
	my ($server, $level, $msg) = @_;
	if (defined $synccheck and $server and my $win = $server->channel_find($synccheck->{name})) {
		$win->print($msg, $level);
	}
}

sub _endof
{
	%$synccheck = (), undef $synccheck if (defined $synccheck);
	Irssi::print(shift) if (@_);
}

sub _new ($)
{
	_endof; my $server = shift;
	return 0 unless ($server and $server->{type} eq 'SERVER' and $server->{connected});

	$synccheck = {};
	$synccheck->{time} = time;
	$synccheck->{server} = $server->{address};
	$synccheck->{tag} = $server->{tag};
	$synccheck->{_error} = 0;
	$synccheck->{_tested} = 0;
	$synccheck->{_info} = 0;

	return $synccheck;
}

sub _setchan ($)
{
	if (defined $synccheck) {
		$synccheck->{name} = shift;
		$synccheck->{channel} = lc($synccheck->{name});
	}
}

sub _addlink ($)
{
	my $link = shift;
	if (defined $synccheck and $link and $link ne $synccheck->{server}) {
		push (@{$synccheck->{links}}, $link);
	}
}

sub _register
{
	my $server = shift; my $nick = lc(shift); my $sig = shift;
	%{$synccheck->{names}->{$server}->{$nick}} = (
		NULL		=> 1,
		op		=> 0,
		voice		=> 0,
		$sig		=> 1,
	) if (defined $synccheck);
}

sub _isregister ($$)
{
	my $server = shift; my $nick = lc(shift);
	return ((defined $synccheck and defined $synccheck->{names}->{$server}->{$nick}->{NULL}) ? 1 : 0);
}

sub _isop ($$)
{
	my $server = shift; my $nick = lc(shift);
	return ((_isregister($server, $nick) and $synccheck->{names}->{$server}->{$nick}->{op}) ? 1 : 0);
}

sub _isvoice ($$)
{
	my $server = shift; my $nick = lc(shift);
	return ((_isregister($server, $nick) and $synccheck->{names}->{$server}->{$nick}->{voice}) ? 1 : 0);
}

sub _rec2mod ($)
{
	my $hash = shift;
	my $mod = ($hash->{voice}) ? '+' : undef; $mod .= ($hash->{op}) ? '@' : undef;
	return $mod;
}

sub _reg2mod ($$)
{
	my $server = shift; my $nick = lc(shift); my $mod = undef;
	if (_isregister($server, $nick)) {
		$mod .= ($synccheck->{names}->{$server}->{$nick}->{voice}) ? '+' : ($synccheck->{names}->{$server}->{$nick}->{op}) ? '@' : '';
	}
	return $mod;
}

sub _errorregister ($$) {
	my ($nick, $sig) = @_; my $retval = 1;
	unless (Irssi::settings_get_bool("synccheck_show_all_errors")) {
		$retval = ($synccheck->{registered_errors}->{$nick}->{$sig}) ? 0 : 1;
	}
	$synccheck->{registered_errors}->{$nick}->{$sig}++;
	return $retval;
}

sub _adderror ($$$$)
{
	my ($nick, $sig, $server, $error) = @_;
	if (_errorregister $nick, $sig) {
		push @{$synccheck->{errors}->{$server}}, $error;
	}
}

sub _flusherrors ($$)
{
	my ($local, $remote) = @_;
	if ($#{$synccheck->{errors}->{$remote}} >= 0) {
		_print($local, MSGLEVEL_CLIENTCRAP, "(error in synchronization will be shown only once for the first server where the error exists, but it can exists on more servers; if you want to show all errors use /set synccheck_show_all_errors On)")
			if (!Irssi::settings_get_bool("synccheck_show_all_errors") and !$synccheck->{_info}++);
		_print($local, MSGLEVEL_CLIENTCRAP, "%RPossible channel %n%_$synccheck->{name}%_%R desynced%n%_ $synccheck->{server} <-> $remote%_:");
		for (@{$synccheck->{errors}->{$remote}})
		{
			_print($local, MSGLEVEL_CLIENTCRAP, "%_".sprintf("%03d", ++$synccheck->{_error}).".%_ $_");
		}
		delete $synccheck->{errors}->{$remote};
	}
}

sub _addnames
{
	my $remote = shift; return unless ($remote and defined $synccheck);
	for (@_)
	{
		/^\@/ and substr($_, 0, 1) = "", _register($remote, $_, "op"), next;
		/^\+/ and substr($_, 0, 1) = "", _register($remote, $_, "voice"), next;
		_register($remote, $_, "NULL");
	}
}

sub _numlinks
{
	return ((defined $synccheck and defined $synccheck->{links}) ? scalar(@{$synccheck->{links}}) : 0);
}

sub tdiff ($)
{
	my $end = time(); my $start = shift;
	return (($start and $start =~ /^\d+$/ and $start <= $end) ? ($end - $start) : 0);
}

sub _synccheck ($)
{
	my $local = shift; my $remote = ${$synccheck->{links}}[$synccheck->{_tested}++];

	_endof("End of sync-check (canceled)"), return
		if (!$synccheck or !$local->channel_find($synccheck->{name}));

	unless ($remote) {
		_print($local, MSGLEVEL_CLIENTCRAP, "%_Sync-check%_ in $synccheck->{name} ($synccheck->{tag}) %_finished in ".tdiff($synccheck->{time})." secs%_");
		_endof; return;
	}

	_print($local, MSGLEVEL_CLIENTCRAP, "%K->%n checking $synccheck->{name}: $synccheck->{server} %_<-> $remote%_ %K[%n$synccheck->{_tested}/"._numlinks."%K]%n");

	$local->redirect_event("names", 0, '', 1, undef, {
		'event 353'	=> 'redir names line',
		'event 366'	=> 'redir names done',
		'event 402',	=> 'redir names split',
		''		=> 'event empty' });

	$local->send_raw("NAMES $synccheck->{channel} :$remote");
}

sub _test
{
	my ($local, $remote) = @_;

	unless (_isregister $remote, $local->{nick}) {
		_adderror($local->{nick}, "notexsit", $remote, "%_you\'re%_ not in channel $synccheck->{name} on $remote");
		_flusherrors($local, $remote);
		delete $synccheck->{names}->{$remote};
		return;
	}

	my $channel = $local->channel_find($synccheck->{name});
	_endof, return unless $channel;

	my %orig = (); map($orig{lc($_->{nick})} = $_, $channel->nicks());

	foreach my $nick (keys %{$synccheck->{names}->{$remote}})
	{
		if (!$orig{$nick}) {
			_adderror($nick, "notexist", $remote, "%_*notexist%_($synccheck->{server}) %_!= "._reg2mod($remote, $nick)."$nick%_($remote)");
			$orig{$nick} = 0; next;
		}

		my $op = _isop $remote, $nick; my $voice = _isvoice $remote, $nick;
		if ($orig{$nick}->{op} != $op) {
			my $mod1 = _rec2mod($orig{$nick}); my $mod2 = _reg2mod($remote, $nick);
			_adderror($nick, "op", $remote, "%_$mod1%_$nick($synccheck->{server}) %_!= $mod2%_$nick($remote)");

		} elsif (!$op and $orig{$nick}->{voice} != $voice) {
			my $mod1 = _rec2mod($orig{$nick}); my $mod2 = _reg2mod($remote, $nick);
			_adderror($nick, "voice", $remote, "%_$mod1%_$nick($synccheck->{server}) %_!= $mod2%_$nick($remote)");
		}
		$orig{$nick} = 0;
	}
	delete $synccheck->{names}->{$remote};

	foreach my $nick (keys %orig)
	{
		next unless $orig{$nick};
		_adderror($nick, "notexist", $remote, _rec2mod($orig{$nick})."%_$nick%_($synccheck->{server}) %_!= *notexist%_($remote)");
	}

	_flusherrors($local, $remote);
	_synccheck $local;
}

Irssi::command_bind 'sync-check' => sub
{
	my $usage = "/%_sync-check%_ [%_channel%_ (%_servers%_)|%_-stop%_]";

	unless ($_[1] and $_[1]->{type} eq 'SERVER' and $_[1]->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	if (defined $synccheck) {
		if ($_[0] !~ /^-stop/) {
			Irssi::print("Sync-check already running " . tdiff($synccheck->{time}) . " secs ago for channel %_$synccheck->{name}%_, wait...");
		} else {
			_endof("%_Stopping%_ sync-checker for channel %_$synccheck->{name}%_ in $synccheck->{tag}")
		}
		return;
	}

	return unless _new($_[1]);

	foreach (split / +/, $_[0])
	{
		/^-yes/i and $synccheck->{_yes} = 1, next;
		/^-stop$/ and _endof("Not running any sync-checker"), return;
		/^-/ and _endof("Unknown argument: %_$_%_, usage: $usage"), return;
		if ($_[1]->ischannel($_)) { _setchan $_; } else { _addlink $_; }
	}

	if ($synccheck->{channel} and !$_[1]->channel_find($synccheck->{channel})) {
		_endof("You\'re not in channel %_$synccheck->{name}%_"); return;
	} elsif (!$synccheck->{channel}) {
		if ($_[2] and $_[2]->{type} eq 'CHANNEL') {
			_setchan $_[2]->{name};
		} else {
			_endof("Not joined to any channel"); return;
		}
	}

	if (!_numlinks) {
		_endof("Doing this is not a good idea. Add -YES option to command if you really mean it"), return unless ($synccheck->{_yes});

		_print($_[1], MSGLEVEL_CLIENTCRAP, "Checking for %_links%_ from %_$synccheck->{server}%_ in %_$synccheck->{tag}%_, wait...");
		$_[1]->redirect_event('links', 0, '', 1, undef, {
			'event 364'	=> 'redir links line',
			'event 365'	=> 'redir links done',
			''		=> 'event empty' });
		$_[1]->send_raw('LINKS :*');

	} else {
		if (_numlinks) {
			_print($_[1], MSGLEVEL_CLIENTCRAP, "%_Checking channel $synccheck->{name} synchronization%_ in: $synccheck->{server} %_<->%_ @{$synccheck->{links}}. This will take a while..");
			_synccheck $_[1];
		}
	}
};

Irssi::Irc::Server::redirect_register(
	"links", 0, 0,
	{ "event 364" => 1, },
	{ "event 402" => 1, "event 263" => 1, "event 365" => 1, },
	undef,
);

Irssi::Irc::Server::redirect_register(
	"names", 0, 0,
	{ "event 353" => 1, },
	{ "event 366" => 1,
	  "event 402" => 1, },
	undef,
);

Irssi::signal_add 'redir links line' => sub {
	$_[1] =~ /(.*) (.*) (.*) :(.*)/;
	_addlink $2;
};

Irssi::signal_add 'redir links done' => sub {
	if (_numlinks) {
		_print($_[0], MSGLEVEL_CLIENTCRAP, "%_Checking channel $synccheck->{name} synchronization%_ in: $synccheck->{server} %_<->%_ @{$synccheck->{links}}. This will take a while..");
		_synccheck $_[0];
	}
};

Irssi::signal_add 'redir names line' => sub {
	$_[1] =~ /(.*) (.*) :(.*)/;
	_addnames($_[2], split(" ", $3)) if (defined $synccheck and lc($2) eq $synccheck->{channel});
};

Irssi::signal_add 'redir names done' => sub
{
	$_[1] =~ /(.*) (.*) :(.*)/;
	_test($_[0], $_[2]) if (defined $synccheck and lc($2) eq $synccheck->{channel});;
};

Irssi::signal_add 'redir names split' => sub
{
	$_[1] =~ /(.*) (.*) :(.*)/;
	_print($_[0], MSGLEVEL_CLIENTCRAP, "%K->%n%_ $2%_: cannot find link (".lc($3)."), skipping");
	_synccheck $_[0];
};

Irssi::settings_add_bool('misc', 'synccheck_show_all_errors', 0);

