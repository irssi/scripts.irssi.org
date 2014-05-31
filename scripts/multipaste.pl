use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003120617";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "multipaste",
    description => "Helps pasting multiple lines to a channel",
    license     => "GPLv2",
    url         => "",
    changed     => "$VERSION",
    modules     => "",
    commands	=> "multipaste"
);

use Irssi 20020324;
use vars qw(%item);

sub sig_send_text ($$$) {
    my ($line, $server, $witem) = @_;
    return unless (Irssi::settings_get_bool('multipaste_auto'));
    return unless (ref $server);
    return unless ($witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));
    $line =~ s/\t/    /g;
    if (%item && $item{waiting}) {
	%item = ();
    }
    if ($witem->{name} eq $item{channel} && $server->{tag} eq $item{server}) {
	Irssi::timeout_remove($item{timeout});
	#Irssi::command("BIND -delete tab");
	my $timeout = 10;
	chomp($line);
	$item{text} .= $line."\n";
	$item{timeout} = Irssi::timeout_add($timeout, \&send_item, undef);
	Irssi::signal_stop();
    } else {
	unless ($line eq '') {
	    Irssi::signal_stop();
	    paste($line, $server, $witem);
	}
    }
}

sub sig_send_command ($$$) {
    my ($line, $server, $witem) = @_;
    return if ($line =~ /^.multipaste/);
    return unless (Irssi::settings_get_bool('multipaste_auto'));
    return unless (ref $witem && ($witem->{type} eq 'CHANNEL' || $witem->{type} eq 'QUERY'));
    if (%item && $item{waiting}) {
	%item = ();
	return;
    }
    # This does not work when the first line starts with 
    return unless $item{text};
    $line =~ s/\t/    /g;
    if ($witem->{name} eq $item{channel} && $server->{tag} eq $item{server}) {
        Irssi::timeout_remove($item{timeout});
	#Irssi::command("BIND -delete tab");
        my $timeout = 10;
        chomp($line);
        $item{text} .= $line."\n";
        $item{timeout} = Irssi::timeout_add($timeout, \&send_item, undef);
        Irssi::signal_stop();
    } else {
        Irssi::signal_stop();
        paste($line, $server, $witem);
    }
}


sub send_item {
    my $limit = Irssi::settings_get_int('multipaste_limit');
    my $server = Irssi::server_find_tag($item{server});
    my $channel = $server->window_item_find($item{channel});
    my $lines = scalar( split(/\n/, $item{text}) );
    if ($limit > 0 && $lines > $limit) {
	unless ($item{confirmed}) {
	    $channel->print('%B>>%n Do you want to paste '.$lines.' lines? Enter "/multipaste" to proceed', MSGLEVEL_CLIENTCRAP);
	    $item{waiting} = 1;
	    Irssi::timeout_remove($item{timeout});
	    return;
	}
    }
    my $prefix = Irssi::settings_get_str('multipaste_prefix');
    my $prefix2 = '';
    $prefix = $item{prefix}.': '.$prefix if $item{prefix};
    $prefix2 = $item{prefix}.': ' if $item{prefix};
    if (scalar( split(/\n/, $item{text}) ) > 1) {
	#Irssi::command("BIND tab word_completion");
	my $embrace = Irssi::settings_get_bool('multipaste_embrace');
	$server->command('MSG -- '.$channel->{name}.' '.$prefix2.',--8<-') if $embrace;
	foreach (split(/\n/, $item{text})) {
	    $server->command('MSG -- '.$channel->{name}.' '.$prefix.$_);
	}
	$server->command('MSG -- '.$channel->{name}.' '.$prefix2.'`-->8-') if $embrace;
    } else {
	my $text = join("", split(/\n/, $item{text}));
	my $prefix = $item{prefix} ? $item{prefix}.': ' : '';
	unless ($prefix.$text eq "\n") {
	    $server->command('MSG -- '.$channel->{name}.' '.$prefix.$text);
	}
    }
    Irssi::timeout_remove($item{timeout});
    %item = ();
}

sub paste ($$$) {
    my ($args, $server, $witem) = @_;
    return unless ref $witem;
    return if (%item);
    chomp($args);
    my $timeout = 10;
    if ($args =~ /^(.+?): (.*)/ && $witem->{type} eq 'CHANNEL' && $witem->nick_find($1)) {
	$item{prefix} = $1;
	$item{text} .= $2."\n";
    } else {
	$item{text} .= $args."\n";
    }
    $item{server} = $server->{tag};
    $item{channel} = $witem->{name};
    $item{timeout} = Irssi::timeout_add($timeout, \&send_item, undef);
}

sub cmd_multipaste ($$$) {
    my ($args, $server, $witem) = @_;
    return unless (%item && $item{waiting});
    $item{confirmed} = 1;
    send_item();
}


sub sig_word_complete ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    my $lines = scalar( split(/\n/, $item{text}) );
    if (%item && ( not $item{waiting} ) ) {
	push @$list, $linestart.$word.'    ';
	Irssi::signal_stop();
    }
}

Irssi::settings_add_bool($IRSSI{name}, 'multipaste_auto', 1);
Irssi::settings_add_int($IRSSI{name}, 'multipaste_limit', 0);
Irssi::settings_add_bool($IRSSI{name}, 'multipaste_embrace', 1);
Irssi::settings_add_str($IRSSI{name}, 'multipaste_prefix', '|');
Irssi::command_bind('multipaste', \&cmd_multipaste);
Irssi::signal_add('send text', 'sig_send_text');
Irssi::signal_add('send command', 'sig_send_command');
Irssi::signal_add_first('complete word', 'sig_word_complete');

print CLIENTCRAP "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded";
