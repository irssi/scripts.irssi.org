#!/usr/bin/perl
#
# by Stefan "Tommie" Tomanek
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '20220104';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek, bw1',
    contact     => 'bw1@aol.at',
    name        => 'leodict',
    description => 'translates via dict.leo.org',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    modules     => 'Mojo::UserAgent Encode JSON::PP Mojo::DOM Getopt::Long POSIX',
    commands	=> "leodict",
    selfcheckcmd=> 'leodict -chec',
);
use vars qw($forked);
use utf8;
use Encode;
use Irssi 20020324;
use JSON::PP;
use Mojo::DOM;
use Getopt::Long qw(GetOptionsFromString);
use Mojo::UserAgent;
use POSIX;

# global
my %gresult;
my $lang;
my $dlang= 'englisch-deutsch/';
my $help;
my $browse;
my $paste;
my $word;
my $dir;
my $ddir= '';
my $check;

# for fork
my $ftext;
my %fresult;

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

sub show_help() {
    my $help = "LeoDict $VERSION
SYNOPSIS
  /leodict [OPTION] <word> [OPTION]
    searches dict.leo.org for appropiate translations
DESCRIPTION
  -p
    paste the translations to the current channel or query
    The number of translations is limited by the setting
    'leodict_paste_max_translations'
  -b
    open dict.leo.org in your web browser (uses openurl.pl)

  -from from German
  -to   to German
  -both from and to German
  -en   English
  -fr   French
  -es   Spanish
  -it   Italian
  -zh   Chinese
  -ru   Russian
  -pt   Portuguese
  -pl   Polish
  -chec selfcheck
SETTINGS
  'leodict_default_options'
    example: -it -from
  'leodict_paste_max_translations'
  'leodict_paste_beautify'
  'leodict_http_proxy_address'
    example: 127.0.0.1
    defaults to none, meaning no proxy will be used for requests.
    despite the name, does not have to be http proxy.
  'leodict_http_proxy_port'
    example: 9050
    defaults to 0, but must be changed if proxy address is not none.
  'leodict_http_proxy_type'
    supported: socks, https, http
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}, $text, "help", 1);
}

sub parser {
    my %ignore=(
	'Suchwort' => 1,
	'Beispiele' => 1,
	'Orthographisch ähnliche Wörter' => 1,
	'Aus dem Umfeld der Suche' => 1,
	'Forumsdiskussionen, die den Suchbegriff enthalten' =>1,
	#'Substantive'
	#'Verben'
	#'Adjektive / Adverbien'
	#'Phrasen'
    );
    %fresult=();

    # tables
    unless (defined $ftext) {
    	%fresult=('Error'=>[['no data']]);
	return;
    }
    my $dom = Mojo::DOM->new($ftext);
    foreach my $tbl ( $dom->find('table')->each ) {

	# head
	my $thead =$tbl->at('thead');
	next unless (defined $thead );
	my $headname = $thead->descendant_nodes->last->to_string;
	next if (exists $ignore{ $headname } );


	# rows
	my @rows=();
	foreach my $row ( $tbl->find('tr')->each) {

	    # colums
	    my @columns=();
	    foreach my $col ( $row->find('td')->each ) {
		my $co = $col->to_string;
		$co =~ s/<.*?>//sg;
		if ( length($co) >2 ) {
		    push(@columns ,$co);
		}
	    }
	    if ( scalar(@columns) > 0 ) {
		push(@rows, [@columns]);
	    }
	}
	$fresult{ $headname } = [ @rows ];
    }
}

sub get_page ($) {
    my ($url) = @_;
    #return get('http://dict.leo.org/?search='.$word.'&relink=off');
    my $ua = Mojo::UserAgent->new;

    # Add proxy to Mojo if needed
    my $proxy_addr = Irssi::settings_get_str('leodict_http_proxy_address');
    my $proxy_port = Irssi::settings_get_int('leodict_http_proxy_port');
    my $proxy_type = Irssi::settings_get_str('leodict_http_proxy_type');
    if ($proxy_addr ne 'none') {
	# Socks proxy
	if ($proxy_type eq 'socks' || $proxy_type eq 'https') {
	    $ua->proxy->http("$proxy_type://$proxy_addr:$proxy_port")->https("$proxy_type://$proxy_addr:$proxy_port"); 
	}
	# Must be http proxy
	else {
	    $ua->proxy->http("$proxy_type://$proxy_addr:$proxy_port");
	}
    }
    
    my $res;
    eval {
	$res=$ua->get($url)->result;
    };
    if (defined $res && $res->is_success) {
	$ftext = $res->body;
	utf8::decode($ftext);
    } else {
	$ftext=undef;
    }
}

sub call_openurl ($) {
    my ($url) = @_;
    no strict "refs";
    # check for a loaded openurl
    if (defined &{ "Irssi::Script::openurl::launch_url" } ) {
        &{ "Irssi::Script::openurl::launch_url" }($url);
    } else {
        print CLIENTCRAP "%R>>%n Please install openurl.pl";
    }
}

sub translate ($$$) {
    my ($url, $target, $server) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    if ($forked) {
        print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
        return;
    }

    # Validate proxy if needed
    my $proxy_addr = Irssi::settings_get_str('leodict_http_proxy_address');
    my $proxy_port = Irssi::settings_get_int('leodict_http_proxy_port');
    my $proxy_type = Irssi::settings_get_str('leodict_http_proxy_type');
    if ($proxy_addr ne 'none') {
	if ($proxy_type ne 'socks' && $proxy_type ne 'https' && $proxy_type ne 'http') {
	    print CLIENTCRAP "%R>>%n Invalid proxy type: $proxy_type.";
	    return;
	}
	if ($proxy_port eq 0) {
	    print CLIENTCRAP "%R>>%n Please specify a proxy port.";
	    return;
	}
    }
    
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	print CLIENTCRAP "%R>>%n Please wait..." unless $target;
	close $wh; 
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag, $target, $server);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	get_page($url);
	parser();
	print($wh encode_json(\%fresult));
	close($wh);
	POSIX::_exit(1);
    }
}

sub one_site {
    my ($site, $cat) = @_;
    my @res;
    foreach my $r ( @{$gresult{$cat}} ) {
	push @res,$r->[$site];
    }
    return [@res];
}

sub pipe_input ($) {
    my ($rh, $pipetag, $target, $tag) = @{$_[0]};
    $forked = 0;
    local $\;
    my $res=<$rh>;
    close $rh;
    return if (length($res) <5);
    %gresult = %{decode_json( $res )};
    Irssi::input_remove($$pipetag);

    if ($target eq '') {
        show_translations(\%gresult, $word);
    } else {
        my $server = Irssi::server_find_tag($tag);
        my $witem = $server->window_item_find($target);
	paste_translations(\%gresult, $word, $witem) if $witem;
    }
}

sub show_translations($$) {
    my %trans = %{$_[0]};
    my $word = $_[1];
    self_check(\%trans) if ( defined $check );
    if (%trans) {
	my $text;
	foreach my $k (keys %trans) {
	    $text .= "== $k ==\n";
	    foreach (@{ $trans{$k} }) {
		$text .= "%U".$_->[0]."%U \n";
		$text .= " `-> ".$_->[1]."\n";
	    }
	}
	my $term_charset= Irssi::settings_get_str('term_charset');
	if ('UTF-8' ne $term_charset) {
	    $text= encode($term_charset, $text);
	}
	print CLIENTCRAP draw_box('LeoDict', $text, $word, 1);
    } else {
	print CLIENTCRAP "%R>>>%n No translations found (".$word.").";
    }
}

sub paste_translations ($$) {
    my ($trans, $word, $target) = @_;
    return unless ($target->{type} eq "CHANNEL" || $target->{type} eq "QUERY");
    if (%{ $trans }) {
        my $text;
	my $beauty = Irssi::settings_get_bool('leodict_paste_beautify');
	my $max = Irssi::settings_get_int('leodict_paste_max_translations');
	foreach my $k (keys %{ $trans }) {
	    $text .= "== $k ==\n";
	    my $i = 0;
	    foreach (@{ $trans->{$k}}) {
		if ($i < $max || $max == 0) {
		    if ($beauty) {
			$text .= $_->[0]." \n";
			$text .= " `-> ".$_->[1]."\n";
		    } else {
			$text .= $_->[0].' => '.$_->[1]."\n";
		    }
		    $i++;
		} else {
		    $text .= '...'."\n";
		    last;
		}
	    }
	}
	my $msg = $text;
        $msg = draw_box('LeoDict', $text, $word, 0) if $beauty;
	$target->command('MSG '.$target->{name}. ' '.$_) foreach (split(/\n/, $msg));
    }
}

#https://dict.leo.org/englisch-deutsch/word
#https://dict.leo.org/franz%C3%B6sisch-deutsch/word
#https://dict.leo.org/spanisch-deutsch/word
#https://dict.leo.org/italienisch-deutsch/word
#https://dict.leo.org/chinesisch-deutsch/word
#https://dict.leo.org/russisch-deutsch/word
#https://dict.leo.org/portugiesisch-deutsch/word
#https://dict.leo.org/polnisch-deutsch/word
#https://dict.leo.org/polnisch-deutsch/word?side=left  pl -> de
#https://dict.leo.org/polnisch-deutsch/word?side=right pl <- de
my %options = (
    "from" => sub {$dir= '?side=right';},
    "to" => sub {$dir= '?side=left';},
    "both" => sub {$dir= '';},
    "en" => sub {$lang = 'englisch-deutsch/'; },
    "fr" => sub {$lang = 'franz%C3%B6sisch-deutsch/'; },
    "es" => sub {$lang = 'spanisch-deutsch/'; },
    "it" => sub {$lang = 'italienisch-deutsch/'; },
    "zh" => sub {$lang = 'chinesisch-deutsch/'; },
    "ru" => sub {$lang = 'russisch-deutsch/'; },
    "pt" => sub {$lang = 'portugiesisch-deutsch/'; },
    "pl" => sub {$lang = 'polnisch-deutsch/'; },
    "h" => \$help,
    "b" => \$browse,
    "p" => \$paste,
    "chec" => \$check,
);

sub cmd_leodict ($$$) {
    my ($args, $server, $witem) = @_;
    utf8::decode($args);
    my $burl = "https://dict.leo.org/";
    my $url;

    $lang= $dlang;
    $dir= $ddir;
    undef $help;
    undef $browse;
    undef $paste;
    undef $check;

    my ($ret, $arg) = GetOptionsFromString($args, %options);

    $word= $arg->[0];
    $url=$burl.$lang.$word.$dir;

    if (defined $help) {
        show_help();
        return();
    }
    if (defined $browse) {
	call_openurl($url);
        return();
    }

    if (defined $paste) {
	#paste_translations($_, $witem) if $witem;
	return unless defined $witem;
	return unless defined $server;
	translate($url, $witem->{name}, $witem->{server}->{tag});
    } elsif (defined $check) {
	$url=$burl.'englisch-deutsch/'.'tree'.$dir;
	translate($url,'', '');
    } else {
	#show_translations($_);
	translate($url,'', '');
    }
}

sub self_check {
    my ( $tr ) =@_;
    my $s='ok';
    Irssi::print("selfcheck: categorys ".scalar( keys %$tr ));
    my $count=0;
    foreach my $n ( keys %$tr ) {
	Irssi::print("selfcheck: category $n ".scalar( @{$tr->{$n}} ));
	$count +=scalar( @{$tr->{$n}} );
    }
    Irssi::print("selfcheck: results $count");
    if ( scalar( keys %$tr ) <4 ) {
	$s='Error: categorys ('.scalar( keys %$tr ).')';
    } elsif ( $count < 35 ) {
	$s="Error: results ($count)";
    }
    Irssi::print("selfcheck: $s");
    my $schs =  exists $Irssi::Script::{'selfcheckhelperscript::'};
    Irssi::command("selfcheckhelperscript $s") if ( $schs );
}

sub sig_setup_changed {
    my $args =Irssi::settings_get_str('leodict_default_options');
    my ($ret, $arg) = GetOptionsFromString($args, %options);
    $dlang=$lang;
    $ddir=$dir;
}

Irssi::signal_add('setup changed', 'sig_setup_changed');

Irssi::command_bind('leodict', 'cmd_leodict');

Irssi::command_set_options('leodict', join(" ",keys %options));

Irssi::settings_add_str($IRSSI{'name'}, 'leodict_default_options', '-en -both');
Irssi::settings_add_int($IRSSI{'name'}, 'leodict_paste_max_translations', 2);
Irssi::settings_add_bool($IRSSI{'name'}, 'leodict_paste_beautify', 1);
Irssi::settings_add_str($IRSSI{'name'}, 'leodict_http_proxy_address', 'none');
Irssi::settings_add_int($IRSSI{'name'}, 'leodict_http_proxy_port', 0);
Irssi::settings_add_str($IRSSI{'name'}, 'leodict_http_proxy_type', 'none');

sig_setup_changed();

print CLIENTCRAP "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded: /leodict -h for help";

# vim:set ts=8 sw=4:
