use strict;
use vars qw($VERSION %IRSSI);
use File::Basename;
use File::Fetch;
use File::Glob ':bsd_glob';
use Getopt::Long qw/GetOptionsFromString/;

use Irssi;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'theme',
    description	=> 'activate, show or get theme',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-11',
    modules => 'File::Basename File::Fetch File::Glob Getopt::Long',
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
  -help|-l
%9description%9
  $IRSSI{description}
END

my (@tl, $count);
my ($show, $update, $get, $list, $phelp);
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

my ($theme_source, $theme_local);

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

sub cmd_set {
	my ($args, $server, $witem)=@_;
	my $t =  $tl[$count];
	if (defined $t) {
		Irssi::settings_set_str('theme',$t);
		Irssi::signal_emit('setup changed');
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
		cmd_get($args, $server, $witem);
		$get = undef;
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
	if (defined $phelp) {
		cmd_help($IRSSI{name}, $server, $witem);
		$phelp = undef;
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

sub cmd_get {
	my ($args, $server, $witem)=@_;
	local $File::Fetch::WARN=0;
	$get.= '.theme' if $get !~ m/\.theme/;
	my $ff= File::Fetch->new(uri => $theme_source.$get);
	my $where = $ff->fetch( to => $theme_local ) or
		Irssi::print("Error: $theme_source$get not found",
			MSGLEVEL_CLIENTCRAP);
	init();
}

sub sig_setup_changed {
	$theme_source= Irssi::settings_get_str($IRSSI{name}.'_source');
	$theme_source.= '/' if $theme_source !~ m#/$#;
	my $l= Irssi::settings_get_str($IRSSI{name}.'_local');
	$theme_local= bsd_glob $l;
	$theme_local.= '/' if $theme_local !~ m#/$#;
}

sub do_complete {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	return unless $linestart =~ m#^/$IRSSI{name}#;
	return if $word =~ m#^-#;
	@$strings = grep { m/^$word/} @tl;
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
}

Irssi::signal_add_first('complete word',  \&do_complete);
Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_source', 'https://irssi-import.github.io/themes/');
Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_local', Irssi::get_irssi_dir());

Irssi::command_bind($IRSSI{name}, \&cmd);
my @opt=map {s/=.*$//, $_}  keys %options;
Irssi::command_set_options($IRSSI{name}, join(" ", @opt));
Irssi::command_bind('help', \&cmd_help);

init();
sig_setup_changed();
