use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
$VERSION = '0.3';
%IRSSI = (
	authors     => 'Mankeli',
	contact     => 'mankeli@einari.org',
	name        => '#pelix Helpers',
	description => 'This script allows you flood shit.',
	license     => 'GNU/GPL',
);

# INSTRUCTIONS:
# /pelix [cmd] [length]
#
# cmds are: wtf, biy0, sepi, jupe and veez
# (sepi cmd is experimental and should be handled with extreme care)

# VERSION HISTORY:
# 0.1 		wtf
# 0.1.5		biy0
# 0.1.6		sepi
# 0.2		jupe
# 0.3		veez

# biy0 script ripped from palomies mirc-script copyright(c) 2003 veezay/palomies.com(r) all rights reserved, used with permission.

sub pelix_biyo
{
	my ($pituus) = @_;
	my $temppi;
	my $koht;
	my $tod;
	my $eka;
	my $wanha;

	$tod = int(rand(2));
	if ($tod eq 0)
	{
		$koht = int(rand(6));
		if ($koht eq 0) { $temppi = ":"; }
		if ($koht eq 1) { $temppi = "."; }
		if ($koht eq 2) { $temppi = "D"; }
		if ($koht eq 3) { $temppi = "d"; }
		if ($koht eq 4) { $temppi = ";"; }
		if ($koht eq 5) { $temppi = ","; }
	}
	else
	{
		$temppi = ":";
	}
	$wanha = -1;
	for ($koht=0; $koht<$pituus; $koht++)
	{
		$eka = int(rand(10));
		if (($eka == 0) && ($wanha != 0)) { $temppi.=":"; }
		if (($eka == 1) && ($wanha != 1)) { $temppi.="."; }
		if (($eka == 2) && ($wanha != 2)) { $temppi.="d"; }
		if (($eka == 3) && ($wanha != 3)) { $temppi.=";"; }
		if (($eka == 4) && ($wanha != 4)) { $temppi.=","; }
		if (($eka == 5) && ($wanha != 5)) { $temppi.=":"; }
		if (($eka > 5) && ($eka <= 7) && ($wanha != $eka)) { $temppi.="D"; }
		if (($eka == 9) && ($eka != $wanha)) { $temppi.="_"; }
	}
	return ($temppi);
}

sub pelix_wtf
{
	my ($pituus) = @_;
	my $temppi;
	my $koht;
	$temppi = "";
#	srand();
	for ($koht=0; $koht<$pituus; $koht++)
	{
		if (int(rand(2)) eq 0)
		{
			$temppi.=";D ";
		}
		else
		{
			$temppi.="? ";
		}
	}
	return($temppi);
}

sub pelix_jupe
{ 
        my ($pituus) = @_;
        my $temppi;
        my $koht;
	my $luku;
        $temppi = "";
#       srand();
        for ($koht=0; $koht<$pituus; $koht++)
        {
		$luku = int(rand(7));
                if ($luku < 3)
                {
                        $temppi.=":P";
                }
		elsif($luku == 3)
		{
			$temppi.=";PP;"
		}
                else
                {
                        $temppi.="?";
                }

		if (int(rand(4)) < 3)
		{
			$temppi.=" ";
		}
        }
        return($temppi);
}

sub pelix_veez
{
	my ($pituus) = @_;
	my $temppi;
	my $koht;
	$temppi = "";
	for ($koht=0; $koht<$pituus; $koht++)
	{
		if (int(rand(2)) eq 0)
		{
			$temppi.=";";
		}
		else
		{
			$temppi.=")";
		}
	}
	return($temppi);
	
}


sub sepinsqd_smile
{
	my ($pituus) = @_;
	my $temppi;
	my $koht;
	my $arvo;

	$temppi = "";
	for ($koht=0; $koht<$pituus; $koht++)
	{
		$arvo = int(rand(4));
		if($arvo eq 0)
		{
			$temppi.="A";
		}
		elsif($arvo eq 1)
		{
			$temppi.="Å";
		}
		else
		{
			$temppi.=";";
		}
	}
	return($temppi);
}

sub pelix
{
	my @teksti;
#     @version = $finger =~ /:\s*(\S+)\s*$/gm;
	my ($data, $server, $witem) = @_;
	my @arg = split(/ +/, $data);
	my $tpit;
	
	$tpit = @arg[1];
	

	if (@arg[0] eq "biy0")
	{
		@teksti = pelix_biyo($tpit);
	}
	elsif (@arg[0] eq "wtf")
	{
		@teksti = pelix_wtf($tpit);
	}
	elsif (@arg[0] eq "jupe")
	{
		@teksti = pelix_jupe($tpit);
	}
	elsif (@arg[0] eq "veez")
	{
		@teksti = pelix_veez($tpit);
	}
	elsif (@arg[0] eq "sepi")
	{
		@teksti = sepinsqd_smile($tpit);
	}
	elsif (@arg[0] eq "")
	{
		Irssi::print("no ÄgZön specified.");
		return;
	}
	else
	{
		Irssi::print("No such ÄgZön as @arg[0].");
		return;
	}
      
	if (!$server || !$server->{connected})
	{
		Irssi::print("Not connected to server");
		return;	
	}
	
	if ($witem && ($witem->{type} eq "CHANNEL" || $witem->{type} eq "QUERY"))
	{
		$witem->command("MSG ".$witem->{name}." @teksti");
	}
		else
	{
		Irssi::print("No active channel/query in window");
	}
}

sub pelix_help
{
	Irssi::print("Usage: runQ");
}

Irssi::command_bind('pelix', 'pelix');
Irssi::command_bind('help pelix','pelix_help');
