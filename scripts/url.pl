# $Id: url.pl,v 1.52 2002/11/21 06:04:52 jylefort Exp $

use Irssi 20020121.2020 ();
$VERSION = "0.54";
%IRSSI = (
	  authors     => 'Jean-Yves Lefort',
	  contact     => 'jylefort\@brutele.be, decadix on IRCNet',
	  name        => 'url',
	  description => 'An URL grabber for Irssi',
	  license     => 'BSD',
	  url         => 'http://void.adminz.be/',
	  changed     => '$Date: 2002/11/21 06:04:52 $ ',
);

# description:
#
#	url.pl grabs URLs in messages and allows you to open them on the fly,
#	or to write them in a HTML file and open that file.
#
# /set's:
#
#	url_grab_level
#
#		message levels to take in consideration
#		example: PUBLICS ACTIONS
#
#	url_redundant
#
#		whether to grab same URLs multiple times or not
#		example: ON
#
#	url_verbose_grab
#
#		whether to grab verbosely or not
#		example: OFF
#
#	url_hilight
#
#		whether to hilight the URLs in the text or not
#		example: OFF
#
#	url_index_color
#
#		hilight index color (mirc color string)
#
#	url_color
#
#		hilight URL color (mirc color string)
#
#	browse_command
#
#		a command used to open URLs
#		%u will be replaced by the URL
#		example: galeon %u &
#
#	url_file
#
#		where to write the URL list
#		example: ~/.irssi-urls.html
#
# commands
#
#	/URL [-clear|<number>]
#
#		-clear will clear the URL list.
#
#		<number> will open the specified URL.
#
#		If no arguments are specified, a HTML file containing all
#		grabbed URLs will be written and opened.
#
# changes:
#
#	2002-11-21	release 0.54
#			* added a DTD to the generated HTML file, suggested
#			  by Hugo Haas <hugo@larve.net>
#
#	2002-11-19	release 0.53
#			* eh yes, once again a better regexp by
#			  Hugo Haas <hugo@larve.net>
#
#	2002-11-06	release 0.52
#			* yet another regexp correction, again by
#			  Hugo Haas <hugo@larve.net>
#
#	2002-10-23	release 0.51
#			* URI regexp corrected by Hugo Haas <hugo@larve.net>
#
#	2002-09-26	release 0.50
#			* entirely rewritten; the previous template bloatness
#			  has been dropped to get back to a simpler concept
#
#	2002-07-04	release 0.47
#			* signal_add's uses a reference instead of a string
#
#	2002-03-11	release 0.46
#			* fixed an oblivion in the documentation
#
#	2002-02-14	release 0.45
#			* replaced theme capability by /set url_color,
#			  fixing a bug in the URL hilighting
#
#	2002-02-09	release 0.44
#			* 0.43 didn't grabbed anything: fixed
#
#	2002-02-09	release 0.43
#			* url_hilight was _still_ causing an infinite loop
#			  under certain conditions: fixed
#			* URLs found at the start of a message were
#			  hilighted wrongly: fixed
#
#	2002-02-09	release 0.42
#			* if url_hilight was enabled, an infinite loop was
#			  caused while printing the hilighted message: fixed
#
#	2002-02-08	release 0.41
#			* safer percent substitutions
#			* improved URL regexp
#
#	2002-02-08	release 0.40
#			* added /URL -create command
#			* added url_hilight setting
#
#	2002-02-01	release 0.34
#			* more precise URL regexp
#
#	2002-02-01	release 0.33
#			* added /URL - command
#			* added url_redundant setting
#
#	2002-02-01	release 0.32
#			* some little improvements made in the URL regexp
#
#	2002-01-31	release 0.31
#			* oops, '<@idiot> I am really stupid' was grabbed coz
#			  the '@' mode char trigerred the email regexp
#
#	2002-01-31	release 0.30
#			* major update: not HTML-oriented anymore; can generate
#			  any type of text file by the use of template files
#
#	2002-01-28	release 0.23
#			* changes in url_item and url_item_timestamp_format
#			  settings will now be seen immediately
#			* "Added item #n in URL list" is now printed after
#			  the grabbed message
#
#	2002-01-28	release 0.22
#			* messages are now saved as they were printed in irssi
#			* removed %n format of url_item
#
#	2002-01-27	release 0.21
#			* uses builtin expand
#
#	2002-01-27	release 0.20
#			* added a %s format to url_item
#			* changed the %d format of url_page to %s
#			* added url_{page|item}_timestamp_format settings
#			* reworked the documentation
#
#	2002-01-25	release 0.12
#			* added url_verbose_grab_setting
#	
#	2002-01-24	release 0.11
#			* now handles actions correctly
#
#	2002-01-23	initial release
#
# todo:
#
#	* also hilight redundant URLs
#	* open URLs with alternate programs
#	* add a 'url_grab_own_messages' setting

use strict;
use POSIX qw(strftime);

use constant MSGLEVEL_NO_URL => 0x0400000;

my @items;

# -verbatim- import expand
sub expand {
  my ($string, %format) = @_;
  my ($len, $attn, $repl) = (length $string, 0);
  
  $format{'%'} = '%';

  for (my $i = 0; $i < $len; $i++) {
    my $char = substr $string, $i, 1;
    if ($attn) {
      $attn = undef;
      if (exists($format{$char})) {
	$repl .= $format{$char};
      } else {
	$repl .= '%' . $char;
      }
    } elsif ($char eq '%') {
      $attn = 1;
    } else {
      $repl .= $char;
    }
  }
  
  return $repl;
}
# -verbatim- end

sub print_text {
  my ($textdest, $text, $stripped) = @_;
  
  if (! ($textdest->{level} & MSGLEVEL_NO_URL)
      && (Irssi::level2bits(Irssi::settings_get_str('url_grab_level'))
	  & $textdest->{level})
      && ($stripped =~ /[a-zA-Z0-9+-.]+:\/\/[^ \t\<\>\"]+/o)) {
    
    if (! Irssi::settings_get_bool('url_redundant')) {
      foreach (@items) { return if ($_->{url} eq $&) }
    }
    
    push @items,
      {
       time => time,
       target => $textdest->{target},
       pre_url => $`,
       url => $&,
       post_url => $'
      };

    if (Irssi::settings_get_bool('url_hilight')) {
      my $url_pos = index $text, $&;
      $textdest->{level} |= MSGLEVEL_NO_URL;
      Irssi::signal_emit('print text', $textdest,
			 substr($text, 0, $url_pos) .
			 Irssi::settings_get_str('url_index_color') . @items . ':' .
			 Irssi::settings_get_str('url_color') . $& . '' .
			 substr($text, $url_pos + length $&),
			 $stripped);
      Irssi::signal_stop();
    }
    
    Irssi::print('Added item #' . @items . ' to URL list')
	if Irssi::settings_get_bool('url_verbose_grab');
  }
}

sub write_file {
  my $file = shift;

  open(FILE, ">$file") or return $!;

  print FILE <<'EOF' or return $!;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <title>IRC URL list</title>
  </head>
  <body>
    <center>
      <table border="1" cellpadding="5">
	<caption>IRC URL list</caption>
	<tr><th>time<th>target<th>message</tr>
EOF

  foreach (@items) {
    my $timestamp = strftime('%c', localtime $_->{time});
    print FILE "	<tr><td>$timestamp<td>$_->{target}<td>$_->{pre_url}<a href=\"$_->{url}\">$_->{url}</a>$_->{post_url}</tr>\n" or return $!;
  }
  
  print FILE <<'EOF' or return $!;
      </table>
    </center>
    <hr>
    <center><small>Generated by url.pl</small>
  </body>
</html>
EOF

  close(FILE) or return $!;

  return undef;
}

sub url {
  my ($args, $server, $item) = @_;
  my ($file) = glob Irssi::settings_get_str('url_file');
  my $command = Irssi::settings_get_str('browse_command');

  if ($args ne '') {
    if (lc $args eq '-clear') {
      @items = ();
      Irssi::print('URL list cleared');
    } elsif ($args =~ /^[0-9]+$/) {
      if ($args > 0 && $items[$args - 1]) {
	system(expand($command, 'u', $items[$args - 1]->{url}));
      } else {
	Irssi::print("URL #$args not found");
      }
    } else {
      Irssi::print('Usage: /URL [-clear|<number>]', MSGLEVEL_CLIENTERROR);
    }
  } else {
    if (@items) {
      my $error;
      if ($error = write_file($file)) {
	Irssi::print("Unable to write $file: $error", MSGLEVEL_CLIENTERROR);
      } else  {
	system(expand($command, 'u', $file));
      }
    } else {
      Irssi::print('URL list is empty');
    }
  }
}

Irssi::settings_add_str('misc', 'url_grab_level',
			'PUBLIC TOPICS ACTIONS MSGS DCCMSGS');
Irssi::settings_add_bool('lookandfeel', 'url_verbose_grab', undef);
Irssi::settings_add_bool('lookandfeel', 'url_hilight', 1);
Irssi::settings_add_str('lookandfeel', 'url_index_color', '08');
Irssi::settings_add_str('lookandfeel', 'url_color', '12');
Irssi::settings_add_bool('misc', 'url_redundant', 0);
Irssi::settings_add_str('misc', 'browse_command',
			'galeon-wrapper %u >/dev/null &');
Irssi::settings_add_str('misc', 'url_file', '~/.irc_url_list.html');

Irssi::signal_add('print text', \&print_text);

Irssi::command_bind('url', \&url);
