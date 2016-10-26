# This is useful with irssiproxy, to monitor irc on a separate terminal,
# or if you just want to sit back and watch conversations. It just
# lets Irssi go to the active window whenever there's any activity.
# 
# It was made to demonstrate Irssi's new Perl capabilities...
# 
# Juerd <juerd@juerd.nl>

use strict;
use vars qw($VERSION %IRSSI);

use Irssi qw(command_bind active_win);
$VERSION = '1.10';
%IRSSI = (
    authors     => 'Juerd',
    contact     => 'juerd@juerd.nl',
    name        => 'Follower',
    description => 'Automatically switch to active windows',
    license     => 'Public Domain',
    url         => 'http://juerd.nl/irssi/',
    changed     => 'Thu Mar 19 11:00 CET 2002',
);

use Irssi 20011211 qw(signal_add command);

sub sig_own {
    my ($server, $msg, $target, $orig_target) = @_;
    $server->print($target, 'Chatting with follow.pl loaded is very foolish.');
}

signal_add {
	    'window hilight'         => sub { command 'window goto active' },
	    'message own_public'     => \&sig_own,
	    'message own_private'    => \&sig_own,
	    'message irc own_action' => \&sig_own
};



=comment

    >> use Irssi 20011211 qw(signal_add command);
    
    Loads the Irssi module, requiring at least version 20011211 and telling
    it to export signal_add() and command() into our package.
    This kind of version checking came available in the 20011208-snapshot.
    Having te Irssi:: subs exported came available in the 20011211-snapshot.
    
    >> sub sig_own
    
    Warns the user: chatting while having windows switch all the time is
    foolish, because your text gets sent to whatever window has the focus
    when you press enter.
    
    >> signal_add
    
    This was exported into our package, so we can use signal_add() without the
    "Irssi::" prefix. Since the 20011207 snapshot, you can add multiple signals
    using a single add_signal(). If you want to do so, use a hash reference
    (either { foo => bar, foo2 => bar2 } or \%hash).
    
    >> sub { ... }
    >> \&subname
    
    These are references to subs(code). The first one is a reference to an
    anonymous sub, the second one refers to a named one. Anonymous code
    references allow for easy placement of oneliners :)
    Irssi understands codereferences since the 20011207 snapshot.
    Using references is better than having a string with the function name,
    imho.

=cut
