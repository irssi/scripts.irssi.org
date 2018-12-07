use strict;
use Irssi;

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'John Sullivan',
    contact     => 'johnsullivan.pem@gmail.com',
    name        => 'ignore_topics',
    description => 'Ignores topic messages for IRC channels.',
    license     => 'MIT',
);


sub sig_print_text {
	my ($dest, $string, $stripped) = @_;
	if ($dest->{'level'} & MSGLEVEL_CRAP) {
		if ($stripped =~ /Topic for #|Topic set by/) {
			Irssi::signal_stop();
		}
	}
}

Irssi::signal_add_first('print text', \&sig_print_text);
