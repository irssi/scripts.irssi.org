use strict;
use warnings;
use Irssi;
use Irssi::TextUI;
use Hash::Util qw();
our $VERSION = '0.3'; # 8a7f8770be646c3
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'linebuffer',
    description => 'dump the linebuffer content',
    license     => 'GNU GPLv2 or later',
   );

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^dumplines *$/i) {
        print CLIENTCRAP <<HELP

DUMPLINES [-file <filename>] [-format] [-ids] [-levels[-prepend|-hex]] [-time] [<count> [<refnum>]]

    Dump the content of the line buffer to a window or file.

    -file:   Output to this file.
    -format: Format the text output.
    -ids:    Print line IDs.
    -levels: Print levels. -prepend: before text, -hex: as hex value
    -time:   Print time stamp.
    count:   Number of lines to reproduce.
    refnum:  Specifies the window to dump.
HELP

    }
}

{
    my %control2format_d = (
	'a' => 'F',
	'c' => '_',
	'e' => '|',
	'i' => '#',
	'f' => 'I',
	'g' => 'n',
       );
    my %control2format_c = (
	"\c_" => 'U',
	"\cV" => '8',
       );
    my %base_bg = (
	'0' => '0',
	'1' => '4',
	'2' => '2',
	'3' => '6',
	'4' => '1',
	'5' => '5',
	'6' => '3',
	'7' => '7',
	'8' => 'x08',
	'9' => 'x09',
	':' => 'x0a',
	';' => 'x0b',
	'<' => 'x0c',
	'=' => 'x0d',
	'>' => 'x0e',
	'?' => 'x0f',
       );
    my %base_fg = (
	'0' => 'k',
	'1' => 'b',
	'2' => 'g',
	'3' => 'c',
	'4' => 'r',
	'5' => 'm',		# p
	'6' => 'y',
	'7' => 'w',
	'8' => 'K',
	'9' => 'B',
	':' => 'G',
	';' => 'C',
	'<' => 'R',
	'=' => 'M',		# P
	'>' => 'Y',
	'?' => 'W',
       );

    my $to_true_color = sub {
	my (@rgbx) = map { ord } @_;
	$rgbx[3] -= 0x20;
	for (my $i = 0; $i < 3; ++$i) {
	    if ($rgbx[3] & (0x10 << $i)) {
		$rgbx[$i] -= 0x20;
	    }
	}
	my $color = $rgbx[0] << 16 | $rgbx[1] << 8 | $rgbx[2];
	($rgbx[3] & 0x1 ? 'z' : 'Z') . sprintf '%06X', $color;
    };

    my %ext_color_off = (
	'.' =>  [0, 0x10],
	'-' =>  [0, 0x60],
	',' =>  [0, 0xb0],
	'+' =>  [1, 0x10],
	"'" =>  [1, 0x60],
	'&' =>  [1, 0xb0],
       );
    my @ext_color_al = (0..9, 'A' .. 'Z');
    my $to_ext_color = sub {
	my ($sig, $chr) = @_;
	my ($bg, $off) = @{ $ext_color_off{$sig} };
	my $color = $off - 0x3f + ord $chr;
	$color += 10 if $color > 214;
	($bg ? 'x' : 'X') . (1+int($color / 36)) . $ext_color_al[$color % 36];
    };
    sub control2format {
	my $line = shift;
	$line =~ s/%/%%/g;
	$line =~ s{( \c_ | \cV )
	       |(?:\cD(?:
			   ([aceigf])
		       |(?:\#(.)(.)(.)(.))
		       |(?:([-.,+'&])(.))
		       |(?:(?:/|([0-?]))(?:/|([/0-?])))
		       |\xff/|(/\xff)
		   ))
	      }{
		  '%'.(defined $1  ? $control2format_c{$1}         :
		       defined $2  ? $control2format_d{$2}         :
		       defined $6  ? $to_true_color->($3,$4,$5,$6) :
		       defined $8  ? $to_ext_color->($7,$8)        :
		       defined $10 ? ($base_bg{$10} . (defined $9 ? '%'.$base_fg{$9} : '')) :
		       defined $9  ? $base_fg{$9} :
		       defined $11 ? 'o' : 'n')
	      }gex;
	$line
    }
}

sub simpletime {
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime $_[0];
    sprintf "%04d"."%02d"x5, 1900+$year, 1+$mon, $mday, $hour, $min, $sec;
}

sub prt_report {
    my $fh = shift;
    if ($fh->isa('Irssi::UI::Window')) {
	for (split "\n", (join $,//'', @_)) {
	    my $line;
	    for (split "\t") {
		if (defined $line) {
		    $line .= ' ' x (5 - (length $line) % 6);
		    $line .= ' ';
		}
		$line .= $_;
	    }
	    $line .= '';
	    $fh->print($line, MSGLEVEL_NEVER);
	}
    }
    else {
	$fh->print(@_);
    }
}

sub dump_lines {
    my ($data, $server, $item) = @_;
    my ($args, $rest) = Irssi::command_parse_options('dumplines', $data);
    ref $args or return;
    my $win = Irssi::active_win;
    my ($count, $winnum) = $data =~ /(-?\d+)/g;
    if (defined $winnum) {
	$win = Irssi::window_find_refnum($winnum) // do {
	    print CLIENTERROR "Window #$winnum not found";
	    return;
	};
    }
    my $fh;
    my $is_file;
    if (defined $args->{file}) {
	unless (length $args->{file}) {
	    print CLIENTERROR "Missing argument to option: file";
	    return;
	}
	open $fh, '>', $args->{file} or do {
	    print CLIENTERROR "Error opening ".$args->{file}.": $!";
	    return;
	};
	$is_file = 1;
    }
    else {
	$fh = Irssi::Windowitem::window_create(undef, 0);
	$fh->command('^scrollback home');
	$fh->command('^scrollback clear');
	$fh->command('^window scroll off');
    }
    prt_report($fh, "\n==========\nwindow: ", $win->{refnum}, "\n");
    my $view = $win->view;
    my $lclength = length $view->{buffer}{lines_count};
    $lclength = 3 if $lclength < 3;
    my $padlen = $lclength;
    my $hdr = sprintf "%${lclength}s", " # ";
    my $hllen = length sprintf '%x', MSGLEVEL_LASTLOG << 1;
                                                                        #123456789012345
    if (defined $args->{ids})          { $padlen += 10;         $hdr .= '|    ID   ' }
    if (defined $args->{time})         { $padlen += 15;         $hdr .= '| date & time  ' }
    if (defined $args->{'levels-hex'}) { $padlen += $hllen + 1; $hdr .= sprintf "|%${hllen}s", ' levels ' }

    prt_report($fh,
	" "x$padlen,"\t/buffer first line\n",
	" "x$padlen,"\t|/buffer cur line\n",
	" "x$padlen,"\t||/bottom start line\n",
	$hdr,"\t|||/start line\n");
    my $j = 1;
    $count = $view->{height} unless $count;
    my $start_line;
    if ($count < 0) {
	$start_line = $view->get_lines;
    }
    else {
	$j = $view->{buffer}{lines_count} - $count + 1;
	$j = 1 if $j < 1;
	$start_line = $view->{buffer}{cur_line};
	for (my $line = $start_line;
	     $line && $count--;
	     ($start_line, $line) = ($line, $line->prev))
	    {}
    }
    for (my $line = $start_line; $line; $line = $line->next) {
	my $i = 0;
	my $t = sprintf "%${lclength}d", $j++;
	$t .= sprintf " %9d", $line->{_irssi} if defined $args->{ids};
	$t .= ' '.simpletime($line->{info}{time}) if defined $args->{time};
	$t .= sprintf " %${hllen}x", $line->{info}{level} if defined $args->{'levels-hex'};
	$t .= "\t" . (join '', map {;++$i; $_->{_irssi} == $line->{_irssi} ? $i : ' ' }
			     $view->{buffer}{first_line}, $view->{buffer}{cur_line},
			 $view->{bottom_startline}, $view->{startline});
	$t .= "\t";
	my $text = $line->get_text(1);
	if (defined $args->{format}) {
	    if (!$is_file) {
		$text = control2format($text);
		$text =~ s{(%.)}{ $1 eq "%o" ? "\cD/\xff" : $1 }ge;
	    }
	}
	else {
	    $text = control2format($text);
	    if (!$is_file) {
		$text =~ s/%/%%/g;
	    }
	}
	my $lst;
	if (defined $args->{'levels-prepend'} || defined $args->{levels}) {
	    my $levels = Irssi::bits2level($line->{info}{level});
	    if (!$is_file) {
		$lst = "%n%r[%n$levels%r]%n";
	    }
	    else {
		$lst = "[$levels]";
	    }
	}
	$t .= "$lst\t" if defined $args->{'levels-prepend'};
	$t .= $text;
	$t .= "\t$lst" if defined $args->{levels};
	$t .= "\n";
	prt_report($fh, $t);
    }
    prt_report($fh, "----------\n", map { $_ // 'NULL' }
	"view w", $view->{width}, " h", $view->{height}, " scroll ", $view->{scroll}, "\n",
	       "     ypos ", $view->{ypos}, "\n",
	"     bottom subline ", $view->{bottom_subline}, " subline ", $view->{subline}, ", is bottom: ", $view->{bottom}, "\n",
	    "buffer: lines count ", $view->{buffer}{lines_count}, ", was last eol: ", $view->{buffer}{last_eol}, "\n",
		"win: last line ", simpletime($win->{last_line}),"\n\n");
}


Irssi::command_bind('dumplines' => 'dump_lines');
Irssi::command_set_options('dumplines' => 'format ids time levels levels-prepend levels-hex 1 -file');
Irssi::command_bind_last('help' => 'cmd_help');
