use strict;
use utf8;
use vars qw($VERSION %IRSSI);

use Irssi;
use XML::LibXML::Simple   qw(XMLin);
use YAML::XS qw/Dump DumpFile LoadFile/;
use DateTime;
use DateTime::Format::Strptime;
use File::Glob qw/:bsd_glob/;
use Text::Wrap;

$VERSION = '0.02';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'ontv2',
    description	=> "turns irssi into a tv program guide",
    license	=> 'GPLv2',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2021-01-10',
    modules => 'XML::LibXML::Simple YAML::XS DateTime DateTime::Format::Strptime File::Glob Text::Wrap',
    commands=> 'ontv2',
    selfcheckcmd=> 'ontv2 check',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9description%9
  $IRSSI{description}
/ontv2 (current)
    List the current tv program
/ontv2 search <query>
    Query the program guide for a show
/ontv2 next
    Show what'S next on TV
/ontv2 tonight
    List tonight's program
/ontv2 watching <station>
    Display what's on <station>
/ontv2 check
    helper for self check the script
/ontv2 read
    read the prgram from file
/ontv2 #xx
    show details

\$ tv_grab_ch_search --output ~/.xmltv/current.xml --days 2

    based on an idea by Stefan 'tommie' Tomanek
%9See also%9
    http://wiki.xmltv.org/index.php/XMLTVProject
END

my $xmltv_file;
my $data;
my $test_str;
my ($prg_count, @prg_list);
my $tf=DateTime::Format::Strptime->new(pattern=>"%Y%m%d%H%M%S %z");
my $localTZ =DateTime::TimeZone->new( name => 'local' );

sub print_head {
	my ($title)= @_;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'head_theme', $title);
}

sub print_footer {
	my ($footer)= @_;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'footer_theme', $footer);
}

sub clear_prg {
	@prg_list=();
	$prg_count=0;
}

sub to_prg_short {
	my ($num)= @_;
	my @cl= (0 .. 9, 'A' .. 'Z');
	my $d= scalar @cl;
	my $s;
	while ($num > 0 ) {
		my $di= $num % $d;
		$num = int ( $num / $d);
		$s .= $cl[$di];
	}
	$s = "#$s";
	return $s;
}

sub to_prg_num {
	my ($short)= @_;
	substr $short, 0, 1, '';
	$short =uc $short;
	my $num=0;
	my @cl= (0 .. 9, 'A' .. 'Z');
	my $d= scalar @cl;
	my %cl;
	my $c=0;
	foreach ( @cl ) {
		$cl{$_}=$c;
		$c++;
	}
	while ( length($short) > 0 ) {
		my $s = substr $short, -1, 1, '';
		$num *= $d;
		$num += $cl{$s};
	}
	return $num;
}

sub print_prg {
	my ($witem, $pn)=@_;
	my $c=Irssi::active_win()->{width}-20;
	local $Text::Wrap::columns = $c;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'title_theme',
		$pn->{begin}->strftime('%H:%M'), $pn->{ende}->strftime('%H:%M'), 
		$pn->{title}->{content},
		$data->{channel}->{$pn->{channel}}->{'display-name'}->{content},
		to_prg_short($prg_count),
	);
	push @prg_list, $pn;
	$prg_count++;
	if ($pn->{'sub-title'}->{content} ne '') {
		my @l = split(/\n/, wrap(' ', ' ' ,$pn->{'sub-title'}->{content}));
		foreach my $l (@l) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'subtitle_theme', $l,);
		}
	}
}

sub print_prg_long {
	my ($witem, $pn)=@_;
	my $c=Irssi::active_win()->{width}-20;
	local $Text::Wrap::columns = $c;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'title_theme',
		$pn->{begin}->strftime('%H:%M'), $pn->{ende}->strftime('%H:%M'),
		$pn->{title}->{content},
		$data->{channel}->{$pn->{channel}}->{'display-name'}->{content},
	);
	if ($pn->{'sub-title'}->{content} ne '') {
		my @l = split(/\n/, wrap(' ', ' ' ,$pn->{'sub-title'}->{content}));
		foreach my $l (@l) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'subtitle_theme', $l,);
		}
	}
	if ($pn->{'desc'}->{content} ne '') {
		my @l = split(/\n/, wrap(' ', ' ' ,$pn->{'desc'}->{content}));
		foreach my $l (@l) {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'subtitle_theme', $l,);
		}
	}
	if ( exists $pn->{category} ) {
		if (ref($pn->{category}) eq 'HASH') {
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tail_theme',
				$pn->{category}->{content},
			);
		}
		if (ref($pn->{category}) eq 'ARRAY') {
			my $s;
			foreach (@{$pn->{category}}) {
				$s .= $_->{content}." ";
			}
			Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'tail_theme', $s);
		}
	}
}

sub cmd_read_xmltv {
	my ($args, $server, $witem)=@_;
	if ( -e $xmltv_file ) {
		$data = XMLin $xmltv_file;
	} else {
		Irssi::print("ontv: Error file not found ($xmltv_file)");
	}
	foreach my $pn ( @{ $data->{programme} } ) {
		my $start= $tf->parse_datetime($pn->{start});
		$pn->{begin}= $start;
		my $stop= $tf->parse_datetime($pn->{stop});
		$pn->{ende}= $stop;
	}
}

sub cmd_search {
	my ($args, $server, $witem)=@_;
	$args =~ s/^search//;
	$args =~ s/^\s+//;
	$args =~ s/\s+$//;
	clear_prg();
	my $now = DateTime->now();
	my $nowp = $now->clone->add( hours=>12 );
	print_head("ontv2 search ($args)");
	foreach my $pn ( @{ $data->{programme} } ) {
		if ( $pn->{title}->{content}=~ m/\Q$args\E/i){
			if ( $pn->{ende}->is_between( $now ,$nowp ) || 
					$pn->{begin}->is_between( $now ,$nowp )) {
				print_prg($witem, $pn);
			}
		}
	}
	print_footer("ontv2 search");
}

sub cmd_watching {
	my ($args, $server, $witem)=@_;
	$args =~ s/^watching//;
	$args =~ s/^\s+//;
	$args =~ s/\s+$//;
	clear_prg();
	my $now = DateTime->now();
	my $nowp = $now->clone->add( hours=>12 );
	print_head("ontv2 watching ($args)");
	foreach my $pn ( @{ $data->{programme} } ) {
		if ( $data->{channel}->{$pn->{channel}}->{'display-name'}->{content}=~ m/\Q$args\E/i){
			if ( $pn->{ende}->is_between( $now ,$nowp ) || 
					$pn->{begin}->is_between( $now ,$nowp )) {
				print_prg($witem, $pn);
			}
		}
	}
	print_footer("ontv2 watching");
}

sub cmd_next {
	my ($args, $server, $witem)=@_;
	clear_prg();
	my $now = DateTime->now();
	$now->add( minutes=>5);
	my $nowp = $now->clone->add( minutes=>30 );
	print_head("ontv2 next ($args)");
	foreach my $pn ( @{ $data->{programme} } ) {
		if ( $pn->{begin}->is_between( $now ,$nowp )) {
			print_prg($witem, $pn);
		}
	}
	print_footer("ontv2 next");
}


sub cmd_tonight {
	my ($args, $server, $witem)=@_;
	clear_prg();
	my $now = DateTime->now();
	$now->set_time_zone($localTZ);
	$now->set_hour(20);
	$now->set_minute(10);
	my $nowp = $now->clone;
	$nowp->set_hour(20);
	$nowp->set_minute(30);
	print_head("ontv2 tonight ($args)");
	foreach my $pn ( @{ $data->{programme} } ) {
		if ( $pn->{begin}->is_between( $now ,$nowp )) {
			print_prg($witem, $pn);
		}
	}
	print_footer("ontv2 tonight");
}

sub cmd_check {
	my ($args, $server, $witem)=@_;
	my $s="ok";
	my $channelc=scalar keys %{$data->{channel}};
	my $prgc=scalar @{$data->{programme}};
	Irssi::print("Channel: $channelc");
	if ( $channelc < 100 ) {
		$s="Error: channel count" ;
		Irssi::print($s);
	}
	Irssi::print("Programme: $prgc");
	if ( $prgc < 1000 ) {
		$s="Error: programme count"; 
		Irssi::print($s);
	}
	my $schs_version = $Irssi::Script::selfcheckhelperscript::VERSION;
	Irssi::command("selfcheckhelperscript $s") if ( defined $schs_version );
}

sub cmd_now {
	my ($args, $server, $witem)=@_;
	clear_prg();
	my $now = DateTime->now();
	print_head("ontv2 now");
	foreach my $pn ( @{ $data->{programme} } ) {
		if ( $now->is_between( $pn->{begin}, $pn->{ende} ) ){
			print_prg($witem, $pn);
		}
	}
	print_footer("ontv2 now");
}

sub cmd_long {
	my ($args, $server, $witem)=@_;
	$args=~s/\s//g;
	my $num= to_prg_num($args);
	my $pn=$prg_list[$num];
	if (defined $pn ) {
		print_prg_long($witem, $pn );
	}
}

sub cmd {
	my ($args, $server, $witem)=@_;
	if ($args =~ m/^read/) {
		cmd_read_xmltv($args, $server, $witem);
	} elsif ($args =~ m/^search/) {
		cmd_search($args, $server, $witem);
	} elsif ($args =~ m/^watching/) {
		cmd_watching($args, $server, $witem);
	} elsif ($args =~ m/^tonight/) {
		cmd_tonight($args, $server, $witem);
	} elsif ($args =~ m/^next/) {
		cmd_next($args, $server, $witem);
	} elsif ($args =~ m/^check/) {
		cmd_check($args, $server, $witem);
	} elsif ($args =~ m/^#/) {
		cmd_long($args, $server, $witem);
	} else {
		cmd_now($args, $server, $witem);
	}
}

sub cmd_help {
	my ($args, $server, $witem)=@_;
	$args=~ s/\s+//g;
	if ($IRSSI{name} eq $args) {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop();
	}
}

sub sig_setup_changed {
	$xmltv_file= bsd_glob(Irssi::settings_get_str($IRSSI{name}.'_xmltv_file'));
}

my $twidth= Irssi::active_win()->{width}-3*6-20-4;
Irssi::theme_register([
	'title_theme', "\$0 \$1 {hilight \$[$twidth]2} \$[18]3 \$[-4]4",
	'subtitle_theme', ' 'x12 .'$0',
	'tail_theme', '{hilight $0}',
	'head_theme',   '%R,--[%n%9%U $0 %U%9%R]%n',
	'footer_theme', '%R`--<%n $0 %R>->%n',
]);

Irssi::signal_add('setup changed', \&sig_setup_changed);

Irssi::settings_add_str($IRSSI{name} ,$IRSSI{name}.'_xmltv_file', '~/.xmltv/current.xml');

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind("$IRSSI{name} read", \&cmd);
Irssi::command_bind("$IRSSI{name} search", \&cmd);
Irssi::command_bind("$IRSSI{name} watching", \&cmd);
Irssi::command_bind("$IRSSI{name} tonight", \&cmd);
Irssi::command_bind("$IRSSI{name} next", \&cmd);
Irssi::command_bind('help', \&cmd_help);

sig_setup_changed();
cmd_read_xmltv();
