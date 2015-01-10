use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "1.5";
%IRSSI =
(
    authors     => 'Marcin \'Qrczak\' Kowalczyk',
    contact     => 'qrczak@knm.org.pl',
    name        => 'LinkChan',
    description => 'Link several channels on serveral networks',
    license     => 'GNU GPL',
    url         => 'http://qrnik.knm.org.pl/~qrczak/irssi/linkchan.pl',
);

our %links;
our $lock_own = 0;

our $config = Irssi::get_irssi_dir . "/linkchan.cfg";

Irssi::command_bind "link", sub
{
    my ($args, $server, $target) = @_;
    Irssi::command_runsub "link", $args, $server, $target;
};

Irssi::command_bind "link add", sub
{
    my ($args, $server, $target) = @_;
    unless ($args =~ m|^ *([^ /]+)/([^ ]+) +([^ /]+)/([^ ]+) *$|)
    {
        print CLIENTERROR "Usage: /link add <chatnet1>/<channel1> <chatnet2>/<channel2>";
        return;
    }
    my ($chatnet1, $channel1, $chatnet2, $channel2) =
      (lc $1, lc $2, lc $3, lc $4);
    foreach my $link ([$chatnet1, $channel1], [$chatnet2, $channel2])
    {
        my ($chat1, $chan1) = @{$link};
        if ($links{$chat1}{$chan1})
        {
            my ($chat2, $chan2) = @{$links{$chat1}{$chan1}};
            print CLIENTERROR "Channel $chat1/$chan1 is already linked to $chat2/$chan2";
            return;
        }
    }
    $links{$chatnet1}{$channel1} = [$chatnet2, $channel2];
    $links{$chatnet2}{$channel2} = [$chatnet1, $channel1];
    print CLIENTNOTICE "Added link: $chatnet1/$channel1 <-> $chatnet2/$channel2";
};

Irssi::command_bind "link remove", sub
{
    my ($args, $server, $target) = @_;
    unless ($args =~ m|^ *([^ /]+)/([^ ]+) *$|)
    {
        print CLIENTERROR "Usage: /link remove <chatnet>/<channel>";
        return;
    }
    my ($chatnet1, $channel1) = (lc $1, lc $2);
    unless ($links{$chatnet1}{$channel1})
    {
        print CLIENTERROR "Channel $chatnet1/$channel1 was not linked";
        return;
    }
    my ($chatnet2, $channel2) = @{$links{$chatnet1}{$channel1}};
    delete $links{$chatnet1}{$channel1};
    delete $links{$chatnet2}{$channel2};
    print CLIENTNOTICE "Removed link: $chatnet1/$channel1 <-> $chatnet2/$channel2";
};

Irssi::command_bind "link list", sub
{
    my ($args, $server, $target) = @_;
    unless ($args =~ /^ *$/)
    {
        print CLIENTNOTICE "Usage: /link list";
        return;
    }
    print CLIENTNOTICE "The following pairs of channels are linked:";
    my %shown = ();
    foreach my $chatnet1 (sort keys %links)
    {
        foreach my $channel1 (sort keys %{$links{$chatnet1}})
        {
            next if $shown{$chatnet1}{$channel1};
            my ($chatnet2, $channel2) = @{$links{$chatnet1}{$channel1}};
            print CLIENTNOTICE "$chatnet1/$channel1 <-> $chatnet2/$channel2";
            $shown{$chatnet2}{$channel2} = 1;
        }
    }
};

sub save_config()
{
    open CONFIG, ">", $config;
    foreach my $chatnet1 (keys %links)
    {
        foreach my $channel1 (keys %{$links{$chatnet1}})
        {
            my ($chatnet2, $channel2) = @{$links{$chatnet1}{$channel1}};
            print CONFIG "$chatnet1/$channel1 $chatnet2/$channel2\n";
        }
    }
    close CONFIG;
}

Irssi::signal_add "setup saved", sub
{
    my ($main_config, $auto) = @_;
    save_config unless $auto;
};

sub load_config()
{
    %links = ();
    open CONFIG, "<", $config or return;
    while (<CONFIG>)
    {
        chomp;
        next if /^ *$/ || /^#/;
        unless (m|^ *([^ /]+)/([^ ]+) +([^ /]+)/([^ ]+) *$|)
        {
            print CLIENTERROR "Syntax error in $config: $_";
            return;
        }
        my ($chatnet1, $channel1, $chatnet2, $channel2) =
          (lc $1, lc $2, lc $3, lc $4);
        $links{$chatnet1}{$channel1} = [$chatnet2, $channel2];
    }
}

Irssi::signal_add "setup reread", \&load_config;

sub message($$)
{
    my ($chan, $msg) = @_;
    $lock_own = 1;
    $chan->{server}->command("msg $chan->{name} $msg");
    $lock_own = 0;
}

sub special_message($$)
{
    my ($chan, $msg) = @_;
    message $chan, "-!- $msg";
}

sub special_message_for($$$)
{
    my ($chan, $nick, $msg) = @_;
    message $chan,
      (defined $nick ? "$nick: " : "") .
      "-!- $msg";
}

sub channel_context($$)
{
    my ($server1, $channel1) = @_;
    my $chatnet1 = lc $server1->{chatnet};
    my $chan1 = $server1->channel_find($channel1) or return undef;
    my $other = $links{$chatnet1}{lc $channel1} or return undef;
    my ($chatnet2, $channel2) = @{$other};
    my $server2 = Irssi::server_find_chatnet($chatnet2) or return;
    my $chan2 = $server2->channel_find($channel2) or return;
    return {
        chatnet1 => $chatnet1,
        server1  => $server1,
        channel1 => $channel1,
        chan1    => $chan1,
        chatnet2 => $chatnet2,
        server2  => $server2,
        channel2 => $channel2,
        chan2    => $chan2,
    };
}

sub channel_contexts_with_nick($$)
{
    my ($server1, $nick1) = @_;
    my $chatnet1 = lc $server1->{chatnet};
    return () unless $links{$chatnet1};
    my @contexts = ();
    foreach my $channel1 (keys %{$links{$chatnet1}})
    {
        my $chan1 = $server1->channel_find($channel1) or next;
        next unless $chan1->nick_find($nick1);
        my ($chatnet2, $channel2) = @{$links{$chatnet1}{$channel1}};
        my $server2 = Irssi::server_find_chatnet($chatnet2) or next;
        my $chan2 = $server2->channel_find($channel2) or next;
        push @contexts, {
            chatnet1 => $chatnet1,
            server1  => $server1,
            channel1 => $channel1,
            chan1    => $chan1,
            chatnet2 => $chatnet2,
            server2  => $server2,
            channel2 => $channel2,
            chan2    => $chan2,
        };
    }
    return @contexts;
}

sub must_be_op($$)
{
    my ($context, $nick) = @_;
    unless (defined $nick ?
            $context->{chan1}->nick_find($nick)->{op} :
            $context->{chan1}->{chanop})
    {
        special_message_for $context->{chan1}, $nick,
          "You're not channel operator in $context->{channel1}";
        return 0;
    }
    unless ($context->{chan2}->{chanop})
    {
        special_message_for $context->{chan1}, $nick,
          "Sorry, I'm not channel operator in $context->{channel2}";
        return 0;
    }
    return 1;
}

sub change_mode($$$)
{
    my ($context, $nick, $mode) = @_;
    return unless must_be_op($context, $nick);
    special_message $context->{chan2},
      "mode/$context->{channel2} [$mode] by $nick"
      if defined $nick;
    $context->{server2}->command("mode $context->{channel2} $mode");
}

sub change_perms($$$$$$)
{
    my ($command, $dir, $mode, $context, $nick, $args) = @_;
    my @nicks = split ' ', $args;
    unless (@nicks)
    {
        special_message_for $context->{chan1}, $nick,
          "Usage: \\$command <nicks>";
        return;
    }
    change_mode $context, $nick, $dir . $mode x @nicks . " @nicks";
}

sub names($$$)
{
    my ($context, $nick, $args) = @_;
    my @nicks = $context->{chan2}->nicks();
    my @ops = grep {$_->{op}} @nicks;
    my @voices = grep {!$_->{op} && $_->{voice}} @nicks;
    my @normal = grep {!$_->{op} && !$_->{voice}} @nicks;
    my @list = (
      map ({['@', $_]} sort {lc $a cmp lc $b} map {$_->{nick}} @ops),
      map ({['+', $_]} sort {lc $a cmp lc $b} map {$_->{nick}} @voices),
      map ({[' ', $_]} sort {lc $a cmp lc $b} map {$_->{nick}} @normal));
    my $max_width = 62 - length $context->{server1}->{nick};
    my $rows = 1;
    my @column_widths;
    while ($rows < @list)
    {
        @column_widths = ();
        my $width = 0;
        my $i = 0;
        while ($i < @list)
        {
            my $column_width = 0;
            foreach my $j ($i .. $i+$rows-1)
            {
                last if $j >= @list;
                my $len = length $list[$j][1];
                $column_width = $len if $column_width < $len;
            }
            push @column_widths, $column_width;
            $width += $column_width + 4;
            $i += $rows;
        }
        last if $width - 1 <= $max_width;
        ++$rows;
    }
    my @output;
    foreach my $i (0..$#list)
    {
        $output[$i % $rows] .=
          sprintf "[%s%*s] ",
          $list[$i][0], -$column_widths[int ($i / $rows)], $list[$i][1];
    }
    foreach my $row (@output)
    {
        chop $row;
        message $context->{chan1}, $row;
    }
}

my %commands =
(
    mode => sub
    {
        my ($context, $nick, $args) = @_;
        unless ($args =~ /^ +\* +(.*)$/ ||
                $args =~ /^ +\Q$context->{channel2}\E +(.*)$/)
        {
            special_message_for $context->{chan1}, $nick,
              "Usage: \\mode * <mode> [<mode parameters>]";
            return;
        }
        change_mode $context, $nick, $1;
    },
    op => sub {&change_perms('op', '+', 'o', @_)},
    deop => sub {&change_perms('deop', '-', 'o', @_)},
    voice => sub {&change_perms('voice', '+', 'v', @_)},
    devoice => sub {&change_perms('devoice', '-', 'v', @_)},
    kick => sub
    {
        my ($context, $nick, $args) = @_;
        unless ($args =~ /^ +([^ ]+)(| .*)$/)
        {
            special_message_for $context->{chan1}, $nick,
              "Usage: \\kick <nicks> [<reason>]";
            return;
        }
        my ($nicks, $reason) = ($1, $2);
        $reason = $reason =~ /^ ?$/ ? " $nick" : " <$nick>$reason"
          if defined $nick;
        return unless must_be_op($context, $nick);
        $context->{server2}->command("kick $context->{channel2} $nicks$reason");
    },
    names => \&names,
);

sub run_command($$$$)
{
    my ($context, $nick, $command, $args) = @_;
    my $func = $commands{lc $command};
    unless ($func)
    {
        special_message_for $context->{chan1}, $nick,
          "Unknown command: $command";
        return;
    }
    $func->($context, $nick, $args);
}

Irssi::signal_add "message public", sub
{
    my ($server1, $msg, $nick, $address, $channel1) = @_;
    my $context = channel_context($server1, $channel1) or return;
    if ($msg =~ /^\\([^ ]+)(| .*)$/)
    {
        Irssi::signal_continue @_;
        run_command $context, $nick, $1, $2;
    }
    elsif ($msg =~ /^<.[^ ]+> /)
    {
        print CLIENTERROR
          "Warning! Channels $context->{chatnet1}/$context->{channel1} " .
          "and $context->{chatnet2}/$context->{channel2} are linked twice.";
        Irssi::command "beep";
    }
    else
    {
        my $nk = $context->{chan1}->nick_find($nick);
        my $perm = $nk->{op} ? '@' : $nk->{voice} ? '+' : ' ';
        message $context->{chan2}, "<$perm$nick> $msg";
    }
};

Irssi::signal_add "message own_public", sub
{
    my ($server1, $msg, $channel1) = @_;
    return if $lock_own;
    my $context = channel_context($server1, $channel1) or return;
    if ($msg !~ s/^\\ // && $msg =~ /^\\([^ ]+)(| .*)$/)
    {
        Irssi::signal_continue @_;
        run_command $context, undef, $1, $2;
    }
    else
    {
        message $context->{chan2}, $msg;
    }
};

Irssi::signal_add "message irc action", sub
{
    my ($server1, $msg, $nick, $address, $channel1) = @_;
    my $context = channel_context($server1, $channel1) or return;
    message $context->{chan2}, " * $nick $msg";
};

Irssi::signal_add "message irc own_action", sub
{
    my ($server1, $msg, $channel1) = @_;
    return if $lock_own;
    my $context = channel_context($server1, $channel1) or return;
    $lock_own = 1;
    $context->{server2}->command("action $context->{channel2} $msg");
    $lock_own = 0;
};

Irssi::signal_add "message join", sub
{
    my ($server1, $channel1, $nick, $address) = @_;
    my $context = channel_context($server1, $channel1) or return;
    special_message $context->{chan2},
      "$nick [$address] has joined $channel1";
};

Irssi::signal_add "message part", sub
{
    my ($server1, $channel1, $nick, $address, $reason) = @_;
    my $context = channel_context($server1, $channel1) or return;
    special_message $context->{chan2},
      "$nick [$address] has left $context->{channel1} [$reason]";
};

Irssi::signal_add "message quit", sub
{
    my ($server1, $nick, $address, $reason) = @_;
    foreach my $context (channel_contexts_with_nick($server1, $nick))
    {
        special_message $context->{chan2},
          "$nick [$address] has quit [$reason]";
    }
};

Irssi::signal_add "message topic", sub
{
    my ($server1, $channel1, $topic, $nick, $address) = @_;
    return if $nick eq $server1->{nick};
    my $context = channel_context($server1, $channel1) or return;
    if ($topic eq "")
    {
        special_message $context->{chan2},
          "Topic unset by $nick on $context->{channel1}";
        $context->{server2}->command("topic -delete $context->{channel2}");
    }
    else
    {
        special_message $context->{chan2},
          "$nick changed the topic of $context->{channel1} to: $topic";
        $context->{server2}->command("topic $context->{channel2} $topic");
    }
};

Irssi::signal_add "message nick", sub
{
    my ($server1, $newnick, $oldnick, $address) = @_;
    foreach my $context (channel_contexts_with_nick($server1, $newnick))
    {
        special_message $context->{chan2},
          "$oldnick is now known as $newnick";
    }
};

Irssi::signal_add "message own_nick", sub
{
    my ($server1, $newnick, $oldnick, $address) = @_;
    foreach my $context (channel_contexts_with_nick($server1, $newnick))
    {
        next if $context->{chatnet1} eq $context->{chatnet2};
        special_message $context->{chan2},
          "$oldnick is now known as $newnick";
    }
};

Irssi::signal_add "message kick", sub
{
    my ($server1, $channel1, $nick, $kicker, $address, $reason) = @_;
    my $context = channel_context($server1, $channel1) or return;
    special_message $context->{chan2},
      "$nick was kicked from $context->{channel1} " .
      "by $kicker [$reason]";
};

Irssi::signal_add "event mode", sub
{
    my ($server1, $data, $nick) = @_;
    $data =~ /^([^ ]*) (.*)$/ or return;
    my ($channel1, $mode) = ($1, $2);
    my $context = channel_context($server1, $channel1) or return;
    special_message $context->{chan2},
      "mode/$context->{channel1} [$mode] by $nick";
};

load_config;

