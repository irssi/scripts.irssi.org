
# 
# Variables:
# /set kill_fake_gets_timeout X - if there is no tranfer in X minutes the get 
#	is closed
#
# Changes:
# 1.1 (2003.02.11)
#	Hmm. The previous official version didn't worket at all (forgot to 
#	uncomment one line) and notbody told me that. Means nobody is using this
#	script...
#	Anyway, this should be fixed. And now it closes stalled gets as well.
#

$VERSION = "1.1";
%IRSSI = (
	authors     => "Piotr 'Cvbge' Krukowiecki",
	name        => 'kill_fake_gets',
	description => 'When new send arrives checks if there are old identical '.
		'sends (ie from the same nick on the same server and with the same '.
		'filename) and closes them',
	license     => 'Public Domain',
	changed     => '2003.02.11', 
	url         => 'http://pingu.ii.uj.edu.pl/~piotr/irssi/'
);

my $debug = 0; # set this to 1 to enable A LOT OF debug messages

sub pd {
	return if (not $debug);
	$dcc = @_[0];
	Irssi::print("SDC '$dcc->{type}' from '$dcc->{nick}' on '$dcc->{servertag}' arg '$dcc->{arg}'");
	Irssi::print("SDC created '$dcc->{created}' addr '$dcc->{addr}' port '$dcc->{port}'");
	Irssi::print("SDC starttime '$dcc->{starttime}' transfd '$dcc->{transfd}'");
	Irssi::print("SDC size '$dcc->{size}' skipped '$dcc->{skipped}'");
}

sub sig_dcc_connected {
    my $dcc = @_[0];
	return if ($dcc->{'type'} ne 'GET');
	Irssi::print("SDC: dcc get connected") if ($debug); 
	pd($dcc);
	foreach (Irssi::Irc::dccs()) {
		pd($_);
		if ($_->{'type'} eq 'GET' and
			$_->{'nick'} eq $dcc->{'nick'} and
			$_->{'servertag'} eq $dcc->{'servertag'} and
			$_->{'arg'} eq $dcc->{'arg'} and 
			$_->{'created'} ne $dcc->{'created'} and
			$_->{'starttime'} ne $dcc->{'starttime'} and
			$_->{'port'} ne $dcc->{'port'}) {
			Irssi::print("SDC: Destroying") if ($debug);
			$_->destroy();
		}
	}
}

my %gets;

sub sig_dcc_destroyed {
	my $dcc = @_[0];
	return if ($dcc->{'type'} ne 'GET');
	
	Irssi::print('SDC: the get was destroyed:') if ($debug); pd($dcc);
	
	# no record - the script must have been loaded less than 1 minute ago
	if (not exists $gets{$dcc->{'servertag'}} or
		not exists $gets{$dcc->{'servertag'}}{$dcc->{'nick'}} or
		not exists $gets{$dcc->{'servertag'}}{$dcc->{'nick'}}{$dcc->{'arg'}}) {
		Irssi::print('SDC: The record for this get does not exists') if ($debug); 
		return;		
	}

	delete $gets{$dcc->{'servertag'}}{$dcc->{'nick'}}{$dcc->{'arg'}};
	Irssi::print('SDC: record destroyed') if ($debug); 
}



sub check_speed {
	my $time = time();
	my $timeout = 60 * Irssi::settings_get_int('kill_fake_gets_timeout');
	foreach (Irssi::Irc::dccs()) {
		next if ($_->{'type'} ne 'GET');
		next if (not $_->{'starttime'}); # transfer not yet started

		Irssi::print('SDC: checking get:') if ($debug);	pd($_);
		# no such record - just loaded the script
		if (not exists $gets{$_->{'servertag'}} or
			not exists $gets{$_->{'servertag'}}{$_->{'nick'}} or
			not exists $gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}) {
			$gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'time'} = $time;
			$gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'transfd'} = $_->{'transfd'};
			Irssi::print("Adding as new get: '$time', '$_->{transfd}'") if ($debug);
			next;
		}
		
		# the transfer is in progress
		if ($_->{'transfd'} != $gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'transfd'}) {
			Irssi::print('SDC: the transfer is in progress (change '. 
			($_->{'transfd'} - $gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'transfd'})
				.' bytes)') if ($debug);
			$gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'time'} = $time;
			$gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'transfd'} = $_->{'transfd'};
			next;
		}

		Irssi::print('SDC: transfer stalled') if ($debug);
		# transfer stalled
		if ($time - $gets{$_->{'servertag'}}{$_->{'nick'}}{$_->{'arg'}}{'time'} 
			> $timeout) {
			Irssi::print('SDC: closing this GET') if ($debug);
			my $server = Irssi::server_find_tag($_->{'servertag'});
		    if (!$server) {
				Irssi::print('SDC: error: could not find server $_->{servertag}') if ($debug);
				next;
			}
			$server->command("DCC CLOSE GET $_->{nick} $_->{arg}");
		}
	}
}

# After this many minutes of no data the get is closed
Irssi::settings_add_int('misc', 'kill_fake_gets_timeout', 2); 

Irssi::signal_add_first('dcc connected', 'sig_dcc_connected');
Irssi::signal_add_last('dcc destroyed', 'sig_dcc_destroyed');
my $timeout_tag = Irssi::timeout_add(60*1000, 'check_speed', undef);
