use strict;
use warnings;

our $VERSION = '0.1'; # dd9c3f5ff21242d
our %IRSSI = (
    authors     => 'Lars Djerf, Nei',
    contact     => 'lars.djerf@gmail.com, Nei @ anti@conference.jabber.teamidiot.de',
    name        => 'colon_emoji',
    description => 'Replace words between :...: in messages according to a text file. Was intended for Unicode Emoji on certain proprietary platforms.',
    license     => 'GPLv3',
   );

# Options
# =======
# /set colon_emoji_target net1/#chan1 net2/
# * space separated list of network/channel entries (network/ for the
#   whole network)
#
# /set colon_emoji_file filename.dat
# * the file which contains the replacements. it must be formatted
#   like this:
#
#      emojiname1   "replacement string 1"
#      emojiname2   "replacement string 2"
#
#   You can find a suitable file on
#   <http://anti.teamidiot.de/static/nei/*/Code/Irssi/>

# Usage
# =====
# after loading the script, configure the channels/networks and the
# data file. aferwards, all incoming messages will have words between
#  :...: replaced according to the file

# TODO handle outgoing messages

use File::Basename 'dirname';
use File::Spec;
use Cwd 'abs_path';
use constant ScriptFile => __FILE__;

my %netchans;
my ($lastfile, $lastfilemod);

my %emojie;

my $regex = qr/(?!)/;

sub sig_message_public {
    my ($server, $msg, $nick, $address, $channel, @x) = @_;
    if (_want_targ($server, $channel)) {
	&event_message;
    }
}

sub sig_message_private {
    my ($server, $msg, $nick, $address, @x) = @_;
    if (_want_targ($server, $nick)) {
	&event_message;
    }
}

sub event_message {
    my ($server, $msg, @rest) = @_;
    $msg =~ s/$regex/$emojie{$1}/g;
    Irssi::signal_continue($server, $msg, @rest);
}

sub sig_setup_changed {
    my @targets = split ' ', lc Irssi::settings_get_str('colon_emoji_target');
    %netchans = map { ($_ => 1) } @targets;
    my $file = Irssi::settings_get_str('colon_emoji_file');
    my $file2 = $file;
    $file2 =~ s/^~\//$ENV{HOME}\//;
    unless (File::Spec->file_name_is_absolute($file2)) {
	$file2 = File::Spec->catfile(dirname(abs_path(+ScriptFile)), $file2);
    }
    unless (defined $lastfile && $lastfile eq $file2 && ((-M $file2) // 0) >= ($lastfilemod//0)) {
	if (open my $in, '<', $file2) {
	    %emojie = ();
	    while (my $e = <$in>) {
		chomp $e;
		next if $e =~ /^>>/;
		if ($e =~ /^\s*(.*?)\s+"(.*?)"/) {
		    $emojie{$1} = $2;
		}
	    }
	    print CLIENTERROR "Warning, no emoji were found in $file" unless keys %emojie;
	}
	else {
	    print CLIENTERROR "Could not read colon_emoji_file $file: $!";
	}
	$lastfile = $file2;
	$lastfilemod = -M $file2;
	my $pat = join '|', map { quotemeta } sort { length $b <=> length $a || $b cmp $a } keys %emojie;
	$regex = length $pat ? qr/:($pat):/ : qr/(?!)/;
    }
}

sub _want_targ {
    my ($server, $target) = @_;
    return unless $server;
    my $t = $server->channel_find($target)
	|| $server->query_find($target)
	|| return;
    my $tag = lc $server->{tag};
    my $name = lc $t->{visible_name};
    my $netchan = "$tag/$name";
    return unless exists $netchans{"$tag/"} || exists $netchans{$netchan} || exists $netchans{"/$name"};
    return 1;
}

sub init {
    sig_setup_changed();
}

Irssi::settings_add_str('colon_emoji', 'colon_emoji_target', '');
Irssi::settings_add_str('colon_emoji', 'colon_emoji_file', 'emoji_def.txt');

Irssi::signal_add('setup changed' => 'sig_setup_changed');
Irssi::signal_add_first('message public' => 'sig_message_public');
Irssi::signal_add_first('message private' => 'sig_message_private');

init();
