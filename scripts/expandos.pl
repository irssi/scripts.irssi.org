use strict;
use warnings;
use Irssi;
use Data::Dumper;

use vars qw($VERSION %IRSSI);

$VERSION = "0.1";
%IRSSI = (
          authors       => 'vague',
          contact       => 'vague!#irssi@libera on irc',
          name          => 'expandos',
          description   => 'Commands to easily add/remove expandos',
          licence       => "GPLv2",
          changed       => "20221006 15:00 CEST"
);

my $expandos;
my $savefile = Irssi::get_irssi_dir() . "/expandos.save";

sub cmd_expando_add {
  my ($data, $active_server, $witem) = @_;
  my ($args, $rest) = Irssi::command_parse_options('expando add', $data);
  my ($exp, $val) = split /\s+(?!=)|\s*=\s*/, $rest, 2;

  if(!defined $exp) {
    print "You must specify expando and value to add it";
    return;
  }
  elsif(!defined $val) {
    print "$exp must have a value";
    return;
  }

  if(exists $expandos->{$exp} && !exists $args->{f}) {
    print "$exp already exists, add -f to force overwrite";
    return;
  }

  $expandos->{$exp} = $val;

  Irssi::expando_create($exp, sub {
    return eval $expandos->{$exp};
  }, {});

  _save();
}

sub cmd_expando_del {
  my ($data, $active_server, $witem) = @_;

  delete $expandos->{$data} if exists $expandos->{$data};

  _save();
}

sub cmd_expando_list {
  my ($data, $active_server, $witem) = @_;

  print "List of defined expandos:";
  for my $key (keys %$expandos) {
    print sprintf("%s = %s", $key, $expandos->{$key});
  }
}

sub _load {
  my $fh;

  if(-f $savefile) {
    print "Loading expandos from $savefile";
    open $fh, "<", $savefile or do { print "expandos.pl: Read error, '$savefile': $!"; return; };
  }

  while(my $line = readline $fh) {
    chomp $line;
    my ($exp, $val) = split /\s*=\s*/, $line, 2;
    $expandos->{$exp} = $val;
  }

  close $fh;
}

sub _save {
  open my $fh, ">", $savefile or do { print "expandos.pl: Save error, '$savefile': $!"; return; };

  print "Saving expandos to $savefile";
  for my $key (keys %$expandos) {
    print $fh sprintf("%s = %s\n", $key, $expandos->{$key});
  }

  close $fh;
}

sub init {
  _load();

  for my $key (keys %$expandos) {
    Irssi::expando_create($key, sub {
      return eval $expandos->{$key};
    }, {});
  }
}

Irssi::command_bind('expando' => sub {
  my ($data, $server, $item) = @_;
  $data =~ s/\s+$//g;
  Irssi::command_runsub('expando', $data, $server, $item);
});

Irssi::command_bind('expando add', 'cmd_expando_add');
Irssi::command_set_options('expando add' => '!f');

Irssi::command_bind('expando del', 'cmd_expando_del');
Irssi::command_bind('expando list', 'cmd_expando_list');

init;
