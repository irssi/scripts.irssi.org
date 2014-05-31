#!/usr/local/bin/perl

# BgTA SCRIPT

use strict;
use vars qw($VERSION %IRSSI %FEATURES);

use Irssi;

# Define Script Version
$VERSION = '0.0.1';
%IRSSI = (
	authors		=> '[^BgTA^]',
	contact		=> 'raul@bgta.net',
	name		=> 'BgTA Script',
	description	=> 'Byte\'s Gallery of the TAilor Script',
	license		=> 'Public Domain',
);

# /bgversion command

sub cmd_bgversion {
	my ($data, $server, $witem) = @_;

	print("\cC4BgTA Script v. ".$VERSION);
	foreach my $key (sort keys %IRSSI) {
		print("\cC4$key: \cC0".$IRSSI{$key}) unless $key =~ /name/i;
	}
	return 1;
}

Irssi::command_bind bgversion => \&cmd_bgversion;

# /bghelp command
$FEATURES{'help'} = "/bghelp \c0 List the BgTA Script FEATURES";

sub cmd_bghelp {
	my ($data, $server, $witem) = @_;

	print("\cC4BgTA Script v. ".$VERSION);
	foreach my $key (sort keys %FEATURES) {
		print("\cC4$key: \cC0".$FEATURES{$key}) unless $key =~ /name/i;
	}
	return 1;
}

Irssi::command_bind bghelp => \&cmd_bghelp;
# GOOGLE
$FEATURES{'google'} = "/bggoogle \cC7search_string \t \cC5Search one result in Google.com";

sub cmd_bggoogle {
	my ($data, $server, $witem) = @_;

	return unless $witem;


	use Net::Google;
	
	# Put here the Google Key. See Google->Tools & Services
	use constant LOCAL_GOOGLE_KEY => "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";

	$witem->command("me Google Searching [$data]...");
	my $google = Net::Google->new(key=>LOCAL_GOOGLE_KEY);

	my $search = $google->search(max_results => 100);

	 $search->query($data);

	 my @tresults = @{$search->results()};

	if(!defined($tresults[0])) {
		$witem->command("me NO RESULTS");
		return;
	}
	my $title = $tresults[0]->title();
	$title =~ s/<[^<]*>//ig;
	$witem->command("me ".$title."\cC2: ".$tresults[0]->URL());
	return;
}

Irssi::command_bind bggoogle => \&cmd_bggoogle;

# PHP Documentation
$FEATURES{'php'} = "/bgphp \cC7function_name \t \cC5Search a PHP Function URL and Definition";
$FEATURES{'phpwb'} = "/bgphpwb \cC7function_name \t \cC5Search a PHP Function URL and Definition AND Kick BAN With the URL";
sub cmd_bgphp {

	my ($data, $server, $witem) = @_;

	return unless $witem;


	use LWP;

	my $Navigator = new LWP::UserAgent({
        "agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
        "timeout" => "180", 
        });

	$data =~ s/\_/\-/ig;

	my $Page = $Navigator->get('http://www.php.net/manual/es/function.'.$data.'.php');
	
	my $content = $Page->content if $Page->is_success;
	if($Page->is_success && $content =~ /([^<]*)<B\nCLASS=\"methodname\"\n>([^<]*)<\/B\n> ([^<]*)/i) {
		$witem->command("me PHP Function $data:");
		$witem->command("me Location: \cC5 http://www.php.net/manual/es/function.".$data.'.php');
		if($content =~ /<td><a href=\"ref.([^\.]*).php\">/i) {
			$witem->command("me Reference: \cC6 http://www.php.net/manual/es/ref.$1.php");
		}
		if($content =~ />([^<]*)<B\nCLASS=\"methodname\"\n>([^<]*)<\/B\n> ([^<]*)/i) {
			$witem->command("me $1\cC0$2\cC $3");
		}
		if($content =~ /--\&nbsp;([A-Za-z0-9\ αινσϊ\n]+)/i) {
			my $sal = $1;
			$sal =~ s/\ \ /\ /gi;
			$sal =~ s/\n/\ /gi;
			chomp($sal);
			$witem->command("me Description: $sal");
		}
	} else {
		$witem->command("me \cC5PHP Function $data: No Results.");
	}

	return;

}

sub cmd_bgphpwb {

	my ($data, $server, $witem) = @_;

	return unless $witem;


	use LWP;

	my $Navigator = new LWP::UserAgent({
        "agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
        "timeout" => "180", 
        });
	
	$data =~ /^([^\ ]*) (.*)$/i;
	my $nick = $1;
	$data = $2;
	$data =~ s/\_/\-/ig;

	my $Page = $Navigator->get('http://www.php.net/manual/es/function.'.$data.'.php');
	
	my $content = $Page->content if $Page->is_success;
	if($Page->is_success && $content =~ /([^<]*)<B\nCLASS=\"methodname\"\n>([^<]*)<\/B\n> ([^<]*)/i) {
		$witem->command("kickban $nick Mira el Jodido Manual: \cC5 http://www.php.net/manual/es/function.".$data.'.php');
	} 

	return;

}
sub bgphpevent {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $text) = $data =~ /^(\S*)\s:(.*)/;

	#if($text =~ /bgphp:(.*)$/) {
	#}	

}
Irssi::signal_add("event notice", "bgphpevent");
Irssi::command_bind bgphp => \&cmd_bgphp;
Irssi::command_bind bgphpwb => \&cmd_bgphpwb;


#  WEB SEARCH TITLE
$FEATURES{'wwwd'} = "/bgwwwd \cC7http://some.web.com/ \t \cC5Look for title and Description of Web";
sub cmd_bgwwwd {

	my ($data, $server, $witem) = @_;

	return unless $witem;


	use LWP;

	my $Navigator = new LWP::UserAgent({
        "agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
        "timeout" => "180", 
        });

	my $Page = $Navigator->get($data);

	if($Page->is_success) {
		my $content = $Page->content;
		my $title = "No Title";
		my $description = "No Description Page";

		if($content =~ /TITLE>([^<]*)<\/TITLE>/i) {
			$title = $1;
		}

		if($content =~ /META NAME=\"DESCRIPTION\" CONTENT=\"([^\"]*)\"/i) {
			$description = $1;
		}
		$witem->command("me [ $data ]: ".$title);
		$witem->command("me \cC5 $description");
	} else {
		$witem->command("me [ $data ] Page Not Found");
	}
}

Irssi::command_bind bgwwwd => \&cmd_bgwwwd;


# Perl Documentation
$FEATURES{'perl'} = "/bgperl \cC7function_name \t \cC5Search a Perl Function URL and Definition";
sub cmd_bgperl {

	my ($data, $server, $witem) = @_;

	return unless $witem;


	use LWP;

	my $Navigator = new LWP::UserAgent({
        "agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
        "timeout" => "180", 
        });

	my $Page = $Navigator->get('http://www.perldoc.com/perl5.8.0/pod/func/'.$data.'.html');
	
	my $content = $Page->content if $Page->is_success;
	if($Page->is_success && $content =~ /<span class=\"docTitle\">([^<]*)<\/span>/i) {
		$witem->command("me Perl Function $data:");
		$witem->command("me Location: \cC5 http://www.perldoc.com/perl5.8.0/pod/func/".$data.'.html');
		if($content =~ /<DL><DT><A NAME=\"[^\"]*\">(.*)\n/i) {
			$witem->command("me \cC0$1");
		}
		if($content =~ /<DT><A NAME=\"$data\">$data\n\n<\/A><\/DT>\n<DD>\n([^\n]*)/i) {
			$witem->command("me $1");
		}
	} else {
		$witem->command("me \cC5Perl Function $data: No Results.");
	}

	return;

}
Irssi::command_bind bgperl => \&cmd_bgperl;

# Debian Search Packages
$FEATURES{'debian'} = "/bgdebian \cC7package name | \cC5Search a package in a Debian stable distribution";
sub cmd_bgdebian {

	my ($data, $server, $witem) = @_;

	return unless $witem;


	use LWP;

	my $Navigator = new LWP::UserAgent({
        "agent" => "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
        "timeout" => "180", 
        });

	$data =~ s/\ /\+/;
	my $Page = $Navigator->get('http://packages.debian.org/cgi-bin/search_packages.pl?keywords='.$data.'&searchon=names&subword=1&version=stable&release=all');
	
	my $content = $Page->content if $Page->is_success;
	if($Page->is_success && $content =~ /<TD><B><A HREF=\"http:\/\/packages\.debian\.org\/stable\/misc\/([^\.]*).html\"> $data/i) {
		$witem->command("me Debian \cC2$data\cC package:");
		$witem->command("me Location: \cC5 http://packages.debian.org/stable/misc/$1.html");
		if($content =~ /<TD COLSPAN=2>([^<]*)</i) {
			$witem->command("me Description: $1");
		}
	} else {
		$witem->command("me \cC5Debian $data package: No Results.");
	}

	return;

}
Irssi::command_bind bgdebian => \&cmd_bgdebian;
1;


