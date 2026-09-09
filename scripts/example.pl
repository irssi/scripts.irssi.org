use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'noname',
    contact	=> 'noname@example.org',
    name	=> 'example',
    description	=> 'This script really does nothing. Sorry.',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-07',
    modules => '',
    commands=> 'example',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9description%9
  $IRSSI{description}
%9See also%9
  null.pl
  https://perldoc.perl.org/perl.html
  https://github.com/irssi/irssi/blob/master/docs/perl.txt
  https://github.com/irssi/irssi/blob/master/docs/signals.txt
  https://github.com/irssi/irssi/blob/master/docs/formats.txt
END

my $test_str;

sub cmd {
	my ($args, $server, $witem)=@_;
	if (defined $witem) {
		$witem->printformat(MSGLEVEL_CLIENTCRAP, 'example_theme',
			$test_str, $test_str, $test_str);
	} else {
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'example_theme',
			$test_str, $test_str, $test_str);
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
	$test_str= Irssi::settings_get_str($IRSSI{name}.'_test_str');
}

Irssi::theme_register([
	'example_theme', '{hilight $0} $1 {error $2}',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_test_str', 'hello world!');

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
