use strict;
use warnings;
use Email::Send::SMTP::Gmail;

use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = '1.1';
%IRSSI = (
	authors     => 'Pablo Martín Báez Echevarría',
	contact     => 'pab_24n@outlook.com',
	name        => 'gmail',
	description => 'send email using Google\'s SMTP server (require Email::Send::SMTP::Gmail)',
	license     => 'Public Domain',
	url         => 'http://reirssi.wordpress.com',
	changed     => '21:42:10, Oct 15th, 2014 UYT',
);

Irssi::settings_add_str('gmail', 'gmail_user', '');
Irssi::settings_add_str('gmail', 'gmail_pass', '');
Irssi::settings_add_str('gmail', 'gmail_sec_layer', 'tls');

sub print_external_format {
    my ($level, $module, $format, @args) = @_;
    {
        local *CORE::GLOBAL::caller = sub { $module };
        Irssi::printformat($level, $format, @args);
    }
}

sub cmd_help {
	if ($_[0] =~ /^gmail *$/i) {
		Irssi::print ( <<SCRIPTHELP_EOF

GMAIL -to <address> [-cc <address>] [-bcc <address>] [-subject <subject>] [-html] [-body <body>] [-attachments <paths>]

    -to, cc, bcc: comma separated email addresses
    -subject: subject text
    -body: body text
    -attachments: comma separated files with full path
    -html: specify that the body is html code instead of plain text
    
Remember that if a parameter consists of more than one word, it must be quoted.

Example:

/GMAIL -to pab_24n\@outlook.com -subject "Subject of my email" -body "Hey there! Just testing my script."

Settings:

/set gmail_user <user\@gmail.com>
/set gmail_pass <password>
/set gmail_sec_layer <tls|ssl> (default is tls)

This script can be used together with trigger.pl as in the following example:

/TRIGGER ADD -topics -command 'GMAIL -to pab_24n\@outlook.com -subject "New topic in \$C\@\$T" -html -body "<b>\$N</b> changed topic of <u>\$C</u> to:<br><i>\$M</i>"'
SCRIPTHELP_EOF
			,MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop;
	}
}


sub cmd_gmail {
	my ($args, $server, $witem) = @_;
	
	my ($options, $trash) = Irssi::command_parse_options('gmail', $args);
	my $to = $options->{to};
	my $cc = (defined $options->{cc}) ? $options->{cc} : "";
	my $bcc = (defined $options->{bcc}) ? $options->{bcc} : "";
	my $subject = (defined $options->{subject}) ? $options->{subject} : "";
	my $contenttype = (defined $options->{html}) ? "text/html" : "text/plain";
	my $body = (defined $options->{body}) ? $options->{body} : "";
	my $attachments = (defined $options->{attachments}) ? $options->{attachments} : "";
	
	if(!$to) {
		print_external_format(Irssi::MSGLEVEL_CLIENTERROR, 'fe-common/core', 'not_enough_params');
		return;
	}
	
	my $user     = Irssi::settings_get_str("gmail_user");
	my $password = Irssi::settings_get_str("gmail_pass");
	my $layer    = lc(Irssi::settings_get_str("gmail_sec_layer"));
	
	if ($layer !~ /^(?:tls|ssl)$/) {
		Irssi::printformat(Irssi::MSGLEVEL_CLIENTERROR, "gmail_error", "Invalid secure layer. See /help gmail");
		return;
	}
	
	my $port = ($layer eq "tls") ? 587 : 465;
	
	my ($mail, $error) = Email::Send::SMTP::Gmail->new( -smtp =>'smtp.gmail.com',
                                                            -login=>"$user",
                                                            -pass =>"$password",
                                                            -layer=>"$layer",
                                                            -port =>"$port" );
        
	if ($mail == -1) {
		$error =~ s/\x0d//g;
		Irssi::printformat(Irssi::MSGLEVEL_CLIENTERROR, "gmail_error", $error);
		return;
	}

	$mail->send(-to=>"$to", -cc=>"$cc", -bcc=>"$bcc", -subject=>"$subject",
	            -contenttype=>"$contenttype", -body=>"$body", -attachments=>"$attachments" );
	Irssi::print('Your email was sent successfully.', MSGLEVEL_CLIENTNOTICE);
	$mail->bye;
}

Irssi::theme_register([
    "gmail_error", '{error ERROR} $0',
]);

Irssi::command_bind('gmail', \&cmd_gmail);
Irssi::command_bind('help', \&cmd_help);
Irssi::command_set_options('gmail', '+to -cc -bcc -subject -html -body -attachments');
