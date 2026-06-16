use strict;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::Irc;
use Irssi::TextUI;

$VERSION = '2.00';
%IRSSI = (
   authors	=> 'John Engelbrecht - original script, dynamic resizing logic by Armin Jenewein, additional modifications by Erwin Iosef',
   contact	=> 'a@m2m.pm, erwiniosef@gmail.com, jengelbr@yahoo.com',
   name	        => 'twtopic.pl',
   description	=> 'Animated Topic bar with dynamic resizing to window width.',
   sbitems      => 'twtopic',
   license	=> 'Public Domain',
   changed	=> '2026-06-16',
   url		=> 'http://irssi.darktalker.net'."\n",
);

my $instrut = 
  ".---------------------------------------------------------.\n".
  "| 1.) shell> mkdir ~/.irssi/scripts                       |\n".
  "| 2.) shell> cp twtopic.pl ~/.irssi/scripts/              |\n".
  "| 3.) shell> mkdir ~/.irssi/scripts/autorun               |\n".
  "| 4.) shell> ln -s ~/.irssi/scripts/twtopic.pl \\          |\n".
  "|            ~/.irssi/scripts/autorun/twtopic.pl          |\n".
  "| 5.) /sbar topic remove topic                            |\n".
  "| 6.) /sbar topic remove topic_empty                      |\n".
  "| 7.) /sbar topic add -after topicbarstart                |\n".
  "|        -priority 100 -alignment left twtopic            |\n".
  "| 9.) /save                                               |\n".
  "|---------------------------------------------------------|\n".
  "|  Options:                               Default:        |\n".
  "|  /set twtopic_refresh <speed>              150          |\n".
  "|  /format twtopic_fgcolor <%%color> |Statusbar text color |\n".
  "|       (See formats.txt in docs for colors)              |\n".
  "|  (For bg, change statusbar bg color in .theme file)     |\n".
  "|  /twtopic_instruct |Print startup instructions          |\n".
  "\`---------------------------------------------------------'";

my $timeout;
my $start_pos;
my $size;
my $color;
my $topicscrollsize;
my $topic;
my @mirc_color_arr = ("\0031","\0035","\0033","\0037","\0032","\0036","\00310","\0030","\00314","\0034","\0039","\0038","\00312","\00313","\00311","\00315","\017");

# Setup timer
sub setup {
   my $time = Irssi::settings_get_int('twtopic_refresh');
   Irssi::timeout_remove($timeout) if ($timeout != 0);

   if ($time < 10) {
      print "Warning: 'twtopic_refresh' must be >= 10";
      $time=150;
      Irssi::settings_set_int('twtopic_refresh',$time);
   }
   $timeout = Irssi::timeout_add($time, 'reload' , undef);
}

# Status bar show handler
sub show {
   my ($item, $get_size_only) = @_;
   $topic = get_topic($item);
   $color = Irssi::current_theme->get_format(__PACKAGE__, 'twtopic_fgcolor');
   #Add '[,]' to both ends of topic string if you want '[ topic ]', ie($color\[$topic\]%n)
   $topic = " $color$topic%n";
   $item->default_handler($get_size_only,$topic, undef, 1);
}

sub get_topic {
    my $win = Irssi::active_win();
    # get the width of the full active window, not $item->{window}
    $size = Irssi::active_win()->{width} - 2;
    my $active = $win->{active};
    unless($active) {
	    $topic="(status)";
	    $start_pos=$size/2+4;
    }
    # $start_pos formula: (size/2 + (length($topic) + 2)/2 - 1, adjust values if needed)

    # handle CHANNEL windows
    if ($active->{type} eq "CHANNEL") {
        # use active server
        my $server = Irssi::active_server();
	unless($server){
		$topic="[no server]";
	        $start_pos=$size/2+5.5;
	}

        $topic = ($server->channel_find($active->{name}))->{topic};

        # remove mIRC color codes
        $topic =~ s/(\003\d{1,2}|\002|\001)//g;
        if($topic eq "") {
            $topic = "[No Topic]";
            $start_pos=$size/2+5;
        }
        else {
                $topicscrollsize=length($topic) + $size;
                scrolltopic($start_pos,$topicscrollsize);
        }
    }

    # handle QUERY windows
    elsif ($active->{type} eq "QUERY") {
        $topic="You are now talking to ..... ".$active->{name};
        $start_pos=$size/2 + (31+length($active->{name}))/2 - 1;
    }

    showtopic($start_pos,$size,$topic);
}

sub showtopic {
    $topic=(" " x $size) . $topic; # extra padding for scrolling
    return substr($topic, $start_pos, $size);
}

sub scrolltopic {
    if ($start_pos > $topicscrollsize) { $start_pos = 0; }
    return $start_pos+=0.5;
}

# Redraw status bar
sub reload { Irssi::statusbar_items_redraw('twtopic'); }

sub print_instrut { print $instrut; }

# Register status bar item
Irssi::statusbar_item_register('twtopic', '$0', 'show');
Irssi::signal_add('setup changed', 'setup');
Irssi::settings_add_int('tech_addon', 'twtopic_refresh', 150);
Irssi::settings_add_bool('tech_addon', 'twtopic_instruct', 1);
Irssi::theme_register(['twtopic_fgcolor' => '%W']);

setup();
Irssi::command_bind('twtopic_instruct','print_instrut');
