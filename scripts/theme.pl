use strict;
use vars qw($VERSION %IRSSI);
use POSIX;
use File::Basename;
use File::Fetch;
use File::Glob ':bsd_glob';
use Getopt::Long qw/GetOptionsFromString/;
use Storable qw/store_fd fd_retrieve/;
use YAML::XS;

use Irssi;

$VERSION = '0.04';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'theme',
    description	=> 'activate, show or get theme',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2020-04-12',
    modules => 'POSIX File::Basename File::Fetch File::Glob Getopt::Long Storable YAML::XS',
    commands=> 'theme',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Synopsis%9
  /theme {-g|-get} <theme>
  /theme [theme] [options]
%9Options%9
  -next|-n      next theme in dir
  -previous|-p  previous theme in dir
  -show|-s      show a test text
  -reload|-r    reload the dir
  -get|-g       get a theme form a website
  -list|-l      list theme in dir
  -update|-u    download themes.yaml
  -info|-i      print info
  -fg_color|-f  set or reset the foreground color
  -bg_color|-b  set or reset the background color
  -help|-h
%9Description%9
  $IRSSI{description}
%9Settings%9
  /set theme_source https://irssi-import.github.io/themes/
  /set theme_local ~/.irssi/
  /set theme_autocolor off
%9Color%9
  the script can set
    VT100 text foreground color
    VT100 text background color
  tested with xterm, konsole, lxterm
%9See also%9
  https://irssi-import.github.io/themes/
  https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Operating-System-Commands
  https://en.wikipedia.org/wiki/X11_color_names
END

my (%themes, @dtl);
my (@tl, $count);
my ($show, $update, $get, $list, $phelp, $info, $yupdate, $fg_color, $bg_color);
my ($noxterm);
my %options = (
	'n' => sub{ $count++; $update=1},
	'next' => sub{ $count++; $update=1},
	'p' => sub{ $count--; $update=1},
	'previous' => sub{ $count--; $update=1},
	's' => \$show,
	'show' => \$show,
	'r' => \&init,
	'reload' => \&init,
	'g=s' => \$get,
	'get=s' => \$get,
	'l' => \$list,
	'list' => \$list,
	'h' => \$phelp,
	'help' => \$phelp,
	'u' => \$yupdate,
	'update' => \$yupdate,
	'i:s' => \$info,
	'info:s' => \$info,
	'f:s' => \$fg_color,
	'fg_color:s' => \$fg_color,
	'b:s' => \$bg_color,
	'bg_color:s' => \$bg_color,
);

my $lorem = << 'END';
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd
gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum
dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor
invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero
eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no
sea takimata sanctus est Lorem ipsum dolor sit amet.
END

my ($theme_source, $theme_local, $theme_autocolor);
my %bg_process= ();

sub background {
	my ($cmd) =@_;
	my ($fh_r, $fh_w);
	pipe $fh_r, $fh_w;
	my $pid = fork();
	if ($pid ==0 ) {
		my @res;
		@res= &{$cmd->{cmd}}(@{$cmd->{args}});
		store_fd \@res, $fh_w;
		close $fh_w;
		POSIX::_exit(1);
	} else {
		$cmd->{fh_r}=$fh_r;
		Irssi::pidwait_add($pid);
		$bg_process{$pid}=$cmd;
	}
}

sub sig_pidwait {
	my ($pid, $status) = @_;
	if (exists $bg_process{$pid}) {
		my @res= @{ fd_retrieve($bg_process{$pid}->{fh_r})};
		$bg_process{$pid}->{res}=[@res];
		if (exists $bg_process{$pid}->{last}) {
			foreach my $p (@{$bg_process{$pid}->{last}}) {
				&$p($bg_process{$pid});
			}
		} else {
			Irssi::print(join(" ",@res), MSGLEVEL_CLIENTCRAP);
		}
		delete $bg_process{$pid};
	}
}

sub cmd_show {
	my ($args, $server, $witem)=@_;
	my $t = Irssi::settings_get_str('theme');
	if (defined $witem) {
		$witem->print(
			"-----  $t -- $count  -----",
			MSGLEVEL_CLIENTCRAP);
		$witem->command('names');
		core_printformat_module_w($witem,
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'pubmsg', 'testnick', $lorem, '@');
		core_printformat_module_w($witem,
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'pubmsg_me', 'testnick',
			'me: '.substr($lorem, 0, 30),'@');
		core_printformat_module_w($witem,
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'own_msg', 'me',
			substr($lorem, 0, 30),'@');
	} else {
		Irssi::print(
			"-----  $t  -- $count -----",
			MSGLEVEL_CLIENTCRAP);
		core_printformat_module(
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'pubmsg', 'testnick', $lorem, '@');
		core_printformat_module(
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'pubmsg_me', 'testnick',
			'me: '.substr($lorem, 0, 30),'@');
		core_printformat_module(
			MSGLEVEL_CLIENTCRAP, 'fe-common/core', 'own_msg', 'me',
			substr($lorem, 0, 30),'@');
	}
}

sub core_printformat_module {
  my ($level, $module, $format, @args) = @_;
  {
    local *CORE::GLOBAL::caller = sub { $module };
    Irssi::printformat($level, $format, @args);
  }
}

sub core_printformat_module_w {
  my ($witem, $level, $module, $format, @args) = @_;
  {
    local *CORE::GLOBAL::caller = sub { $module };
    $witem->printformat($level, $format, @args);
  }
}

sub set_fg_color {
	my ($fg) = @_;
	if ($ENV{'TERM'} =~ m/^xterm/) {
		if ( defined $fg ) {
			print STDERR "\033]10;$fg\a";
		} else {
			print STDERR "\033]110\a";
		}
	} else {
		$noxterm.=" and " if ($noxterm);
		$noxterm.="fg_color:$fg";
	}
}

sub set_bg_color {
	my ($bg) = @_;
	if ($ENV{'TERM'} =~ m/^xterm/) {
		if ( defined $bg) {
			print STDERR "\033]11;$bg\a";
		} else {
			print STDERR "\033]111\a";
		}
	} else {
		$noxterm.=" and " if ($noxterm);
		$noxterm.="bg_color:$bg";
	}
}


sub get_theme {
	my ($args)=@_;
	local $File::Fetch::WARN=0;
	$get.= '.theme' if $get !~ m/\.theme/;
	my $ff= File::Fetch->new(uri => $theme_source.$get);
	my $where = $ff->fetch( to => $theme_local ) or
		return	"Error: $theme_source$get not found";
	return "$get downloaded.";
}

sub get_yaml {
	local $File::Fetch::WARN=0;
	my $get='themes.yaml';
	if (-e $theme_local.$get) {
		unlink $theme_local.$get;
	}
	my $ff= File::Fetch->new(uri => $theme_source.$get);
	my $where = $ff->fetch( to => $theme_local ) or
		return	"Error: $theme_source$get not found";
	return "$get downloaded.";
}

sub cmd_set {
	my ($args, $server, $witem)=@_;
	my $t =  $tl[$count];
	if (defined $t) {
		Irssi::settings_set_str('theme',$t);
		Irssi::signal_emit('setup changed');
		if ($theme_autocolor) {
			set_fg_color($themes{$t}->{fgColor});
			set_bg_color($themes{$t}->{bgColor});
		}
	}
}

sub cmd {
	my ($args, $server, $witem)=@_;
	my ($ret, $arg) = GetOptionsFromString($args, %options);
	if ( defined $$arg[0]) {
		my $c=0;
		foreach my $t (@tl) {
			if ($t eq $$arg[0]) {
				$count=$c;
				last;
			}
			$c++;
		}
		cmd_set();
	}
	if (defined $update) {
		if ($count <0) {
			$count = $#tl+$count+1;
		}
		if ($count >$#tl) {
			$count = $count-$#tl-1;
		}
		cmd_set();
		$update= undef;
	}
	if (defined $show) {
		cmd_show($args, $server, $witem);
		$show = undef;
	}
	if (defined $get) {
		my $cmd;
		$cmd->{cmd}=\&get_theme;
		$cmd->{args}=[$args];
		$cmd->{last}=[
			\&init,
			\&print_result,
		];
		background( $cmd );
		$get = undef;
	}
	if (defined $yupdate) {
		my $cmd;
		$cmd->{cmd}=\&get_yaml;
		$cmd->{last}=[
			\&init,
			\&print_result,
		];
		background( $cmd );
		$yupdate = undef;
	}
	if (defined $list) {
        my $c=0;
		foreach (@tl) {
            if ($c == $count) {
                Irssi::print(">>$_<<", MSGLEVEL_CLIENTCRAP);
            } else {
                Irssi::print("  $_", MSGLEVEL_CLIENTCRAP);
            }
            $c++;
		}
		$list = undef;
	}
	if (defined $info) {
		cmd_info($args, $server, $witem);
		$info = undef;
	}
	if (defined $phelp || $args eq '' ) {
		cmd_help($IRSSI{name}, $server, $witem);
		$phelp = undef;
	}
	if (defined $fg_color) {
		if (length($fg_color)>0) {
			set_fg_color($fg_color);
		} else {
			set_fg_color();
		}
		$fg_color= undef;
	}
	if (defined $bg_color) {
		if (length($bg_color)>0) {
			set_bg_color($bg_color);
		} else {
			set_bg_color();
		}
		$bg_color= undef;
	}
	if (defined $noxterm) {
		Irssi::print(
			"Do not know how to set colour for your terminal ($ENV{TERM})."
			, MSGLEVEL_CLIENTCRAP);
		Irssi::print(
			"Manually configure it for $noxterm"
			, MSGLEVEL_CLIENTCRAP);
		$noxterm= undef;
	}
}

sub cmd_info {
	my ($args, $server, $witem)=@_;
	Irssi::print("Info: $info", MSGLEVEL_CLIENTCRAP);
	if (exists $themes{$info}) {
		Irssi::print(Dump($themes{$info}), MSGLEVEL_CLIENTCRAP);
	} elsif (exists $themes{$tl[$count]}) {
		Irssi::print(Dump($themes{$tl[$count]}), MSGLEVEL_CLIENTCRAP);
	}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub sig_setup_changed {
	$theme_source= Irssi::settings_get_str($IRSSI{name}.'_source');
	$theme_source.= '/' if $theme_source !~ m#/$#;
	my $l= Irssi::settings_get_str($IRSSI{name}.'_local');
	$theme_local= bsd_glob $l;
	$theme_local.= '/' if $theme_local !~ m#/$#;
	$theme_autocolor= Irssi::settings_get_bool($IRSSI{name}.'_autocolor');
}

sub print_result {
	my ($cmd) = @_;
	if (defined $cmd->{res}->[0]) {
		Irssi::print($cmd->{res}->[0] , MSGLEVEL_CLIENTCRAP);
	}
}

sub do_complete {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	return unless $linestart =~ m#^/$IRSSI{name}#;
	return if $word =~ m#^-#;
	if ( $linestart !~ m/(-g|-get|-i|-info)/ ) {
		@$strings = grep { m/^$word/} @tl;
	} else {
		@$strings = grep { m/^$word/} @dtl;
	}
	Irssi::signal_stop;
}

sub init {
	my $theme = Irssi::settings_get_str('theme');
	my $p1= Irssi::get_irssi_dir();
	my @t = bsd_glob $p1.'/*.theme';
	@tl=();
	my $c=0;
	foreach my $fn (@t) {
		$fn = basename($fn, '.theme');
		push @tl, $fn;
		$count=$c if $theme eq $fn;
		$c++;
	}
	$lorem =~ s/\n/ /g;
	if (-e $p1.'/themes.yaml') {
		@dtl=undef;
		my @l;
		open my $fi, '<',$p1.'/themes.yaml';
		my $syml= do {local $/; <$fi>};
		close $fi;
		eval {
			@l = @{Load($syml)};
		};
		if (length($@) >0) {
			print $@;
		} else {
			foreach my $e (@l) {
				$themes{$e->{name}}=$e;
				push @dtl, $e->{name};
			}
		}
	}
}

Irssi::signal_add_first('complete word',  \&do_complete);
Irssi::signal_add('setup changed', \&sig_setup_changed);
Irssi::signal_add('pidwait', \&sig_pidwait);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_source', 'https://irssi-import.github.io/themes/');
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_local', Irssi::get_irssi_dir());
Irssi::settings_add_bool($IRSSI{name} ,$IRSSI{name}.'_autocolor', 0);

Irssi::command_bind($IRSSI{name}, \&cmd);
my @opt=map {s/[=:].*$//, $_}  keys %options;
Irssi::command_set_options($IRSSI{name}, join(" ", @opt));
Irssi::command_bind('help', \&cmd_help);

init();
sig_setup_changed();

if (!(-e $theme_local.'themes.yaml')) {
	my $cmd;
	$cmd->{cmd}=\&get_yaml;
	$cmd->{last}=[
		\&init,
		\&print_result,
	];
	background( $cmd );
}
