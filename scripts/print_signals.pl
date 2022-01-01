# print_signals.pl — Irssi script to help with inspecting signals
#
# © 2017,2021 martin f. krafft <madduck@madduck.net>
# Released under the MIT licence.
#
### Usage:
#
# /script load print_signals
#
# and then use e.g. tail -F /tmp/irssi_signals.log outside of irssi.
#
### Settings:
#
# /set print_signals_to_file ["/tmp/irssi_signals.log"]
#   Set the file to which to log all signals and their data
#
# /set print_signals_limit_regexp [""]
#   Specify a regexp to limit the signals being captured, e.g. "^window".
#   Default is no limit.
#
# # Please note that exclude takes precedence over limit:
#
# /set print_signals_exclude_regexp ["print text|key press|textbuffer"]
#   Specify a regexp to exclude signals from being captured. Default is not to
#   fire on signals about printing text or key presses.
#
### Changelog:
#
# 2021-11-04 v1.2
# * Omit signals that cannot be enumerated
#
# 2021-09-20 v1.1
# * Unload signal handlers when script is unloaded
# * Update list of signals from upstream
#
# 2017-02-03 v1.0
#
# * Initial release.
#

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi;
use Data::Dumper;

$VERSION = '1.2';

%IRSSI = (
    authors     => 'martin f. krafft',
    contact     => 'madduck@madduck.net',
    name        => 'print signals debugger',
    description => 'hooks into almost every signal and writes the information provided to a file',
    license     => 'MIT',
    changed     => '2021-11-04'
);

Irssi::settings_add_str('print_signals', 'print_signals_to_file', '/tmp/irssi_signals.log');
Irssi::settings_add_str('print_signals', 'print_signals_limit_regexp', '');
Irssi::settings_add_str('print_signals', 'print_signals_exclude_regexp',
	'print text|key press|textbuffer|rawlog|log written');

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Pad = '     ';

sub signal_handler {
	my $signal = shift(@_);
	my $limitre = Irssi::settings_get_str('print_signals_limit_regexp');
	return unless $signal =~ qr/$limitre/;
	my $excludere = Irssi::settings_get_str('print_signals_exclude_regexp');
	return if $signal =~ qr/$excludere/;
	my @names = shift(@_);
	my @data = shift(@_);
	my $outfile = Irssi::settings_get_str('print_signals_to_file');
	my $fh;
	if (!open($fh, '>>', $outfile)) {
		Irssi::print("cannot append to log file $outfile while handling signal '$signal'");
		return;
	};
	print $fh "\n== $signal ==\n";
	print $fh Data::Dumper->Dump(@data, @names);
	close($fh);
}

# TODO: a programmatic way to extract the list of all signals from Irssi
# itself, along with descriptive names of the arguments.
# curl -s https://raw.githubusercontent.com/irssi/irssi/master/docs/signals.txt | sed -rne 's,^ ",",p'
my $signals = <<_END;
"gui exit"
"gui dialog", char *type, char *text
"send command", char *command, SERVER_REC, WI_ITEM_REC
"chat protocol created", CHAT_PROTOCOL_REC
"chat protocol updated", CHAT_PROTOCOL_REC
"chat protocol destroyed", CHAT_PROTOCOL_REC
"channel created", CHANNEL_REC, int automatic
"channel destroyed", CHANNEL_REC
"chatnet created", CHATNET_REC
"chatnet destroyed", CHATNET_REC
"commandlist new", COMMAND_REC
"commandlist remove", COMMAND_REC
"error command", int err, char *cmd
"send command", char *args, SERVER_REC, WI_ITEM_REC
"send text", char *line, SERVER_REC, WI_ITEM_REC
"command "<cmd>, char *args, SERVER_REC, WI_ITEM_REC
"default command", char *args, SERVER_REC, WI_ITEM_REC
"ignore created", IGNORE_REC
"ignore destroyed", IGNORE_REC
"ignore changed", IGNORE_REC
"log new", LOG_REC
"log remove", LOG_REC
"log create failed", LOG_REC
"log locked", LOG_REC
"log started", LOG_REC
"log stopped", LOG_REC
"log rotated", LOG_REC
"log written", LOG_REC, char *line
"module loaded", MODULE_REC, MODULE_FILE_REC
"module unloaded", MODULE_REC, MODULE_FILE_REC
"module error", int error, char *text, char *rootmodule, char *submodule
"tls handshake finished", SERVER_REC, TLS_REC
"nicklist new", CHANNEL_REC, NICK_REC
"nicklist remove", CHANNEL_REC, NICK_REC
"nicklist changed", CHANNEL_REC, NICK_REC, char *old_nick
"nicklist host changed", CHANNEL_REC, NICK_REC
"nicklist account changed", CHANNEL_REC, NICK_REC, char *account
"nicklist gone changed", CHANNEL_REC, NICK_REC
"nicklist serverop changed", CHANNEL_REC, NICK_REC
"pidwait", int pid, int status
"query created", QUERY_REC, int automatic
"query destroyed", QUERY_REC
"query nick changed", QUERY_REC, char *orignick
"window item name changed", WI_ITEM_REC
"query address changed", QUERY_REC
"query server changed", QUERY_REC, SERVER_REC
"rawlog", RAWLOG_REC, char *data
"server looking", SERVER_REC
"server connected", SERVER_REC
"server connecting", SERVER_REC, ulong *ip
"server connect failed", SERVER_REC
"server disconnected", SERVER_REC
"server quit", SERVER_REC, char *msg
"server sendmsg", SERVER_REC, char *target, char *msg, int target_type
"setup changed"
"setup reread", char *fname
"setup saved", char *fname, int autosaved
"ban type changed", char *bantype
"channel joined", CHANNEL_REC
"channel wholist", CHANNEL_REC
"channel sync", CHANNEL_REC
"channel topic changed", CHANNEL_REC
"ctcp msg", SERVER_REC, char *args, char *nick, char *addr, char *target
"ctcp msg "<cmd>, SERVER_REC, char *args, char *nick, char *addr, char *target
"default ctcp msg", SERVER_REC, char *args, char *nick, char *addr, char *target
"ctcp reply", SERVER_REC, char *args, char *nick, char *addr, char *target
"ctcp reply "<cmd>, SERVER_REC, char *args, char *nick, char *addr, char *target
"default ctcp reply", SERVER_REC, char *args, char *nick, char *addr, char *target
"ctcp action", SERVER_REC, char *args, char *nick, char *addr, char *target
"awaylog show", LOG_REC, int away_msgs, int filepos
"server nick changed", SERVER_REC
"event connected", SERVER_REC
"server cap ack "<cmd>, SERVER_REC
"server cap nak "<cmd>, SERVER_REC
"server cap new "<cmd>, SERVER_REC
"server cap delete "<cmd>, SERVER_REC
"server cap end", SERVER_REC
"server cap req", SERVER_REC, char *caps
"server sasl failure", SERVER_REC, char *reason
"server sasl success", SERVER_REC
"server event", SERVER_REC, char *data, char *sender_nick, char *sender_address
"server event tags", SERVER_REC, char *data, char *sender_nick, char *sender_address, char *tags
"event "<cmd>, SERVER_REC, char *args, char *sender_nick, char *sender_address
"default event", SERVER_REC, char *data, char *sender_nick, char *sender_address
"whois default event", SERVER_REC, char *args, char *sender_nick, char *sender_address
"server incoming", SERVER_REC, char *data
"redir "<cmd>, SERVER_REC, char *args, char *sender_nick, char *sender_address
"server lag", SERVER_REC
"server lag disconnect", SERVER_REC
"massjoin", CHANNEL_REC, GSList of NICK_RECs
"ban new", CHANNEL_REC, BAN_REC
"ban remove", CHANNEL_REC, BAN_REC, char *setby
"channel mode changed", CHANNEL_REC, char *setby
"nick mode changed", CHANNEL_REC, NICK_REC, char *setby, char *mode, char *type
"user mode changed", SERVER_REC, char *old
"away mode changed", SERVER_REC
"netsplit server new", SERVER_REC, NETSPLIT_SERVER_REC
"netsplit server remove", SERVER_REC, NETSPLIT_SERVER_REC
"netsplit new", NETSPLIT_REC
"netsplit remove", NETSPLIT_REC
"dcc ctcp "<cmd>, char *args, DCC_REC
"default dcc ctcp", char *args, DCC_REC
"dcc unknown ctcp", char *args, char *sender, char *sendaddr
"dcc reply "<cmd>, char *args, DCC_REC
"default dcc reply", char *args, DCC_REC
"dcc unknown reply", char *args, char *sender, char *sendaddr
"dcc chat message", DCC_REC, char *msg
"dcc created", DCC_REC
"dcc destroyed", DCC_REC
"dcc connected", DCC_REC
"dcc rejecting", DCC_REC
"dcc closed", DCC_REC
"dcc request", DCC_REC, char *sendaddr
"dcc request send", DCC_REC
"dcc chat message", DCC_REC, char *msg
"dcc transfer update", DCC_REC
"dcc get receive", DCC_REC
"dcc error connect", DCC_REC
"dcc error file create", DCC_REC, char *filename
"dcc error file open", char *nick, char *filename, int errno
"dcc error get not found", char *nick
"dcc error send exists", char *nick, char *filename
"dcc error unknown type", char *type
"dcc error close not found", char *type, char *nick, char *filename
"autoignore new", SERVER_REC, AUTOIGNORE_REC
"autoignore remove", SERVER_REC, AUTOIGNORE_REC
"flood", SERVER_REC, char *nick, char *host, int level, char *target
"notifylist new", NOTIFYLIST_REC
"notifylist remove", NOTIFYLIST_REC
"notifylist joined", SERVER_REC, char *nick, char *user, char *host, char *realname, char *awaymsg
"notifylist away changed", SERVER_REC, char *nick, char *user, char *host, char *realname, char *awaymsg
"notifylist left", SERVER_REC, char *nick, char *user, char *host, char *realname, char *awaymsg
"proxy client connecting", CLIENT_REC
"proxy client connected", CLIENT_REC
"proxy client disconnected", CLIENT_REC
"proxy client command", CLIENT_REC, char *args, char *data
"proxy client dump", CLIENT_REC, char *data
"gui print text", WINDOW_REC, int fg, int bg, int flags, char *text, TEXT_DEST_REC
"gui print text finished", WINDOW_REC, TEXT_DEST_REC
"complete word", GList * of char *s, WINDOW_REC, char *word, char *linestart, int *want_space
"irssi init read settings"
"exec new", PROCESS_REC
"exec remove", PROCESS_REC, int status
"exec input", PROCESS_REC, char *text
"message public", SERVER_REC, char *msg, char *nick, char *address, char *target
"message private", SERVER_REC, char *msg, char *nick, char *address, char *target
"message own_public", SERVER_REC, char *msg, char *target
"message own_private", SERVER_REC, char *msg, char *target, char *orig_target
"message join", SERVER_REC, char *channel, char *nick, char *address, char *account, char *realname
"message part", SERVER_REC, char *channel, char *nick, char *address, char *reason
"message quit", SERVER_REC, char *nick, char *address, char *reason
"message kick", SERVER_REC, char *channel, char *nick, char *kicker, char *address, char *reason
"message nick", SERVER_REC, char *newnick, char *oldnick, char *address
"message own_nick", SERVER_REC, char *newnick, char *oldnick, char *address
"message invite", SERVER_REC, char *channel, char *nick, char *address
"message invite_other", SERVER_REC, char *channel, char *invited, char *nick, char *address
"message topic", SERVER_REC, char *channel, char *topic, char *nick, char *address
"message host_changed", SERVER_REC, char *nick, char *newaddress, char *oldaddress
"message account_changed", SERVER_REC, char *nick, char *address, char *account
"message away_notify", SERVER_REC, char *nick, char *address, char *awaymsg
"keyinfo created", KEYINFO_REC
"keyinfo destroyed", KEYINFO_REC
"print text", TEXT_DEST_REC *dest, char *text, char *stripped
"print format", THEME_REC *theme, char *module, TEXT_DEST_REC *dest, formatnum_args
"print noformat", TEXT_DEST_REC *dest, char *text
"theme created", THEME_REC
"theme destroyed", THEME_REC
"window hilight", WINDOW_REC
"window hilight check", TEXT_DEST_REC, char *msg, int *data_level, int *should_ignore
"window dehilight", WINDOW_REC
"window activity", WINDOW_REC, int old_level
"window item hilight", WI_ITEM_REC
"window item activity", WI_ITEM_REC, int old_level
"window item new", WINDOW_REC, WI_ITEM_REC
"window item remove", WINDOW_REC, WI_ITEM_REC
"window item moved", WINDOW_REC, WI_ITEM_REC, WINDOW_REC
"window item changed", WINDOW_REC, WI_ITEM_REC
"window item server changed", WINDOW_REC, WI_ITEM_REC
"window created", WINDOW_REC
"window destroyed", WINDOW_REC
"window changed", WINDOW_REC, WINDOW_REC old
"window changed automatic", WINDOW_REC
"window server changed", WINDOW_REC, SERVER_REC
"window refnum changed", WINDOW_REC, int old
"window name changed", WINDOW_REC
"window history changed", WINDOW_REC, char *oldname
"window level changed", WINDOW_REC
"default event numeric", SERVER_REC, char *data, char *nick, char *address
"message irc op_public", SERVER_REC, char *msg, char *nick, char *address, char *target
"message irc own_wall", SERVER_REC, char *msg, char *target
"message irc own_action", SERVER_REC, char *msg, char *target
"message irc action", SERVER_REC, char *msg, char *nick, char *address, char *target
"message irc own_notice", SERVER_REC, char *msg, char *target
"message irc notice", SERVER_REC, char *msg, char *nick, char *address, char *target
"message irc own_ctcp", SERVER_REC, char *cmd, char *data, char *target
"message irc ctcp", SERVER_REC, char *cmd, char *data, char *nick, char *address, char *target
"message irc mode", SERVER_REC, char *channel, char *nick, char *addr, char *mode
"message dcc own", DCC_REC *dcc, char *msg
"message dcc own_action", DCC_REC *dcc, char *msg
"message dcc own_ctcp", DCC_REC *dcc, char *cmd, char *data
"message dcc", DCC_REC *dcc, char *msg
"message dcc action", DCC_REC *dcc, char *msg
"message dcc ctcp", DCC_REC *dcc, char *cmd, char *data
"gui key pressed", int key
"beep"
"gui print text after finished", WINDOW_REC, LINE_REC *line, LINE_REC *prev_line, TEXT_DEST_REC
"gui textbuffer line removed", TEXTBUFFER_VIEW_REC *view, LINE_REC *line, LINE_REC *prev_line
"otr event", SERVER_REC, char *nick, char *status
_END

my %handlers = ();

sub load {
	foreach my $sigline (split(/\n/, $signals)) {
		my ($sig, @args) = split(/, /, $sigline);
		$sig =~ y/"//d;
		next if ( $sig =~ m/<.*>/ );
		my $handler = sub { signal_handler($sig, \@args, \@_); };
		Irssi::signal_add_first($sig, $handler);
		$handlers{$sig} = $handler;
	}
}

sub UNLOAD {
	while (my ($sig, $handler) = each %handlers) {
		Irssi::signal_remove($sig, $handler);
	}
	%handlers = ();
}

load();
