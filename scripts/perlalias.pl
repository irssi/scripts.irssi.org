=head1 perlalias.pl - Perl-based command aliases for irssi

This script provides an /alias-like function that uses small pieces of perl code to carry out the commands.

=head2 Usage

Install into irssi script directory and /run perlalias and/or put into autorun.

=head2 Commands

=over

=item /perlalias

Syntax: /perlalias [[[-]<alias>] [<code>]]

Parameters: A name of the alias and the perl code to execute.

If you prepend the alias with -, it will remove the alias.

If you give no arguments, the list of defined aliases will be displayed.

Description:

Creates or updates an alias. Like any perl code, multiple statements must be separated using ; characters.
No replacement of parameter values is done: any $text is a perl variable.

Examples:

/PERLALIAS UNACT foreach my $w (Irssi::windows) { $w->activity(0); }

=back

=over

=item /perlunalias

Syntax: /perlunalias <alias>

Parameters: The alias to remove.

Description:

Removes the given alias.

=back

Notes on alias authoring:

The following variables are available to you in in the body of your perlalias:

* $_ contains the raw text of the arguments supplied to the command
* @_ contains those some arguments split on whitespace
* $server references the currently active server, if any, otherwise undef.
* $witem references the currently active window item (channel, query, or other), if any. Otherwise undef.
* Most of the irssi $X variables are available as well, producing results exactly as if you used Irssi::parse_special.
* Note that $1, $2, etc do not map to the irssi variables. Those are regex variables. You want $_[0], $_[1], etc:
** Unless you mess with $", $3- is basically "@_[2..$#_]", and $* is "@_" or simply $_ (which has repeated spaces intact)

The alias is compiled once, when the alias is added or the script loads the saved aliases. As usual, your BEGIN {} blocks will run immediately at
that time. If an alias encounters a fatal-error during compilation, the alias will still be stored and saved, and the error will be saved in the alias. The error will be redisplayed if you try to use the alias: no attempt to execute any code will be made. The alias will also be displayed differently in the /perlalias listing.

You can use signal_add or command_bind as normal in your alias. However, if you use them normally, the signals and commands you
add will be removed when the alias finishes executing. If you want a persistant signal or command, you must place it inside a
BEGIN {} or UNITCHECK {} block (and you must pass the compile stage).

Note that because you are adding code to an already-running perl state, CHECK {} blocks do not run.

Additionally, all aliases added are linked to perlalias.pl: if it is unloaded, the aliases will be removed.

You can retain data between multiple use of the alias using an 'our' variable. These variables are not shared with other aliases, and neither are named subs that you might declare.
In addition, these variables aren't saved if the script is unloaded and reloaded (or if irssi restarts).

The following directives are in effect on alias code:

use strict;
use warnings FATAL => qw(closure);

All default warnings - those marked (S) or (D) in perldiag - are enabled and closure warnings are made fatal errors.

Closure warnings are made fatal errors, so you get an error if you try to use an outer lexical (my/state) variable inside a named sub. This won't
work as you might normally expect at file-scope as alias code is compiled once and run multiple times. All other warnings are off by default. If you
want them, you can use warnings; as usual.

Aliases can be saved and reloaded with the usual /save and /reload (including autosave). Saved aliases are loaded at script load. The textual content
of the alias (including BEGIN {} and UNITCHECK {} blocks) are saved and will be re-executed when the alias next loads.

=head2 ChangeLog

=over

=item 2.0

Perl 5.22 or later is now mandatory.

Major overhaul to how aliases get compiled and executed:

* Aliases are now under the effect of 'use 5.22.0': perl version 5.22.0 is required both for perlalias itself and for aliases. In addition, all perl 5.22.0 feature bundles are enabled (see perldoc feature). Notably, 'state $var' is available by default.
* Aliases are now compiled with strict on, default perl warnings (previously all warnings were off), and with closure warnings (see perldiag) enabled. This will help warn you of using outside 'my' variables inside named subs : this won't work as you expect!
* Perlalias warnings will emit to the default window with a nicer looking output now.
* Aliases now get their own individual package scopes, so your 'our' variables and named subs are no longer shared among aliases.
* You can use 'shared state $Var' to share the $Var variable with your other aliases. You have to do this in each alias that wants to use the shared variable. You can share scalars, arrays, and hashes this way.
** If you use an initializer, only the first alias to run that declares the state variable will decide the initial value of the variable.
* You now have access to most of the $X-type special variables used in standard aliases, without needing to deal with parse_special().
* Aliases that fail to compile are no longer rejected. They'll be registered, but when you try to execute them, the compile error message will simply be displayed again. Failed aliases will also display differently in the alias list.

=item 1.3

Made signal_add and command_bind usable within the alias code. They will persist if used inside a BEGIN block but will be removed
after execution otherwise.

=item 1.0

First version.

=back

=cut

# This need to be before pragmas, so that the eval runs in a pragma-free state
sub _clean_eval { eval $_[0]; } ## no critic

use 5.22.0;
use strict;
use warnings FATAL => qw(all);
use Irssi;
use Irssi::Irc;
use Carp ();

use B ();

{ package Irssi::Nick; } # Keeps trying to look for this package but for some reason it doesn't get loaded.

our $VERSION = '2.0.1';
our %IRSSI = (
	authors => 'aquanight',
	contact => 'aquanight@gmail.com',
	name => 'perlalias',
	description => 'Quickly create commands from short perl blocks',
	license => 'public domain'
	);

package Irssi::Script::perlalias::IrssiVar {
	sub TIESCALAR {
		my $class = shift;
		my $irssivar = shift;
		my $this = bless \$irssivar, $class;
		return $this;
	}

	sub FETCH {
		my $this = shift;
		my $irssivar = $$this;
		return Irssi::Script::perlalias::aliaspkg::parse_special($irssivar);
	}

	sub STORE { Carp::croak "Attempt to modify irssi special variable"; }
}

my $_eval_prep;
BEGIN { $_eval_prep = ""; }

# Base package which provides variables to the alias code.
package Irssi::Script::perlalias::aliaspkg {
	our $server;
	our $witem;

	our @_irssi_vars;
	use vars map '$'.$_, @_irssi_vars = (
		qw(A B C F I J K k M N O P Q R T V versiontime abiversion W Y Z sysname sysrelease sysarch topic tag chatnet itemname), # core
		qw(H S X x usermode cumode cumode_space), # irc
		qw(E L U), # gui
		qw(winref winname), # fe
		qw(D)); # notify-whois

	BEGIN {
		for my $var (@_irssi_vars) {
			use Symbol ();
			my $gr = Symbol::qualify_to_ref($var);
			my $sv = *$gr{SCALAR};
			tie $$sv, 'Irssi::Script::perlalias::IrssiVar' => "\$$var";
			$_eval_prep .= "our \$$var;\n";
		}
	}

	our %shared;

	# Empty placeholder sub for our keyword.
	sub shared {
	}

	sub parse_special {
		my ($special) = @_;
		defined $witem and return $witem->parse_special($special);
		defined $server and return $server->parse_special($special);
		return Irssi::parse_special($special);
	}
}

# The below is intended to be representative of the template of an alias's package.
#package Irssi::Script::perlalias::aliaspkg::perlalias {
#	BEGIN {
#		import Irssi::Script::perlalias::aliaspkg;
#	}
#
#	our $_name = "name of the command";
#
#	our $_text = "plaintext of the alias";
#
#	sub invoke {
#		# The compiled version of the alias.
#	}
#
#	our @_signals; # Data about the signals this alias has hooked
#	our @_commands: # Data about commands this alias has created
#
#	our $_error; # Stored compilation error
#}

# Unfortunately, we can't really just use the alias name as a package name. Irssi commands have no restrictions on what characters are in them.
# Nothing stops someone from wanting a command named mallet::gnome or something else weird. It's on them to figure out how to type in weird stuff
# like ^W or whatever. Whitespace is somewhat safe due to the command format but not entirely.
our %alias_packages = ();

my $pkgindex = 0;

sub next_package_name { sprintf("Irssi::Script::perlalias::aliaspkg::A%d", ++$pkgindex); };

# These capture signal_add* and command_bind* invocations that occur during alias compilation (via BEGIN{}s) and execution.

sub capture_signal_command {
	my ($cmd, $irssi_proc, $store) = @_;
	my $capture_handler = sub {
		#exists $cmds{$cmd} or return;
		#defined $cmds{$cmd}->{cmpcmd} or return;
		#Carp::cluck "Capturing attempt to add signal";
		$irssi_proc->(@_);
		push @$store, $_[0], $_[1];
	};
	return $capture_handler;
}

sub cleanup_signals {
	my ($remove_proc, @signals) = @_;
	while (scalar(@signals) > 0) {
		my ($signal, $handler) = splice @signals, 0, 2;
		defined($signal) or return;
		$remove_proc->($signal, $handler);
	}
}

sub execute_alias;

our $alias_depth = "";
sub cmd__alias {
	my ($data, $server, $witem) = @_;
	return if $alias_depth;
	# If they do Irssi::command("blerp") or anything like that, it needs to go to a real command, just like aliases do.
	local $alias_depth = 1;
	my $sig = Irssi::signal_get_emitted();
	Irssi::signal_stop(); # Don't let any real command catch it.
	my ($cmd) = ($sig =~ m/^command (.*)$/);
	defined $cmd or Carp::confess "This is weird"; # What are we doing here?
	execute_alias $cmd, $data, $server, $witem;
}

# The new alias handling code starts here:

sub destroy_alias_package {
	my ($name) = @_;
	my $package = $alias_packages{$name};
	return unless defined $package;
	no strict 'refs';
	my @signals = @{"${package}::signals"};
	my @commands = @{"${package}::commands"};
	cleanup_signals(\&Irssi::signal_remove, @signals);
	cleanup_signals(\&Irssi::command_unbind, @commands);
	delete $alias_packages{$name};
	Irssi::command_unbind("$name", \&cmd__alias);
	Symbol::delete_package($package);
	return;
}

sub collect_shared_variables;

sub setup_alias_package {
	my ($name, $code) = @_;
	# Terminate the existing alias, if there is one.
	exists $alias_packages{$name} and destroy_alias_package $name;
	Irssi::command_bind_first("$name", \&cmd__alias);
	my $package = next_package_name;
	$alias_packages{$name} = $package;
	my $signals;
	my $commands;
	{
		no strict 'refs';
		${"${package}::_text"} = $code;
		${"${package}::_name"} = $name;
		@{"${package}::_signals"} = ();
		$signals = \@{"${package}::_signals"};
		@{"${package}::_commands"} = ();
		$commands = \@{"${package}::_commands"};
		${"${package}::_error"} = undef;
	}
	no warnings 'redefine'; # Shut up about monkey patching
	local *Irssi::signal_add = capture_signal_command($name, Irssi->can("signal_add"), $signals);
	local *Irssi::signal_add_first = capture_signal_command($name, Irssi->can("signal_add_first"), $signals);
	local *Irssi::signal_add_last = capture_signal_command($name, Irssi->can("signal_add_last"), $signals);
	local *Irssi::signal_add_priority = capture_signal_command($name, Irssi->can("signal_add_priority"), $signals);
	local *Irssi::command_bind = capture_signal_command($name, Irssi->can("command_bind"), $commands);
	local *Irssi::command_bind_first = capture_signal_command($name, Irssi->can("command_bind_first"), $commands);
	local *Irssi::command_bind_last = capture_signal_command($name, Irssi->can("command_bind_last"), $commands);
	local $SIG{__WARN__} = sub {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_warning => $name);
		Irssi::print($_[0], MSGLEVEL_CLIENTERROR);
	};
	my sub failed_alias { ## no critic
		my $err = shift;
		$err =~ /^ASSERT/ and die $err; ## no critic
		no strict 'refs';
		undef *{"${package}::invoke"}; # Kill the sub if it compiled but we failed shared-state setup.
		${"${package}::_error"} = $err;
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_compile_error => $name);
		Irssi::print($err, MSGLEVEL_CLIENTERROR);
		cleanup_signals(\&Irssi::signal_remove, @$signals);
		cleanup_signals(\&Irssi::command_unbind, @$commands);
	}
	_clean_eval qq{
#line 1 "perlalias-eval-setup"
		package Irssi::Script::perlalias::aliaspkg;
		BEGIN { \*${package}::shared = \\&shared; }
		our \$shared;
		our \$witem;
		$_eval_prep
		package $package;
		use 5.22.0;
		use strict;
		use warnings 'closure';
		use Irssi;
		sub invoke {
#line 1 "perlalias $name"
			$code;
		}
		1;
	} or do { failed_alias $@; return; };
	eval {
		collect_shared_variables $package;
		1;
	} or do { failed_alias $@; return; };
}

sub execute_alias {
	my ($name, $data, $server, $witem) = @_;
	local $Irssi::Script::perlalias::aliaspkg::server = $server;
	local $Irssi::Script::perlalias::aliaspkg::witem = $witem;
	my $package = $alias_packages{$name};
	return unless defined $package;
	no strict 'refs';
	my $proc = "$package"->can("invoke");
	unless (defined $proc) {
		my $err = ${"${package}::_error"};
		defined $err or return; # Not sure how we'd get here with no error and no proc. Perhaps we lost a race?
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_compile_error => $name);
		Irssi::print($err, MSGLEVEL_CLIENTERROR);
	}
	my @signals;
	my @commands;
	no warnings 'redefine'; # SHUT UP ABOUT MONKEY PATCHING
	local *Irssi::signal_add = capture_signal_command($name, Irssi->can("signal_add"), \@signals);
	local *Irssi::signal_add_first = capture_signal_command($name, Irssi->can("signal_add_first"), \@signals);
	local *Irssi::signal_add_last = capture_signal_command($name, Irssi->can("signal_add_last"), \@signals);
	local *Irssi::signal_add_priority = capture_signal_command($name, Irssi->can("signal_add_priority"), \@signals);
	local *Irssi::command_bind = capture_signal_command($name, Irssi->can("command_bind"), \@commands);
	local *Irssi::command_bind_first = capture_signal_command($name, Irssi->can("command_bind_first"), \@commands);
	local *Irssi::command_bind_last = capture_signal_command($name, Irssi->can("command_bind_last"), \@commands);
	local $SIG{__WARN__} = sub {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_warning => $name);
		Irssi::print($_[0], MSGLEVEL_CLIENTERROR);
	};
	local $_ = $data;
	my @args = split / +/, $data;
	eval { $proc->(@args);};
	my $err = $@;
	# signals/commands created during this step were not the result of a BEGIN{}/UNITCHECK{}/etc.
	# These signals get removed after completion!
	cleanup_signals(\&Irssi::signal_remove, @signals);
	cleanup_signals(\&Irssi::command_unbind, @commands);
	if ($err) {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_exec_error => $name);
		Irssi::print($err, MSGLEVEL_CLIENTERROR);
	}
}

sub list_commands {
	my ($prefix) = @_;
	my @whichones = sort grep /^\Q$prefix\E/, keys %alias_packages;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'perlaliaslist_header');
	for my $name (@whichones) {
		my $package = $alias_packages{$name};
		no strict 'refs';
		my $text = ${"${package}::_text"};
		if (defined "$package"->can("invoke")) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, perlaliaslist_line => $name, $text);
		}
		else {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, perlaliaslist_line_error => $name, $text);
		}
	}
}

sub cmd_perlalias {
	my ($data, $server, $witem) = @_;
	my ($command, $script) = split /\s+/, $data, 2;
	if (($command//"") eq "") {
		list_commands "";
	}
	elsif ($command =~ m/^-/) {
		$command = substr($command, 1);
		if (exists $alias_packages{$command}) {
			destroy_alias_package $command;
			Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_removed => $command);
		}
		else {
			Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_not_found => $command);
		}
	}
	elsif (($script//"") eq "") {
		list_commands $command;
	}
	else {
		setup_alias_package $command, $script;
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_added => $command);
	}

}

sub cmd_perlunalias {
	my ($data, $server, $witem) = @_;
	my $command = $data;
	if (exists $alias_packages{$command}) {
		destroy_alias_package $command;
		Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_removed => $command);
	}
	else {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_not_found => $command);
	}
}

sub sig_setup_saved {
	my ($main, $auto) = @_;
	my $file = Irssi::get_irssi_dir() . "/perlalias.json";
	open my $fd, '>', $file or return;
	my $js = JSON::PP->new->utf8->pretty(0);
	my $obj = [ map {
			my $package = $alias_packages{$_};
			no strict 'refs';
			my $text = ${"${package}::_text"};
			+{ command => $_, script => $text };
		} keys %alias_packages ];
	$fd->print($js->encode($obj));
	close $fd;
}

use JSON::PP;

use constant JSON_CONFIG => Irssi::get_irssi_dir() . "/perlalias.json";
use constant LEGACY_CONFIG => Irssi::get_irssi_dir() . "/perlalias";

sub sig_setup_reread {
	my %newcmds;
	my $fd;
	if (open $fd, "<", JSON_CONFIG) {
		my $js = JSON::PP->new->utf8->pretty(0);
		local $/;
		unless (eval {
			my $obj = $js->decode(<$fd>);
			for my $entry (@$obj) {
				my ($cmd, $script) = $entry->@{qw/command script/};
				if (exists $newcmds{$cmd}) {
					Irssi::print("There is a duplicate record in the PerlAlias save file.", MSGLEVEL_CLIENTERROR);
					Irssi::print("Offending alias: $cmd", MSGLEVEL_CLIENTERROR);
					Irssi::print("Previous definition: " . $newcmds{$cmd}, MSGLEVEL_CLIENTERROR);
					Irssi::print("Duplicate definition: $script", MSGLEVEL_CLIENTERROR);
				}
				$newcmds{$cmd} = $script;
			}
			1;
		}) { goto LEGACY_CONF; }
		close $fd;
		goto PROCESS;
	}
	else
	{
		LEGACY_CONF:
		open my $fd, "<", LEGACY_CONFIG or return;
		my $ln;
		while (defined($ln = <$fd>)) {
			chomp $ln;
			my ($cmd, $script) = split /\t/, $ln, 2;
			if (exists $newcmds{$cmd}) {
				Irssi::print("There is a duplicate record in the PerlAlias save file.", MSGLEVEL_CLIENTERROR);
				Irssi::print("Offending alias: $cmd", MSGLEVEL_CLIENTERROR);
				Irssi::print("Previous definition: " . $newcmds{$cmd}, MSGLEVEL_CLIENTERROR);
				Irssi::print("Duplicate definition: $script", MSGLEVEL_CLIENTERROR);
			}
			$newcmds{$cmd} = $script;
		}
		Irssi::print("Legacy config loaded. Please /save to upgrade config file.", MSGLEVEL_CLIENTNOTICE);
		close $fd;
	}
	PROCESS:
	# Scrub the existing list. Update existings, remove any that aren't in the config, then we'll add any that's new.
	my @currentcmds = keys %alias_packages;
	for my $cmd (@currentcmds) {
		if (exists $newcmds{$cmd}) {
			setup_alias_package($cmd, $newcmds{$cmd});
		}
		else {
			destroy_alias_package($cmd);
		}
		delete $newcmds{$cmd};
	}
	# By this point all that should be in newcmds is any ... new commands.
	for my $cmd (keys %newcmds) {
		setup_alias_package($cmd, $newcmds{$cmd});
	}
}

sub sig_complete_perlalias {
	my ($lst, $win, $word, $line, $want_space) = @_;
	$word//return;
	$line//return;
	$lst//return;
	if ($line ne '') {
		my $package = $alias_packages{$line};
		no strict 'refs';
		my $def = ${"${package}::_text"};
		$def//return;
		push @$lst, $def->{textcmd};
		Irssi::signal_stop();
	}
	else {
		push @$lst, (grep /^\Q$word\E/i, keys %alias_packages);
		Irssi::signal_stop();
	}
}

sub sig_complete_perlunalias {
	my ($lst, $win, $word, $line, $want_space) = @_;
	$lst//return;
	$word//return;
	push @$lst, (grep /^\Q$word\E/i, keys %alias_packages);
}

Irssi::signal_register({"complete command " => [qw(glistptr_char* Irssi::UI::Window string string intptr)]});
Irssi::signal_add("complete command perlalias" => \&sig_complete_perlalias);
Irssi::signal_add("complete command perlunalias" => \&sig_complete_perlunalias);

Irssi::signal_add("setup saved" => \&sig_setup_saved);
Irssi::signal_add("setup reread" => \&sig_setup_reread);

Irssi::command_bind(perlalias => \&cmd_perlalias);
Irssi::command_bind(perlunalias => \&cmd_perlunalias);

my %formats = (
	# $0 Name of alias
	'perlalias_compile_error' => '{error Error compiling alias {hilight $0}:}',
	# $0 Name of alias
	'perlalias_exec_error' => '{error Error executing alias {hilight $0}:}',
	'perlalias_warning' => '{error Warning in alias {hilight $0}:}',
	'perlalias_cmd_in_use' => 'Command {hilight $0} is already in use',
	'perlalias_added' => 'PerlAlias {hilight $0} added',
	'perlalias_removed' => 'PerlAlias {hilight $0} removed',
	'perlalias_not_found' => 'PerlAlias {hilight $0} not found',
	'perlaliaslist_header' => '%#PerlAliases:',
	# $0 Name of alias, $1 alias text
	'perlaliaslist_line' => '%#$[10]0 $1',
	'perlaliaslist_line_error' => '%#{error $[10]0} $1',
);

Irssi::theme_register([%formats]);

sig_setup_reread;

#__END__

# For error helping:
my $_skip_asserts = 0;
sub assert :prototype(&$) {
	return if $_skip_asserts;
	my $condition = shift;
	my $message = shift;
	return if $condition->();
	Carp::confess "ASSERT FAILURE: $message";
}

# There is going to be some pretty heavy stuff going on here.

# Because every perlalias runs inside its own package, there are basically three classes of variables:
#
# # Variables that reset every time the alias runs -- my $x; (*)
# # Variables that keep their value between different alias runs, but are not visible to other aliases -- state $x; our $y;
# # Variables that keep their value between different alias runs, and are shared across aliases -- shared state $z;
#
# The 'shared state' declarator brings the third type into existence.
#
# Major credit to 'mst' and 'LeoNerd' of Freendoe/#perl for putting up with my awkward attempts at figuring this out.

# Shared variables are now of the format:
# [ <data>, <proc>, <pad>, <index> ]
# <data> contains an instance of Tie::StdScalar, Tie::StdArray, or Tie::StdHash
# <proc> contains an anonymous sub. Any time the variable is accessed, we call <proc> in void context.
#        <proc> will just be a small sub that contains a state with initializer. Calling it will trigger the initializer.
# <pad> Contains an array reference which is a reference to the first PAD of <proc>, which will be where we find....
# <index> The index number to the state's "initializer has run" controlling variable.
# When setting up a new shared variable, that variable should be a state, and if it has its own initializer, we will link that state
# variable's initializer-control variable to the one in the anonymous sub. Thus if either initializer runs, neither will run again.

use Tie::Scalar ();
use Tie::Array ();
use Tie::Hash ();

use Scalar::Util 'reftype';

package Irssi::Script::perlalias::SharedVar {
	sub create {
		my ($class, $data, $proc, $pad, $index) = @_;
		my $this = bless [$data, $proc, $pad, $index], $class;
		return $this;
	}

	sub TIESCALAR {
		my ($class, $to) = @_;
		return $to;
	}

	sub TIEARRAY {
		my ($class, $to) = @_;
		return $to;
	}

	sub TIEHASH {
		my ($class, $to) = @_;
		return $to;
	}

	for my $method (qw/FETCH STORE FETCHSIZE STORESIZE CLEAR PUSH POP SHIFT UNSHIFT SPLICE EXTEND DELETE EXISTS 
		DESTROY UNTIE FIRSTKEY NEXTKEY SCALAR/) {
		no strict 'refs';
		*{"Irssi::Script::perlalias::SharedVar::$method"} = sub {
			my $this = shift;
			my ($data, $proc, $pad, $index) = @$this;
			# Spring the state initializer.
			$proc->() unless $method eq "DESTROY" || $method eq "UNTIE";
			$data->$method(@_);
		}
	}
};

# Be careful with the array this returns. It is ONLY safe to access indexes linked to scalars!
sub get_state_pad {
	my $sub = shift;
	assert {defined $sub} "Undefined proc";
	assert {ref($sub) eq "CODE"} "Not a proc";
	return B::svref_2object($sub)->PADLIST->ARRAYelt(1)->object_2svref;
}

# Keep the C-style for loop for child-op enumeration in one spot.
sub op_kids {
	my $op = shift;
	assert {defined $op} "Got an undefined op";
	assert {$op->UNIVERSAL::isa("B::OP")} "Invalid opcode class";
	my @kids;
	if ($op->flags & B::OPf_KIDS) {
		for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
			assert { defined $kid } "Undefined kid";
			push @kids, $kid;
		}
	}
	return @kids;
}

# prototype for a map-like operator, so we can have walk_ops { BLOCK } $op
sub walk_ops :prototype(&@) {
	my $sub = shift;
	my @ops = @_;
	my @return;
	while (scalar @ops) {
		my $op = shift @ops;
		assert {defined $op} "Undefined op";
		assert {$op->UNIVERSAL::isa("B::OP")} "Invalid opcode class";
		next unless $$op;
		local $_ = $op;
		push @return, $sub->();
		unshift @ops, op_kids $op;
	}
	return @return;
}

# Returns the sub, the array for its PAD, and the index of the state variable's control var.
# Packs it all into an array that we can shove into %shared_init;
sub generate_state_locker {
	my $sub = sub { state $x = 42; };
	my $pad = get_state_pad $sub;
	my ($stateix) = walk_ops {
		return () unless B::class($_) eq "LOGOP";
		return () unless $_->name eq 'once';
		return ($_->targ);
		} B::svref_2object($sub)->ROOT;
	return $sub, $pad, $stateix;
}

use constant true => !0;
use constant false => !1;

sub is_op_type {
	my ($op, $name) = @_;
	$op->name eq $name and return true;
	$op->name eq 'null' or return false;
	return B::ppname($op->targ) eq "pp_$name";
}

sub op_is_sub {
	my ($pad, $op, $sub) = @_;
	assert {defined $op} "Undefined op";
	assert {$op->UNIVERSAL::isa("B::OP")} "Invalid opcode class";
	if (!is_op_type($op, "rv2cv")) {
		return false;
	}
	assert { ($op->flags & ~B::RV2CVOPCV_FLAG_MASK) == 0 } "Not possible: perl should've paniced already";
	if ($op->private & B::OPpENTERSUB_AMPER) { return false; }
	if ($op->flags & B::OPf_KIDS == 0) { return false; }
	my $rvop = $op->first;
	my $cv;
	if (is_op_type($rvop, 'gv') || is_op_type($rvop, 'const')) {
		if (B::class($rvop) eq "PADOP") {
			$cv = $pad->ARRAYelt($rvop->padix)->object_2svref;
		}
		elsif (B::class($rvop) eq "SVOP") {
			$cv = $rvop->sv->object_2svref;
		}
		else {
			assert { 0 } "Impossible, class is: " . B::class($rvop);
		}
		if (reftype($cv) eq "GLOB") {
			$cv = *$cv{CODE};
		}
	}
	elsif (is_op_type($rvop, 'padcv')) {
		return false; # Not needed at this time.
	}
	else {
		return false;
	}
	if (reftype($cv) ne "CODE") { return false; }
	return $cv == $sub;
}

use B::Concise ();

sub collect_shared_variables {
	my $package = shift;
	my $invoke = $package->can("invoke");

	my $invoke_cv = B::svref_2object $invoke;
	my $invoke_pl = $invoke_cv->PADLIST;
	my $invoke_pn = $invoke_pl->NAMES;

	my $pad = $invoke_pl->ARRAYelt(1);
	my $padobj = $pad->object_2svref;

	my sub padname {
		my $ix = shift;
		return $invoke_pn->ARRAYelt($ix);
	}

	my $cop;

	my sub op_die {
		die sprintf("%s at %s line %d.\n", shift, $cop->file, $cop->line); ## no critic
	}

	my sub op_assert(&$) {
		return if $_skip_asserts;
		my $condition = shift;
		my $message = shift;
		return if $condition->();
		my $concise = "";
		open my $fd, ">", \$concise;
		my $prev = B::Concise::walk_output;
		B::Concise::walk_output $fd;
		B::Concise::concise_subref(basic => $invoke, "${package}::invoke");
		B::Concise::walk_output $prev; # Set back to 
		close $fd;
		Carp::confess sprintf("ASSERT FAILURE: %s at %s line %d.\n%s\n", $message, $cop->file, $cop->line, $concise);
	}

	my sub register_state {
		my ($name, $ref, $state_control_index) = @_;
		op_assert {ref $ref} "Didn't get a reference";
		# Is there an existing shared state:
		my $current = $Irssi::Script::perlalias::aliaspkg::shared{$name};
		unless(defined $current) {
			# No current state, so we need to create one.
			my $data;
			for (substr($name, 0, 1) . ref($ref)) {
				/^\$SCALAR$/ and do { $data = Tie::StdScalar->TIESCALAR(); }, last;
				/^\@ARRAY$/ and do { $data = Tie::StdArray->TIEARRAY(); }, last;
				/^\%HASH$/ and do { $data = Tie::StdHash->TIEHASH(); }, last;
				op_die "Can't figure out what to do with '$name'";
			}
			$current = Irssi::Script::perlalias::SharedVar->create($data, generate_state_locker);
			$Irssi::Script::perlalias::aliaspkg::shared{$name} = $current;
		}
		ref $current eq "Irssi::Script::perlalias::SharedVar" or Carp::confess "Corrupt state in shared table at '$name'";
		for (ref($ref)) {
			/^SCALAR$/ and do { tie $$ref, "Irssi::Script::perlalias::SharedVar", $current; }, last;
			/^ARRAY$/ and do { tie @$ref, "Irssi::Script::perlalias::SharedVar", $current; }, last;
			/^HASH$/ and do { tie %$ref, "Irssi::Script::perlalias::SharedVar", $current; }, last;
			op_die "Can't figure out what to do with '$name'";
		}
		if (defined $state_control_index) {
			use feature 'refaliasing';
			no warnings 'experimental';
			\($padobj->[$state_control_index]) = \($current->[2]->[$current->[3]]);
		}
	}
	
	# state $x; state @x; state %x;
	my sub try_basic_state {
		my $op = shift;
		if ($op->name eq "padsv" or $op->name eq "padav" or $op->name eq "padhv") {
			# Correct candidate for a direct variable access. At this point, we return either the name and reference
			# to the variable or we raise an exception.
			my $padix = $op->targ;
			my $pname = padname $padix;
			my $name = $pname->PVX;
			my $ref = $pad->ARRAYelt($padix)->object_2svref;
			# Check that this is a proper introduction
			unless ($op->private & B::OPpLVAL_INTRO) {
				op_die "Can't share variable '$name' because of its previous life (are you missing a 'state'?)";
			}
			if ($pname->FLAGS & B::PADNAMEt_OUR) {
				# Sanity check mostly. 'our' variables will look like a global in the optree
				op_die "Can't share 'our' variable '$name'";
			}
			unless ($pname->FLAGS & B::PADNAMEt_STATE) {
				op_die "Can't share 'my' variable '$name'";
			}
			# It's a properly declared state variable, return the name and reference.
			assert {ref $ref} "B returned something undefined";
			register_state $name, $ref;
			return 1;
		}
		return "";
	}

	# state ($x, $y, @x, %y);
	my sub try_multi_state {
		my $op = shift;
		# 
		if (is_op_type $op, 'list') {
			my @kids = op_kids $op;
			for my $k (@kids) {
				$k->name eq 'null' and next;
				try_basic_state $k or op_die "Invalid multiple-variable state";
			}
			return 1;
		}
		return "";
	}

	# state $x = 42;
	# state @x = (1..5);
	my sub try_initializer_state {
		my $op = shift;
		# Initializers use a null which then goes to a 'once' opcode...
		if ($op->name eq 'null') {
			$op = $op->first;
			# There should be no siblings...
			return () if $op->sibling->$*;
			return () unless $op->name eq 'once';
			my @once_kids = op_kids $op;
			# once has the following moving parts:
			# ->targ is the pad index of the control variable:
			my $control_padix = $op->targ;
			# It also has three child ops:
			# The first is a 'null' op for some reason.
			# The second will be some kind of assignment op. This is the initializer.
			# The third will ALWAYS be a padsv REGARDLESS OF WHAT KIND OF THING (it's never a padav or padhv).
			# The third is the variable that was initialized - we'll also see it in the initializer if we went looking.
			# Because the only thing in perl syntax that generates a 'once' opcode right now is 'state', we can assume
			# this is what we're dealing with:
			my $varop = pop @once_kids;
			op_assert {$varop->name eq 'padsv'} sprintf("Unexpected once child '%s'", $varop->name);
			#op_die sprintf("Unexpected once child '%s'", $varop->name) unless $varop->name eq 'padsv'; ##### assert
			my $svix = $varop->targ;
			my $pname = padname $svix;
			my $name = $pname->PVX;
			# Sanity check:
			if (($pname->FLAGS & (B::PADNAMEt_OUR | B::PADNAMEt_STATE)) != B::PADNAMEt_STATE) {
				op_die "Unexpected non-state variable"; ##### assert
			}
			my $ref = $pad->ARRAYelt($svix)->object_2svref;
			assert {ref $ref} "B returned something undefined";
			register_state $name, $ref, $control_padix;
			return 1;
		}
		return "";
	}

	# Just tries to detect certain incorrect uses of 'shared' to give a more useful error message.
	my sub nicer_errors {
		my $op = shift;
		op_assert {defined $op} "Undefined opcode";
		if (is_op_type($op, 'rv2sv') || is_op_type($op, 'rv2av') || is_op_type($op, 'rv2hv') || is_op_type($op, 'rv2gv')) {
			# Possible pattern for a global symbol
			my $nx = $op->first;
			if ($nx->name eq 'gvsv' or $nx->name eq 'gv') {
				# Under multiplicity, gvsv is a PADOP and has ->padix point to a PAD containing the GV
				# Without, gvsv is an SVOP and has the GV directly.
				my $gv;
				if (B::class($nx) eq 'PADOP') {
					my $gvix = $nx->padix;
					my $gvslot = $pad->ARRAYelt($gvix);
					$gv = $gvslot->object_2svref;
				}
				else { # B::class($nx) eq 'SVOP'
					$gv = $op->sv->object_2svref;
				}
				my $name = *$gv{NAME};
				if ($nx->name eq 'gvsv' or $op->name eq 'rv2sv') {
					$name = '$' . $name;
				}
				elsif ($op->name eq 'rv2av') {
					$name = '@' . $name;
				}
				elsif ($op->name eq 'rv2hv') {
					$name = '%' . $name;
				}
				elsif ($op->name eq 'rv2gv') {
					$name = '*' . $name;
				}
				else {
					return; # Fallback to default message.
				}
				if ($op->private & B::OPpOUR_INTRO) { # our statement introduced a global
					op_die "Can't share 'our' variable '$name'";
				}
				else { # Qualified, previously-declared, or 'no strict'
					op_die "Can't share global symbol '$name'";
				}
			}
		}
	}

	walk_ops {
		if (B::class($_) eq "COP") {
			$cop = $_;
			return ();
		}
		return () unless B::class($_) eq "UNOP";
		return () unless $_->name eq 'entersub';
		my @argops = op_kids $_;
		if (@argops == 1) {
			@argops = op_kids $_->first;
		}
		op_assert {@argops > 1} "What no arguments?";
		my $subop = pop @argops;
		# Check if it is the sub shared...
		return unless op_is_sub($pad, $subop, \&Irssi::Script::perlalias::aliaspkg::shared);
		# At this point forward, we start triggering exceptions if we find something we don't like.
		$argops[0]->name eq 'pushmark' and shift @argops;
		# We want only a single argument.
		for my $op (@argops) {
			my ($name, $ref, $state_control_index);
			try_basic_state($op) and next;
			try_multi_state($op) and next;
			try_initializer_state($op) and next;
			nicer_errors $op;
			op_die "Invalid use of shared";
		}
	} $invoke_cv->ROOT;
}

# Some assorted debugging aids... Use via /script exec I guess.
sub dump_aliases {
	while (my ($alias, $package) = each %alias_packages) {
		Irssi::print("Alias '$alias' : Package '$package'");
		no strict 'refs';
		if ($alias eq ${"${package}::_name"}) {
			Irssi::print "-> _name is correct";
		}
		else {
			Irssi::print "-> !!! _name is not correct! " . ${"${package}::_name"};
		}
		Irssi::print "-> Original code: " . ${"${package}::_text"};
		if (defined(my $err = ${"${package}::_error"})) {
			Irssi::print "-> Script did not compile: $err";
		}
		else {
			my $cv = "$package"->can("invoke");
			Irssi::print "-> PADNAME listing: [index] [name] [flags]";
			{
				my $cvb = B::svref_2object($cv);
				my $cvpl = $cvb->PADLIST;
				my $cvpn = $cvpl->NAMES;
				for my $ix ( 0 .. $cvpn->MAX) {
					my $pn = $cvpn->ARRAYelt($ix);
					if ($pn->isa("B::PADNAME")) {
						Irssi::print sprintf("[%d] [%s] [%x]", $ix, $pn->PVX//"(null)", $pn->FLAGS);
					}
				}
			}

			Irssi::print "-> Concise dump:";
			my $concise = "";
			open my $fd, ">", \$concise;
			my $prev = B::Concise::walk_output;
			B::Concise::walk_output $fd;
			B::Concise::concise_subref(basic => $cv, "${package}::invoke");
			B::Concise::walk_output $prev; # Set back to 
			Irssi::print $concise;
		}
	}
}
