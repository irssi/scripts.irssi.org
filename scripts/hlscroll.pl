use strict;
use Irssi qw(command_bind MSGLEVEL_HILIGHT);
use vars qw($VERSION %IRSSI);

# Recommended key bindings: alt+pgup, alt+pgdown:
#   /bind meta2-5;3~ /scrollback hlprev
#   /bind meta2-6;3~ /scrollback hlnext

$VERSION = '0.02';
%IRSSI = (
    authors     => 'Juerd, Eevee',
    contact	=> '#####@juerd.nl',
    name	=> 'Scroll to hilights',
    description	=> 'Scrolls to previous or next highlight',
    license	=> 'Public Domain',
    url		=> 'http://juerd.nl/site.plp/irssi',
    changed	=> 'Fri Apr 13 05:48 CEST 2012',
    inspiration => '@eevee on Twitter: "i really want irssi keybindings that will scroll to the next/previous line containing a highlight. why does this not exist"',
);

sub _hlscroll{
    my ($direction, $data, $server, $witem) = @_;
    $witem or return;
    my $window = $witem->window or return;

    my $view = $window->view;
    my $line = $view->{buffer}->{cur_line};
    my $delta = $direction eq 'prev' ? -1 : 1;

    my $linesleft = $view->{ypos} - $view->{height} + 1;
    my $scrollby = 0;  # how many display lines to scroll to the next highlight

    # find the line currently at the bottom of the screen
    while (1) {
        my $line_height = $view->get_line_cache($line)->{count};

        if ($linesleft < $line_height) {
            # found it!
            if ($direction eq 'prev') {
                # skip however much of $line is on the screen
                $scrollby = $linesleft - $line_height;
            }
            else {
                # skip however much of $line is off the screen
                $scrollby = $linesleft;
            }

            last;
        }

        $linesleft -= $line_height;

        last if not $line->prev;
        $line = $line->prev;
    }

    while ($line->$direction) {
        $line = $line->$direction;
        my $line_height = $view->get_line_cache($line)->{count};

        if ($line->{info}{level} & MSGLEVEL_HILIGHT) {
            # this algorithm scrolls to the "border" between lines -- if
            # scrolling down, add in the line's entire height so it's entirely
            # visible
            if ($direction eq 'next') {
                $scrollby += $delta * $line_height;
            }

            $view->scroll($scrollby);
            return;
        }

        $scrollby += $delta * $line_height;
    }

    if ($direction eq 'next' and not $line->next) {
        # scroll all the way to the bottom, after the last highlight
        $view->scroll_line($line);
    }
};

command_bind 'scrollback hlprev' => sub { _hlscroll('prev', @_) };
command_bind 'scrollback hlnext' => sub { _hlscroll('next', @_) };
