use strict;
use vars qw($VERSION %IRSSI);
use Irssi 20020120.0250 ();
$VERSION = "3.2b";
%IRSSI = (
    authors     => 'Timo Sirainen, David Leadbeater',
    contact     => 'tss@iki.fi, dgl@dgl.cx',
    name        => 'title',
    description => 'Display configurable title as XTerm title',
    license     => 'GNU GPL',
    url         => 'http://irssi.dgl.cx/',
);

# Settings:
# title_string: The string used in the title, see below for explaination
# title_topic_length: The length to truncate the topic to (some terminals have
# problems with long titles).
# title_screen_window: (EXPERIMENTAL), sets the screen window title rather than
# the Xterm title.

# The $vars are normal Irssi vars (docs/special_vars.txt).
# $.var does some magic, adds a space at the begining and brackets around 
# the item but only if it produces output.

# Here is some examples:
# The default:
# /set title_string Irssi: [$N@$tag]$.C$.winname$.act
# Quite nice with lots of info:
# /set title_string $cumode$winname$C$.M$.act$.topic
# Nickname with usermode
# /set title_string $N(+$usermode)

# To use this with screen you need some lines in your ~/.screenrc
# termcap xterm 'hs:ts=\E]2;:fs=\007:ds=\E]2;screen\007'
# terminfo xterm 'hs:ts=\E]2;:fs=\007:ds=\E]2;screen\007'
# This probably only works if you have $TERM set to xterm.

my %act;
use IO::Handle;

sub xterm_topic {
	my($text) = @_;

	STDERR->autoflush(1);
   if(Irssi::settings_get_bool('title_screen_window')) {
      print STDERR "\033k$text\033\\";
   }else{
	   print STDERR "\033]0;$text\007";
   }
}

sub refresh_topic {
	my $title = Irssi::settings_get_str('title_string');
	$title =~ s/\$([A-Za-z.,;:]+)/special_var($1)/eg;
	xterm_topic($title);
}

sub special_var {
   my($str) = @_;

   my($begin,$end);
   if($str =~ s/^\.//) {
	  $begin = ' [';
      $end = ']';
   }else{
	  $begin = $end = '';
   }

   my $result;
   if($str eq 'topic') {
	  $result = topic_str();
   }elsif($str eq 'act') {
	  $result = act_str();
   }else{
	  my $item = ref Irssi::active_win() ? Irssi::active_win()->{active} : '';
	  $item = Irssi::active_server() unless ref $item;
	  return '' unless ref $item;

	  $result = $item->parse_special('$' . $str);
   }

   $begin = '(+', $end = ')' if $str eq 'M' && $begin;

   return $result ? $begin . $result . $end : '';
}

sub topic_str {
	my $server = Irssi::active_server();
	my $item = ref Irssi::active_win() ? Irssi::active_win()->{active} : '';

	if(ref $server && ref $item && $item->{type} eq 'CHANNEL') {
	   my $topic = $item->{topic};
       # Remove colour and bold from topic...
	   $topic =~ s/\003(\d{1,2})(\,(\d{1,2})|)//g;
	   $topic =~ s/[\x00-\x1f]//g;
	   $topic = substr($topic, 0,Irssi::settings_get_int('title_topic_length'));
	   return $topic if length $topic;
	}
	return '';
}

sub act_str {
   my @acts;
   for my $winref(keys %act) {
      # handle windows with items and not gracefully
      my $window = Irssi::window_find_refnum($winref);
      if(defined($window)) {
         for my $win ($window->items or $window) {
	          if($win->{data_level} >= 3 || $win->{data_lev} >= 3) {
	              push(@acts,$win->{name});
             } else {
		           delete($act{$winref});
             }
	       }
      } else {
		   delete($act{$winref});
	   }
   }
   return join(', ',@acts);
}

sub topic_changed {
   my($chan) = @_;
   return unless ref Irssi::active_win() &&
	  Irssi::active_win()->{active}->{type} eq 'CHANNEL';
   return unless lc $chan->{name} eq lc Irssi::active_win()->{active}->{name};

   refresh_topic();
}

sub hilight_win {
   my($win) = @_;
   return unless ref $win && $win->{data_level} >= 3;
   $act{$win->{refnum}}++;

   refresh_topic();
}

Irssi::signal_add_last('window changed', 'refresh_topic');
Irssi::signal_add_last('window item changed', 'refresh_topic');
Irssi::signal_add_last('window server changed', 'refresh_topic');
Irssi::signal_add_last('server nick changed', 'refresh_topic');
Irssi::signal_add_last('channel topic changed', 'topic_changed');
Irssi::signal_add_last('window hilight', 'hilight_win');
Irssi::signal_add_last('setup changed', 'refresh_topic');

Irssi::settings_add_str('misc', 'title_string', 'Irssi: [$N@$tag]$.C$.winname$.act');
Irssi::settings_add_int('misc', 'title_topic_length', 250);
Irssi::settings_add_bool('misc', 'title_screen_window', 0);

