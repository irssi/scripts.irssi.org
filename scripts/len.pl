# $Id: len.pl 4 2006-03-11 18:30:09Z ch $

use Irssi 20020324;
use 5.005_62;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0.0';
#$VERSION = '1.0.0 SVN ($LastChangedRevision: 4 $)';
%IRSSI = (
          authors     => 'Clemens Heidinger',
          changed     => '$LastChangedDate: 2006-03-11 19:30:09 +0100 (Sat, 11 Mar 2006) $',
          commands    => 'len',
          contact     => 'heidinger@dau.pl',
          description => 'If you try to get a nick with 11 characters but only ' .
                         '9 are allowed, this script will prevent the '          .
                         'nickchange. The same for too long topics, kickmsgs, '  .
                         'partmsgs and quitmsgs.',
          license     => 'BSD',
          name        => 'len',
         );

################################################################################
#                                                                              #
# CHANGELOG                                                                    #
#                                                                              #
# 2006-03-11    release 1.0.0                                                  #
#               No big changes. As the script is stable for quite a while,     #
#               this is the 1.0.0 release.                                     #
#                                                                              #
# 2005-01-28    release 0.4.0                                                  #
#               Splitted up 005 event messages will cause no trouble anymore   #
#                                                                              #
# 2004-04-26    release 0.3.2                                                  #
#               minor changes                                                  #
#                                                                              #
# 2003-01-18    release 0.3.1                                                  #
#               - revised help-message                                         #
#               - minor changes                                                #
#                                                                              #
# 2003-01-18    release 0.3.0                                                  #
#               %data-hash moved to extern file specified in setting           #
#               len_data_file                                                  #
#                                                                              #
# 2002-10-02    release 0.2.1                                                  #
#               Changed output format of /len                                  #
#                                                                              #
# 2002-09-27    release 0.2.0                                                  #
#               Added command /len with a table containing the values for      #
#               NICKLEN etc. and tips if these values haven't been received    #
#               from the server yet                                            #
#                                                                              #
# 2002-09-26    release 0.1.0                                                  #
#               initial release                                                #
#                                                                              #
################################################################################

################################################################################
# Register commands
################################################################################

Irssi::command_bind('len', \&command_len);

################################################################################
# Register settings
################################################################################

# String
Irssi::settings_add_str('misc', 'len_data_file', "$ENV{HOME}/.len");

################################################################################
# Register signals
################################################################################

Irssi::signal_add_first('command kick', \&signal_command_kick);
Irssi::signal_add_first('command nick', \&signal_command_nick);
Irssi::signal_add_first('command part', \&signal_command_part);
Irssi::signal_add_first('command quit', \&signal_command_quit);
Irssi::signal_add_first('command topic', \&signal_command_topic);
Irssi::signal_add_last('event 005', \&signal_event_005);

################################################################################
# Register themes
################################################################################

Irssi::theme_register(['len_print', '[$0] {line_start} $1']);

################################################################################
# Global Variables
################################################################################

# Put values of the settings in %option-hash

our %option;

# Most IRC-Server send a message containing the values for NICKLEN, TOPICLEN
# and KICKLEN.
# Well, some server do not send this message. Get these values from %data-hash
# stored in file specified in setting len_data_file.

our %data;

################################################################################
# Code run once at start
################################################################################

print CLIENTCRAP "len.pl $VERSION loaded. For further information type %9/len%9";

################################################################################
# Subroutines (commands)
################################################################################

sub command_len {
	my ($data, $server, $witem) = @_;
	my $output;

	unless ($server and defined($server)) {
		print_out("First connect to a server...");
		return;
	}

	read_file();

	my $kicklen  = sprintf "%-8s", $data{$server->{tag}}{kicklen};
	my $nicklen  = sprintf "%-8s", $data{$server->{tag}}{nicklen};
	my $partlen  = sprintf "%-8s", $data{$server->{tag}}{partlen};
	my $quitlen  = sprintf "%-8s", $data{$server->{tag}}{quitlen};
	my $topiclen = sprintf "%-9s", $data{$server->{tag}}{topiclen};

	$output = &fix(<<"	END");
	|=========|=================|
	|         | max. characters |
	|=========|=================|
	| kickmsg | $kicklen        |
	|---------|-----------------|
	| nick    | $nicklen        |
	|---------|-----------------|
	| partmsg | $partlen        |
	|---------|-----------------|
	| quitmsg | $quitlen        |
	|---------|-----------------|
	| topic   | $topiclen       |
	|---------|-----------------|
	END

	unless ($kicklen   =~ /\d/ &&
	        $nicklen   =~ /\d/ &&
	        $partlen   =~ /\d/ &&
	        $quitlen   =~ /\d/ &&
	        $topiclen  =~ /\d/)
	{
		$output .= &fix(<<"		END");

		Obviously there are some values missing.
		When you connect to a server most send you a message (numeric 005)
		with the proper values for the maximal nick length, topic length etc.
		If you loaded this script after connecting to "$server->{tag}"
		you should reconnect.
		If this doesn't help, the server is not sending the message with these
		values.
		The following alternatives remain:
		  * Use another server of the same network and cross your fingers
		    that it'll send the message.
		  * Find out the values and adjust the data hash in the file
		    specified in the setting len_data_file.
		    The file might look like this:

		    %{ \$data{$server->{tag}} } = (
		        'kicklen'  => <value>,
		        'nicklen'  => <value>,
		        'partlen'  => <value>,
		        'quitlen'  => <value>,
		        'topiclen' => <value>,
		    );

		    %{ \$data{someOtherNetwork} } = (
		        'kicklen'  => 160,
		        'nicklen'  => 9,
		        'partlen'  => 160,
		        'quitlen'  => 160,
		        'topiclen' => 160,
		    );
		END
	}

	foreach my $line (split /\n/, $output) {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'len_print', $server->{tag}, $line);
	}
}

################################################################################
# Subroutines (signals)
################################################################################

sub signal_command_kick {
	my ($command, $server, $witem) = @_;

	return unless ($server and defined($server));

	read_file();

	# Syntax for /kick:
	# KICK [<channel>] <nicks> [<reason>]
	# We want to isolate <reason> to know how long it is

	# delete [<channel>] <nicks>
	$command =~ s/^\s*           # Start of String and optional some whitespace
	              (?:            # Grouping
	              \#\S+          # This is <channel>
	              )?             # End of Grouping, <channel> is optional
	              [ ]?           # Maybe a single space
	              \S+            # Everything not whitespace. These are the nicks.
	              [ ]?           # Maybe a single space
	             //x;            # Delete everything

	# The rest of $command is the kickmsg
	my $kickmsg = $command;

	my $len = length($kickmsg);
	my $maxlen = $data{$server->{tag}}{kicklen};

	if ($maxlen > 0 && $len > $maxlen) {
		print_out("kickmsg too long! ($len/$maxlen)");
		Irssi::signal_stop();
	}
}

sub signal_command_nick {
	my ($nick, $server, $witem) = @_;

	return unless ($server and defined($server));

	read_file();

	my $len = length($nick);
	my $maxlen = $data{$server->{tag}}{nicklen};

	if ($maxlen > 0 && $len > $maxlen) {
		print_out("Nick too long! ($len/$maxlen)");
		Irssi::signal_stop();
	}
}

sub signal_command_part {
	my ($command, $server, $witem) = @_;

	return unless ($server and defined($server));

	read_file();

	# Syntax for /part:
	# PART [<channels>] [<message>]
	# So we want to get rid of the channels to isolate the partmsg

	# Delete [<channels>]
	$command =~ s/^#\S+ //;

	# The rest of $command is the partmsg
	my $partmsg = $command;

	my $len = length($partmsg);
	my $maxlen = $data{$server->{tag}}{partlen};

	if ($maxlen > 0 && $len > $maxlen) {
		print_out("partmsg too long! ($len/$maxlen)");
		Irssi::signal_stop();
	}
}

sub signal_command_quit {
	my ($quitmsg, $server, $witem) = @_;

	return unless ($server and defined($server));

	read_file();

	my $len = length($quitmsg);
	my $maxlen = $data{$server->{tag}}{quitlen};

	if ($maxlen > 0 && $len > $maxlen) {
		print_out("quitmsg too long! ($len/$maxlen)");
		Irssi::signal_stop();
	}
}

sub signal_command_topic {
	my ($command, $server, $witem) = @_;

	return unless ($server and defined($server));

	read_file();

	# Syntax for /topic:
	# TOPIC [-delete] [<channel>] [<topic>]
	# We want to isolate <reason> to know how long it is

	# Delete <channel>
	$command =~ s/^#\S+ //;

	# The rest of $command is the topic
	my $topic = $command;

	my $len = length($topic);
	my $maxlen = $data{$server->{tag}}{topiclen};

	if ($maxlen > 0 && $len > $maxlen) {
		print_out("Topic too long! ($len/$maxlen)");
		Irssi::signal_stop();
	}
}

# Most server send this message containig the values for NICKLEN etc. on
# connect (event 005).

sub signal_event_005 {
	my ($server, $string) = @_;

	if ($string =~ /KICKLEN=(\d+)/) {
		$data{$server->{tag}}{kicklen} = $1;
		$data{$server->{tag}}{partlen} = $1;
		$data{$server->{tag}}{quitlen} = $1;
	}
	if ($string =~ /NICKLEN=(\d+)/) {
		$data{$server->{tag}}{nicklen} = $1;
	}
	if ($string =~ /TOPICLEN=(\d+)/) {
		$data{$server->{tag}}{topiclen} = $1;
	}
}

################################################################################
# Helper subroutines
################################################################################

sub fix {
	my $string = shift;
	$string =~ s/^\t+//gm;
	return $string;
}

sub print_err {
	my $text = shift;

	print CLIENTCRAP '%Rlen.pl error%n: ' . $text;
}

sub print_out {
	my $text = shift;

	print CLIENTCRAP '%9len.pl%9: ' . $text;
}

sub read_file {
	set_settings();

	my $file = $option{len_data_file};

	unless (-e $file && -r $file) {
		return;
	}
	unless (my $return = do $file) {
		if ($@) {
			print_err("parsing $file failed: $@");
		}
		unless (defined($return)) {
			print_err("'do $file' failed");
		}
	}
}

sub set_settings {
	# String
	$option{len_data_file} = Irssi::settings_get_str('len_data_file');
}
