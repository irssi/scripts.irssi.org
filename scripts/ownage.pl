# /OWNAGE [<output to channel>]
# shows how many channels you're joined and how many in them you're op, and
# how many nicks are in those channels (not including you)

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '20071209';
%IRSSI = (
    authors     => '',
    contact     => '',
    name        => '',
    description => '',
    license     => '',
    commands    => 'ownage',
);

sub cmd_ownage {
    my $chans   = 0;
    my $opchans = 0;
    my $nicks   = 0;
    my $opnicks = 0;

    foreach my $channel ( Irssi::channels() ) {
        $chans++;
        if ( $channel->{chanop} ) {
            $opchans++;
            my @channicks = $channel->nicks();
            $nicks += ( scalar @channicks ) - 1;

            $opnicks--;    # don't count youself
            foreach my $nick (@channicks) {
                $opnicks++ if $nick->{op};
            }
        }
    }
    my ( undef, undef, $dest ) = @_;
    my $text =
      "@" . "$opchans / $chans : $nicks nicks (of which $opnicks are ops)";
    if ( $dest && ( $dest->{type} eq "CHANNEL" || $dest->{type} eq "QUERY" ) ) {
        $dest->command("msg $dest->{name} $text");
    }
    else {
        Irssi::print $text, MSGLEVEL_CLIENTCRAP;
    }
}

Irssi::command_bind( 'ownage', 'cmd_ownage' );
