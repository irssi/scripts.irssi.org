## Usage: /CWHO [-a | -l | -o | -v ] [ mask ]

##  ver 1.1 
# - added sorting
# - few fixes

use Irssi 20020300;
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "1.1";
%IRSSI = (
        authors         => "Maciek \'fahren\' Freudenheim",
        contact         => "fahren\@bochnia.pl",
        name            => "Cached WHO",
        description     => "Usage: /CWHO [-a | -l | -o | -v ] [ mask ]",
        license         => "GNU GPLv2 or later",
        changed         => "Mon May  6 14:02:25 CEST 2002"
);

Irssi::theme_register([
	'cwho_line', '%K[%W$[!-3]0%K][%C$1%B$[9]2%K][%B$[-10]3%P@%B$[34]4%K]%n'
]);

sub sort_mode {
	if ($a->[0] eq $b->[0]) {
		return 0;
	} elsif ($a->[0] eq "@") {
		return -1;
	} elsif ($b->[0] eq "@") {
		return 1;
	} elsif ($a->[0] eq "v") {
		return -1;
	} elsif ($b->[0] eq "v") {
		return 1
	};
}

Irssi::command_bind 'cwho' => sub {
	my ($pars, $server, $winit) = @_;
	$pars =~ s/^\s+//;
	my @data = split(/ +/, $pars);
	my ($cmode, $cmask, $i) = ('.', "*!*@*", 0);

	unless ($winit && $winit->{type} eq "CHANNEL") {
	    Irssi::print("You don't have active channel in that window");
	    return;
	}

	my $channel = $winit->{name};
	
	while ($_ = shift(@data)) {
		/^-a$/ and $cmode = '.', next;
		/^-l$/ and $cmode = 'X', next;
		/^-o$/ and $cmode = '@', next;
		/^-v$/ and $cmode = 'v', next;
		/[!@.]+/ and $cmask = $_, next;
	}

	my @sorted = ();
	for my $hash ($winit->nicks()) {
		my $mode = $hash->{op}? "@" : $hash->{voice}? "v" : " ";

		if ($cmode eq "X") {
			next if $mode ne " ";
		} elsif ($mode !~ /$cmode/) {next}
		
		next unless $server->mask_match_address($cmask, $hash->{nick}, $hash->{host});	

		my ($user, $host) = split(/@/, $hash->{host});
		push @sorted, [ $mode, $hash->{nick}, $user, $host ];
	}
	
	@sorted = sort { sort_mode || lc $a->[1] cmp lc $b->[1] } @sorted;
	
	$server->printformat($channel, MSGLEVEL_CLIENTCRAP, 'cwho_line', ++$i, @$_) for (@sorted);

	Irssi::print("No matches for \'$cmask\'.") unless $i;
}
