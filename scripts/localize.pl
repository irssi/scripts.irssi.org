#!/usr/bin/perl
#
#
# By Stefan 'tommie' Tomanek, stefan@kann-nix.org
#
#
# This script works fine on DFN (german universities) and T-Oline sites
#
# 01.03.2002
# *Changed to GPL
#
# 15.03.2002
# *Now works on QUERIES as well
#
# 24.04.2002
# *the nick does not have to be on the channel
# *switched to /WHO
#
# 27.04.2002
# *localization of hosts (/localize @hostname)
#
# 29.04.2002
# *tweaked Design
# *added channel statistics
#
# 04.05.2002
# *added alternate database (IP Atlas)
#
# 05.05.2002
# *the script is now able to use both databases simultaniously
# */set localize_use_<database> to enable or disable them
#
# 10.05.2002
# *non-blocking IO via fork()
#
# 13.05.2002
# *finally improved forking and background localizing
# *now using XML
#
# 26.05.2002
# *Implemented auto-localize
#
# 28.05.2002
# *major updates
# *fixed race conditions
#
# 30.05.2002
# *finally rendered traceroute support usefull
#
# 31.05.2002
# *moved database to this file
#
# 03.07.2002
# *switched to Data::Dumper
#
# 25.11.2014
# Added utrace.de as a localizer
# http://www.utrace.de/

use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "2014112501";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "localize",
    description => "Localizes users using traceroute, the localizer database or IP-Atlas",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION",
    modules     => "Data::Dumper LWP::UserAgent HTML::Entities",
    commands	=> "localize"
);

use Irssi 20020324;
use LWP::UserAgent;
use HTML::Entities;
use Data::Dumper;
use POSIX;
use Socket;

use vars qw(%queries %cache %ipdb $procs @tracer $debug);
$debug = 0;
$procs = 0;


# host regexps for trace_host
#

@tracer = (
    { provider => 'tonline',
      regexp   => [ '.*?-.*?\.(.*?)(\.DE|)\.net\.dtag\.de', ]
    },
    { provider => 'uunet',
      regexp   => [ '.*?-\d+-\d+\..*?\.(.*?)\d?\.uunet\.de', ]
    },
    { provider => 'kpnqwest',
      regexp   => [ '.*?-.*?\.(\w?)\.de\.kpnqwest\.net', ]
    },
    { provider => 'ewetel',
      regexp   => [ '.*?-.*?-.*?\.rt8\.(.*?)\.ewetel\.net',
                    '(.*?)[0-9]*-.*?\.ewetel\.net',
		    'so\d+-\d+-\d+-bbrt\d+\.(.*?)\.ewe-ip-backbone\.de']
    },
    { provider => 'arcor',
      regexp   => [ '((?!dsl)\w+)-\d+-\d+-\d+-\d+\.arcor-ip\.net',
                    '.*?-(.*?)-.*?\d*\.arcor-online\.net']
    },
    { provider => 'mediaways',
      regexp   => ['.*-(.*)-de.*-.*-.*-.*\..*\.mediaways.net', ]
    },
    { provider => 'mobilcom',
      regexp   => ['.*\.(.*?)[0-9]+-.\.mcbone\.net',]
    },
    { provider => 'vianetworks',
      regexp   => ['\w+\.(.*?)\.revmap\.vianetworks\.de',
                   'rt\d{3}(.*?)\.de\.vianw\.net',]
    },
    { provider => 'mfnx',
      regexp   => ['.+-\d+-\d+-\d+\..+\.(.*?)[0-9]+\.de\.mfnx\.net',]
    },
    { provider => 'colt',
      regexp   => ['.+-.*\..+\.(.*?)\.DE.COLT-ISC.NET',
                   '.+\.((?!dsl)(?!host)\w+)\.de\.colt\.net',
		   '..\d\.(\w+)\.de\.colt\.net',]
    },
    { provider => 'telia',
      regexp   => ['(.*?)-.+-.+-.+\.telia.net',]
    },
    { provider => 'hansanet',
      regexp   => ['.*\.(.*?)-[0-9]+\.hansenet\.net',]
    },
    { provider => 'isis',
      regexp   => ['isis-gw-(.*?)[0-9]\.de\.cw\.net', ]
    },
    { provider => 'cable & wireless',
      regexp   => ['.*-\d+-\d+-\d+-.*?-(.*?)\d+\.de\.cw\.net',
                   '.*?-.*?-(.*?)\d+\.de\.cw\.net']
    },
    { provider => 'NEFkom',
      regexp   => ['nefkom-gw-(.*?)\.de\.cw\.net',]
    },
    { provider => 'eastlink',
      regexp   => ['.*?-.*?-.*?-.*?-(.*?)\.eastlink.de',]
    },
    { provider => 'alternet',
      regexp   => ['.*\.(.*?)\d?\.de\.alter\.net',]
    },
    { provider => 'CompleTel',
      regexp   => ['.+-.+-.+-.+\.(.*)\.ipcenta\.de',]
    },
    { provider => 'mediascape',
      regexp   => ['.+\..+\.(.*?)\.mediascape\.net',]
    },
    { provider => 'schlund',
      regexp   => ['gw-prtr-[0-9]+-.+\.(.+)[0-9]+\.schlund.net',]
    },
    { provider => 'bisping',
      regexp   => ['(.*?)-gw-pmx[0-9]*\.bisping\.net',]
    },
    { provider => 'gatel',
      regexp   => ['ser[0-3]+-[0-3]+\.(.*?)[0-3]+\.de\.gatel\.net',]
    },
    { provider => 'qsc',
      regexp   => ['rqsc-(.*?)-de[0-9]+-.+[0-9]+-[0-9]+-[0-9]+\.nw\.mediaways\.net',
                   'bsn\d+\.(.*?)\.qdsl-home\.de',
		   'bsn\d+\.(.*?)\.qsc\.de',
		   'core1\.(.*?)\.qsc\.de']
    },
    { provider => 'dfn',
      regexp   => ['.r-(.*?)[0-9]+\.g-win.dfn.de',
                   '.*\.uni-(.*?)\.de',
		   '.*\.fh-(.*?)\.de',
		   '.*\.tu-(.*?)\.de',
		   '.*\.fu-(.*?)\.de',]
    },
    { provider => 'mops.net',
      regexp   => ['.*?\.core\d\.(.*?)\.mops\.net',]
    },
    { provider => 'schule.de',
      regexp   => ['.*\.(.*?)\..*?\.Schule\.DE',]
    },
    { provider => 'belwue',
      regexp   => ['(?:.*?-)?(.*?)\d+\.BelWue\.DE',]
    },
    { provider => 'lambdanet',
      regexp   => ['.*?\.(.*?)\.de\.lambdanet\.net',]
    }
);
    
%ipdb = (
    # For utrace.de API documentation, see http://en.utrace.de/api.php
    d1utrace=>{ name=>'utrace',
		   active=>1,
		   url=>'http://xml.utrace.de/?query=',
		   city=>'<region>(.*?)<\/region>',
		   province=>'<org>(.*?)<\/org>',
		   country=>'<countrycode>(.*?)<\/countrycode>',
		   provider=>'<isp>(.*?)<\/isp>', 
		   failure=>'request-limit-exceeded|Host not found'},
    d2ipatlas=> { name=>'IP-Atlas',
		  active=>0,
	          url=>'http://www.xpenguin.com/plot.php?address=',
                  city=>'is located in (.*?),',
		  province=>'is located in.*, (.*?) \(state\),',
		  country=>'is located in.*, (.*?)\. ',
		  failure=>'cannot be located|does not resolve' },
    d3netgeo => { name=>'NetGeo',
                  active=>0,
		  url=>'http://netgeo.caida.org/perl/netgeo.cgi?target=',
		  city=>'CITY:\ *(\w+)<br>',
		  province=>'STATE:.*?, (.*?) \(state\)<br>',
		  country=>'COUNTRY:\ *(\w+)<br>',
		  failure=> "SHOULD NOT"},
);

sub draw_box ($$$) {
    my ($title, $text, $footer) = @_;
    my $box = ''; 
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    return $box; 
}

sub show_help() {
    my $help="Localize $VERSION
/localize <nickname>
    Try to localize the user 'nickname'
/localize @<hostname>
    Try to localize the host
/localize <#channel>
    Create a tree of the people inside the channel
/localize -s
    Save the localize cache and settings
/localize -r
    Reload the localize cache from file
/localize -c
    Clear the cache
/localize -sc
    Shows the current content of the cache
/localize -h
    Display this help
";
    my $text = "";
    foreach (split(/\n/, $help)) {
	$_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box("Localize", $text, "Help");
}

sub get ($) {
    my ($url) = @_;
    my $ua = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
    $ua->agent('Irssi');
    my $request = HTTP::Request->new('GET', $url);
    my $response = $ua->request($request);
    if ($response->is_success()) {
	return $response->content();
    } else {
	return undef;
    }
}

sub parse_page ($$) {
    my ($page, $item) = @_;
    my %empty;
    my (%location);
    $_ = $page;
    my $regexp = $item->{failure};
    return(%location) if /$regexp/;
    foreach my $key ('city', 'province', 'country') {
	$location{$key} = '';
	my $regexp = $item->{$key};
	if (/$regexp/) {
	    $location{$key} = $1;
	} else {
	    return(%empty);
	}
    }
    if (defined $item->{provider}) {
	if (/$item->{provider}/) {
	    $location{provider} = $1;
	}
    }
    $location{map} = $item->{name} if (%location);
    return (%location);
}

sub trace_host ($) {
    my ($host) = @_;
    my $cmd = Irssi::settings_get_str('localize_trace_cmd');
    local *F;
    my $pid = open(F, '-|', $cmd.' '.$host.' 2>/dev/null');
    my $loc_host;
    my $provider;
    my $hops = 0;
    my $maxhops = Irssi::settings_get_int('localize_trace_distance');
    $_ = $host;
    while (defined $_) {
	print $_ if $debug;
	$hops++;
	if (/\*/) {
	    kill 15, $pid;
	    close(F);
	    return([$loc_host, $provider]) if ($hops < $maxhops && $hops >= 0);
	    return([undef, undef]);
	} else {
	    foreach my $traced (@tracer) {
		foreach my $regexp (@{$traced->{regexp}}) {
		    if (/[0-9]+  $regexp /i) {
			$loc_host = $1;
			$provider = $traced->{provider};
			print $regexp if $debug;
			print "$loc_host <-> $provider" if $debug;
			$hops = 0;
			last;
		    }
		}
	    }
	}
	$_ = <F>;
    }
    close(F);
    if ( ($hops < $maxhops) && ($hops >= 0)) {
	if ($debug) {
	    print $loc_host."-".$provider foreach (1..10);
	}
	return([$loc_host, $provider]);
    } else {
	print $hops." -> ".$maxhops if $debug;
    }
    return([undef, undef]);
}

sub localize($$) {
    my ($nicks, $query) = @_;
    if (Irssi::settings_get_bool('localize_background')) {
	bg_fetch($nicks, $query);
    } else {
	fg_fetch($nicks, $query);
    }
}

sub fg_fetch ($$) {
    my ($nicks, $query) = @_;
    my $data = create_output(@{$nicks});
    my $auto = $queries{$query}->[0]{auto};
    remove_request($query);
    process_input($query, $auto, $data);
}

sub bg_fetch ($$) {
    my ($nicks, $query) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    my $pid = fork();
    $procs++;
    if ($pid > 0) {
	close $wh;
	my $size = scalar(@{$nicks});
	my $auto = $queries{$query}->[0]{auto};
	remove_request($query);
	unless ($auto ne '') {
	    print CLIENTCRAP '%R>>%n Localizing '.$size.' host(s) in background [pid '.$pid.']...' if Irssi::settings_get_bool('localize_show_message');
	}
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, $query, $auto, \$pipetag);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	my $data = create_output(@{$nicks});
	eval {
	    print($wh $data);
	    close($wh)
	};
	POSIX::_exit(1);
    }
}


sub create_output(@) {
    my (@nicks) = @_;
    my @new_db;
    my @stuff;
    my @data;
    my $i = 0;
    foreach (@nicks) {
	my $nick = $$_[0];
	my $host = $$_[1];
	my (%location);
	if (defined $cache{$host}) {
	    %location = %{$cache{$host}};
	    $location{$_} = $location{$_} foreach (keys %location);
	    $location{'map'} .= " (cached)";
	} else {
	    if (Irssi::settings_get_bool('localize_use_traceroute')) {
		unless (%location) {
		    my ($sign, $provider) = @{ trace_host($host) };
		    print "\n\n>>>>".$sign if $debug;
		    %location = kfz2location($sign) if $sign;
		    $location{map} = 'traceroute' if (%location);
		    $location{provider} = $provider if (%location);
		}
	    }
	    if (Irssi::settings_get_bool('localize_use_databases')) {
		unless (%location) {
		    foreach (sort keys(%ipdb)) {
			my $item = $ipdb{$_};
			next unless $item->{active};
			#my $ip = gethostbyname($host);
			#next unless $ip;
			my $url = $item->{url}.$host; #inet_ntoa($ip);
			my $text = get($url);
			%location = parse_page($text, $item);
		    }
		}
	    }
	    if (Irssi::settings_get_bool('localize_get_coordinates')) {
		if (%location) {
		    my $city = $location{city};
		    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
		    my $data = $ua->get('http://www.astro.com/atlas/horoscope/?expr='.$city)->content();
		    foreach (split /\n/, $data) {
			decode_entities($_);
			if (/^<li><a href="\/cgi\/ade\.cgi\?&(?:.*?)">(.*?)<\/a>, (?:.*?): <b>(\d+)n(\d+)<\/b>, <b>(\d+)e(\d+)<\/b>/i) {
			    $location{latitude} = "$2.$3";
			    $location{longitude} = "$4.$5";
			    last;
			}
		    }
		}
	    }
	}
	$location{'nick'} = $nick if (%location);
	$location{'host'} = $host if (%location);
	#$location{$_} = $location{$_} foreach (keys %location);
	push @stuff, \%location;
	$i++;
    }
    my %foo = ("nicks" => \@stuff);
    my $dumper = Data::Dumper->new([\%foo]);
    $dumper->Purity(1)->Deepcopy(1);
    my $data = $dumper->Dump;
    return($data);
}

sub pipe_input ($$$$) {
    my ($rh, $query, $auto, $pipetag) = @{$_[0]};
    my @lines = <$rh>;
    close($rh);
    Irssi::input_remove($$pipetag);
    my $text = join("", @lines);
    process_input($query, $auto, $text);
}

sub process_input($$$) {
    my ($query, $auto, $text) = @_;
    my $channel_prefix = '^(\#|\+|\!)';
    my %stuff;
    $procs--;
    no strict;
    %stuff = %{ eval "$text" };
    return(0) unless (%stuff);
    my @items = @{$stuff{nicks}};
    my %channel;
    foreach (@items) {
	my %location = %{$_};
	if (not %location) {
	    unless ($query =~ /$channel_prefix/) {
		print CLIENTCRAP '%R>>%n Unable to localize '.$query if ($auto eq '');
	    }
	} else {
	    my $nocache = Irssi::settings_get_str('localize_ipatlas_nocache');
	    add_to_cache(%location) unless ($location{'map'} eq 'IP-Atlas' && $location{'host'} =~ /$nocache/);
	    
	    $location{$_} = $location{$_} foreach (keys %location);
	    my $nick = $location{'nick'};
	    if ($query =~ /$channel_prefix/) {
		push @{ $channel{$location{"country"}}{$location{"province"}}{$location{"city"}} }, [$nick, $location{"map"}];
	    } else {
		if ($auto eq '') {
		    show_location(%location);
		} else {
		    auto_localize($auto, %location);
		}
	    }
	    #remove_request($query);
	}
    }
    if ($query =~ /$channel_prefix/) {
	show_cities($query, %channel);
    }
}

sub add_to_cache (%) {
    my (%location) = @_;
    my $host = $location{'host'};
    return if defined $cache{$host};
    foreach (keys %location) {
	next if ($_ eq 'nick' || $_ eq 'host');
	$cache{$host}{$_} = $location{$_};
    }
}

sub save_cache {
    my $filename = Irssi::settings_get_str('localize_cache_filename');
    my $data = Dumper(\%cache);
    local *F;
    open(F, '>'.$filename);
    print(F $data);
    close(F);
    print CLIENTCRAP "%R>>%n localize cache (".scalar(keys(%cache))." entries/".length($data)." bytes) saved to ".$filename;
}

sub load_cache {
    no strict;
    my $filename = Irssi::settings_get_str('localize_cache_filename');
    my (%new_cache, $text);
    local *F;
    open F, "<".$filename || return;
    $text .= $_ foreach (<F>);
    close(F);
    eval { %new_cache = %{ eval "$text" }; };
    foreach (keys %new_cache) {
	$cache{$_} = $new_cache{$_} unless defined $cache{$_};
    }
    print CLIENTCRAP "%R>>%n localize cache (".scalar(keys %new_cache)." hosts) loaded";
}

sub clear_cache {
    foreach (keys(%cache)) {
	delete $cache{$_};
    }
    print CLIENTCRAP "%R>>%n localize cache cleared";
}

sub show_location (%) {
    my (%location) = @_;
    my $query = Irssi::query_find($location{"nick"});
    my $output = \&Irssi::print;
    $output = sub { $query->print(@_); } if ($query);
    my $text = "";
    my $headline = '%R,--[%n%9%ULocation of '.$location{"nick"}." (".$location{"host"}.")%U%9%R]%n";
    foreach ('Country', 'Province', 'City', 'Provider') {
	my $fill = ' 'x(9-length($_));
	$text .= '%B'.$fill.$_.':%n '.$location{lc $_}."\n" if defined $location{lc $_};
    }
    #$text .= $location{latitude}."/".$location{longitude};
    &$output(draw_box('Location of '.$location{nick}.' ('.$location{host}.')', $text, $location{map}), MSGLEVEL_CLIENTCRAP);
    show_map($location{latitude}, $location{longitude}, $location{nick}) if Irssi::settings_get_bool('localize_xplanet_show_map');
}

sub show_map ($$$) {
    my ($lat, $long, $nick) = @_;
    return unless defined $lat && defined $long;
    my $cmd = Irssi::settings_get_str('localize_xplanet_cmd');
    my $file = Irssi::settings_get_str('localize_xplanet_temp_file');
    local *F;
    open F, '>'.$file;
    print F $lat.'	'.$long.'	"'.$nick.'"';
    close F;
    system("$cmd -markerf $file &");
}

sub show_cities ($%) {
    my ($channel, %cities) = @_;
    print CLIENTCRAP "%R,---[%n%9%U".$channel."%U%9%R]%n";
    foreach (sort keys %cities) {
	print CLIENTCRAP "%R+-+[%n".$_."%R]%n";
	print CLIENTCRAP "%R| | %n";
	my $n_provs = scalar( keys %{$cities{$_}});
	foreach my $province (sort keys %{$cities{$_}}) {
	    my $cp = '|';
	    $cp = ' ' if ($n_provs == 1);
	    print CLIENTCRAP "%R| +-+%n"."%R[%n".$province."%R]%n";
	    my $n_cities = scalar(keys %{$cities{$_}{$province}});
	    foreach my $city (sort keys %{$cities{$_}{$province}}) {
		my $cc = '|';
		$cc = ' ' if ($n_cities == 1);
		print CLIENTCRAP "%R| $cp +-+%n"."%R[%n".$city."%R]%n";
		my $n_nicks = scalar(@{$cities{$_}{$province}{$city}});
		foreach my $nick (sort @{$cities{$_}{$province}{$city}}) {
		    my $cn = '|`';
		    $cn = '`-' if ($n_nicks == 1);
		    print CLIENTCRAP "%R| $cp $cc $cn-----%n%B[%n".$nick->[0]."%B]%n";
		    $n_nicks--;
		}
		$n_cities--;
	    }
	    print CLIENTCRAP "%R| $cp ";
	    $n_provs--;
	}
	#print CLIENTCRAP "%R|    ";
    }
    print CLIENTCRAP "%R`----->%n";
}


sub cmd_localize ($$$) {
    my ($args, $server, $witem) = @_;
    my @names = split(/ /, $args);
    foreach (@names) {
	if ( substr($_, 0, 1) eq '@' ) {
	    my $ip = substr(lc($_), 1);
	    new_request($server, $ip, 2, '');
	    localize([[$ip, $ip]], $ip);
	} elsif ($_ eq '-h') {
	    show_help();
	} elsif ($_ eq '-c') {
	    clear_cache();
	} elsif ($_ eq '-s') {
	    save_cache();
	} elsif ($_ eq '-r') {
	    load_cache();
	} elsif ($_ eq '-sc') {
	    show_cache(@names);
	    return();
	} else {
	    new_request($server, lc($_), 0, '');
	}
    }
}

sub show_cache (@) {
    my (@params) = @_;
    unless (defined $params[1] && $params[1] eq '-i_am_insane') {
	my $entries = scalar(keys(%cache));
	print CLIENTCRAP '%R>>%n There are '.$entries.' saved locations in the cache. If you really want to display them all, type /localize -sc -i_am_insane';
    } else {
	my $text = "";
	foreach my $key (sort keys %cache) {
	    my %item = %{$cache{$key}};
	    $item{$_} = $item{$_} foreach (keys %item);
	    my $string .= $key;
	    foreach ('country', 'province', 'city', 'map') {
		$string .= ' | '.$item{$_};
	    }
	    $text .= $string."\n";
	}
	print CLIENTCRAP draw_box("Localize Cache", $text, "cache listing");
    }
}

sub process_reply ($$$$) {
    my ($server, $args, $sender, $address) = @_;
    if ($args =~ /^(.*?) (.*?) (.*?) (.*?) (.*?) (.*?) (.*?)/) {
	if (defined $queries{lc $6} && scalar(@{$queries{lc $6}}) > 0) {
	    foreach (@{$queries{lc $6}}) {
		my %query = %{$_};
		next unless ($query{status} <2);
		Irssi::signal_stop();
		push @{${$_}{buffer}},[$6, $4];
		${$_}{status} = 1;
	    }
	} elsif (defined $queries{lc $2} && scalar(@{$queries{lc $2}}) > 0) {
	    foreach (@{$queries{lc $2}}) {
		my %query = %{$_};
		next unless ($query{status} <2);
		Irssi::signal_stop();
		push @{${$_}{buffer}},[$6, $4];
		${$_}{status} = 1;
	    }
	}
    } elsif ($args =~ /^(.*?) (.*?) :End of (|\/)WHO list\./) {
	my ($self, $target) = ($1, $2);
	return unless (defined $queries{lc $target} && scalar(@{$queries{lc $target}}) > 0);
	my $needed = 0;
	foreach (@{$queries{lc $target}}) {
	    my %query = %{$_};
	    $needed = 1 if $query{status} < 2;
	    next unless ($query{status} == 1);
	    if ($query{status} == 1) {
		Irssi::signal_stop;
		$query{status} = 2;
		localize \@{$query{buffer}}, $target;
		delete $query{buffer};
		return();
	    }
	}
	if ($needed) {
	    Irssi::signal_stop;
	    unless ($queries{lc $target}[0]{auto} ne '') {
		print CLIENTCRAP '%R>>%n No such nick '.$target;
	    }
	    remove_request($target);
	}
    }
}

sub event_message_join ($$$$) {
    my ($server, $channel, $nick, $address) = @_;
    return() unless Irssi::settings_get_bool('localize_auto_localize_on_join');
    my $maxreq = Irssi::settings_get_int('localize_auto_localize_maxrequests');
    my $channels = Irssi::settings_get_str('localize_auto_localize_channel_list');
    if ($channel =~ /$channels/i) {
	$address =~ /(.*)@(.*)/;
	my $host = $2;
	if ($procs < $maxreq) {
	    new_request($server, $nick, 2, lc($channel));
	    localize([[lc($nick), $host]], lc($nick));
	} else {
	    #Irssi::print "%R>>%n Too many processes running";
	}
    }
}

sub event_query_created($$) {
    my ($query, $auto) = @_;
    my $nick = $query->{name};
    my $server = $query->{server};
    my $maxreq = Irssi::settings_get_int('localize_auto_localize_maxrequests');
    return(0) unless (scalar(keys %queries) < $maxreq && Irssi::settings_get_bool('localize_auto_localize_on_query'));
    $nick = substr($nick, 1) if (substr($nick, 0, 1) eq '=');
    new_request($server, $nick, 0, lc($query->{name}));
}

sub auto_localize ($%) {
    my ($auto, %location) = @_;
    my $nick = lc($location{'nick'});
    my $channel = Irssi::window_item_find($auto);
    $channel->printformat(MSGLEVEL_CLIENTCRAP, 'auto_localize', $nick, $location{host}, $location{'city'}, $location{'province'}, $location{'country'}, $location{'map'}) if defined $channel;
}

sub new_request ($$$$) {
    my ($server, $nick, $status, $auto) = @_;
    return unless ref $server;
    # 0 nothing done
    # 1 started to fetch hosts
    # 2 all hosts fetched
    push(@{$queries{lc $nick}}, {status => $status, auto=>$auto});
    $server->command('who '.lc($nick)) if $status == 0;
}

sub remove_request ($) {
    my ($nick) = @_;
    shift @{$queries{$nick}};
    delete $queries{$nick} if scalar(@{$queries{$nick}}) == 0;
}

# Yes, I know tat this i huge
sub kfz2location($) {
    my %trans = (
	"rklh"=> "RE",
	"wstk"=> "Wk",
	"essn"=> "E",
	"stgt"=> "S",
	"ffm" => "F",
	"mnz" => "MZ",
	"fra" => "F",
	"esn" => "E",
	"dtm" => "DO",
	"kln" => "K",
	"dus" => "D",
	"mue" => "M",
	"mnch"=> "M",
	"brln"=> "B",
	"hmb" => "HH",
	"brmn"=> "HB",
	"hmbg"=> "HH",
	"han" => "H",
	"kiel"=> "KI",
	"lpz" => "L",
	"bln" => "B",
	"ber" => "B",
	"mch" => "M",
	"erf" => "EF",
	"mdb" => "MD",
	"nbg" => "N",
	"hnv" => "H",
	"dui" => "DU",
	"mnhm" => "MA",
	"mhm" => "MA",
	"flf" => "FL",
	"lwhf" => "LU",
	"wue" => "WÜ",
	"frnk" => "F",
	"dsdf" => "D",
	"sgt"  => "S",
	"aug"  => "A",
	"mch"  => "M",
	"ddn"  => "DD",
	"drs" => "DD",
	"jen" => "J",
	"che" => "C",
	"nuremberg" => "N",
	"weingarten" => "RV",
	"munich" => "M",
	"muc" => "M",
	"goe" => "GÖ",
	"obhs" => "OB",
	"dus" => "D",
    );

    my %province = (
	1=>'Baden-Württemberg',
	2=>'Bayern',
	3=>'Berlin',
	4=>'Brandenburg',
	5=>'Bremen',
	6=>'Hamburg',
	7=>'Hessen',
	8=>'Mecklenburg-Vorpommern',
	9=>'Niedersachsen',
	10=>'Nordrhein-Westfalen',
	11=>'Rheinland-Pfalz',
	12=>'Saarland',
	13=>'Sachsen',
	14=>'Sachsen-Anhalt',
	15=>'Thüringen',
	16=>'Schleswig-Holstein'
    );
    
    my %added = (
	"PLA"=>{city=>"Plattling", province=>2},
    );
    my %de_kfz = (
	"A"=>{city=>"Augsburg", province=>2},
	"AA"=>{city=>"Ostalbkreis", province=>1},
	"AB"=>{city=>"Aschaffenburg", province=>2},
	"ABG"=>{city=>"Altenburger Land", province=>15},
	"AC"=>{city=>"Aachen", province=>10},
	"AE"=>{city=>"Auerbach", province=>13},
	"AH"=>{city=>"Ahaus ", province=>10},
	"AIB"=>{city=>"Bad Aibling", province=>2},
	"AIC"=>{city=>"Aichach-Friedberg", province=>2},
	"AK"=>{city=>"Altenkirchen", province=>11},
	"AL"=>{city=>"Altena", province=>10},
	"ALF"=>{city=>"Alfeld (Leine)", province=>9},
	"ALS"=>{city=>"Alsfeld", province=>7},
	"ALZ"=>{city=>"Alzenau", province=>2},
	"AM"=>{city=>"Amberg", province=>2},
	"AN"=>{city=>"Ansbach", province=>2},
	"ANA"=>{city=>"Annaberg", province=>13},
	"ANG"=>{city=>"Angermünde", province=>4},
	"ANK"=>{city=>"Ostvorpommern, Anklam", province=>8},
	"AP"=>{city=>"Weimarer-Land", province=>15},
	"APD"=>{city=>"Weimarer Land, Apolda", province=>15},
	"AR"=>{city=>"Arnsberg", province=>10},
	"ARN"=>{city=>"Ilm-Kreis", province=>15},
	"ART"=>{city=>"Artern", province=>15},
	"AS"=>{city=>"Amberg-Sulzbach", province=>2},
	"ASD"=>{city=>"Aschendorf-Hümmling", province=>9},
	"ASL"=>{city=>"Aschersleben", province=>14},
	"ASZ"=>{city=>"Aue-Schwarzenberg", province=>13},
	"AT"=>{city=>"Altentreptow", province=>8},
	"AU"=>{city=>"Aue", province=>13},
	"AUR"=>{city=>"Aurich", province=>9},
	"AW"=>{city=>"Ahrweiler", province=>11},
	"AZ"=>{city=>"Alzey", province=>11},
	"AZE"=>{city=>"Anhalt-Zerbst", province=>14},
	"AÖ"=>{city=>"Altötting", province=>2},
	"B"=>{city=>"Berlin", province=>"3"},
	"BA"=>{city=>"Bamberg", province=>2},
	"BAD"=>{city=>"Baden-Baden", province=>1},
	"BAR"=>{city=>"Barnim", province=>4},
	"BB"=>{city=>"Böblingen", province=>1},
	"BBG"=>{city=>"Bernburg", province=>14},
	"BC"=>{city=>"Biberach", province=>1},
	"BCH"=>{city=>"Buchen", province=>1},
	"BE"=>{city=>"Beckum", province=>10},
	"BED"=>{city=>"Brand-Erbisdorf", province=>13},
	"BEI"=>{city=>"Beilngries", province=>2},
	"BEL"=>{city=>"Belzig", province=>4},
	"BER"=>{city=>"Bernau", province=>4},
	"BF"=>{city=>"Burgsteinfurt", province=>10},
	"BGD"=>{city=>"Berchtesgaden", province=>2},
	"BGL"=>{city=>"Berchtesgadener Land", province=>2},
	"BH"=>{city=>"Bühl", province=>1},
	"BI"=>{city=>"Bielefeld", province=>10},
	"BID"=>{city=>"Biedenkopf", province=>7},
	"BIN"=>{city=>"Bingen", province=>11},
	"BIR"=>{city=>"Birkenfeld", province=>11},
	"BIT"=>{city=>"Bitburg", province=>11},
	"BIW"=>{city=>"Bischofswerda", province=>13},
	"BK"=>{city=>"Backnang", province=>1},
	"BKS"=>{city=>"Bernkastel", province=>11},
	"BL"=>{city=>"Zollernalbkreis", province=>1},
	"BLB"=>{city=>"Bad Berleburg", province=>10},
	"BLK"=>{city=>"Burgenlandkreis", province=>14},
	"BM"=>{city=>"Erftkreis", province=>10},
	"BN"=>{city=>"Bonn", province=>10},
	"BNA"=>{city=>"Borna", province=>13},
	"BO"=>{city=>"Bochum", province=>10},
	"BOG"=>{city=>"Bogen", province=>2},
	"BOH"=>{city=>"Bocholt", province=>10},
	"BOR"=>{city=>"Borken", province=>10},
	"BOT"=>{city=>"Bottrop", province=>10},
	"BR"=>{city=>"Bruchsal", province=>1},
	"BRA"=>{city=>"Wesermarsch", province=>9},
	"BRB"=>{city=>"Brandenburg", province=>4},
	"BRG"=>{city=>"Burg", province=>14},
	"BRI"=>{city=>"Brilon", province=>10},
	"BRK"=>{city=>"Bad Brückenau", province=>2},
	"BRL"=>{city=>"Braunlage", province=>9},
	"BRV"=>{city=>"Bremervörde", province=>9},
	"BS"=>{city=>"Braunschweig", province=>9},
	"BSB"=>{city=>"Bersenbrück", province=>9},
	"BSK"=>{city=>"Beeskow", province=>4},
	"BT"=>{city=>"Bayreuth", province=>2},
	"BTF"=>{city=>"Bitterfeld", province=>14},
	"BU"=>{city=>"Burgdorf", province=>9},
	"BUL"=>{city=>"Burglengenfeld", province=>2},
	"BZ"=>{city=>"Bautzen", province=>13},
	"BZA"=>{city=>"Bergzabern", province=>11},
	"BÖ"=>{city=>"Bördekreis", province=>14},
	"BÜD"=>{city=>"Büdingen", province=>7},
	"BÜR"=>{city=>"Büren", province=>10},
	"BÜS"=>{city=>"Büsingen", province=>1},
	"BÜZ"=>{city=>"Bützow", province=>8},
	"C"=>{city=>"Chemnitz", province=>13},
	"CA"=>{city=>"Calau", province=>4},
	"CAS"=>{city=>"Castrop-Rauxel", province=>10},
	"CB"=>{city=>"Cottbus", province=>4},
	"CE"=>{city=>"Celle", province=>9},
	"CHA"=>{city=>"Cham", province=>2},
	"CLP"=>{city=>"Cloppenburg", province=>9},
	"CLZ"=>{city=>"Clausthal-Zellerfeld", province=>9},
	"CO"=>{city=>"Coburg", province=>2},
	"COC"=>{city=>"Cochem-Zell", province=>11},
	"COE"=>{city=>"Coesfeld", province=>10},
	"CR"=>{city=>"Crailsheim", province=>1},
	"CUX"=>{city=>"Cuxhaven", province=>9},
	"CW"=>{city=>"Calw", province=>1},
	"D"=>{city=>"Düsseldorf", province=>10},
	"DA"=>{city=>"Darmstadt", province=>7},
	"DAH"=>{city=>"Dachau ", province=>2},
	"DAN"=>{city=>"Lüchow-Dannenberg", province=>9},
	"DAU"=>{city=>"Daun", province=>11},
	"DBR"=>{city=>"Bad Doberan", province=>8},
	"DD"=>{city=>"Dresden", province=>13},
	"DE"=>{city=>"Dessau", province=>14},
	"DEG"=>{city=>"Deggendorf", province=>2},
	"DEL"=>{city=>"Delmenhorst", province=>9},
	"DGF"=>{city=>"Dingolfing-Landau", province=>2},
	"DH"=>{city=>"Diepholz", province=>9},
	"DI"=>{city=>"Dieburg", province=>7},
	"DIL"=>{city=>"Dillenburg", province=>7},
	"DIN"=>{city=>"Dinslaken", province=>10},
	"DIZ"=>{city=>"Diez", province=>11},
	"DKB"=>{city=>"Dinkelsbühl", province=>2},
	"DL"=>{city=>"Döbeln", province=>13},
	"DLG"=>{city=>"Dillingen a. d. Donau", province=>2},
	"DM"=>{city=>"Demmin", province=>8},
	"DN"=>{city=>"Düren", province=>10},
	"DO"=>{city=>"Dortmund", province=>10},
	"DON"=>{city=>"Donau-Ries", province=>2},
	"DS"=>{city=>"Donaueschingen", province=>1},
	"DT"=>{city=>"Detmold", province=>10},
	"DU"=>{city=>"Duisburg", province=>10},
	"DUD"=>{city=>"Duderstadt", province=>9},
	"DW"=>{city=>"Weißeritzkreis", province=>13},
	"DZ"=>{city=>"Delitzsch", province=>13},
	"DÜW"=>{city=>"Bad Dürkheim", province=>11},
	"E"=>{city=>"Essen", province=>10},
	"EA"=>{city=>"Eisenach, Stadt", province=>15},
	"EB"=>{city=>"Eilenburg", province=>13},
	"EBE"=>{city=>"Ebersberg", province=>2},
	"EBN"=>{city=>"Ebern", province=>2},
	"EBS"=>{city=>"Ebermannstadt", province=>2},
	"ECK"=>{city=>"Eckernförde", province=>16},
	"ED"=>{city=>"Erding", province=>2},
	"EE"=>{city=>"Elbe-Elster", province=>4},
	"EF"=>{city=>"Erfurt", province=>15},
	"EG"=>{city=>"Eggenfelden", province=>2},
	"EH"=>{city=>"Eisenhüttenstadt", province=>4},
	"EHI"=>{city=>"Ehingen", province=>1},
	"EI"=>{city=>"Eichstätt", province=>2},
	"EIC"=>{city=>"Eichsfeld", province=>15},
	"EIH"=>{city=>"Eichstätt-Kreis", province=>2},
	"EIL"=>{city=>"Eisleben", province=>14},
	"EIN"=>{city=>"Einbeck", province=>9},
	"EIS"=>{city=>"Saale-Holzlandkreis, Eisenberg", province=>15},
	"EL"=>{city=>"Emsland", province=>9},
	"EM"=>{city=>"Emmendingen", province=>1},
	"EMD"=>{city=>"Emden", province=>9},
	"EMS"=>{city=>"Rhein-Lahn-Kreis", province=>11},
	"EN"=>{city=>"Ennepe-Ruhr-Kreis", province=>10},
	"ER"=>{city=>"Erlangen", province=>2},
	"ERB"=>{city=>"Odenwaldkreis", province=>7},
	"ERH"=>{city=>"Erlangen-Höchstadt", province=>2},
	"ERK"=>{city=>"Erkelenz", province=>10},
	"ES"=>{city=>"Esslingen", province=>1},
	"ESA"=>{city=>"Eisenach", province=>15},
	"ESB"=>{city=>"Eschenbach i.d.Oberpfalz", province=>2},
	"ESW"=>{city=>"Werra-Meißner-Kreis", province=>7},
	"EU"=>{city=>"Euskirchen", province=>10},
	"EUT"=>{city=>"Eutin", province=>16},
	"EW"=>{city=>"Eberswalde", province=>4},
	"F"=>{city=>"Frankfurt am Main", province=>7},
	"FAL"=>{city=>"Fallingbostel", province=>9},
	"FB"=>{city=>"Wetteraukreis", province=>7},
	"FD"=>{city=>"Fulda", province=>7},
	"FDB"=>{city=>"Friedberg", province=>2},
	"FDS"=>{city=>"Freudenstadt", province=>1},
	"FEU"=>{city=>"Feuchtwangen", province=>2},
	"FF"=>{city=>"Frankfurt / Oder", province=>4},
	"FFB"=>{city=>"Fürstenfeldbruck", province=>2},
	"FG"=>{city=>"Freiberg", province=>13},
	"FH"=>{city=>"Frankfurt / Main-Höchst", province=>7},
	"FI"=>{city=>"Finsterwalde", province=>4},
	"FKB"=>{city=>"Frankenberg", province=>7},
	"FL"=>{city=>"Flensburg", province=>16},
	"FLÖ"=>{city=>"Flöha", province=>13},
	"FN"=>{city=>"Bodenseekreis", province=>1},
	"FO"=>{city=>"Forchheim", province=>2},
	"FOR"=>{city=>"Forst", province=>4},
	"FR"=>{city=>"Freiburg", province=>1},
	"FRG"=>{city=>"Freyung-Grafenau", province=>2},
	"FRI"=>{city=>"Friesland", province=>9},
	"FRW"=>{city=>"Bad Freienwalde", province=>4},
	"FS"=>{city=>"Freising", province=>2},
	"FT"=>{city=>"Frankenthal", province=>11},
	"FTL"=>{city=>"Freital", province=>13},
	"FW"=>{city=>"Fürstenwalde", province=>4},
	"FZ"=>{city=>"Fritzlar", province=>7},
	"FÜ"=>{city=>"Fürth", province=>2},
	"FÜS"=>{city=>"Füssen", province=>2},
	"G"=>{city=>"Gera", province=>15},
	"GA"=>{city=>"Gardelegen", province=>14},
	"GAN"=>{city=>"Bad Gandersheim", province=>9},
	"GAP"=>{city=>"Garmisch-Partenkirchen", province=>2},
	"GC"=>{city=>"Chemnitzer Land", province=>13},
	"GD"=>{city=>"Schwäbisch Gmünd", province=>1},
	"GDB"=>{city=>"Gadebusch", province=>8},
	"GE"=>{city=>"Gelsenkirchen", province=>10},
	"GEL"=>{city=>"Geldern", province=>10},
	"GEM"=>{city=>"Gemünden a.Main", province=>2},
	"GEO"=>{city=>"Gerolzhofen", province=>2},
	"GER"=>{city=>"Germersheim", province=>11},
	"GF"=>{city=>"Gifhorn", province=>9},
	"GG"=>{city=>"Groß-Gerau", province=>7},
	"GHA"=>{city=>"Geithain", province=>13},
	"GHC"=>{city=>"Gräfenhainichen", province=>14},
	"GI"=>{city=>"Gießen", province=>7},
	"GK"=>{city=>"Geilenkirchen-Heinsberg", province=>10},
	"GL"=>{city=>"Rheinisch-Bergischer Kreis", province=>10},
	"GLA"=>{city=>"Gladbeck", province=>10},
	"GM"=>{city=>"Oberbergischer Kreis", province=>10},
	"GMN"=>{city=>"Grimmen", province=>8},
	"GN"=>{city=>"Gelnhausen", province=>7},
	"GNT"=>{city=>"Genthin", province=>14},
	"GOA"=>{city=>"St. Goar", province=>11},
	"GOH"=>{city=>"St. Goarshausen", province=>11},
	"GP"=>{city=>"Göppingen", province=>1},
	"GR"=>{city=>"Görlitz", province=>13},
	"GRA"=>{city=>"Grafenau", province=>2},
	"GRH"=>{city=>"Großenhain", province=>13},
	"GRI"=>{city=>"Griesbach i. Rottal", province=>2},
	"GRM"=>{city=>"Grimma", province=>13},
	"GRS"=>{city=>"Gransee", province=>4},
	"GRZ"=>{city=>"Greiz", province=>15},
	"GS"=>{city=>"Goslar", province=>9},
	"GT"=>{city=>"Gütersloh", province=>10},
	"GTH"=>{city=>"Gotha", province=>15},
	"GUB"=>{city=>"Guben", province=>4},
	"GUN"=>{city=>"Gunzenhausen", province=>2},
	"GV"=>{city=>"Grevenbroich", province=>10},
	"GVM"=>{city=>"Grevesmühlen", province=>8},
	"GW"=>{city=>"Greifswald Land", province=>8},
	"GZ"=>{city=>"Günzburg", province=>2},
	"GÖ"=>{city=>"Göttingen", province=>9},
	"GÜ"=>{city=>"Güstrow", province=>8},
	"H"=>{city=>"Hannover", province=>9},
	"HA"=>{city=>"Hagen", province=>10},
	"HAB"=>{city=>"Hammelburg", province=>2},
	"HAL"=>{city=>"Halle", province=>14},
	"HAM"=>{city=>"Hamm", province=>10},
	"HAS"=>{city=>"Haßberge", province=>2},
	"HB"=>{city=>"Bremen", province=>5},
	"HBN"=>{city=>"Hildburghausen", province=>15},
	"HBS"=>{city=>"Halberstadt", province=>14},
	"HC"=>{city=>"Hainichen", province=>13},
	"HCH"=>{city=>"Hechingen", province=>1},
	"HD"=>{city=>"Rhein-Neckar-Kreis", province=>1},
	"HDH"=>{city=>"Heidenheim (Brenz)", province=>1},
	"HDL"=>{city=>"Haldensleben", province=>14},
	"HE"=>{city=>"Helmstedt", province=>9},
	"HEB"=>{city=>"Hersbruck", province=>2},
	"HEF"=>{city=>"Hersfeld-Rotenburg", province=>7},
	"HEI"=>{city=>"Dithmarschen", province=>16},
	"HER"=>{city=>"Herne", province=>10},
	"HET"=>{city=>"Hettstedt", province=>14},
	"HF"=>{city=>"Herford", province=>10},
	"HG"=>{city=>"Hochtaunus-Kreis", province=>7},
	"HGN"=>{city=>"Hagenow", province=>8},
	"HGW"=>{city=>"Greifswald", province=>8},
	"HH"=>{city=>"Hamburg", province=>6},
	"HHM"=>{city=>"Hohenmölsen", province=>14},
	"HI"=>{city=>"Hildesheim", province=>9},
	"HIG"=>{city=>"Eichsfeld, Heiligenstadt", province=>15},
	"HIP"=>{city=>"Hilpoltstein", province=>2},
	"HL"=>{city=>"Lübeck", province=>16},
	"HM"=>{city=>"Hameln-Pyrmont", province=>9},
	"HMÜ"=>{city=>"Hann. Münden", province=>9},
	"HN"=>{city=>"Heilbronn", province=>1},
	"HO"=>{city=>"Hof", province=>2},
	"HOG"=>{city=>"Hofgeismar", province=>7},
	"HOH"=>{city=>"Hofheim i. Ufr.", province=>2},
	"HOL"=>{city=>"Holzminden", province=>9},
	"HOM"=>{city=>"Saarpfalz-Kreis", province=>12},
	"HOR"=>{city=>"Horb", province=>1},
	"HOT"=>{city=>"Hohenstein-Ernstthal", province=>13},
	"HP"=>{city=>"Bergstraße", province=>7},
	"HR"=>{city=>"Schwalm-Eder-Kreis", province=>7},
	"HRO"=>{city=>"Rostock", province=>8},
	"HS"=>{city=>"Heinsberg", province=>10},
	"HSK"=>{city=>"Hochsauerland-Kreis", province=>10},
	"HST"=>{city=>"Stralsund", province=>8},
	"HU"=>{city=>"Main-Kinzig-Kreis", province=>7},
	"HUS"=>{city=>"Husum", province=>16},
	"HV"=>{city=>"Havelberg", province=>14},
	"HVL"=>{city=>"Havelland", province=>4},
	"HW"=>{city=>"Halle/Westfalen", province=>10},
	"HWI"=>{city=>"Wismar", province=>8},
	"HX"=>{city=>"Höxter", province=>10},
	"HY"=>{city=>"Hoyerswerda", province=>13},
	"HZ"=>{city=>"Herzberg", province=>4},
	"HÖS"=>{city=>"Höchstadt a. d. Aisch", province=>2},
	"HÜN"=>{city=>"Hünfeld", province=>7},
	"IGB"=>{city=>"St. Ingbert", province=>12},
	"IK"=>{city=>"Ilm-Kreis", province=>15},
	"IL"=>{city=>"Ilmenau", province=>15},
	"ILL"=>{city=>"Illertissen", province=>2},
	"IN"=>{city=>"Ingolstadt", province=>2},
	"IS"=>{city=>"Iserlohn", province=>10},
	"IZ"=>{city=>"Steinburg", province=>16},
	"J"=>{city=>"Jena", province=>15},
	"JB"=>{city=>"Jüterbog", province=>4},
	"JE"=>{city=>"Jessen", province=>14},
	"JEV"=>{city=>"Jever", province=>9},
	"JL"=>{city=>"Jerichower Land", province=>14},
	"JÜL"=>{city=>"Jülich", province=>10},
	"K"=>{city=>"Köln", province=>10},
	"KA"=>{city=>"Karlsruhe", province=>1},
	"KAR"=>{city=>"Karlstadt", province=>2},
	"KB"=>{city=>"Waldeck-Frankenberg", province=>7},
	"KC"=>{city=>"Kronach", province=>2},
	"KE"=>{city=>"Kempten", province=>2},
	"KEH"=>{city=>"Kelheim", province=>2},
	"KEL"=>{city=>"Kehl", province=>1},
	"KEM"=>{city=>"Kemnath", province=>2},
	"KF"=>{city=>"Kaufbeuren", province=>2},
	"KG"=>{city=>"Bad Kissingen", province=>2},
	"KH"=>{city=>"Bad Kreuznach", province=>11},
	"KI"=>{city=>"Kiel", province=>16},
	"KIB"=>{city=>"Donnersberg-Kreis", province=>11},
	"KK"=>{city=>"Kempen-Krefeld", province=>10},
	"KL"=>{city=>"Kaiserslautern", province=>11},
	"KLE"=>{city=>"Kleve", province=>10},
	"KLZ"=>{city=>"Klötze", province=>14},
	"KM"=>{city=>"Kamenz", province=>13},
	"KN"=>{city=>"Konstanz", province=>1},
	"KO"=>{city=>"Koblenz", province=>11},
	"KR"=>{city=>"Krefeld", province=>10},
	"KRU"=>{city=>"Krumbach", province=>2},
	"KS"=>{city=>"Kassel", province=>7},
	"KT"=>{city=>"Kitzingen", province=>2},
	"KU"=>{city=>"Kulmbach", province=>2},
	"KUS"=>{city=>"Kusel", province=>11},
	"KW"=>{city=>"Königs-Wusterhausen", province=>4},
	"KY"=>{city=>"Kyritz", province=>4},
	"KYF"=>{city=>"Kyffhäuserkreis", province=>15},
	"KÖN"=>{city=>"Bad Königshofen i. Grabfeld", province=>2},
	"KÖT"=>{city=>"Köthen", province=>14},
	"KÖZ"=>{city=>"Kötzting", province=>2},
	"KÜN"=>{city=>"Hohenlohekreis", province=>1},
	"L"=>{city=>"Leipzig / Leipziger Land", province=>13},
	"LA"=>{city=>"Landshut", province=>2},
	"LAN"=>{city=>"Landau a.d.Isar", province=>2},
	"LAT"=>{city=>"Lauterbach", province=>7},
	"LAU"=>{city=>"Nürnberger Land", province=>2},
	"LB"=>{city=>"Ludwigsburg", province=>1},
	"LBS"=>{city=>"Lobenstein", province=>15},
	"LBZ"=>{city=>"Lübz", province=>8},
	"LC"=>{city=>"Luckau", province=>4},
	"LD"=>{city=>"Landau i. d. Pfalz", province=>11},
	"LDK"=>{city=>"Lahn-Dill-Kreis", province=>7},
	"LDS"=>{city=>"Dahme-Spreewald", province=>4},
	"LE"=>{city=>"Lemgo", province=>10},
	"LEO"=>{city=>"Leonberg", province=>1},
	"LER"=>{city=>"Leer", province=>9},
	"LEV"=>{city=>"Leverkusen", province=>10},
	"LF"=>{city=>"Laufen", province=>2},
	"LG"=>{city=>"Lüneburg", province=>9},
	"LH"=>{city=>"Lüdinghausen", province=>10},
	"LI"=>{city=>"Lindau", province=>2},
	"LIB"=>{city=>"Bad Liebenwerda", province=>4},
	"LIF"=>{city=>"Lichtenfels", province=>2},
	"LIN"=>{city=>"Lingen", province=>9},
	"LIP"=>{city=>"Lippe", province=>10},
	"LK"=>{city=>"Lübbecke", province=>10},
	"LL"=>{city=>"Landsberg am Lech", province=>2},
	"LM"=>{city=>"Limburg-Weilburg", province=>7},
	"LN"=>{city=>"Lübben", province=>4},
	"LOH"=>{city=>"Lohr a.Main", province=>2},
	"LOS"=>{city=>"Oder-Spree", province=>4},
	"LP"=>{city=>"Lippstadt", province=>10},
	"LR"=>{city=>"Lahr", province=>1},
	"LSZ"=>{city=>"Bad Langensalza", province=>15},
	"LU"=>{city=>"Ludwigshafen", province=>11},
	"LUK"=>{city=>"Luckenwalde", province=>4},
	"LWL"=>{city=>"Ludwigslust", province=>8},
	"LÖ"=>{city=>"Lörrach", province=>1},
	"LÖB"=>{city=>"Löbau", province=>13},
	"LÜD"=>{city=>"Lüdenscheid, Stadt", province=>10},
	"LÜN"=>{city=>"Lünen", province=>10},
	"M"=>{city=>"München", province=>2},
	"MA"=>{city=>"Mannheim", province=>1},
	"MAB"=>{city=>"Marienberg", province=>13},
	"MAI"=>{city=>"Mainburg", province=>2},
	"MAK"=>{city=>"Marktredwitz", province=>2},
	"MAL"=>{city=>"Mallersdorf", province=>2},
	"MAR"=>{city=>"Marktheidenfeld", province=>2},
	"MB"=>{city=>"Miesbach", province=>2},
	"MC"=>{city=>"Malchin", province=>8},
	"MD"=>{city=>"Magdeburg", province=>14},
	"ME"=>{city=>"Mettmann", province=>10},
	"MED"=>{city=>"Meldorf /Suderdithmarschen", province=>16},
	"MEG"=>{city=>"Melsungen", province=>7},
	"MEI"=>{city=>"Meißen", province=>13},
	"MEK"=>{city=>"Mittlerer Erzgebirgskreis", province=>13},
	"MEL"=>{city=>"Melle", province=>9},
	"MEP"=>{city=>"Meppen", province=>9},
	"MER"=>{city=>"Merseburg", province=>14},
	"MES"=>{city=>"Meschede", province=>10},
	"MET"=>{city=>"Mellrichstadt", province=>2},
	"MG"=>{city=>"Mönchengladbach", province=>10},
	"MGH"=>{city=>"Bad Mergentheim", province=>1},
	"MGN"=>{city=>"Meiningen", province=>15},
	"MH"=>{city=>"Mülheim an der Ruhr", province=>"Nordrhein-Westfalen."},
	"MHL"=>{city=>"Unstrut-Hainich-Kreis, Mühlhausen", province=>15},
	"MI"=>{city=>"Minden", province=>10},
	"MIL"=>{city=>"Miltenberg", province=>2},
	"MK"=>{city=>"Märkischer Kreis", province=>10},
	"ML"=>{city=>"Mansfelder Land", province=>14},
	"MM"=>{city=>"Memmingen", province=>2},
	"MN"=>{city=>"Unterallgäu", province=>2},
	"MO"=>{city=>"Moers", province=>10},
	"MOD"=>{city=>"Marktoberdorf", province=>2},
	"MOL"=>{city=>"Märkisch-Oderland", province=>4},
	"MON"=>{city=>"Monschau", province=>10},
	"MOS"=>{city=>"Neckar-Odenwald-Kreis", province=>1},
	"MQ"=>{city=>"Merseburg-Querfurt", province=>14},
	"MR"=>{city=>"Marburg-Biedenkopf", province=>7},
	"MS"=>{city=>"Münster", province=>10},
	"MSP"=>{city=>"Main-Spessart", province=>2},
	"MST"=>{city=>"Mecklenburg-Strelitz", province=>8},
	"MT"=>{city=>"Montabaur", province=>11},
	"MTK"=>{city=>"Main-Taunus-Kreis", province=>7},
	"MTL"=>{city=>"Muldentalkreis", province=>13},
	"MW"=>{city=>"Mittweida", province=>13},
	"MY"=>{city=>"Mayen", province=>11},
	"MYK"=>{city=>"Mayen-Koblenz", province=>11},
	"MZ"=>{city=>"Mainz (-Bingen)", province=>11},
	"MZG"=>{city=>"Merzig-Saar", province=>12},
	"MÜ"=>{city=>"Mühldorf am Inn", province=>2},
	"MÜB"=>{city=>"Münchberg", province=>2},
	"MÜL"=>{city=>"Müllheim", province=>1},
	"MÜN"=>{city=>"Münsingen", province=>1},
	"MÜR"=>{city=>"Müritz", province=>8},
	"N"=>{city=>"Nürnberg", province=>2},
	"NAB"=>{city=>"Nabburg", province=>2},
	"NAI"=>{city=>"Naila", province=>2},
	"NAU"=>{city=>"Nauen", province=>4},
	"NB"=>{city=>"Neubrandenburg", province=>8},
	"ND"=>{city=>"Neuburg-Schrobenhausen", province=>2},
	"NDH"=>{city=>"Nordhausen", province=>15},
	"NE"=>{city=>"Neuss", province=>10},
	"NEA"=>{city=>"Neustadt a. d. Aisch", province=>2},
	"NEB"=>{city=>"Nebra", province=>14},
	"NEC"=>{city=>"Neustadt b.Coburg", province=>2},
	"NEN"=>{city=>"Neunburg vorm Wald", province=>2},
	"NES"=>{city=>"Rhön-Grabfeld", province=>2},
	"NEU"=>{city=>"Titisee-Neustadt im Schwarzwald", province=>1},
	"NEW"=>{city=>"Neustadt an der Waldnaab", province=>2},
	"NF"=>{city=>"Nordfriesland", province=>16},
	"NH"=>{city=>"Neuhaus am Rennweg", province=>15},
	"NI"=>{city=>"Nienburg", province=>9},
	"NIB"=>{city=>"Niebüll", province=>16},
	"NK"=>{city=>"Neunkirchen", province=>12},
	"NM"=>{city=>"Neumarkt", province=>2},
	"NMB"=>{city=>"Naumburg", province=>14},
	"NMS"=>{city=>"Neumünster", province=>16},
	"NOH"=>{city=>"Bentheim", province=>9},
	"NOL"=>{city=>"Niederschlesische Oberlausitz", province=>13},
	"NOM"=>{city=>"Northeim", province=>9},
	"NOR"=>{city=>"Norden", province=>9},
	"NP"=>{city=>"Neuruppin", province=>4},
	"NR"=>{city=>"Neuwied", province=>11},
	"NRÜ"=>{city=>"Neustadt a.Rübenberge", province=>9},
	"NT"=>{city=>"Nürtingen", province=>1},
	"NU"=>{city=>"Neu-Ulm", province=>2},
	"NVP"=>{city=>"Nordvorpommern", province=>8},
	"NW"=>{city=>"Neustadt a. d. Weinstraße", province=>11},
	"NWM"=>{city=>"Nordwestmecklenburg", province=>8},
	"NY"=>{city=>"Niesky", province=>13},
	"NZ"=>{city=>"Neustrelitz", province=>8},
	"NÖ"=>{city=>"Nördlingen", province=>2},
	"OA"=>{city=>"Oberallgäu", province=>2},
	"OAL"=>{city=>"Ostallgäu", province=>2},
	"OB"=>{city=>"Oberhausen", province=>10},
	"OBB"=>{city=>"Obernburg a. Main", province=>2},
	"OBG"=>{city=>"Osterburg", province=>14},
	"OC"=>{city=>"Oschersleben", province=>14},
	"OCH"=>{city=>"Ochsenfurt", province=>2},
	"OD"=>{city=>"Stormarn", province=>16},
	"OE"=>{city=>"Olpe", province=>10},
	"OF"=>{city=>"Offenbach", province=>7},
	"OG"=>{city=>"Ortenaukreis", province=>1},
	"OH"=>{city=>"Ostholstein", province=>16},
	"OHA"=>{city=>"Osterode am Harz", province=>9},
	"OHV"=>{city=>"Oberhavel", province=>4},
	"OHZ"=>{city=>"Osterholz-Scharmbeck", province=>9},
	"OK"=>{city=>"Ohre-Kreis", province=>14},
	"OL"=>{city=>"Oldenburg", province=>9},
	"OLD"=>{city=>"Oldenburg/Holstein", province=>16},
	"OP"=>{city=>"Opladen", province=>10},
	"OPR"=>{city=>"Ostprignitz-Ruppin", province=>4},
	"OR"=>{city=>"Oranienburg", province=>4},
	"OS"=>{city=>"Osnabrück", province=>9},
	"OSL"=>{city=>"Oberspreewald-Lausitz", province=>4},
	"OTT"=>{city=>"Otterndorf", province=>9},
	"OTW"=>{city=>"Ottweiler", province=>12},
	"OVI"=>{city=>"Oberviechtach", province=>2},
	"OVL"=>{city=>"Obervogtland", province=>13},
	"OVP"=>{city=>"Ostvorpommern", province=>8},
	"OZ"=>{city=>"Oschatz", province=>13},
	"ÖHR"=>{city=>"Öhringen", province=>1},
	"P"=>{city=>"Potsdam", province=>4},
	"PA"=>{city=>"Passau", province=>2},
	"PAF"=>{city=>"Pfaffenhofen", province=>2},
	"PAN"=>{city=>"Rottal-Inn", province=>2},
	"PAR"=>{city=>"Parsberg", province=>2},
	"PB"=>{city=>"Paderborn", province=>10},
	"PCH"=>{city=>"Parchim", province=>8},
	"PE"=>{city=>"Peine", province=>9},
	"PEG"=>{city=>"Pegnitz", province=>2},
	"PER"=>{city=>"Perleberg", province=>4},
	"PF"=>{city=>"Pforzheim / Enzkreis", province=>1},
	"PI"=>{city=>"Pinneberg", province=>16},
	"PIR"=>{city=>"Sächsische Schweiz", province=>13},
	"PK"=>{city=>"Pritzwalk", province=>4},
	"PL"=>{city=>"Plauen", province=>13},
	"PLÖ"=>{city=>"Plön", province=>16},
	"PM"=>{city=>"Potsdam-Mittelmark", province=>4},
	"PN"=>{city=>"Pößneck", province=>15},
	"PR"=>{city=>"Prignitz", province=>4},
	"PRÜ"=>{city=>"Prüm", province=>11},
	"PS"=>{city=>"Pirmasens / Südwestpfalz", province=>11},
	"PW"=>{city=>"Pasewalk", province=>8},
	"PZ"=>{city=>"Prenzlau", province=>4},
	"QFT"=>{city=>"Querfurt", province=>14},
	"QLB"=>{city=>"Quedlinburg", province=>14},
	"R"=>{city=>"Regensburg", province=>2},
	"RA"=>{city=>"Rastatt", province=>1},
	"RC"=>{city=>"Reichenbach", province=>13},
	"RD"=>{city=>"Rendsburg-Eckernförde", province=>16},
	"RDG"=>{city=>"Ribnitz-Damgarten", province=>8},
	"RE"=>{city=>"Recklinghausen", province=>10},
	"REG"=>{city=>"Regen", province=>2},
	"REH"=>{city=>"Rehau", province=>2},
	"REI"=>{city=>"Bad Reichenhall", province=>2},
	"RG"=>{city=>"Großenhain", province=>13},
	"RH"=>{city=>"Roth", province=>2},
	"RI"=>{city=>"Rinteln", province=>9},
	"RID"=>{city=>"Riedenburg", province=>2},
	"RIE"=>{city=>"Riesa", province=>13},
	"RL"=>{city=>"Rochlitz", province=>13},
	"RM"=>{city=>"Röbel", province=>8},
	"RN"=>{city=>"Rathenow", province=>4},
	"RO"=>{city=>"Rosenheim", province=>2},
	"ROD"=>{city=>"Roding", province=>2},
	"ROF"=>{city=>"Rotenburg/Fulda", province=>7},
	"ROK"=>{city=>"Rockenhausen", province=>11},
	"ROL"=>{city=>"Rottenburg a. d. Laaber", province=>2},
	"ROS"=>{city=>"Rostock-Kreis", province=>8},
	"ROT"=>{city=>"Rothenburg o.d.Tauber", province=>2},
	"ROW"=>{city=>"Rotenburg (Wümme)", province=>9},
	"RS"=>{city=>"Remscheid", province=>10},
	"RSL"=>{city=>"Roßlau", province=>14},
	"RT"=>{city=>"Reutlingen", province=>1},
	"RU"=>{city=>"Rudolstadt", province=>15},
	"RV"=>{city=>"Ravensburg", province=>1},
	"RW"=>{city=>"Rottweil", province=>1},
	"RY"=>{city=>"Rheydt", province=>10},
	"RZ"=>{city=>"Herzogtum Lauenburg", province=>16},
	"RÜD"=>{city=>"Rheingau-Taunus-Kreis", province=>7},
	"RÜG"=>{city=>"Rügen", province=>8},
	"S"=>{city=>"Stuttgart", province=>1},
	"SAB"=>{city=>"Saarburg", province=>11},
	"SAD"=>{city=>"Schwandorf in Bayern", province=>2},
	"SAN"=>{city=>"Stadtsteinach", province=>2},
	"SAW"=>{city=>"Altmarkkreis Salzwedel", province=>14},
	"SB"=>{city=>"Saarbrücken", province=>12},
	"SBG"=>{city=>"Strasburg", province=>8},
	"SBK"=>{city=>"Schönebeck", province=>"Sachsen Anhalt"},
	"SC"=>{city=>"Schwabach", province=>2},
	"SCZ"=>{city=>"Schleiz", province=>15},
	"SDH"=>{city=>"Sondershausen", province=>15},
	"SDL"=>{city=>"Stendal", province=>14},
	"SDT"=>{city=>"Schwedt", province=>4},
	"SE"=>{city=>"Bad Segeberg", province=>16},
	"SEB"=>{city=>"Sebnitz", province=>13},
	"SEE"=>{city=>"Seelow", province=>4},
	"SEF"=>{city=>"Scheinfeld", province=>2},
	"SEL"=>{city=>"Selb", province=>2},
	"SF"=>{city=>"Sonthofen", province=>2},
	"SFA"=>{city=>"Soltau-Fallingbostel", province=>9},
	"SFB"=>{city=>"Senftenberg", province=>4},
	"SFT"=>{city=>"Staßfurt", province=>14},
	"SG"=>{city=>"Solingen", province=>10},
	"SGH"=>{city=>"Sangerhausen", province=>14},
	"SHA"=>{city=>"Schwäbisch Hall", province=>1},
	"SHG"=>{city=>"Schaumburg", province=>9},
	"SHK"=>{city=>"Saale-Holzland-Kreis", province=>15},
	"SHL"=>{city=>"Suhl", province=>15},
	"SI"=>{city=>"Siegen", province=>10},
	"SIG"=>{city=>"Sigmaringen", province=>1},
	"SIM"=>{city=>"Rhein-Hunsrück-Kreis", province=>11},
	"SK"=>{city=>"Saalkreis", province=>14},
	"SL"=>{city=>"Schleswig-Flensburg", province=>16},
	"SLE"=>{city=>"Schleiden", province=>10},
	"SLF"=>{city=>"Saalfeld-Rudolstadt", province=>15},
	"SLG"=>{city=>"Saulgau", province=>1},
	"SLN"=>{city=>"Schmölln", province=>15},
	"SLS"=>{city=>"Saarlouis", province=>12},
	"SLZ"=>{city=>"Bad Salzungen", province=>15},
	"SLÜ"=>{city=>"Schlüchtern", province=>7},
	"SM"=>{city=>"Schmalkalden-Meiningen", province=>15},
	"SMÜ"=>{city=>"Schwabmünchen", province=>2},
	"SN"=>{city=>"Schwerin", province=>8},
	"SNH"=>{city=>"Sinsheim Elsenz", province=>1},
	"SO"=>{city=>"Soest", province=>10},
	"SOB"=>{city=>"Schrobenhausen", province=>2},
	"SOG"=>{city=>"Schongau", province=>2},
	"SOK"=>{city=>"Saale-Orla-Kreis", province=>15},
	"SOL"=>{city=>"Soltau", province=>9},
	"SON"=>{city=>"Sonneberg", province=>15},
	"SP"=>{city=>"Speyer", province=>11},
	"SPB"=>{city=>"Spremberg", province=>4},
	"SPN"=>{city=>"Spree-Neiße", province=>4},
	"SPR"=>{city=>"Springe", province=>9},
	"SR"=>{city=>"Straubing (-Bogen)", province=>2},
	"SRB"=>{city=>"Strausberg", province=>4},
	"SRO"=>{city=>"Stadtroda", province=>15},
	"ST"=>{city=>"Steinfurt", province=>10},
	"STA"=>{city=>"Starnberg", province=>2},
	"STB"=>{city=>"Sternberg", province=>8},
	"STD"=>{city=>"Stade", province=>9},
	"STE"=>{city=>"Staffelstein", province=>2},
	"STH"=>{city=>"Schaumburg-Lippe", province=>9},
	"STL"=>{city=>"Stollberg", province=>13},
	"STO"=>{city=>"Stockach", province=>1},
	"SU"=>{city=>"Rhein-Sieg-Kreis", province=>10},
	"SUL"=>{city=>"Sulzbach-Rosenberg", province=>2},
	"SW"=>{city=>"Schweinfurt", province=>2},
	"SWA"=>{city=>"Bad Schwalbach", province=>7},
	"SY"=>{city=>"Syke", province=>9},
	"SZ"=>{city=>"Salzgitter", province=>9},
	"SZB"=>{city=>"Schwarzenberg", province=>13},
	"SÄK"=>{city=>"Säckingen", province=>1},
	"SÖM"=>{city=>"Sömmerda", province=>15},
	"SÜW"=>{city=>"Südliche Weinstraße", province=>11},
	"TBB"=>{city=>"Main-Tauber-Kreis", province=>1},
	"TE"=>{city=>"Tecklenburg", province=>10},
	"TET"=>{city=>"Teterow", province=>8},
	"TF"=>{city=>"Teltow-Fläming", province=>4},
	"TG"=>{city=>"Torgau", province=>13},
	"TIR"=>{city=>"Tirschenreuth", province=>2},
	"TO"=>{city=>"Torgau-Oschatz", province=>13},
	"TP"=>{city=>"Templin", province=>4},
	"TR"=>{city=>"Trier", province=>11},
	"TS"=>{city=>"Traunstein", province=>2},
	"TT"=>{city=>"Tettnang", province=>1},
	"TUT"=>{city=>"Tuttlingen", province=>1},
	"TÖL"=>{city=>"Bad Tölz-Wolfratshausen", province=>2},
	"TÖN"=>{city=>"Tönning", province=>16},
	"TÜ"=>{city=>"Tübingen", province=>1},
	"UE"=>{city=>"Uelzen", province=>9},
	"UEM"=>{city=>"Ueckermünde", province=>8},
	"UER"=>{city=>"Uecker-Randow", province=>8},
	"UFF"=>{city=>"Uffenheim", province=>2},
	"UH"=>{city=>"Unstrut-Hainich-Kreis", province=>15},
	"UL"=>{city=>"Ulm / Alb-Donau-Kreis", province=>1},
	"UM"=>{city=>"Uckermark", province=>4},
	"UN"=>{city=>"Unna", province=>10},
	"USI"=>{city=>"Usingen", province=>7},
	"ÜB"=>{city=>"Überlingen", province=>1},
	"V"=>{city=>"Vogtlandkreis", province=>13},
	"VAI"=>{city=>"Vaihingen", province=>1},
	"VB"=>{city=>"Vogelsbergkreis", province=>7},
	"VEC"=>{city=>"Vechta", province=>9},
	"VER"=>{city=>"Verden", province=>9},
	"VIB"=>{city=>"Vilsbiburg", province=>2},
	"VIE"=>{city=>"Viersen", province=>10},
	"VIT"=>{city=>"Viechtach", province=>2},
	"VK"=>{city=>"Völklingen", province=>12},
	"VL"=>{city=>"Villingen", province=>1},
	"VOF"=>{city=>"Vilshofen", province=>2},
	"VOH"=>{city=>"Vohenstrauß", province=>2},
	"VS"=>{city=>"Schwarzwald-Baar-Kreis", province=>1},
	"W"=>{city=>"Wuppertal", province=>10},
	"WA"=>{city=>"Waldeck", province=>7},
	"WAF"=>{city=>"Warendorf", province=>10},
	"WAK"=>{city=>"Wartburgkreis", province=>15},
	"WAM"=>{city=>"Westlicher Altmark-Kreis", province=>14},
	"WAN"=>{city=>"Wanne-Eickel", province=>10},
	"WAR"=>{city=>"Warburg", province=>10},
	"WAT"=>{city=>"Wattenscheid", province=>10},
	"WB"=>{city=>"Wittenberg", province=>14},
	"WBS"=>{city=>"Worbis", province=>15},
	"WD"=>{city=>"Wiedenbrück", province=>10},
	"WDA"=>{city=>"Werdau", province=>13},
	"WE"=>{city=>"Weimar", province=>15},
	"WEB"=>{city=>"Westerburg-Westerwald", province=>11},
	"WEG"=>{city=>"Wegscheid", province=>2},
	"WEL"=>{city=>"Weilburg", province=>7},
	"WEM"=>{city=>"Wesermünde", province=>9},
	"WEN"=>{city=>"Weiden", province=>2},
	"WER"=>{city=>"Wertingen", province=>2},
	"WES"=>{city=>"Wesel", province=>10},
	"WF"=>{city=>"Wolfenbüttel", province=>9},
	"WG"=>{city=>"Wangen", province=>1},
	"WHV"=>{city=>"Wilhelmshaven", province=>9},
	"WI"=>{city=>"Wiesbaden", province=>7},
	"WIL"=>{city=>"Wittlich", province=>11},
	"WIS"=>{city=>"Wismar, Kreis", province=>8},
	"WIT"=>{city=>"Witten", province=>10},
	"WIZ"=>{city=>"Witzenhausen", province=>7},
	"WK"=>{city=>"Wittstock", province=>4},
	"WL"=>{city=>"Harburg", province=>9},
	"WLG"=>{city=>"Wolgast", province=>8},
	"WM"=>{city=>"Weilheim-Schongau", province=>2},
	"WMS"=>{city=>"Wolmirstedt", province=>14},
	"WN"=>{city=>"Rems-Murr-Kreis", province=>1},
	"WND"=>{city=>"St. Wendel", province=>12},
	"WO"=>{city=>"Worms", province=>11},
	"WOB"=>{city=>"Wolfsburg", province=>9},
	"WOH"=>{city=>"Wolfhagen", province=>7},
	"WOL"=>{city=>"Wolfach", province=>1},
	"WOR"=>{city=>"Wolfratshausen", province=>2},
	"WOS"=>{city=>"Wolfstein", province=>2},
	"WR"=>{city=>"Wernigerode", province=>14},
	"WRN"=>{city=>"Waren", province=>8},
	"WS"=>{city=>"Wasserburg a. Inn", province=>2},
	"WSF"=>{city=>"Weißenfels", province=>14},
	"WST"=>{city=>"Ammerland", province=>9},
	"WSW"=>{city=>"Weißwasser", province=>13},
	"WT"=>{city=>"Waldshut", province=>1},
	"WTL"=>{city=>"Wittlage", province=>9},
	"WTM"=>{city=>"Wittmund", province=>9},
	"WUG"=>{city=>"Weißenburg-Gunzenhausen", province=>2},
	"WUN"=>{city=>"Wunsiedel", province=>2},
	"WUR"=>{city=>"Wurzen", province=>13},
	"WW"=>{city=>"Westerwald-Kreis", province=>11},
	"WZ"=>{city=>"Wetzlar", province=>7},
	"WZL"=>{city=>"Wanzleben", province=>14},
	"WÜ"=>{city=>"Würzburg", province=>2},
	"WÜM"=>{city=>"Waldmünchen", province=>2},
	"Z"=>{city=>"Zwickau (-Land)", province=>13},
	"ZE"=>{city=>"Zerbst", province=>14},
	"ZEL"=>{city=>"Zell / Mosel", province=>11},
	"ZI"=>{city=>"Löbau-Zittau", province=>13},
	"ZIG"=>{city=>"Ziegenhain", province=>7},
	"ZP"=>{city=>"Zschopau", province=>13},
	"ZR"=>{city=>"Zeulenroda", province=>15},
	"ZS"=>{city=>"Zossen", province=>4},
	"ZW"=>{city=>"Zweibrücken", province=>11},
	"ZZ"=>{city=>"Zeitz", province=>14}
    );
    my ($key) = @_;
    $key = $trans{lc $key} if defined $trans{lc $key};
    my %location;
    $key = uc($key);
    my %base = %de_kfz;
    if (defined $base{$key}) {
	$location{country} = 'Germany';
	$location{city} = $base{$key}{'city'};
	$location{province} = $province{$base{$key}->{province}};
    } else {
	#Irssi::print $key;
	foreach (keys %base) {
	    my $city = $base{$_}{city};
	    #$city = lc($city);
	    #$city =~ s/ä/ae/g;
	    #$city =~ s/ü/ue/g;
	    #$city =~ s/ö/oe/g;
	    #$city = uc($city);
	    if ($city =~ /(^| |-)$key( |-|$)/i) {
		$location{country} = 'Germany';
		$location{city} = $base{$_}{city};
		$location{province} = $province{$base{$_}{province}};
	    }
	}
    }
    return %location;
}


foreach ((352, 315)) {
    Irssi::signal_add_first('event '.$_, 'process_reply');
}

sub pre_unload { save_cache(); }

Irssi::signal_add('message join', 'event_message_join');
Irssi::signal_add('query created', 'event_query_created');
Irssi::signal_add('setup saved', 'save_cache');

Irssi::settings_add_bool($IRSSI{'name'}, 'localize_background', 1);

Irssi::settings_add_str($IRSSI{'name'}, 'localize_cache_filename', Irssi::get_irssi_dir()."/localize_cache");
Irssi::settings_add_str($IRSSI{'name'}, 'localize_trace_cmd', "/usr/sbin/traceroute -q 1 -w 2 -I");
Irssi::settings_add_int($IRSSI{'name'}, 'localize_trace_distance', 3);

Irssi::settings_add_str($IRSSI{'name'}, 'localize_auto_localize_channel_list', '.*');
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_auto_localize_on_join', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_auto_localize_on_query', 1);
Irssi::settings_add_int($IRSSI{'name'}, 'localize_auto_localize_maxrequests', 5);
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_get_coordinates', 0);
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_use_databases', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_use_traceroute', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'localize_show_message', 1);
Irssi::settings_add_str($IRSSI{'name'}, 'localize_ipatlas_nocache', '.*\.dip\.t-dialin\.net');

Irssi::settings_add_bool($IRSSI{'name'}, 'localize_xplanet_show_map', 0);
Irssi::settings_add_str($IRSSI{'name'}, 'localize_xplanet_temp_file', Irssi::get_irssi_dir()."/localize_xplanet_temp");
Irssi::settings_add_str($IRSSI{'name'}, 'localize_xplanet_cmd', "xplanet -w");

Irssi::theme_register([
    auto_localize => '%B`->%n $0 ($1) has been localized in $2, $3, $4 %B[%n$5%B]%n',
]);

Irssi::command_bind('localize', 'cmd_localize');

load_cache();
print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /localize -h for help';
