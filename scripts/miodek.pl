# Miodek 1.0.2
#
# Lam 10-11.9.2001 + pó¼niejsze zmiany s³ownika (g³ównie YagoDa)
#
# Pewnie ten skrypt jest napisany ¼le, co prawdopodobnie wynika z faktu, ¿e
# to w ogóle mój pierwszy skrypt w perlu, ale có¿, na pewno ludzie, których
# ten skrypt kopie s± g³upsi od niego :)
#
# S³ownik jest wynikiem nocnego przegl±dania logów z irca (g³ównie
# grepowania po "sh" oraz "kunia") i powiêksza siê podczas ka¿dej rozmowy :)
#
# 10:32 <aska|off> hm... to u was za kopiom???????
# 10:32 <aska|off> ehhee za kcenie??????
#
# Miodek 2.0 z obs³ug± regexów i s³owników w plikach by³ w
# przygotowaniu, ale po padzie dysku straci³em ochotê odzyskiwania go.
# Na jaki¶ czas.

use Irssi;
use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0.2";
%IRSSI = (
	authors => "Leszek Matok, Andrzej Jagodziñski",
	contact => "lam\@lac.pl",
	name => "miodek",
	description => "Simple wordkick system, with extended polish dictionary for channels enforcing correct polish.",
	license => "GPLv2",
	changed => "10.3.2002 20:10"
);


my $miodek = '
# moje w³asne dopiski :> (by yagus)

szypko          szybko
wogule          w ogole
qrva            panna lekkich obyczajow
drobiask        drobiazg
ogladash        ogl±dasz
przeciesh       przecie¿
zeszycikof      zeszytów
widzish         widzisz
JESOOO          Jezu
jesooooooo      Jezu
jesoooooooo     Jezu
jesooooooooo    Jezu
jesoooooooooo   Jezu
jesooooooooooo  Jezu
jesoooooooooooo Jezu
zgadzash        zgadzasz
jesooo          Jezu
jesoooo         Jezu
jesooooo        Jezu
jesoooooo       Jezu
zobaczysh       zobaczysz
pokonash        pokonasz
nawidzish       nawidzisz
myslish         myœlisz
komplexof       kompleksów
chujq           cz³onku
moofi           mówi
umiesh          umiesz
lubish          lubisz
tilaf           T.Love
wjesz           wiesz
priff           priv
prif            priv
lukof           £uków
lukoof          £uków
kad             sk±d
k¹d             sk±d
wlosoof         w³osów
wlosof          w³osów
dobzie          dobrze
fogóle          w ogóle 
fogole          w ogóle
wogóle          w ogóle
wogole          w ogóle
pishesz         piszesz
pishesh         piszesz
mooofish        mówisz
uwazash         uwa¿asz
slyshysh        s³yszysz
zaparofaly      zaparowa³y
wyprafiash      wyprawiasz
wyprafiasz      wyprawiasz
znof            znów
idziesh         idziesz
grash           grasz
moofi³          mówi³
moofil          mówi³
qlfa            kurwa
dopsie          dobrze
schodof         schodów
pierdolic       kochaæ
pierdoliæ       kochaæ
jebaæ           uprawiaæ mi³o¶æ
jebac           uprawiaæ mi³o¶æ
pierdolec       kochanek
psyjechac       przyjechaæ
kces            chcesz
przyjebal       pokocha³
przyjeba³       pokocha³
ujebal          pokocha³ 
zajebal         zakocha³
ujeba³          pokocha³
zajeba³         zakocha³
chuja           cz³onka
huja            cz³onka
pierdoli        kocha
odwiezesh       odwieziesz
bedziesh        bêdziesz
mooofiles       mówi³e¶
moofiles        mówi³e¶
mofi            mówi
dogryzash       dogryzasz
terash          teraz
tfooj           twój
dorosniesh      doro¶niesz
pofiem          powiem
poffiem         powiem
dopla           dobra
doblam          dobra
# typowe kretynizmy (90% by Lam)
tesh            te¿
tesz            te¿
tysh            te¿
tysz            te¿
jush            ju¿
jusz            ju¿
ush             ju¿
mash            masz
cush            có¿
coosh           có¿
cosh            có¿
robish          robisz
jesh            jesz
# qrwa          kurwa
kurfa           kurwa
qrfa            kurwa
kofam           kocham
koffam          kocham
kofany          kochany
koffany         kochany
kofana          kochana
koffana         kochana
moofie          mówiê
moof            mów
moofisz         mówisz
moofish         mówisz
mofie           mówiê
mof             mów
mofisz          mówisz
mofish          mówisz
pofiem          powiem
gadash          gadash
wiesh           wiesz
fiesh           wiesz
fiem            wiem
# tego wprost nienawidzê!
KCE             chcê
kce             chcê
kcem            chcê
kcesz           chcesz
kcesh           chcesz
moshe           mo¿e
mosze           mo¿e
moshna          mo¿na
# widzia³em jak jaki¶ czik o inteligencji ameby pisa³ "moszna", ale smaczek ;)
bosh            bo¿e
boshe           bo¿e
boshesh         bo¿e
jesu            Jezu
joosh           ju¿
# no tego to ja bym nie wymy¶li³ :)
fokle           w ogóle
psheprasham     przepraszam
# a to s³owo ma tyle wersji.. ci ludzie naprawdê siê nudz±.
dobshe          dobrze
dopshe          dobrze
dopsze          dobrze
dopsz           dobrze
topshe          dobrze
topsze          dobrze
topsz           dobrze
topla           dobra
toplanoc        dobranoc
dopry           dobry
dopra           dobra
# od tego momentu wy³±cznie wy³apane na ircu
napish          napisz
palish          palisz
trafke          trawkê
trafka          trawka
slofa           s³owa
pishe           pisze
piszem          piszê
moozg           mózg
kref            krew
krfi            krwi
naprafde        naprawdê
zafsze          zawsze
dziendopry      dzieñdobry
snoof           snów
kopiom          kopi±
kcenie          chcenie
kcê             chcê
kórfa           kurwa
kórwa           kurwa
mooj            mój
jesoo           Jezu
loodzie         ludzie
loodzi          ludzi
ktoora          która
ktoory          który
ktoore          które
gloopi          g³upi
gloopia         g³upia
goopi           g³upi
goopia          g³upia
gupi            g³upi
gupia           g³upia
siem            siê
pshesada        przesada
booziak         buziak
booziaki        buziaki
mogem           mogê
bes             bez
spowrotem       z powrotem
poczeba         potrzeba
niepoczeba      nie potrzeba
czeba           trzeba
glofa           g³owa
glofe           g³owê
suonce          s³oñce
fitam           witam
fitaj           witaj
fitajcie        witajcie
slofnik         s³ownik
# usuniête w wyniku batalii o Jerzego Owsiaka. Prawdopodobnie nied³ugo
# zobaczymy to s³owo w s³owniku. Ciekawe co napisz± pod has³em "siemanie"?
# siema         siê ma
# siemasz       siê masz
cieshysh        cieszysz
tfierdzish      twierdzisz
jezd            jest
brzytkie        brzydkie
brzytki         brzydki
brzytka         brzydka
otfarty         otwarty
otfarte         otwarte
otfarta         otwarta
leprzy          lepszy
leprze          lepsze
leprza          lepsza
lepshy          lepszy
lepshe          lepsze
lepsha          lepsza
zief            ziew
kfila           chwila
kfile           chwilê
kfilka          chwilka
kfilke          chwilkê
bendem          bêdê
lecem           lecê
pifo            piwo
pifko           piwko
pifkiem         piwkiem
bszytkie        brzydkie
bszytki         brzydki
bszytka         brzydka
goofny          g³ówny
goofno          gówno
muoda           m³oda
miaua           mia³a
miauam          mia³am
tszeba          trzeba
wporzo          w porzo
# na pro¶bê Upiora trochê bluzgów + nowe by yagoda
kurwa           dziewica orleañska
kurwy           panny
kurwie          pannie
kurewka         panienka
kurwo           panno
qrwa            prostytutka
# eksperymentalne wielkie litery :-)
CHUJ            cz³oneczek
HUJ             cz³oneczek
KURWA           panienka
KURWY           panny
CIPA            pochwa
PIZDA           pochwa
SKURWYSYN       Protas
chuj            cz³onek
chuje           cz³onki
chujowo         cz³onkowsko
chujowy         cz³onkowski
chujowa         cz³onkowska
chujowe         cz³onkowskie
huj             cz³onek
huje            cz³onki
hujowo          cz³onkowsko
hujowy          cz³onkowski
hujowa          cz³onkowska
hujowe          cz³onkowskie
cipa            pochwa
pizda           pochwa
pierdolony      kochany
pierdolona      kochana
pierdolone      kochane
jebany          kochany
jebana          kochana
jebane          kochane
skurwysyn       Protas
skurwysynu      synu prostytutki
skurwiel        Lam
skurwielu       z kur wielu
pierdole        kocham
jebie           kocham
pierdol         kochaj
kutas           penis
cipka           pochewka
';

my %slowa;
my $ilosc_slow = 0;

foreach my $linia (split(/\n/, $miodek)) {
	chomp $linia;
	next if ($linia =~ /^#/ || $linia eq "");

	my ($org, $popraw) = split(/\s+/, $linia, 2);
	$slowa{$org} = $popraw;
	$ilosc_slow++
}

sub server_event {
	my ($server, $data, $nick, $address) = @_;
	my ($type, $data) = split(/ /, $data, 2);
	return unless ($type =~ /privmsg/i);
	my ($target, $tekst) = split(/ :/, $data, 2);
	my $powod;

	# pozbywam siê syfów kontrolnych, oraz ^A z CTCP
	# mo¿e jest jaka¶ funkcja w irssi do wycinania kolorów mircowych?
	$tekst =~ s/[]//g;

	foreach my $wyraz (split(/[\s,.;!?\/"`':()_-]/,$tekst)) {
		my $popraw = $slowa{$wyraz};
		if ($popraw) {
			if ($powod) {
				$powod = $powod . ", ";
			}
			$powod = $powod . $popraw;
		}
	}

	if ($powod && $target =~ /^[#!+&]/ ) {
		$server->command("/kick $target $nick $powod");
		Irssi::print "%Rkop%n ($target): %c$nick%n, powod: $powod";
	}
}

# Musia³em siê podczepiæ pod server event zamiast event privmsg, bo irssi
# wycina CTCP z PRIVMSG (co jest dla mnie zachowaniem dziwnym).
Irssi::signal_add_last("server event", "server_event");
Irssi::print "%GMiodek%c:%n ilo¶æ s³ów w s³owniku: $ilosc_slow";
