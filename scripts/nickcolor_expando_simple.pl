use strict;
use warnings;
use experimental 'signatures';
use Irssi;

our $VERSION = '0.0.2'; # 4003f16d601cf51
our %IRSSI = (
    authors	=> 'Nei',
    name	=> 'nickcolor_expando_simple',
    description	=> 'provide a simple hash based $nickcolor expando',
    license	=> 'ISC',
   );
die "This script requires Irssi 1.3 or later"
    if (Irssi::parse_special('$abiversion')||0) < 36;

# Usage
# =====
# after loading the script, add the colour expando to the format
# (themes' abstracts are not supported)
#
#   /format pubmsg {pubmsgnick $2 {pubnick $nickcolor$0}}$1
#
# or use the install routine
#
#   /script exec Irssi::Script::nickcolor_expando_simple::install
#
# alternatively, use it together with nm2 script

# Options
# =======
# /set nick_colors <list>
# * list of colour codes to use for $nickcolor
#
# /set nick_char_sum_hash <ON|OFF>
# * whether to use sum of chars as the hash function
#

# To replicate the account-notify colour scheme, try
# /set nick_colors %b %R %Y %G %M %w
# /set nick_char_sum_hash ON
# /run nickcolor_expando_simple

our $nickcolor;

my $char_sum_hash;
my %session_colours;
my @colours;

sub lc1459 {
    my $x = shift;
    $x =~ y/][\\^/}{|~/;
    lc $x
}

sub expando_nickcolor {
    $nickcolor // ''
}

sub char_sum {
    my ($string) = @_;
    chomp $string;
    my @chars = split //, $string;
    my $counter;

    foreach my $char (@chars) {
	$counter += ord $char;
    }

    $counter
}

sub one_at_a_time {
    use integer;
    my $hash = 0x5065526c + length $_[0];
    for my $ord (unpack 'U*', $_[0]) {
	$hash += $ord;
	$hash += $hash << 10;
	$hash &= 0xffffffff;
	$hash ^= $hash >> 6;
    }
    $hash += $hash << 3;
    $hash &= 0xffffffff;
    $hash ^= $hash >> 11;
    $hash = $hash + ($hash << 15);
    $hash &= 0xffffffff;
}

sub simple_hash {
    if ($char_sum_hash) {
	&char_sum
    } else {
	&one_at_a_time
    }
}

sub sig_expando_incoming ($server, $line, $in_nick, $address, $tags_str) {
    return unless defined $in_nick;

    my $_colour;
    my $hash = $session_colours{$in_nick} //= simple_hash($in_nick);
    if (@colours && defined $hash) {
	$_colour = Irssi::format_string_expand($colours[ $hash % @colours ]);
    }
    local $nickcolor = $_colour;
    &Irssi::signal_continue;
}

sub get_nick_color2 ($tag, $chanstr, $nickstr, $format) {
    return unless $format;
    my $hash = $session_colours{$nickstr} //= simple_hash($nickstr);
    if (@colours && defined $hash) {
	return Irssi::format_string_expand($colours[ $hash % @colours ]);
    }
    return;
}

sub setup_changed {
    $char_sum_hash = Irssi::settings_get_bool('nick_char_sum_hash');
    @colours = split ' ', Irssi::settings_get_str('nick_colors');
}

sub init {
    setup_changed();
}

Irssi::settings_add_str('misc', 'nick_colors', '%r %R %g %G %y %b %B %m %M %c %C %X42 %X3A %X5E %X4N %X3H %X3C %X32');
Irssi::settings_add_bool('misc', 'nick_char_sum_hash', 0);

Irssi::signal_add('server event tags' => 'sig_expando_incoming');
Irssi::signal_add_last('setup changed'  => 'setup_changed');

Irssi::expando_create('nickcolor' => \&expando_nickcolor, { 'server incoming' => 'none' });

init();

my %formats = (
    action_public	   => [4, '{pubaction '      ,'$0',''                      ,'}','$1' ],
    action_public_channel  => [4, '{pubaction '      ,'$0','{msgchannel $1}'       ,'}','$2' ],
    action_private	   => [4, '{pvtaction '      ,'$0',''                      ,'}','$2' ],
    action_private_query   => [4, '{pvtaction_query ','$0',''                      ,'}','$2' ],

    notice_public	   => [6, '{notice '         ,'$0','{pubnotice_channel $1}','}','$2' ],
    notice_private	   => [6, '{notice '         ,'$0','{pvtnotice_host $1}'   ,'}','$2' ],
    #                          * *                   * #  *                   *

    msg_private		   => [2, '{privmsg '        ,''  ,''             ,'$0','' ,' $1'            ,'}','$2' ],
    msg_private_query	   => [2, '{privmsgnick '    ,''  ,''             ,'$0','' ,''               ,'}','$2' ],
    pubmsg_me		   => [0, '{pubmsgmenick '   ,'$2',' {menick '    ,'$0','}',''               ,'}','$1' ],
    pubmsg_me_channel	   => [0, '{pubmsgmenick '   ,'$3',' {menick '    ,'$0','}','{msgchannel $1}','}','$2' ],
    pubmsg_hilight	   => [0, '{pubmsghinick $0 ','$3',' '            ,'$1', '','',              ,'}','$2' ],
    pubmsg_hilight_channel => [0, '{pubmsghinick $0 ','$4',' '            ,'$1', '','{msgchannel $2}','}','$3' ],
    pubmsg		   => [0, '{pubmsgnick '     ,'$2',' {pubnick '   ,'$0','}',''               ,'}','$1' ],
    pubmsg_channel	   => [0, '{pubmsgnick '     ,'$3',' {pubnick '   ,'$0','}','{msgchannel $1}','}','$2' ],
    #                          * *                   *    *               * #  *   *                 *   *

    ctcp_reply		   => [8, 'CTCP {hilight $0} reply from '   ,'{nick '    ,'$1', '}',''                        ,': $2' ],
    ctcp_reply_channel	   => [8, 'CTCP {hilight $0} reply from '   ,'{nick '    ,'$1', '}',' in channel {channel $3}',': $2' ],
    ctcp_ping_reply	   => [8, 'CTCP {hilight PING} reply from ' ,'{nick '    ,'$0', '}',''                        ,': $1.$[-3.0]2 seconds' ],

    ctcp_requested	   => [8, '{ctcp '                          ,'{hilight ' ,'$0', '}',' {comment $1} requested CTCP {hilight $2} from {nick $4}}'        ,': $3' ],
    ctcp_requested_unknown => [8, '{ctcp '                          ,'{hilight ' ,'$0', '}',' {comment $1} requested unknown CTCP {hilight $2} from {nick $4}}',': $3' ],
   );

sub do_install ($impl) {
    for my $fmt (sort keys %formats) {
	my $fs = join '', $impl->(@{ $formats{$fmt} });
	Irssi::command("^format $fmt $fs");
    }
}

sub install {
    do_install(sub ($t, @fs) {
		   my $pos = $t <= 2 ? 3 : $t <= 6 ? 1 : 2;
		   $fs[ $pos ] = '$nickcolor' . $fs[ $pos ];
		   @fs
	       });
}

sub uninstall {
    do_install(sub ($t, @fs) {
		   @fs
	       });
}
