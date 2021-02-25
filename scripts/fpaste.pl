use strict;
use utf8;
use HTTP::Tiny;
use File::Glob ':bsd_glob';
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '0.02';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'fpaste',
    description	=> 'copy infos to fpaste',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2021-01-24',
    modules => 'HTTP::Tiny File::Glob',
    commands=> 'fpaste',
    selfcheckcmd=> 'fpaste -check',
);

my $help = << "END";
%9Name%9
  $IRSSI{name}
%9Version%9
  $VERSION
%9Syntax%9
  /$IRSSI{name} <-file <filename>> [-summary "summary"]
  /$IRSSI{name} <-command <command>> [-summary "summary"]
  /$IRSSI{name} <-sysinfo> [-summary "summary"]
%9description%9
  -file     paste the file to fpaste
  -command  run the command and paste the result
  -sysinfo  colletct system infos and load them up
  -check    self check
%9See also%9
  http://fpaste.scsys.co.uk/irssi
  https://github.com/rcaputo/bot-pastebot
END

my %fpaste_channels =(
	'#irssi'=>1,
	'#curl'=>1,
	'#ledgersmb'=>1,
	'#mojo'=>1,
	'#ospkg'=>1,
	'#perl'=>1,
	'#r'=>1,
	'#raku'=>1,
);

my $host="http://fpaste.scsys.co.uk";
my $url="$host/paste";

my $buffer;

sub fpasteurl {
	my ($res) = @_;
	if( $res->{content} =~ m#($host/\d+)#) {
		return $1;
	} else {
		return $res->{url};
	}
}

sub paste {
	my ($channel, $nick, $summary, $paste)= @_;
	my $ht = HTTP::Tiny->new(
		agent=>"irssi/$IRSSI{name} $VERSION");
	my $data= {
		channel=>$channel,
		nick=>$nick,
		summary=>$summary,
		paste=>$paste,
		'Paste it'=>'Paste it',
	};
	my $res =$ht->post_form($url, $data);
	return fpasteurl($res);
}

sub fslurp {
	my ($filename) =@_;
	$filename = bsd_glob $filename;
	if ( -e $filename ) {
		local $/;
		open my $fi,'<',$filename;
		my $data=<$fi>;
		close $fi;
		return $data;
	}
}

sub getsetting {
	my ($name)= @_;
	my $s=$name. ": ";
	$s .= Irssi::settings_get_str($name);
	$s .= "\n";
	return $s;
}

sub scripts {
	my %all;
	my $s;
	foreach (sort grep s/::$//, keys %Irssi::Script::) {
		no strict 'refs';
		my %info = %{ "Irssi::Script::${_}::IRSSI" };
		$info{version} = ${ "Irssi::Script::${_}::VERSION" };
		$all{$_}={%info};
	}
	foreach (sort keys %all) {
		$s .= sprintf "%-20s version: $all{$_}->{version}\n",$_;
	}
	return $s;
}

sub do_capture {
	my ($cmd, $witem) = @_;
	Irssi::signal_add_first('print text', 'sig_print_text');
	if (defined $witem) {
		$witem->command($cmd);
	} else {
		Irssi::command($cmd);
	}
	Irssi::signal_remove('print text', 'sig_print_text');
}

sub getbuf {
	my $s= $buffer;
	$buffer='';
	$s =~ s/^-!- //m;
	return $s;
}

sub sig_print_text {
	my ($text_dest, $str, $stripped_str) = @_;
	$buffer .= $stripped_str. "\n";
	Irssi::signal_stop;
}

sub sysinfo {
	my $info;
	my $irssi;
	$info .= "Irssi\n";
	do_capture('eval echo version: $J');
	$irssi .= getbuf();
	do_capture('eval echo release date: $V');
	$irssi .= getbuf();
	$irssi .= getsetting('term_charset');
	$irssi =~ s/^/  /mg;
	$info .= $irssi;
	#
	my $scr;
	$info .= "Scripts\n";
	$scr .= scripts();
	$scr =~ s/^/  /mg;
	$info .= $scr;
	#
	my $mod;
	$info .= "Modules\n";
	do_capture('load');
	$mod .= getbuf();
	$mod =~ s/^/  /mg;
	$info .= $mod;
	#
	$info .= "System\n";
	my $sys;
	$sys .= "Perl Version: $^V\n";
	$sys .= "OS Name: $^O\n";
	$sys .= "ENV TERM: $ENV{TERM}\n";
	$sys .= "ENV XTERM_LOCALE: $ENV{XTERM_LOCALE}\n";
	$sys .= "ENV LANG: $ENV{LANG}\n";
	if ($^O eq 'linux') {
		$sys .= ` uname -a`."\n";
		$sys .= `cat /etc/os-release`. "\n";
	}
	$sys =~ s/^/  /mg;
	$info .= $sys;
	return $info;
}

sub self_check {
	my ( $res ) = @_;
	my $s="ok";
	if ( $res !~ m/^http/ ) {
		$s= "Error: url ($res)";
	}
	Irssi::print("fpaste: selfcheck: $s");
	my $schs_version = $Irssi::Script::selfcheckhelperscript::VERSION;
	Irssi::command("selfcheckhelperscript $s") if ( defined $schs_version );
}

sub cmd {
	my ($args, $server, $witem)=@_;
	my ($opt, $arg) = Irssi::command_parse_options($IRSSI{name}, $args);
	my $channel='(none)';
	my ($nick, $result, $summary, $paste, $run, $check);
	my $serv= Irssi::active_server();
	if ( defined $serv ){ 
		$nick= $server->{nick};
	} else {
		$nick= Irssi::settings_get_str('nick');
	}
	if (defined $witem) {
		if ($witem->{type} eq 'CHANNEL') {
			if ( exists $fpaste_channels{$witem->{name}} ) {
				$channel=$witem->{name};
				$nick=$server->{nick};
			}
		}
	}
	if (exists $opt->{file}) {
		$summary=$opt->{file};
		$paste= fslurp($opt->{file});
		$run=1;
	}
	if (exists $opt->{command}) {
		$summary=$opt->{command};
		do_capture($opt->{command}, $witem);
		$paste=getbuf();
		$run=1;
	}
	if (exists $opt->{sysinfo}) {
		$summary='sysinfo';
		$paste=sysinfo();
		$run=1;
	}
	if (exists $opt->{summary}) {
		$summary=$opt->{summary};
	}
	if (exists $opt->{check}) {
		$summary='check';
		$paste=sysinfo();
		$run=1;
		$check=1;
	}
	if ( defined $run ) {
		$result= paste($channel, $nick, $summary, $paste);
		if ( $check == 1 ) {
			self_check($result);
			$check=0;
		}
		if (defined $witem) {
			$witem->print($result, MSGLEVEL_CLIENTCRAP);
		} else {
			Irssi::print($result, MSGLEVEL_CLIENTCRAP);
		}
	} else {
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
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

Irssi::command_bind($IRSSI{name}, \&cmd);
Irssi::command_bind('help', \&cmd_help);
Irssi::command_set_options($IRSSI{name}, "+file +command sysinfo +summary help check");
