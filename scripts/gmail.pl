use strict;
use warnings;
use Irssi;
use Email::Send::SMTP::Gmail;
use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
	authors     => 'Pablo Martín Báez Echevarría',
	contact     => 'pab_24n@outlook.com',
	name        => 'gmail',
	description => 'send email using Google\'s SMTP server (require Email::Send::SMTP::Gmail)',
	license     => 'Public domain',
	url         => 'http://reirssi.wordpress.com',
	changed     => '15:40:45, Sep 23rd, 2014 UYT',
);

Irssi::settings_add_str('gmail', 'gmail_user', '');
Irssi::settings_add_str('gmail', 'gmail_pass', '');

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

GMAIL -to <address> [-cc <address>] [-bcc <address>] [-subject <subject>] [-body <body>] [-attachments <paths>]

    -to, cc, bcc: comma separated email addresses
    -subject: subject text
    -body: body text
    -attachments: comma separated files with full path
    
Remember that if a parameter consists of more than one word, it must be quoted.

Example:

/GMAIL -to pab_24n\@outlook.com -subject "Subject of my email" -body "Hey there! Just testing my script."

To configure this script:

/set gmail_user user\@gmail.com
/set gmail_pass user_password
SCRIPTHELP_EOF
			,MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop;
	}
}


sub cmd_gmail ($$$) {
	my ($args, $server, $witem) = @_;
	
	my ($options, $trash) = Irssi::command_parse_options('gmail', $args);
	my $to = $options->{to};
	my $cc = (defined $options->{cc}) ? $options->{cc} : "";
	my $bcc = (defined $options->{bcc}) ? $options->{bcc} : "";
	my $subject = (defined $options->{subject}) ? $options->{subject} : "";
	my $body = (defined $options->{body}) ? $options->{body} : "";
	my $attachments = (defined $options->{attachments}) ? $options->{attachments} : "";
	
	if(!$to) {
		print_external_format(Irssi::MSGLEVEL_CLIENTERROR, 'fe-common/core', 'not_enough_params');
		return;
	}
	
	my $user     = Irssi::settings_get_str("gmail_user");
	my $password = Irssi::settings_get_str("gmail_pass");

	my ($mail, $error) = Email::Send::SMTP::Gmail->new( -smtp=>'smtp.gmail.com',
                                                            -login=>"$user",
                                                            -layer=> 'ssl',
                                                            -port=> '465',
                                                            -pass=> "$password" );
	if ($mail == -1) {
		Irssi::print("%U%9ERROR%9%U: $error", MSGLEVEL_CLIENTERROR);
		return;
	}

	$mail->send(-to=>"$to", -cc=>"$cc", -bcc=>"$bcc", -subject=>"$subject",
	            -body=>"$body", -attachments=>"$attachments" );
	Irssi::print('The email was successfully sent to '.$to.'.', MSGLEVEL_CLIENTNOTICE);
	$mail->bye;
}

Irssi::command_bind('gmail', \&cmd_gmail);
Irssi::command_bind('help', \&cmd_help);
Irssi::command_set_options('gmail', '+to -cc -bcc -subject -body -attachments');
