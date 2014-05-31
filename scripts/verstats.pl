use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "20030208";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "VerStats",
    description => "Draws a diagram of the used clients in a channel",
    license     => "GPLv2",
    url         => "http://scripts.irssi.org",
    changed     => "$VERSION",
    commands	=> "verstats"
);


use Irssi;

use vars qw(%clients $timeout);

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


sub sig_ctcp_reply_version ($$$$$) {
    my ($server, $args, $nick, $addr, $target) = @_;
    return unless $timeout;
    Irssi::timeout_remove($timeout);
    if ($args =~ /^(.*?)( |\/|$)/) {
	my $client = lc($1);
	$client =~ s/^[^\w]//;
	$client =~ s/%.//g;
	#$clients{$client} = 0 unless defined $clients{$client};
	push @{$clients{$client}}, $nick;
    }
    $timeout = Irssi::timeout_add(5000, \&finished, undef);
}

sub finished {
    my $max=0;
    foreach (keys %clients) {
	$max = @{$clients{$_}} if $max < @{$clients{$_}};
    }
    return if $max == 0;
    my $width = 60;
    my $block = $width/$max;
    my $text;
    foreach (sort {@{$clients{$b}} <=> @{$clients{$a}}} keys %clients) {
	s/%/%%/g;
	$text .= "'".$_."'".': '.@{$clients{$_}}."\n";
	my $bar = '#'x(($block * @{$clients{$_}})-1);
	$text .= $bar.">\n";
	#$text .= $_.' ' foreach (@{$clients{$_}});
	#$text .= "\n";
    }
    %clients = ();
    print CLIENTCRAP draw_box('VerStats', $text, 'stats', 1);
    Irssi::timeout_remove($timeout);
    $timeout = undef;
}

sub cmd_verstats ($$$) {
    my ($args, $server, $witem) = @_;
    return unless ($server && ref $witem && $witem->{type} eq 'CHANNEL');
    $witem->command('ctcp '.$witem->{name}.' version');
    $timeout = Irssi::timeout_add(5000, \&finished, undef)
}

Irssi::signal_add('ctcp reply version' => \&sig_ctcp_reply_version);
Irssi::command_bind('verstats' => \&cmd_verstats);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded';
