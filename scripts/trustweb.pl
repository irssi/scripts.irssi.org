use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003020801";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "TrustWeb",
    description => "Illustrates the trust between ops",
    license     => "GPLv2",
    modules     => "Data::Dumper IO::File POSIX",
    changed     => "$VERSION",
    commands	=> "trustweb"
);


use Irssi 20020324;
use Irssi::TextUI;
use Data::Dumper;
use IO::File;
use POSIX;
use vars qw(%database);

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }                                                                               $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub show_help() {
    my $help = $IRSSI{name}." ".$VERSION."
/trustweb help
    Display this help
/trustweb save/load
    Load or save the database
/trustweb show <nick>
    Display the trust for <nick>
/trustweb scan
    Scan all buffers for modechanges
/trustweb trace <nick1> <nick2>
    Search the shortest connection between two nicks
/trustweb merge <nick1> <nick2>
    Move all trustdata from nick1 to nick2
";
    my $text = "";
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}, $text, "Help", 1);
}


sub save_db {
    my $filename = Irssi::settings_get_str('trustweb_db_file');
    my $io = new IO::File $filename, "w";
    if (defined $io) {
	my $dumper = Data::Dumper->new([\%database]);
	$dumper->Purity(1)->Deepcopy(1);
	$io->print($dumper->Dump);
	$io->close;
    }
    print CLIENTCRAP "%B>>%n Trustweb database saved to ".$filename;
}

sub load_db {
    my $filename = Irssi::settings_get_str('trustweb_db_file');
    my $io = new IO::File $filename, "r";
    if (defined $io) {
	no strict 'vars';
	my $text;
	$text .= $_ foreach ($io->getlines);
	my $database = eval "$text";
	%database = %$database if ref $database;
    }
    print CLIENTCRAP "%B>>%n Trustweb database loaded from ".$filename;
}

sub scan_buffers {
    foreach my $channel (Irssi::channels()) {
    	my $win = $channel->window();
	my $name = $channel->{name};
	my $server = $channel->{server};
	my $view = $win->view();
	my $line = $view->get_lines();
	my $lines  = 0;
	while (defined $line) {
	    my $text = $line->get_text(0);
	    if ($line->{info}{level} == 2048) {
		if ($text =~ /\[([\+\-].*?)\] by (.*)/) {
		    sig_message_irc_mode($server, $name, $2, undef, $1);
		}
	    }
	    $line = $line->next;
	    $lines++;
	}
    }
}

sub sig_message_irc_mode ($$$$$) {
    my ($server, $channel, $nick, $addr, $mode) = @_;
    return if ($nick =~ /\./);
    my $state;
    my @pipe;
    my %result;
    my $tag = lc $server->{tag};
    my ($modes, $nicks) = split(/ /, $mode, 2);
    foreach (split(//, $modes)) {
	if ($_ eq '+' || $_ eq '-') {
	    $state = $_;
	} else {
	    push @pipe, $state.$_;
	}
    }

    foreach (split(/ /, $nicks)) {
	my $change = shift(@pipe);
	if ($change eq '+o') {
	    foreach my $active (split /, ?/, $nick) {
		$database{$tag}{lc $active}{lc $_} = 1;
	    }
	} elsif ($change eq '-o') {
	    foreach my $active (split /, ?/, $nick) {
		$database{$tag}{lc $active}{lc $_} = -1;
	    }
	}
    }
}

sub sig_nicklist_changed ($$$) {
    my ($channel, $nick, $old) = @_;
    my $server = $channel->{server};
    my $new = lc $nick->{nick};
    my $tag = lc $server->{tag};
    merge_nicks($tag, $old, $new);
}

sub merge_nicks ($$$) {
    my ($tag, $old, $new) = @_;
    $tag = lc $tag;
    $new = lc $new;
    $old = lc $old;
    return if $old eq $new;
    if (defined $database{$tag}{$old}) {
	foreach (keys %{ $database{$tag}{$old} }) {
	    $database{$tag}{$new}{$_} = $database{$tag}{$old}{$_};
	}
	delete $database{$tag}{$old}
    }
    foreach (keys %{ $database{$tag} }) {
	if (defined $database{$tag}{$_}{$old}) {
	    $database{$tag}{$_}{$new} = $database{$tag}{$_}{$old};
	    delete $database{$tag}{$_}{$old};
	}
    }
}

sub show_trust ($$) {
    my ($nicks, $tag) = @_;
    my $text;
    foreach (@$nicks) {
	$text .= draw_trust($_, $tag);
    }
    print CLIENTCRAP &draw_box('TrustWeb', $text, $tag, 1);
}

sub draw_trust ($$) {
    my ($nick, $tag) = @_;
    my (@opfrom,  @opto);
    my $text;
    #return unless $database{$nick};
    my ($maxfrom, $maxto)  = (0, 0);
    my $distrust = Irssi::settings_get_bool('trustweb_show_distrust');
    foreach (sort keys %{ $database{$tag} }) {
	next unless defined $database{$tag}{$_}{lc $nick};
	push @opfrom, [$_,1] if $database{$tag}{$_}{lc $nick} > 0;
	push @opfrom, [$_,-1] if ($database{$tag}{$_}{lc $nick} < 0 && $distrust);
	$maxfrom = length($_) if length($_) > $maxfrom;
    }
    if (defined $database{$tag}{lc $nick}) {
	foreach (sort keys %{$database{$tag}{lc $nick}}) {
	    push @opto, [$_,1] if $database{$tag}{lc $nick}{$_} > 0;
	    push @opto, [$_,-1] if ($database{$tag}{lc $nick}{$_} < 0 && $distrust);
	    $maxto = length($_) if length($_) > $maxto;
	}
    }
    my $items = @opfrom > @opto ? @opfrom-1 : @opto-1;
    my $i = 0;
    my $center = sprintf("%.0f", $items/2);
    $center = @opfrom-1 if (@opfrom && not(defined $opfrom[$center]));
    $center = @opto-1 if (@opto && not(defined $opto[$center]));
    foreach (0..$items) {
	my $line;
	if (defined $opfrom[$_]) {
	    $line .= '<'.$opfrom[$_][0];
	    $line .= ' ' x ($maxfrom - length($opfrom[$_][0]));
	    $line .= '>';
            $line .= '-' if $opfrom[$_][1] > 0;
            $line .= '%' if $opfrom[$_][1] < 0;
	    $line .= "," if $_ < $center;
	    $line .= "+" if $_ == $center;
	    $line .= "'" if $_ > $center;
	} else {
	    $line .= ' ' x ($maxfrom+4) if $maxfrom;
	}
	if ($_ == $center) {
	    $line .= '-' if @opfrom;
	    $line .= '(%9'.$nick.'%9)';
	    $line .= '-' if @opto;
	} else {
	    $line .= ' ' if @opfrom;
	    $line .= ' ' x (length($nick)+2);
	    $line .= ' ' if @opto;
	}
	if (defined $opto[$_]) {
            $line .= "," if $_ < $center;
            $line .= "+" if $_ == $center;
            $line .= "'" if $_ > $center;
	    $line .= '-' if $opto[$_][1] > 0;
	    $line .= '%' if $opto[$_][1] < 0;
	    $line .= '<'.$opto[$_][0];
	    $line .= ' ' x ($maxto - length($opto[$_][0]));
	    $line .= '>';
	} else {
	    $line .= ' ' x ($maxto+4) if $maxto;
	}
	$text .= $line."\n";
	$i++;
    }
    return $text;
}

sub bg_trace ($$$) {
    my ($tag, $from, $to) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    my $pid = fork();
    if ($pid > 0) {
	close $wh;
	Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($tag, $from, $to, $rh, \$pipetag);
        $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	my $result = walk($from, $to, $database{$tag}, {}, [], [], 0);
	my $dumper = Data::Dumper->new([$result]);
	$dumper->Purity(1)->Deepcopy(1);
	print($wh $dumper->Dump());
	close $wh;
	POSIX::_exit(1);
    }
}

sub pipe_input ($) {
    my ($tag, $from, $to, $rh, $pipetag) = @{$_[0]};
    my $text;
    $text .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    no strict 'vars';
    my $result = eval "$text";
    draw_trace($tag, $from, $to, $result);
}

sub walk ($$$$$$) {
    my ($pos, $goal, $data, $visited, $street, $ideal) = @_;
    my @road = @$street;
    
    return $ideal if $visited->{$pos};
    return $ideal if (@$ideal && not(Irssi::settings_get_bool('trustweb_trace_find_shortest_path')));
    return \@road if ($pos eq $goal);
    return $ideal if (@$ideal && @$street >= @$ideal);
    return $ideal if (Irssi::settings_get_int('trustweb_trace_max_depth') && @road > Irssi::settings_get_int('trustweb_trace_max_depth'));
    
    $visited->{$pos} = 1;
    my $nodistrust = not Irssi::settings_get_bool('trustweb_trace_distrust');
    foreach (keys %{ $data->{$pos} }) {
	next if ($data->{$pos}{$_} < 1 && $nodistrust);
	push @road, [ $_, 1, $data->{$pos}{$_} ];
	$ideal = walk($_, $goal, $data, $visited, \@road, $ideal);
	pop @road;
    }
    foreach (keys %$data) {
	next unless defined $data->{$_}{$pos};
	next if ($data->{$_}{$_} < 1 && $nodistrust);
	push @road, [ $_, 0, $data->{$_}{$pos} ];
	$ideal = walk($_, $goal, $data, $visited, \@road, $ideal);
	pop @road;
    }
    $visited->{$pos} = 0;
    return $ideal;
}


sub draw_trace ($$$$) {
    my ($tag, $from, $to, $route) = @_;
    my $line = "%B<<%n ";
    if (ref $route && @$route) {
	$line .= $from;
	foreach (@$route) {
	    if ($_->[1]) { 
		$line .= ' ';
		$line .= $_->[2] > 0 ? '=' : '%%';
		$line .= '> ';
	    } else {
		$line .= ' <';
		$line .= $_->[2] > 0 ? '=' : '%';
		$line .= ' ';
	    }
	    $line .= $_->[0];
	}
    } else {
	$line .= "No connection between ".$from." and ".$to." could be found.";
    }
    print $line;
}

sub pre_unload {
    save_db();
}

sub cmd_trustweb ($$$) {
    my ($args, $server, $witem) = @_;
    my $tag = ref $server ? lc $server->{tag} : lc Irssi::settings_get_str('trustweb_default_ircnet');
    my @arg = split(/ +/, $args);
    if (not(@arg) || $arg[0] eq 'help') {
	show_help();
    } elsif ($arg[0] eq 'scan') {
	scan_buffers();
	print CLIENTCRAP "%R>>%n All buffers scanned for modes";
    } elsif ($arg[0] eq 'show' && defined $arg[1]) {
	shift @arg;
	show_trust(\@arg, $tag);
    } elsif ($arg[0] eq 'save') {
	save_db;
    } elsif ($arg[0] eq 'load') {
	load_db;
    } elsif ($arg[0] eq 'trace' && defined $arg[1] && defined $arg[2]) {
	bg_trace($tag, lc $arg[1], lc $arg[2]);
	print CLIENTCRAP "%B>>%n Searching connection between ".$arg[1]." and ".$arg[2]."...";
    } elsif ($arg[0] eq 'merge' && defined $arg[1] && defined $arg[2]) {
	return unless ref $server;
	merge_nicks($server->{tag}, $arg[1], $arg[2]);
	print CLIENTCRAP "%B>>%n '".$arg[1]."' has been merged with '".$arg[2]."'";
    }
}

Irssi::settings_add_str($IRSSI{name}, 'trustweb_default_ircnet', '');
Irssi::settings_add_str($IRSSI{name}, 'trustweb_db_file', Irssi::get_irssi_dir()."/trustweb_database");
Irssi::settings_add_bool($IRSSI{name}, 'trustweb_show_distrust' , 1);

Irssi::settings_add_bool($IRSSI{name}, 'trustweb_trace_distrust' , 1);
Irssi::settings_add_bool($IRSSI{name}, 'trustweb_trace_find_shortest_path' , 1);
Irssi::settings_add_int($IRSSI{name}, 'trustweb_trace_max_depth' , 0);

Irssi::signal_add('setup saved', 'save_db');
Irssi::signal_add('message irc mode', \&sig_message_irc_mode);
Irssi::signal_add_first('nicklist changed', \&sig_nicklist_changed);

Irssi::command_bind('trustweb', \&cmd_trustweb);

foreach my $cmd ('save', 'load', 'scan', 'show', 'help', 'trace', 'merge') {
    Irssi::command_bind('trustweb '.$cmd =>
        sub { cmd_trustweb("$cmd ".$_[0], $_[1], $_[2]); } );
}

load_db();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /trustweb help for help';
