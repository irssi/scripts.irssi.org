# OnTV by Stefan'tommie' Tomanek

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "20050226";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "OnTV",
    description => "turns irssi into a tv program guide",
    license     => "GPLv2",
    modules     => "Data::Dumper POSIX LWP::Simple HTML::Entities Text::Wrap",
    changed     => "$VERSION",
    commands	=> "ontv"
);

use Irssi 20020324;
use Data::Dumper;
use POSIX;
use LWP::Simple;
use HTML::Entities;
use Text::Wrap;

use vars qw($forked @comp);

sub show_help() {
    my $help=$IRSSI{name}." ".$VERSION."
/ontv (current)
    List the current tv program
/ontv search <query>
    Query the program guide for a show
/ontv next
    Show what'S next on TV
/ontv tonight
    List tonight's program
/ontv watching <station>
    Display what's on <station>
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box($IRSSI{name}." help", $text, "help", 1) ;
}

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub get_prog ($) {
    my ($what) = @_;
    my $url = 'http://www.tvmovie.de/tv-programm/jetzt.html?nocache=true';
    $url = 'http://www.tvmovie.de/tv-programm/gleich.html?nocache=true' if ($what == 0);
    $url = 'http://www.tvmovie.de/tv-programm/2015.html' if ($what == 2);
    my $data = get($url);
    my $programs = [];
    my %program;
    foreach (split /\n/, $data) {
	#print $_;
	if (/class="linkgrau">(.*?)<\/a><\/font><\/td>/) {
	    $program{station} = $1;
	    decode_entities($program{station});
	}
	#if (/<a href="http:\/\/www.tvmovie.de\/tv-programm\/sendung.html\?SendungID=(\d+)" class="linkblack"><b>(.*?)<\/b><\/a>/) {
	if (/<a href="http:\/\/www.tvmovie.de\/tv-programm\/sendung.html\?SendungID=(\d+)" class="linkblack"><b>(.*?)<\/b>/) {
	    $program{id} = $1;
	    $program{title} = $2;
	    decode_entities($program{title});
	}
	if (/<FONT face="Verdana, Arial, Helvetica, sans-serif" size="1" color="#757575"><br>(.*?)<\/font><\/font><\/td>/) {
	    $program{comment} = decode_entities($1);
	}
	if (/color='#ee0000'>(.*?)<\/font><\/td>/) {
	    $program{type} = decode_entities($1);
	}
	if (/color="white"><b>([A-Z]{2})<\/b><\/font><\/td>/) {
	    $program{day} = $1;
	}
	if (/size="1">(\d{2}\.\d{2})&nbsp;<\/font><\/td>/) {
	    $program{begin} = $1;
	    decode_entities($program{begin});
	}
	if (/size="1">bis&nbsp;(\d{2}\.\d{2})<\/font><\/td>/) {
	    $program{end} = $1;
	    decode_entities($program{end});
	    my %data = %program;
	    push @$programs, \%data;
	    %program = ();
	}
    }
    return $programs;
}

sub search_prog ($) {
    my ($query) = @_;
    encode_entities($query);
    my $url = 'http://fernsehen.tvmovie.de/finder?finder=swsendung&tag=alle&sw_sendung='.$query;
    my $data = get($url);
    return( parse_search($data) );
}

sub parse_search ($) {
    my ($data) = @_;
    my $programs = [];
    my %program;
    foreach (split /\n/, $data) {
	if (/color="white"><b>([A-Z]{2})<\/b> <\/font><\/td>$/) {
	    $program{day} = $1;
	    decode_entities($program{day});
	}
	if (/size="1">(\d{2}:\d{2})<\/font><\/td>$/) {
	    $program{begin} = $1;
	    decode_entities($program{begin});
	} elsif (/class="linkgrau">(.*?)<\/a><\/font><\/td>$/) {
	    $program{station} = $1;
	    decode_entities($program{station});
	} elsif (/<a href="http:\/\/www.tvmovie.de\/tv-programm\/sendung\.html\?SendungID=(\d+)" class="linkblack"><b>(.*?)<\/b><\/a><\/font>(?:<FONT face="Verdana, Arial, Helvetica, sans-serif" size="1" color="#757575"><br>(.*?)<\/font>)?/) {
	    $program{id} = $1;
	    $program{title} = $2;
	    $program{comment} = $3;
	    decode_entities($program{title});
	    decode_entities($program{comment});
	#} elsif (/{ \t]*<td valign="top" align="left">$/) {
	    my %data = %program;
	    push @$programs, \%data;
	}
    }
    return $programs;
}

sub get_info ($) {
    my ($id) = @_;
    my $data = get('http://www.tvmovie.de/tv-programm/sendung.html?SendungID='.$id);
    my %info;
    foreach (split(/\n/, $data)) {
	#print;
	if (/size="3"><b>(.*?)<\/b><br><\/font>$/) {
	    $info{title} = decode_entities($1);
	} elsif (/color="#FFFFFF"><b>&nbsp;(\d+\.\d+\.\d+) \|/) {
	    $info{date} = decode_entities($1);
	} elsif (/size="1"><b>(.*?)<\/b><br><br><\/font>$/) {
	    $info{comment} = decode_entities($1);
	} elsif (/class="uppercase"><b>(.*?)<\/b> <\/font>/) {
	    $info{type} = decode_entities($1);
	} elsif (/<FONT face="Verdana, Arial, Helvetica, sans-serif" size="1">(.*?)<br><br><\/font>/) {
	    $info{desc} = decode_entities($1);
	} elsif (/\[Sender:&nbsp;(.*?)\] \[Beginn:&nbsp;(.*?)\] \[Dauer:&nbsp;(.*?) Min\.\] \[Ende:&nbsp;(.*?)\] \[SV:&nbsp;(.*?)\]/) {
	    $info{station} = decode_entities($1);
	    $info{begin} = decode_entities($2);
	    $info{end} = decode_entities($4);
	    $info{showview} = decode_entities($5);
	}
    }
    my $stat = $info{station};
    $info{desc} =~ s/$stat$//;
    #$info{desc} =~ s/<br><br>$//;
    $info{desc} =~ s/<br>/\n/g;
    return \%info;
}

sub bg_fetch ($$) {
    my ($op, $query) = @_;
    my ($rh, $wh); 
    pipe($rh, $wh); 
    if ($forked) {
        print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
        return;
    }
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	print CLIENTCRAP "%R>>%n Please wait...";
	close $wh;
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag, $op, $query);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	my $result = {};
	my @program;
	my $stations = Irssi::settings_get_str('ontv_stations');
	eval {
	    if ($op eq 'current') {
		@program = @{ get_prog(1) };
		foreach (@program) {
		    push @{ $result->{program} }, $_ if ($_->{station} =~ /^($stations)$/);
		}
	    } elsif ($op eq 'next') {
		@program = @{ get_prog(0) };
		foreach (@program) {
		    push @{ $result->{program} }, $_ if ($_->{station} =~ /^($stations)$/);
		}
	    } elsif ($op eq 'tonight') {
		@program = @{ get_prog(2) };
		foreach (@program) {
                    push @{ $result->{program} }, $_ if ($_->{station} =~ /^($stations)$/);
                }
	    } elsif ($op eq 'search') {
		@program = @{ search_prog($query) };
		foreach (@program) {
		    push @{ $result->{program} }, $_ if ($_->{station} =~ /^($stations)$/);
		}
	    } elsif ($op eq 'watching') {
		@program = @{ get_prog(1) };
		foreach (@program) {
		    next unless ($_->{station} =~ /^($query)$/);
		    push @{ $result->{program} }, $_;
		    print $_->{id};
		    $result->{info} = get_info($_->{id});
		}
	    } elsif ($op eq 'info') {
		$result->{info} = get_info($query);
	    }
	    my $dumper = Data::Dumper->new([$result]);
	    $dumper->Purity(1)->Deepcopy(1)->Indent(0);
	    print($wh $dumper->Dump);
	};
	close $wh;
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    my ($rh, $pipetag, $op, $args) = @{$_[0]};
    $forked = 0;
    Irssi::input_remove($$pipetag);
    my $text;
    $text .= $_ foreach <$rh>;
    no strict 'vars';
    my $incoming = eval("$text");
    return unless ($incoming->{program} || $incoming->{info});
    print_prog($incoming->{program}, 'current') if ($op eq 'current');
    print_prog($incoming->{program}, 'next') if ($op eq 'next');
    print_prog($incoming->{program}, 'tonight') if ($op eq 'tonight');
    print_prog($incoming->{program}, 'query: "'.$args.'"') if ($op eq 'search');
    print_prog($incoming->{program}, 'current: "'.$args.'"') if ($op eq 'watching');
    print_info($incoming->{info}) if $incoming->{info};
}

sub print_info ($) {
    my ($info) = @_;
    my $text;
    $text .= '%9'.$info->{title}.'%9'."\n";
    $text .= $info->{date}.': '.$info->{begin}."-".$info->{end}."\n";
    $text .= 'Showview: '.$info->{showview}."\n\n";
    $text .= $info->{comment}."\n\n";
    $text .= $info->{desc};
    my $col = int( Irssi::active_win()->{width}*(2/3) );
    $Text::Wrap::columns = $col;
    my $article = wrap("", "", $text);
    print CLIENTCRAP &draw_box('OnTV', $article, $info->{title}, 1);
}

sub print_prog ($$) {
    my ($program, $query) = @_;
    @comp = @$program;
    my $text;
    foreach (@$program) {
	$text .= "%9".$_->{station}."%9:";
	$text .= " %U".$_->{title}."%U";
	$text .= " [".$_->{type}."]"if $_->{type};
	$text .= " (".$_->{id}.")\n";
	$text .= " >".$_->{comment}."<\n" if $_->{comment};
	$text .= "  time: ";
	$text .= $_->{day}.", ";
	$text .= $_->{begin};
	$text .= "-".$_->{end} if $_->{end};
	$text .= "\n";
	#$text .= "\n";
    }
    print CLIENTCRAP &draw_box('OnTV', $text, $query, 1);
}

sub sig_complete_word ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.ontv (info)/;
    foreach (@comp) {
        push @$list, $_->{id} if ($_->{id} =~ /^(\Q$word\E.*)?$/);
        push @$list, $_->{station} if ($_->{station} =~ /^(\Q$word\E.*)?$/);
        push @$list, $_->{title} if ($_->{title} =~ /^(\Q$word\E.*)?$/);
    }
    Irssi::signal_stop();
}


sub cmd_ontv ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if (scalar(@arg) == 0 || $arg[0] eq 'current') {
	bg_fetch('current', '');
    } elsif ($arg[0] eq 'next') {
	bg_fetch('next', '');
    } elsif ($arg[0] eq 'tonight') {
	bg_fetch('tonight', '');
    } elsif ($arg[0] eq 'search') {
	shift @arg;
	bg_fetch('search', join(' ', @arg))
    } elsif ($arg[0] eq 'watching' && defined $arg[1]) {
	shift @arg;
	bg_fetch('watching', join(' ', @arg));
    } elsif ($arg[0] eq 'info' && defined $arg[1]) {
	shift @arg;
	my $query = join(' ', @arg);
	unless ($query =~ /^\d+$/) {
	    foreach (@comp) {
		if ($_->{title} eq $query || $_->{station} eq $query) {
		    $query = $_->{id};
		    last;
		}
	    }
	}
	bg_fetch('info', $query);
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

Irssi::settings_add_str($IRSSI{name}, 'ontv_stations', '.*' );

Irssi::command_bind('ontv' => \&cmd_ontv);

Irssi::signal_add_first('complete word', \&sig_complete_word);

foreach my $cmd ('search', 'current', 'next', 'tonight', 'watching', 'help', 'info') {
    Irssi::command_bind('ontv '.$cmd =>
         sub { cmd_ontv("$cmd ".$_[0], $_[1], $_[2]); } );
}


print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /ontv help for help';
