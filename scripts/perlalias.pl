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

The arguments given to the /alias when typed are put into $_ and are also split on whitespace and put into @_.
In addition, the variables $server and $witem will refer to the active server and window item respectively.

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

Additionally, all aliases added are linked to perlalias.pl: if it is unloaded, the aliases will be removed.

Aliases can be saved and reloaded with the usual /save and /reload (including autosave). Saved aliases are loaded at script load.

=head2 ChangeLog

=over

=item 1.0

First version.

=back

=cut

use strict;
use warnings FATAL => qw(all);
use Irssi;
use Irssi::Irc;
use Carp ();

#use Cwd;
use POSIX qw(strftime);

{ package Irssi::Nick; } # Keeps trying to look for this package but for some reason it doesn't get loaded.

our $VERSION = '1.1';
our %IRSSI = (
	authors => 'aquanight',
	contact => 'aquanight@gmail.com',
	name => 'perlalias',
	description => 'Quickly create commands from short perl blocks',
	license => 'public domain'
	);

# Bound commands
my %cmds; # Contains command entries. The entry has three items:
	# textcmd => Plaintext of the command to execute, which is used for loading/saving
	# cmpcmd => Compiled command, for executing.
	# tag => Our tag which we need to remove the command

# Package we execute all the commands within, to keep them away from our bits.
package Irssi::Script::perlalias::aliaspkg {
}

sub DESTROY {
	Symbol::delete_package("Irssi::Script::perlalias::aliaspkg::");
}

# Alias executor
sub exec_perlalias {
	my ($cmd, $data, $server, $witem) = @_;
	exists $cmds{$cmd} or return;
	defined $cmds{$cmd}->{cmpcmd} or return;
	local $_ = $data;
	$cmds{$cmd}->{cmpcmd}->($server, $witem, split / +/, $data);
}

# Bind a command
sub setup_command {
	my ($cmd, $data) = @_;
	# Compile the script.
	my $code = qq{package Irssi::Scripts::perlalias::aliaspkg;\nno warnings;\nsub {my \$server = shift; my \$witem = shift;\n#line 1 "perlalias $cmd"\n$data}\n};
	my $proc = eval $code;
	if ($@) {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_compile_error => $cmd);
		Irssi::print(MSGLEVEL_CLIENTERROR, $@);
		return "";
	}
	if (exists($cmds{$cmd})) {
		my $entry = $cmds{$cmd};
		$entry->{textcmd} = $data;
		$entry->{cmpcmd} = $proc;
	}
	else {
		my $entry = {};
		my $tag = sub { exec_perlalias $cmd, @_; };
		foreach my $existing_cmd (Irssi::commands()) {
			if ($existing_cmd->{cmd} eq $cmd) {
				Irssi::print_format(MSGLEVEL_CLIENTERROR, perlalias_cmd_in_use => $cmd);
				return "";
			}
		}
		$entry->{textcmd} = $data;
		$entry->{cmpcmd} = $proc;
		$entry->{tag} = sub { exec_perlalias $cmd, @_; };
		Irssi::command_bind($cmd, $entry->{tag});
		$cmds{$cmd} = $entry;
	}
	return 1;
}

sub remove_command {
	my ($cmd) = @_;
	if (exists($cmds{$cmd})) {
		my $entry = $cmds{$cmd};
		$entry->{tag}//die "Missing the tag we need to remove the alias!!!";
		Irssi::command_unbind($cmd, $entry->{tag});
		delete $cmds{$cmd};
		return 1;
	}
	else {
		Irssi::printformat(MSGLEVEL_CLIENTERROR, perlalias_not_found => $cmd);
		return "";
	}
}

sub list_commands {
	my ($prefix) = @_;
	my @whichones = sort grep /^\Q$prefix\E/, keys %cmds;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'perlaliaslist_header');
	for my $name (@whichones) {
		my $entry = $cmds{$name};
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, perlaliaslist_line => $name, $entry->{textcmd});
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
		if (remove_command($command)) { Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_removed => $command); }
	}
	elsif (($script//"") eq "") {
		list_commands $command;
	}
	else {
		if (setup_command($command, $script)) { Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_added => $command); }
	}

}

sub cmd_perlunalias {
	my ($data, $server, $witem) = @_;
	if (remove_command $data) { Irssi::printformat(MSGLEVEL_CLIENTNOTICE, perlalias_removed => $data); }
}

sub sig_setup_saved {
	my ($main, $auto) = @_;
	my $file = Irssi::get_irssi_dir() . "/perlalias";
	open my $fd, '>', $file or return;
	for my $cmd (keys %cmds) {
		my $entry = $cmds{$cmd};
		printf $fd "%s\t%s\n", $cmd, $entry->{textcmd};
	}
	close $fd;
}

sub sig_setup_reread {
	my $file = Irssi::get_irssi_dir() . "/perlalias";
	open my $fd, "<", $file or return;
	my $ln;
	my %newcmds;
	while (defined($ln = <$fd>)) {
		chomp $ln;
		my ($cmd, $script) = split /\t/, $ln, 2;
		if (exists $newcmds{$cmd}) {
			Irssi::print(MSGLEVEL_CLIENTERROR, "There is a duplicate record in the PerlAlias save file.");
			Irssi::print(MSGLEVEL_CLIENTERROR, "Offending alias: $cmd");
			Irssi::print(MSGLEVEL_CLIENTERROR, "Previous definition: " . $newcmds{$cmd});
			Irssi::print(MSGLEVEL_CLIENTERROR, "Duplicate definition: $script");
		}
		$newcmds{$cmd} = $script;
	}
	# Scrub the existing list. Update existings, remove any that aren't in the config, then we'll add any that's new.
	my @currentcmds = keys %cmds;
	for my $cmd (@currentcmds) {
		if (exists $newcmds{$cmd}) {
			setup_command($cmd, $newcmds{$cmd});
		}
		else {
			remove_command($cmd);
		}
		delete $newcmds{$cmd};
	}
	# By this point all that should be in newcmds is any ... new commands.
	for my $cmd (keys %newcmds) {
		setup_command($cmd, $newcmds{$cmd});
	}
	close $fd;
}

sub sig_complete_perlalias {
	my ($lst, $win, $word, $line, $want_space) = @_;
	$word//return;
	$line//return;
	$lst//return;
	if ($line ne '') {
		my $def = $cmds{$line};
		$def//return;
		push @$lst, $def->{textcmd};
		Irssi::signal_stop();
	}
	else {
		push @$lst, (grep /^\Q$word\E/i, keys %cmds);
		Irssi::signal_stop();
	}
}

sub sig_complete_perlunalias {
	my ($lst, $win, $word, $line, $want_space) = @_;
	$lst//return;
	$word//return;
	push @$lst, (grep /^\Q$word\E/i, keys %cmds);
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
	'perlalias_cmd_in_use' => 'Command {hilight $0} is already in use',
	'perlalias_added' => 'PerlAlias {hilight $0} added',
	'perlalias_removed' => 'PerlAlias {hilight $0} removed',
	'perlalias_not_found' => 'PerlAlias {hilight $0} not found',
	'perlaliaslist_header' => '%#PerlAliases:',
	# $0 Name of alias, $1 alias text
	'perlaliaslist_line' => '%#$[10]0 $1',
);

Irssi::theme_register([%formats]);

sig_setup_reread;
