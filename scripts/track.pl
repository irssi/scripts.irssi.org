use Irssi qw(servers);
use warnings; use strict;
use vars qw($VERSION %IRSSI); 

my $EMPTY  = qw();
my $quiet  = 0;
$VERSION   = "1.3";
  
%IRSSI = (
      authors => "Ziddy",
      contact => "DALnet",
      name => "track.pl",
      description => "Builds a database of users, allowing easy indexing by"    .
                     " issuing /search [type] [input]. You can find a user "    .
                     "three ways: by nickname, by host (IP/hostmask) or by"     .
                     "ident. To specify which search you'd like to do, use"     .
                     "one of the three types: host, nick, ident\n"              .
                     "Wildcards work, but you need to use perl regex for it"    .
                     " to work. Use '/search help' for more infor and commands" .
                     "Let me know if you find any bugs by sending me a memo on" .
                     " DALnet. Thanks.\n  -Ziddy",
      license => "Public Domain",
      url => "none"
);

sub whois_signal {
    my ($server, $data, $txtserver) = @_;
    my ($me, $nick, $ident, $host) = split(" ", $data);
    open(my $fh, '>>', "$ENV{HOME}/.irssi/scripts/track.lst");
    open(my $fh2, '<', "$ENV{HOME}/.irssi/scripts/track.lst");
    my @list = <$fh2>;
    $nick    = conv($nick);
    ($ident  = $ident) =~ s/^~//;
    $ident   = conv($ident);

    if(!grep(/$nick;$ident;$host/, @list)) {
        print $fh "$nick;$ident;$host\n";
        if (!$quiet) { Irssi::print("%G$nick has been added to the database"); }
    } else {
        if (!$quiet) { Irssi::print("%R$nick exists in the database"); }
    }

    close($fh); close($fh2);
}

sub joining {
    my ($server, $channame, $nick, $host) = @_;
    open(my $fh, '>>', "$ENV{HOME}/.irssi/scripts/track.lst");
    open(my $fh2, '<', "$ENV{HOME}/.irssi/scripts/track.lst");
    $nick     = conv($nick);
    my @list  = <$fh2>;
    my @spl   = split(/@/, $host);
    my $ident = $spl[0];
    my $mask  = $spl[1];
    ($ident   = $ident) =~ s/^~//;
    $ident    = conv($ident);

    if(!grep(/$nick;$ident;$mask/, @list)) {
        print $fh "$nick;$ident;$mask\n";
        if (!$quiet) { Irssi::print("%GADDED $nick;$ident;$mask"); }
    } else {
        if (!$quiet) { Irssi::print("%REXIST $nick;$ident;$mask"); }
    }

    close($fh); close($fh2);
}

sub nchange {
    my ($server, $newnick, $oldnick, $host) = @_;
    open(my $fh, '>>', "$ENV{HOME}/.irssi/scripts/track.lst");
    open(my $fh2, '<', "$ENV{HOME}/.irssi/scripts/track.lst");
    $newnick  = conv($newnick);
    my @list  = <$fh2>;
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

    close($fh); close($fh2);
}

sub search {
    my $input  = $_[0];
    chomp($input);
    my @spl    = split(/\s/, $input);
    my $type   = $spl[0];
    my $data   = $spl[1];
    $data      = conv($data);
    my $match  = 0;
    open(my $fh, '<', "$ENV{HOME}/.irssi/scripts/track.lst");
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
        Irssi::print("\n%GHelp%n\nUsage: /search [type] [input]\n" .
                     "       gather  -  Join your channels then run this\n" .
                     "                  to gather nicks already online\n" .
                     "                  This may take a while on first run\n" .
                     "        quiet  -  Toggle quiet. If this is on, it wont\n" .
                     "                  show when a person is added or already\n" .
                     "                  exists in the database\n" .
                     "        count  -  Print amount of database entries\n" .
                     "ident [input]  -  Search for entries by supplied ident\n" .
                     "nick  [input]  -  Search for entries by supplied nick\n" .
                     "host  [input]  -  Search for entries by supplied " .
                     "IP address\n" . " " x 18 . "or hostmask, IPv4 or IPv6\n" .
                     "\n%RNote%n: Regular expressions are acceptable! Be\n" .
                     "careful though. It has no protection to stop you from \n" .
                     "sucking at regex. If you don't match something, it'll\n" .
                     "crash the script (unmatched quantifiers)\nLove,\n  --Ziddy\n");
        return;
    }

    if ($type eq "gather") {
        &namechan;
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
            Irssi::print("%RUsage%n: /search [ident|host|nick] [input]");
            last;
        }
    }

    if (!$match) {
        Irssi::print("%RNo data to return");
    }
}

sub namechan {
    my $count = 0;
    foreach (Irssi::channels()) {
        foreach ($_->nicks()) {
            my $nickc = conv($_->{nick});
            my $nick  = $_->{nick};
            open(my $fh, '<', "$ENV{HOME}/.irssi/scripts/track.lst");
            my @list  = <$fh>;

            if(!grep(/$nickc;/, @list)) {
                Irssi::active_server->send_raw("WHOIS " . $nick);
                $count++;
            } else {
                if (!$quiet) { Irssi::print("%RAlready gathered $nick"); }
            }

            close($fh);
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

Irssi::command_bind('search' => \&search);
Irssi::signal_add('message join', 'joining');
Irssi::signal_add('message nick', 'nchange');
Irssi::signal_add_first('event 311', 'whois_signal');
