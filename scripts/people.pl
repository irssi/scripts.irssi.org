use strict;
use 5.005_62;       # for 'our'
use Irssi 20020428; # for Irssi::signal_continue
use Time::HiRes;
use vars qw($VERSION %IRSSI);

our $has_crypt = 0;
eval {require Crypt::PasswdMD5};
unless ($@) {
    $has_crypt = 1;
    import Crypt::PasswdMD5;
}

$VERSION = "1.7";
%IRSSI =
(
    authors     => "Marcin 'Qrczak' Kowalczyk, Johan 'ion' Kiviniemi",
    contact     => 'qrczak@knm.org.pl',
    name        => 'People',
    description => 'Userlist with autoopping, autokicking etc.',
    license     => 'GNU GPL',
    url         => 'http://qrnik.knm.org.pl/~qrczak/irc/people.pl',
    url_ion     => 'http://johan.kiviniemi.name/stuff/irssi/people.pl',
);

######## STATE ########

our %handles;
our %user_masks;
our %user_flags;
our %channel_flags;
our %user_channel_flags;
our %authenticated = ();
our %expire_auth = ();

our $config     = Irssi::get_irssi_dir . "/people.cfg";
our $config_tmp = Irssi::get_irssi_dir . "/people.tmp";
our $config_old = Irssi::get_irssi_dir . "/people.cfg~";

Irssi::settings_add_bool 'people', 'people_autosave', 1;
Irssi::settings_add_int  'people', 'people_op_delay_min', 10;
Irssi::settings_add_int  'people', 'people_op_delay_max', 20;
Irssi::settings_add_str  'people', 'people_default_chatnet', "DALnet";
Irssi::settings_add_bool 'people', 'people_color_friends', 0;
Irssi::settings_add_bool 'people', 'people_color_everybody', 0;
Irssi::settings_add_int  'people', 'people_expire_password', 60;
Irssi::settings_add_bool 'people', 'people_channel_notice', 1;
Irssi::settings_add_str  'people', 'people_colors', "rgybmcRGYBMC";

our $handle_re = qr/([^\0- &#+!,\-\177][^\0- ,\177]*)/;
our $mask_re = qr/([^\0- \177]+)/;
our $masks_re = qr/([^\0- \177]+(?: +[^\0- \177]+)*)/;
our $opt_masks_re = qr/((?: +[^\0- \177]+)*)/;
our $chatnet_re = qr/([\w-._]+)/;
our $channel_re = qr/([&#+!][^\0- ,\177]*)/;
our $channels_re = qr/([&#+!][^\0- ,\177]*(?:,[&#+!][^\0- ,\177]*)*)/;
our $mask_re = qr/([^\0- \177]+)/;
our $flags_re = qr/((?:[+\-!][a-zA-Z]+)+)/;
our $arg_re = qr/(?: (.*))?/;
our $nick_re = qr/([A-}][\-0-9A-}]*)/;
our $nicks_re = qr/([A-}][\-0-9A-}]*(?: +[A-}][\-0-9A-}]*)*)/;
our $nicks_commas_re = qr/([A-}][\-0-9A-}]*(?:,[A-}][\-0-9A-}]*)*)/;

our $master_set_flags = 'deikmopqrvx';
our $master_see_flags = 'deiklmopqrvx';
our $all_flags        = 'cdeiklmnopqrvx';

sub tr_flag {
    my ($flag) = @_;
    $flag =~ tr/CIL/cil/;
    return $flag;
}

our %master_set_flags = map {$_ => 1} split //, $master_set_flags;
our %master_see_flags = map {$_ => 1} split //, $master_see_flags;
our %all_flags        = map {$_ => 1} split //, $all_flags;

######## HELP ########

our $help_commands =

our %help = (
    people => [
        'When I meet people, they are recognized based on their nick and',
        'address, and actions can be automatically performed upon them',
        '(such as opping or kicking).',
        '',
        'Actions depend on flags associated with the user in the channel.',
        'Flags can be specified globally for a user, for everybody in',
        'a channel, or locally for a user in a channel. A flag setting',
        'can be positive or negative. If conflicting settings are present',
        'for a flag, local setting is more important than channel setting',
        'which is more important than global setting.',
        '',
        'A user handle has a set of nick & address masks used to recognize',
        'that person. If someone matches masks of several users, all their',
        'flags are considered together, resolving conflicts in favor of',
        'more specific masks.',
        '',
        'Commands which modify the user list may be given locally',
        'by the owner of the script (e.g. /flag someone +o) or',
        'remotely by someone with enough privileges, either by msg',
        '(e.g. /msg Qrczak !flag someone +o), or ctcp',
        '(e.g. /ctcp Qrczak flag someone +o).',
        '',
        'Commands which manage the user list can be used only by people',
        'with the master status (+m). A local master can manage only',
        'local users (+l) who don\'t have any flags outside his channels.',
        'Commands which perform actions in channels can be used only',
        'by people with the operator status (+o).',
        '',
        'You can use "help <command>" to learn details about the command.',
        'Available commands: help, user add, user remove, mask add,',
        'mask remove, user rename, user list, flag, find, trust, op, deop,',
        'voice, devoice, kick, ban, unban, kickban, invite.',
    ],
    help => [
        'HELP [<command>]',
        '',
        'Show details about the command, or introduction to the script',
        'if no argument is given.',
    ],
    'user add' => [
        'USER ADD <handle> <mask>...',
        '',
        'Add a user, recognized by address masks (nick!user@host or',
        'user@host or host). <handle> is a user name for internal use by',
        'the script. If <masks> are omitted and a user with nick <handle>',
        'is on a channel with the owner of the script, try to guess the',
        'mask basing on his address: replace the first part of host with *',
        'if it contains any digits, or replace the last part of IP address',
        'with * if the address is a numeric IP. You must be a master (+m)',
        'somewhere to use this command.',
    ],
    'user remove' => [
        'USER REMOVE <handle>',
        '',
        'Remove all information about the user <handle>.',
    ],
    'mask add' => [
        'MASK ADD <handle> <mask>...',
        '',
        'Add more address masks to recognize user <handle>.',
    ],
    'mask remove' => [
        'MASK REMOVE <handle> <mask>...',
        '',
        'Remove some address masks used to recognize user <handle>.',
    ],
    'user rename' => [
        'USER RENAME <handle> <new-handle>',
        '',
        'Use a new internal name <new-handle> for the user <handle>.',
    ],
    'user list' => [
        'USER LIST [[<chatnet>/]<#channels>] [+<flags>]',
        'USER LIST text...',
        '',
        'List all users, or users having any flags in the specified',
        'channels, or users having any of the specified flags somewhere,',
        'or users having any of the specified flags in the channels,',
        'or users having any of the specified texts in handle, address',
        'masks or flag arguments.',
    ],
    flag => [
        'FLAG <handle>',
        'FLAG [<chatnet>/]<#channels>',
        'FLAG <handle>                         <flags>',
        'FLAG          [<chatnet>/]<#channels> <flags>',
        'FLAG <handle> [<chatnet>/]<#channels> <flags>',
        '',
        'Without flags given, show flags of the user or channel.',
        'Otherwise add or remove flags globally for a user, for',
        'everybody in a channel, or locally for a user in a channel.',
        '',
        '<flags> is +<letters> (add these flags), -<letters> (remove',
        'these flags, or set them as a negative exception if the flag',
        'would othwerise come from global or channel setting), !<letters>',
        '(set these flags as a negative exception) or a combination of',
        'such settings. If the last flag is being added, it may be followed',
        'by space and <argument> for that flag whose meaning depends on',
        'the flag.',
        '',
        'Meanings of flags:',
        '',
        '+c - Color nick on public messages. This flag is meaningful',
        '     only for the owner of the script. The color will be',
        '     computed from the handle. If people_color_friends variable',
        '     is set, nicks of all recognized people will be colored.',
        '     If people_color_everybody variable is set, every nick',
        '     will be colored, basing on the nick if the person is not',
        '     recognized. The color may be also specified explicitly in',
        '     the argument of +c:',
        '       %k - black, %r - red,     %g - green, %y - yellow or brown,',
        '       %b - blue,  %m - magenta, %c - cyan,  %w - white,',
        '       %K %R %G %Y %B %M %C %W - bright variants of these colors.',
        '',
        '+d - Deop if he gets op, except when opped by you or by a',
        '     master (+m). When flags conflict, +o and +r override +d.',
        '',
        '+e - Execute command given as the argument. $C is replaced with',
        '     the channel the person entered, $N - nick, $A - address.',
        '',
        '+i - A comment or information which reminds why the person is',
        '     interesting can be stored in the argument of +i. It has',
        '     no real effect. It\'s only shown with notification (+n).',
        '',
        '+k - Ban and kick out. The ban mask will be the mask used to',
        '     recognize him, or based on his address if +k came from',
        '     channel flags (replace the first part of host with * if it',
        '     contains any digits, or replace the last part of IP address',
        '     with * if the address is a numeric IP). The kick reason may',
        '     be specified in the argument of the +k flag. When flags',
        '     conflict, +o and +r override +k.',
        '',
        '+l - Local user. Can have address masks changed by a local master',
        '     if the user doesn\'t have any flags outside the master\'s',
        '     channels.',
        '',
        '+m - Master. Can manage the user list, or a local part of it if',
        '     only a local master. His actions on other users (opping and',
        '     deopping) will not be questioned by +r and +d of these users.',
        '',
        '+n - Notify you when the user joins or leaves channels. This flag',
        '     is meaningful only for the owner of the script.',
        '',
        '+o - Op, after a short random delay to avoid op flood when he',
        '     would be opped by others anyway.',
        '',
        '+p - Password is needed to recognize that person. This flag',
        '     should be used when address masks are not secure, i.e.',
        '     unwanted people can have the same addresses. When +p has',
        '     no argument, the person doesn\'t have the password set',
        '     yet and should use the PASS command to set it. Once set,',
        '     the password is stored encrypted in the argument of +p',
        '     and the person must use the PASS command to be recognized.',
        '     The people_expire_password variable tells how many seconds',
        '     to remember the authorization if the person is not seen',
        '     on any channels.',
        '',
        '+q - Devoice if he gets voiced, except when voiced by you or',
        '     by a master (+m).',
        '',
        '+r - Reop if somebody deops him, except when deopped by you,',
        '     by himself, or by a master (+m).',
        '',
        '+v - Voice, after a short random delay to avoid voice flood',
        '     when he would be voiced or opped by others anyway.',
        '',
        '+x - Disable all other flags, except perhaps notification (+n).',
    ],
    find => [
        'FIND',
        'FIND [<chatnet>/]<#channel>',
        'FIND <mask>',
        'FIND <nick>',
        '',
        'Find recognized users on all channels (only owner can do this),',
        'or on the channel, or matching the mask, or having the nick if',
        'present on a channel with me.',
    ],
    trust => [
        'TRUST [<nick>]...',
        '',
        'Set these nicks as authenticated.',
    ],
    op => [
        'OP <#channel> [<nick>]...',
        '',
        'Op these nicks in the channel. If nicks are not given, ops you.',
    ],
    deop => [
        'DEOP <#channel> [<nick>]...',
        '',
        'Deop these nicks in the channel. If nicks are not given,',
        'deops you.',
    ],
    voice => [
        'VOICE <#channel> [<nick>]...',
        '',
        'Voices these nicks in the channel. If nicks are not given,',
        'voices you.',
    ],
    devoice => [
        'DEVOICE <#channel> [<nick>]...',
        '',
        'Devoices these nicks in the channel. If nicks are not given,',
        'devoices you.',
    ],
    kick => [
        'KICK <#channel> <nicks> [<reason>]',
        '',
        'Kick these nicks out of the channel.',
    ],
    ban => [
        'BAN <#channel> <mask/nick>...',
        '',
        'Ban address masks from the channel. If a nick of a person',
        'sitting there is given, the mask is derived from his address.',
    ],
    unban => [
        'UNBAN <#channel> [<masks>]',
        '',
        'Remove some bans from the channel. If no masks are given,',
        'remove all bans against you.',

    ],
    kickban => [
        'KICKBAN <#channel> <nicks> [<reason>]',
        '',
        'Ban and kick out people from the channel. The mask to ban',
        'is derived from their addresses.',
    ],
    invite => [
        'INVITE <#channel> [<nick>]',
        '',
        'Invite the person to the channel. If the nick is not given,',
        'invite you.',
    ],
    pass => [
        'PASS <password>',
        'PASS <password> <new-password>',
        '',
        'Authenticate with the password to ensure the owner that you',
        'are the right person (if you have the +p flag), or set the',
        'password if it wasn\'t set yet. To change the password once',
        'it was set, give both old and new passwords.',
    ]
);

our %local_help = (people => 1);

sub cmd_help($$) {
    my ($context, $args) = @_;
    my $command = join(' ', split(' ', lc $args));
    $command = 'people' if !$context->{owner} && $command eq '';
    my $text = $help{$command};
    if (!$text || $context->{owner} && !$local_help{$command}) {
        $context->{error}("No help for $command") unless $context->{owner};
        return;
    }
    foreach my $line ('', @$text, '') {
        $context->{crap}($line eq '' ? ' ' : $line);
    }
    Irssi::signal_stop if $context->{owner};
}

######## A REGEXP OF ALL MASKS TO IMPROVE PERFORMANCE ########

our %mask_to_regexp = ();
foreach my $i (0..255) {
    my $ch = chr $i;
    $mask_to_regexp{$ch} = "\Q$ch\E";
}
$mask_to_regexp{'?'} = '.';
$mask_to_regexp{'*'} = '.*';

sub mask_to_regexp($) {
    my ($mask) = @_;
    $mask =~ s/(.)/$mask_to_regexp{$1}/g;
    return $mask;
}

our $all_masks;

sub update_all_masks() {
    my @masks = ();
    foreach my $hdl (keys %handles) {
        push @masks, @{$user_masks{$hdl}};
    }
    $all_masks = join('|', map {mask_to_regexp $_} @masks);
    $all_masks = qr/^(?:$all_masks)$/i;
}

######## CONTEXT OF COMMANDS: LOCAL OR REPLYING TO MESSAGES ########

our $local_context = {
    crap           => sub {my ($msg) = @_; $msg =~ s/%/%%/g; print CLIENTCRAP $msg},
    notice         => sub {my ($msg) = @_; $msg =~ s/%/%%/g; print CLIENTNOTICE $msg},
    error          => sub {my ($msg) = @_; $msg =~ s/%/%%/g; print CLIENTERROR $msg},
    usage          => sub {my ($msg) = @_; $msg =~ s/%/%%/g; print CLIENTERROR "Usage: /$msg"},
    usage_next     => sub {my ($msg) = @_; $msg =~ s/%/%%/g; print CLIENTERROR "       /$msg"},
    owner          => 1,
    set_flags      => \%all_flags,
    set_flags_str  => $all_flags,
    see_flags      => \%all_flags,
    server         => undef,
};

######## CHECK PRIVILEGES TO PERFORM COMMANDS ########

sub has_global_flag($$) {
    my ($context, $flag) = @_;
    return $context->{owner} || defined $context->{globals}{$flag};
}

sub has_local_flag($$$$) {
    my ($context, $chatnet, $channel, $flag) = @_;
    return 1 if $context->{owner};
    return
      exists $context->{locals}{$chatnet}{$channel}{$flag} ?
      defined $context->{locals}{$chatnet}{$channel}{$flag} :
      exists $channel_flags{$chatnet}{$channel}{$flag} ?
      defined $channel_flags{$chatnet}{$channel}{$flag} :
      defined $context->{globals}{$flag};
}

sub has_flag_somewhere($$) {
    my ($context, $flag) = @_;
    return 1 if $context->{owner} || defined $context->{globals}{$flag};
    my $locals = $context->{locals};
    foreach my $chatnet (keys %$locals) {
        my $channels = $locals->{$chatnet};
        foreach my $channel (keys %$channels) {
            my $flags = $channels->{$channel};
            return 1 if defined $flags->{$flag};
        }
    }
    return 0;
}

sub must_be_master($) {
    my ($context) = @_;
    return 1 if has_flag_somewhere($context, 'm');
    $context->{error}("Sorry, you don't have master privileges.");
    return 0;
}

sub must_be_operator($) {
    my ($context) = @_;
    return 1 if has_flag_somewhere($context, 'o') ||
      has_flag_somewhere($context, 'm');
    $context->{error}("Sorry, you don't have operator privileges.");
    return 0;
}

sub may_manage($$) {
    my ($context, $hdl) = @_;
    return 1 if has_global_flag($context, 'm');
    unless (defined $user_flags{$hdl}{l}) {
        $context->{error}("Sorry, \cc04$handles{$hdl}\co isn't local to your channels.");
        return 0;
    }
    my $locals = $user_channel_flags{$hdl};
    foreach my $chatnet (keys %$locals) {
        my $channels = $locals->{$chatnet};
        foreach my $channel (keys %$channels) {
            my $flags = $channels->{$channel};
            foreach my $flag (keys %$flags) {
                next unless defined $flags->{$flag};
                unless (defined $context->{locals}{$chatnet}{$channel}{m}) {
                    $context->{error}("Sorry, \cc04$handles{$hdl}\co has flags outside your channels.");
                    return 0;
                }
            }
        }
    }
    return 1;
}

######## FIND USERS AND FLAGS ########

sub more_specific($$) {
    my ($user1, $user2) = @_;
    return 0 unless $user1 && $user2;
    my $mask1 = $user1->[1];
    my $mask2 = $user2->[1];
    return 0 if $mask1 eq $mask2;
    $mask1 =~ /^(.*)!(.*)$/ or return 0;
    my ($nick1, $address1) = ($1, $2);
    $mask2 =~ /^(.*)!(.*)$/ or return 0;
    my ($nick2, $address2) = ($1, $2);
    return 0 if Irssi::mask_match_address($mask1, $nick2, $address2);
    return 1 if Irssi::mask_match_address($mask2, $nick1, $address1);
    return 0 if Irssi::mask_match_address($address1, $address2, undef);
    return 1 if Irssi::mask_match_address($address2, $address1, undef);
    $address1 =~ s/^.*\@/*\@/;
    $address2 =~ s/^.*\@/*\@/;
    return 0 if Irssi::mask_match_address($address1, $address2, undef);
    return 1 if Irssi::mask_match_address($address2, $address1, undef);
    return 0;
}

sub find_users($$$) {
    my ($chatnet, $nick, $address) = @_;
    return () unless "$nick!$address" =~ $all_masks;
    my @users = ();
    foreach my $hdl (keys %user_masks) {
        next if defined $chatnet &&
          defined $user_flags{$hdl}{p} &&
          !$authenticated{$chatnet}{$address}{$hdl};
        my $masks = $user_masks{$hdl};
        foreach my $mask (@$masks) {
            if (Irssi::mask_match_address($mask, $nick, $address)) {
                push @users, [$hdl, $mask];
            }
        }
    }
    return @users;
}

sub find_best_user($$$) {
    my ($chatnet, $nick, $address) = @_;
    my $best = undef;
    foreach my $user (find_users $chatnet, $nick, $address) {
        $best = $user unless more_specific($best, $user);
    }
    return $best ? @$best : ();
}

sub add_flag($$$$$) {
    my ($flags, $users, $flag, $arg, $user) = @_;
    return if
      exists $flags->{$flag} &&
      more_specific($users->{$flag}, $user);
    $flags->{$flag} = $arg;
    $users->{$flag} = $user;
}

sub find_global_flags($$$) {
    my ($chatnet, $nick, $address) = @_;
    my $flags = {}; my $users = {};
    foreach my $user (find_users $chatnet, $nick, $address) {
        my ($hdl, $mask) = @$user;
        my $globals = $user_flags{$hdl};
        foreach my $flag (keys %$globals) {
            my $arg = $globals->{$flag};
            add_flag $flags, $users, $flag, $arg, $user;
        }
        add_flag $flags, $users, '', '', $user;
    }
    return ($flags, $users);
}

sub find_local_flags($$$$) {
    my ($chatnet, $channel, $nick, $address) = @_;
    my @users = find_users $chatnet, $nick, $address;
    my $flags = {}; my $users = {};
    foreach my $user (@users) {
        my ($hdl, $mask) = @$user;
        my $globals = $user_flags{$hdl};
        foreach my $flag (keys %$globals) {
            my $arg = $globals->{$flag};
            add_flag $flags, $users, $flag, $arg, $user;
        }
        add_flag $flags, $users, '', '', $user;
    }
    my $chan_flags = $channel_flags{$chatnet}{$channel};
    foreach my $flag (keys %$chan_flags) {
        my $arg = $chan_flags->{$flag};
        add_flag $flags, $users, $flag, $arg, undef;
    }
    foreach my $user (@users) {
        my ($hdl, $mask) = @$user;
        my $locals = $user_channel_flags{$hdl}{$chatnet}{$channel};
        foreach my $flag (keys %$locals) {
            my $arg = $locals->{$flag};
            add_flag $flags, $users, $flag, $arg, $user;
        }
    }
    return ($flags, $users);
}

sub find_local_flags_if_matches($$$$$) {
    my ($hdl, $chatnet, $channel, $nick, $address) = @_;
    my $user = undef;
    foreach my $mask (@{$user_masks{$hdl}}) {
        if (Irssi::mask_match_address($mask, $nick, $address)) {
            $user = [$hdl, $mask]; last;
        }
    }
    return ({}, {}) unless $user;
    my $flags = {}; my $users = {};
    my $globals = $user_flags{$hdl};
    foreach my $flag (keys %$globals) {
        my $arg = $globals->{$flag};
        add_flag $flags, $users, $flag, $arg, $user;
    }
    add_flag $flags, $users, '', '', $user;
    my $chan_flags = $channel_flags{$chatnet}{$channel};
    foreach my $flag (keys %$chan_flags) {
        my $arg = $chan_flags->{$flag};
        add_flag $flags, $users, $flag, $arg, undef;
    }
    my $locals = $user_channel_flags{$hdl}{$chatnet}{$channel};
    foreach my $flag (keys %$locals) {
        my $arg = $locals->{$flag};
        add_flag $flags, $users, $flag, $arg, $user;
    }
    return ($flags, $users);
}

sub find_all_flags($$$) {
    my ($chatnet, $nick, $address) = @_;
    my $globals = {}; my $global_users = {};
    my $locals = {}; my $local_users = {};
    foreach my $user (find_users $chatnet, $nick, $address) {
        my ($hdl, $mask) = @$user;
        my $flags = $user_flags{$hdl};
        foreach my $flag (keys %$flags) {
            my $arg = $flags->{$flag};
            add_flag $globals, $global_users, $flag, $arg, $user;
        }
        my $chatnets = $user_channel_flags{$hdl};
        foreach my $chatnet (keys %$chatnets) {
            my $channels = $chatnets->{$chatnet};
            foreach my $channel (keys %$channels) {
                my $flags = $channels->{$channel};
                foreach my $flag (keys %$flags) {
                    my $arg = $flags->{$flag};
                    add_flag
                      \%{$locals->{$chatnet}{$channel}},
                      \%{$local_users->{$chatnet}{$channel}},
                      $flag, $arg, $user;
                }
            }
        }
    }
    return ($globals, $locals);
}

######## SHOW USERLIST ########

sub handle_exists($$) {
    my ($context, $handle) = @_;
    unless (defined $handles{lc $handle}) {
        $context->{error}("User \cc04$handle\co doesn't exist.");
        return 0;
    }
    return 1;
}

sub filter_flags($$) {
    my ($flags, $filter) = @_;
    my %filtered = ();
    foreach my $flag (keys %$flags) {
        $filtered{$flag} = $flags->{$flag} if $filter->{$flag};
    }
    return \%filtered;
}

sub show_flags($) {
    my ($flags) = @_;
    return "(none)" unless $flags && %$flags;
    my @on = ();
    my @off = ();
    foreach my $flag (sort keys %$flags) {
        push @{defined $flags->{$flag} ? \@on : \@off}, $flag;
    }
    return
      "\cc9" .
      (@off ? "-" . join('', @off) : '') .
      (@on ? '+' .
        join('', grep {$flags->{$_} eq ''} @on) .
        join('', map {"$_\cc3($flags->{$_})\cc9"} grep {$flags->{$_} ne ''} @on) :
        '') .
      "\co";
}

sub show_handle($$) {
    my ($context, $hdl) = @_;
    handle_exists $context, $hdl or return;
    my $globals = $user_flags{$hdl} || {};
    $globals = filter_flags $globals, $context->{see_flags}
      unless $context->{owner};
    my @locals = ();
    my $chatnets = $user_channel_flags{$hdl};
    foreach my $chatnet (sort keys %$chatnets) {
        my $channels = $chatnets->{$chatnet};
        foreach my $channel (sort keys %$channels) {
            my $flags = $channels->{$channel} || {};
            $flags = filter_flags $flags, $context->{see_flags}
              unless $context->{owner};
            push @locals, [$chatnet, $channel, $flags] if %$flags;
        }
    }
    my @masks = @{$user_masks{$hdl}};
    if (@masks) {
        my $plural = @masks == 1 ? "" : "s";
        $context->{crap}("\cc04$handles{$hdl}\co is \cc10@masks\co");
    } else {
        $context->{crap}("\cc04$handles{$hdl}\co exists but has no address masks");
    }
    my @flags = %$globals ? (show_flags($globals)) : ();
    foreach my $local (@locals) {
        my ($chatnet, $channel, $flags) = @$local;
        push @flags, "\cb$chatnet/$channel\cb " . show_flags($flags)
          if has_local_flag($context, $chatnet, $channel, 'm');
    }
    @flags = ("(none)") unless @flags;
    $context->{crap}("    flags: " . join("; ", @flags));
}

sub show_channel($$$$) {
    my ($context, $chatnet, $channel, $show_empty) = @_;
    my $flags = $channel_flags{$chatnet}{$channel} || {};
    $flags = filter_flags $flags, $context->{see_flags}
      unless $context->{owner};
    return unless $show_empty || %$flags;
    $context->{crap}("Flags of \cb$chatnet/$channel\cb are " . show_flags($flags));
}

sub filter_handle($$$$$) {
    my ($context, $hdl,
        $filter_channels, $filter_flags, $filter_text) = @_;
    return 1 unless $filter_channels || $filter_flags || $filter_text;
    my $globals = $user_flags{$hdl};
    my $locals = $user_channel_flags{$hdl};
    if ($filter_text) {
        foreach my $re (@$filter_text) {
            return 1 if $hdl =~ $re;
            my $masks = $user_masks{$hdl};
            foreach my $mask (@$masks) {
                return 1 if $mask =~ $re;
            }
            foreach my $flag (keys %$globals) {
                return 1 if $globals->{$flag} =~ $re;
            }
            foreach my $chatnet (keys %$locals) {
                my $channels = $locals->{$chatnet};
                foreach my $channel (keys %$channels) {
                    my $flags = $channels->{$channel};
                    foreach my $flag (keys %$flags) {
                        return 1 if defined $flags->{$flag} && $flags->{$flag} =~ $re;
                    }
                }
            }
        }
        return 0;
    }
    if ($filter_flags) {
        foreach my $flag (@$filter_flags) {
            next unless $context->{owner} || $context->{see_flags}{$flag};
            return 1 if defined $globals->{$flag};
            foreach my $chatnet (keys %$locals) {
                my $channels = $locals->{$chatnet};
                foreach my $channel (keys %$channels) {
                    next unless has_local_flag($context, $chatnet, $channel, 'm') &&
                      (!$filter_channels || $filter_channels->{$chatnet}{$channel});
                    my $flags = $channels->{$channel};
                    return 1 if exists $flags->{$flag};
                }
            }
        }
        return 0;
    } else {
        return 1 if $globals && %$globals;
        foreach my $chatnet (keys %$locals) {
            my $channels = $locals->{$chatnet};
            foreach my $channel (keys %$channels) {
                next unless has_local_flag($context, $chatnet, $channel, 'm') &&
                  $filter_channels->{$chatnet}{$channel};
                my $flags = $channels->{$channel};
                return 1 if %$flags;
            }
        }
        return 0;
    }
}

sub filter_channel($$$$$$) {
    my ($context, $chatnet, $channel,
        $filter_channels, $filter_flags, $filter_text) = @_;
    return 0 unless has_local_flag($context, $chatnet, $channel, 'm');
    if ($filter_text) {
        my $flags = $channel_flags{$chatnet}{$channel};
        foreach my $re (@$filter_text) {
            return 1 if $channel =~ $re;
            foreach my $flag (keys %$flags) {
                return 1 if $flags->{$flag} =~ $re;
            }
        }
        return 0;
    }
    return 0 if $filter_channels && !$filter_channels->{$chatnet}{$channel};
    return 1 unless $filter_flags;
    my $flags = $channel_flags{$chatnet}{$channel};
    foreach my $flag (@$filter_flags) {
        next unless $context->{owner} || $context->{see_flags}{$flag};
        return 1 if defined $flags->{$flag};
    }
    return 0;
}

sub default_chatnet($) {
    my ($context) = @_;
    my $server = $context->{server} || $context->{owner} && Irssi::active_server;
    return $server->{chatnet} if $server;
    return Irssi::settings_get_str('people_default_chatnet');
}

sub cmd_user_list($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    my $filter_channels = undef;
    my $filter_flags = undef;
    my $filter_text = undef;
    if ($args =~ /^ *(?:(?:$chatnet_re\/)?$channels_re +)?\+([a-zA-Z]+) *$/o ||
        $args =~ /^ *(?:$chatnet_re\/)?$channels_re *$/o ||
        $args =~ /^ *$/) {
        my ($chatnet, $channels, $flags) = ($1, $2, $3);
        if (defined $channels) {
            $chatnet = default_chatnet $context unless defined $chatnet;
            $chatnet = lc $chatnet;
            $channels = lc $channels;
            $filter_channels = {$chatnet => {map {$_ => 1} split /,/, $channels}};
        }
        $filter_flags = [split //, $flags] if defined $flags;
        $context->{crap}(
          $filter_flags ?
            "Users having " .
            (length $flags == 1 ? "\cc9+$flags\co flag" : "any of \cc9+$flags\co flags") .
            ($filter_channels ? " on \cb$chatnet/$channels\cb:" : ":") :
            $filter_channels ?
              "Users having any flags on \cb$chatnet/$channels\cb:" :
              "User list:");
    } else {
        my @texts = split ' ', $args;
        $context->{crap}("Users having something common with \cb@texts\cb:");
        $filter_text = [map {qr/\Q$_\E/i} @texts];
    }
    foreach my $hdl (sort keys %handles) {
        show_handle $context, $hdl
          if filter_handle $context, $hdl,
            $filter_channels, $filter_flags, $filter_text;
    }
    foreach my $chatnet (sort keys %channel_flags) {
        my $channels = $channel_flags{$chatnet};
        foreach my $channel (sort keys %$channels) {
            show_channel $context, $chatnet, $channel, 0
              if filter_channel $context, $chatnet, $channel,
                $filter_channels, $filter_flags, $filter_text;
        }
    }
    $context->{crap}("End of user list");
}

######## WORK WHEN MEETING PEOPLE ########

sub channel_notice($$$) {
    my ($server, $channel, $msg) = @_;
    $server->command("notice $channel -!- $msg")
      if Irssi::settings_get_bool('people_channel_notice');
}

sub disappeared($) {
    my ($chatnet, $nick, $address, $hdl) = @{$_[0]};
    delete $authenticated{$chatnet}{$address}{$hdl};
    delete $authenticated{$chatnet}{$address} unless %{$authenticated{$chatnet}{$address}};
    delete $expire_auth{$chatnet}{$address}{$hdl};
    delete $expire_auth{$chatnet}{$address} unless %{$expire_auth{$chatnet}{$address}};
    print CLIENTNOTICE "\cc11*!$address\co is no longer recognized as \cc04$handles{$hdl}\co (authentication expired).";
}

sub disappears($$$) {
    my ($chatnet, $nick, $address) = @_;
    my $handles = $authenticated{$chatnet}{$address} or return;
    my $delay = Irssi::settings_get_int('people_expire_password') * 1000;
    foreach my $hdl (keys %$handles) {
        my $expiring = $expire_auth{$chatnet}{$address}{$hdl};
        Irssi::timeout_remove $expiring if $expiring;
        my $tag = Irssi::timeout_add_once $delay, \&disappeared,
          [$chatnet, $nick, $address, $hdl];
        $expire_auth{$chatnet}{$address}{$hdl} = $tag;
    }
}

sub maybe_disappears($$$$$) {
    my ($chatnet, $server, $channel, $nick, $address) = @_;
    foreach my $chan ($server->channels()) {
        next if defined $channel && lc $chan->{name} eq $channel;
        return if $chan->nick_find_mask("*!$address");
    }
    disappears $chatnet, $nick, $address;
}

sub appears($$$) {
    my ($chatnet, $nick, $address) = @_;
    my $handles = $expire_auth{$chatnet}{$address} or return;
    my @handles = keys %$handles;
    foreach my $hdl (@handles) {
        my $tag = $handles->{$hdl};
        Irssi::timeout_remove $tag;
        delete $handles->{$hdl};
    }
}

our %queued_actions = ();

our %action_not_needed = (
    '+o' => sub {$_[0]->{op}},
    '-o' => sub {not $_[0]->{op}},
    '+v' => sub {$_[0]->{op} || $_[0]->{voice}},
    '-v' => sub {$_[0]->{op} || not $_[0]->{voice}},
);

# Delete/create an appropriate timeout.
sub queue_handle($$) {
    my ($chatnet, $channel) = @_;
    my $ref = $queued_actions{$chatnet}{$channel};
    $ref->{queue} ||= [];

    if (defined $ref->{tag} and @{ $ref->{queue} } == 0) {
        Irssi::timeout_remove $ref->{tag};
        delete $ref->{tag};
        delete $ref->{time};
    }

    unless (@{ $ref->{queue} } == 0) {
        my $time = $ref->{queue}[0]{time};
        unless (defined $ref->{time} and $ref->{time} == $time) {
            Irssi::timeout_remove $ref->{tag} if defined $ref->{tag};
            $ref->{time} = $time;
            my $delay = 1000 * ($time - Time::HiRes::time);
            $delay = 10 if $delay < 10;
            $ref->{tag} = Irssi::timeout_add_once $delay, \&queue_run,
              [$chatnet, $channel];
        }
    }
}

# Run the first items from the queue.
sub queue_run(\@) {
    my ($chatnet, $channel) = @{ $_[0] };
    delete $queued_actions{$chatnet}{$channel}{tag};
    delete $queued_actions{$chatnet}{$channel}{time};

    my $server = Irssi::server_find_chatnet $chatnet;
    my $queue  = $queued_actions{$chatnet}{$channel}{queue};
    my $chan;
    $chan = $server->channel_find($channel) if defined $server;
    unless (defined $server and defined $chan) {
        @$queue = ();
        return;
    }

    my $max_modes = $server->isupport('modes') || 1;
    my (@modes);
    while (@modes < $max_modes and @$queue > 0) {
        my $action = shift @$queue;
        my $who = $chan->nick_find($action->{nick});
        next unless defined $who;
        next if $action_not_needed{$action->{action}}($who);
        push @modes, [$action->{action}, $action->{nick}];
    }

    if (@modes) {
        my ($mode_actions, @mode_params) = ('');
        for my $mode (sort { $a->[0] cmp $b->[0] } @modes) {
            $mode_actions .= $mode->[0];
            push @mode_params, $mode->[1];
        }
        $server->command("mode $channel $mode_actions @mode_params");
    }

    queue_handle $chatnet, $channel;
}

sub queue_nick_changed($$$) {
    my ($chatnet, $old_nick, $nick) = @_;
    while (my ($channel, $ref) = each %{ $queued_actions{$chatnet} }) {
        next unless defined $ref->{queue};
        foreach (grep { $_->{nick} eq $old_nick } @{ $ref->{queue} }) {
            $_->{nick} = $nick;
        }
    }
}

sub cancel_queued($$$) {
    my ($chatnet, $channel, $nick) = @_;
    my $queue = $queued_actions{$chatnet}{$channel}{queue};
    return unless defined $queue;
    @$queue = grep { $_->{nick} ne $nick } @$queue;
    queue_handle $chatnet, $channel;
}

sub cancel_queued_everywhere($$) {
    my ($chatnet, $nick) = @_;
    while (my ($channel, $ref) = each %{ $queued_actions{$chatnet} }) {
        cancel_queued $chatnet, $channel, $nick;
    }
}

sub queue_action($$$$;$) {
    my ($chatnet, $action, $channel, $nick, $delay) = @_;
    unless (defined $delay) {
        my $delay_min = Irssi::settings_get_int('people_op_delay_min');
        my $delay_max = Irssi::settings_get_int('people_op_delay_max');
        $delay_min = $delay_max if $delay_min > $delay_max;
        $delay = $delay_min + rand ($delay_max - $delay_min);
    }
    my $queue = ($queued_actions{$chatnet}{$channel}{queue} ||= []);
    @$queue = sort { $a->{time} <=> $b->{time} } @$queue, {
        time   => Time::HiRes::time + $delay,
        action => $action,
        nick   => $nick
    };
    queue_handle $chatnet, $channel;
}

sub improve_mask($) {
    my ($mask) = @_;
    return "$1*" if $mask =~ /^(.*\@\d+\.\d+\.\d+\.)\d+$/;
    return "$1*$2" if $mask =~ /^(.*\@)[^.]*\d[^.]*(\..*)$/;
    return $mask;
}

sub ban($$$$$$) {
    my ($server, $channel, $nick, $address, $is_op, $users) = @_;
    my $mask = $users->{k} ? $users->{k}[1] : "*!" . improve_mask $address;
    $server->command("mode $channel " . ($is_op ? "-o+b $nick $mask" : "+b $mask"));
}

sub kick($$$$) {
    my ($server, $channel, $nick, $flags) = @_;
    $server->command("kick $channel $nick" . ($flags->{k} eq '' ? "" : " $flags->{k}"));
}

sub execute($$$$$) {
    my ($server, $channel, $nick, $address, $flags) = @_;
    my $cmd = $flags->{e};
    $cmd =~ s/\$([CNA])/{
       C => $channel,
       N => $nick,
       A => $address,
    }->{$1}/eg;
    $server->command($cmd);
}

sub show_who($$$) {
    my ($hdl, $nick, $address) = @_;
    return
      (defined $hdl ?
        $hdl eq lc $nick ?
          "\cc04$handles{$hdl}\co" :
          $nick =~ s/\Q$hdl\E/\cc04$handles{$hdl}\cc11/i ?
            "\cc11$nick\co" :
            "\cc04$handles{$hdl}\co = \cc11$nick\co" :
        "\cc11$nick\co") .
      " \cc14[\cc10$address\cc14]\co";
}

sub notify($$$$$$) {
    my ($nick, $address, $flags, $users, $str, $beep) = @_;
    return unless defined $flags->{n};
    my $hdl = $users->{''}[0];
    $str =~ s/\{who\}/show_who $hdl, $nick, $address/eg;
    print CLIENTCRAP $str . ($flags->{i} eq '' ? "" : " ($flags->{i})");
    Irssi::command "beep" if $beep;
}

sub process_user($$$$$$$$) {
    my ($server, $chan, $is_op, $is_voice, $nick, $address, $flags, $users) = @_;
    return if defined $flags->{x};
    return unless $chan->{chanop};
    my $chatnet = lc $server->{chatnet};
    my $channel = lc $chan->{name};
    if (defined $flags->{r}) {
        queue_action $chatnet, '+o', $channel, $nick unless $is_op;
    } elsif (defined $flags->{o}) {
    } elsif (defined $flags->{k}) {
        ban $server, $channel, $nick, $address, $is_op, $users;
        kick $server, $channel, $nick, $flags;
    } elsif (defined $flags->{d}) {
        queue_action $chatnet, '-o', $channel, $nick, 0.1 if $is_op;
    }
    if (defined $flags->{v}) {
    } elsif (defined $flags->{q}) {
        queue_action $chatnet, '-v', $channel, $nick, 0.2 if $is_voice;
    }
    if ($flags->{e} ne '') {
        execute $server, $channel, $nick, $address, $flags;
    }
}

Irssi::signal_add_last 'event join', sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or return;
    my $channel = lc $1;
    return if $nick eq $server->{nick};
    my $chatnet = lc $server->{chatnet};
    my $chan = $server->channel_find($channel) or return;
    appears $chatnet, $nick, $address;
    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
    notify $nick, $address, $flags, $users, "{who} has joined \cb$channel\cb", 1;
    return if defined $flags->{x};
    return unless $chan->{chanop};
    if (defined $flags->{r} || defined $flags->{o}) {
        queue_action $chatnet, '+o', $channel, $nick;
    } elsif (defined $flags->{k}) {
        ban $server, $channel, $nick, $address, 0, $users;
        kick $server, $channel, $nick, $flags;
    }
    if (defined $flags->{v}) {
        queue_action $chatnet, '+v', $channel, $nick;
    }
    if ($flags->{e} ne '') {
        execute $server, $channel, $nick, $address, $flags;
    }
};

sub process_channel($$$) {
    my ($server, $chan, $notify) = @_;
    my $chatnet = lc $server->{chatnet};
    my $channel = lc $chan->{name};
    foreach my $who ($chan->nicks()) {
        my $nick = $who->{nick};
        next if $nick eq $server->{nick};
        my $address = $who->{host};
        my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
        notify $nick, $address, $flags, $users,
          "{who} is on \cb$channel\cb", 0 if $notify;
        process_user $server, $chan, $who->{op}, $who->{voice}, $nick, $address, $flags, $users;
    }
}

Irssi::signal_add_last 'channel wholist', sub {
    my ($chan) = @_;
    my $server = $chan->{server};
    my $chatnet = lc $server->{chatnet};
    foreach my $who ($chan->nicks()) {
        appears $chatnet, $who->{nick}, $who->{host};
    }
    process_channel $server, $chan, 1;
};

Irssi::signal_add_first 'channel destroyed', sub {
    my ($chan) = @_;
    my $server = $chan->{server};
    my $chatnet = lc $server->{chatnet};
    foreach my $who ($chan->nicks()) {
        maybe_disappears $chatnet, $server, lc $chan->{name}, $who->{nick}, $who->{host};
    }
};

sub is_master($$$$) {
    my ($chatnet, $chan, $channel, $nick) = @_;
    return 1 if $nick eq $chan->{server}{nick};
    my $who = $chan->nick_find($nick);
    my $address = $who ? $who->{host} : '';
    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
    return defined $flags->{m};
}

Irssi::signal_add_last 'nick mode changed', sub {
    my ($chan, $who, $setter) = @_;
    my $server = $chan->{server};
    my $nick = $who->{nick};
    if ($nick eq $server->{nick}) {
        return unless $chan->{chanop};
        process_channel $server, $chan, 0 if $chan->{wholist};
    } else {
        my $chatnet = lc $server->{chatnet};
        my $channel = lc $chan->{name};
        my $address = $who->{host};
        my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
        return if defined $flags->{x};
        return unless $chan->{chanop};
        if (defined $flags->{r}) {
            queue_action $chatnet, '+o', $channel, $nick
              unless $who->{op} ||
              $setter eq $nick ||
              is_master($chatnet, $chan, $channel, $setter);
        } elsif (defined $flags->{o}) {
        } elsif (defined $flags->{d}) {
            queue_action $chatnet, '-o', $channel, $nick, 0.1
              unless !$who->{op} ||
              is_master($chatnet, $chan, $channel, $setter);
        }
        if (defined $flags->{v}) {
        } elsif (defined $flags->{q}) {
            queue_action $chatnet, '-v', $channel, $nick, 0.2
              unless !$who->{voice} ||
              is_master($chatnet, $chan, $channel, $setter);
        }
    }
};

Irssi::signal_add_last 'event part', sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^([^ ]+) +:(.*)$/ or $args =~ /^([^ ]+) +([^ ]+)$/ or $args =~ /^([^ ]+)()$/ or return;
    my ($channel, $reason) = (lc $1, $2);
    my $chatnet = lc $server->{chatnet};
    my $chan = $server->channel_find($channel) or return;
    maybe_disappears $chatnet, $server, $channel, $nick, $address;
    cancel_queued $chatnet, $channel, $nick;
    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
    notify $nick, $address, $flags, $users,
      "{who} has left \cb$channel\cb \cc14[\co$reason\cc14]\co", 0;
};

Irssi::signal_add_last 'event quit', sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or $args =~ /^()$/ or return;
    my $reason = $1;
    my $chatnet = lc $server->{chatnet};
    maybe_disappears $chatnet, $server, undef, $nick, $address;
    cancel_queued_everywhere $chatnet, $nick;
    my ($flags, $users) = find_global_flags $chatnet, $nick, $address;
    delete $flags->{n};
    foreach my $chan ($server->channels()) {
        next unless $chan->nick_find($nick);
        my $channel = lc $chan->{name};
        my ($local_flags, $local_users) = find_local_flags $chatnet, $channel, $nick, $address;
        if (defined $local_flags->{n}) {
            $flags->{n} = '';
            last;
        }
    }
    notify $nick, $address, $flags, $users,
      "{who} has quit \cc14[\co$reason\cc14]\co", 0;
};

Irssi::signal_add_last 'event kick', sub {
    my ($server, $args, $kicker, $kicker_address) = @_;
    $args =~ /^([^ ]+) +([^ ]+) +:(.*)$/ or $args =~ /^([^ ]+) +([^ ]+) +([^ ]+)$/ or
      $args =~ /^([^ ]+) +([^ ]+)()$/ or return;
    my ($channel, $nick, $reason) = (lc $1, $2, $3);
    my $chatnet = lc $server->{chatnet};
    my $chan = $server->channel_find($channel) or return;
    my $who = $chan->nick_find($nick);
    return unless defined $who;
    my $address = $who->{host};
    maybe_disappears $chatnet, $server, $channel, $nick, $address;
    cancel_queued $chatnet, $channel, $nick;
    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
    notify $nick, $address, $flags, $users,
      "{who} was kicked from \cb$channel\cb by \cb$kicker\cb \cc14[\co$reason\cc14]\co", 0;
};

Irssi::signal_add_last 'event nick', sub {
    my ($server, $args, $old_nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or return;
    my $new_nick = $1;
    my $chatnet = lc $server->{chatnet};
    queue_nick_changed $chatnet, $old_nick, $new_nick;
    foreach my $chan ($server->channels()) {
        my @nicks = map {$_->{nick}} $chan->nicks();
        my $who = $chan->nick_find($new_nick);
        next unless $who;
        my $channel = lc $chan->{name};
        my ($old_flags, $old_users) = find_local_flags $chatnet, $channel, $old_nick, $address;
        my ($new_flags, $new_users) = find_local_flags $chatnet, $channel, $new_nick, $address;
        if (defined $new_flags->{n} &&
            (!defined $old_flags->{n} || $old_users->{''}[0] ne $new_users->{''}[0])) {
            notify $new_nick, $address, $new_flags, $new_users,
              "{who} is on \cb$channel\cb", 1;
        }
        next if defined $new_flags->{x};
        next unless $chan->{chanop};
        if (defined $new_flags->{o}) {
            queue_action $chatnet, '+o', $channel, $new_nick
              if !defined $old_flags->{o} && !$who->{op};
        } elsif (defined $new_flags->{k}) {
            ban $server, $channel, $new_nick, $address, $who->{op}, $new_users;
            kick $server, $channel, $new_nick, $new_flags;
        } elsif (defined $new_flags->{d}) {
            queue_action $chatnet, '-o', $channel, $new_nick, 0.1
              if !defined $old_flags->{d} && $who->{op};
        }
        if (defined $new_flags->{v}) {
            queue_action $chatnet, '+v', $channel, $new_nick
              if !defined $old_flags->{v} && !$who->{op} && !$who->{voice};
        } elsif (defined $new_flags->{q}) {
            queue_action $chatnet, '-v', $channel, $new_nick, 0.2
              if !defined $old_flags->{q} && $who->{voice};
        }
        if ($new_flags->{e} ne '') {
            execute $server, $channel, $new_nick, $address, $new_flags;
        }
    }
};

######## NICK COLORS ########

sub compute_color($) {
    my ($text) = @_;
    my $sum = 0;
    foreach my $ch (lc($text) =~ /[a-z]/g) {
        $sum += ord $ch;
    }
    my @colors = split(//, Irssi::settings_get_str('people_colors'));
    return '%' . $colors[$sum % @colors];
}

Irssi::signal_add_last 'message public', sub {
    my ($server, $msg, $nick, $address, $channel) = @_;
    my $chatnet = lc $server->{chatnet};
    $channel = lc $channel;
    my $chan = $server->channel_find($channel) or return;
    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
    return unless defined $flags->{c} ||
      Irssi::settings_get_bool('people_color_friends') && defined $flags->{''} ||
      Irssi::settings_get_bool('people_color_everybody');
    my $color = $flags->{c} ne '' ? $flags->{c} :
      compute_color(defined $flags->{c} && $users->{c} ? $handles{$users->{c}[0]} :
                    defined $flags->{''} ? $handles{$users->{''}[0]} : $nick);
    my $window = $server->window_find_item($channel);
    my $theme = $window->{theme} || Irssi::current_theme;
    my $oform = $theme->get_format('fe-common/core', 'pubmsg');
    my $nform = $oform;
    $nform =~ s/(\$(?:\[-?\d+\])?0)/$color$1%n/g;
    $window->command("^format pubmsg $nform") if $window;
    Irssi::signal_continue @_;
    $window->command("^format pubmsg $oform") if $window;
};

######## WORK WHEN USERLIST CHANGED ########

sub user_changed_on_channel($$$$$) {
    my ($hdl, $server, $chatnet, $chan, $channel) = @_;
    foreach my $who ($chan->nicks()) {
        my $nick = $who->{nick};
        next if $nick eq $server->{nick};
        my $address = $who->{host};
        my ($flags, $users) = find_local_flags_if_matches $hdl, $chatnet, $channel, $nick, $address;
        notify $nick, $address, $flags, $users,
          "{who} is on \cb$channel\cb", 0;
        process_user $server, $chan, $who->{op}, $who->{voice}, $nick, $address, $flags, $users;
    }
}

sub user_changed($) {
    my ($hdl) = @_;
    foreach my $server (Irssi::servers) {
        my $chatnet = lc $server->{chatnet};
        foreach my $chan ($server->channels()) {
            next unless $chan->{wholist};
            my $channel = lc $chan->{name};
            user_changed_on_channel $hdl, $server, $chatnet, $chan, $channel;
        }
    }
}

sub user_channel_changed($$$) {
    my ($hdl, $chatnet, $channel) = @_;
    my $server = Irssi::server_find_chatnet $chatnet or return;
    my $chan = $server->channel_find($channel) or return;
    user_changed_on_channel $hdl, $server, $chatnet, $chan, $channel;
}

sub channel_changed($$) {
    my ($chatnet, $channel) = @_;
    my $server = Irssi::server_find_chatnet $chatnet or return;
    my $chan = $server->channel_find($channel) or return;
    process_channel $server, $chan, 0 if $chan->{wholist};
}

sub all_changed() {
    foreach my $server (Irssi::servers) {
        foreach my $chan ($server->channels()) {
            process_channel $server, $chan, 0 if $chan->{wholist};
        }
    }
}

######## STORE CONFIGURATION IN A FILE ########

sub show_flag($$) {
    my ($flag, $arg) = @_;
    return defined $arg ? $arg eq '' ? "+$flag" : "+$flag $arg" : "-$flag";
}

sub save_config() {
    open CONFIG, ">$config_tmp";
    foreach my $hdl (sort keys %handles) {
        my $handle = $handles{$hdl};
        my @masks = sort @{$user_masks{$hdl}};
        print CONFIG "user $handle @masks\n";
        my $globals = $user_flags{$hdl};
        foreach my $flag (sort keys %$globals) {
            print CONFIG "flag $handle " .
              show_flag($flag, $globals->{$flag}) . "\n";
        }
        my $chatnets = $user_channel_flags{$hdl};
        foreach my $chatnet (sort keys %$chatnets) {
            my $channels = $chatnets->{$chatnet};
            foreach my $channel (sort keys %$channels) {
                my $locals = $channels->{$channel};
                foreach my $flag (sort keys %$locals) {
                    print CONFIG "flag $handle $chatnet/$channel " .
                      show_flag($flag, $locals->{$flag}) . "\n";
                }
            }
        }
        print CONFIG "\n";
    }
    foreach my $chatnet (sort keys %channel_flags) {
        my $channels = $channel_flags{$chatnet};
        foreach my $channel (sort keys %$channels) {
            my $flags = $channels->{$channel};
            next unless %$flags;
            foreach my $flag (sort keys %$flags) {
                print CONFIG "flag $chatnet/$channel " .
                  show_flag($flag, $flags->{$flag}) . "\n";
            }
            print CONFIG "\n";
        }
    }
    close CONFIG;
    rename $config, $config_old;
    rename $config_tmp, $config;
}

sub autosave_config() {
    save_config if Irssi::settings_get_bool 'people_autosave';
}

Irssi::signal_add 'setup saved', sub {
    my ($main_config, $auto) = @_;
    save_config unless $auto;
};

sub unique_masks(@) {
    my %masks = ();
    foreach my $mask (@_) {
        $mask = "*\@$mask" if $mask !~ /\@|!\*$/;
        $mask = "*!$mask" if $mask !~ /!/;
        $masks{$mask} = 1;
    }
    return sort keys %masks;
}

sub load_config() {
    %handles = ();
    %user_masks = ();
    %user_flags = ();
    %channel_flags = ();
    %user_channel_flags = ();
    open CONFIG, $config or return;
    while (<CONFIG>) {
        chomp;
        next if /^ *$/ || /^#/;
        if (/^user +$handle_re$opt_masks_re *$/o) {
            my ($handle, $masks) = ($1, $2);
            $handles{lc $handle} = $handle;
            $user_masks{lc $handle} = [unique_masks(split(' ', $masks))];
        } elsif (/^flag +$handle_re +$chatnet_re\/$channel_re +\+([a-zA-Z])$arg_re$/o) {
            my ($handle, $chatnet, $channel, $flag, $arg) = ($1, $2, $3, $4, $5);
            $flag = tr_flag $flag;
            $arg = '' unless defined $arg;
            $user_channel_flags{lc $handle}{$chatnet}{$channel}{$flag} = $arg;
        } elsif (/^flag +$handle_re +$chatnet_re\/$channel_re +-([a-zA-Z]) *$/o) {
            my ($handle, $chatnet, $channel, $flag) = ($1, $2, $3, $4);
            $flag = tr_flag $flag;
            $user_channel_flags{lc $handle}{$chatnet}{$channel}{$flag} = undef;
        } elsif (/^flag +$chatnet_re\/$channel_re +\+([a-zA-Z])$arg_re$/o) {
            my ($chatnet, $channel, $flag, $arg) = ($1, $2, $3, $4);
            $flag = tr_flag $flag;
            $arg = '' unless defined $arg;
            $channel_flags{$chatnet}{$channel}{$flag} = $arg;
        } elsif (/^flag +$chatnet_re\/$channel_re +-([a-zA-Z]) *$/o) {
            my ($chatnet, $channel, $flag) = ($1, $2, $3);
            $flag = tr_flag $flag;
            $channel_flags{$chatnet}{$channel}{$flag} = undef;
        } elsif (/^flag +$handle_re +\+([a-zA-Z])$arg_re$/o) {
            my ($handle, $flag, $arg) = ($1, $2, $3);
            $flag = tr_flag $flag;
            $arg = '' unless defined $arg;
            $user_flags{lc $handle}{$flag} = $arg;
        } elsif (/^flag +$handle_re +-([a-zA-Z]) *$/o) {
            my ($handle, $flag) = ($1, $2);
            $flag = tr_flag $flag;
            $user_flags{lc $handle}{$flag} = undef;
        } else {
            print CLIENTERROR "Syntax error in $config: $_";
        }
    }
    update_all_masks;
    all_changed;
}

Irssi::signal_add 'setup reread', \&load_config;

######## MANAGE THE USER LIST ########

sub find_nick($) {
    my ($nick) = @_;
    foreach my $chan (Irssi::channels) {
        my $who = $chan->nick_find($nick) or next;
        my $address = $who->{host};
        return $address if $address ne '';
    }
    return undef;
}

sub find_server_nick($$) {
    my ($server, $nick) = @_;
    foreach my $chan ($server->channels) {
        my $who = $chan->nick_find($nick) or next;
        my $address = $who->{host};
        return $address if $address ne '';
    }
    return undef;
}

sub guess_mask($) {
    my ($nick) = @_;
    my $address = find_nick $nick;
    return defined $address ? (improve_mask $address) : ();
}

sub cmd_user_add($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    unless ($args =~ /^ *$handle_re$opt_masks_re *$/o) {
        $context->{usage}("user add <handle> <mask>...");
        return;
    }
    my ($handle, $masks) = ($1, $2);
    my $hdl = lc $handle;
    if (defined $handles{$hdl}) {
        $context->{error}("User \cc04$handles{$hdl}\co already exists");
        return;
    }
    my @masks = split(' ', $masks);
    @masks = guess_mask $handle unless @masks;
    @masks = unique_masks(@masks);
    $handles{$hdl} = $handle;
    $user_masks{$hdl} = [@masks];
    $user_flags{$hdl}{l} = ''
      unless $context->{owner} || defined $context->{globals}{m};
    if (@masks) {
        my $plural = @masks == 1 ? "" : "s";
        $context->{notice}("Added user \cc04$handle\co with address mask$plural \cc10@masks\co");
    } else {
        $context->{notice}("Added user \cc04$handle\co with no address masks.");
    }
    update_all_masks;
    user_changed $hdl;
    autosave_config;
}

sub cmd_user_remove($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    unless ($args =~ /^ *$handle_re *$/o) {
        $context->{usage}("user remove <handle>");
        return;
    }
    my $handle = $1;
    handle_exists $context, $handle or return;
    my $hdl = lc $handle;
    may_manage $context, $hdl or return;
    $context->{notice}("Removed user \cc04$handles{$hdl}\co.");
    delete $user_flags{$hdl};
    delete $user_channel_flags{$hdl};
    user_changed $hdl;
    delete $handles{$hdl};
    delete $user_masks{$hdl};
    update_all_masks;
    autosave_config;
};

sub cmd_mask_add($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    unless ($args =~ /^ *$handle_re +$masks_re *$/o) {
        $context->{usage}("mask add <handle> <mask>...");
        return;
    }
    my ($handle, $masks) = ($1, $2);
    handle_exists $context, $handle or return;
    my $hdl = lc $handle;
    may_manage $context, $hdl or return;
    my %masks = map {$_ => 1} @{$user_masks{$hdl}};
    foreach my $mask (unique_masks(split(' ', $masks))) {
        $masks{$mask} = 1;
    }
    $user_masks{$hdl} = [sort keys %masks];
    show_handle $context, $hdl;
    update_all_masks;
    user_changed $hdl;
    autosave_config;
}

sub cmd_mask_remove($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    unless ($args =~ /^ *$handle_re +$masks_re *$/o) {
        $context->{usage}("mask remove <handle> <mask>...");
        return;
    }
    my ($handle, $masks) = ($1, $2);
    handle_exists $context, $handle or return;
    my $hdl = lc $handle;
    may_manage $context, $hdl or return;
    my %masks = map {$_ => 1} @{$user_masks{$hdl}};
    foreach my $mask (unique_masks(split(' ', $masks))) {
        delete $masks{$mask};
    }
    $user_masks{$hdl} = [sort keys %masks];
    show_handle $context, $hdl;
    update_all_masks;
    user_changed $hdl;
    autosave_config;
}

sub cmd_user_rename($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    unless ($args =~ /^ *$handle_re +$handle_re *$/o) {
        $context->{usage}("user rename <handle> <new-handle>");
        return;
    }
    my ($old_handle, $new_handle) = ($1, $2);
    handle_exists $context, $old_handle or return;
    my $old_hdl = lc $old_handle;
    my $new_hdl = lc $new_handle;
    may_manage $context, $old_hdl or return;
    if ($new_hdl ne $old_hdl && defined $handles{$new_hdl}) {
        $context->{error}("User \cc04$handles{$new_hdl}\co already exists.");
        return;
    }
    $handles{$new_hdl} = $new_handle;
    if ($new_hdl ne $old_hdl) {
        delete $handles{$old_hdl};
        $user_masks{$new_hdl} = $user_masks{$old_hdl};
        delete $user_masks{$old_hdl};
        if ($user_flags{$old_hdl}) {
            $user_flags{$new_hdl} = $user_flags{$old_hdl};
            delete $user_flags{$old_hdl};
        }
        if ($user_channel_flags{$old_hdl}) {
            $user_channel_flags{$new_hdl} = $user_channel_flags{$old_hdl};
            delete $user_channel_flags{$old_hdl};
        }
    }
    $context->{notice}("Renamed user \cc04$old_handle\co to \cc04$new_handle\co.");
    autosave_config;
}

######## MANAGE FLAGS ########

sub flag_usage($) {
    my ($context) = @_;
    $context->{usage}     ("flag <handle>");
    $context->{usage_next}("flag [<chatnet>/]<#channels>");
    $context->{usage_next}("flag <handle>                         <flags>");
    $context->{usage_next}("flag          [<chatnet>/]<#channels> <flags>");
    $context->{usage_next}("flag <handle> [<chatnet>/]<#channels> <flags>");
    $context->{error}("<flags> is (+<letter>...|-<letter>...)...");
    $context->{error}("The last +<letter> may be followed by space and <argument>");
}

sub parse_flags($) {
    my ($flags) = @_;
    return map {
        my ($dir, $force) = /^\+/ ? ('', 0) : /^-/ ? (undef, 0) : (undef, 1);
        map {[$_, $dir, $force]} (/[a-zA-Z]/g)
    } ($flags =~ /[+\-!][a-zA-Z]+/g);
}

sub cmd_flag($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    if ($args =~ /^ *(?:$chatnet_re\/)?$channels_re *$/o) {
        my ($chatnet, $channels) = ($1, lc $2);
        $chatnet = default_chatnet $context unless defined $chatnet;
        $chatnet = lc $chatnet;
        foreach my $channel (split /,/, $channels) {
            show_channel $context, $chatnet, $channel, 1;
        }
        return;
    }
    if ($args =~ /^ *$handle_re *$/o) {
        my ($hdl) = lc $1;
        show_handle $context, $hdl;
        return;
    }
    unless ($args =~ /^ *(?:$handle_re +)??(?:(?:$chatnet_re\/)?$channels_re +)?$flags_re$arg_re$/o) {
        flag_usage $context; return;
    }
    my ($handle, $chatnet, $channels, $flags, $arg) = ($1, $2, $3, $4, $5);
    unless (defined $handle || defined $channels) {
        flag_usage $context; return;
    }
    $arg = '' unless defined $arg;
    if (defined $handle) {
        handle_exists $context, $handle or return;
    }
    my $hdl = lc $handle;
    my @channels = ();
    if (defined $channels) {
        $chatnet = default_chatnet $context unless defined $chatnet;
        $chatnet = lc $chatnet;
        @channels = map {[$chatnet, lc $_]} split /,/, $channels;
    }
    my @changes = parse_flags $flags;
    if ($arg ne '') {
        unless (defined $changes[$#changes][1]) {
            flag_usage $context; return;
        }
        $changes[$#changes][1] = $arg;
    }
    foreach my $change (@changes) {
        my ($flag, $arg, $force) = @$change;
        my $new_flag = tr_flag $flag;
        if ($new_flag ne $flag) {
            $context->{error}("Please use \cc9+$new_flag\co instead of \cc9+$flag\co.");
            $flag = $new_flag;
            $change->[0] = $flag;
        }
        unless ($context->{set_flags}{$flag}) {
            if ($context->{owner}) {
                $context->{error}("Warning, only flags \cc9$context->{set_flags_str}\co are meaningful.");
            } else {
                $context->{error}("Sorry, you can only set flags \cc9$context->{set_flags_str}\co.");
                return;
            }
        }
    }
    unless ($context->{owner} || defined $context->{globals}{m}) {
        if (@channels) {
            foreach my $chatnet_channel (@channels) {
                my ($chatnet, $channel) = @$chatnet_channel;
                unless (defined $context->{locals}{$chatnet}{$channel}{m}) {
                    $context->{error}("Sorry, you don't have master privileges in \cb$channel\cb.");
                    return;
                }
            }
        } else {
            my $chatnets = $context->{locals};
            foreach my $chatnet (keys %$chatnets) {
                my $channels = $chatnets->{$chatnet};
                foreach my $channel (keys %$channels) {
                    my $flags = $channels->{$channel};
                    push @channels, [$chatnet, $channel] if defined $flags->{m};
                }
            }
        }
    }
    if (defined $handle) {
        if (@channels) {
            foreach my $chatnet_channel (@channels) {
                my ($chatnet, $channel) = @$chatnet_channel;
                my $flags = \%{$user_channel_flags{$hdl}{$chatnet}{$channel}};
                foreach my $change (@changes) {
                    my ($flag, $arg, $force) = @$change;
                    my $global =
                      exists $channel_flags{$chatnet}{$channel}{$flag} ?
                      $channel_flags{$chatnet}{$channel}{$flag} :
                      $user_flags{$hdl}{$flag};
                    if ($force ||
                        defined $arg != defined $global ||
                        defined $arg && defined $global &&
                        $arg ne $global && $arg ne '') {
                        $flags->{$flag} = $arg;
                    } else {
                        delete $flags->{$flag};
                    }
                }
            }
            show_handle $context, $hdl;
            foreach my $chatnet_channel (@channels) {
                my ($chatnet, $channel) = @$chatnet_channel;
                user_channel_changed $hdl, $chatnet, $channel;
            }
        } else {
            my $flags = \%{$user_flags{$hdl}};
            foreach my $change (@changes) {
                my ($flag, $arg, $force) = @$change;
                if ($force || defined $arg) {
                    $flags->{$flag} = $arg;
                } else {
                    delete $flags->{$flag};
                }
            }
            show_handle $context, $hdl;
            user_changed $hdl;
        }
    } else {
        foreach my $chatnet_channel (@channels) {
            my ($chatnet, $channel) = @$chatnet_channel;
            my $flags = \%{$channel_flags{$chatnet}{$channel}};
            foreach my $change (@changes) {
                my ($flag, $arg, $force) = @$change;
                if ($force || defined $arg) {
                    $flags->{$flag} = $arg;
                } else {
                    delete $flags->{$flag};
                }
            }
            show_channel $context, $chatnet, $channel, 1;
            channel_changed $chatnet, $channel;
        }
    }
    autosave_config;
}

######## FIND USERS ########

sub cmd_find($$) {
    my ($context, $args) = @_;
    if ($args =~ /^ *(?:$chatnet_re\/)?$channel_re *$/o) {
        my ($chatnet, $channel) = ($1, lc $2);
        must_be_master $context or return;
        $chatnet = default_chatnet $context unless defined $chatnet;
        $chatnet = lc $chatnet;
        my $server = Irssi::server_find_chatnet $chatnet;
        unless ($server) {
            $context->{error}("Sorry, I'm not connected to $chatnet.");
            return;
        }
        my $chan = $server->channel_find($channel);
        unless ($chan) {
            $context->{error}("Sorry, I'm not on $channel.");
        }
        my @people = ();
        foreach my $who ($chan->nicks()) {
            my $nick = $who->{nick};
            next if $nick eq $server->{nick};
            my $address = $who->{host};
            my ($hdl, $mask) = find_best_user undef, $nick, $address;
            next unless defined $hdl;
            push @people, [$hdl, $nick, $address];
        }
        unless (@people) {
            $context->{crap}("I don't recognize any people from \cb$channel\cb.");
            return;
        }
        $context->{crap}("Recognized people on \cb$channel\cb:");
        foreach my $person (sort {$a->[0] cmp $b->[0]} @people) {
            my ($hdl, $nick, $address) = @$person;
            $context->{crap}(show_who $hdl, $nick, $address);
        }
    } elsif ($args =~ /^ *$mask_re *$/o) {
        my $mask = $1;
        must_be_master $context or return;
        my ($nick, $address);
        if ($mask =~ /^(.*)!(.*)$/) {
            ($nick, $address) = ($1, $2);
        } elsif ($mask =~ /\@/) {
            ($nick, $address) = ('*', $mask);
        } else {
            $nick = $mask;
            $address = find_nick $nick;
            unless (defined $address) {
                $context->{error}("I don't see \cc11$nick\co on my channels.");
                return;
            }
        }
        my @users = find_users undef, $nick, $address;
        unless (@users) {
            $context->{error}("I don't know who \cc11$nick\co \cc14[\cc10$address\cc14]\co is.");
            return;
        }
        foreach my $user (@users) {
            my ($hdl, $mask) = @$user;
            my $who = show_who $hdl, $nick, $address;
            $context->{crap}("$who \cc14(\cc10$mask\cc14)\co");
        }
    } elsif ($context->{owner} && $args =~ /^ *$/) {
        my %people = ();
        my %channels = ();
        foreach my $server (Irssi::servers) {
            my $chatnet = lc $server->{chatnet};
            foreach my $chan ($server->channels()) {
                my $channel = lc $chan->{name};
                foreach my $who ($chan->nicks()) {
                    my $nick = $who->{nick};
                    next if $nick eq $server->{nick};
                    my $address = $who->{host};
                    my ($hdl, $mask) = find_best_user undef, $nick, $address;
                    next unless defined $hdl;
                    $people{$chatnet}{$nick} = [$address, $hdl];
                    push @{$channels{$chatnet}{$nick}}, $channel;
                }
            }
        }
        my @people = ();
        foreach my $chatnet (keys %people) {
            my $nicks = $people{$chatnet};
            foreach my $nick (keys %$nicks) {
                my ($address, $hdl) = @{$nicks->{$nick}};
                my $channels = $channels{$chatnet}{$nick};
                push @people, [$hdl, $chatnet, $nick, $address, $channels];
            }
        }
        foreach my $person (sort {$a->[0] cmp $b->[0]} @people) {
            my ($hdl, $chatnet, $nick, $address, $channels) = @$person;
            my $who = show_who $hdl, $nick, $address;
            my $channels_txt = join(", ", sort @$channels);
            $context->{crap}("\cc14[\co$chatnet\cc14]\co $who is on \cb$channels_txt\cb");
        }
    } else {
        if ($context->{owner}) {
            $context->{usage}     ("find");
            $context->{usage_next}("find <#channel>");
        } else {
            $context->{usage}     ("find <#channel>");
        }
        $context->{usage_next}("find <mask>");
        $context->{usage_next}("find <nick>");
    }
};

######## OPERATOR COMMANDS ########

sub find_channel($$$) {
    my ($context, $channel, $need_op) = @_;
    my $chan = $context->{server}->channel_find($channel);
    if ($chan) {
        if ($need_op && !$chan->{chanop}) {
            $context->{error}("Sorry, I'm not an operator on \cb$channel\cb.");
            return undef;
        }
        return $chan;
    } else {
        $context->{error}("Sorry, I'm not on \cb$channel\cb.");
        return undef;
    }
}

sub must_be_channel_operator($$$) {
    my ($context, $chatnet, $channel) = @_;
    return 1 if has_local_flag($context, $chatnet, $channel, 'o') ||
      has_local_flag($context, $chatnet, $channel, 'm');
    $context->{error}("Sorry, you don't have operator privileges on \cb$channel\cb.");
    return 0;
}

sub cmd_trust($$) {
    my ($context, $args) = @_;
    must_be_master $context or return;
    my @nicks = map { lc } split /\s+/, $args;
    my $chatnet = lc default_chatnet $context;
    my $server = Irssi::server_find_chatnet $chatnet;
    foreach my $nick (@nicks) {
        my $address = find_server_nick $server, $nick;
        unless (defined $address) {
            $context->{error}("I don't see \cc11$nick\co in \cb$chatnet\cb.");
            next;
        }
        my @users = find_users undef, $nick, $address;
        unless (@users) {
            $context->{error}("I don't recognize \cc11$nick\co.");
        }
        foreach my $user (@users) {
            my ($hdl, $mask) = @$user;
            unless (defined $user_flags{$hdl}{p}) {
                $context->{error}("\cc04$hdl\co doesn't need a password.");
                next;
            }
            $context->{notice}("Trusting \cc11$nick\co to be \cc04$hdl\co " .
              "on \cb$chatnet\cb.");
            $authenticated{$chatnet}{$address}{$hdl} = 1;
            maybe_disappears $chatnet, $server, undef, $nick, $address;
            foreach my $chan ($server->channels()) {
                next unless $chan->{wholist};
                next unless $chan->{chanop};
                my $channel = lc $chan->{name};
                # nick_find_mask() only returns one nick.
                foreach my $who (grep { $_->{host} eq $address } $chan->nicks()) {
                    my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
                    next if defined $flags->{x};
                    if (defined $flags->{r} || defined $flags->{o}) {
                        queue_action $chatnet, '+o', $channel, $who->{nick};
                    }
                    if (defined $flags->{v}) {
                        queue_action $chatnet, '+v', $channel, $who->{nick};
                    }
                    # FIXME: flag +e?
                }
            }
        }
    }
}

sub cmd_op($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re(?: +$nicks_re)? *$/o) {
        $context->{usage}("op <#channel> [<nick>]...");
        return;
    }
    my ($channel, $nicks) = (lc $1, $2);
    my @nicks = defined $nicks ? split ' ', $nicks : ($context->{nick});
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @good = ();
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        next if $who->{op};
        unless (has_local_flag($context, $chatnet, $channel, 'm')) {
            my $address = $who->{host};
            my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
            if (!defined $flags->{o} && defined $flags->{d}) {
                $context->{error}("I refuse to op \cb$nick\cb on \cb$channel\cb - has \cc9+d\co flag.");
                next;
            }
        }
        push @good, $nick;
    }
    if (@good) {
        my $cmd = "+" . "o" x @good . " @good";
        channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
        $server->command("mode $channel $cmd");
    }
}

sub cmd_deop($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re(?: +$nicks_re)? *$/o) {
        $context->{usage}("deop <#channel> [<nick>]...");
        return;
    }
    my ($channel, $nicks) = (lc $1, $2);
    my @nicks = defined $nicks ? split ' ', $nicks : ($context->{nick});
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @good = ();
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        next unless $who->{op};
        unless (has_local_flag($context, $chatnet, $channel, 'm')) {
            if ($nick eq $server->{nick}) {
                $context->{error}("I refuse to deop myself on \cb$channel\cb.");
                next;
            }
            my $address = $who->{host};
            my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
            if (defined $flags->{r} && $nick ne $context->{nick}) {
                $context->{error}("I refuse to deop \cb$nick\cb on \cb$channel\cb - has \cc9+r\co flag.");
                next;
            }
        }
        push @good, $nick;
    }
    if (@good) {
        my $cmd = "-" . "o" x @good . " @good";
        channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
        $server->command("mode $channel $cmd");
    }
}

sub cmd_voice($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re(?: +$nicks_re)? *$/o) {
        $context->{usage}("voice <#channel> [<nick>]...");
        return;
    }
    my ($channel, $nicks) = (lc $1, $2);
    my @nicks = defined $nicks ? split ' ', $nicks : ($context->{nick});
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @good = ();
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        next if $who->{voice};
        unless (has_local_flag($context, $chatnet, $channel, 'm')) {
            my $address = $who->{host};
            my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
            if (!defined $flags->{v} && defined $flags->{q}) {
                $context->{error}("I refuse to voice \cb$nick\cb on \cb$channel\cb - has \cc9+q\co flag.");
                next;
            }
        }
        push @good, $nick;
    }
    if (@good) {
        my $cmd = "+" . "v" x @good . " @good";
        channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
        $server->command("mode $channel $cmd");
    }
}

sub cmd_devoice($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re(?: +$nicks_re)? *$/o) {
        $context->{usage}("devoice <#channel> [<nick>]...");
        return;
    }
    my ($channel, $nicks) = (lc $1, $2);
    my @nicks = defined $nicks ? split ' ', $nicks : ($context->{nick});
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @good = ();
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        next unless $who->{voice};
        push @good, $nick;
    }
    if (@good) {
        my $cmd = "-" . "v" x @good . " @good";
        channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
        $server->command("mode $channel $cmd");
    }
}

sub cmd_kick($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re +$nicks_commas_re(| .*)$/o) {
        $context->{usage}("kick <#channel> <nicks> [<reason>]");
        return;
    }
    my ($channel, $nicks, $reason) = (lc $1, $2, $3);
    my @nicks = split /,/, $nicks;
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    $reason = " $context->{nick}" if $reason =~ /^ ?$/;
    $reason =~ s/^ //;
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        unless (has_local_flag($context, $chatnet, $channel, 'm')) {
            if ($nick eq $server->{nick}) {
                $context->{error}("I refuse to kick myself from \cb$channel\cb.");
                next;
            }
        }
        channel_notice $server, $channel, "$nick was kicked from $channel by $context->{nick} [$reason]";
        $server->command("kick $channel $nick $reason");
    }
}

sub cmd_ban($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re +$masks_re *$/o) {
        $context->{usage}("ban <#channel> <mask/nick>...");
        return;
    }
    my ($channel, $masks) = (lc $1, $2);
    my @masks = split ' ', $masks;
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @good = ();
    foreach my $mask (@masks) {
        if ($mask !~ /!/) {
            if ($mask =~ /\@/) {
                $mask = "*!$mask";
            } else {
                my $who = $chan->nick_find($mask);
                unless ($who) {
                    $context->{error}("\cb$mask\cb is not on \cb$channel\cb.");
                    next;
                }
                my $address = $who->{host};
                if ($address eq '') {
                    $context->{error}("Sorry, I don't know \cb$mask\cb's address yet.");
                    next;
                }
                $mask = "*!" . improve_mask $address;
            }
        }
        push @good, $mask;
    }
    if (@good) {
        my $cmd = "+" . "b" x @good . " @good";
        channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
        $server->command("mode $channel $cmd");
    }
}

sub cmd_unban($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re(?: +$masks_re)? *$/o) {
        $context->{usage}("unban <#channel> [<masks>]");
        return;
    }
    my ($channel, $masks) = (lc $1, $2);
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    my @masks = ();
    if (defined $masks) {
        @masks = split ' ', $masks;
    } else {
        my $nick = $context->{nick};
        my $address = $context->{address};
        foreach my $ban ($chan->bans()) {
            push @masks, $ban->{ban}
              if Irssi::mask_match_address($ban->{ban}, $nick, $address);
        }
        unless (@masks) {
            $context->{notice}("There are no bans against you on \cb$channel\cb.");
            return;
        }
    }
    my $cmd = "-" . "b" x @masks . " @masks";
    channel_notice $server, $channel, "mode/$channel [$cmd] by $context->{nick}";
    $server->command("mode $channel $cmd");
    unless (defined $masks) {
        $context->{notice}("Any bans against you on \cb$channel\cb have been cleared.");
    }
}

sub cmd_kickban($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    unless ($args =~ /^ *$channel_re +$nicks_commas_re(| .*)$/o) {
        $context->{usage}("kickban <#channel> <nicks> [<reason>]");
        return;
    }
    my ($channel, $nicks, $reason) = (lc $1, $2, $3);
    my @nicks = split /,/, $nicks;
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    $reason = " $context->{nick}" if $reason =~ /^ ?$/;
    $reason =~ s/^ //;
    foreach my $nick (@nicks) {
        my $who = $chan->nick_find($nick);
        unless ($who) {
            $context->{error}("\cb$nick\cb is not on \cb$channel\cb.");
            next;
        }
        unless (has_local_flag($context, $chatnet, $channel, 'm')) {
            if ($nick eq $server->{nick}) {
                $context->{error}("I refuse to kick myself from \cb$channel\cb.");
                next;
            }
        }
        my $address = $who->{host};
        if ($address eq '') {
            $context->{error}("Sorry, I don't know \cb$nick\cb's address yet.");
        } else {
            ban $server, $channel, $nick, $address, $$who->{op}, {};
        }
        channel_notice $server, $channel, "$nick was kicked from $channel by $context->{nick} [$reason]";
        $server->command("kick $channel $nick $reason");
    }
}

sub cmd_invite($$) {
    my ($context, $args) = @_;
    must_be_operator $context or return;
    my ($channel, $nick);
    if ($args =~ /^ *$channel_re(?: +$nick_re)? *$/o) {
        ($channel, $nick) = (lc $1, $2);
    } elsif ($args =~ /^ *$nick_re +$channel_re *$/o) {
        ($nick, $channel) = ($1, lc $2);
    } else {
        $context->{usage}("invite <#channel> [<nick>]");
        return;
    }
    $nick = $context->{nick} unless defined $nick;
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    must_be_channel_operator $context, $chatnet, $channel or return;
    my $chan = find_channel $context, $channel, 1 or return;
    if ($chan->nick_find($nick)) {
        $context->{error}("\cb$nick\cb is already on \cb$channel\cb");
        return;
    }
    channel_notice $server, "$nick,$channel",  "$context->{nick} invited $nick into $channel";
    $server->command("invite $nick $channel");
}

######## AUTHENTICATION ########

sub must_have_crypt($) {
    my ($context) = @_;
    $context->{error}("Sorry, passwords don't work here - Crypt::PasswdMD5 module not found.")
      unless $has_crypt;
    return $has_crypt;
}

our @salt_chars = ('.', '/', '0'..'9', 'A'..'Z', 'a'..'z');

sub crypt_new_password($) {
    my ($password) = @_;
    my $salt = join('', map {$salt_chars[rand @salt_chars]} (1..8));
    return unix_md5_crypt($password, $salt);
}

sub check_password($$) {
    my ($password, $required) = @_;
    return $required eq unix_md5_crypt($password, $required);
}

sub cmd_pass($$) {
    my ($context, $args) = @_;
    unless ($args =~ /^ *([^ ]+)(?: +([^ ]+))? *$/) {
        $context->{usage}     ("pass <password>   - authenticate or set password for the first time");
        $context->{usage_next}("pass <password> <new-password>   - change password");
        return;
    }
    my ($password, $new_password) = ($1, $2);
    my $server = $context->{server};
    my $chatnet = lc $server->{chatnet};
    my $nick = $context->{nick};
    my $address = $context->{address};
    my $password_set = 0;
    my $right_password = 0;
    my $wrong_password = 0;
    foreach my $user (find_users undef, $nick, $address) {
        my ($hdl, $mask) = @$user;
        my $required = $user_flags{$hdl}{p};
        next unless defined $required;
        must_have_crypt $context or return;
        my $who_nick = "\cc11$nick\co \cc14[\cc10$address\cc14]\co";
        my $who_hdl = "\cc04$handles{$hdl}\co";
        if ($required ne '' && !check_password($password, $required)) {
            print CLIENTNOTICE "$who_nick gave \cbwrong\cb password for $who_hdl.";
            $wrong_password = 1;
            next;
        }
        if ($required eq '' || defined $new_password) {
            $password = $new_password if defined $new_password;
            $user_flags{$hdl}{p} = crypt_new_password $password;
            print CLIENTNOTICE "$who_nick \cbset\cb the password for $who_hdl.";
            $password_set = 1;
        } else {
            print CLIENTNOTICE "$who_nick gave \cbright\cb password for $who_hdl.";
            $right_password = 1;
        }
        $authenticated{$chatnet}{$address}{$hdl} = 1;
        maybe_disappears $chatnet, $server, undef, $nick, $address;
        foreach my $chan ($server->channels()) {
            next unless $chan->{wholist};
            next unless $chan->{chanop};
            my $channel = lc $chan->{name};
            # nick_find_mask() only returns one nick.
            foreach my $who (grep { $_->{host} eq $address } $chan->nicks()) {
                my ($flags, $users) = find_local_flags $chatnet, $channel, $nick, $address;
                next if defined $flags->{x};
                if (defined $flags->{r} || defined $flags->{o}) {
                    queue_action $chatnet, '+o', $channel, $who->{nick};
                }
                if (defined $flags->{v}) {
                    queue_action $chatnet, '+v', $channel, $who->{nick};
                }
                # FIXME: flag +e?
            }
        }
    }
    if ($password_set || $right_password) {
        $context->{notice}("Your password has been set.") if $password_set;
        $context->{notice}("Right password.") if $right_password;
    } elsif ($wrong_password) {
        $context->{error}("Wrong password.");
    } else {
        $context->{error}("Sorry, I don't recognize you.");
    }
    save_config if $password_set;
}

######## LOCAL COMMANDS ########

Irssi::command_bind 'user', sub {
    my ($args, $server, $target) = @_;
    Irssi::command_runsub 'user', $args, $server, $target;
};

Irssi::command_bind 'mask', sub {
    my ($args, $server, $target) = @_;
    Irssi::command_runsub 'mask', $args, $server, $target;
};

sub local_command($$) {
    my ($command, $func) = @_;
    Irssi::command_bind $command, sub {
        my ($args, $server, $target) = @_;
        $func->($local_context, $args);
    };
    $local_help{$command} = 1;
}

local_command 'help',        \&cmd_help;
delete $local_help{help};
local_command 'user add',    \&cmd_user_add;
local_command 'user remove', \&cmd_user_remove;
local_command 'mask add',    \&cmd_mask_add;
local_command 'mask remove', \&cmd_mask_remove;
local_command 'user rename', \&cmd_user_rename;
local_command 'user list',   \&cmd_user_list;
local_command 'flag',        \&cmd_flag;
local_command 'find',        \&cmd_find;
local_command 'trust',       \&cmd_trust;

######## RESPOND TO MESSAGES ########

our %commands;

sub run_subcommand($$$) {
    my ($command, $context, $args) = @_;
    if ($args =~ / *([a-zA-Z]+)(| .*)$/) {
        my ($subcommand, $subargs) = ($1, $2);
        my $func = $commands{"$command " . lc $subcommand} or return;
        $func->($context, $subargs);
    }
}

%commands = (
    help          => \&cmd_help,
    user          => sub {&run_subcommand('user', @_)},
    mask          => sub {&run_subcommand('mask', @_)},
    'user add'    => \&cmd_user_add,
    'user remove' => \&cmd_user_remove,
    'mask add'    => \&cmd_mask_add,
    'mask remove' => \&cmd_mask_remove,
    'user rename' => \&cmd_user_rename,
    'user list'   => \&cmd_user_list,
    flag          => \&cmd_flag,
    find          => \&cmd_find,
    trust         => \&cmd_trust,
    op            => \&cmd_op,
    deop          => \&cmd_deop,
    voice         => \&cmd_voice,
    devoice       => \&cmd_devoice,
    kick          => \&cmd_kick,
    ban           => \&cmd_ban,
    unban         => \&cmd_unban,
    kickban       => \&cmd_kickban,
    invite        => \&cmd_invite,
    pass          => \&cmd_pass,
);

sub remote_command($$$$$$) {
    my ($server, $msg, $nick, $address, $reply, $prefix) = @_;
    return 0 unless $msg =~ /^([a-zA-Z]+)(| .*)$/;
    my ($command, $args) = ($1, $2);
    my $func = $commands{lc $command} or return 0;
    my $chatnet = lc $server->{chatnet};
    my ($globals, $locals) = find_all_flags $chatnet, $nick, $address;
    my $context = {
        crap           => sub {$server->command("$reply $nick $_[0]")},
        notice         => sub {$server->command("$reply $nick $_[0]")},
        error          => sub {$server->command("$reply $nick $_[0]")},
        usage          => sub {$server->command("$reply $nick Usage: $prefix$_[0]")},
        usage_next     => sub {$server->command("$reply $nick        $prefix$_[0]")},
        owner          => 0,
        globals        => $globals,
        locals         => $locals,
        set_flags      => \%master_set_flags,
        set_flags_str  => $master_set_flags,
        see_flags      => \%master_see_flags,
        server         => $server,
        nick           => $nick,
        address        => $address,
    };
    $func->($context, $args);
    return 1;
}

Irssi::signal_add_last 'message private', sub {
    my ($server, $msg, $nick, $address) = @_;
    return unless $msg =~ /^!(.*)$/;
    Irssi::signal_continue @_;
    remote_command $server, $1, $nick, $address, "notice", "!";
};

Irssi::signal_add_last "ctcp msg", sub {
    my ($server, $args, $nick, $address, $target) = @_;
    return unless lc $target eq lc $server->{nick};
    remote_command $server, $args, $nick, $address, "notice", ""
      and Irssi::signal_stop;
};

######## INITIALIZATION ########

load_config;
