# by Stefan 'tommie' Tomanek

use strict;

use Irssi 20020324;
use Irssi::TextUI;
use Crypt::CBC;
use Digest::MD5 qw(md5 md5_hex md5_base64);;

use vars qw($VERSION %IRSSI);
$VERSION = '2008051101';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'IRCSec',
    description => 'secures your conversation',
    license     => 'GPLv2',
    changed     => $VERSION,
    modules     => 'Crypt::CBC Digest::MD5',
    sbitems     => 'ircsec',
    commands	=> "ircsec",
    
);

use vars qw(%channels);

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
    my $help=$IRSSI{name}." ".$VERSION."
/ircsec secure <key>
    Encrypt and decrypt conversation in current channel/query with <key>
/ircsec unlock
    Disable de/encryption
/ircsec toggle
    Temporary dis- or enable security
";
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box($IRSSI{name}." help", $text, "help", 1) ;
}


sub encrypt ($$$) {
    my ($text, $key, $algo) = @_;
    my $cipher;
    eval {
       $cipher = Crypt::CBC->new( -key             => $key,
                                  -cipher          => $algo,
                                  -iv              => '$KJh#(}q',
                                  -literal_key     => 0,
                                  -padding         => 'space',
                                  -header          => 'randomiv'
                                );

    };
    return unless $cipher;
    my $checksum = md5_base64($text);
    my $ciphertext = $cipher->encrypt_hex($text." ".$checksum);
    return $ciphertext;
}

sub decrypt ($$$) {
    my ($data, $key, $algo) = @_;
    my $cipher;
    eval {
       $cipher = Crypt::CBC->new( -key             => $key,
                                  -cipher          => $algo,
                                  -iv              => '$KJh#(}q',
                                  -literal_key     => 0,
                                  -padding         => 'space',
                                  -header          => 'randomiv'
				);

    };
    return unless $cipher;
    my $plaintext = $cipher->decrypt_hex($data);
    my ($text, $checksum) = $plaintext =~ /^(.*) (.*?)$/;
    if ($checksum eq md5_base64($text)) {
	return $text;
    } else {
	return undef;
    }
}

sub sig_send_text ($$$) {
    my ($line, $server, $witem) = @_;
    return unless ref $witem;
    my $tag = $witem->{server}->{tag};
    if (defined $channels{$tag}{$witem->{name}} && $channels{$tag}{$witem->{name}}{active}) {
	my $key = $channels{$tag}{$witem->{name}}{key};
	Irssi::signal_stop();
	my $cipher = Irssi::settings_get_str('ircsec_default_cipher');
	my $crypt = encrypt($line, $key, $cipher);
#	if (defined $crypt) {
	    Irssi::signal_continue("[IRCSec:".$cipher."] ".$crypt, $server, $witem);
#	} else {
#	    $witem->print("%R[IRCSec]>%n Unknown cipher method '".$cipher."'", MSGLEVEL_CLIENTCRAP);
#	}
    }
}

sub decode ($$$) {
    my ($server, $text, $target) = @_;
    return unless ($text =~ /^\[IRCSec(:(.*?))?\] ([\d\w]+)/);
    my $string = $3;
    my $cipher = $2;
    $cipher = Irssi::settings_get_str('ircsec_default_cipher') unless $cipher;
    my $witem = $server->window_item_find($target);
    return unless ref $witem;
    return unless defined $channels{$server->{tag}}{$target};
    my $key = $channels{$server->{tag}}{$target}{key};
    my $plain = decrypt($string, $key, $cipher);
    if (defined $plain) {
	$witem->print("%B[IRCSec:".$cipher."]>%n $plain", MSGLEVEL_CLIENTCRAP);
    } else {
	$witem->print("%R[IRCSec]>%n Unknown cipher method '".$cipher."' or wrong key", MSGLEVEL_CLIENTCRAP);
    }
}

sub sb_ircsec ($$) {
    my ($item, $get_size_only) = @_;
    my $win = !Irssi::active_win() ? undef : Irssi::active_win()->{active};
    my $line;
    if (ref $win && ($win->{type} eq "CHANNEL" || $win->{type} eq "QUERY")){
	my $name = $win->{name};
	my $tag = $win->{server}->{tag};
	if ($channels{$tag}{$name} && $channels{$tag}{$name}{active}) {
	    $line = "%G%Uo-m%U%n";
	} elsif ($channels{$tag}{$name}){
	    $line = "%Ro-m%n";
	}
    }
    my $format = "{sb ".$line."}";
    $item->{min_size} = $item->{max_size} = length($line);
    $item->default_handler($get_size_only, $format, 0, 1);
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub cmd_ircsec ($$$) { 
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if (@arg == 0 || $arg[0] eq 'help') {
	# do some stuff
	show_help();
    } elsif ($arg[0] eq 'secure') {
	shift @arg;
	return unless ref $witem;
	if (@arg) {
	    my $key = join(' ', @arg);
	    if (length($key) < 8) {
		$witem->print("%R>>%n Key must be a minimum of 8 characters", MSGLEVEL_CLIENTCRAP);
	    } else {
		$channels{$server->{tag}}{$witem->{name}}{key} = join(' ', @arg);
		$channels{$server->{tag}}{$witem->{name}}{active} = 1;
		$witem->print("%B>>%n %Go-m%n Conversation secured", MSGLEVEL_CLIENTCRAP);
	    }
	} else {
	    $witem->print("%R>>%n Please specify a key", MSGLEVEL_CLIENTCRAP);
	}
	Irssi::statusbar_items_redraw('ircsec');
    } elsif ($arg[0] eq 'unlock') {
	delete $channels{$server->{tag}}{$witem->{name}};
	$witem->print("%B>>%n %Ro-m%n Security disabled", MSGLEVEL_CLIENTCRAP);
	Irssi::statusbar_items_redraw('ircsec');
    } elsif ($arg[0] eq 'toggle') {
	return unless ref $witem;
	if ($channels{$server->{tag}}{$witem->{name}}) {
	    $channels{$server->{tag}}{$witem->{name}}{active} = not $channels{$server->{tag}}{$witem->{name}}{active};
	    Irssi::statusbar_items_redraw('ircsec');
	}
    }
}

Irssi::signal_add('message private', sub { decode($_[0], $_[1], $_[2]); });
Irssi::signal_add('message public', sub { decode($_[0], $_[1], $_[4]); });
Irssi::signal_add('message own_private', sub { decode($_[0], $_[1], $_[2]); });
Irssi::signal_add('message own_public', sub { decode($_[0], $_[1], $_[2]); });

Irssi::signal_add_first('send text', "sig_send_text");
Irssi::signal_add('window changed', sub { Irssi::statusbar_items_redraw('ircsec'); });
Irssi::signal_add('window item changed', sub { Irssi::statusbar_items_redraw('ircsec'); });

Irssi::statusbar_item_register('ircsec', 0, 'sb_ircsec');

Irssi::settings_add_str($IRSSI{name}, 'ircsec_default_cipher', 'Blowfish');

Irssi::command_bind('ircsec', \&cmd_ircsec);

foreach my $cmd ('unlock', 'secure', 'toggle') {
    Irssi::command_bind('ircsec '.$cmd => sub {
        cmd_ircsec("$cmd ".$_[0], $_[1], $_[2]); });
}

print CLIENTCRAP "%B>>%n ".$IRSSI{name}." ".$VERSION." loaded: /ircsec help for help";

