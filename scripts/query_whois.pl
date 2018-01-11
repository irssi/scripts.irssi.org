use strict;
use Irssi;

{
  our $VERSION = "0.02";
  our %IRSSI = (
    name        => "query_whois",
    description => "whois on every query open (and only then)",
    url         => "http://explodingferret.com/linux/irssi/query_whois.pl",
    authors     => "ferret",
    contact     => "ferret(tA)explodingferret(moCtoD), ferret on irc.freenode.net",
    licence     => "Public Domain",
    changed     => "2008-09-22",
    changes     => "idle time added",
    modules     => "",
    commands    => "",
    settings    => "",
  );
}

Irssi::signal_add_first 'query created' => sub {
  my ( $witem ) = @_;

  $witem->{server}->command("whois $witem->{name} $witem->{name}");
};
