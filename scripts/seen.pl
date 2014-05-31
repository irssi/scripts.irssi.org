use strict;
use 5.005_62;       # for 'our'
use Irssi 20020428; # for Irssi::signal_continue
use vars qw($VERSION %IRSSI);

$VERSION = "1.8";
%IRSSI = (
    authors     => 'Marcin \'Qrczak\' Kowalczyk',
    contact     => 'qrczak@knm.org.pl',
    name        => 'Seen',
    description => 'Tell people when other people were online',
    license     => 'GPL',
    url         => 'http://qrnik.knm.org.pl/~qrczak/irssi/seen.pl',
);

######## User interface ########

# COMMANDS
# ========
#
# /seen <nick>
#     Show last seen info about nick.
#
# /say_seen [<to_whom>] <nick>
#     Say last seen info about nick in the current window. If to_whom
#     is present, answer as if that person issued a seen request.
#
# /listen on [[<chatnet>] <channel>]
#     Turn on listening for seen requests in the current or given channel.
#
# /listen off [[<chatnet>] <channel>]
#     Turn off listening for seen requests in the current or given channel.
#
# /listen delay [[<chatnet>] <channel>]
#     Turn on listening for seen requests in the current or given channel.
#     We will reply only if nobody else replies with a message containing
#     the given nick (probably a seen reply from another bot) in seen_delay
#     seconds.
#
# /listen private [[<chatnet>] <channel>]
#     Turn on listening for seen requests in the current or given channel.
#     The reply will be sent as a private notice.
#
# /listen disable [[<chatnet>] <channel>]
#     Same as "off", used to distinguish channels where we won't listen
#     for sure from channels we didn't specify anything about.
#
# /listen list
#     Show which channels we are listening for seen requests on.

# Forms of seen requests from other people:
#     Public message "<our_nick>: seen <nick>".
#     Public message "seen <nick>" on channels where we are listening.
#     Private message "seen <nick>".
#     Any of the above with "!seen" instead of "seen".
#     Any of the above with a question mark at the end.
#     Any of the above with "jest <nick>?", "by³ <nick>?", "by³a <nick>?",
#       "<nick> jest?", "<nick> by³?", "<nick> by³a?", with optional
#       "czy" at the beginning - provided that we know that nick
#       (to avoid treating some other message as a seen request).

# VARIABLES
# =========
#
# seen_expire_after
#     After that number of days we forget about nicks and addresses.
#     Default 30.
#
# seen_expire_asked_after
#     After that number of days we forget that that somebody was
#     searched for and don't send a notice. Default 7.
#
# seen_delay   
#     On channels set to '/listen delay' we reply if after that number
#     of seconds nobody else replies. Default 60.

######## Internal structure of the database in memory ########

# %listen_on      = (chatnet => {channel => listening})
# %address_absent = (chatnet => {address => time})
# %nicks          = (chatnet => {address => [nick]})
# %last_nicks     = (chatnet => {address => nick})
# %how_quit       = (chatnet => {address => how_quit})
# %spoke          = (chatnet => {address => time})
# %nick_absent    = (chatnet => {nick => time})
# %addresses      = (chatnet => {nick => address})
# %orig_nick      = (chatnet => {nick => nick})
# %channels       = (chatnet => {nick => [channel]})
# %asked          = (chatnet => {nick => {nick_asks => time}})

# listening:
#   'on', undef = 'off', 'delay', 'private', 'disable'

# how_quit:
#   ['disappeared']
#   ['was_left', kanal]
#   ['left', channel, reason]
#   ['quit', channels, reason]
#   ['was_kicked', channel, kicker, reason]

######## Global variables ########

our %listen_on = ();
our %address_absent = ();
our %nicks = ();
our %last_nicks = ();
our %how_quit = ();
our %spoke = ();
our %nick_absent = ();
our %addresses = ();
our %orig_nick = ();
our %channels = ();
our %asked = ();

Irssi::settings_add_int "seen", "seen_expire_after", 30;      # days
Irssi::settings_add_int "seen", "seen_expire_asked_after", 7; # days
Irssi::settings_add_int "seen", "seen_delay", 60;             # seconds

our $database     = Irssi::get_irssi_dir . "/seen.dat";
our $database_tmp = Irssi::get_irssi_dir . "/seen.tmp";
our $database_old = Irssi::get_irssi_dir . "/seen.dat~";

######## Utilities ########

our $nick_regexp = qr/
  [A-Z\[\\\]^_`a-z{|}\200-\377]
  [\-0-9A-Z\[\\\]^_`a-z{|}\200-\377]*
  /x;
our $seen_regexp = qr/^ *!?seen +($nick_regexp) *\?* *$/i;
our $maybe_seen_regexp1 = qr/
  ^\ *
  (?:a\ +)?
  (?:(?:if|when|here)\ +)?
  (?:(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e)\ +)*
  (?:in|by[³l]a?)\ +
  (?:(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e)\ +)*
  ($nick_regexp)
  (?:\ +(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e))*
  \ *\?+\ *$/ix;
our $maybe_seen_regexp2 = qr/
  ^\ *
  (?:a\ +)?
  (?:(?:czy|kiedy|gdzie)\ +)?
  (?:(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e)\ +)*
  ($nick_regexp)?\ +
  (?:(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e)\ +)*
  (?:in|by[³l]a?)
  (?:\ +(?:dzi[¶s]|today|last time|recently|ju[¿z]|here|tutaj|mo[¿z]e))*
  \ *\?+\ *$/ix;
our $exclude_regexp = qr/^(?:kto[¶s]?|who?|that?|that|ladna|i|a)$/i;

sub lc_irc($) {
    my ($str) = @_;
    $str =~ tr/A-Z[\\]/a-z{|}/;
    return $str;
}

sub uc_irc($) {
    my ($str) = @_;
    $str =~ tr/a-z{|}/A-Z[\\]/;
    return $str;
}

our %lc_regexps = ();

sub lc_irc_regexp($) {
    my ($str) = @_;
    $str =~ s/(.)/my $lc = lc_irc $1; my $uc = uc_irc $1; "[\Q$lc$uc\E]"/eg;
    return $str;
}

sub canonical($) {
    my ($address) = @_;
    $address =~ s/^[\^~+=-]//;
    return $address;
}

sub show_list(@) {
    @_ == 0 and return "";
    @_ == 1 and return $_[0];
    return join(", ", @_[0..$#_-1]) . " i " . $_[$#_];
}

sub show_time_since($) {
    my ($time) = @_;
    my $diff = time() - $time;
    $diff >= 0 or return "nie wiem kiedy (zegarek mi sie popsul)";
    my $s = $diff % 60; $diff = int(($diff - $s) / 60);
    my $m = $diff % 60; $diff = int(($diff - $m) / 60);
    my $h = $diff % 24; $diff = int(($diff - $h) / 24);
    my $d = $diff;
    my $s_txt = $s ? "${s}s " : "";
    my $m_txt = $m ? "${m}m " : "";
    my $h_txt = $h ? "${h}h " : "";
    my $d_txt = $d ? "${d}d " : "";
    return
      $d ? "$d_txt${h_txt}ago" :
      $h ? "$h_txt${m_txt}ago" :
      $m ? "$m_txt${s_txt}ago" :
      "${s}s ago";
}

sub all_channels($@) {
    my ($chatnet, @nicks) = @_;
    my %chans = ();
    foreach my $nick (@nicks) {
        if ($channels{$chatnet}{lc_irc $nick}) {
            foreach my $channel (@{$channels{$chatnet}{lc_irc $nick}}) {
                $chans{$channel} = 1;
            }
        }
    }
    return keys %chans;
}

sub is_private($) {
    my ($channel) = @_;
    return $channel && $channel->{mode} =~ /^[^ ]*[ps]/;
}

sub mark_private($$) {
    my ($channel, $name) = @_;
    return is_private $channel ? "-$name" : $name;
}

######## Actions on the database in memory ########

sub do_listen($$$) {
    my ($chatnet, $channel, $state) = @_;
    if ($state eq 'off') {
        delete $listen_on{$chatnet}{$channel};
    } else {
        $listen_on{$chatnet}{$channel} = $state;
    }
}

sub do_join($$$$) {
    my ($chatnet, $address, $nick, $channel) = @_;
    my $lc_nick = lc_irc $nick;
    my $lc_channel = lc_irc $channel;
    delete $address_absent{$chatnet}{$address};
    push @{$nicks{$chatnet}{$address}}, $nick
      unless grep {lc_irc $_ eq $lc_nick} @{$nicks{$chatnet}{$address}};
    push @{$channels{$chatnet}{$lc_nick}}, $channel
      unless grep {lc_irc $_ eq $lc_channel} @{$channels{$chatnet}{$lc_nick}};
    delete $how_quit{$chatnet}{$address};
    delete $nick_absent{$chatnet}{$lc_nick};
    $addresses{$chatnet}{$lc_nick} = $address;
    $orig_nick{$chatnet}{$lc_nick} = $nick;
}

sub do_quit_all($$$$$) {
    my ($time, $chatnet, $address, $nick, $reason) = @_;
    $address_absent{$chatnet}{$address} = $time;
    delete $nicks{$chatnet}{$address};
    $last_nicks{$chatnet}{$address} = $nick;
    $how_quit{$chatnet}{$address} = $reason;
}

sub do_quit($$$$) {
    my ($time, $chatnet, $address, $nick) = @_;
    my $lc_nick = lc_irc $nick;
    $nicks{$chatnet}{$address} =
      [grep {lc_irc $_ ne $lc_nick} @{$nicks{$chatnet}{$address}}];
    delete $channels{$chatnet}{$lc_nick};
    $nick_absent{$chatnet}{$lc_nick} = $time;
    $addresses{$chatnet}{$lc_nick} = $address;
    $orig_nick{$chatnet}{$lc_nick} = $nick;
}

sub do_part($$$$) {
    my ($chatnet, $address, $nick, $channel) = @_;
    my $lc_nick = lc_irc $nick;
    my $lc_channel = lc_irc $channel;
    $channels{$chatnet}{$lc_nick} =
      [grep {lc_irc $_ ne $lc_channel} @{$channels{$chatnet}{$lc_nick}}];
}

sub do_nick($$$$$) {
    my ($time, $chatnet, $address, $old_nick, $new_nick) = @_;
    my $lc_old_nick = lc_irc $old_nick;
    my $lc_new_nick = lc_irc $new_nick;
    $nicks{$chatnet}{$address} =
      [(grep {lc_irc $_ ne $lc_old_nick} @{$nicks{$chatnet}{$address}}), $new_nick];
    my $chans = $channels{$chatnet}{$lc_old_nick};
    delete $channels{$chatnet}{$lc_old_nick};
    $channels{$chatnet}{$lc_new_nick} = $chans;
    $nick_absent{$chatnet}{$lc_old_nick} = $time;
    delete $nick_absent{$chatnet}{$lc_new_nick};
    $addresses{$chatnet}{$lc_new_nick} = $address;
    $orig_nick{$chatnet}{$lc_new_nick} = $new_nick;
}

sub do_spoke($$$) {
    my ($time, $chatnet, $address) = @_;
    my $old_time = $spoke{$chatnet}{$address};
    $spoke{$chatnet}{$address} = $time
      unless defined $old_time && $old_time > $time;
}

sub do_ask($$$$) {
    my ($time, $chatnet, $nick, $nick_asks) = @_;
    my $lc_nick = lc_irc $nick;
    my $lc_nick_asks = lc_irc $nick_asks;
    my $old_time = $asked{$chatnet}{$lc_nick}{$lc_nick_asks};
    $asked{$chatnet}{$lc_nick}{$lc_nick_asks} = $time
      unless defined $old_time && $old_time > $time;
}

sub do_forget_ask($$$) {
    my ($chatnet, $nick, $nick_asks) = @_;
    my $lc_nick = lc_irc $nick;
    my $lc_nick_asks = lc_irc $nick_asks;
    delete $asked{$chatnet}{$lc_nick}{$lc_nick_asks};
}

######## Actions on the database in memory and in the file ########

sub append_to_database(@) {
    open DATABASE, ">>$database";
    print DATABASE map {"$_\n"} @_;
    close DATABASE;
}

sub on_listen($$$) {
    my ($chatnet, $channel, $state) = @_;
    do_listen $chatnet, $channel, $state;
    append_to_database "listen $state $chatnet $channel";
}

sub on_join($$$$) {
    my ($chatnet, $address, $nick, $channel) = @_;
    do_join $chatnet, $address, $nick, $channel;
    append_to_database "join $chatnet $address $nick $channel";
}

sub on_quit_all($$$$) {
    my ($chatnet, $address, $nick, $reason) = @_;
    my $time = time();
    do_quit_all $time, $chatnet, $address, $nick, $reason;
    append_to_database "quit_all $time $chatnet $address $nick @$reason";
}

sub on_quit($$$$) {
    my ($chatnet, $address, $nick, $reason) = @_;
    my $time = time();
    do_quit $time, $chatnet, $address, $nick;
    append_to_database "quit $time $chatnet $address $nick";
    on_quit_all $chatnet, $address, $nick, $reason
      unless @{$nicks{$chatnet}{$address}};
}

sub on_part($$$$$) {
    my ($chatnet, $address, $nick, $channel, $reason) = @_;
    do_part $chatnet, $address, $nick, $channel;
    append_to_database "part $chatnet $address $nick $channel";
    on_quit $chatnet, $address, $nick, $reason
      unless @{$channels{$chatnet}{lc_irc $nick}};
}

sub on_nick($$$$) {
    my ($chatnet, $address, $old_nick, $new_nick) = @_;
    my $time = time();
    do_nick $time, $chatnet, $address, $old_nick, $new_nick;
    append_to_database "nick $time $chatnet $address $old_nick $new_nick";
}

sub on_spoke($$) {
    my ($chatnet, $address) = @_;
    my $time = time();
    return if $spoke{$chatnet}{$address} == $time;
    do_spoke $time, $chatnet, $address;
    append_to_database "spoke $time $chatnet $address";
}

sub on_ask($$$) {
    my ($chatnet, $nick, $nick_asks) = @_;
    my $time = time();
    do_ask $time, $chatnet, $nick, $nick_asks;
    append_to_database "ask $time $chatnet $nick $nick_asks";
}

######## Reading the database from file ########

sub syntax_error() {
    die "Syntax error in $database: $_";
}

our %parse_how_quit = (
    disappeared => sub {
        return ['disappeared'];
    },
    was_left => sub {
        $_[0] =~ /^ ([^ ]*)$/ or syntax_error;
        return ['was_left', $1];
    },
    left => sub {
        $_[0] =~ /^ ([^ ]*) (.*)$/ or syntax_error;
        return ['left', $1, $2];
    },
    quit => sub {
        $_[0] =~ /^ ([^ ]*) (.*)$/ or syntax_error;
        return ['quit', $1, $2];
    },
    was_kicked => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) (.*)$/ or syntax_error;
        return ['was_kicked', $1, $2, $3];
    },
);

sub parse_how_quit($) {
    my ($how_quit) = @_;
    $how_quit =~ /^([^ ]*)(| .*)$/ or syntax_error;
    my $func = $parse_how_quit{$1} or syntax_error;
    return $func->($2);
}

our %parse_database = (
    listen => sub {
        $_[0] =~ /^ (on|off|delay|private|disable) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_listen $2, $3, $1;
    },
    join => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_join $1, $2, $3, $4;
    },
    quit_all => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (.*)$/ or syntax_error;
        my ($time, $chatnet, $address, $nick, $how_quit) = ($1, $2, $3, $4, $5);
        do_quit_all $time, $chatnet, $address, $nick, parse_how_quit($how_quit);
    },
    quit => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_quit $1, $2, $3, $4;
    },
    part => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_part $1, $2, $3, $4;
    },
    nick => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_nick $1, $2, $3, $4, $5;
    },
    spoke => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_spoke $1, $2, $3;
    },
    ask => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_ask $1, $2, $3, $4;
    },
    forget_ask => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
        do_forget_ask $1, $2, $3;
    },
);

sub read_database() {
    open DATABASE, $database or return;
    while (<DATABASE>) {
        chomp;
        /^([^ ]*)(| .*)$/ or syntax_error;
        my $func = $parse_database{$1} or syntax_error;
        $func->($2);
    }
    close DATABASE;
}

######## Writing the database to file ########

sub write_database {
    open DATABASE, ">$database_tmp";
    foreach my $chatnet (keys %listen_on) {
        foreach my $channel (keys %{$listen_on{$chatnet}}) {
            my $state = $listen_on{$chatnet}{$channel};
            print DATABASE "listen $state $chatnet $channel\n";
        }
    }
    foreach my $chatnet (keys %nick_absent) {
        foreach my $nick (keys %{$nick_absent{$chatnet}}) {
            my $time = $nick_absent{$chatnet}{$nick};
            my $address = $addresses{$chatnet}{$nick};
            my $orig = $orig_nick{$chatnet}{$nick};
            print DATABASE "quit $time $chatnet $address $orig\n";
        }
    }
    foreach my $chatnet (keys %address_absent) {
        foreach my $address (keys %{$address_absent{$chatnet}}) {
            my $time = $address_absent{$chatnet}{$address};
            my $nick = $last_nicks{$chatnet}{$address};
            my $reason = $how_quit{$chatnet}{$address};
            print DATABASE "quit_all $time $chatnet $address $nick @$reason\n";
        }
    }
    foreach my $chatnet (keys %spoke) {
        foreach my $address (keys %{$spoke{$chatnet}}) {
            my $time = $spoke{$chatnet}{$address};
            print DATABASE "spoke $time $chatnet $address\n";
        }
    }
    foreach my $chatnet (keys %nicks) {
        foreach my $address (keys %{$nicks{$chatnet}}) {
            foreach my $nick (@{$nicks{$chatnet}{$address}}) {
                foreach my $channel (@{$channels{$chatnet}{lc_irc $nick}}) {
                    print DATABASE "join $chatnet $address $nick $channel\n";
                }
            }
        }
    }
    foreach my $chatnet (keys %asked) {
        foreach my $nick (keys %{$asked{$chatnet}}) {
            foreach my $nick_asked (keys %{$asked{$chatnet}{$nick}}) {
                my $time = $asked{$chatnet}{$nick}{$nick_asked};
                print DATABASE "ask $time $chatnet $nick $nick_asked\n";
            }
        }
    }
    close DATABASE;
    rename $database, $database_old;
    rename $database_tmp, $database;
}

######## Update the database to reflect currently joined users ########

sub initialize_database() {
    my $time = time();
    foreach my $chatnet (keys %nicks) {
        my @addresses = keys %{$nicks{$chatnet}};
        foreach my $address (@addresses) {
            my @nicks = @{$nicks{$chatnet}{$address}};
            foreach my $nick (@nicks) {
                do_quit $time, $chatnet, $address, $nick;
            }
            do_quit_all $time, $chatnet, $address, $nicks[0], ['disappeared'];
        }
    }
    foreach my $server (Irssi::servers()) {
        foreach my $channel ($server->channels()) {
            foreach my $nick ($channel->nicks()) {
                do_join lc $server->{chatnet},
                  canonical $nick->{host}, $nick->{nick}, $channel->{name}
                  if $nick->{host} ne "";
            }
        }
    }
}

######## Expire old entries ########

sub expire_database() {
    my $days = Irssi::settings_get_int("seen_expire_after");
    my $time = time() - $days*24*60*60;
    my %reachable_addresses = ();
    foreach my $chatnet (keys %addresses) {
        foreach my $address (values %{$addresses{$chatnet}}) {
            $reachable_addresses{$chatnet}{$address} = 1;
        }
    }
    foreach my $chatnet (keys %address_absent) {
        foreach my $address (keys %{$address_absent{$chatnet}}) {
            if ($address_absent{$chatnet}{$address} <= $time ||
                !$reachable_addresses{$chatnet}{$address}) {
                delete $address_absent{$chatnet}{$address};
                delete $last_nicks{$chatnet}{$address};
                delete $how_quit{$chatnet}{$address};
            }
        }
    }
    foreach my $chatnet (keys %spoke) {
        foreach my $address (keys %{$spoke{$chatnet}}) {
            if ($spoke{$chatnet}{$address} <= $time ||
                !$reachable_addresses{$chatnet}{$address}) {
                delete $spoke{$chatnet}{$address};
            }
        }
    }
    foreach my $chatnet (keys %nick_absent) {
        foreach my $nick (keys %{$nick_absent{$chatnet}}) {
            if ($nick_absent{$chatnet}{$nick} <= $time) {
                delete $nick_absent{$chatnet}{$nick};
                delete $addresses{$chatnet}{$nick};
                delete $orig_nick{$chatnet}{$nick};
            }
        }
    }
    my $days_asked = Irssi::settings_get_int("seen_expire_asked_after");
    my $time_asked = time() - $days_asked*24*60*60;
    foreach my $chatnet (keys %asked) {
        foreach my $nick (keys %{$asked{$chatnet}}) {
            foreach my $nick_asks (keys %{$asked{$chatnet}{$nick}}) {
                if ($asked{$chatnet}{$nick}{$nick_asks} <= $time_asked) {
                    delete $asked{$chatnet}{$nick}{$nick_asks};
                }
            }
        }
    }
}

######## Compose a description when did we see that person ########

sub show_reason($) {
    my ($reason) = @_;
    return ":" if $reason eq "";
    $reason =~ s/\cc\d\d?(,\d\d?)?|[\000-\037]//g;
    return ": $reason";
}

sub only_public(@$) {
    my $can_show = pop @_;
    my @channels = ();
    foreach my $channel (@_) {
        if ($channel =~ /^-(.*)$/) {
            push @channels, $1 if $can_show->($1);
        } else {
            push @channels, $channel;
        }
    }
    return wantarray ? @channels : $channels[0];
}

sub is_here(\@$) {
    my ($channels, $where_asks) = @_;
    return if !defined $where_asks;
    my $lc_where_asks = lc_irc $where_asks;
    foreach my $i (0..$#{$channels}) {
        if (lc_irc $channels->[$i] eq $lc_where_asks) {
            splice @{$channels}, $i, 1;
            return 1;
        }
    }
    return 0;
}

sub on_channels(@) {
    return @_ == 1 ? "on the channel $_[0]" : "on the channels " . show_list(@_);
}

our %show_how_quit = (
    disappeared => sub {
        return "they disappeared.  No more information is available.";
    },
    was_left => sub {
        my ($true_channel, $where_asks, $can_show) = @_;
        my $channel = only_public $true_channel, $can_show;
        return
          defined $channel ?
            lc_irc $channel eq lc_irc $where_asks ?
              "byla here i wtedy stad wyszedlem." :
              "byla na kanale $channel, z ktorego wtedy wyszedlem." :
            "byla na kanale, z ktorego wtedy wyszedlem.";
    },
    left => sub {
        my ($true_channel, $reason, $where_asks, $can_show) = @_;
        my $channel = only_public $true_channel, $can_show;
        return
          (defined $channel ?
            lc_irc $channel eq lc_irc $where_asks ?
              "person left" : "they left the channel $channel" :
            "left because") .
          show_reason($reason);
    },
    quit => sub {
        my ($true_channels, $reason, $where_asks, $can_show) = @_;
        my @channels = only_public split(/,/, $true_channels), $can_show;
        my $is_here = is_here @channels, $where_asks;
        return
          (@channels == 0 ?
            $is_here ? "they left " : "" :
            ($is_here ? "byla tutaj oraz " : "they were seen quitting ") .
            on_channels(@channels) .
            " ") .
          "with the message" . show_reason($reason);
    },
    was_kicked => sub {
        my ($true_channel, $kicker, $reason, $where_asks, $can_show) = @_;
        my $channel = only_public $true_channel, $can_show;
        return
          "they " .
          (defined $channel ?
            lc_irc $channel eq lc_irc $where_asks ?
              "were kicked" : "were kicked from $channel" :
            "kicked") .
          " by $kicker" . show_reason($reason);
    },
);

sub show_how_quit($$$) {
    my ($how_quit, $where_asks, $can_show) = @_;
    return $show_how_quit{$how_quit->[0]}
      (@{$how_quit}[1..$#{$how_quit}], $where_asks, $can_show);
}

sub show_where_is($$$$$$$) {
    my ($server, $nick, $address, $where_asks, $can_show, $asked_and, $spoke_and) = @_;
    my $chatnet = lc $server->{chatnet};
    my $lc_nick = lc_irc $nick;
    my @nicks = @{$nicks{$chatnet}{$address}};
    @nicks = sort @nicks;
    my @channels = all_channels($chatnet, @nicks);
    @channels =
      only_public
      map ({mark_private($server->channel_find($_), $_)} sort @channels),
      $can_show;
    my $is_here = is_here @channels, $where_asks;
    my $this_nick_absent = $nick_absent{$chatnet}{$lc_nick};
    return
      (defined $this_nick_absent ?
        "Osoba, ktora uzywala nicka $nick " .
        show_time_since($this_nick_absent) .
        ", $asked_and${spoke_and}teraz jest jako " .
        show_list(@nicks) .
        " " :
        "Queried user $asked_and${spoke_and}$nick is currently " .
        (@nicks == 1 ? "" : "(rowniez jako " .
          show_list(grep {lc_irc $_ ne $lc_nick} @nicks) . ") ")) .
      (@channels == 0 ?
        $is_here ? "in this channel" : "on IRC" :
        ($is_here ? "here on " : "") . on_channels(@channels)) .
      ".";
}

sub seen($$$$$$) {
    my ($server, $nick, $who_asks, $where_asks, $can_show, $asked) = @_;
    my $chatnet = lc $server->{chatnet};
    my $lc_nick = lc_irc $nick;
    my $address = $addresses{$chatnet}{$lc_nick};
    unless (defined $address) {
        if (defined $asked) {return "You asked- $asked about $nick.", 0, 0}
        return "Sorry, I don't know of $nick.", 0, 0;
    }
    $nick = $orig_nick{$chatnet}{$lc_nick};
    if ($address eq canonical $server->{userhost}) {
        return "I am $nick!", 1, 0;
    }
    if (defined $who_asks && $address eq $who_asks) {
        return "You are $nick!", 1, 0;
    }
    my $asked_and = defined $asked ? "$asked; " : "";
    my $spoke = $spoke{$chatnet}{$address};
    my $spoke_and = defined $spoke ?
      "last spoke " . show_time_since($spoke) . ".  " : "";
    if (defined $address_absent{$chatnet}{$address}) {
        my $last_nick = $last_nicks{$chatnet}{$address};
        my $when_address = show_time_since $address_absent{$chatnet}{$address};
        if (lc_irc $last_nick eq $lc_nick) {
            return "The person with the nick $nick $asked_and$spoke_and$when_address " .
              show_how_quit($how_quit{$chatnet}{$address},
                            $where_asks, $can_show), 1, 1;
        } else {
            my $when_nick = show_time_since $nick_absent{$chatnet}{$lc_nick};
            return "Person, who $when_nick used nick $nick, " .
              "$asked_and$spoke_and$when_address jako $last_nick " .
              show_how_quit($how_quit{$chatnet}{$address},
                            $where_asks, $can_show), 1, 1;
        }
    } else {
        return show_where_is($server, $nick, $address,
                             $where_asks, $can_show,
                             $asked_and, $spoke_and), 1, 0;
    }
}

######## Initialization ########

read_database;
expire_database;
initialize_database;
write_database;

Irssi::timeout_add 60*60*1000, sub {expire_database; write_database}, undef;

######## Irssi signal handlers ########

sub can_show_this_channel($) {
    my ($channel) = @_;
    my $lc_channel = lc_irc $channel;
    return sub {lc_irc $_[0] eq $lc_channel};
}

sub can_show_his_channels($$) {
    my ($chatnet, $nick) = @_;
    my $lc_nick = lc_irc $nick;
    my @channels = $channels{$chatnet}{$lc_nick} ?
      @{$channels{$chatnet}{$lc_nick}} : ();
    return sub {
        my $channel = lc_irc $_[0];
        return grep {lc_irc $_ eq $channel} @channels;
    };
}

sub check_asked($$$) {
    my ($chatnet, $server, $nick) = @_;
    my $lc_nick = lc_irc $nick;
    my $who_asked = $asked{$chatnet}{$lc_nick};
    return unless $who_asked;
    foreach my $nick_asked (sort {$who_asked->{$a} <=> $who_asked->{$b}}
                            keys %{$who_asked}) {
        my $when_asked = show_time_since $who_asked->{$nick_asked};
        my ($reply, $found, $remember_asked) =
          seen $server, $nick_asked, undef, undef,
          can_show_his_channels($chatnet, $nick),
          "szukala Cie $when_asked";
        $server->command("notice $nick $reply");
        do_forget_ask $chatnet, $nick, $nick_asked;
        append_to_database "forget_ask $chatnet $nick $nick_asked";
    }
}

Irssi::signal_add "channel wholist", sub {
    my ($channel) = @_;
    my $server = $channel->{server};
    my $chatnet = lc $server->{chatnet};
    foreach my $nick ($channel->nicks()) {
        my $lc_nick = lc_irc $nick->{nick};
        my $lc_channel = lc_irc $channel->{name};
        on_join $chatnet, canonical $nick->{host}, $nick->{nick}, $channel->{name}
          unless $nick->{host} eq "" ||
          $channels{$chatnet}{$lc_nick} &&
          grep {lc_irc $_ eq $lc_channel} @{$channels{$chatnet}{$lc_nick}};
        check_asked $chatnet, $server, $nick->{nick};
    }
};

Irssi::signal_add_first "channel destroyed", sub {
    my ($channel) = @_;
    my $chatnet = lc $channel->{server}{chatnet};
    foreach my $nick ($channel->nicks()) {
        on_part $chatnet, canonical $nick->{host}, $nick->{nick}, $channel->{name},
          ['was_left', mark_private($channel, $channel->{name})]
          unless $nick->{host} eq "";
    }
};

Irssi::signal_add "event join", sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or return;
    my $channel = $1;
    my $chatnet = lc $server->{chatnet};
    on_join $chatnet, canonical $address, $nick, $channel;
    check_asked $chatnet, $server, $nick;
};

Irssi::signal_add "event part", sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^([^ ]+) +:(.*)$/ or $args =~ /^([^ ]+) +([^ ]+)$/ or $args =~ /^([^ ]+)()$/ or return;
    my ($channel, $reason) = ($1, $2);
    my $chatnet = lc $server->{chatnet};
    return if defined $nick_absent{$chatnet}{lc_irc $nick};
    $reason = "" if $reason eq $nick;
    on_part $chatnet, canonical $address, $nick, $channel,
      ['left', mark_private($server->channel_find($channel), $channel), $reason];
};

Irssi::signal_add "event quit", sub {
    my ($server, $args, $nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or $args =~ /^()$/ or return;
    my $reason = $1;
    my $chatnet = lc $server->{chatnet};
    my $lc_nick = lc_irc $nick;
    return if defined $nick_absent{$chatnet}{$lc_nick};
    $reason = "" if $reason =~ /^(Quit: )?(leaving)?$/;
    my @channels = $channels{$chatnet}{$lc_nick} ?
      @{$channels{$chatnet}{$lc_nick}} : ();
    on_quit $chatnet, canonical $address, $nick,
      ['quit', join(",", map {mark_private($server->channel_find($_), $_)} sort @channels), $reason];
};

Irssi::signal_add "event kick", sub {
    my ($server, $args, $kicker, $kicker_address) = @_;
    $args =~ /^([^ ]+) +([^ ]+) +:(.*)$/ or $args =~ /^([^ ]+) +([^ ]+) +([^ ]+)$/ or
      $args =~ /^([^ ]+) +([^ ]+)()$/ or return;
    my ($channel, $nick, $reason) = ($1, $2, $3);
    my $chatnet = lc $server->{chatnet};
    $reason = "" if $reason eq $kicker;
    on_part $chatnet, $addresses{$chatnet}{lc_irc $nick}, $nick, $channel,
      ['was_kicked', mark_private($server->channel_find($channel), $channel), $kicker, $reason];
};

Irssi::signal_add "event nick", sub {
    my ($server, $args, $old_nick, $address) = @_;
    $args =~ /^:(.*)$/ or $args =~ /^([^ ]+)$/ or return;
    my $new_nick = $1;
    return if $address eq "";
    my $chatnet = lc $server->{chatnet};
    on_nick $chatnet, canonical $address, $old_nick, $new_nick;
    check_asked $chatnet, $server, $new_nick;
};

######## Commands ########

Irssi::command_bind "seen", sub {
    my ($args, $server, $target) = @_;
    my $nick;
    if ($args =~ /^ *([^ ]+) *$/) {
        $nick = $1;
    } else {
        Irssi::print "Usage: /seen <nick>";
        return;
    }
    unless ($server && $server->{connected}) {
        Irssi::print "Not connected to server";
        return;
    }
    my ($reply, $found, $remember_asked) =
      seen $server, $nick, undef, undef, sub {1}, undef;
    Irssi::print $reply;
};

Irssi::command_bind "say_seen", sub {
    my ($args, $server, $target) = @_;
    my $chatnet = lc $server->{chatnet};
    my ($nick_asks, $prefix, $nick);
    if ($args =~ /^ *([^ ]+) *$/) {
        $nick_asks = undef;
        $prefix = "";
        $nick = $1;
    } elsif ($args =~ /^ *([^ ]+) +([^ ]+) *$/) {
        $nick_asks = $1;
        $prefix = "$1: ";
        $nick = $2;
    } else {
        Irssi::print "Usage: /say_seen [<to_whom>] <nick>";
        return;
    }
    unless ($server && $server->{connected}) {
        Irssi::print "Not connected to server";
        return;
    }
    unless ($target) {
        Irssi::print "Not in a channel or query";
        return;
    }
    my $can_show =
      $target->{type} eq 'CHANNEL' ?
        can_show_this_channel($target->{name}) :
      $target->{type} eq 'QUERY' ?
        can_show_his_channels($chatnet, $target->{name}) :
      sub {0};
    my ($reply, $found, $remember_asked) =
      seen $server, $nick, undef, $target->{name}, $can_show, undef;
    on_ask $chatnet, $nick, $nick_asks
      if defined $nick_asks && $remember_asked;
    $server->command("msg $target->{name} $prefix$reply");
};

sub cmd_listen_switch($$$$) {
    my ($state, $args, $server, $target) = @_;
    if ($args =~ /^ *$/) {
        unless ($server && $server->{connected}) {
            Irssi::print "Not connected to server";
            return;
        }
        unless ($target && $target->{type} eq 'CHANNEL') {
            Irssi::print "Not in a channel";
            return;
        }
        on_listen lc $server->{chatnet}, lc_irc $target->{name}, $state;
    } elsif ($args =~ /^ *([^ ]+) *$/)
    {
        unless ($server && $server->{connected}) {
            Irssi::print "Not connected to server";
            return;
        }
        on_listen lc $server->{chatnet}, lc_irc $1, $state;
    } elsif ($args =~ /^ *([^ ]+) +([^ ]+) *$/)
    {
        on_listen lc $1, lc_irc $2, $state;
    } else {
        Irssi::print "Usage: /listen $state [[<chatnet>] <channel>]";
    }
}

Irssi::command_bind "listen", sub {
    my ($args, $server, $target) = @_;
    Irssi::command_runsub "listen", $args, $server, $target;
};

Irssi::command_bind "listen on", sub {
    my ($args, $server, $target) = @_;
    cmd_listen_switch "on", $args, $server, $target;
};

Irssi::command_bind "listen off", sub {
    my ($args, $server, $target) = @_;
    cmd_listen_switch "off", $args, $server, $target;
};

Irssi::command_bind "listen delay", sub {
    my ($args, $server, $target) = @_;
    cmd_listen_switch "delay", $args, $server, $target;
};

Irssi::command_bind "listen private", sub {
    my ($args, $server, $target) = @_;
    cmd_listen_switch "private", $args, $server, $target;
};

Irssi::command_bind "listen disable", sub {
    my ($args, $server, $target) = @_;
    cmd_listen_switch "disable", $args, $server, $target;
};

our @joined_text = ("      ", "joined");

Irssi::command_bind "listen list", sub {
    my ($args, $server, $target) = @_;
    if ($args =~ /^ *$/) {
        my %all_channels = ();
        foreach my $server (Irssi::servers()) {
            my $chatnet = lc $server->{chatnet};
            foreach my $channel ($server->channels()) {
                $all_channels{$chatnet}{lc_irc $channel->{name}}[0] = 1;
            }
        }
        foreach my $chatnet (keys %listen_on) {
            foreach my $channel (keys %{$listen_on{$chatnet}}) {
                $all_channels{$chatnet}{$channel}[1] = $listen_on{$chatnet}{$channel};
            }
        }
        my $max_chatnet_width = 1;
        my $max_channel_width = 1;
        foreach my $chatnet (keys %all_channels) {
            $max_chatnet_width = length $chatnet
              if length $chatnet > $max_chatnet_width;
            foreach my $channel (keys %{$all_channels{$chatnet}}) {
                $max_channel_width = length $channel
                  if length $channel > $max_channel_width;
            }
        }
        Irssi::print "'seen' is listening:";
        foreach my $chatnet (sort keys %all_channels) {
            foreach my $channel (sort keys %{$all_channels{$chatnet}}) {
                Irssi::print
                  $chatnet .
                  " " x ($max_chatnet_width - length ($chatnet) + 1) .
                  $channel .
                  " " x ($max_channel_width - length ($channel) + 3) .
                  $joined_text[$all_channels{$chatnet}{$channel}[0]] .
                  "   " .
                  $all_channels{$chatnet}{$channel}[1];
            }
        }
    } else {
        Irssi::print "Usage: /listen list";
    }
};

Irssi::command_bind "forget", sub {
    my ($args, $server, $target) = @_;
    my $nick;
    if ($args =~ /^ *([^ ]+) *$/) {
        $nick = $1;
    } else {
        Irssi::print "Usage: /forget <nick>";
        return;
    }
    unless ($server) {
        Irssi::print "Not connected to server";
        return;
    }
    my $chatnet = lc $server->{chatnet};
    return unless $asked{$chatnet}{$nick};
    foreach my $nick_asked (keys %{$asked{$chatnet}{$nick}}) {
        do_forget_ask $chatnet, $nick, $nick_asked;
        append_to_database "forget_ask $chatnet $nick $nick_asked";
    }
};

######## Listen to seen requests from other people ########

our $last_reply = undef;
our $last_asked = undef;

our %pending_replies = ();

sub seen_reply($$$$$$) {
    my ($server, $nick_asks, $address, $target, $nick, $sure) = @_;
    my $chatnet = lc $server->{chatnet};
    my ($reply, $found, $remember_asked) =
      seen $server, $nick, $address, $target,
        can_show_this_channel($target), undef;
    return unless $sure || $found;
    unless ($reply eq $last_reply && $nick eq $last_asked) {
        Irssi::print "[$target] $nick_asks: $reply";
        $server->command("msg $target $nick_asks: $reply");
        $last_reply = $reply;
        $last_asked = $nick;
    }
    on_ask $chatnet, $nick, $nick_asks if $remember_asked;
}

sub private_seen_reply($$$$$$) {
    my ($server, $nick_asks, $address, $target, $nick, $sure) = @_;
    my $chatnet = lc $server->{chatnet};
    my ($reply, $found, $remember_asked) =
      seen $server, $nick, $address, undef,
        can_show_his_channels($chatnet, $nick_asks), undef;
    return unless $sure || $found;
    $server->command("notice $nick_asks $reply");
    $server->command("notice $nick_asks " .
      "Pytac o obecnosc ludzi mozesz mnie tez prywatnie, np. /msg $server->{nick} seen $nick");
    on_ask $chatnet, $nick, $nick_asks if $remember_asked;
}

sub delayed_seen_reply($$$$$$) {
    my ($server, $nick_asks, $address, $target, $nick, $sure) = @_;
    my $chatnet = lc $server->{chatnet};
    my $lc_nick = lc_irc $nick;
    return if defined $pending_replies{$chatnet}{$target}{$lc_nick};
    my $timeout = Irssi::settings_get_int("seen_delay") * 1000;
    $pending_replies{$chatnet}{$target}{$lc_nick} = Irssi::timeout_add_once $timeout, sub {
        delete $pending_replies{$chatnet}{$target}{$lc_nick};
        seen_reply $server, $nick_asks, $address, $target, $nick, $sure;
    }, undef;
}

our %reply_method = (
    on => \&seen_reply,
    off => undef,
    delay => \&delayed_seen_reply,
    private => \&private_seen_reply,
    disable => undef,
);

sub check_another_seen($$$$) {
    my ($chatnet, $channel, $msg, $nick_asks) = @_;
    my $lc_channel = lc_irc $channel;
    if ($listen_on{$chatnet}{$lc_channel} eq 'delay') {
        foreach my $nick (keys %{$pending_replies{$chatnet}{$channel}}) {
            my $nick_regexp = lc_irc_regexp $nick;
            if ($msg =~ /(^|[ \cb])$nick_regexp($|[ !,.:;?\cb])/ ||
                lc_irc $nick_asks eq $nick) {
                my $tag = $pending_replies{$chatnet}{$channel}{$nick};
                Irssi::timeout_remove $tag;
                delete $pending_replies{$chatnet}{$channel}{$nick};
            }
        }
    }
}

Irssi::signal_add "message public", sub {
    my ($server, $msg, $nick_asks, $address, $channel) = @_;
    my $chatnet = lc $server->{chatnet};
    $address = canonical $address;
    on_spoke $chatnet, $address;
    my $lc_channel = lc_irc $channel;
    my ($msg_body, $func) =
      $msg =~ /^\Q$server->{nick}\E(?:|:|\cb:\cb) +(.*)$/i ? ($1, \&seen_reply) :
      ($msg, $reply_method{$listen_on{$chatnet}{$lc_channel} || 'off'});
    if (defined $func) {
        my $sure =
          $msg_body =~ $seen_regexp ? 1 :
          $msg_body =~ $maybe_seen_regexp1 ||
          $msg_body =~ $maybe_seen_regexp2 ? 0 :
          undef;
        if (defined $sure) {
            my $nick = $1;
            return if $sure == 0 && $nick =~ $exclude_regexp;
            Irssi::signal_continue @_;
            $func->($server, $nick_asks, $address, $channel, $nick, $sure);
            return;
        }
    }
    check_another_seen $chatnet, $channel, $msg, $nick_asks;
};

Irssi::signal_add "message irc notice", sub {
    my ($server, $msg, $nick_asks, $address, $target) = @_;
    my $chatnet = lc $server->{chatnet};
    check_another_seen $chatnet, $target, $msg, $nick_asks;
};

Irssi::signal_add "message private", sub {
    my ($server, $msg, $nick_asks, $address) = @_;
    my $chatnet = lc $server->{chatnet};
    on_spoke $chatnet, canonical $address;
    check_asked $chatnet, $server, $nick_asks;
    my $sure =
      $msg =~ $seen_regexp ? 1 :
      $msg =~ $maybe_seen_regexp1 ||
      $msg =~ $maybe_seen_regexp2 ? 0 :
      undef;
    if (defined $sure) {
        my $nick = $1;
        my ($reply, $found, $remember_asked) =
          seen $server, $nick, canonical $address, undef,
          can_show_his_channels($chatnet, $nick_asks), undef;
        return unless $sure || $found;
        Irssi::signal_continue @_;
        $server->command("msg $nick_asks $reply");
        on_ask $chatnet, $nick, $nick_asks if $remember_asked;
    }
};

Irssi::signal_add "message irc action", sub {
    my ($server, $msg, $nick, $address, $target) = @_;
    on_spoke lc $server->{chatnet}, canonical $address;
};
