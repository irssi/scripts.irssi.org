#################################
#       WISESTAMP MANUAL        #
#################################
#                               #
# /set wisestamp_indent [num]   # 
#                               #  
#################################

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.1";
%IRSSI = (
	  authors     => 'Antti Ruokomäki',
	  contact     => 'antti.ruokomaki@mbnet.fi',
	  name        => 'wisestamp',
	  description => 'If timestamp_timeout is used, the text '.
	                 'will be indented when the stamp is hidden',
	  license     => 'Public Domain',
	  changed     => 'Wed Apr 12 22:46:00 2006'
	  );


my $timeout;
my $indent_str;

# $inprogress prevents infinite printint loops
my $inprogress = 0;

# The main function
sub show_stamp_shadow {

    return if ($inprogress
	       || $timeout == '0'
	       || Irssi::settings_get_bool('timestamps') == 0);

    $inprogress = 1;    

    my ($destination, $text, $stripped) = @_;
    my $last_stamp = $destination->{window}->{last_timestamp};
    my $time_from_last_stamp = time() - $last_stamp;
    
    # Add indent if timestamp is hidden
    if( $time_from_last_stamp < $timeout ) {
	$text = $indent_str.$text;
    }

    # Output the manipulated text
    Irssi::signal_emit('print text', $destination, $text, $stripped);
    $inprogress = 0;
    Irssi::signal_stop(); 
} 


# Reset settings on startup and when settings change
sub check_settings {

    # Recalculate the indent string
    my $indent = Irssi::settings_get_int('wisestamp_indent');
    $indent_str = '';
    for (my $count=0; $count<$indent; $count++) {
	$indent_str .= ' ';
    }

    # Check out the timeout
    $timeout = Irssi::settings_get_str('timestamp_timeout');
}


Irssi::settings_add_int('wisestamp', 'wisestamp_indent', 5);
Irssi::signal_add('setup changed' , \&check_settings);
Irssi::signal_add('print text'    , \&show_stamp_shadow);

check_settings();