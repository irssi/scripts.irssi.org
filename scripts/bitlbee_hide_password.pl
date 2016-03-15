use strict;
use warnings;
use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Ævar Arnfjörð Bjarmason',
    contact     => 'avarab@gmail.com',
    name        => 'bitlbee_hide_password.pl',
    description => 'Hide your REGISTER and IDENTIFY password lines in &bitlbee from screen & logs ',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.org & https://github.com/avar/dotfiles/blob/master/.irssi/scripts/bitlbee_hide_password.pl',
);

# HOWTO:
#
#   /load bitlbee_hide_password.pl
#
# When you're using Bitlbee and do either:
#
#    REGISTER <password>
#
# or:
#
#    IDENTIFY <password>
#
# Your password will be shown on screen, and more importantly logged
# in your logfiles. This extension intercepts these commands in your
# &bitlbee channel and hides it from screen & logs.
#
# Note: You can avoid the password going into the log without this
# plugin by doing:
#
#    IDENTIFY
#    /OPER
#
# But this script also makes sure that your REGISTER commands will be
# hidden, and of course "IDENTIFY <password>" commands if you ever
# forget to IDENTIFY with /OPER.

sub msg_intercept_bitlbee_password_lines {
    my ($tdest, $data, $stripped) = @_;

    # The $tdest object has various other things, like ->{target},
    # ->{window} (object) etc.
    my $server = $tdest->{server};

    # Some events just have ->{window} and no ->{server}, we can
    # ignore those
    return unless $server;

    # We only care about the &bitlbee control channel
    my $target = $tdest->{target};
    return unless $target eq '&bitlbee';

    # We're matching against $stripped but replacing both because the
    # $data thing is escaped and much harder to match against.
    if ($stripped =~ /^<.?[^>]+> (?:register|identify) .+/si) {
        s/(identify|register) .+/$1 <password stripped by $IRSSI{name}>/i for $data, $stripped;
        Irssi::signal_continue($tdest, $data, $stripped);
    }
}

Irssi::signal_add_first('print text', 'msg_intercept_bitlbee_password_lines');
