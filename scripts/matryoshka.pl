use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Storable qw/freeze thaw/;
use Compress::Zlib;
use Crypt::CBC;
use Crypt::Cipher::AES;
use File::Glob ':bsd_glob';
use CPAN::Meta::YAML;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'matryoshka',
    description	=> 'a password matryoshka',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-12-03',
    modules => 'Storable Compress::Zlib Crypt::CBC Crypt::Cipher::AES File::Glob '.
				'CPAN::Meta::YAML',
    commands=> 'matryoshka',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9description%9
  $IRSSI{description}
%9example%9
  /matryoshka expando add mynet /msg -mynet nickserv IDENTIFY account password
  /network add -autosendcmd '\$mynet' mynet

  /matryoshka startup add /connect ircserver port password nick
%9Settings%9
  %Umatryoshka_file%U
  %Umatryoshka_key%U
  %Umatryoshka_key_file%U
%9Commands%9
  %Usave%U
  %Udump%U
  %Uexpando%U
    list
    add <expando name> <string>
    remove <expando name>
    update
  %Ustartup%U
    list
    add <command string>
    remove <number>
    run
  %Uhelp%U
%9Warning%9
  The passwords are not save in this store!
END

my ($matryoshka_file, $matryoshka_key, $matryoshka_key_file);
my $db;
my $change=0;
my $key;
my %expandos;
my %expandosf;

sub cmd {
	my ($args, $server, $witem)=@_;
	my @args = split /\s+/,$args;
	my $arg = shift @args;
	my $cmd=0;
	if ( $arg eq 'save') {
		$change=1;
		savekeyfile();
		savefile();
		$cmd++;
	}
	if ( $arg eq 'dump') {
		cmd_dump($server, $witem, @args);
		$cmd++;
	}
	if ( $arg eq 'expando' ) {
		scmd_expando($server, $witem, @args);
		$cmd++;
	}
	if ( $arg eq 'startup' ) {
		scmd_startup($server, $witem, @args);
		$cmd++;
	}
	if ( $arg eq 'help' || $cmd == 0 ) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
	}
}

sub scmd_startup {
	my ($server, $witem, @args)=@_;
	my $arg= shift @args;
	if ($arg eq 'list') {
		sscmd_s_list($server, $witem, @args);
	}
	if ($arg eq 'add') {
		sscmd_s_add($server, $witem, @args);
	}
	if ($arg eq 'remove') {
		sscmd_s_remove($server, $witem, @args);
	}
	if ($arg eq 'run') {
		startup_run();
	}
}

sub sscmd_s_list {
	my ($server, $witem, @args)=@_;
	if (exists $db->{startup} ) {
		my $c=1;
		foreach (@{$db->{startup}}) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'startup_theme',
				$c, $_ );
			$c++;
		}
	}
}

sub sscmd_s_add {
	my ($server, $witem, @args)=@_;
	if (!exists $db->{startup} ) {
		$db->{startup}=[];
	}
	push @{$db->{startup}}, join(" ", @args);
	$change=1;
}

sub sscmd_s_remove {
	my ($server, $witem, @args)=@_;
	my $ex= shift @args;
	splice @{$db->{startup}}, $ex-1, 1;
	$change=1;
}

sub startup_run {
	if (exists $db->{startup} ) {
		foreach (@{$db->{startup}}) {
			Irssi::command($_);
		}
	}
}

sub scmd_expando {
	my ($server, $witem, @args)=@_;
	my $arg= shift @args;
	if ($arg eq 'list') {
		sscmd_e_list($server, $witem, @args);
	}
	if ($arg eq 'add') {
		sscmd_e_add($server, $witem, @args);
	}
	if ($arg eq 'remove') {
		sscmd_e_remove($server, $witem, @args);
	}
	if ($arg eq 'update') {
		updateexpandos();
	}
}

sub sscmd_e_list {
	my ($server, $witem, @args)=@_;
	if (exists $db->{expando} ) {
		foreach (sort keys %{$db->{expando}}) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'expando_theme',
				$_, $db->{expando}->{$_});
		}
	}
}

sub sscmd_e_add {
	my ($server, $witem, @args)=@_;
	if (!exists $db->{expando} ) {
		$db->{expando}={};
	}
	my $ex= shift @args;
	$db->{expando}->{$ex}= join " ", @args;
	$change=1;
}

sub sscmd_e_remove {
	my ($server, $witem, @args)=@_;
	my $ex= shift @args;
	delete $db->{expando}->{$ex};
	$change=1;
}

sub cmd_dump {
	my ($server, $witem, @args)=@_;
	my $yml= CPAN::Meta::YAML->new;
	push @$yml, $db;
	print $yml->write_string;
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub loadfile {
	my $fn= filename($matryoshka_file);
	if ( -e $fn) {
		my ($serial, $comp, $cyper);
		open my $fi, '<', $fn;
		local $/;
		$cyper= <$fi>;
		close $fi;
		my $cbc2 = Crypt::CBC->new( -cipher=>'Cipher::AES', -key=>$key );
		my $cyper2 = $cbc2->decrypt($cyper);
		my $cbc = Crypt::CBC->new( -cipher=>'Cipher::AES', -key=>$matryoshka_key );
		$comp = $cbc->decrypt($cyper2);
		$serial= uncompress( $comp );
		$db= thaw($serial);
		$change=0;
	}
}

sub savefile {
	my $fn= filename($matryoshka_file);
	my $serial= freeze( $db );
	my $comp;
	if ($change != 0) {
		$comp= compress( $serial, 9 );
		my $cbc = Crypt::CBC->new( -cipher=>'Cipher::AES', -key=>$matryoshka_key);
		my $ciphertext = $cbc->encrypt($comp);
		my $cbc2 = Crypt::CBC->new( -cipher=>'Cipher::AES', -key=>$key);
		my $ciphertext2 = $cbc2->encrypt($ciphertext);
		open my $fa, '>', $fn;
		print $fa $ciphertext2;
		close $fa;
	}
}

sub loadkeyfile {
	my $fn= filename($matryoshka_key_file);
	if (-e $fn) {
		open my $fi, '<', $fn;
		local $/;
		$key= <$fi>;
		close $fi;
	} else {
		savekeyfile();
	}
}

sub savekeyfile {
	my $fn= filename($matryoshka_key_file);
	$key= Crypt::CBC->random_bytes(16);
	$change=1;
	open my $fa, '>', $fn;
	print $fa $key;
	close $fa;
}

sub filename {
	my ($fn)= @_;
	if ($fn !~ m#/#) {
		$fn= Irssi::get_irssi_dir().'/'.$fn;
	} else {
		$fn= bsd_glob($fn);
	}
	return $fn;
}

sub updateexpandos {
	foreach (keys %{$db->{expando}}) {
		if (!defined $expandos{$_}) {
			my $fustr = '$expandosf{'.$_.'}= sub { return "'. $db->{expando}->{$_}.'";}';
			eval($fustr);
			Irssi::expando_create $_, $expandosf{$_}, { };
			$expandos{$_}=2;
		} else {
			$expandos{$_}=2;
		}
	}
	foreach (keys %expandos) {
		if ( $expandos{$_} == 1) {
			delete $expandos{$_};
			Irssi::expando_destroy $_;
		} else {
			$expandos{$_}=1;
		}
	}
}

sub sig_setup_changed {
	$matryoshka_file= Irssi::settings_get_str($IRSSI{name}.'_file');
	$matryoshka_key= Irssi::settings_get_str($IRSSI{name}.'_key');
	if ( $matryoshka_key eq '' ) {
		$matryoshka_key= Crypt::CBC->random_bytes(16);
		Irssi::settings_set_str($IRSSI{name}.'_key', $matryoshka_key);
		$change=1;
	}
	$matryoshka_key_file= Irssi::settings_get_str($IRSSI{name}.'_key_file');
}

sub UNLOAD {
	savefile();
}

Irssi::theme_register([
	'expando_theme', '{hilight $0} $1',
	'startup_theme', '{hilight $0} $1',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_file', 'matryoshka.store');
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_key', '');
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_key_file', '.matryoshka.key.file');

Irssi::command_bind($IRSSI{name}, \&cmd);
foreach ( qw/save dump expando startup/ ){
	Irssi::command_bind($IRSSI{name}.' '.$_, \&cmd);
}
foreach ( qw/list add remove update/ ){
	Irssi::command_bind($IRSSI{name}.' expando '.$_, \&cmd);
}
foreach ( qw/list add remove run/ ){
	Irssi::command_bind($IRSSI{name}.' startup '.$_, \&cmd);
}
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
loadkeyfile();
loadfile();
updateexpandos();
startup_run();
