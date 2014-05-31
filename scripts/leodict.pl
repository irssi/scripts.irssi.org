#!/usr/bin/perl
#
# by Stefan "Tommie" Tomanek
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '20040515';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'leodict',
    description => 'translates via dict.leo.org',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    changed     => $VERSION,
    modules     => 'LWP::Simple Data::Dumper',
    commands	=> "leodict"
);
use vars qw($forked);
use Irssi 20020324;
use LWP::Simple;
use POSIX;


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
/leodict <word1> <word2>...
    searches dict.leo.org for appropiate translations
/leodict -p <word1>...
    paste the translations to the current channel or query
    The number of translations is limited by the setting
    'leodict_paste_max_translations'
/leodict -b <word1>...
    open dict.leo.org in your web browser (uses openurl.pl)
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}, $text, "help", 1);
}



sub get_page ($) {
    my ($word) = @_;
    return get('http://dict.leo.org/?search='.$word.'&relink=off');
}

sub get_words ($) {
    my ($word) = @_;
    my @translations;
    my $data = get_page($word);
    foreach (split(/\n/, $data)) {
	if (/(\d+) search results/) {
	    my $results = $1;
	    foreach (split(/\<\/TR\>/)) {
		my @trans;
		foreach (split(/\<\/TD\>/)) {
		    $_ =~ s/\<.*?\>//g;
		    $_ =~ s/^ *//g;
		    $_ =~ s/ *$//g;
		    $_ =~ s/&nbsp;//g;
		    $_ =~ s/^\t*//g;
		    # Thanks to senneth
		    $_ =~ s/Direct Matches//g;
		    next if (/\d+ search results/);
		    #print $_."\n" if (/\w/);
		    push @trans, $_ if (/\w/);
		}
		if (scalar(@trans) == 2) {
		    push @translations, \@trans;
		}
	    }
	}
    }
    return \@translations;
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
    my ($word,$target,$server) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    if ($forked) {
        print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
        return;
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
	eval {
	    my %result;
	    $result{trans} = get_words($word);
	    $result{word} = $word;
	    my $dumper = Data::Dumper->new([\%result]);
	    $dumper->Purity(1)->Deepcopy(1)->Indent(0);
	    my $data = $dumper->Dump;
	    print($wh $data);
	};
	close($wh);
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    my ($rh, $pipetag, $target, $tag) = @{$_[0]};
    $forked = 0;
    my $text;
    $text .= $_ foreach <$rh>;
    close $rh;
    Irssi::input_remove($$pipetag);
    unless ($text) {
	print CLIENTCRAP "%R<<%n Something weird happend";
	return(0);
    }
    no strict 'vars';
    my %incoming = %{ eval("$text") };
    if ($target eq '') {
	show_translations($incoming{trans},$incoming{word});
    } else {
	my $server = Irssi::server_find_tag($tag);
	my $witem = $server->window_item_find($target);
	paste_translations($incoming{trans}, $incoming{word}, $witem) if $witem;
    }
}

sub show_translations($$) {
    my @trans = @{$_[0]};
    my $word = $_[1];
    if (@trans) {
	my $text;
	foreach (@trans) {
	    $text .= "%U".$_->[0]."%U \n";
	    $text .= " `-> ".$_->[1]."\n";
	}
	print CLIENTCRAP draw_box('LeoDict', $text, $word, 1);
    } else {
	print CLIENTCRAP "%R>>>%n No translations found (".$word.").";
    }
}

sub paste_translations ($$) {
    my ($trans, $word, $target) = @_;
    return unless ($target->{type} eq "CHANNEL" || $target->{type} eq "QUERY");
    if (@$trans) {
        my $text;
	my $beauty = Irssi::settings_get_bool('leodict_paste_beautify');
	my $max = Irssi::settings_get_int('leodict_paste_max_translations');
       	my $i = 0;
        foreach (@$trans) {
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
	my $msg = $text;
        $msg = draw_box('LeoDict', $text, $word, 0) if $beauty;
	$target->command('MSG '.$target->{name}. ' '.$_) foreach (split(/\n/, $msg));
    }

}

sub cmd_leodict ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    my $paste = 0;
    my $browse = 0;
    if ($arg[0] eq '-p') {
	$paste = 1;
	shift(@arg);
    } elsif ($arg[0] eq '-b') {
	$browse = 1;
	shift(@arg);
    } elsif ($arg[0] eq '-h') {
	show_help();
	return();
    }
    
    foreach (@arg) {
	if ($paste) {
	    #paste_translations($_, $witem) if $witem;
	    next unless ref $witem;
	    next unless ref $server;
	    translate($_, $witem->{name}, $witem->{server}->{tag});
	} elsif ($browse) {
	    call_openurl('http://dict.leo.org/?lang=en&search='.$_);
	} else {
	    #show_translations($_);
	    translate($_,'', '');
	}
    }
}

Irssi::command_bind('leodict', 'cmd_leodict');

Irssi::settings_add_int($IRSSI{'name'}, 'leodict_paste_max_translations', 2);
Irssi::settings_add_bool($IRSSI{'name'}, 'leodict_paste_beautify', 1);

print CLIENTCRAP "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded: /leodict -h for help";
