#!/usr/bin/perl -T -w

# Harjoitustyˆn‰ tehty skripta.

# K‰yttˆ:
# 1) kopioi .irssi/scripts hakemistoon
# 2) /run ircgmessagenotify.pl
# 3) /set ircgusername yournick
# 4) /set ircgpassword yourpassword
# 5) Voit myˆs optionaalisesti s‰‰t‰‰ ircgcheck_interval arvoa joka sekunneissa m‰‰‰r‰‰ kyselyjen v‰lisen ajan sekunteina
# 6) ircgdo_polling asetus voi olla joko 1 tai 0 ja se m‰‰r‰‰ pollataanko serveri‰ ylip‰‰ns‰
# 7) /statusbar window add ircgcomments         komento lis‰‰ statusbariin kohdan IRCG: n jossa n kuvaa uusien viestien lukum‰‰r‰‰. =)
# 8) /ircgcomments komento kyselee k‰sin pakotettuna tilanteen

# jos polling on asetettu 0 ei edes k‰sipelin kysely toimi.

# Kiitokset statusbar ideasta Whiz:ille.. kiitos p‰llist‰ ideasta p‰lliin skriptaan jne.
# Kiitoksia ei heru Whizille kyll‰k‰‰n toimimattomista regexpeist‰... joutu ihan itse opetteleen keletanatu.

use strict;
use LWP::UserAgent;
use HTTP::Cookies;
use Irssi;
use Irssi::TextUI;

# ------------------------------------
# Ircgalleria skriptin poikanen
#

use vars qw($VERSION %IRSSI);
$VERSION = "0.1b";
%IRSSI = (
 authors => "BCOW",
 contact => "bcow\@iki.fi",
 name => "ircgmessagenotify",
 description => "Tarkistelee irc-galleria.net:i‰ ja sanoo kun sinulle on uusia viestej‰.",
 license => "GPLv2",
 url => "http://www.verkonpaino.net/",
 changed => "21.01.2004 23:55:00 EET"
);

# alustetaan asetukset
Irssi::settings_add_str('ircgmessagenotify', 'ircgusername', '');
Irssi::settings_add_str('ircgmessagenotify', 'ircgpassword', '');
Irssi::settings_add_int('ircgmessagenotify', 'ircgcheck_interval', '120');
Irssi::settings_add_int('ircgmessagenotify', 'ircgdo_polling', '1');

# alustetaan keksis‰ilˆ :P
my $cookie_jar = HTTP::Cookies->new(file => $ENV{'HOME'}. "/.irssi/ircgmessagenotify_cookie_jar.dat", autosave => 1,);
# alustetaan viestilaskuri
my $lastcount = 0;
# alustetaan timeria
my $timeout;
my $timeouttag;

# -- aseta timeri
sub setup_timer
{
	# aseta uusi timeri
	$timeout = Irssi::settings_get_int("ircgcheck_interval");
	if ($timeout < 60)
	{
		$timeout == 60;
		Irssi::print("ircgcheck_interval ei voi olla pienempi kuin 60. Asetin sen 60:een.");
	}
	$timeouttag = Irssi::timeout_add($timeout * 1000, 'check_for_new_messages', '');
}

# -- varmistetaan ett‰ timeri muuttuu ja sen mukaan myˆs skriptan ajo.
sub setup_changed
{
	# m‰‰ritykset muuttui. aseta timeri uudestan =)
	Irssi::timeout_remove($timeouttag);
	&setup_timer;
	# jokatapauksessa piirr‰ statusbar uudestaan
	Irssi::statusbar_items_redraw("ircgcomments");
}

# -- varsinainen funktio jolla tsekataan viestit
sub check_messages
{
	my $forced = $_[0];

	my $ua = LWP::UserAgent->new;
	$ua->agent("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)");
	$ua->timeout(10);
	$ua->cookie_jar($cookie_jar);

	my $irclogin = Irssi::settings_get_str('ircgusername');
	my $passwd = Irssi::settings_get_str('ircgpassword');

	my $req = HTTP::Request->new(POST => "http://irc-galleria.net/login.php");
	$req->content_type("application/x-www-form-urlencoded");
	$req->content("login=$irclogin&passwd=$passwd");

	my $res = $ua->request($req);

	# Oliko palautus ok vai virhe
	if ($res->is_success) {
		#print $res->content;
		# okei saatiin tehty‰ kirjautuminen.. ˆˆm ja saatiin se mit‰ pit‰isikin. t‰m‰ ei ole kuitenkaan se mit‰ halutaan ;)
		Irssi::print("ircgmessagenotify.pl sanoo: ˆˆˆmm.. t‰t‰ ei pit‰nyt tapahtua: ". $res->as_string);
	} elsif ($res->is_redirect) {
		# okei uudelleenohjaus niinkuin pit‰isikin(?) olla¥
		if ($res->header("Location") =~ /error/)
		{
			# gallerian virhe
			Irssi::print("ircgmessagenotify.pl sanoo VIRHE kirjauduttaessa: gallerian virhekoodi!");
		} else {
			# homma ok. Haetaanpas sitten uudella requestilla viestit
			my $req2 = HTTP::Request->new(GET => "http://irc-galleria.net/". $res->header("Location"));

			# useragent toivottavasti muistaa keksit
			my $res2 = $ua->request($req2);

			if ($res2->is_success)
			{
				# ookii ;) saatiin content!
				if ($res2->content =~ /Sinulle on uusia kommentteja/)
				{
					#Irssi::print("Sinulle on uusia kommentteja irc-galleriassa!!!");
					my $newcount = $res2->content;
					#$newcount =~ s/.*commentcount\"\>\(//i;
					#$newcount =~ s/\)\<.*//i;

					# irroita arvo :)
					$newcount =~ /.*commentcount\"\>\((\d)\)\<.*/;
					$newcount = $1;

					my $uusia = $newcount - $lastcount;

					#Irssi::print("Uusia: $uusia, newcount: $newcount, lastcount: $lastcount");

					# sitten viimeinen tarkistus ;)
					if ($lastcount < $newcount)
					{
						# uusia viestej‰! jeee!
						Irssi::print("Sinulle on irc-galleriassa $uusia kpl uusia kommentteja. Yhteens‰ $newcount kpl.");
					} elsif ($lastcount > $newcount) {
						# viestej‰ on luettu sitten viimekerran tai jotain muuta hassua, mutta niit‰ on kuitenkin
						Irssi::print("Sinulle on irc-galleriassa $newcount kpl viestej‰ odottamassa lukemista.");
					} # nolla tekee jotakin omituista :)

					# aseta arvo
					$lastcount = $newcount;
				} else {
					# aseta arvo nollille koska ei ole uusia viestej‰
					$lastcount = 0;
					if ($forced == 1)
					{
						# hassuja ep‰loogisuuksia tuossa ylemp‰n‰ ja siin‰ mit‰ t‰ss‰ tapahtuu ;)
						Irssi::print("Sinulle ei ole uusia kommentteja irc-galleriassa.");
					}
				}
			} else {
				# virhe :(((
				Irssi::print("ircgmessagenotify.pl sanoo VIRHE viestien lukum‰‰r‰‰ selvitett‰ess‰: ". $res2->status_line);
			}
		}
	} else {
		#print $res->status_line, "\n";
		# virhe :(((
		Irssi::print("ircgmessagenotify.pl sanoo VIRHE kirjauduttaessa: ". $res->status_line);
	}
}

# -- tarkista pakotetusti
sub check_messages_forced
{
	&check_messages(1);
	# jokatapauksessa piirr‰ statusbar uudestaan
	Irssi::statusbar_items_redraw("ircgcomments");
}

# -- tarkista onko uusia viestej‰ eli yhdy palvelimeen ja tsekkaa lukema
sub check_for_new_messages
{
	# tarkista tarvitseeko tehd‰ mit‰‰n?
	if (Irssi::settings_get_int("ircgdo_polling") > 0)
	{
		#Irssi::print("Tick");
		&check_messages(0);
	} # do_polling
	# jokatapauksessa piirr‰ statusbar uudestaan
	Irssi::statusbar_items_redraw("ircgcomments");
}

# -- n‰yt‰ tieto t‰n hetkisest‰ laskurista statusbarissa -)
sub statusbar
{
	my ($item, $get_size_only) = @_;

	my $state;

	if (Irssi::settings_get_int("ircgdo_polling") > 0)
	{
		# jos pollataan n‰yt‰kkin jotain
		$state = $lastcount;
	} else {
		# ei pollata joten n‰yt‰ -
		$state = "-";
	}

	$item->default_handler($get_size_only, undef, "IRCG: $state", 1);
}

# Kiinnitet‰‰n timeri
&setup_timer;

# sitten signaali liitoksia
Irssi::signal_add("setup changed", "setup_changed");

# ja komento liitoksia
Irssi::command_bind('ircgcomments', 'check_messages_forced');

# viimeiseksi j‰‰ statusbar liitos
Irssi::statusbar_item_register('ircgcomments','{sb $0-}', 'statusbar');