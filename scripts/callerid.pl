use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => 'Daniel "dubkat" Reidy',
    contact     => 'dubkat@dubkat.org (www.dubkat.org)',
    name        => 'callerid',
    description => 'Reformats CallerID (+g) Messages
               (Also known as Server-Side Ignore)
               on Hybrid & Ratbox IRCDs (EFnet)
               to be Easier on the Eyes',
    license     => 'GPL',
    url         => 'http://scripts.irssi.org/',
);

#########################################################################################
#	Thanks to Geert and Senneth for helping me out with my first irssi script!	#
#	Hopefully someone will find this useful.					#
#											#
#	Callerid is used to block messages from users at the server.			#
#	Callerid mode is activated by usermode +g on Hybrid and Ratbox servers (EFnet)	#
#	The ircd maintains a list of users that may message you.			#
#	To add users to the list, do /quote accept NICK					#
#	The IRCD will *NOT* inform you that the user has been added.			#
#	To remove a user from the list do /quote accept -NICK				#
#	The IRCD will *NOT* inform you that the user has been removed.			#
#	To see a list of users on your accept list do /quote accept *			#
#											#
#	The following alias may make life easier:					#
#	alias accept quote accept							#
#########################################################################################

Irssi::signal_add('event 716', 'callerid_them');
	sub callerid_them {
		my ($server, $data) = @_;
		my (undef, $nick, undef) = split(/ +/, $data, 3);
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'callerid_them', $nick);
		Irssi::signal_stop();
	}

Irssi::signal_add('event 717', 'callerid_them_notified');
	sub callerid_them_notified { 
		my ($server, $data) = @_;
		my (undef, $nick, undef) = split(/ +/, $data, 3);
                $server->printformat($nick, MSGLEVEL_CLIENTCRAP, 'callerid_them_notified', $nick);
                Irssi::signal_stop();
        }

Irssi::signal_add('event 282', 'callerid_accept_eof');
	sub callerid_accept_eof { Irssi::signal_stop(); }

Irssi::signal_add('event 718', 'callerid_you');
	sub callerid_you {
		my ($server, $data) = @_;
		my (undef, $nick, $host, undef) = split(/ +/, $data, 4);
		$server->printformat($nick, MSGLEVEL_CLIENTCRAP, 'callerid_you', $nick, $host);
		Irssi::signal_stop();
	}

Irssi::signal_add('event 281', 'callerid_accept_list');
	sub callerid_accept_list {
		my ($server, $data) = @_;
		my (undef, $list, undef) = split(/ +/, $data, 3);
		$data =~ s/^\S+\s//;
		$data =~ s/\s+:$//;
		$server->printformat($data, MSGLEVEL_CLIENTCRAP, 'callerid_accept_list', $data);
		Irssi::signal_stop();
	}


Irssi::signal_add('event 457', 'callerid_accept_exsists');
	sub callerid_accept_exsists {
		my ($server, $data) = @_;
		my (undef, $nick, undef) = split(/ +/, $data, 3);
		Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'callerid_accept_exsists', $nick);
		Irssi::signal_stop();
	}


Irssi::signal_add('event 458', 'callerid_not_on_list');
        sub callerid_not_on_list {
                my ($server, $data) = @_;
                my (undef, $info, undef) = split(/ +/, $data, 3);
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'callerid_not_on_list', $info);
                Irssi::signal_stop();
        }

Irssi::signal_add('event 456', 'callerid_full');
	sub callerid_full {
		my ($server, $data) = @_;
                my (undef, $info) = split(/ +/, $data, 2);
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'callerid_full', $info);
                Irssi::signal_stop();
        }

Irssi::signal_add('event 401', 'callerid_invalid_nick');
        sub callerid_invalid_nick{
                my ($server, $data) = @_;
                my (undef, $info, undef) = split(/ +/, $data, 3);
                Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'callerid_invalid_nick', $info);
                Irssi::signal_stop();
        }


Irssi::theme_register
  (
     [
	'callerid_them',
	'%_[%_%RCALLERID%n%_]%_ %W$0%n is in server-side ignore.',

	'callerid_you',
	'%_[%_%yCALLERID%n%_]%_ %W$0%n ($1) is attempting to message you.',

	'callerid_accept_list',
	'%_[%_%gACCEPTED%n%_]%_ %W$0%n',

	'callerid_accept_exsists',
	'%_[%_%BCALLERID%n%_]%_ %W$0%n Is Already On Your Accept List. Do %_/quote accept *%_ for a list :)',

	'callerid_full',
	'%_[%_%pCALLERID%n%_]%_ List is full. Do %_/quote accept *%_ for a list',

        'callerid_not_on_list',
        '%_[%_%pCALLERID%n%_]%_ $0 is not a user on your accept list.',

        'callerid_invalid_nick',
        '%_[%_%pCALLERID%n%_]%_ Cannot add/remove $0. That nick does not exist.',

        'callerid_them_notified',
        '%_[%_%rCALLERID%n%_]%_ %_$0%_ has been notified that you attempted to message them. (They will not notified of further messages for 60sec).',

     ]
  );
