# typofix.pl - when someone uses s/foo/bar typofixing, this script really
# goes and modifies the original text on screen.

use strict;
use warnings;
use Irssi qw(
    settings_get_str	settings_get_bool
    settings_add_str	settings_add_bool
    signal_add		signal_stop
);
use Irssi 20140701;
use Irssi::TextUI;
use Algorithm::Diff 'sdiff';

our $VERSION = '1.12'; # 4be3787e5717715
our %IRSSI = (
    authors	=> 'Juerd (first version: Timo Sirainen, additions by: Qrczak)',
    contact	=> 'tss@iki.fi, juerd@juerd.nl, qrczak@knm.org.pl',
    name	=> 'Typofix',
    description	=> 'When someone uses s/foo/bar/, this really modifies the text',
    license	=> 'Same as Irssi',
    url		=> 'http://juerd.nl/irssi/',
    changed	=> 'Sat Jun 28 16:24:26 CEST 2014',
    upgrade_info => '/set typofix_modify_string %wold%gnew%n',
    NOTE1	=> 'you need irssi 0.8.17'
);

#  /SET typofix_modify_string  [fixed]    - append string after replaced text
#  /SET typofix_hide_replace NO           - hide the s/foo/bar/ line
# (J) /SET typofix_format                 - format with "old" and "new" in it


my $chars = '/|;:\'"_=+*&^%$#@!~,.?-';
my $regex = qq{(?x-sm:                       # "s/foo/bar/i # oops"
	\\s*				     # Optional whitespace
	s                                    # Substitution operator      s
	([$chars])                           # Delimiter                  /
	    (   (?: \\\\. | (?!\\1). )*   )  # Pattern                    foo
	    # Backslash plus any char, or a single non-delimiter char
	\\1                                  # Delimiter                  /
	    (   (?: \\\\. | (?!\\1). )*   )  # Replacementstring          bar
	\\1?                                 # Optional delimiter         /
	([a-z]*)                             # Modifiers                  i
	\\s*                                  # Optional whitespace         
	(.?)                                 # Don't hide if there's more # oops
)};
my $irssi_mumbo = qr/\cD[`-i]|\cD[&-@\xff]./;
my $irssi_mumbo_no_partial = qr/(?<!\cD)(?<!\cD[&-@\xff])/;

sub replace {
    my ($window, $nick, $from, $to, $opt, $screen) = @_;

    my $view = $window->view();
    my $line = $screen ? $view->{bottom_startline} : $view->{startline};

    my $last_line;
    (my $copy = $from) =~ s/\^|^/^.*\\b$nick\\b.*?\\s.*?/;
    while ($line) {
	my $text = $line->get_text(0);
	eval {
    	    $last_line = $line 
		if ($line->{info}{level} & (MSGLEVEL_PUBLIC | MSGLEVEL_MSGS)) &&
		$text !~ /$regex/o && $text =~ /$copy/;
	    1
	} or return;
	$line = $line->next();
    }
    return 0 if (!$last_line);
    my $text = $last_line->get_text(1);

    # variables and case insensitivity
    $from = "(?i:$from)" if $opt =~ /i/;
    $to = quotemeta $to;
    $to =~ s{\\\\\\(.)|\\(.)([1-9])?}{
	if (defined $1) {
	    "\\$1"
	} elsif (defined $3 && ($2 eq "\\" || $2 eq "\$")) {
	    "\$$3"
	} else {
	    "\\$2".($3//"")
	} }ge;

    # text replacing
    $text =~ s/(.*(?:\b|$irssi_mumbo)$irssi_mumbo_no_partial$nick(?:\b|$irssi_mumbo).*?\s)//;
    my $pre = $1;
    $text =~ s/$irssi_mumbo//g;
    my $format = settings_get_str('typofix_format');
    $format =~ s/old/\0\cA/;
    $format =~ s/new/\0\cB/;
    $format =~ s/%/\0\cC/g;

    my $old = $text;
    eval " \$text =~ s/\$from/$to/".($opt =~ /g/ ? "g" : "")." ; 1 "
	or Irssi::print "Typofix warning: $@", return 0;
    my $new = '';
    my $diff = Algorithm::Diff->new([split//,$old],[split//,$text]);
    while ($diff->Next()) {
	local $" = '';
	if (my @it = $diff->Same()) {
	    $new .= "@it";
	}
	else {
	    my %r = ("\cA" => [ $diff->Items(1) ],
		     "\cB" => [ $diff->Items(2) ]);
	    my $format_st = $format;
	    $format_st =~ s/\0([\cA\cB])/@{$r{$1}}/g;
	    $new .= $format_st;
	}
    }
    s/%/%%/g for $pre, $new;
    s/\0\cC/%/g for $new;
    $text = $pre . $new . settings_get_str('typofix_modify_string');

    my $bottom = $view->{bottom};
    my $info = $last_line->{info};
    $window->print_after($last_line, $info->{level}, $text, $info->{time});
    $view->remove_line($last_line);
    $window->command('^scrollback end') if $bottom && !$window->view->{bottom};
    $view->redraw();

    return 1;
}

sub event_privmsg {
    my ($server, $data, $nick, $address) = @_;
    my ($target, $text) = $data =~ /^(\S*)\s:(.*)/ or return;

    return unless $text =~ /^$regex/o;
    my ($from, $to, $opt, $extra) = ($2, $3, $4, $5);

    my $hide = settings_get_bool('typofix_hide_replace') && !$extra;

    my $ischannel = $server->ischannel($target);
    my $level = $ischannel ? MSGLEVEL_PUBLIC : MSGLEVEL_MSGS;

    $target = $nick unless $ischannel;
    my $window = $server->window_find_closest($target, $level);

    signal_stop() if (replace($window, $nick, $from, $to, $opt, 0) && $hide);
}

sub event_own_public {
    my ($server, $text, $target) = @_;

    return unless $text =~ /^$regex/o;
    my ($from, $to, $opt, $extra) = ($2, $3, $4, $5);

    my $hide = settings_get_bool('typofix_hide_replace') && !$extra;
    $hide = 0 if settings_get_bool('typofix_own_no_hide');

    my $level = $server->ischannel($target) ? MSGLEVEL_MSGS : MSGLEVEL_PUBLIC;
    my $window = $server->window_find_closest($target, $level);

    signal_stop() if (replace($window, $server->{nick}, $from, $to, $opt, 0) && $hide);
}

settings_add_str ('typofix', 'typofix_modify_string', ' [fixed]');
settings_add_str ('typofix', 'typofix_format', '%rold%gnew%n');
settings_add_bool('typofix', 'typofix_hide_replace', 0);
settings_add_bool('typofix', 'typofix_own_no_hide', 0);

signal_add {
    'event privmsg'	 => \&event_privmsg,
    'message own_public' => \&event_own_public
};
