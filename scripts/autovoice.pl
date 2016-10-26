#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
	unless (exists $::{"Irssi::"}) {
		require Pod::Usage;
		Pod::Usage::pod2usage(-verbose => 2);
	} 
}

use Irssi;
our $VERSION = '0.05';
our %IRSSI = (
		authors => 'aluser',
		name => 'autovoice',
		description => 'autovoice',
		license => 'GPL',
	);

our %bad;

=head1 SYNOPSIS

	/script load autovoice
	/autovoice add #somechannel
Idle on #somechannel as [half]op, and you will voice people :)

=head1 MOTIVATION

This is certainly not a new concept, but I dislike many implementations of autovoicing because they are not as intelligent as they could be.  Blindly voicing everyone who joins your channel is dumb, because it removes the protection that +m is supposed to give you.  A troublemake need merely to rejoin the channel to get his voice back.  You probably want to voice newcomers to your channel, so a password or hostmask system is no good.  Besides, it's intuitive that anybody leaving the channel without voice and quickly rejoining is trying to leverage your autovoicer!  So, the main purpose of this script is to automatically detect these people and not voice them.

The other important feature is fine-grained control over where you voice people.  You might want to autovoice in efnet #foo but not in dalnet #foo.  The C</autovoice add> command gives you C<-server> and C<-ircnet> options to control on which channels you will autovoice, even if the channels have identical names.

I still consider this script to be lightly tested, but I do hope that it is well documented enough that it can be debugged well.

=head1 INSTALL

Just place this script in F<~/.irssi/scripts>.  To have it load automatically when you start Irssi, do this:

	mkdir -p ~/.irssi/scripts/autorun
	ln -s ../autovoice.pl ~/.irssi/scripts/autorun/

If you haven't figured it out yet, you can run the script outside of Irssi to get a man page type document, like this:

	chmod +x autovoice.pl
	./autovoice.pl

=head1 COMMANDS

=over

=item I</autovoice add>

This is a helper to add channels to L<autovoice_channels> for you.
I'm going to explain this by example:

	/autovoice add #channelfoo
	/autovoice add -server irc.foo.com #barbarfoo
	/autovoice add -ircnet EFNet #perlhelp
	/autovoice add -server irc.efnet.org -ircnet Undernet #irssi

Note that the last example actually adds two "channels" to the setting, both named #irssi.  The channel will be valid on Undernet or the server irc.efnet.org.

=item I</autovoice remove>

This is a helper to remove channels from L<autovoice_channels> for you.
Example:

	/autovoice remove #somechannel
	/autovoice remove #channel1 #channel2

=item I</autovoice dump>

Mostly for debugging, this dumps the perl hash containing blacklisted nicks to your screen.

=item I</autovoice flush>

Flush the blacklists.

=back

=head1 SETTINGS

=over

=item bool I<autovoice> = ON

Set autovoicing on or off.

=item string I<autovoice_channels> = 

Control which channels we will autovoice.  The simplest form is

	#channel1 , #channel2 , #channel3

Space before the commas is mandatory; after is optional.  For any channel in the list, you may specify a chatnet or a server like this:

	#channel1 , #channel2 =>SOMECHATNET , #channel3 @some.server.com

Space after the channels and before the C<< => >> or C<@> is required.  Space after the C<< => >> or C<@> is optional.  (not shown)

See L</autovoice add> and L</autovoice remove> for wrappers to this.

=item int I<autovoice_cycletime> = 600

Control the amount of time, in seconds, for which we remember that a nick left a channel without voice.

=item bool I<autovoice_voice_ops> = OFF

Whether or not to give voice to people who already have op or halfop

=item bool I<autovoice_use_ident> = OFF

Whether to distinguish between nicks which have the same host but different user names.  (nick![ident@host] vs nick!ident@[host])

=back

=cut


=head1 BUGS

Plenty.

=over

=item

&add will add duplicate channels

=item

Error checking in &add is weak.

=item

Setting L<autovoice_use_ident> causes the existing blacklists to be ineffective.

=item

C<parse_channels> and C<deparse_channels> mix up the ordering of the channels in the autovoice_channels setting.  This is a property of the hash used to represent the setting.

=item

remove doesn't let you remove only one channel when several use the same name.

=item

Setting L<autovoice_cycletime> does not change the timing for entries already in the badlist, only for entries made after the setting is changed.  As far as I can tell, the alternatives are to A) Have a potentially ever-growing %bad, or B) to run a cleanup on a timer which must traverse all of %bad.

=back

=cut


=head1 HACKING

This section is for people interested in tweaking/fixing/improving/developing/hacking this script.  It describes every subroutine and data structure in the script.  If you do not know Perl you should stop reading here.

Variables ending in C<_rec> are Irssi objects of some sort.  I also use C<_text> to indicate normal strings.

=head2 DATA STRUCTURES

=over

=item %bad

This hash holds the badlists for all channels.  Each key is a tag as supplied by C<$server_rec->{tag}>.  Each value is a hash reference as follows:

Each key is a lowercased channel name as given by C<< lc $channel_rec->{name} >> .  Each value is a hash referenc described as follows:

Each key is a lowercased host.  If the host was marked bad while autovoice_use_ident was set, it is in the form "username@host.com".  If not, it is just "host.com".  Each value is a tag as returned by C<Irssi::timeout_add>.  This is used to remove the callback which is planning to remove the entry from the badlist after autovoice_cycletime expires.

=item %commands

This hash holds the commands invoked as C<< /autovoice <command> [ arg1 arg2 ... ] >>.  Each key is the lowercased name of a command, and each value is a reference to a subroutine.  The subroutine should expect an Irssi Server object, a WindowItem object, and a list of user supplied arguments.  The case of the arguments is left as supplied by the user.

=back

=cut

=head2 SUBROUTINES

=over

=item I<massjoin($channel_rec, $nicks_ray)>

The nicks in the array referenced by $nicks_ray are joining $channel_rec.  This is an irssi signal handler.

=cut

sub massjoin {
	my ($channel_rec, $nicks_ray) = @_;
	voicem($channel_rec, @$nicks_ray);
}

=item I<message_part($server_rec, $channel_text, $nick_text, $addr, $reason)>

A nick is parting a channel.  $addr and $reason are not used.  This is an irssi signal handler.

=cut

sub message_part {
	my ($server_rec, $channel_text, $nick_text) = @_;
	#Irssi::print("chan: $channel_text, nick: $nick_text");
	#return unless defined $nick_text;	# happens if the part was us
	no warnings;
	my $channel_rec = $server_rec->channel_find($channel_text);
	use warnings;
	return unless defined $channel_rec;
	my $nick_rec = $channel_rec->nick_find($nick_text);
	partem($channel_rec, $nick_rec);
}

=item I<message_quit($server_rec, $nick_text, $addr, $reason)>

A nick is quiting the server.  $addr and $reason are not used.  This is an irssi signal handler.

=cut

sub message_quit {
	my ($server_rec, $nick_text, $addr, $reason) = @_;
	my $chanstring = $server_rec->get_channels();
	$chanstring =~ s/ .*//; #strip channel keys
	my @channels_text = split /,/, $chanstring;
	no warnings;
	my @channels_rec =
		map { $server_rec->channel_find($_) } @channels_text;
	use warnings;
	for (@channels_rec) {
		my $nick_rec = $_->nick_find($nick_text);
		if (defined $nick_rec) {
			partem($_, $nick_rec);
		}
	}
}

=item I<message_kick($server_rec, $channel_text, $nick_text, $addr, $reason)>

Called when a nick is kicked from a channel.  This is an Irssi signal handler.

=cut

sub message_kick {
	my ($server_rec, $channel_text, $nick_text) = @_;
	my $channel_rec = $server_rec->channel_find($channel_text);
	return unless defined $channel_rec;
	my $nick_rec = $channel_rec->nick_find($nick_text);
	partem($channel_rec, $nick_rec);
}

=item I<voicem($channel_rec, @nicks)>

This voices all of @nicks on $channel_rec, provided they aren't in the blacklist.

=cut

sub voicem {
	my ($channel_rec, @nicks) = @_;
	if (is_auto($channel_rec)) {
		for my $nick_rec (@nicks) {
			unless (is_bad($channel_rec, $nick_rec)
					or $nick_rec->{voice}) {
				if (get_voiceops() or
						!($nick_rec->{op} or $nick_rec->{halfop})) {
					my $nick_text = $nick_rec->{nick};
					$channel_rec->command("voice $nick_text");
				}
			}
		}
	}
}

=item I<partem($channel_rec, $nick_rec)>

Called when a nick is leaving a channel, by any means.  This is what decides whether the nick does or does not have voice.

=cut

sub partem {
	my ($channel_rec, $nick_rec) = @_;
	#$channel_rec->print("partem called");
	if (is_auto($channel_rec)) {
		#$channel_rec->print("this channel is autovoiced.");
		if (not $nick_rec->{voice} and
				not $nick_rec->{op} and
				not $nick_rec->{halfop}) {
			#$channel_rec->print("nick leaving with no voice");
			make_bad($channel_rec, $nick_rec);
		} else {
			make_unbad($channel_rec, $nick_rec);
		}
	}
}

=item I<is_bad($channel_rec, $nick_rec)>

Returns 1 if $nick_rec is blacklisted on $channel_rec, 0 otherwise.

=cut

sub is_bad {
	my ($channel_rec, $nick_rec) = @_;
	my $server_tag = $channel_rec->{server}->{tag};
	my $channel_text = lc $channel_rec->{name};
	my $host_text = lc $nick_rec->{host};
	if (not get_useident()) {
		$host_text =~ s/.*?\@//;
	}
	#$channel_rec->print("calling is_bad {$server_tag}{$channel_text}{$host_text}");
	return
		exists $bad{$server_tag} &&
		exists $bad{$server_tag}{$channel_text} &&
		exists $bad{$server_tag}{$channel_text}{$host_text};
}

=item I<make_bad($channel_rec, $nick_rec)>

Blacklist $nick_rec on $channel_rec for autovoice_cycletime seconds.

=cut

sub make_bad {
	my ($channel_rec, $nick_rec) = @_;
	my $tag = $channel_rec->{server}->{tag};
	my $channel_text = lc $channel_rec->{name};
	my $host_text = lc $nick_rec->{host};
	if (not get_useident()) {
		$host_text =~ s/.*?\@//;
	}
	#$channel_rec->print("channel_rec: ".ref($channel_rec)."nick_rec: ".ref($nick_rec).". make bad $tag, $channel_text, $host_text");
	Irssi::timeout_remove($bad{$tag}{$channel_text}{$host_text})
			if exists $bad{$tag}{$channel_text}{$host_text};
	$bad{$tag}{$channel_text}{$host_text} =
			Irssi::timeout_add(get_cycletime(),
							'timeout',
							[ $channel_rec, $nick_rec ]);
}

=item I<timeout([$channel_rec, $nick_rec])>

This is the irssi timeout callback which removes $nick_rec from the blacklist for $channel_rec when autovoice_cycletime seconds have elapsed.  make_unbad finds the tag in the badlist in order to keep this from being called again.  Note that it only takes one argument, an array ref

=cut

sub timeout {
	my ($channel_rec, $nick_rec) = @{$_[0]};
	#$channel_rec->print("timing out");
	make_unbad($channel_rec, $nick_rec);
}

=item I<make_unbad($channel_rec, $nick_rec)>

Remove $nick_rec from the blacklist for $channel_rec

=cut

sub make_unbad {
	my ($channel_rec, $nick_rec) = @_;
	my $tag = $channel_rec->{server}->{tag};
	my $channel_text = lc $channel_rec->{name};
	my $host_text = lc $nick_rec->{host};
	if (not get_useident()) {
		$host_text =~ s/.*\@//;
	}
	if (exists $bad{$tag}{$channel_text}{$host_text}) {
		Irssi::timeout_remove($bad{$tag}{$channel_text}{$host_text});
		delete $bad{$tag}{$channel_text}{$host_text};
		if (not keys %{$bad{$tag}{$channel_text}}) {
			delete $bad{$tag}{$channel_text};
		}
		if (not keys %{$bad{$tag}}) {
			delete $bad{$tag};
		}
	}
}

=item I<parse_channels()>

Examine autovoice_channels and return a hash reference.  Each key is a channel name, lowercased.  Each value is a hash with one to three keys, 'server', 'chatnet', and/or 'plain'.  If server, it holds an array ref with all servers on which the channel is autovoice.  If chatnet, it holds an array ref with all the chatnets on which the channel is autovoice.  If plain, it just has the value 1.

=cut

sub parse_channels {
	my $chanstring = lc Irssi::settings_get_str('autovoice_channels');
	$chanstring =~ s/^\s+//;
	$chanstring =~ s/\s+$//;
	my @fields = split /\s+,\s*/, $chanstring;
	my %hash;
	keys %hash  = scalar @fields;
	for (@fields) {
		if (/\s=>/) {
			my ($channel, $chatnet) = split /\s+=>\s*/, $_, 2;
			add_channel_to_parsed(\%hash, $channel, $chatnet, undef);
		} elsif (/\s\@/) {
			my ($channel, $server) = split /\s+\@\s*/, $_, 2;
			add_channel_to_parsed(\%hash, $channel, undef, $server);
		} else {
			my ($channel) = /(\S+)/;
			add_channel_to_parsed(\%hash, $channel, undef, undef);
		}
	}
	return \%hash;
}

=item I<deparse_channels($hashr)>

Take a hash ref like that produced by parse_channels and convert it into a string suitable for autovoice_channels

=cut

sub deparse_channels {
	my $hashr = shift;
	my @fields;
	for my $channel (keys %$hashr) {
		my $s = $channel;
		push(@fields, $s) if exists $hashr->{$channel}->{plain};
		if (exists $hashr->{$channel}->{server}) {
			for (@{$hashr->{$channel}->{server}}) {
				push(@fields, $s.' @ '.$_);
			}
		}
		if (exists $hashr->{$channel}->{chatnet}) {
			for (@{$hashr->{$channel}->{chatnet}}) {
				push(@fields, $s.' => '.$_);
			}
		}
	}
	return join ' , ', @fields;
}

=item I<is_auto($channel_rec)>

Returns 1 if $channel_rec is an autovoiced channel as defined by autovoice_channels, 0 otherwise.

=cut

sub is_auto {
	unless (Irssi::settings_get_bool('autovoice')) {
		return 0;
	}
	my $channel_rec = shift;
	my $channel_text = lc $channel_rec->{name};
	my $parsedchannels = parse_channels();
	return 0 unless exists $parsedchannels->{$channel_text};
	if (exists $parsedchannels->{$channel_text}->{plain}) {
		return 1;
	} elsif (exists $parsedchannels->{$channel_text}->{chatnet}) {
		#Irssi::print("looking at chatnet @{$parsedchannels->{$channel_text}->{chatnet}}");
		for (@{$parsedchannels->{$channel_text}->{chatnet}}) {
			return 1 if $_ eq lc $channel_rec->{server}->{chatnet};
		}
		return 0;
	} else {
		for (@{$parsedchannels->{$channel_text}->{server}}) {
			return 1 if $_ eq lc $channel_rec->{server}->{address};
		}
		return 0;
	}
}

our %commands = (
					dump => \&dump,
					add => \&add,
					remove => \&remove,
					flush => \&flush,
				);

=item I<autovoice_cmd($data, $server, $witem)>

Irssi command handler which dispatches all the /autovoice * commands.  Autovoice commands are given ($server_rec, $witem, @args), where @args is the result of split ' ', $data minus the first element ("autovoice").  Note that the case of @args is not changed.

=cut

sub autovoice_cmd {
	my ($data, $server, $witem) = @_;
	my ($cmd, @args) = (split ' ', $data);
	$cmd = lc $cmd;
	if (exists $commands{$cmd}) {
		$commands{$cmd}->($server, $witem, @args)
	} else {
		Irssi::print("No such command: autovoice $cmd");
	}
}

=item I<dump($server_rec, $witem, @args)>

Invoked as C</autovoice dump>, this C<require>s Data::Dumper and dumps the blacklist hash to the current window. @args and $server_rec are ignored.

=cut

sub dump {
	require Data::Dumper;
	my $witem = $_[1];
	my $string = Data::Dumper->Dump([\%bad], ['bad']);
	chomp $string;
	if ($witem) {
		$witem->print($string);
	} else {
		Irssi::print($string);
	}
}

=item I<add($server_rec, $witem, @args)>

Invoked as C</autovoice add (args)>.  This adds channels to autovoice_channels.  See L</autovoice add> in COMMANDS for usage.

=cut

sub add {
	my ($server_rec, $witem, @args) = @_;
	@args = map {lc} @args;
	my $parsedchannels = parse_channels();
	my ($server, $chatnet, $channel);
	for (my $i = 0; $i < @args; ++$i) {
		if ($args[$i] eq '-ircnet') {
			if (defined $chatnet) {
				Irssi::print("autovoice add: warning: -ircnet given twice, using the second value.");
			}
			$chatnet = $args[$i+1];
			splice(@args, $i, 1)
		} elsif ($args[$i] eq '-server') {
			if (defined $server) {
				Irssi::print("autovoice add: warning: -server given twice, using the second value.");
			}
			$server = $args[$i+1];
			splice(@args, $i, 1);
		} else {
			if (defined $channel) {
				Irssi::print("autovoice add: warning: more than one channel specified, using the last one.");
			}
			$channel = $args[$i];
			$channel = '#'.$channel
				unless $server_rec->ischannel($channel);
		}
	}
	unless (defined $channel) {
		Irssi::print("autovoice add: no channel specified");
		return;
	}
	add_channel_to_parsed($parsedchannels, $channel, $chatnet, $server);
	Irssi::settings_set_str('autovoice_channels' =>
			deparse_channels($parsedchannels));
	if ($witem) {
		$witem->command("set autovoice_channels");
	} else {
		Irssi::command("set autovoice_channels");
	}
}

=item I<add_channel_to_parsed($parsedchannels, $channel, $chatnet, $server)>

Adds a channel to a hash ref like that returned by &parse_channels.  If $chatnet is defined but $server is not, restrict it to the chatnet.  If $server is defined but $chatnet is not, restrict it to the server.  If both are defined, add to channels, one restricted to the server and the other to the chatnet.  (Both with the same name)  If neither is defined, do not restrict the channel to a chatnet or server.

=cut

sub add_channel_to_parsed {
	my ($parsedchannels, $channel, $chatnet, $server) = @_;
	if (defined $chatnet) {
		push @{$parsedchannels->{$channel}->{chatnet}}, $chatnet;
	} 
	if (defined $server) {
		push @{$parsedchannels->{$channel}->{server}}, $server;
	} 
	if (not defined($chatnet) and not defined($server)) {
		$parsedchannels->{$channel}->{plain} = 1;
	}
}

=item I<remove($server_rec, $witem, @args)>

Invoked as

	/autovoice remove [-ircnet IRCNET] [-server SERVER] #chan1 [-ircnet IRCNET] [-server SERVER] #chan2

Removes all channels matching those specified.  An -ircnet or -server option only applies to the channel following it, and must be specified before its channel name.  A channel without -ircnet or -server options removes all channels with that name.

=cut

sub remove {
	my ($server_rec, $witem, @args) = @_;
	my %parsedchannels = %{parse_channels()};
	my ($wantserver, $wantchatnet, $server, $chatnet);
	for (@args) {
		$_ = lc;
		if ($wantserver) {
			$wantserver = 0;
			$server = $_;
		} elsif ($wantchatnet) {
			$wantchatnet = 0;
			$chatnet = $_;
		} elsif ($_ eq '-server') {
			$wantserver = 1;
		} elsif ($_ eq '-ircnet') {
			$wantchatnet = 1;
		} elsif (exists $parsedchannels{$_}) {
			my $chan = $_;
			if (defined $server and exists $parsedchannels{$chan}{server}) {
				@{$parsedchannels{$chan}{server}} = grep {$_ ne $server} @{$parsedchannels{$chan}{server}};
			}
			if (defined $chatnet and exists $parsedchannels{$chan}{chatnet}) {
				@{$parsedchannels{$chan}{chatnet}} = grep {$_ ne $chatnet} @{$parsedchannels{$chan}{chatnet}};
			}
			if (not defined $server and not defined $chatnet) {
				delete $parsedchannels{$chan};
			} else {
				if (exists $parsedchannels{$chan}{server} and not @{$parsedchannels{$chan}{server}}) {
					delete $parsedchannels{$chan}{server};
				}
				if (exists $parsedchannels{$chan}{chatnet} and not @{$parsedchannels{$chan}{chatnet}}) {
					delete $parsedchannels{$chan}{chatnet};
				}
			}
		}
	}
	Irssi::settings_set_str('autovoice_channels' =>
			deparse_channels(\%parsedchannels));
	if ($witem) {
		$witem->command("set autovoice_channels");
	} else {
		Irssi::command("set autovoice_channels");
	}
}

=item I<flush($server_rec, $witem, @args)>

Flush the badlist.

=cut

sub flush {
	%bad = ();
}

=item I<get_cycletime()>

Checks autovoice_cycletime and returns the cycle time in milliseconds.

=cut

sub get_cycletime {
	1000 * Irssi::settings_get_int("autovoice_cycletime");
}

=item I<get_voiceops()>

Return the value of autovoice_voice_ops

=cut

sub get_voiceops {
	Irssi::settings_get_bool("autovoice_voice_ops");
}

=item I<get_useident()>

Return the value of autovoice_use_ident

=cut

sub get_useident {
	Irssi::settings_get_bool("autovoice_use_ident");
}

=back

=cut

Irssi::signal_add_first('message part', 'message_part');
Irssi::signal_add_first('message quit', 'message_quit');
Irssi::signal_add_first('message kick', 'message_kick');
Irssi::signal_add_last('massjoin', 'massjoin');
Irssi::settings_add_str('autovoice', 'autovoice_channels' => "");
Irssi::settings_add_int('autovoice', 'autovoice_cycletime' => 600);
Irssi::settings_add_bool('autovoice', 'autovoice_voice_ops' => 0);
Irssi::settings_add_bool('autovoice', 'autovoice_use_ident' => 0);
Irssi::settings_add_bool('autovoice', 'autovoice' => 1);
Irssi::command_bind(autovoice => 'autovoice_cmd');
