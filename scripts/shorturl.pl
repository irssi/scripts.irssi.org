#!/usr/bin/perl -w
# This Irssi script automatically converts incoming http/https links into shorter "tinyurl" style links
#
# Irssi /set Options
# you can view your current settigns by running "/set shorturl" in Irssi
#
# /set shorturl_debug <on|off>           -- (off) if you have a problem try turning this on to debug
# /set shorturl_send_to_channel <on|off> -- (off) send the converted tinyurl publicly to everyone in your channels
# /set shorturl_chans <"#channel1, #channel2, etc"> -- Channels to automatically convert. Empty Defaults to all
# /set shorturl_min_url_length <35> -- (35) How long a url has to be to trigger automatic url shortening
#
# Optional manual usage is
# /shorturl http://yourlongurl.com/blahblahblah

# No user servicable parts below this line :D
#--------------------------------------------------------------------- 
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "20090904"; # Fixed and enhanced by tsaavik (dave000@hellspark.com)
%IRSSI = (
	authors					=>	"eo, tsaavik",
	contact					=>	'irssi@eosin.org, dave001@hellspark.com',
	name						=>	"shorturl.pl",
	description	   		=>	"Private/Public url reduction script.",
	license					=>	"GPLv2",
	changed					=>	"$VERSION"
);

use Irssi;
use Irssi::Irc;
#
# If you dont have either of these,
# I suggest: perl -MCPAN -e 'install "Bundle::LWP" '
# or whatever perl module install method you find
# suitable.
use LWP::Simple;
use LWP::UserAgent;

# Each one of these have different methods of 
# getting a url back. So dont go adding any 
# others unless you wish to write in the retrieval
# code for it. Or email me. -
my @lookups = ("tinyurl", "metamark");

#these are overwritten by irssi settings via setuphandler()
my ($min_url_length, $send_to_channel, $debug, $channel_list);

sub setuphandler{
   # The script no longers sends translations to channel by default
   # You can enable the older functionality here.
   # it is controlled via the irssi /set command (see above)
   Irssi::settings_add_bool("shorturl", "shorturl_send_to_channel", 0);
   if( Irssi::settings_get_bool("shorturl_send_to_channel") ) {
      print "shorturl: sending of shorturl's to public channels enabled";
      $send_to_channel=1;
   }

   #what channels should be parsed (default is empty, which is all)
   # it is controlled via the irssi /set command (see above)
   Irssi::settings_add_str("shorturl", "shorturl_chans", "");
	$channel_list = Irssi::settings_get_str("shorturl_chans");
   if ($channel_list) {
      print "shorturl: Following channels are now parsed $channel_list";
   }

   # Max chars per url. No sense in translating already short urls :)
   # it is controlled via the irssi /set command (see above)
   Irssi::settings_add_int("shorturl", "shorturl_min_url_length", 35);
   my $old_min_url_length=$min_url_length;
   $min_url_length=Irssi::settings_get_int("shorturl_min_url_length");
   if ($min_url_length != $old_min_url_length) {
      print "shorturl: min_url_length sucessfully set to $min_url_length";
   }

   # Debug messages (prints what url shorterner is used, error messages, etc)
   # it is controlled via the irssi /set command (see above)
   Irssi::settings_add_bool("shorturl", "shorturl_debug", 0);
   my $old_debug=$debug;
   $debug=Irssi::settings_get_bool("shorturl_debug");
   if ($debug != $old_debug) {
      if ($debug){
         print "shorturl: Debug Mode Enabled";
         $debug=1;
      }else{
         print "shorturl: Debug Mode Disabled";
         $debug=0;
      }
   }
   
}

sub InjectUrl {
    # data - contains the parameters for /shorturl
    # server - the active server in window
    # target - the active window item (eg. channel, query)
    #         or undef if the window is empty
    my ($data, $server, $target) = @_;

    if (!$server || !$server->{connected}) {
      Irssi::print("Not connected to server");
      return;
    }

    if ($data) {
      GotUrl($server, $data, undef, undef, $target);
    }
}

sub GotUrl {
	my ($server, $data, $nick, $addr, $target) = @_;
   if (!$server || !$server->{connected}) {
      Irssi::print("Not connected to server");
      return;
    }
	return unless(goodchan($target));	
	$data =~ s/^\s+//;
	$data =~ s/\s+$//;
	my @urls = ();
	my ($url, $a, $return, $char, $ch, $result, $choice) = "";;
	my $same = 0;
	my $sitewas = "t";
	my @chars = ();

	return unless (($data =~ /\bhttp\:/) || ($data =~ /\bhttps\:/));
	deb("$target triggered GotUrl() with url: $data");

	# split on whitespace and get the url(s) out
	# done this way in case there are more than 
	# one url per line.
	foreach(split(/\s/, $data)) {
		if (($_ =~ /^http\:/) || ($_ =~ /^https\:/)){
			foreach $a (@urls) {
				if ($_ eq $a) {
					# incase they use the same url on the line.
					$same = 1;
					next;
				}
			}

			if ($same == 0) {
				$same = 0;
				push(@urls, $_);
			}
		}
	}

	# Go through the resulting urls
	foreach (@urls) {

		#Minimum url length.
		return unless (count($_) > $min_url_length);
		@chars = split(//, $_);
		
		# Originally I used uri_escape() for this
		# But tinyurl didnt like it.. might be because
		# of the post method I was using at the time.
		foreach $char (@chars) {
			if ($char !~ /[A-Za-z0-9]/) {
				$ch = sprintf("%%%02x",ord($char));
				$result .= $ch;
			} else {
				$result .= $char;
			}
		}

		# Get a random provider from the list.
		$choice = $lookups[ rand(@lookups) ];
		if ($choice eq "metamark") {
		   deb("$target Generating metamark url for $result");
			$url = "http://metamark.net/api/rest/simple?long_url=" . $result;
			eval { $return = get($url) };
			next unless ($return);
			next if ($return =~ /ERROR\:/);
         if ($send_to_channel == 1) {
			   $server->command("msg $target $return");
         }else{
			   $server->print("$target", "$return", MSGLEVEL_CLIENTCRAP);
			   #Irssi::print("$target: $return");
         }
		} else {
         deb("$target Generating tinyurl url for $result");
         deb("tinyurl(\$server, $target, $result)");
 			tinyurl($server, $target, $result);
		}
		
	}
	return;
}

sub tinyurl {
	my ($server, $chan, $longurl) = @_;
   my $url = 'http://tinyurl.com/api-create.php?url='.$longurl;
   deb("getting url:($url)");
   my $browser = LWP::UserAgent->new;
	$browser->agent("tinyurl for irssi/0.8.12 ");
   my $response = $browser->get($url);
   my $tinyurl = $response->content;
   my $ua = LWP::UserAgent->new;
   if ($response->is_success) {
	   if ($send_to_channel == 1) {
	      $server->command("msg $chan $tinyurl");
      }else{
			$server->print("$chan", "$tinyurl", MSGLEVEL_CLIENTCRAP);
	      #Irssi::print("$chan: $tinyurl");
      }
   }else{
      deb("ERROR: tinyurl: tinyurl is down or not pingable");
   }
}

# conditinal print.
sub deb($) {
	Irssi::print(shift) if ($debug == 1);
}


# returns the character count.
sub count($) {
	my @array = split(//, shift);
	return($#array + 1);
}

# Checks if we should be translating 
# urls for the requesting channel.
# returns True if the list is not set
# thus, it will translate for ALL channels.
# returns True if channel matches one in the list.
# returns undef otherwise.
sub goodchan {
	my $chan = shift;
	return("OK") if (! $channel_list);
	foreach(split(/\,/, $channel_list)) {
		return("$_") if ($_ =~ /$chan/i);
	}
	return undef;
}

setuphandler(); #initilize variables on first run
Irssi::signal_add("setup changed", "setuphandler");
Irssi::signal_add_last("message public", "GotUrl");
Irssi::signal_add_last("ctcp action", "GotUrl");
Irssi::command_bind('shorturl', 'InjectUrl');


