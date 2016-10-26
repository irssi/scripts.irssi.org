#
# by Stefan "tommie" Tomanek <stefan@pico.ruhr.de>

use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2003020801';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'babelirc',
    description => 'translates your messages via Babelfish',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',                                     changed     => $VERSION,
    modules     => 'WWW::Babelfish Unicode::String Data::Dumper',
    sbitems     => 'babelirc_sb',
    commands	=> 'babelirc'
);  

use WWW::Babelfish;
use Unicode::String;
use Data::Dumper;
use Irssi 20020324;
use Irssi::TextUI;
use POSIX;


use vars qw(%channels);

sub show_help() {
    my $help = "babelirc $VERSION
/babelirc add <channel> <from> <to>
    Add a new translation entry for <channel>
/babelirc del <channel>
    Removes the translation for <channel>
/babelirc toggle <channel>
    Toggle selected entry
/babelirc list
    List all translation entries
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("BabelIRC", $text, "help", 1);
}


sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    my $exp_flags = Irssi::EXPAND_FLAG_IGNORE_EMPTY | Irssi::EXPAND_FLAG_IGNORE_REPLACES;
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {                                                      $box .= '%R|%n '.$_."\n";
    }                                                                               $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}


sub translate ($$$) {
    my ($text,$from,$to) = @_;
    Unicode::String->stringify_as('latin1');
    my $s = new Unicode::String($text);
    my $obj = new WWW::Babelfish('agent' => 'Mozilla/8.0');
    return undef unless $obj;
    my $data = $obj->translate('source' => $from,
                               'destination' => $to,
			       'text' => $s->utf8());
    Unicode::String->stringify_as('utf8');
    my $s2 = new Unicode::String($data);
    return($s2->latin1());
}

sub bg_trans ($$$$$$) {
    my ($text, $server, $target, $from, $to, $dir) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    my $pid = fork();
    if ($pid > 0) {
	close $wh;
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my %trans = ( text=>$text, trans=>translate($text, $from, $to) );
	    $trans{server} = $server->{tag};
	    $trans{target} = $target->{name} if $target;
	    $trans{dir} = $dir;
	    my $dumper = Data::Dumper->new([\%trans]);
	    $dumper->Purity(1)->Deepcopy(1);
	    my $data = $dumper->Dump;
	    print($wh $data);
	    close($wh);
	};
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    no strict;
    my ($rh, $pipetag) = @{$_[0]};
    my $text;
    $text .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    my %result = %{ eval "$text" };
    unless (defined $result{target}) {
	print CLIENTCRAP $result{text};
	print CLIENTCRAP $result{trans};
    } else {
	my $server = Irssi::server_find_tag($result{server});
	my $channel = $server->window_item_find($result{target});
	my $stamp = Irssi::settings_get_str('babelirc_stamp');
	my $text = $result{trans};
	unless (defined $text) {
	    $channel->print("%R>>%n Translation failed", MSGLEVEL_CLIENTCRAP);
	    return;
	}
	$text = $result{text} if ($result{trans} eq '&nbsp;');
	if ($result{dir} eq 'out') {
	    $server->command('MSG '.$channel->{name}.' '.$text.' '.$stamp);
	} else {
	    $channel->print("%b`->%n ".$text.' '.$stamp, MSGLEVEL_CLIENTCRAP);
	}
	if ($channels{$channel->{name}}->{status} >= 2) {
	    $channels{$channel->{name}}->{status}--;
	}
	Irssi::statusbar_items_redraw('babelirc_sb');
    }
}



sub cmd_babelirc ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ +/, $args);
    if ($arg[0] eq 'add' && defined $arg[1] && defined $arg[2] && defined $arg[3]) {
	my $local = Irssi::settings_get_str('babelirc_my_language');
	add_channel($arg[1],$arg[2],$arg[3]);
    } elsif ($arg[0] eq 'add' && defined $arg[1] && $witem) {
	my $local = Irssi::settings_get_str('babelirc_my_language');
	add_channel($witem->{name},$local,$arg[1]);
    } elsif ($arg[0] eq 'del' && defined $arg[1]) {
	delete $channels{$arg[1]} if defined $channels{$arg[1]};
	Irssi::statusbar_items_redraw('babelirc_sb');
    } elsif ($arg[0] eq 'list') {
	list_trans();
    } elsif ($arg[0] eq 'toggle' && defined $arg[1]) {
	toggle_trans($arg[1]);
    } elsif ($arg[0] eq 'toggle') {
	toggle_trans($witem->{name}) if $witem;
    } elsif ($arg[0] eq 'help' || $arg[0] eq '-h') {
	show_help()
    } elsif ($arg[0] eq 'save') {
	save_channels();
    } elsif ($arg[0] eq 'load') {
	load_channels();
    }
}

sub toggle_trans ($) {
    my ($channel) = @_;
    return unless defined $channels{$channel};
    $channels{$channel}{status} = not $channels{$channel}{status};
    Irssi::statusbar_items_redraw('babelirc_sb');
}

sub list_trans () {
    my $text;
    foreach (sort keys %channels) {
	if ($channels{$_}{status} == 0) {
	    $text .= "%9<Q«%9";
	} else {
	    $text .= "%g%9<Q«%9%n";
	}
	$text .= ' %9'.$_."%9\n";
	$text .= '    From: '.$channels{$_}{from}."\n";
	$text .= '    To  : '.$channels{$_}{to}."\n";
    }
    print CLIENTCRAP draw_box("BabelIRC", $text, "list", 1);
}

sub add_channel ($$$) {
    my ($target, $from, $to) = @_;
    my %channel = (from=>$from, to=>$to, status => 0);
    $channels{$target} = \%channel;
    Irssi::statusbar_items_redraw('babelirc_sb');
}

sub save_channels {
    my $filename = Irssi::settings_get_str('babelirc_filename');
    local *F;
    open F, '>'.$filename;
    my $data = Dumper(\%channels);
    print F $data;
    close F;
    print CLIENTCRAP "%R>>%n BabelIRC channels saved";
}

sub load_channels {
    my $filename = Irssi::settings_get_str('babelirc_filename');
    return unless (-e $filename);
    local *F;
    open F, '<'.$filename;
    my $text;
    $text .= $_ foreach <F>;
    no strict "vars";
    %channels = %{ eval "$text" };
}

sub babelirc_show ($$) {
    my ($item, $get_size_only) = @_;
    my $win = !Irssi::active_win() ? undef : Irssi::active_win()->{active};
    if (ref $win && ($win->{type} eq "CHANNEL" || $win->{type} eq "QUERY") && defined $channels{$win->{name}}) {
	my $fish = "<Q«";
	my @bubbles = ('°', 'o', '*', '·', ' ');
	$fish = $bubbles[rand(@bubbles)].$fish;
	$item->{min_size} = $item->{max_size} = length($fish);
	if ($channels{$win->{name}}->{status} == 1) {
	    $fish = '%U%g'.$fish.'%U%n';
	} elsif ($channels{$win->{name}}->{status} >= 2) {
	    $fish = '%9%F'.$fish.'%F%9';
	}
	my $format = "{sb ".$fish."}";
	$item->default_handler($get_size_only, $format, 0, 1);
    } else {
	$item->{min_size} = $item->{max_size} = 0;
    }
}

sub event_send_text ($$$) {
    my ($line, $server, $witem) = @_;
    return unless ref $witem;
    if (defined $channels{$witem->{name}}) {
	return if $channels{$witem->{name}}->{status} == 0;
	my $stamp = Irssi::settings_get_str('babelirc_stamp');
	my $regexp = quotemeta($stamp);
	return if $line =~ / $regexp$/;
	Irssi::signal_stop();
	$channels{$witem->{name}}->{status}++;
	Irssi::statusbar_items_redraw('babelirc_sb');
	bg_trans($line, $server, $witem, $channels{$witem->{name}}->{from}, $channels{$witem->{name}}->{to}, "out");
    }
}

sub event_message_public ($$$$) {
    my ($server, $text, $nick, $address, $target) = @_; 
    return unless defined $channels{$target};
    return unless $channels{$target}{status} > 0;
    my $regexp = '^'.Irssi::settings_get_str("babelirc_retranslate").'$';
    return unless $text =~ /$regexp/;
    my $witem = Irssi::window_item_find($target);
    bg_trans($text, $server, $witem, $channels{$witem->{name}}->{to}, $channels{$witem->{name}}->{from}, "in");
}

Irssi::command_bind('babelirc', \&cmd_babelirc);
foreach my $cmd ('add', 'del', 'list', 'toggle', 'help', 'save', 'load') {
    Irssi::command_bind('babelirc '.$cmd => sub {
		    cmd_babelirc($cmd." ".$_[0], $_[1], $_[2]); });
}

Irssi::timeout_add(5000, sub { Irssi::statusbar_items_redraw('babelirc_sb');}, undef);

Irssi::statusbar_item_register('babelirc_sb', 0, "babelirc_show");

Irssi::signal_add_first('send text', "event_send_text");
Irssi::signal_add('message public', "event_message_public");
Irssi::signal_add('window changed', sub {Irssi::statusbar_items_redraw('babelirc_sb');});
Irssi::signal_add('setup saved', 'save_channels');

Irssi::settings_add_str($IRSSI{name}, 'babelirc_stamp', '[BabelIRC]');
Irssi::settings_add_str($IRSSI{name}, 'babelirc_my_language', 'German');
Irssi::settings_add_str($IRSSI{name}, 'babelirc_retranslate', '');

Irssi::settings_add_str($IRSSI{name}, 'babelirc_filename', Irssi::get_irssi_dir()."/babelirc_channels");

load_channels();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /babelirc help for help';

