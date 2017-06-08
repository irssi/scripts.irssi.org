use strict;
use warnings;

our $VERSION = '0.3.7'; # 0887f6607e62b30
our %IRSSI = (
    authors     => 'Nei',
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name        => 'colorize_nicks',
    description => 'Colourise mention of nicks in the message body.',
    license     => 'GNU GPLv2 or later',
   );

# inspired by mrwright's nickcolor.pl and xt's colorize_nicks.pl
#
# you need nickcolor_expando or another nickcolor script providing the
# get_nick_color2 function

# Usage
# =====
# should start working once loaded

# Options
# =======
# /set colorize_nicks_skip_formats <num>
# * how many forms (blocks of irssi format codes or non-letters) to
#   skip at the beginning of line before starting to colourise nicks
#   (you usually want to skip the speaker's nick itself and the
#   timestamp)
#
# /set colorize_nicks_ignore_list <words to ignore>
# * list of nicks (words) that should never be coloured
#
# /set colorize_nicks_repeat_formats <ON|OFF>
# * repeat the format stack from the beginning of line, enable when
#   using per-line colours and colorize_nicks breaks it

# Commands
# ========
# you can use this alias:
#
# /alias nocolorize set colorize_nicks_ignore_list $colorize_nicks_ignore_list
#
# /nocolorize <nick>
# * quickly add nick to the bad word list of nicks that should not be
#   colourised

no warnings 'redefine';
use Irssi;

my $irssi_mumbo = qr/\cD[`-i]|\cD[&-@\xff]./;

my $nickchar = qr/[\]\[[:alnum:]\\|`^{}_-]/;
my $nick_pat = qr/($nickchar+)/;

my @ignore_list;

my $colourer_script;

sub prt_text_issue {
    my ( $dest,
	 $text,
	 $stripped
	) = @_;
    my $colourer;
    unless ($colourer_script
		&& ($colourer = "Irssi::Script::$colourer_script"->can('get_nick_color2'))) {
	for my $script (sort map { s/::$//r } grep { /^nickcolor|nm/ } keys %Irssi::Script::) {
	    if ($colourer = "Irssi::Script::$script"->can('get_nick_color2')) {
		$colourer_script = $script;
		last;
	    }
	}
    }
    return unless $colourer;
    return unless $dest->{level} & MSGLEVEL_PUBLIC;
    return unless defined $dest->{target};
    my $chanref = ref $dest->{server} && $dest->{server}->channel_find($dest->{target});
    return unless $chanref;
    my %nicks = map { $_->[0] => $colourer->($dest->{server}{tag}, $chanref->{name}, $_->[1], 1) }
	grep { defined }
	    map { if (my $nr = $chanref->nick_find($_)) {
		[ $_ => $nr->{nick} ]
	    } }
		keys %{ +{ map { $_ => undef } $stripped =~ /$nick_pat/g } };
    delete @nicks{ @ignore_list };
    my @forms = split /((?:$irssi_mumbo|\s|[.,*@%+&!#$()=~'";:?\/><]+(?=$irssi_mumbo|\s))+)/, $text, -1;
    my $ret = '';
    my $fmtstack = '';
    my $nick_re = join '|', map { quotemeta } sort { length $b <=> length $a } grep { length $nicks{$_} } keys %nicks;
    my $skip = Irssi::settings_get_int('colorize_nicks_skip_formats');
    return if $skip < 0;
    while (@forms) {
	my ($t, $form) = splice @forms, 0, 2;
	if ($skip > 0) {
	    --$skip;
	    $ret .= $t;
	    $ret .= $form if defined $form;
	    if (Irssi::settings_get_bool('colorize_nicks_repeat_formats')) {
		$fmtstack .= join '', $form =~ /$irssi_mumbo/g if defined $form;
		$fmtstack =~ s/\cDe//g;
	    }
	}
	elsif (length $nick_re
		   && $t =~ s/((?:^|\s)\W{0,3}?)(?<!$nickchar|')($nick_re)(?!$nickchar)/$1$nicks{$2}$2\cDg$fmtstack/g) {
	    $ret .= "$t\cDg$fmtstack";
	    $ret .= $form if defined $form;
	    $fmtstack .= join '', $form =~ /$irssi_mumbo/g if defined $form;
	    $fmtstack =~ s/\cDe//g;
	}
	else {
	    $ret .= $t;
	    $ret .= $form if defined $form;
	}
    }
    Irssi::signal_continue($dest, $ret, $stripped);
}

sub setup_changed {
    @ignore_list = split /\s+|,/, Irssi::settings_get_str('colorize_nicks_ignore_list');
}

sub init {
    setup_changed();
}

Irssi::signal_add({
    'print text' => 'prt_text_issue',
});
Irssi::signal_add_last('setup changed' => 'setup_changed');

Irssi::settings_add_int('colorize_nicks', 'colorize_nicks_skip_formats' => 2);
Irssi::settings_add_str('colorize_nicks', 'colorize_nicks_ignore_list' => '');
Irssi::settings_add_bool('colorize_nicks', 'colorize_nicks_repeat_formats' => 0);

init();
