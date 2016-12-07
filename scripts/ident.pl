#!/usr/bin/perl -w

use strict;
use Irssi;
use POSIX;

use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
    authors     => 'Isaac Good',
    contact     => "irssi\@isaacgood.com; irc.freenode.net/yitz",
    name        => 'ident',
    description => 'Ident to NickServs',
    name        => "ident",
    description => "Automatically IDENTIFY when prompted",
    license     => 'MIT',
);


my %pw;


sub LoadPasswords {
    # Load the passwords from file.
    delete @pw{keys %pw};
    my $filename = Irssi::get_irssi_dir() . '/passwords';
    my $FH;
    unless(open $FH, "<", $filename)
    {
        print "Can not open $filename";
        return 0;
    }
    while (my $line = <$FH>)
    {
        chomp $line;
        next unless ($line);
        my ($tag, $password) = split(/  */, $line, 2);
        next unless ($tag and $password);
        $pw{$tag} = $password;
    }
    return 1;
}


sub notice {
    my ($server, $data, $nick, $host) = @_;
    my ($channel, $msg) = split(/ :/, $data, 2);
    my $l = 0;

    # Test the notice. Must be from nickserv and be asking you to identify.
    return undef unless (lc($nick) eq 'nickserv');
    return undef unless (lc($msg) =~ /msg nickserv identify/);
    # Check it's a direct message and we have a password for this network.
    return undef unless (lc($channel) eq lc($server->{'nick'}));
    return undef unless ($pw{$server->{'chatnet'}});

    my $pw = $pw{$server->{'chatnet'}};
    # Use the /quote nickserv approach to reduce chance of leaking the password to a bad actor, ie someone pretending to be nickserv.
    $server->command("^quote nickserv identify $pw");

    return undef;
}


if (LoadPasswords()) {
    Irssi::signal_add('event notice', \&notice);
}
