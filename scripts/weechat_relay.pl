#!/usr/bin/env perl
# Copyright (c) 2016 Thomas Stagner <aquanight@gmail.com>
# Copyright (c) 2015-2016 Robin Burchell <robin.burchell@viroteck.net>
# Copyright (c) 2011-2012 Timothy J Fontaine
# https://github.com/rburchell/irssi-relay
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

use v5.12;

use strict;
use warnings 'all';

no warnings 'portable';

use Irssi;
use Irssi::TextUI;

use Mojolicious::Lite;
use Mojo::Server::Daemon;

use File::Basename 'dirname';
use File::Spec;

use Carp ();

our $VERSION = '0.0.2';
our %IRSSI = (
  authors => 'weechat_relay.pl authors',
  contact => 'robin.burchell@viroteck.net',
  name    => 'Weechat Relay',
  license => 'MIT',
  description => 'Weechat relay protocol implementation',
  changed => '2016-08-18'
);

Irssi::theme_register([
 'weechat_relay',
 '{line_start}{hilight ' . $IRSSI{'name'} . ':} $0'
]);

my @needs = ('Compress::Zlib', 'IO::Socket::SSL', 'Mojolicious::Lite', 'Mojo::Server::Daemon');
foreach my $need (@needs) {
	eval("use $need");
	if ($@) {
		Irssi::print($IRSSI{'name'} . " requires Compress::Zlib, IO::Socket::SSL, Mojolicious::Lite and Mojo::Server::Daemon");
		Irssi::print("To install these modules execute:");
		Irssi::print("cpan install Compress::Zlib IO::Socket::SSL Mojolicious::Lite Mojo::Server::Daemon");
		die();
	}
}

Irssi::settings_add_str('weechat_relay', 'wcrelay_host', 'localhost');
Irssi::settings_add_int('weechat_relay', 'wcrelay_port', 9001);
Irssi::settings_add_bool('weechat_relay', 'wcrelay_ssl', 0);
Irssi::settings_add_str('weechat_relay', 'wcrelay_cert', '');
Irssi::settings_add_str('weechat_relay', 'wcrelay_key', '');
Irssi::settings_add_str('weechat_relay', 'wcrelay_password', '');
Irssi::settings_add_int('weechat_relay', 'wcrelay_ziplevel', Compress::Zlib::Z_DEFAULT_COMPRESSION);

my $tsfmt = Irssi::settings_get_str("timestamp_format");
my $tsrxval;

sub _rxify {
	my ($mrk, $txt) = @_;
	$mrk eq 'TEXT' and return '\w+';
	$mrk eq 'NUM' and return '\d+';
	$mrk eq 'NUMSPC' and return '[\d ]+';
	$mrk eq 'PERCENT' and return '\%';
	$mrk eq 'NOTSPEC' and return quotemeta($txt);
	$mrk eq 'WEIRD' and return '';
	if ($mrk eq 'COMPOSITE') {
		for (substr($txt, -1, 1)) { # Puts the last character into $_
			/D/ and return '\d+\/\d+\/\d+';
			/F/ and return '\d+\-\d+\-\d+';
			/n/ and return '\n';
			/t/ and return '\t';
			/z/ and return '[+-]\d+';
		}
	}
}

our $REGMARK;
$tsrxval = $tsfmt =~ s/(%[aAbBhpPZ](*MARK:TEXT)|%(?:[CdGgHIjmMsSuUVwWyY]|E[CyY]|O[dHImMSuUVwWy])(*MARK:NUM)|%O?[ekl](*MARK:NUMSPC)|%%(*MARK:PERCENT)|%(DFntz)(*MARK:COMPOSITE)|%(?:E?[cxX+]|rRT)(*MARK:WEIRD)|(*MARK:NOTSPEC).)/
	_rxify($REGMARK, $1);
/ger; # g = replace-all, e = replacement is actually code, r = leave $tsfmt unchanged, return result to put in $tsrx

# Now add the regex settings
Irssi::settings_add_str(weechat_relay => 'wcrelay_strip_prefix', $tsrxval);

my $tsrx;

sub _load_regex {
	$tsrx = undef;
	# Now GET the actual regex string currently set (since irssi may have loaded some other value from config)
	$tsrxval = Irssi::settings_get_str('wcrelay_strip_prefix');

	# Now compile it:
	eval {
		if ($tsrxval ne '') {
			$tsrx = qr/^$tsrxval/;
		}
	};
	if ($@) {
		my $msg = ($@ =~ s/ at .* line \d+//r);
		Irssi::print("Your wcrelay_strip_prefix setting has errors: $msg");
		Irssi::print("Line prefixes will not be stripped until this is corrected.");
	}
}
_load_regex();

my $daemon;
my $loop_id;

my %settings;
my %clients = ();
sub ws_loop;

sub demojoify {
	if (defined($loop_id)) {
		Irssi::timeout_remove($loop_id);
	}
	# TODO: is daemon cleared up properly? and finish this
	$daemon->stop();
	my @c = values %clients;
	$_->{client}->finish() for @c;
	# Block until all ->finish calls complete.
	while (scalar keys %clients) {
		ws_loop;
	}
}

sub mojoify {
    $ENV{MOJO_REUSE} = 1;

    # Mojo likes to spew, this makes irssi mostly unsuable
    my $logdir = Irssi::get_irssi_dir() . "/log";
    unless (-e $logdir) { mkdir $logdir; }
    if (!-d $logdir) { warn "Log directory is not a directory"; app->log(Mojo::Log->new("/dev/null")); }
    else {
	    app->log(Mojo::Log->new(path => "$logdir/weechat_relay.log"));
    }

    app->log->level('debug');

    my $listen_url;

    my $host = Irssi::settings_get_str('wcrelay_host');
    my $port = Irssi::settings_get_int('wcrelay_port');
    my $cert = Irssi::settings_get_str('wcrelay_cert');
    my $key  = Irssi::settings_get_str('wcrelay_key');

    %settings = (host => $host, port => $port, cert => $cert, key => $key, ssl => Irssi::settings_get_bool('wcrelay_ssl'));

    if(Irssi::settings_get_bool('wcrelay_ssl')) {
	if (-e $cert && -e $key) {
	        $listen_url = sprintf("https://%s:%d?cert=%s&key=%s", $host, $port, $cert, $key);
	} else {
		Irssi::print($IRSSI{'name'} . " was unable to read the configured SSL certificate (wcrelay_cert) or private key (wcrelay_key)");
		return;
	}
    } else {
        $listen_url = sprintf("http://%s:%d", $host, $port);
    }

    logmsg("listen on $listen_url");
    $daemon = Mojo::Server::Daemon->new(app => app, listen => [$listen_url], inactivity_timeout => 0)->start;

    #TODO XXX FIXME we may be able to up this to 1000 or higher if abuse
    # mojo ->{handle} into the input_add system
    $loop_id = Irssi::timeout_add(100, \&ws_loop, 0);

}

mojoify();

sub setup_changed {
    my ($cert, $key);
    $cert = Irssi::settings_get_str('wcrelay_cert');
    $key  = Irssi::settings_get_str('wcrelay_key');

    if(length($cert) && !-e $cert) {
        logmsg("Certificate file doesn't exist: $cert");
    }
    if(length($key) && !-e $key) {
        logmsg("Key file doesn't exist: $key");
    }

    # If any connection settings changed, stop and restart the mojo server. NOTE: this means we also disconnect all relays!
    # NOTE: password changes do NOT force a stop/restart
    if (
	$settings{host} ne Irssi::settings_get_str('wcrelay_host') ||
	$settings{port} != Irssi::settings_get_int('wcrelay_port') ||
	$settings{cert} ne Irssi::settings_get_str('wcrelay_cert') ||
	$settings{key}  ne Irssi::settings_get_str('wcrelay_key')  ||
	$settings{ssl}  != Irssi::settings_get_bool('wcrelay_ssl')) {
	
	# Irssi will sometimes crash here when settings are changed and we only demojoify() and mojoify()
	# Let's just let Irssi clean up our mess
	Irssi::print($IRSSI{'name'} . ' must be reloaded to use updated connection settings.');
   }

    # Did the regex setting change?
    if ($tsrxval ne Irssi::settings_get_str('wcrelay_strip_prefix'))
    {
	    _load_regex();
    }
};

sub ws_loop {
    if($daemon) {
        my $id = $daemon->ioloop->timer(0.0 => sub {});
        $daemon->ioloop->one_tick;
        $daemon->ioloop->remove($id);
    }
}

sub logmsg {
    my $msg = shift;
#    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'weechat_relay', $msg);
    app->log->info($msg);
}

my $logmsg = \&logmsg; # For WeechatMessage

websocket '/weechat' => sub {
    my $client = shift;
    logmsg("Client connected:" . $client->tx->remote_address);
    $clients{$client} = {
        client => $client,
        color => 0,
        authenticated => 0,
	compression => 'off',
    };
    $client->on(message => \&process_message);
    $client->on(finish => sub {
            # delete first, otherwise we'll try tell the client about their disconnect,
            # which will be rather painful.
	    desync_client($client);
            delete $clients{$client};
            logmsg("Client disconnected: " . $client->tx->remote_address);
    });
};

get '/' => sub {
    my $client = shift;
    logmsg("Something made a HTTP request: " . $client->tx->remote_address);
    $client->render(text => "")
};

sub sendto_client {
    my ($client, $msg) = @_;
    if($clients{$client}->{'authenticated'}) {
        $client->send({binary => $msg});
    }
}

=thisisntused
sub sendto_all_clients {
    my $msg = shift;

    while (my ($client, $chash) = each %clients) {
        sendto_client($chash->{'client'}, $msg);
    }
}
=cut

sub parse_init {
    my ($client, $id, $arguments) = @_;
    my @kvpairs = split(',', $arguments);
    my $chash = $clients{$client};
    foreach my $kvpair (@kvpairs) {
        my ($key, $value) = split('=', $kvpair);

        if ($key eq 'compression') {
	    $chash->{compression} = $value;
        } elsif ($key eq 'password') {
            # TODO
	    my $tpass = Irssi::settings_get_str('wcrelay_password');
            if ($value eq $tpass) {
	            $chash->{'authenticated'} = 1;
	            logmsg("Client has successfully authenticated");
            }
        } else {
            logmsg("Client sent unknown init key: $key = $value")
        }
    }
}

package WeechatMessage {
    sub new {
        my $self = bless {};
        return $self->init(@_);
    }

    sub init {
        my $self = shift;
        return $self;
    }

    sub add_int {
        my ($self, $int) = @_;
        $self->{buf} .= pack("i>", $int);
	return $self;
    }

    sub set_int {
	    my ($self, $pos, $int) = @_;
	    substr($self->{buf}, $pos, 4) = pack("i>", $int);
	    return $self;
    }

    sub add_uint {
        my ($self, $uint) = @_;
        $self->{buf} .= pack("N", $uint);
	return $self;
    }

    sub add_chr {
        my ($self, $chr) = @_;
	$self->{buf} .= pack("c", $chr);
	return $self;
    }

    sub add_string {
        my ($self, $string) = @_;
	if (defined($string)) {
	        $self->{buf} .= pack("i>/a", $string);
	} else {
		$self->add_int(-1); # sz 0xFFFFFFFF == NULL string.
	}
	return $self;
    }

    sub add_string_shortlength {
        my ($self, $string) = @_;
	$self->{buf} .= pack("c/a", $string);
	return $self;
    }

    sub add_ptr {
	my ($self, $ptr) = @_;
	#$self->{buf} .= pack("c/a", sprintf("%016x", $ptr));
	use integer;
	defined($ptr) or Carp::cluck("Attempting to add an undefined pointer value");
	$self->add_string_shortlength(sprintf("%016x", $ptr));
	return $self;
    }

    sub add_type {
        my ($self, $type) = @_;
        $self->{buf} .= $type;
	return $self;
    }

    sub add_info {
        my ($self, $name, $value) = @_;
        add_string($self, $name);
        add_string($self, $value);
	return $self;
    }

    sub concat {
	my ($self, $other) = @_;
	$self->{buf} .= $other;
	return $self;
    }

    sub get_buffer {
	    my ($self) = @_;
	    my $retval = "\1";
	    $retval .= Compress::Zlib::compress($self->{buf}, Irssi::settings_get_int('wcrelay_ziplevel'));
	    my $retbuf = pack("N", 4+length($retval)) . $retval;
	local $Data::Dumper::Terse = 1;
	local $Data::Dumper::Useqq = 1;
	$logmsg->("Zlib-compressed buffer contents are: " . Data::Dumper->Dump([$retbuf], ['retbuf']));
	return $retbuf;
    }

    sub get_raw_buffer {
	    my ($self) = @_;
	    return $self->{buf};
    }

    sub get_length {
	    my ($self) = @_;
	    return length $self->{buf};
    }
}

sub parse_info {
    my ($client, $id, $arguments) = @_;
    if ($arguments eq 'version') {
        my $obj = WeechatMessage::new();
        $obj->add_string($id);
        $obj->add_type("inf");
        $obj->add_info("version", "1.4");
        sendto_client($client, $obj->get_buffer());
    } else {
        logmsg("Unknown INFO requested: $arguments");
    }
}


# Splits off one piece of an hpath. It takes off the first segment, skipping a leading /.
# Splits into object name, count, and then the rest of the path with leading /.
# Count is 0 if there is no count supplied. "Rest of path" is empty string (with not even a /) if this is the end of the path.
sub hpath_tok {
	my ($hpath)= @_;

	if ($hpath =~ m[^/?(?'obj'[^/]+?)(?:\((?'ct'(?:[+-]?\d+|\*))\))?(?'rest'/.*)?$]) {
		my ($obj, $count, $rest) = ($1, $2, $3);
		$count //= 0;
		$rest //= "";
		return $obj, $count, $rest;
	}
}

my %ext_map = (
	'.' => [0x10, 0],
	'-' => [0x60, 0],
	',' => [0xB0, 0],
	'+' => [0x10, 1],
	"'" => [0x60, 1],
	'&' => [0xB0, 1],
);
my %style_map = (
	b => '_',
	c => '*',
	d => '!',
	f => '/',
);
my @irssi_weechat_color_map = (
	# First sixteen colors are irssi's terminal colors:
	# black, blue, green, cyan, red, magenta, yellow, white, BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, YELLOW, WHITE
	# BLACK = dark grey, white = light grey, WHITE, of course, is actual white
	# yellow is closer to "brown"
	1, 9, 5, 13, 3, 11, 7, 15, 2, 10, 6, 14, 4, 12, 8, 16
);
sub format_irssi_to_weechat {
	my ($input) = @_;
	my $output = "";
	# Irssi's format codes, in a nutshell:
	# \cDa -> blink (dropped)
	# \cDb -> underline
	# \cDc -> bold
	# \cDd -> reverse
	# \cDe -> indent marker (dropped)
	# \cDf -> italic
	# \cDg -> reset
	# \cDh -> clrtoeol (dropped)
	# \cDi -> monospace (dropped - for now)
	# \cD?? -> (## = some values), color code 0-16, foreground and background
	# \cD.? -> foreground color code 16-...
	# \cD-? -> foreground color code 96-...
	# \cD,? -> foreground color code 176-...
	# \cD+? -> background color code 16-...
	# \cD'? -> background color code 96-...
	# \cD&? -> background color code 176-...
	# \c#???? -> RGB color
	my %state = map { $_ => 0 } keys %style_map;
	pos($input) = 0; # Put to start of string.
	while ($input =~ m/\G([^\cD]+(*MARK:TEXT)|\cD[abcdefghi](*MARK:STYLE)|\cD[-.,+'&].(*MARK:EXTCLR)|\cD#....(*MARK:CLR24)|\cD[^-.,+'&#].(*MARK:CLRSTD)|\cD(*MARK:BADCTRLD))/g) {
		my $tx = $1;
		if ($REGMARK eq 'TEXT') {
			$output .= $tx;
		}
		elsif ($REGMARK eq 'STYLE') {
			my $type = substr($tx, 1, 1);
			if ($type eq 'g') {
				$output .= "\x1C";
				%state = map { $_ => 0 } keys %style_map;
			}
			elsif (exists $style_map{$type}) {
				$output .= ($state{$type} ? "\x1B" : "\x1A") . $style_map{$type};
				$state{$type} = !$state{$type};
			}
		}
		elsif ($REGMARK eq 'EXTCLR') {
			my ($e, $o) = map { ord(substr($tx, $_, 1)) } (1, 2);
			my ($adj, $isbg) = @{$ext_map{chr($e)}};
			my $clr = 16 + ($adj - 0x3F + $o);
			$output .= sprintf("\x19%s@%05d", ($isbg ? "B" : "F"), $irssi_weechat_color_map[$clr]//$clr);
		}
		elsif ($REGMARK eq 'CLR24') {
			# HTML color mapping
			my ($r, $g, $b, $x) = map { ord(substr($tx, $_, 1)) } (2, 3, 4, 5); # split to chars and get charcode
			$x -= 0x20;
			if ($x & 0x10) { $r -= 0x20; }
			if ($x & 0x20) { $g -= 0x20; }
			if ($x & 0x40) { $b -= 0x20; }
			logmsg(sprintf("HTML color decoded: #%02x%02x%02x", $r, $g, $b));
			# But what the heck to do with it? Weechat doesn't seem to have 24-bit color...
		}
		elsif ($REGMARK eq 'CLRSTD') {
			my ($f, $b) = map { ord(substr($tx, $_, 1)) } (1, 2);
			if ($f == ord('/')) { $f = undef; }
			elsif ($f > ord('?') || $f < ord('0')) { $f = 0; }
			else { $f -= ord('0'); $f = $irssi_weechat_color_map[$f]//$f; }
			
			if ($b == ord('/')) { $b = undef; }
			elsif ($b > ord('?') || $b < ord('0')) { $b = 0; }
			else { $b -= ord('0'); $b = $irssi_weechat_color_map[$b]//$b; }

			if (defined($f) && defined($b)) {
				$output .= sprintf("\x19*%02d,%02d", $f, $b);
			}
			elsif (defined($f)) {
				$output .= sprintf("\x19F%02d", $f);
			}
			elsif (defined($b)) {
				$output .= sprintf("\x19B%02d", $b);
			}
		}
		else {
			# ...
		}
	}
	# Simplify the output string (e.g. combine colors and attribute-sets, combine fg/bg)
	# Combine foreground/background consecutives:
#	$output =~ s/[\x19]F(@?\d+)[\x19]B(@?\d+)/\x19*$1,$2/g;
#	$output =~ s/[\x19]B(@?\d+)[\x19]F(@?\d+)/\x19*$2,$1/g;
#	$output =~ s/[\x1A](.)[\x19]
	return $output;
}

sub separate_message_and_prefix {
	my ($txt) = @_;
	### XXX Right now the nick selection regex is hardcoded.
	### It would probably be better as another /set to deal with
	### things like non-ANSI character sets.
	my $clrs = qr/(?:\cD(?:[a-i]|#....|..))*/; # quick regex for colorcode skipping
	# Below regex based on inspircd nick validation.
	my $nickreg = qr/[0-9A-}][A-}0-9-]+/;
	my $pfxs = join "", (map { $_->isupport("PREFIX") =~ m/^\(\w+\)(.*)$/ and $1 or '@+'; } Irssi::servers());
	my $pfxrx = qr/[ \Q$pfxs\E]/;
	# This was a good idea if irssi's themes were a bit more consistent with using it. Sadly, it is not, so it goes away.
=if0
	if ($txt =~ m/\cDe/p) {
		my ($pfx, $msg) = (
			${^PREMATCH},
			${^POSTMATCH},
		);
		# Gather up all format codes in the prefix and replay them in the message, so that
		# the color changes correctly carry over.
		my $allclrs = join "", ($pfx =~ m/$clrs/g);
		$msg = $allclrs . $msg;
		if ($pfx =~ m/($nickreg)/)
		{
			$pfx = $1;
		}
		return $pfx, $msg;
	}
=cut
	# The below all pretty much will only work under the default.theme. I'm not a fan of this, but it's a start.
	# Standard messages: <@nick> message
	if ($txt =~ m/^($clrs)<(${clrs}${pfxrx}${clrs}${nickreg})${clrs}>$clrs /p) {
		my ($rawpfx, $initclrs, $pfx, $msg) = (
			${^MATCH},
			$1,
			$2,
			${^POSTMATCH},
		);
		# Make sure the initial colors are correctly applied to the nick:
		$pfx = $initclrs . $pfx;
		# Also replay all color codes from the prefix into the message.
		my $allclrs = join "", ($rawpfx =~ m/$clrs/g);
		$msg = $allclrs . $msg;
		return $pfx, $msg;
	}
	# Action messages: * @nick message
	elsif ($txt =~ m/^(${clrs}\s*${clrs}\*${clrs})\s*(${clrs}${pfxrx}?${clrs}${nickreg}${clrs}\s+.*)/) {
		my ($pfx, $msg) = (
			$1,
			$2,
		);
		my $allclrs = join "", ($pfx =~ m/$clrs/g);
		$msg = $allclrs . $msg;
		return $pfx, $msg;
	}
	# -!- and -!- Irssi: cases
	elsif ($txt =~ m/$clrs-$clrs!$clrs-$clrs(?: ${clrs}Irssi:$clrs)?/p) {
		my ($pfx, $msg) = (
			${^MATCH},
			${^POSTMATCH},
		);
		return $pfx, $msg;
	}
	else {
		return "--\cDg", $txt;
	}

}

# Basic signature for an hdata handler:
# list_<n> : Subroutine called when requesting top-level list <n>, the counter value will be passed.
#   Return value should be the list of objects from the list.
# sublist_<n> : Subroutine called when requesting member list <n>, the object and counter value will be passed.
#   Return value should be the object or list of objects in that member.
# type_sublist_<n> : String indicating the class of the sublist, which must be some other class in the hdata_classes hash.
# key_<n> : Subroutine called when requesting key <n>. The object to retrieve the key from will be passed, as well as a WeechatMessage instance.
#   The subroutine should encode the object value into the WeechatMessage instance. It should not return anything.
# type_key_<n> : String which is the 3-letter code type of the key.
# from_pointer : Subroutine called when the top-level list item is a pointer address. The pointer (as an integer) is passed.
#   Return value should be the object in question. Return undef if no such object.
# get_pointer : Subroutine called to get a pointer value from an object.
my %line_ptr_cache; # The from_pointer algo for line is stupid because we have to literally do a mass search of all lines in all buffers.
	# this hash exists so that gui_print_line_finished can short-circuit the whole damn thing.
my %hdata_classes = (
	buffer => {
		list_gui_buffers => sub {
			my ($ct) = @_;
			# A weechat "buffer" is what irssi calls a window, but weechat also merges in stuff from window item.
			# Solution: we return the window and the info of the active item (if there is one)
			# And we will have to push things like nicklist changes if they do /window item next
			my @w = sort { $a->{refnum} <=> $b->{refnum} } Irssi::windows();
			if ($ct eq '*' || $ct > $#w) { return @w; }
			elsif ($ct <= 0) { return $w[0]; }
			else { return $w[0 .. $ct]; }
		},
		sublist_lines => sub {
			my ($w, $ct) = @_; # Irssi::Window
			return $w->view()->{buffer};
		},
		type_sublist_lines => 'lines',
		get_pointer => sub {
			my ($w) = @_; # Irssi::Window
			return $w->{_irssi};
		},
		from_pointer => sub {
			my ($p) = @_;
			my @w = Irssi::windows();
			my ($w) = grep { $_->{_irssi} == $p } @w;
			return $w;
		},
		sublist_plugin => sub { },
		sublist_own_lines => sub { my ($w, $ct) = @_; return $w->view()->{buffer}; },
		type_sublist_own_lines => 'lines',
		sublist_mixed_lines => sub { my ($w, $ct) = @_; return $w->view()->{buffer}; },
		type_sublist_mixed_lines => 'lines',
		sublist_nicklist_root => sub { },
		sublist_input_undo_snap => sub { },
		sublist_input_undo => sub { },
		sublist_last_input_undo => sub { },
		sublist_ptr_input_undo => sub { },
		sublist_completion => sub { },
		sublist_history => sub { },
		sublist_last_history => sub { },
		sublist_ptr_history => sub { },
		sublist_keys => sub { },
		sublist_last_key => sub { },
		sublist_prev_buffer => sub { },
		sublist_next_buffer => sub { },
		list_gui_buffer_last_displayed => sub { },
		list_last_gui_buffer => sub { },
		type_key_number => 'int',
		key_number => sub { my ($w, $m) = @_; $m->add_int($w->{refnum}); },
		type_key_layout_number => 'int',
		key_layout_number => sub { my ($w, $m) = @_; $m->add_int($w->{refnum}); },
		type_key_layout_number_merge_order => 'int',
		type_key_name => 'str',
		key_name => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->{active};
			if(defined($wi)) {
				my $s = $wi->{server};
				$m->add_string($s->{address} . "." . $wi->{name});
			}
			elsif ($w->{name}//"" ne '') {
				$m->add_string($w->{name});
			}
			else {
				$m->add_string("nameless-" . $w->{refnum});
			}
		},
		type_key_full_name => 'str',
		key_full_name => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->{active};
			if(defined($wi)) {
				my $s = $wi->{server};
				$m->add_string('irc.' . $s->{address} . "." . $wi->{name});
			}
			elsif ($w->{name}//"" ne '') {
				$m->add_string('irc.' . $w->{name});
			}
			else {
				$m->add_string('noname.nameless-' . $w->{refnum});
			}
		},
		type_key_short_name => 'str',
		key_short_name => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->{active};
			if(defined($wi)) {
				$m->add_string($wi->{name});
			}
			elsif ($w->{name}//"" ne '') {
				$m->add_string($w->{name});
			}
			else {
				$m->add_string('nameless-' . $w->{refnum});
			}
		},
		type_key_type => 'int',
		key_type => sub { my ($w, $m) = @_; my ($wi) = $w->{active}; $m->add_int(1); }, # GUI_BUFFER_TYPE_FREE
		type_key_notify => 'int',
		key_notify => sub {
			my ($w, $m) = @_;
			$m->add_int(3); # GUI_BUFFER_NOTIFY_ALL
			return;
=if0
			given ($w->{hilight_color}) {
				when(0) { $m->add_int(0); } # DATA_LEVEL_NONE => GUI_BUFFER_NOTIFY_NONE
				when(1) { $m->add_int(3); } # DATA_LEVEL_TEXT => GUI_BUFFER_NOTIFY_ALL
				when(2) { $m->add_int(2); } # DATA_LEVEL_MSG => GUI_BUFFER_NOTIFY_MESSAGE
				when(3) { $m->add_int(1); } # DATA_LEVEL_HILIGHT => GUI_BUFFER_NOTIFY_HIGHLIGHT
				default { $m->add_int(3); } # Send any other value as GUI_BUFFER_NOTIFY_ALL
			},
=cut
		},
		type_key_num_displayed => 'int',
		key_num_displayed => sub { my ($w, $m) = @_; $m->add_int(1); },
		type_key_active => 'int',
		key_active => sub { my ($w, $m) = @_; $m->add_int(2); }, # Only active (not merged)
		type_key_hidden => 'int',
		key_hidden => sub { my ($w, $m) = @_; $m->add_int(0); }, # not hidden
		type_key_zoomed => 'int',
		key_zoomed => sub { my ($w, $m) = @_; $m->add_int(0); }, # not zoomed
		type_key_print_hooks_enabled => 'int',
		key_print_hooks_enabled => sub { my ($w, $m) = @_; $m->add_int(0); }, # No hooks
		type_key_day_change => 'int',
		key_day_change => sub { my ($w, $m) = @_; $m->add_int(1); }, # Yes irssi prints "Day changed" lines
		type_key_clear => 'int',
		key_clear => sub { my ($w, $m) = @_; $m->add_int(1); }, # /clear allowed
		type_key_filter => 'int',
		key_filter => sub { my ($w, $m) = @_; $m->add_int(0); }, # no filters
		type_key_closing => 'int',
		key_closing => sub { my ($w, $m) = @_; $m->add_int(0); }, # not closing
		type_key_title => 'str',
		key_title => sub { my ($w, $m) = @_; my ($wi) = $w->items(); if (defined($wi)) { $m->add_string($wi->parse_special('$topic')); } else { $m->add_string(Irssi::parse_special('Irssi v$J - http://www.irssi.org')); } },
		type_key_time_for_each_line => 'int',
		key_time_for_each_line => sub { my ($w, $m) = @_; $m->add_int(Irssi::settings_get_bool("timestamps")); },
		type_key_chat_refresh_needed => 'int',
		key_chat_refresh_needed => sub { my ($w, $m) = @_; $m->add_int(0); }, # Not sure what to do here
		type_key_nicklist => 'int',
		key_nicklist => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->items();
			if (defined($wi) && $wi->{type} eq "CHANNEL") { $m->add_int(1); }
			else { $m->add_int(0); }
		},
		type_key_nicklist_case_sensitive => 'int',
		key_nicklist_case_sensitive => sub { my ($w, $m) = @_; $m->add_int(0); },
		type_key_nicklist_max_length => 'int',
		key_nicklist_max_length => sub { my ($w, $m) = @_; $m->add_int(65535); }, # Theoretically unlimited, since irssi knows how malloc works
		type_key_nicklist_display_groups => 'int',
		key_nicklist_display_groups => sub { my ($w, $m) = @_; $m->add_int(0); },
		type_key_nicklist_count => 'int',
		key_nicklist_count => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->items();
			if (defined($wi) && $wi->DOES("Irssi::Irc::Channel")) {
				$m->add_int(scalar(@{[$wi->nicks()]}));
			}
			else {
				$m->add_int(0);
			}
		},
		type_key_nicklist_groups_count => 'int',
		key_nicklist_groups_count => sub { my ($w, $m) = @_; $m->add_int(0); },
		type_key_nicklist_nicks_count => 'int',
		key_nicklist_nicks_count => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->items();
			if (defined($wi) && $wi->DOES("Irssi::Irc::Channel")) {
				$m->add_int(scalar(@{[$wi->nicks()]}));
			}
			else {
				$m->add_int(0);
			}
		},
		type_key_nicklist_visible_count => 'int',
		key_nicklist_visible_count => sub {
			my ($w, $m) = @_;
			my ($wi) = $w->items();
			if (defined($wi) && $wi->DOES("Irssi::Irc::Channel")) {
				$m->add_int(scalar(@{[$wi->nicks()]}));
			}
			else {
				$m->add_int(0);
			}
		},
		type_key_input => 'int',
		key_input => sub { my ($w, $m) = @_; $m->add_int(1); },
		type_key_input_get_unknown_commands => 'int',
		key_input_get_unknown_commands => sub { my ($w, $m) = @_; $m->add_int(0); },
		type_key_input_buffer => 'str',
		key_input_buffer => sub { my ($w, $m) = @_; $m->add_string(Irssi::parse_special('$L')); },
		type_key_input_buffer_alloc => 'int',
		type_key_input_buffer_size => 'int',
		type_key_input_buffer_length => 'int',
		type_key_input_buffer_pos => 'int',
		type_key_input_buffer_1st_display => 'int',
		type_key_input_undo_count => 'int',
		type_key_num_history => 'int',
		type_key_text_search => 'int',
		type_key_text_search_exact => 'int',
		type_key_text_search_regex => 'int',
		type_key_text_search_regex_compiled => 'int',
		type_key_text_search_where => 'int',
		type_key_text_search_found => 'int',
		type_key_text_search_input => 'str',
		type_key_highlight_words => 'str',
		type_key_highlight_regex => 'int',
		type_key_highlight_regex_compiled => 'int',
		type_key_highlight_tags_restrict => 'str',
		type_key_highlight_tags_restrict_count => 'int',
		type_key_highlight_tags_restrict_array => 'arr',
		type_key_highlight_tags => 'str',
		type_key_highlight_tags_count => 'int',
		type_key_highlight_tags_array => 'arr',
		type_key_hotlist_max_level_nicks => 'int',
		type_key_keys_count => 'int',
		type_key_local_variables => 'htb',
		key_local_variables => sub {
			my ($w, $m) = @_;
			my $wi = $w->{active};
			my %locals = (
				plugin => 'irc'
			);
			if (defined $wi) {
				$locals{server} = $wi->{server}->{address};
				if ($wi->DOES("Irssi::Irc::Channel")) { $locals{type} = "channel"; }
				elsif ($wi->DOES("Irssi::Irc::Query")) { $locals{type} = "private"; }
			}
			$m->add_type("str");
			$m->add_type("str");
			$m->add_int(scalar keys %locals);
			for my $k (keys %locals) {
				my $v = $locals{$k};
				$m->add_string($k);
				$m->add_string($v);
			}
		},
	},
	# TODO TODO TODO What the heck is hotlist? For now returning empties.
	hotlist => {
		list_gui_hotlist => sub {
			my ($ct) = @_;
			return grep { $_->{data_level} > 0 } Irssi::windows();
		},
		get_pointer => sub {
			my ($w) = @_; # Irssi::Window
			return $w->{_irssi};
		},
		from_pointer => sub {
			my ($p) = @_;
			my @w = Irssi::windows();
			my ($w) = grep { $_->{_irssi} == $p } @w;
			return $w;
		},
		type_key_priority => 'int',
		key_priority => sub {
			my ($w, $m) = @_;
			if ($w->{data_level} == 1) { # DATA_LEVEL_TEXT
				$m->add_int(0); # GUI_HOTLIST_LOW
			}
			elsif ($w->{data_level} == 2) { # DATA_LEVEL_MSG
				$m->add_int(1); # GUI_HOTLIST_MESSAGE
			}
			elsif ($w->{data_level} == 3) { # DATA_LEVEL_HILIGHT
				$m->add_int(3); # GUI_HOTLIST_HIGHLIGHT
			}
			else {
				$m->add_int(0); # GUI_HOTLIST_LOW
			}
		},
		type_key_creation_time => 'tim',
		key_creation_time => sub {
			my ($w, $m) = @_;
			$m->add_string_shortlength(sprintf("%d", $w->{last_line}));
		},
		type_key_buffer => 'ptr',
		key_buffer => sub {
			my ($w, $m) = @_;
			$m->add_ptr($w->{_irssi});
		},
		type_key_count => 'arr',
		key_count => sub {
			my ($w, $m) = @_;
			$m->add_type("int");
			$m->add_int(4);
			$m->add_int($w->{data_level} == 1 || 0); # || 0 looks odd until you remember that "false" from > is "" not 0.
			$m->add_int($w->{data_level} == 2 || 0); # || 0 looks odd until you remember that "false" from > is "" not 0.
			$m->add_int(0);
			$m->add_int($w->{data_level} == 3 || 0); # || 0 looks odd until you remember that "false" from > is "" not 0.
		},
	},
	lines => {
		sublist_first_line => sub {
			my ($buf, $ct) = @_;
			my $l = $buf->{first_line};
			my @l = ([$buf, $l]);
			if ($ct eq '*')
			{
				while (defined($l = $l->next()))
				{
					push @l, ([$buf, $l]);
				}
			}
			elsif ($ct < 0)
			{
				while ($ct < 0)
				{
					++$ct;
					$l = $l->prev();
					$l//last;
					push @l, ([$buf, $l]);
				}
			}
			else
			{
				while ($ct > 0)
				{
					$l = $l->next();
					$l//last;
					--$ct;
					push @l, ([$buf, $l]);
				}
			}
			return @l;
		},
		get_pointer => sub {
			my ($v) = @_;
			return $v->{_irssi};
		},
		from_pointer => sub {
			my ($ptr) = @_;
			my @w = Irssi::windows();
			my @v = map { $_->view(); } @w;
			my ($v) = grep { $_->{_irssi} == $ptr } @v;
			return $v;
		},
		type_sublist_first_line => 'line',
		sublist_last_line => sub {
			my ($buf, $ct) = @_;
			my $l = $buf->{cur_line};
			$l//return ;
			my @l = ([$buf, $l]);
			if ($ct eq '*')
			{
				while (defined($l = $l->next()))
				{
					push @l, ([$buf, $l]);
				}
			}
			elsif ($ct < 0)
			{
				while ($ct < 0)
				{
					++$ct;
					$l = $l->prev();
					$l//last;
					push @l, ([$buf, $l]);
				}
			}
			else
			{
				while ($ct > 0)
				{
					$l = $l->next();
					$l//last;
					--$ct;
					push @l, ([$buf, $l]);
				}
			}
			return @l;
		},
		type_sublist_last_line => 'line',
		sublist_last_read_line => sub {
			my ($buf, $ct) = @_;
			my $l = $buf->{cur_line};
			my @l = ([$buf, $l]);
			if ($ct eq '*')
			{
				while (defined($l = $l->next()))
				{
					push @l, ([$buf, $l]);
				}
			}
			elsif ($ct < 0)
			{
				while ($ct < 0)
				{
					++$ct;
					$l = $l->prev();
					$l//last;
					push @l, ([$buf, $l]);
				}
			}
			else
			{
				while ($ct > 0)
				{
					$l = $l->next();
					$l//last;
					--$ct;
					push @l, ([$buf, $l]);
				}
			}
			return @l;
		},
		type_sublist_last_read_line => 'line',
		type_key_lines_count => 'int',
		key_lines_count => sub {
			my ($buf, $m) = @_;
			$m->add_int($buf->{lines_count});
			return;
		},
		type_key_first_line_not_read => 'int',
		key_first_line_not_read => sub {
			my ($buf, $m) = @_;
			$m->add_int(0);
		},
		type_key_lines_hidden => 'int',
		key_lines_hidden => sub {
			my ($buf, $m) = @_;
			$m->add_int(0);
		},
		type_key_buffer_max_length => 'int',
		key_buffer_max_length => sub {
			my ($buf, $m) = @_;
			$m->add_int(65536); # Arbitrary
		},
		type_key_buffer_max_length_refresh => 'int',
		type_key_prefix_max_length => 'int',
		key_prefix_max_length => sub {
			my ($buf, $m) = @_;
			$m->add_int(65536); # Arbitrary
		},
		type_key_prefix_max_length_refresh => 'int',
	},
	line => {
		sublist_data => sub {
			my ($bl, $ct) = @_;
			return $bl;
		},
		get_pointer => sub {
			my ($bl) = @_;
			my ($buf, $l) = @$bl;
			return $l->{_irssi};
		},
		from_pointer => sub {
			my ($ptr) = @_;
			if (exists($line_ptr_cache{$ptr})) { return $line_ptr_cache{$ptr}; }
			my @w = Irssi::windows();
			my @b = map { $_->view()->{buffer} } @w;
			for my $buf (@b) {
				for (my $l = $b->{first_line}; defined($l); $l = $l->next()) {
					if ($l->{_irssi} eq $ptr) {
						return [$buf, $l];
					}
				}
			}
			return undef;
		},
		type_sublist_data => 'line_data',
	},
	line_data => {
		get_pointer => sub {
			my ($bl, $ct) = @_;
			my ($buf, $l) = @$bl;
			return $l->{_irssi};
		},
		from_pointer => sub {
			my ($ptr) = @_;
			if (exists($line_ptr_cache{$ptr})) { return $line_ptr_cache{$ptr}; }
			my @w = Irssi::windows();
			my @b = map { $_->view()->{buffer} } @w;
			for my $buf (@b) {
				for (my $l = $b->{first_line}; defined($l); $l = $l->next()) {
					if ($l->{_irssi} eq $ptr) {
						return [$buf, $l];
					}
				}
			}
			return undef;
		},
		type_key_buffer => 'ptr',
		key_buffer => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			my @w = Irssi::windows();
			my ($w) = grep { $_->view()->{buffer}->{_irssi} == $buf->{_irssi} } @w;
			$m->add_ptr($w->{_irssi});
		},
		#type_key_y => 'int',
		#key_y => sub { my ($l, $m) = @_; $m->add_int(uhIdunno); },
		type_key_date => 'tim',
		key_date => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			$m->add_string_shortlength($l->{info}->{time});
		},
		type_key_date_printed => 'tim',
		key_date_printed => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			$m->add_string_shortlength($l->{info}->{time});
		},
		#type_key_str_time => 'str',
		#type_key_tags_count => 'int',
		#type_key_tags => 'arr',
		type_key_displayed => 'chr',
		key_displayed => sub { my ($bl, $m) = @_; $m->add_chr(1); },
		type_key_highlight => 'chr',
		key_highlight => sub { my ($bl, $m) = @_; $m->add_chr(0); },
		type_key_refresh_needed => 'chr',
		key_refresh_needed => sub { my ($bl, $m) = @_; $m->add_chr(0); },
		type_key_prefix => 'str',
		key_prefix => sub {
			# try and extract the sender's nickname out of the line..
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			my $txt = $l->get_text(1);

			# strip the timestamp (if we know how)
			defined($tsrx) and $txt =~ s/^${tsrx}\s*//;

			my ($pfx, $msg) = separate_message_and_prefix($txt);
			$pfx = format_irssi_to_weechat($pfx);

			$m->add_string($pfx);
		},
		type_key_prefix_length => 'int',
		key_prefix_length => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			my $txt = $l->get_text(1);

			defined($tsrx) and $txt =~ s/^${tsrx}\s*//;
			my ($pfx, $msg) = separate_message_and_prefix($txt);
			$pfx = format_irssi_to_weechat($pfx);

			$m->add_int(length $pfx);
		},
		type_key_message => 'str',
		key_message => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			my $txt = $l->get_text(1); # WE NOW ARE RETURNING LINES WITH COLORS!!!

			# strip the timestamp (if we know how)
			defined($tsrx) and $txt =~ s/^${tsrx}\s*//;

			# also strip the nickname prefix (we send this seperately, in key_prefix)
			# TODO: isupport
			#$txt =~ s/^<[ ~&@%+]*([^ ]+)> //; # if you change this, also change key_prefix.
			#$txt =~ s/^\* ([^ ]+) //;

			my ($pfx, $msg) = separate_message_and_prefix($txt);

			$msg = format_irssi_to_weechat($msg);
			
			my $once = 0;
			$msg =~ s/[\cC\cD\c_\cB\cV\cO]/$once||=do{logmsg("WARNING: THERE ARE STILL IRSSI CODES IN THIS MESSAGE! $msg");1;}; "";/ge;

			$m->add_string($msg);
		},
		type_key_tags_array => 'arr',
		key_tags_array => sub {
			my ($bl, $m) = @_;
			my ($buf, $l) = @$bl;
			$m->add_type('str');
			my @tags;
			my $lvl = $l->{info}->{level};
			my $msglvl = Irssi::settings_get_level("activity_hilight_level") | Irssi::settings_get_level("activity_msg_level");
			# This is a good choice because its default is MSGS DCCMSGS
			my $privlvl = Irssi::settings_get_level('activity_hilight_level');
			my $nolvl = Irssi::settings_get_level('activity_hide_level');
			(($lvl & $privlvl) != 0) and push @tags, "notify_private";
			(($lvl & $msglvl) != 0) and push @tags, "notify_message";
			(($lvl & $nolvl) != 0) and push @tags, "notify_none";
			(($lvl & Irssi::MSGLEVEL_HILIGHT) != 0) and push @tags, "notify_highlight";

			$m->add_int(scalar @tags);
			$m->add_string($_) for @tags;
		},
	},
);

sub parse_hdata {
	use integer;
	# IMPORTANT: $client CAN BE UNDEFINED - THIS IS DONE IN THE EVENT HANDLERS
	# WHEN THIS HAPPENS WE *RETURN* THE BUILT RESPONSE MESSAGE INSTEAD OF SENDING IT.
	my ($client, $id, @arguments) = @_;

    # OK Gory details of what an hdata path looks like:
    # The first token before the : is the "root class"
    #   For example, buffer is the buffer class which describes window contents, input, nicklist
    # Right after comes either a pointer giving a specific object or a list
    #   For example, the gui_buffers list is all buffers currently in view
    # Then, comes a /-delimited list of sub-members to drill down an object tree. For example,
    #   /lines/first_line(*)/data
    #   lines is the lines member of the buffer class, which is of type lines, then
    #   first_line is the first_line member of the lines class which is of type line, then
    #   data is the data member of the line class which is of type line_data
    # After that is a space and a list of properties.
    # In place of the root list, a pointer can be used to start from a particular object.
    # For a list, an integer in () implements list iteration.
    #   +N gives the next N items,
    #   -N gives the previous N items,
    #   * is basically "the rest of the list". The example shows ussing (*) on first_line but
    #   first_line isn't a list, so really it gets treated like "a list of one"

        return unless @arguments > 0;
	my $arguments = pop @arguments;

	my $count = () = $arguments =~ /(.+):([^ ]+)( (.+))?/;
	if ($count eq 0) {
		logmsg("Bad HDATA request: $arguments");
		return;
	}

	my $hclass = $1;
	my $path = $2;
	my @keys = grep /./, split /,/, ($4//"");

	my $cls = $hdata_classes{$hclass};

	$cls//do{
		    logmsg("Unknown HDATA class: $hclass");
		    return;
	};

	my ($objstr, $ct);
	($objstr, $ct, $path) = hpath_tok($path);

	my @objs;

	if (scalar(@arguments) > 0)
	{
		logmsg("Got a internal HDATA for $path from objects of $hclass with keys @keys");
		@objs = map { sprintf("%016x", $cls->{get_pointer}->($_)) => $_ } @arguments;
	}
	elsif ($objstr =~ m/^0x/)
	{
		logmsg("Got a HDATA for $path from pointer $objstr of $hclass with keys @keys");
		# Pointer value
		no warnings 'portable'; # I MEAN IT
		my $objptr = hex($objstr);
		exists $cls->{from_pointer} or do {
			logmsg("Class $hclass can't retrieve objects from pointers.");
			return;
		};
		my $obj = ($cls->{from_pointer}->($objptr));
		$obj//do{
			logmsg("Object reference $objstr was not recognized by $hclass.");
			return;
		};
		my $ptr = sprintf("%016x", ($cls->{get_pointer}->($obj)));
		@objs = ($ptr => $obj);
	}
	else
	{
		exists $cls->{"list_$objstr"} or do {
			logmsg("List $objstr not defined for $hclass");
			return;
		};
		logmsg("Got a HDATA for $ct $path from list $objstr from $hclass with keys @keys");
		my @obj = ($cls->{"list_$objstr"}->($ct));
		# We can technically legitimately return no objects on some lists.
		#unless (@obj) {
		#		logmsg("No objects returned for list $objstr from $hclass");
		#		return;
		#}
		for my $obj (@obj) {
			my $ptr = sprintf("%016x", ($cls->{get_pointer}->($obj)));
			push @objs, ($ptr => $obj);
		}
	}

	while ($path ne '')
	{
		my @results;
		($objstr, $ct, $path) = hpath_tok($path);
		my $s = $cls->{"sublist_$objstr"};
		my $st = $cls->{"type_sublist_$objstr"};
		$s//do {
			logmsg("No sublist $objstr in $hclass");
			return;
		};
		$st//do {
			logmsg("Don't know type of items in sublist $objstr in $hclass");
			return;
		};
		$hclass .= "/" . $st;
		my $newcls = $hdata_classes{$st};
		$newcls//do {
			logmsg("Don't recognize type $st of items in sublist $objstr in $hclass");
			return;
		};
		for (my $oix = 0; $oix < scalar(@objs); $oix += 2)
		{
			my $ptr = $objs[$oix];
			my $obj = $objs[$oix + 1];
			my @r = $s->($obj, $ct);
			for my $r (@r)
			{
				my $newp = $ptr . "/" . sprintf("%016x", ($newcls->{get_pointer}->($r)));
				#logmsg($newp);
				push @results, ($newp => $r);
			}
		}
		$cls = $newcls;
		@objs = @results;
	}

	my @keytypes;

	if (@keys < 1)
	{
		#logmsg("Getting all keys from $hclass");
		@keys = map { /^key_(.*)$/ && $1 } grep { /^key_/ && exists $cls->{"type_$_"} } keys %$cls;
		#logmsg("Keys: @keys");
	}
	else
	{
		@keys = grep { exists $cls->{"key_$_"} && exists $cls->{"type_key_$_"} } @keys;
		#logmsg("Actual defined keys: @keys");
	}

	@keytypes = map { $_ . ":" . $cls->{"type_key_$_"} } @keys;

	my $m = new WeechatMessage;

	$m->add_string($id);
	$m->add_type("hda");
	$m->add_string($hclass);
	$m->add_string(join ",", @keytypes);
	$m->add_int((scalar @objs)/2);

	for (my $oix = 0; $oix < scalar(@objs); $oix += 2)
	#for my $ptr (keys %objs)
	{
		my $ptr = $objs[$oix];
		# Add the p-path
		my @ppath = split /\//, $ptr;
		my $obj = $objs[$oix + 1];
		for my $pptr (@ppath)
		{
			no warnings 'portable'; # I MEAN IT.
			$m->add_ptr(hex($pptr));
		}
		for my $k (@keys)
		{
			$cls->{"key_$k"}->($obj, $m);
		}
	}

	if (defined($client))
	{
		sendto_client($client, $m->get_buffer());
		return;
	}
	else
	{
		return $m;
	}
}

sub get_window_from_weechat_name
{
	my ($name) = @_;
	#key_full_name => sub { my ($w, $m) = @_; my ($wi) = $w->items(); if(defined($wi)) { my $s = $wi->{server}; $m->add_string('irc.' . $s->{address} . "." . $wi->{name}); } else { $m->add_string('irc.' . $w->{name}); } },
	for my $w (Irssi::windows())
	{
		my @wi = $w->items();
		for my $wi (@wi)
		{
			my $s = $wi->{server};
			if ($name eq 'irc.' . $s->{address} . "." . $wi->{name}) {
				return $w;
			}
		}
		if ($name eq 'irc.' . $w->{name})
		{
			return $w;
		}
		if ($name eq 'noname.nameless-' . $w->{refnum})
		{
			return $w;
		}
	}
	return undef;
}

sub parse_input
{
	my ($client, $id, $arguments) = @_;
	my ($target, $input);
	if ($arguments =~ m/^([^ ]+) (.*)$/)
	{
		($target, $input) = ($1, $2);
	}
	else
	{
		logmsg("Bad INPUT message");
	}
	my $buf;
	if ($target =~ m/^0x/)
	{
		use integer;
		no warnings 'portable'; # I MEAN IT
		my $ptr = hex($target);
		$buf = $hdata_classes{buffer}->{from_pointer}->($ptr);
	}
	elsif ($target eq 'core.weechat') {
		logmsg("Intercepting core.weechat command: $input");
		# Intercept commands sent to core.weechat and emulate (some of) them:
		if ($input =~ m[^/buffer (.*)]) {
			$buf = get_window_from_weechat_name($1);
			Irssi::signal_emit("window dehilight", $buf);
		}
		return;
	}
	else
	{
		$buf = get_window_from_weechat_name($target);
	}
	my $oldw = Irssi::active_win();
	$buf//return;
	if ($input =~ m[^(/buffer set hotlist -1|/input set_unread_current_buffer)]) {
		Irssi::signal_emit("window dehilight" => $buf);
		return;
	}
	# Remove -noswitch from /join,/query
	$input =~ s{^(/(join|query)) -noswitch}{};
	$buf->set_active();
	#$buf->command($input);
	my $s = $buf->{active_server};
	my $wi = $buf->{active};
	Irssi::signal_emit("send command", $input, $s, $wi);
	if (($buf->{_irssi} == Irssi::active_win()->{_irssi}) && (grep { $_->{_irssi} == $oldw->{_irssi} } Irssi::windows())) {
		$oldw->set_active();
	}
}

my %subscribers;

sub parse_sync {
	my ($client, $id, $arguments) = @_;
	my ($buffer, %events);
	if ($arguments =~ m/^\s*$/)
	{
		$buffer = '*';
		%events = (buffers => 1, upgrade => 1, buffer => 1, nicklist => 1);
	}
	elsif ($arguments =~ m/^([^ ]+)$/)
	{
		$buffer = $1;
		if ($buffer eq '*')
		{
			%events = (buffers => 1, upgrade => 1, buffer => 1, nicklist => 1);
		}
		else
		{
			%events = (buffer => 1, nicklist => 1);
		}
	}
	elsif ($arguments =~ m/^([^ ]+) ([^ ]+)/)
	{
		$buffer = $1;
		%events = map { $_ => 1 } split /,/, $2;
	}
	if ($buffer ne "*")
	{
		my $w = get_window_from_weechat_name($buffer);
		$w//return;
		$buffer = $w->{_irssi};
	}

	for my $evt (keys %events)
	{
		if ($events{$evt})
		{
			logmsg("Subscribing $client to $evt from $buffer");
			$subscribers{$evt}->{$buffer}->{$client} = $client;
		}
	}
}

sub parse_desync {
	my ($client, $id, $arguments) = @_;
	my ($buffer, %events);
	if ($arguments =~ m/^\s*$/)
	{
		$buffer = '*';
		%events = (buffers => 1, upgrade => 1, buffer => 1, nicklist => 1);
	}
	elsif ($arguments =~ m/^([^ ]+)$/)
	{
		$buffer = $1;
		if ($buffer eq '*')
		{
			%events = (buffers => 1, upgrade => 1, buffer => 1, nicklist => 1);
		}
		else
		{
			%events = (buffer => 1, nicklist => 1);
		}
	}
	elsif ($arguments =~ m/^([^ ]+) (.*)$/)
	{
		$buffer = $1;
		%events = map { $_ => 1 } split /,/, $2;
	}
	if ($buffer ne "*")
	{
		my $w = get_window_from_weechat_name($buffer);
		$w//return;
		$buffer = $w->{_irssi};
	}

	for my $evt (keys %events)
	{
		if ($events{$evt})
		{
			logmsg("Unsubscribing $client from $evt from $buffer");
			delete $subscribers{$evt}->{$buffer}->{$client};
		}
	}
}

sub dispatch_event_message
{
	my ($msg, @targets) = @_;

	my $data = $msg->get_buffer();

	my %clients = ();

	while (@targets > 0)
	{
		my $event = shift @targets;
		my $buffer = shift @targets;
		$buffer//="*";
		if (exists $subscribers{$event})
		{
			if (exists $subscribers{$event}->{"*"})
			{
				for my $k (keys %{$subscribers{$event}->{'*'}}) {
					$clients{$k} = $subscribers{$event}->{'*'}->{$k};
				}
			}
			if ($buffer ne '*' && exists $subscribers{$event}->{$buffer})
			{
				for my $k (keys %{$subscribers{$event}->{$buffer}}) {
					$clients{$k} = $subscribers{$event}->{$buffer}->{$k};
				}
			}
		}
	}

	logmsg("Dispatching to " . scalar(keys %clients) . " subscribers");

	for my $k (keys %clients)
	{
		my $cli = $clients{$k};
		sendto_client($cli, $data);
	}
}

sub desync_client {
	my ($client) = @_;
	for my $event (keys %subscribers)
	{
		for my $buffer (keys %{$subscribers{$event}})
		{
			delete $subscribers{$event}->{$buffer}->{$client};
		}
	}
}

sub parse_nicklist {
	use integer;
	my ($client, $id, $arguments) = @_;
	my @buf;
	my $bufarg;
	logmsg("Got NICKLIST for $arguments");
	if (ref($arguments) && $arguments->DOES("Irssi::UI::Window"))
	{
		$arguments->{_irssi} or do { Carp::cluck("Why is this undefined?"); };
		@buf = [$arguments, $arguments->{active}];
	}
	elsif (($bufarg) = ($arguments =~ m/^([^ ]+)/)) {
		if ($bufarg =~ m/^0x/) {
			use integer;
			no warnings 'portable'; # I MEAN IT
			my $w = $hdata_classes{buffer}->{from_pointer}->(hex($bufarg));
			@buf = [$w, $w->{active}];
		} else {
			use integer;
			my $w = get_window_from_weechat_name($bufarg);
			@buf = [$w, $w->{active}];
		}
	}
	else
	{
		@buf = map { [$_, $_->{active}] } Irssi::windows();
	}
	my $m = WeechatMessage->new();
	$m->add_string($id);
	$m->add_type('hda');
	$m->add_string("buffer/nicklist_item");
	$m->add_string("group:chr,visible:chr,level:int,name:str,color:str,prefix:str,prefix_color:str");
	my $ctpos = $m->get_length();
	my $objct = 0;
	$m->add_int(0);
	for my $buf (@buf)
	{
		my ($w, $wi) = @$buf;
		unless (defined($wi) && $wi->DOES("Irssi::Irc::Channel"))
		{
			# Send an empty nicklist and go. We need this because if someone has channels and queries on a single window,
			# if they switch to a query we should push an empty nicklist.
			++$objct;
			my $ptr = $w->{_irssi};
			$ptr//do{Carp::cluck("Why is this undefined?"); next;};
			$m->add_ptr($w->{_irssi})->add_ptr($w->{_irssi}); # path
			$m->add_chr(1); # group
			$m->add_chr(0); # visible
			$m->add_int(0); # level
			$m->add_string("root")->add_string(undef)->add_string(undef)->add_string(undef);
			next;
		}
		my %nicks = map { $_->{nick} => $_ } $wi->nicks();
		my $pfxraw = $wi->{server}->isupport("PREFIX")//"(ov)@+";
		my (@pfx) = ($pfxraw =~ m/^\(([[:alpha:]]+)\)(.+)$/);
		length $pfx[0] == length $pfx[1] or logmsg("Imbalanced PREFIX alert!: $pfxraw");
		my $grpct = 0;
		# Add nicklist root
		++$objct;
		$m->add_ptr($w->{_irssi})->add_ptr($w->{_irssi}); # path
		$m->add_chr(1); # group
		$m->add_chr(0); # visible
		$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
		$m->add_string("root"); # name
		$m->add_string(undef); # color
		$m->add_string(undef); # prefix
		$m->add_string(undef); # prefix_color
		for (my $pfxidx = 0; $pfxidx < length $pfx[0]; ++$pfxidx) {
			my ($pltr, $psym) = map { substr $_, $pfxidx, 1 } @pfx;
			++$objct;
			$m->add_ptr($w->{_irssi})->add_ptr($wi->{_irssi} + $grpct);
			$m->add_chr(1); # group
			$m->add_chr(1); # visible
			$m->add_int(1); # level
			$m->add_string(sprintf("%03d|%s", $grpct, $pltr)); # name
			$m->add_string("weechat.color.nicklist_group"); # color
			$m->add_string(undef); # prefix
			$m->add_string(undef); # prefix_color
			$grpct++;
			my @pfxd = sort { $a cmp $b } keys %nicks;
			for my $n (@pfxd)
			{
				my $nick = $nicks{$n};
				$nick->{prefixes} =~ m/\Q$psym\E/ or next;
				delete $nicks{$n};
				++$objct;
				$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi});
				$m->add_chr(0); # group
				$m->add_chr(1); # visible
				$m->add_int(0); # level
				$m->add_string($nick->{nick}); # name
				$m->add_string(undef); # color
				$m->add_string($psym); # prefix
				$m->add_string(''); # prefix_color
			}
		}
		my @nopfx = sort { $a->{nick} cmp $b->{nick} } map { $nicks{$_} } keys %nicks;
		++$objct;
		$m->add_ptr($w->{_irssi})->add_ptr($wi->{_irssi} + 999);
		$m->add_chr(1); # group
		$m->add_chr(1); # visible
		$m->add_int(1); # level
		$m->add_string("999|..."); # name
		$m->add_string("weechat.color.nicklist_group"); # color
		$m->add_string(undef); # prefix
		$m->add_string(undef); # prefix_color
		for my $nick (@nopfx)
		{
			++$objct;
			$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi});
			$m->add_chr(0); # group
			$m->add_chr(1); # visible
			$m->add_int(0); # level
			$m->add_string($nick->{nick}); # name
			$m->add_string(undef); # color
			$m->add_string(''); # prefix
			$m->add_string(''); # prefix_color
		}
	}
	$m->set_int($ctpos, $objct);
	if (defined($client)) {
		sendto_client($client, $m->get_buffer());
	} else {
		return $m;
	}
}

sub process_message {
    my ($client, $message) = @_;

    my ($id, $command, $arguments);

    $message =~ s/\n$//;
    #logmsg("Processing: $message");

    # Commands have format: "(id) command arguments\n".

	if ($message =~ m/^\(([^\)]+)\) (.*)/) {
		($id, $message) = ($1, $2);
	}
	else {
		$id = undef;
	}

	($command, $arguments) = split / +/, $message, 2;

	$arguments//="";

=if0
    if ($message =~ /^\(([^ ]+)\) ([^ ]+) (.+)$/) {
        $id = $1;
        $command = $2;
        $arguments = $3;
    } elsif ($message =~ /^\(([^ ]+)\) ([^ ]+)$/) {
        # also handle optional arguments :)
        $id = $1;
        $command = $2;
    } else {
        logmsg("Got a bad message: $message");
        return
    }
=cut

		if ($command eq 'init') {
			parse_init($client, $id, $arguments);
			return;
		}

		# Drop the client if they don't send INIT first, or their INIT password was bad.
		if (!$clients{$client}->{authenticated}) {
			$client->finish();
		}
		elsif ($command eq 'info') {
			parse_info($client, $id, $arguments);
		}
		elsif ($command eq 'hdata') {
			logmsg("HDATA: $message");
			parse_hdata($client, $id, $arguments);
		}
		elsif ($command eq 'input') {
			parse_input($client, $id, $arguments);
		}
		elsif ($command eq 'sync') {
			parse_sync($client, $id, $arguments);
		}
		elsif ($command eq 'desync') {
			parse_desync($client, $id, $arguments);
		}
		elsif ($command eq 'quit') {
			desync_client($client);
			$client->finish();
			delete $clients{$client};
		}
		elsif ($command eq 'test') {
			my $m = WeechatMessage->new();
			$m->add_string($id);
			$m->add_type('chr')->add_chr(65);
			$m->add_type('int')->add_int(123456);
			$m->add_type('int')->add_int(-123456);
			$m->add_type('lon')->add_string_shortlength("1234567890");
			$m->add_type('lon')->add_string_shortlength("1234567890");
			$m->add_type('str')->add_string("a string");
			$m->add_type('str')->add_string("");
			$m->add_type('str')->add_string(undef);
			$m->add_type('buf')->add_string("buffer");
			$m->add_type('buf')->add_string(undef);
			$m->add_type('ptr')->add_string_shortlength("0x1234abcd");
			$m->add_type('ptr')->add_string_shortlength("0x0");
			$m->add_type('tim')->add_string_shortlength("1321993456");
			$m->add_type('arr')->add_type('str')->add_int(2)->add_string("abc")->add_string("def");
			$m->add_type('arr')->add_type('int')->add_int(3)->add_int(123)->add_int(456)->add_int(789);
			sendto_client($client, $m->get_buffer());
		}
		elsif ($command eq 'ping') {
			my $m = WeechatMessage->new();
			$m->add_string("_pong");
			$m->add_type('str');
			$m->add_string($arguments);
			sendto_client($client, $m->get_buffer());
		}
		elsif ($command eq 'nicklist') {
			parse_nicklist($client, $id, $arguments);
		}
		else {
			logmsg("Unhandled: $message");
			$id//="(null)";
			logmsg("ID: $id COMMAND: $command ARGS: $arguments");
		}
}

my $wants_hilight_message = {};

our $_ugh = 0;
sub gui_print_text_finished {
	$_ugh and return;
	local $_ugh = 1;
	eval {
	local $SIG{__WARN__} = \&logmsg;
    my ($window) = @_;
    my $ref = $window->{'refnum'}; 
    my $buf = $window->view()->{buffer};
    my $line = $buf->{cur_line};

    my $ptr = sprintf("%016x", $line->{_irssi});

    my $m = parse_hdata(undef, "_buffer_line_added", [$buf, $line], "line_data:0xINARGS");
    dispatch_event_message($m, buffer => $window->{_irssi});
    };
    if ($@) { logmsg("ERROR IN PRINT TEXT HANDLER !!! !!! !!! $@"); }
}

=pod
sub configure {
    my ($client, $event) = @_;
    my $chash = $clients{$client};

    for my $key (keys %{$event}) {
        if($key ne 'event') {
            $chash->{$key} = $event->{$key};
        }
    }
}
=cut

=todo
# These two relate to nicklist diffs. They have to be up here so window_destroyed can remove windows with pending nicklist changes.
# We're going to use a bit of irssi-like logic, where each change to the nicklist is held in a buffer for up to 2 seconds.
my $nickdiff_timertag = undef;
# Keyed by window {_irssi} value.
# Value is a list with nickrec {_irssi} value (which we need for pointer-path) and 
my %nickdiff_pending;
=cut

sub window_created {
    my $window = shift;
    use integer;

    my $m = parse_hdata(undef, "_buffer_opened", $window, "buffer:0xINARGS number,full_name,short_name,nicklist,title,local_variables,prev_buffer,next_buffer");

    dispatch_event_message($m, buffers => '*', buffer => $window->{_irssi});

    #sendto_all_clients({
    #  event => 'addwindow',
    #  window => "$window->{'refnum'}",
    #  name => $window->{name},
    #});
}

sub window_destroyed {
    my $window = shift;
    use integer;

    my $m = parse_hdata(undef, "_buffer_closing", $window, "buffer:0xINARGS number,full_name");

    dispatch_event_message($m, buffers => '*', buffer => $window->{_irssi});

    for my $evt (keys %subscribers)
    {
	    delete $subscribers{$evt}->{$window->{_irssi}}; # Auto-remove all window subscriptions
    }

#    delete $nickdiff_pending{$window->{_irssi}};

    # sendto_all_clients({
    #   event => 'delwindow',
    #   window => "$window->{'refnum'}",
    # });
}

sub window_activity {
    my ($window, $oldlevel) = @_;

    while (my ($client, $chash) = each %clients) {
        #sendto_client($chash->{'client'}, {
        #   event => 'activity',
        #    window => "$window->{'refnum'}",
        #     level => $window->{data_level},
#      oldlevel => $oldlevel,
#    });
    }
}

sub window_hilight {
    my $window = shift;
    $wants_hilight_message->{$window->{'refnum'}} = 1;
}

sub window_refnum_changed {
    my ($window, $oldnum) = @_;

    my $m = parse_hdata(undef, "_buffer_moved", $window, "buffer:0xINARGS number,full_name,prev_buffer,next_buffer");
    dispatch_event_message($m, buffers => '*', buffer => $window->{_irssi});

    #sendto_all_clients({
    #  event => 'renumber',
    #  old => $oldnum,
    #  cur => $window->{'refnum'},
#  });
}

sub window_item_name_changed {
	my ($witem) = @_;
	my $w = $witem->window();

	my $m = parse_hdata(undef, "_buffer_renamed", $w, "buffer:0xINARGS number,full_name,short_name,local_variables");
	dispatch_event_message($m, buffers => '*', buffer => $w->{_irssi});
	if ($w->DOES("Irssi::Irc::Query")) {
		$m = parse_hdata(undef, "_buffer_title_changed", $w, "buffer:0xINARGS number,full_name,title");
		dispatch_event_message($m, buffers => '*', buffer => $w->{_irssi});
	}
}

sub window_item_changed {
	my ($window, $witem) = @_;
	# First announce the window rename.
	my $m = parse_hdata(undef, "_buffer_renamed", $window, "buffer:0xINARGS number,full_name,short_name,local_variables");
	dispatch_event_message($m, buffers => '*', buffer => $window->{_irssi});
#	delete $nickdiff_pending{$window->{_irssi}};
	$m = parse_nicklist(undef, "_nicklist", $window);
	dispatch_event_message($m, nicklist => $window->{_irssi});
	$m = parse_hdata(undef, "_buffer_localvar_changed", $window, "buffer:0xINARGS number,full_name,local_variables");
	dispatch_event_message($m, buffers => '*', buffer => $window->{_irssi});
}

sub window_title_changed {
	my ($witem) = @_;
	my $w = $witem->window();
	my $m = parse_hdata(undef, "_buffer_title_changed", $w, "buffer:0xINARGS number,full_name,title");
	dispatch_event_message($m, buffers => '*', buffer => $w->{_irssi});
}

sub nicklist_add {
	my ($chan, $nick) = @_;
	my $w = $chan->window();
	my $psym = substr($nick->{prefixes}//"", 0, 1);
	my $pfxraw = $chan->{server}->isupport("PREFIX")//"(ov)@+";
	my (@pfx) = ($pfxraw =~ m/^\(([[:alpha:]]+)\)(.+)$/);
	length $pfx[0] == length $pfx[1] or logmsg("Imbalanced PREFIX alert!: $pfxraw");
	my $m = WeechatMessage->new();
	$m->add_string("_nicklist_diff");
	$m->add_type("hda");
	$m->add_string("buffer/nicklist_item");
	$m->add_string("_diff:chr,group:chr,visible:chr,level:int,name:str,color:str,prefix:str,prefix_color:str");
	$m->add_int(2);
	my $grpix = $psym ? index($pfx[1], $psym) : 999;
	$m->add_ptr($w->{_irssi})->add_ptr($chan->{_irssi} + $grpix); # path
	$m->add_chr(ord('^')); # diff code
	$m->add_chr(1); # group
	$m->add_chr(1); # visible
	$m->add_int(1); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string(sprintf("%03d|%s", $grpix, ($grpix == 999 ? "..." : substr($pfx[0], $grpix, 1)))); # name
	$m->add_string("weechat.color.nicklist_group"); # color
	$m->add_string(undef); # prefix
	$m->add_string(undef); # prefix_color
	$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi}); # path
	$m->add_chr(ord('+')); # diff code
	$m->add_chr(0); # group
	$m->add_chr(1); # visible
	$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string($nick->{nick}); # name
	$m->add_string(""); # color
	$m->add_string($psym); # prefix
	$m->add_string(undef); # prefix_color
	dispatch_event_message($m, nicklist => $w->{_irssi});
}

sub nicklist_remove {
	my ($chan, $nick) = @_;
	$chan->{left} and return; # nicklist removes fire off during channel teardown - skip them
	my $w = $chan->window();
	$w//return; # The above should've already covered this...
	my $psym = substr($nick->{prefixes}//"", 0, 1);
	my $pfxraw = $chan->{server}->isupport("PREFIX")//"(ov)@+";
	my (@pfx) = ($pfxraw =~ m/^\(([[:alpha:]]+)\)(.+)$/);
	length $pfx[0] == length $pfx[1] or logmsg("Imbalanced PREFIX alert!: $pfxraw");
	my $m = WeechatMessage->new();
	$m->add_string("_nicklist_diff");
	$m->add_type("hda");
	$m->add_string("buffer/nicklist_item");
	$m->add_string("_diff:chr,group:chr,visible:chr,level:int,name:str,color:str,prefix:str,prefix_color:str");
	$m->add_int(2);
	my $grpix = $psym ? index($pfx[1], $psym) : 999;
	$m->add_ptr($w->{_irssi})->add_ptr($chan->{_irssi} + $grpix); # path
	$m->add_chr(ord('^')); # diff code
	$m->add_chr(1); # group
	$m->add_chr(1); # visible
	$m->add_int(1); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string(sprintf("%03d|%s", $grpix, ($grpix == 999 ? "..." : substr($pfx[0], $grpix, 1)))); # name
	$m->add_string("weechat.color.nicklist_group"); # color
	$m->add_string(undef); # prefix
	$m->add_string(undef); # prefix_color
	$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi}); # path
	$m->add_chr(ord('-')); # diff code
	$m->add_chr(0); # group
	$m->add_chr(1); # visible
	$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string($nick->{nick}); # name
	$m->add_string(""); # color
	$m->add_string($psym); # prefix
	$m->add_string(undef); # prefix_color
	dispatch_event_message($m, nicklist => $w->{_irssi});
}

sub nicklist_change {
	my ($chan, $nick) = @_;
	my $w = $chan->window();
	my $psym = substr($nick->{prefixes}//"", 0, 1);
	my $pfxraw = $chan->{server}->isupport("PREFIX")//"(ov)@+";
	my (@pfx) = ($pfxraw =~ m/^\(([[:alpha:]]+)\)(.+)$/);
	length $pfx[0] == length $pfx[1] or logmsg("Imbalanced PREFIX alert!: $pfxraw");
	my $m = WeechatMessage->new();
	$m->add_string("_nicklist_diff");
	$m->add_type("hda");
	$m->add_string("buffer/nicklist_item");
	$m->add_string("_diff:chr,group:chr,visible:chr,level:int,name:str,color:str,prefix:str,prefix_color:str");
	$m->add_int(2);
	my $grpix = $psym ? index($pfx[1], $psym) : 999;
	$m->add_ptr($w->{_irssi})->add_ptr($chan->{_irssi} + $grpix); # path
	$m->add_chr(ord('^')); # diff code
	$m->add_chr(1); # group
	$m->add_chr(1); # visible
	$m->add_int(1); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string(sprintf("%03d|%s", $grpix, ($grpix == 999 ? "..." : substr($pfx[0], $grpix, 1)))); # name
	$m->add_string("weechat.color.nicklist_group"); # color
	$m->add_string(undef); # prefix
	$m->add_string(undef); # prefix_color
	$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi}); # path
	$m->add_chr(ord('*')); # diff code
	$m->add_chr(0); # group
	$m->add_chr(1); # visible
	$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string($nick->{nick}); # name
	$m->add_string(""); # color
	$m->add_string($psym); # prefix
	$m->add_string(undef); # prefix_color
	dispatch_event_message($m, nicklist => $w->{_irssi});
}

sub nickmode_change {
	my ($chan, $nick, $setby, $modestr, $typestr) = @_;
	my $w = $chan->window();
	my $pfxraw = $chan->{server}->isupport("PREFIX")//"(ov)@+";
	my (@pfx) = ($pfxraw =~ m/^\(([[:alpha:]]+)\)(.+)$/);
	length $pfx[0] == length $pfx[1] or logmsg("Imbalanced PREFIX alert!: $pfxraw");
	# Irssi will have already updated the ->{prefixes} value so we have no way to verify we aren't processing a duplicate change.
	# If the highest prefix is higher than the one corresponding to the changed mode, then nothing needs to be done:
	my $m = WeechatMessage->new();
	$m->add_string("_nicklist_diff");
	$m->add_type("hda");
	$m->add_string("buffer/nicklist_item");
	$m->add_string("_diff:chr,group:chr,visible:chr,level:int,name:str,color:str,prefix:str,prefix_color:str");
	$m->add_int(4);

	my $toppfx = $nick->{prefixes} ? substr($nick->{prefixes}//"", 0, 1) : undef;
	my $topidx = defined($toppfx) ? index($pfx[1], $toppfx) : undef;
	my $topmode = defined($topidx) ? substr($pfx[0], $topidx, 1) : undef;
	my $nextpfx = length($nick->{prefixes}) > 1 ? substr($nick->{prefixes}, 1, 1) : undef; # Space so perl doesn't warn of substr'ing too far
	my $nextidx = defined($nextpfx) ? index($pfx[1], $nextpfx) : undef;
	my $nextmode = defined($nextidx) ? substr($pfx[0], $nextidx, 1) : undef;
	my $chgpfx = $modestr;
	my $chgidx = index($pfx[1], $chgpfx);
	my $chgmode = substr($pfx[0], $chgidx, 1);

	my (@remove, @addto);

	if ($typestr eq '+') {
		$chgpfx eq ($toppfx//"") or return; # If the top prefix isn't what we just added, nothing needs to be done.
		if (!defined($nextpfx)) {
			@remove = (999, "...", "");
		} else {
			@remove = ($nextidx, $nextmode, $nextpfx);
		}
		@addto = ($topidx, $topmode, $toppfx);
	} else {
		@remove = ($chgidx, $chgmode, $chgpfx);
		if (!defined($topidx)) {
			@addto = (999, "...", "");
		} else {
			$chgidx < $topidx or return; # If removed prefix is not higher than the top-most prefix, nothing needs to be done.
			@addto = ($topidx, $topmode, $toppfx);
		}
	}

	my ($remove_idx, $remove_mode, $remove_pfx) = @remove;
	my ($add_idx, $add_mode, $add_pfx) = @addto;

	$m->add_ptr($w->{_irssi})->add_ptr($chan->{_irssi} + $remove_idx); # path
	$m->add_chr(ord('^')); # diff code
	$m->add_chr(1); # group
	$m->add_chr(1); # visible
	$m->add_int(1); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string(sprintf("%03d|%s", $remove_idx, $remove_mode)); # group name
	$m->add_string("weechat.color.nicklist_group"); # color
	$m->add_string(undef); # prefix
	$m->add_string(undef); # prefix_color
	$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi}); # path
	$m->add_chr(ord('-')); # diff code
	$m->add_chr(0); # group
	$m->add_chr(1); # visible
	$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string($nick->{nick}); # name
	$m->add_string(""); # color
	$m->add_string($remove_pfx); # prefix
	$m->add_string(undef); # prefix_color
	# Remove from the lesser prefix
	my $chgpidx = index($pfx[0], $modestr);
	$m->add_ptr($w->{_irssi})->add_ptr($chan->{_irssi} + $add_idx); # path
	$m->add_chr(ord('^')); # diff code
	$m->add_chr(1); # group
	$m->add_chr(1); # visible
	$m->add_int(1); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string(sprintf("%03d|%s", $add_idx, $add_mode)); # group name
	$m->add_string("weechat.color.nicklist_group"); # color
	$m->add_string(undef); # prefix
	$m->add_string(undef); # prefix_color
	$m->add_ptr($w->{_irssi})->add_ptr($nick->{_irssi}); # path
	$m->add_chr(ord('+')); # diff code
	$m->add_chr(0); # group
	$m->add_chr(1); # visible
	$m->add_int(0); # level (0 for root and all nicks, 1 for all other groups)
	$m->add_string($nick->{nick}); # name
	$m->add_string(""); # color
	$m->add_string($add_pfx); # Prefix
	$m->add_string(undef); # prefix_color
	dispatch_event_message($m, nicklist => $w->{_irssi});
}

Irssi::signal_add("gui print text finished" => \&gui_print_text_finished);

Irssi::signal_add("window created" => \&window_created);
Irssi::signal_add("window destroyed" => \&window_destroyed);
Irssi::signal_add("window activity" => \&window_activity);
Irssi::signal_add_first("window hilight" => \&window_hilight);
Irssi::signal_add("window refnum changed" => \&window_refnum_changed);
Irssi::signal_add_last("window item name changed" => \&window_item_name_changed);
Irssi::signal_add_last("query address changed" => \&window_title_changed);
Irssi::signal_add_last("channel topic changed" => \&window_title_changed);
Irssi::signal_add_last("window item changed" => \&window_item_changed);
Irssi::signal_add_last("nicklist new" => \&nicklist_add);
Irssi::signal_add_last("nicklist remove" => \&nicklist_remove);
Irssi::signal_add_last("nicklist chnaged" => \&nicklist_change);
Irssi::signal_add_last("nick mode changed" => \&nickmode_change);

Irssi::signal_add("setup changed", \&setup_changed);

sub UNLOAD {
	demojoify();
	Symbol::delete_package("WeechatMessage");
}
