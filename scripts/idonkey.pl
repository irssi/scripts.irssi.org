# iDonkey for mldonkey
#
## by Stefan Tomanek
#

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2004051601";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "iDonkey",
    description => "equips Irssi with an interface to mldonkey",
    license     => "GPLv2",
    changed     => "$VERSION",
    modules     => "IO::Socket::INET Data::Dumper LWP::UserAgent HTML::Entities",
    sbitems     => "idonkey",
    commands	=> "idonkey"
);


use Irssi 20020324;
use Irssi::TextUI;
use IO::Socket::INET;
use LWP::UserAgent;
use HTML::Entities;
use Data::Dumper;
use POSIX;
use vars qw($forked $timer $timer2 $index %downloads $nresults $seen $credits $noul %edlinks $expected);

sub show_help() {
    my $help = $IRSSI{name}." $VERSION
/idonkey (downloads)
    List your current downloads
/idonkey launch
    Start a new mldonkey process
/idonkey quit
    Quit the mldonkey
/idonkey servers (connected)
    List connected servers
/idonkey servers all
    List all servers
/idonkey servers connect <num>
    Connect to server with id <num>
    or connect more servers
/idonkey servers disconnect <num>
    Disconnnect from server with id <num>
/idonkey overnet (stats)
    Print OverNet statistics
/idonkey dllink (force) <link>
    Download an ed2k-link
/idonkey search <query>
    Query the donkey network for a file
/idonkey results
    Display the results of the last query
/idonkey get (force) <num1> <num2>
    Download the named files
/idonkey pause <filename>
    Pause a download
/idonkey resume <filename>
    Resume a download
/idonkey cancel <filename>
    Cancel a download
/idonkey commit
    Move downloaded files to the incoming directory
/idonkey settings show
    Display the current mldonkey settings
/idonkey settings change <key> <value>
    Change settings of mldonkey
/idonkey shares reshare
    Check all shared files
/idonkey shares close
    Close all open file descriptors
/idonkey sharereactor (latest)
    Display the latest releases
/idonkey sharereactor search <query>
    Search www.sharereactor.com
/idonkey sharereactor download <release>
    Download all files of a release
/idonkey bittorrent search <quer>
    Search torrents
/idonkey noupload <min>
    Disable uploading for <min> minutes
/idonkey client-stats
    Display detailed client statistics
/idonkey forget
    Clear all searches
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box($IRSSI{name}, $text, "help", 1);
}


sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = ''; 
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
    	$box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    unless ($colour) {
	$box =~ s/%(.)/$1 eq '%'?$1:''/eg;
    }
    return $box;
}   

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
	    my $l = $line->[$_];
	    $l =~ s/%[^%]//g;
	    $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }   
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
	    my $l = $line->[$_];
            $text .= $line->[$_];
	    $l =~ s/%[^%]//g;
	    $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1) unless ($_ == scalar(@$line)-1);
        }
        $text .= "\n";
    }
    return $text;
}

sub donkey_connect {
    my $host = Irssi::settings_get_str('idonkey_host');
    my $port = Irssi::settings_get_int('idonkey_port');
    my $password = Irssi::settings_get_str('idonkey_password');
    my $sock = IO::Socket::INET->new(PeerAddr => $host,
                                     PeerPort => $port,
                                     Proto    => 'tcp');
    return 0 unless $sock;
    my $password = Irssi::settings_get_str('idonkey_password');
    while ($_ = $sock->getline()) {
	s/\e.*?m//g;
	if (/Use \? for help/) {
	    $sock->print("auth ".$password."\n");
	} elsif (/Full access enabled/) {
	    $sock->print("ansi false\n");
	    foreach (1..3) {
		$sock->getline();
	    }
	    return $sock;
	} elsif (/Bad login\/password/) {
	    $sock->close();
	    return 0;
	}
    }
}

sub bg_do ($) {
    my ($cmd) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    return if $forked > 1;
    $forked++;
    my $pid = fork();
    if ($pid > 0) {
        close $wh;
        Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($rh, \$pipetag);                                                    $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args); 
    } else {
	eval {
	    my $result;
	    if ($cmd eq 'downloads') {
		$result->{downloads} = get_downloads();
	    } elsif ($cmd =~ /^(pause|cancel|resume) (.*)/) {
		transfer_command($1, $2);
	    } elsif ($cmd =~ /^results *(.*)/) {
		$result->{results} = get_results($1);
	    } elsif ($cmd eq 'servers') {
		$result->{servers} = get_servers(0);
	    } elsif ($cmd eq 'allservers') {
		$result->{servers} = get_servers(1);
	    } elsif ($cmd eq 'status') {
		if (Irssi::settings_get_bool('idonkey_update_results')) {
		    #$result->{nresults} = scalar @{ get_results('/.*/')->{results} };
		}
		$result->{status} = get_status_info();
	    } elsif ($cmd eq 'ovstats') {
		$result->{ovstats} = get_ovstats();
	    } elsif ($cmd =~ /^settings (.*?)$/) {
		my $regexp = $1;
		$regexp = '.*' unless $regexp;
		$result->{settings} = get_settings($regexp);
	    } elsif ($cmd =~ /^set (.*?) (.*)$/) {
		my ($key, $val) = ($1, $2);
		$result->{change} = change_setting($key, $val);
	    } elsif ($cmd eq 'reshare') {
		$result->{reshare} = reshare();
	    } elsif ($cmd eq 'close_fds') {
		$result->{close_fds} = close_fds();
	    } elsif ($cmd =~ /^sr-search (.*)$/) {
		$result->{sr_search} = sharereactor_search($1);
	    } elsif ($cmd eq "sr-latest") {
		$result->{sr_latest} = sharereactor_latest();
	    } elsif ($cmd =~ /^bt-search (.*)$/) {
		$result->{bt_search} = bittorrent_search($1);
	    } elsif ($cmd =~ /^noupload (.*)$/) {
		$result->{noupload} = no_upload($1);
	    } elsif ($cmd eq 'client-stats') {
		$result->{client_stats} = get_client_stats();
	    } elsif ($cmd eq 'forget') {
		$result->{forget} = forget_searches();
	    } elsif ($cmd =~ /^fake (.*)/) {
		$result->{fake} = check_fake($1);
	    }
	    my $dumper = Data::Dumper->new([$result]);
	    $dumper->Purity(1)->Deepcopy(1);
	    my $text = $dumper->Dump;
	    print($wh $text);
	    #store_fd $result, $wh;
	    close($wh);
	};
	POSIX::_exit(1);
    }
    
}

sub pipe_input {
    my ($rh, $pipetag) = @{$_[0]};
    $forked--;
    Irssi::input_remove($$pipetag);
    my $text;
    $text .= $_ foreach <$rh>;
    #print "RETURN";
    #print $text;
    no strict 'vars';
    my $result = eval "$text";
    return unless ref $result;
    %downloads = %{ $result->{downloads} } if ref $result->{downloads};
    $expected = $result->{results}->{waiting} if defined  $result->{results} && $result->{results}->{waiting};
    show_client_stats($result->{client_stats}) if ref $result->{client_stats};
    list_downloads($result->{downloads}) if ref $result->{downloads};
    list_results($result->{results}) if ref $result->{results};
    list_servers($result->{servers}) if ref $result->{servers};
    show_ovstats($result->{ovstats},0) if ref $result->{ovstats};
    show_settings($result->{settings}) if ref $result->{settings};
    show_change($result->{change}) if ref $result->{change};
    update_status($result->{status}) if ref $result->{status};
    show_sr_search($result->{sr_search}) if ref $result->{sr_search};
    show_sr_latest($result->{sr_latest}) if ref $result->{sr_latest};
    show_bt_search($result->{bt_search}) if ref $result->{bt_search};
    store_links($result->{sr_search}) if ref $result->{sr_search};
    store_links_bt($result->{bt_search}) if ref $result->{bt_search};
    $nresults = $result->{nresults} if $result->{nresults};
    
    show_fake($result->{fake}) if $result->{fake};
    print CLIENTCRAP "%B>>%n Forgot ".$result->{forget}." searche(s)" if exists $result->{forget};
    print CLIENTCRAP "%B>>%n Upload disabled for ".$result->{noupload}->[0]." minutes" if exists $result->{noupload};
    print CLIENTCRAP "%B>>%n Shares have been checked" if $result->{reshare};
    print CLIENTCRAP "%B>>%n Files have been closed" if $result->{close_fds};
}

sub show_fake ($) {
    my ($data) = @_;
    my $name = $data->{filename};
    my $hash = $data->{hash};
    my $text = "%B>>%n '".$name."' [".$hash."] is ";
    $text .= 'not ' unless $data->{fake};
    $text .= 'a fake';
    print CLIENTCRAP $text;
}

sub store_links ($) {
    my ($results) = @_;
    %edlinks = ();
    foreach (@$results) {
	$edlinks{$_->{name}} = $_->{files};
    }
}

sub store_links_bt ($) {
    my ($results) = @_;
    %edlinks = ();
    foreach (@$results) {
        $edlinks{$_->{name}} = [ $_->{torrent} ];
    }
}


sub check_fake ($) {
    my ($num) = @_;
    my $results = get_results('/.*/');
    my $res;
    foreach (@{$results->{results}}) {
	#print $num."  ".$_->{id};
	$res = $_ if $_->{id} eq $num;
    }
    return undef unless $res;
    $res->{fake} = is_fake($res->{hash});
    return $res;
}

sub forget_searches {
    my $sock = donkey_connect();
    return undef unless $sock;
    my $i = 0;
    foreach (keys %{ get_queries() }) {
	$sock->print('forget '.$_."\n");
	$i++;
    }
    $sock->print("q\n");
    $sock->close();
    return $i;
}

sub show_client_stats ($) {
    my ($data) = @_;
    my @table;
    foreach (sort keys %$data) {
	my $first = 1;
	foreach my $item (sort keys %{ $data->{$_} }) {
	    next if $item eq 'banned';
	    next if $item eq 'seen';
	    next if $data->{$_}{$item}{num} == 0;
	    my @line;
	    push @line, $first ? "%9".$_."%9" : '';
	    $first = 0;
	    push @line, uc substr($item, 0, 1);
	    push @line, $data->{$_}{$item}{percent}."%";
	    push @line, '#'x(80/100 * $data->{$_}{$item}{percent});
	    push @table, \@line;
	}
    }
    my $text = array2table(@table);
    print CLIENTCRAP &draw_box('iDonkey', $text, 'Client Stats', 1);
}

sub show_sr_latest ($) {
    my ($results) = @_;
    my @table;
    foreach (@$results) {
	push @table, [$_->{date}, $_->{category}, "%9".$_->{title}."%9"];
	#$text .= $_->{date}." %9".$_->{title}."%9 [".$_->{category}."]\n";
    }
    my $text = array2table(@table);
    print CLIENTCRAP &draw_box('iDonkey', $text, 'Sharereactor latest releases', 1);
}

sub show_sr_search ($) {
    my ($results) = @_;
    my $text;
    foreach (@$results) {
	$text .= "%9".$_->{name}."%9 [".$_->{category}."]\n";
	foreach (@{ $_->{files} }) {
	    $text .= '-> '.$_."\n";
	}
    }
    print CLIENTCRAP &draw_box('iDonkey', $text, 'ShareReactor', 1);
}

sub show_bt_search ($) {
    my ($results) = @_;
    my $text;
    foreach (@$results) {
	$text .= "%9".$_->{name}."%9\n";
	my $url = $_->{torrent};
	$url =~ s/%/%%/g;
	$text .= "-> $url\n";
    }
    print CLIENTCRAP &draw_box('iDonkey', $text, 'BitTorrent results', 1);
}

sub show_change (\%) {
    my ($change) = @_;
    print CLIENTCRAP "%B>>%n [iDonkey] Setting %9".$change->{key}."%9 changed from '".$change->{old}."' to '".$change->{new}."'";
}

sub show_settings (\%) {
    my ($settings) = @_;
    my @table;
    foreach (sort keys %$settings) {
	push @table, ["%9".$_."%9", $settings->{$_}];
    }
    my $text = array2table(@table);
    print CLIENTCRAP &draw_box('iDonkey', $text, 'settings', 1);
}

sub show_ovstats (\%$) {
    my ($stats, $nodes) = @_;
    my $text;
    
    if ($nodes) {
	$text .= "%9Connected nodes:%9\n";
	$text .= '  '.$_."\n" foreach @{ $stats->{nodes} };
	$text .= "\n";
    }
    #$text .= @{ $stats->{nodes} }." connected nodes\n\n";
    $text .= "%9Search hits:%9 ".$stats->{search_hits}."\n";
    $text .= "%9Source hits:%9 ".$stats->{source_hits};
    print CLIENTCRAP &draw_box('iDonkey', $text, 'OverNet stats', 1);
}

sub update_status (\%) {
    my ($data) = @_;
    return unless ref $data;
    $expected = $data->{waiting};
    $noul = $data->{noupload};
    $credits = $data->{credit};
    %downloads = %{ $data->{downloads} };
    Irssi::statusbar_items_redraw('idonkey');
}

sub no_upload ($) {
    my ($min) = @_;
    my $sock = donkey_connect();
    return undef unless $sock;
    my $noup;
    my $credit;
    $sock->print('nu '.$min."\n");
    $sock->flush();
    $sock->print("vu\n");
    while ($_ = $sock->getline()) {
	if (/^Upload credits : (\d+) minutes$/) {
	    $credit = $1;
	} elsif (/^Upload disabled for (\d+)/) {
	    $noup = $1;
	    $sock->close();
	}
    }
    return [$noup, $credit];
}

sub get_client_stats {
    my %stats;
    my $sock = donkey_connect();
    return \%stats unless $sock;
    $sock->print("client_stats\n");
    my $op;
    while ($_ = $sock->getline()) {
	if (/Total seens:/) {
	    $op = "seen";
	} elsif (/Total filerequests received:/) {
	    $op = "requests";
	} elsif (/Total downloads:/) {
	    $op = "downloads";
	} elsif (/Total uploads:/) {
	    $op = "uploads";
	} elsif (/Total banneds:/) {
	    $op = "banned";
	} elsif (/^ *(.*?): *(\d+) \((\d+\.\d+) %\)/) {
	    $stats{$1}{$op}{num} = $2;
	    $stats{$1}{$op}{percent} = $3;
	} elsif (/^$/) {
	    $sock->close();
	    last;
	}
    }
    return \%stats;
}

sub get_downloads {
    my %downloads;
    my $sock = donkey_connect();
    return \%downloads unless $sock;
    $sock->print("vd\n");
    my $ready;
    my $nfiles;
    my @files;
    my $sent;
    while ($_ = $sock->getline()) {
	my $line = $_;
	#print $line foreach (1..100);
	if (/^Downloaded (\d+)\/(\d+) files/) {
	    $nfiles = $1+$2;
	#} elsif (/^\[(.*?) *(\d+) *?\] +(?:.*?) +([-0-9.]+) +(?:-?\d+) +(?:\d+) +[\d-]+:([\d-]+) +([0-9.-]+|Paused|Queued)/) {
	} elsif (/^\[(.*?) *(\d+) *?\] +(?:.*?) +([-0-9.]+) +(?:-?\d+) +(?:\d+) +(?:\d+) +[\d-]+:([\d-]+) +\d+\/\d+ +([0-9.-]+|Paused|Queued)/) {
	    #print $_;
	    my $id = $2;
	    $downloads{$id}{percent} = $3;
	    $downloads{$id}{available} = ($4 == 0) ? 1 : 0;
	    $downloads{$id}{rate} = $5;
	    push @files, $id;
	} elsif (/^ *\[(.*?) *(\d+) *?\] +(.*?) +(\d+) +[0-9A-Z]{32}/) {
	    my $id = $2;
	    $downloads{$id}{net} = $1;
	    $downloads{$id}{percent} = 100;
	    $downloads{$id}{rate} = "Completed";
	    $downloads{$id}{size} = $4;
	    $downloads{$id}{downloaded} = $4;
	    push @{ $downloads{$id}{names} }, $3;
	    #$sock->print("vd ".$id."\n");
	    push @files, $id;
	} elsif (/\[(.*?) *(\d+) *?\] +(.*?) +(\d+) +(\d+)$/) {
	    $downloads{$sent}{net} = $1;
	    $downloads{$sent}{size} = $4;
	    $downloads{$sent}{downloaded} = $5;
	    push @{ $downloads{$sent}{names} }, $3;
	} elsif (/^    \((.*?)\)$/) {
	    push @{ $downloads{$sent}{names} }, $1;
	} elsif (/^(\d+) sources:/) {
	    $downloads{$sent}{sources} = $1;
	    $sent = undef;
	    #$downloads{$processing}{onlist} = 0;
	} elsif (/^Chunks: \[(\d+)\]/ && not $downloads{$sent}{net} eq 'BitTorrent') {
	    foreach (split(//, $1)) {
		push @{ $downloads{$sent}{chunks} }, $_;
		#print $processing if $processing eq '3';
	    }
	}
	$ready = 1 if (@files == $nfiles);
	#} elsif (/^ *(?:.*?) \(last_ok <(?:.*?)> lasttry <(?:.*?)> nexttry <(?:.*?)> onlist (true|false)\)$/) {
	#    $downloads{$processing}{onlist}++ if $1 eq 'true';
	#}
	if (($nfiles == 0) || defined @files && @files == 0 && not defined $sent) {
	    $sock->close();
	    return \%downloads;
	} else {
	    if ($ready && not defined $sent) {
		$sent = pop @files;
		if (1) {
		    $sock->close();
		    $sock = donkey_connect();
		    #$sock->print("id\n");
		    $sock->print('vd '.$sent."\n");
		    # What a hack :) FIXME in mldonkey
		} else {
		    $sent = undef;
		}
	    }
	}
    }
}

sub transfer_command ($$) {
    my ($cmd, $transfer) = @_;
    my $sock = donkey_connect();
    return undef unless $sock;
    my $downloads = get_downloads();
    if ($downloads->{$transfer}) {
	$sock->print($cmd." ".$transfer."\n");
    } else {
	foreach (keys %$downloads) {
	    foreach my $name (@{$downloads->{$_}{names}}) {
		next unless $name eq $transfer;
		$sock->print($cmd." ".$_."\n");
	    }
	}
    }
    $sock->close();
}

sub sharereactor_latest {
    my $ua = LWP::UserAgent->new(env_proxy => 1,
 				 keep_alive => 1,
                                 timeout => 30);
    my $response = $ua->get('http://www.sharereactor.com/');
    my @releases;
    foreach (split /\n/, $response->content() ) {
	if (/^<a href="release\.php\?id=(\d+)">(\d+\.\d+\.\d+) - (.*?)<\/a> <a href="category\.php\?id=\d+">\((.*?)\)<\/a><br>/) {
	    #print "FOO";
	    my $new = { date => $2, id => $1, title => $3, category => $4 };
	    push @releases, $new;
	}
    }
    return \@releases;
}

sub sharereactor_search ($) {
    my ($query) = @_;
    my $enc_query = HTML::Entities::encode($query);
    my $ua = LWP::UserAgent->new(env_proxy => 1,
 				 keep_alive => 1,
                                 timeout => 30);
    my $response = $ua->get('http://www.sharereactor.com/search.php?search='.$enc_query.'&category=0');
    return unless $response->is_success();
    my @results;
    foreach (split /\n/, $response->content()) {
        if (/<a href="release\.php\?id=(\d+)">(.*?)<\/a>/) {
            push @results, { name => $2, id => $1 };

	    my $ua2 = LWP::UserAgent->new(env_proxy => 1,
			   		  keep_alive => 1,
					  timeout => 30);
            my $response2 = $ua2->get('http://www.sharereactor.com/downloadrelease.php?id='.$1);
            foreach (split /\n/, $response2->content()) {
                if (/"(ed2k:\/\/\|file\|.*?\|\d+\|.*?\|)";/) {
                    push @{ $results[-1]->{files} }, $1;
                }
            }
        } elsif (/<a href="category\.php\?id=\d+">(.*?)<\/a>/) {
            $results[-1]->{category} = $1;
        }
    }
    #print $_->{name}." ".$_->{id}."\n" foreach @results;
    return \@results;
}

sub bittorrent_search ($) {
    my ($query) = @_;
    my $enc_query = HTML::Entities::encode($query);
    my $ua = LWP::UserAgent->new(env_proxy => 1,
                                 keep_alive => 1,
                                 timeout => 30);
    my $response = $ua->get('http://www.bytemonsoon.com/?search='.$enc_query.'&cat=0&incldead=0');
    return unless $response->is_success();
    my @results;
    foreach (split /\n/, $response->content()) {
	if (/^<td><a href="details\.php\?id=(\d+)&amp;hit=1"><b>(.*?)<\/b><\/a><\/td>$/) {
	    push @results, { name => $2, id => $1 };
	} elsif (/^<td align="center"><a href="(.*?)">torrent<\/a><\/td>$/) {
	    $results[-1]->{torrent} = "http://www.bytemonsoon.com/$1";
	}
    }
    return \@results
}

sub get_ovstats {
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("ovstats\n");
    my $result; 
    $result->{nodes} = [];
    while ($_ = $sock->getline()) {
	if (/^ +(\d+\.\d+\.\d+.\d+:\d+)$/) {
	    push @{ $result->{nodes} }, $1;
	} elsif (/^  Search hits: (\d+)$/) {
	    $result->{search_hits} = $1;
	} elsif (/^  Source hits: (\d+)$/) {
	    $result->{source_hits} = $1;
	} elsif (/^$/) {
	    last;
	}
    }
    return $result;
}

sub is_fake ($) {
    my ($hash) = @_;
    my $ua = LWP::UserAgent->new(env_proxy => 1,
 				 keep_alive => 1,
                                 timeout => 30);
    my $url = 'http://edonkeyfakes.ath.cx/fakecheck/update/fakecheck.php';
    my %form = ( hash => $hash );
    my $response = $ua->post($url, \%form);
    return unless $response->is_success();
    return not ($response->content() =~ /Your query didn't match anything in our fakedatabase\!/);
}

sub get_settings ($) {
    my ($regexp) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("voo\n");
    my $result = {};
    while ($_ = $sock->getline()) {
	if (/^(.*?) = (.*?)$/) {
	    my ($key, $val) = ($1, $2);
	    #print "<".$regexp.">";
	    next unless ($key =~ /$regexp/i);
	    $result->{$key} = $val;
	} else {
	    $sock->close();
	    return $result;
	}
    }
}

sub reshare {
    my $sock = donkey_connect();
    return 0 unless $sock;
    $sock->print("reshare\n");
    $sock->close();
    return 1;
}

sub close_fds {
    my $sock = donkey_connect();
    return 0 unless $sock;
    $sock->print("close_fds\n");
    $sock->close();
    return 1;
}

sub change_setting ($$) {
    my ($key, $val) = @_;
    my $result;
    $result->{key} = $key;
    $result->{old} = get_settings($key)->{$key};
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("set ".$key." ".$val."\n");
    $sock->close();
    #$result->{new} = $val;
    $result->{new} = get_settings($key)->{$key};
    return $result;
}

sub get_servers ($) {
    my ($all) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    if ($all) {
	$sock->print("vma\n");
    } else {
	$sock->print("vm\n");
    }
    my $result;
    while ($_ = $sock->getline()) {
	#if (/^\[(.*?) (\d+) *\] ([0-9.]+):(\d+) + (.*?) + (\d+) +(\d+) (Connected)?$/) {
	if (/^\[(.*?) (\d+) *\] (.+):(\d+) + (.*?) + (\d+) +(\d+) (Connected)?$/) {
	    my $server = { net     => $1,
		           id      => $2,
	                   ip      => $3,
			   port    => $4,
			   comment => $5,
			   users   => $6,
			   files   => $7
			  };
	    $result->{$2} = $server;
	} elsif (/^ *$/) {
	    $sock->close();
	    return $result;
	}
    }
}

sub search_file ($) {
    my ($query) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("s ".$query."\n");
    while ($_ = $sock->getline()) {
	if (/Query \d+ Sent to \d+/) {
	    $sock->close;
	    return 1;
	} elsif (/exception/) {
	    $sock->close;
	    return 0;
	}
    }
}

sub list_downloads ($) {
    my ($data) = @_;
    my $text = downloads2text($data, '/.*/'); #downloads_list($data, '/.*/');
    print CLIENTCRAP &draw_box('iDonkey', $text, 'Downloads', 1);
}

sub get_best_name ($) {
    my ($names) = @_;
    my $result;
    foreach (@$names) {
	# It's a hash
	$result = $_;
	last unless /[A-Z0-9]{32}/;
    }
    return $result;
}

sub downloads2text ($$) {
    my ($downloads, $regexp) = @_;
    my $length = Irssi::settings_get_int('idonkey_max_filename_length');
    my $text;
    my @table;
    my @chunks;
    my @names;
    my ($speed, $downloaded, $size) = (0,0,0);
    foreach (sort {get_best_name($downloads->{$a}{names}) cmp get_best_name($downloads->{$b}{names})} keys %$downloads) {
	my @line;
	my $filename = get_best_name($downloads->{$_}{names});
	my $name = shorten_filename($filename, $length);
	$name =~ s/%/%%/g;
	my $download;
	# Color codes:
	#  Yellow	Paused
	#  Bold green	Completed
	#  Green	Downloading & 100% available
	#  Blue		Downloading, but not completly on network
	if ($downloads->{$_}{rate} =~ /Paused|Queued/) {
	    $download .= '%yo%n';
	} elsif ($downloads->{$_}{rate} eq 'Completed') {
	    $download .= '%Go%n';
	} else {
	    if ($downloads->{$_}{available}) {
		$download .= '%go%n';
	    } else {
		$download .= '%bo%n';
	    }
	    $speed += $downloads->{$_}{rate};
	}
	$size += $downloads->{$_}{size};
	$downloaded += $downloads->{$_}{downloaded};
	$download .= ' %9'.$name.'%9 ('.$_.')';
	push @names, $download;
	#$text .= "\n" if 1;
	push @line, round($downloads->{$_}{downloaded}, $downloads->{$_}{size});
	#$text .= '     '.round($downloads->{$_}{downloaded}, $downloads->{$_}{size})."/";
	push @line, round($downloads->{$_}{size},$downloads->{$_}{size});
	push @line, '('.$downloads->{$_}{percent}.'%%)';
	#$text .= round($downloads->{$_}{size},$downloads->{$_}{size})." (".$downloads->{$_}{percent}."%%)";
	if ($downloads->{$_}{rate} =~ /^[0-9.]+$/) {
	    push @line, $downloads->{$_}{rate}." kb/s";
	} elsif ($downloads->{$_}{rate} eq '-') {
	    push @line, "0 kb/s";
	} else {
	    push @line, $downloads->{$_}{rate};
	}
	#push @line, ' ['.$downloads->{$_}{sources}.'/'.$downloads->{$_}{onlist}.' @'.$downloads->{$_}{net}.']' if (defined $downloads->{$_}{sources});
	my $netload = '[';
	$netload .= $downloads->{$_}{sources}."@";
	$netload .= $downloads->{$_}{net}.']';
	push @line, $netload;
	push @line, .$downloads->{$_}{tag};
	#$text .= "\n";
	if (1 || $downloads->{$_}{chunks}) {
	    if (ref $downloads->{$_}{chunks} && @{$downloads->{$_}{chunks}} > 1) {
		my $chunk;
		$chunk .= '[';
		foreach (@{$downloads->{$_}{chunks}}) {
		    if ($_ > 1) {
			$chunk .= '%g|%n';
		    } elsif ($_ == 1) {
			$chunk .= '%b:%n';
		    } else {
			$chunk .= '%r.%n';
		    }
		}
		$chunk .= "]";
		push @chunks, $chunk;
	    } else {
		push @chunks, "";
	    }
	}
	push @table, \@line;
    }
    foreach (split /\n/, array2table(@table)) {
	$text .= (shift @names)."\n";
	$text .= "     ".$_."\n";
	if (Irssi::settings_get_bool('idonkey_show_chunks')) {
	    my $chunk = shift @chunks;
	    $text .= "   ".$chunk."\n" if $chunk;
	}
    }
    my $percent = $size > 0 ? ($downloaded / $size)*100 : 0; 
    $percent = $1 if ($percent =~ /(\d+\.\d{1}).*?/);
    if (keys %$downloads > 1) {
	$text .= "".'%9Total:%9 ';
	$text .= round($downloaded, $size).'/';
	$text .= round($size, $size);
	$text .= ' ('.$percent.'%%), '.$speed.' kb/s';
    }
    return $text;
}

sub round ($$) {
    return $_[0] unless Irssi::settings_get_bool('idonkey_round_filesize');
    if ($_[1] > 100000) {
	return sprintf "%.2fMB", $_[0]/1024/1024;
    } else {
	return sprintf "%.2fKB", $_[0]/1024;
    }
}

sub get_queries {
    my $sock = donkey_connect();
    # FIXME A real parser here?
    return undef unless $sock;
    $sock->print("vs\n");
    my %result;
    my $num;
    while ($_ = readline($sock)) {
	chop;
	if (/^Searching (\d+) queries$/) {
	    $num = $1;
	} elsif (/^\[(\d+) *\](.*) .*?$/) {
	    my $id = $1;
	    my $regexp = $2;
	    my @token = $regexp =~ /CONTAINS\[(.*?)\]/g;
	    $result{$id} = \@token;
	    $num--;
	}
	last if (defined $num && $num == 0);
    }
    return \%result;
}

sub get_results ($) {
    my ($filter) = @_;
    my $sock = donkey_connect();
    my $net = '.*';
    if ($filter =~ /-net (.*?)(?: |$)/) {
	$net = $1;
    }
    #my $regexp = '.*';
    my @filters;
    while  ($filter =~ /(\!?)\/(.*?)\//g) {
	my %entry = ( "reverse" => $1 ? 1 : 0,
	              "regexp"  => $2
		      );
	push @filters, \%entry;
    }
    my $result;
    my @results;
    my $waiting = 0;
    my $filtered = 0;
    return undef unless $sock;
    my $num = 0;
    $sock->print("vr\n");
    my @token;
    while ($_ = readline($sock)) {
	chop;
	if (/^Result of search (\d+)$/) {
	    my $searches = get_queries();
	    @token = @{ $searches->{$1} } if ref $searches->{$1};
	} elsif (/^(\d+) results \((?:done|(-?\d+) waiting)\)$/) {
	    $num = $1;
	    $waiting = $2 if $2;
	    unless ($num) {
		$sock->close();
		last();
	    }
        } elsif (/^\[ *(\d+)\] (.*?(?: Napster)?) (.*)/) {
	    # FIXME Find a better Solution for open Napster
	    my %data = ( id=> $1, filename => $3, visible => 1, net => $2);
	    
	    $data{visible} = 1 unless @filters;
	    foreach my $entry (@filters) {
		next unless $data{visible};
		my $regexp = $entry->{regexp};
		my $reverse = $entry->{reverse};
		if (not $reverse) {
		    $data{visible} = 0 if not ($data{filename} =~ /$regexp/i);
		} else {
		    $data{visible} = 0 if ($data{filename} =~ /$regexp/i);
		}
	    }
	    if (Irssi::settings_get_bool('idonkey_filter_search_results') && @token) {
		foreach (@token) {
	    	    $data{visible} = 0 unless $data{filename} =~ /$_/i;
		    last unless $data{visible};
		}
		$data{visible} = 0 unless $data{net} =~ /$net/i;
	    }
            if (Irssi::settings_get_bool('idonkey_filter_nameless_results')) {
		    $data{visible} = 0 unless $data{filename};
            }
	    push @results, \%data;
	} elsif (/^ ALREADY DOWNLOADED$/) {
	    $results[-1]->{downloaded} = 1;
        } elsif (/^ +(-?\d+) ([0-9A-Z]{32}) (\d+)?/) {
	    $results[-1]->{size} = $1;
	    $results[-1]->{hash} = $2;
	    $results[-1]->{sources} = $3;
	    unless ($results[-1]->{visible}) {
		pop @results;
		$filtered++;
	    } else {
		#$results[-1]->{fake} = is_fake($results[-1]->{hash});
	    }
	} elsif (/No search to print/ || /^$/ || /^exception/) {
	    $sock->close();
	    last();
	}
    }
    my $sortby = Irssi::settings_get_str('idonkey_sort_results_by');
    @results = sort {uc($a->{$sortby}) <=> uc($b->{$sortby})} @results; 
    $result->{results} = \@results;
    $result->{waiting} = $waiting;
    $result->{filtered} = $filtered;
    return $result;
}

sub list_servers ($) {
    my ($data) = @_;
    my @text;
    foreach (sort { $data->{$a}{id} <=> $data->{$b}{id} } keys %$data) {
	push @text, ["%9".$data->{$_}{id}."%9", $data->{$_}{net}, $data->{$_}{ip}.':'.$data->{$_}{port}, $data->{$_}{users}, $data->{$_}{files}, $data->{$_}{comment}];
    }
    unshift @text, ["%9ID%9", "%9net%9", "%9address%9", "%9users%9", "%9files%9", "%9comment%9"] if @text;
    print CLIENTCRAP &draw_box('iDonkey', array2table(@text), 'servers', 1);
}

sub list_results ($) {
    my ($data) = @_;
    my $results = $data->{results};
    my @text;
    $seen = $nresults;
    my $length = Irssi::settings_get_int('idonkey_max_filename_length');
    foreach (@$results) {
	my @line;
	next unless $_->{visible};
	my $file = shorten_filename($_->{filename}, $length);
	$file =~ s/%/%%/g;
	push @line, '%9'.$_->{id}.'%9';
	push @line, '%9'.$file.'%9';
	push @line, $_->{fake} ? '%RF%n' : ''; 
	push @line, $_->{downloaded} ? '%GD%n' : ''; 
	push @line, $_->{net} if defined $_->{net};
	push @line, '['.$_->{sources}.']';
	push @line, round($_->{size}, $_->{size});
	
	push @text, \@line;
    }
    my $footer = 'Results';
    $footer .= ' ('.$data->{filtered}.' filtered)' if $data->{filtered} > 0;
    $footer .= ' ('.$data->{waiting}.' waiting)' if $data->{waiting} > 0;
    print CLIENTCRAP &draw_box('iDonkey', array2table(@text), $footer, 1);
}

sub get_file ($$) {
    my ($file, $force) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("d ".$file."\n");
    while ($_ = $sock->getline()) {
	if (/download started/) {
	    $sock->close();
	    return 1;
	} elsif (/(File already downloaded|could not start download)/) {
	    if ($force) {
		$sock->print("force_download\n");
		$sock->close();
		return 1
	    } else {
		$sock->close();
		return 0;
	    }
	}
    }
}

sub download_link ($$) {
    my ($url, $force) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("dllink ".$url."\n");
    $sock->print("force_download\n") if $force;
    while ($_ = $sock->getline()) {
	if (/download (started|forced)|Done/) {
	    $sock->close();
	    return 1;
	} elsif (/Unable|bad syntax|exception/ && not $force) {
	    $sock->close();
	    return 0;
	}
    }
}

sub connect_servers ($$) {
    my ($ids, $disconnect) = @_;
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("c\n") unless (@$ids);
    foreach (@$ids) {
	if ($disconnect) {
	    $sock->print("x ".$_."\n");
	} else {
	    $sock->print("c ".$_."\n");
	}
    }
    $sock->close();
}

sub quit_donkey {
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("kill\n");
    $sock->close();
    return 1;
}

sub commit_downloads {
    my $sock = donkey_connect();
    return unless $sock;
    $sock->print("commit\n");
    $sock->close();
    until ($_ = $sock->getline()) {
	#if (/commited/) {
	    return 1;
	#} else {
	#    return 0;
	#}
    }
}

sub get_status_info {
    my $result;
    $result->{downloads} = get_downloads();
    $result->{waiting} = get_results('/.*/')->{waiting};
    my $upload = no_upload(0);
    $result->{credit} = $upload->[1];
    $result->{noupload} = $upload->[0];
    return $result;
}

sub cmd_idonkey ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if (@arg == 0 || $arg[0] eq 'downloads') {
	#list_downloads();
	bg_do('downloads');
    } elsif ($arg[0] eq 'help') {
	show_help();
    } elsif ($arg[0] =~ /pause|resume|cancel/ && defined $arg[1]) {
	bg_do(join(' ', @arg));
    } elsif ($arg[0] =~ /results/) {
	bg_do(join(' ', @arg));
    } elsif ($arg[0] eq 'search') {
	shift @arg;
	if (search_file(join(' ', @arg))) {
	    $seen = 0;
	    $nresults = 0;
	    print CLIENTCRAP "%R>>%n Query '".join(' ', @arg)."' sent to network...";
	}
    } elsif ($arg[0] eq 'get' && defined $arg[1]) {
	shift @arg;
	my $force = 0;
	foreach my $id (@arg) {
	    if ($id eq 'force') {
		$force = 1;
	    } elsif (get_file($id, $force)) {
		print CLIENTCRAP "%R>>%n Download of file ".$id." started";
	    } else {
		print CLIENTCRAP "%R>>%n Download of file ".$id." failed";
	    }
	}
    } elsif ($arg[0] eq 'dllink' && defined $arg[1]) {
	shift @arg;
	join(' ', @arg) =~ /(force )?(.*)/;
	my $force = defined $1 ? 1 : 0;
	if (download_link($2, $1)) {
	    print CLIENTCRAP "%R>>%n Download of ".$2." started";
	} else {
	    print CLIENTCRAP "%R>>%n Download of ".$2." failed";
	}
    } elsif ($arg[0] eq 'commit') {
	if (commit_downloads()) {
	    print CLIENTCRAP "%R>>%n Completed downloads saved";
	} else {
	    print CLIENTCRAP "%R>>%n Saving completed downloads failed";
	}
    } elsif ($arg[0] eq 'launch') {
	my $cmd = Irssi::settings_get_str('idonkey_mldonkey_cmd');
	system($cmd);
	print CLIENTCRAP "%R>>%n MLDonkey launched";
    } elsif ($arg[0] eq 'quit') {
	if ( quit_donkey() ) {
	    print CLIENTCRAP "%R>>%n MLDonkey killed";
	} else {
	    print CLIENTCRAP "%R>>%n Unable to kill MLDonkey";
	}
    } elsif ($arg[0] eq 'servers') {
	shift @arg;
	if ( (not @arg) || ($arg[0] eq 'connected') ) {
	    bg_do('servers');
	} elsif ($arg[0] eq 'disconnect') {
	    shift @arg;
	    connect_servers(\@arg, 1);
	} elsif ($arg[0] eq 'connect') {
	    shift @arg;
	    connect_servers(\@arg, 0);
	} elsif ($arg[0] eq 'all') {
	    bg_do('allservers');
	}
    } elsif ($arg[0] eq 'overnet') {
	shift @arg;
	if ( (not @arg) || ($arg[0] eq 'stats') ) {
	    bg_do('ovstats');
	} elsif ($arg[0] eq 'nodes') {
	    bg_do('ovnodes');
	}
    } elsif ($arg[0] eq 'settings') {
	shift @arg;
	if ( (not @arg) ) {
	    # Do something
	} elsif ($arg[0] eq 'show') {
	    shift @arg;
	    bg_do('settings '.join(' ',@arg));
	} elsif ($arg[0] eq 'change') {
	    shift @arg;
	    return unless (defined $arg[0] && defined $arg[1]);
	    my $key = shift @arg;
	    my $val = join(' ', @arg);
	    bg_do('set '.$key.' '.$val)
	}
    } elsif ($arg[0] eq 'shares') {
	shift @arg;
	if ( (not @arg) ) {
	    ## list shares?
	} elsif ($arg[0] eq 'reshare') {
	    bg_do('reshare');
	} elsif ($arg[0] eq 'close') {
	    bg_do('close_fds');
	}
    } elsif ($arg[0] eq 'sharereactor') {
	shift @arg;
	if ( (not @arg) || $arg[0] eq 'latest') {
	    print CLIENTCRAP "%B>>%n Retrieving latest releases...";
	    bg_do('sr-latest');
	} elsif ($arg[0] eq 'search') {
	    shift @arg;
	    bg_do('sr-search '.join(" ", @arg));
	    print CLIENTCRAP "%B>>%n Searching ShareReactor for '".join(" ", @arg)."'";
	} elsif ($arg[0] eq 'download' && defined $arg[1]) {
	    shift @arg;
	    download_sr(join(" ", @arg));
	}
    } elsif ($arg[0] eq 'bittorrent') {
	shift @arg;
	if ($arg[0] eq 'search') {
	    shift @arg;
	    bg_do('bt-search '.join(" ", @arg));
	    print CLIENTCRAP "%B>>%n Searching BitTorrent for '".join(" ", @arg)."'";
	}
    } elsif ($arg[0] eq 'noupload') {
	shift @arg;
	if (@arg && $arg[0] =~ /-?\d+/) {
	    bg_do('noupload '.$arg[0]);
	}
    } elsif ($arg[0] eq 'client-stats') {
	bg_do('client-stats');
    } elsif ($arg[0] eq 'forget') {
	bg_do('forget');
    } elsif ($arg[0] eq 'fake' && defined $arg[1]) {
	shift @arg;
	foreach (@arg) {
	    next unless /\d+/;
	    bg_do('fake '.$_);
	}
    }
}

sub download_sr ($) {
    my ($download) = @_;
    if (defined $edlinks{$download}) {
	foreach my $link (@{ $edlinks{$download} }) {
	    if (download_link($link,0)) {
		print CLIENTCRAP "%R>>%n Download of ".$link." started";
	    } else {
		print CLIENTCRAP "%R>>%n Download of ".$link." failed";
	    }
	}
    } else {
	print CLIENTCRAP "%B>>%n Unknown release, try searching for it.";
    }
}


sub shorten_filename ($$) {
    my ($file, $length) = @_;
    unless ($length == 0) {
	my $post = 4;
	my $pre = $length-5-$post;
	$file =~ s/^(.{$pre}).*(.{$post})/$1\[\.\.\.\]$2/;
    }
    return $file;
}

sub filename_percent ($$) {
    my ($name, $percent) = @_;
    my $length = length($name);
    my $done = $length * ($percent/100);
    my $string = '%g%U'.substr($name, 0, $done).'%U%n%y'.substr($name, $done, $length).'%n';
    return $string;
}

sub sb_idonkey ($$) {
    my ($item, $get_size_only) = @_;
    my $line;
    $line .= $nresults."|" if ($seen != $nresults && defined $seen);
    $line .= '%F'.$expected."%F|" if $expected > 0;
    $line .= $noul."min|" if $noul > 0;
    #my $length = Irssi::settings_get_int('idonkey_max_filename_length');
    my $length = Irssi::settings_get_int('idonkey_statusbar_max_filename_length');
    my $i = 0;
    foreach (sort keys %downloads) {
	$index = 0 if $index > (scalar keys %downloads)-1;
	unless ($i == $index) {
	    $i++;
	    next;
	}
	unless (Irssi::settings_get_bool('idonkey_statusbar_show_paused')) {
	    if ($downloads{$_}{rate} eq 'Paused') {
		$index++;
		next;
	    }
	}
	my $filename = get_best_name($downloads{$_}{names});
	my $file = shorten_filename($filename, $length);
	$line .= filename_percent($file, $downloads{$_}{percent});
	$line .= ' '.$downloads{$_}{percent}.'%% ';
	unless ($downloads{$_}{rate} eq '-') {
	    $line .= $downloads{$_}{rate};
	    $line .= ' kb/s' if $downloads{$_}{rate} =~ /^[0-9.]+$/;
	}
	$line .= ' ';
	$i++;
    }
    $line =~ s/ $//;
    my $format = "{sb ".$line."}";
    $item->{min_size} = $item->{max_size} = length($line);
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub call_for_status {
    bg_do('status');
}

sub sig_complete_word ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    if ($linestart =~ /^.idonkey (pause|resume|cancel)/) {
	foreach (sort {get_best_name($downloads{$a}{names}) cmp get_best_name($downloads{$b}{names})} keys %downloads) {
	    my $name = get_best_name($downloads{$_}{names});
	    if ( ($1 eq 'resume' && $downloads{$_}{rate} eq 'Paused') ||
		($1 eq 'pause'  && not $downloads{$_}{rate} eq 'Paused') ||
		($1 eq 'cancel') ) {
		push @$list, $name if $name =~ /^(\Q$word\E.*)?$/i;
	    }
	}
	Irssi::signal_stop();
    } elsif ($linestart =~ /^.idonkey search/) {
	my @opts = ('minsize', 'maxsize', 'media', 'Video', 'Audio', 'format', 'title', 'album', 'artist', 'field', 'not', 'and', 'or');
	foreach (@opts) {
	    $_ = '-'.$_;
	    push @$list, $_ if /^(\Q$word\E.*)?$/i;
	}
	Irssi::signal_stop();
    } elsif ($linestart =~ /^.idonkey sharereactor download/) {
	foreach (sort keys %edlinks) {
	    push @$list, $_ if /^(\Q$word\E.*)?$/i;
	}
	Irssi::signal_stop();
    } elsif ($linestart =~ /^.idonkey dllink/) {
	foreach (sort keys %edlinks) {
	    foreach my $link (@{ $edlinks{$_} }) {
		push @$list, $link if $link =~ /^(\Q$word\E.*)?$/i;
	    }
	}
	Irssi::signal_stop();
    } elsif ($linestart =~ /^.idonkey results/) {
	my @opts = ('net');
	foreach (@opts) {
	    $_ = '-'.$_;
	    push @$list, $_ if /^(\Q$word\E.*)?$/i;
	}
    }
}

sub next_status {
    $index++;
    $index = 0 if $index > (scalar keys %downloads)-1;
    Irssi::statusbar_items_redraw('idonkey');
}

sub install_timer {
    return if defined $timer;
    my $timeout = Irssi::settings_get_int('idonkey_statusbar_interval');
    my $timeout2 = Irssi::settings_get_int('idonkey_update_interval');
    return unless $timeout && $timeout2;
    $timer = Irssi::timeout_add($timeout*1000, \&next_status, undef);
    $timer2 = Irssi::timeout_add($timeout2*1000, \&call_for_status, undef);
}

sub uninstall_timer {
    return unless defined $timer;
    Irssi::timeout_remove($timer);
    Irssi::timeout_remove($timer2);
    $timer = undef;
}

Irssi::command_bind('idonkey', \&cmd_idonkey);
foreach my $cmd ('downloads', 'pause', 'resume', 'results', 'search', 'get', 'get force', 'cancel', 'help', 'commit', 'dllink', 'dllink force', 'launch', 'quit', 'servers', 'servers disconnect', 'servers connected', 'servers all', 'servers connect', 'overnet', 'overnet stats', 'overnet nodes', 'settings', 'settings show', 'settings change', 'shares', 'shares reshare', 'shares close', 'sharereactor', 'sharereactor search', 'sharereactor download', 'sharereactor latest', 'noupload', 'client-stats', 'forget', 'fake', 'bittorrent', 'bittorrent search') {
    Irssi::command_bind('idonkey '.$cmd => sub {
        cmd_idonkey("$cmd ".$_[0], $_[1], $_[2]); });
}
Irssi::signal_add_first('complete word', \&sig_complete_word);

Irssi::settings_add_str($IRSSI{name}, 'idonkey_password', '');
Irssi::settings_add_str($IRSSI{name}, 'idonkey_host', 'localhost');
Irssi::settings_add_int($IRSSI{name}, 'idonkey_port', 4000);
Irssi::settings_add_int($IRSSI{name}, 'idonkey_max_filename_length', 65);
# sources, filename, id, size
Irssi::settings_add_str($IRSSI{name}, 'idonkey_sort_results_by', "id");
Irssi::settings_add_bool($IRSSI{name}, 'idonkey_round_filesize', 1);


Irssi::settings_add_bool($IRSSI{name}, 'idonkey_filter_nameless_results', 1);
Irssi::settings_add_bool($IRSSI{name}, 'idonkey_filter_search_results', 0);
Irssi::settings_add_bool($IRSSI{name}, 'idonkey_show_chunks', 1);

Irssi::settings_add_str($IRSSI{name}, 'idonkey_mldonkey_cmd', 'screen mldonkey');
Irssi::settings_add_int($IRSSI{name}, 'idonkey_statusbar_interval', 0);
Irssi::settings_add_bool($IRSSI{name}, 'idonkey_statusbar_show_paused', 1);
Irssi::settings_add_int($IRSSI{name}, 'idonkey_update_interval', 0);
Irssi::settings_add_bool($IRSSI{name}, 'idonkey_update_results', 1);
Irssi::settings_add_int($IRSSI{name}, 'idonkey_statusbar_max_filename_length', 25);

Irssi::statusbar_item_register('idonkey', 0, "sb_idonkey");

install_timer();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded, /idonkey help';
