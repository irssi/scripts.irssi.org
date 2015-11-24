# - Lets you tab over a number of people who've recently spoken in channel
# - Removes people from the list who leave the channel
# - Tabcomplete works only from an empty input line and will complete to
#   the person who last spoke
# - The same nick is only included once in the list
# - When at the end of the list, empties the input line and lets you begin
#   from the start again
# - /set completion_keep_publics decides how many nicks to remember

use Irssi;
use Data::Dumper;

my $VERSION = '1.0';
my %IRSSI = (
    authors     => 'vague',
    contact     => 'vague!#irssi@freenode on irc',
    name        => 'tabcompletenick',
    description => 'tabcomplete, on an empty input buffer, over /set completion_keep_publics nicks in channel, parts for any reason(kick, part, quit) are removed from the tabcomplete list',
    license     => 'GPL2',
    url         => "http://gplus.to/vague",
    changed     => "24 Nov 16:00:00 CET 2015",
);

my $lastspokehash = {};
my $expand_next = 0;

Irssi::signal_add_first('gui key pressed', sub {
  my ($key) = @_;
  my $prompt = Irssi::parse_special('$L');
  my $pos = Irssi::gui_input_get_pos();

  $server = Irssi::active_server();
  $witem = Irssi::active_win()->{active};

  return unless $witem->{type} eq "CHANNEL";

  my $arr = $lastspokehash{$server->{tag}}->{$witem->{name}};

  if(!$expand_next) {
    return unless $key == 9;
    return unless $pos == 0;
    return unless @{$arr};

    $expand_next++;
  }
  else {
    if($key != 9) {
      $expand_next = 0;
      return;
    }

    if($expand_next < scalar @{$arr}) {
      $expand_next++;
    } else {
      $expand_next = 0;
    }
  }

  my $last = Irssi::parse_special('$LASTSPOKE');

  if($last ne '') {
    $prompt = $last . Irssi::settings_get_str('completion_char') . " ";
  } else {
    $prompt = $last;
  }

  Irssi::gui_input_set($prompt);
  Irssi::gui_input_set_pos(length($prompt));
  Irssi::signal_stop();
});

sub expando_lastspoke {
  my ($server, $witem) = @_;
  $server = Irssi::active_server();
  $witem = Irssi::active_win()->{active};

  return '' if $expand_next == 0;
  return '' unless ref($witem) eq 'Irssi::Irc::Channel';
  my $arr = $lastspokehash{$server->{tag}}->{$witem->{name}};
  return '' unless @{$arr};
  return '' unless $expand_last <= $arr;

  return @{$lastspokehash{$server->{tag}}->{$witem->{name}}}[$expand_next - 1];
}

sub act_public {
  my ($server, $msg, $nick, $address, $witem) = @_;

  return if $witem eq '';

  my $i = 0;
  my $arr = $lastspokehash{$server->{tag}}->{$witem};
  foreach(@{$arr}) {
    if($_ eq $nick) {
      splice @{$arr}, $i, 1;
      last;
    }
    $i++;
  }

  unshift @{$lastspokehash{$server->{tag}}->{$witem}}, $nick;
  splice @{$lastspokehash{$server->{tag}}->{$witem}}, Irssi::settings_get_int('completion_keep_publics');
}

sub _part {
  my ($server, $channel, $nick) = @_;

  if(!$channel) {
    foreach my $chan (keys %{$lastspokehash{$server->{tag}}}) {
      my $arr = $lastspokehash{$server->{tag}}->{$chan};
      my $i = 0;
      foreach(@{$arr}) {
        if($_ eq $nick) {
          splice @{$arr}, $i, 1;
          last;
        }

        $i++;
      }
    }
  }
  else {
    my $arr = $lastspokehash{$server->{tag}}->{$channel};
    my $i = 0;
    foreach(@{$arr}) {
      if($_ eq $nick) {
        splice @{$arr}, $i, 1;
        last;
      }

      $i++;
    }
  }

  delete $lastspokehash{$server->{tag}}->{$channel} unless @{$lastspokehash{$server->{tag}}->{$channel}};
  delete $lastspokehash{$server->{tag}} unless keys %{$lastspokehash{$server->{tag}}};
}

Irssi::signal_add_first('message quit', sub {
  my ($server, $nick, $address, $reason) = @_;
  _part($server, undef, $nick);
});

Irssi::signal_add_first('message part', sub {
  my ($server, $channel, $nick, $address, $reason) = @_;
  _part($server, $channel, $nick);
});

Irssi::signal_add_first('message kick', sub {
  my ($server, $channel, $nick, $kicker, $address, $reason) = @_;
  _part($server, $channel, $nick);
});

Irssi::signal_add_first('message nick', sub {
  my ($server, $newnick, $oldnick, $address) = @_;

  foreach my $chan (keys %{$lastspokehash{$server->{tag}}}) {
    my $arr = $lastspokehash{$server->{tag}}->{$chan};
    my $i = 0;
    foreach(@{$arr}) {
      if($_ eq $oldnick) {
        @{$arr}[$i] = $newnick;
        last;
      }

      $i++;
    }
  }
});

Irssi::signal_add('message public', \&act_public);
Irssi::signal_add('message irc action', \&act_public);
Irssi::expando_create('LASTSPOKE', \&expando_lastspoke, {});
