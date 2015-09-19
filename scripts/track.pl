use Irssi qw(servers);
use warnings; use strict;
use vars qw($VERSION %IRSSI);

my $quiet     = 0;
my $dupcount  = 0;
$VERSION      = "2.1";

%IRSSI = (
      authors => "Ziddy",
      contact => "DALnet",
      name => "track.pl",
      description => "Keeps track of users by building a database" .
                     "of online, joining and nickchanges. Regex-cabable" .
                     "for the most part, AKA import available. Search by" .
                     "ident, nick or host",
      license => "Public Domain",
      url => "none"
);

sub whois_signal {
    my ($server, $data, $txtserver) = @_;
    my ($me, $nick, $ident, $host) = split(" ", $data);
    open(my $fh, '>>', Irssi::get_irssi_dir() . "/scripts/track.lst");
    open(my $fh2, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
    my @list = <$fh2>;
    close($fh2);
    $nick    = conv($nick);
    ($ident  = $ident) =~ s/^~//;
    $ident   = conv($ident);

    if(!grep(/$nick;$ident;$host/, @list)) {
        print $fh "$nick;$ident;$host\n";
        if (!$quiet) { Irssi::print("%G$nick has been added to the database"); }
    } else {
        if (!$quiet) { Irssi::print("%R$nick exists in the database"); }
    }

    close($fh);
}

sub joining {
    my ($server, $channame, $nick, $host) = @_;
    open(my $fh, '>>', Irssi::get_irssi_dir() . "/scripts/track.lst");
    open(my $fh2, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
    $nick     = conv($nick);
    my @list  = <$fh2>;
    close($fh2);
    my @spl   = split(/@/, $host);
    my $ident = $spl[0];
    my $mask  = $spl[1];
    ($ident   = $ident) =~ s/^~//;
    $ident    = conv($ident);
    $dupcount++;

    if(!grep(/$nick;$ident;$mask/, @list)) {
        print $fh "$nick;$ident;$mask\n";
        if (!$quiet) { Irssi::print("%GADDED $nick;$ident;$mask"); }
    } else {
        if (!$quiet) { Irssi::print("%REXIST $nick;$ident;$mask"); }
    }

    close($fh);

    if ($dupcount >= 100) {
        open(my $fhr, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
        my @list   = <$fhr>;
        close($fhr);
        my @duprem = uniq(@list);
        open(my $fhw, '>', Irssi::get_irssi_dir() . "/scripts/track.lst");
        print $fhw @duprem;
        close($fhw);
        $dupcount = 0;
    }


}

sub nchange {
    my ($server, $newnick, $oldnick, $host) = @_;
    open(my $fh, '>>', Irssi::get_irssi_dir() . "/scripts/track.lst");
    open(my $fh2, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
    $newnick  = conv($newnick);
    my @list  = <$fh2>;
    close($fh2);
    my @spl   = split(/@/, $host);
    my $ident = $spl[0];
    my $mask  = $spl[1];
    ($ident   = $ident) =~ s/^~//;
    $ident    = conv($ident);

    if(!grep(/$newnick;$ident;$mask/, @list)){
        print $fh "$newnick;$ident;$mask\n";
        if (!$quiet) { Irssi::print("%GADDED $newnick;$ident;$mask)"); }
    } else {
        if (!$quiet) { Irssi::print("%REXIST $newnick;$ident;$mask"); }
    }

    close($fh);
}

sub track {
    my $input  = $_[0];
    chomp($input);
    my @spl    = split(/\s/, $input);
    my $type   = $spl[0];
    my $data   = $spl[1];
    $data      = conv($data);
    my $match  = 0;
    open(my $fh, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
    my @list = <$fh>;
    close($fh);

    if ($type eq "count") {
        Irssi::print("%GDatabase entries%n: " . scalar(@list));
        return;
    }

    if ($type eq "quiet") {
        if ($quiet) { $quiet = 0; } else { $quiet = 1; }
        Irssi::print("%GQuiet mode set to $quiet");
        return;
    }

    if ($type eq "help") {
        Irssi::print("\n%GHelp%n\n" .
                     "      /gather  -  Join your channels then run this\n" .
                     "                  to gather nicks already online\n" .
                     "                  This may take a while on first run\n" .
                     " /track quiet  -  Toggle quiet. If this is on, it wont\n" .
                     "                  show when a person is added or already\n" .
                     "                  exists in the database\n" .
                     "/track count   -  Print amount of database entries\n" .
                     "/import [file] -  This allows you to import AKA data-\n" .
                     "                  bases. AKA is a popular mIRC script\n" .
                     "                  which allows you to keep track of people\n" .
                     "                  by nickname and hostmask. This imports\n" .
                     "                  all of the nicknames and hosts and fills\n" .
                     "                  in the ident with AKAImport, since AKA does\n" .
                     "                  not keep track of idents\n\nCommon usage:\n" .
                     "/track ident [input]  -  Search for entries by supplied ident\n" .
                     "/track nick  [input]  -  Search for entries by supplied nick\n" .
                     "/track host  [input]  -  Search for entries by supplied " .
                     "IP address\n" . " " x 25 . "or hostmask, IPv4 or IPv6\n" .
                     "\n%RNote%n: Regular expressions are acceptable! Be\n" .
                     "careful though. It has no protection to stop you from \n" .
                     "sucking at regex. If you don't match something, it'll\n" .
                     "crash the script (unmatched quantifiers)\nLove,\n  --Ziddy\n");
        return;
    }

    foreach my $line (@list) {
        my ($unick, $ident, $host);
        if ($type eq "ident") {
            if ($line =~ m/^(.*?);($data);(.*)$/i) {
                ($unick, $ident, $host) = (unconv($1), unconv($2), $3);
                Irssi::print("%GIdent[%n$data%G]%n: $unick used $ident on $host");
                $match = 1;
            }
        } elsif ($type eq "host") {
            if ($line =~ m/^(.*?);(.*?);($data)$/i) {
                ($unick, $ident, $host) = (unconv($1), unconv($2), $3);
                Irssi::print("%GHost[%n$data%G]%n: $unick used $ident on $host");
                $match = 1;
            }
        } elsif ($type eq "nick") {
            if ($line =~ m/^($data);(.*?);(.*)$/i) {
                ($unick, $ident, $host) = (unconv($1), unconv($2), $3);
                Irssi::print("%GNick[%n$data%G]%n: $unick used $ident on $host");
                $match = 1;
            }
        } else {
            Irssi::print("%RUsage%n: /track [ident|host|nick] [input]");
            last;
        }
    }

    if (!$match) {
        Irssi::print("%RNo data to return");
    }
}

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub namechan {
    my ($null, $cserv) = @_;
    my $count = 0;
    $cserv = $cserv->{tag};
    foreach my $serv (Irssi::channels()) {
        my $curserv = $serv->{server}->{tag};
        if ($cserv eq $curserv) {
            foreach my $nname ($serv->nicks()) {
                my $nickc = conv($nname->{nick});
                my $nick  = $nname->{nick};
                open(my $fh, '<', Irssi::get_irssi_dir() . "/scripts/track.lst");
                my @list  = <$fh>;
                close($fh);

                if(!grep(/$nickc;/, @list)) {
                    Irssi::active_server->send_raw("WHOIS " . $nick);
                    $count++;
                } else {
                    if (!$quiet) { Irssi::print("%RAlready gathered $nick"); }
                }

            }
        }
    }
    Irssi::print("%GGathering complete - Added $count new entries");
}

sub conv {
    my $data = $_[0];
    if (!$data) { return; }
    ($data = $data) =~ s/\]/~~/g;
    ($data = $data) =~ s/\[/@@/g;
    ($data = $data) =~ s/\^/##/g;
    ($data = $data) =~ s/\\/&&/g;
    return $data;
}

sub unconv {
    my $data = $_[0];
    if (!$data) { return; }
    ($data = $data) =~ s/~~/\]/g;
    ($data = $data) =~ s/@@/\[/g;
    ($data = $data) =~ s/##/\^/g;
    ($data = $data) =~ s/%%/\\/g;
    return $data;
}

#Messy for now
sub importAKA {
    my $input = $_[0];
    if (-e $input) {
        open(my $fh, '<', $input);
        my @list = <$fh>;
        close($fh);
        my $ip = 0;
        my ($string, $import);
        foreach my $line (@list) {
            chomp($line);
            my @nicks;
            if ($line =~ /(.*?)@(.*+)/g) {
                $ip = $2;
            } elsif ($line =~ /(.*)~/g) {
                my @nicksplit = split(/~/, $1);
                foreach my $ns (@nicksplit) {
                    push(@nicks, $ns);
                }
            }
            foreach my $nick (@nicks) {
                my $snick = conv($nick);
                if ($snick and $ip) {
                    if (length($snick) > 1 and length($ip) > 1) {
                        $string .= "$snick;AKAImport;$ip;;;";
                    }
                }
            }
        }
        my @arrn = split(/;;;/, $string);
        open(my $fh2, '>>', Irssi::get_irssi_dir() . "scripts/track.lst");
        foreach my $out (@arrn) {
            if (length($out) > 1) {
                $out =~ s/\r//g;
                print $fh2 "$out\n";
                $import++;
            }
        }
        close($fh2);
        Irssi::print("%GImported $import users into the database%n");
    }
}

Irssi::command_bind('track' => \&track);
Irssi::command_bind('gather' => \&namechan);
Irssi::command_bind('import' => \&importAKA);
Irssi::signal_add('message join', 'joining');
Irssi::signal_add('message nick', 'nchange');
Irssi::signal_add_first('event 311', 'whois_signal');
