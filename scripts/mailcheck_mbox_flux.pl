#!/usr/bin/perl -w

use strict;
use Irssi;

use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
    authors     => "Erkki Seppälä",
    contact     => "flux\@inside.org",
    name        => "Mail Check",
    description => "Polls your unix mailbox for new mail",
    license     => "Public Domain",
    url         => "http://xulfad.inside.org/~flux/software/irssi/",
    changed     => "Mon Mar  4 23:25:18 EET 2002"
);

sub getMessages( $ ) {
  local *F;
  open(F, "<", $_[0]) or return ();
  my $inHeaders = 0;
  my $headers;
  my %result = ();
  my $time;
  while (<F>) {
    chomp;
    if (/^From /) {
      my @fields = /^From [^ ]+ (.*)/;
      $time = $fields[0];
      $inHeaders = 1;
    } elsif ($inHeaders) {
      if ($_ eq "") {
	$result{$time} = $headers;

	$inHeaders = 0;
	$headers = {};
      } else {
	my @fields = /^([^:]+): (.*)$/;
	if (@fields == 2) {
	  $headers->{$fields[0]} = $fields[1];
	}
      }
    }
  }
  close(F);

  return %result;
}

# assumes both headers are in time order
# format: From flux@xulfad.ton.tut.fi Wed Jan 24 23:44:00 2001
sub newMail ( $$ ) {
  my ($box, $contents) = @_;
  my @newMail;
  foreach my $mail (keys %{$contents}) {
    if (!exists $box->{contents}->{$mail}) {
      push @newMail, {%{$contents->{$mail}}, BOX=>$box};
    }
  }
  return @newMail;
}

sub checkMail( $ ) {
  my $boxes = shift;
  my @changed = ();
  foreach my $box (keys %{$boxes}) {
#    Irssi::print "Checking $box";
    my @st = stat($box);
    my $mtime = $st[9];
    if ($mtime != $boxes->{$box}->{time}) {
      my %contents = getMessages($box);
      if ($boxes->{$box}->{time}) {
	push @changed, newMail($boxes->{$box}, \%contents);
      }
      $boxes->{$box}->{contents} = \%contents;
      $boxes->{$box}->{time} = $mtime;
    }
  }
  return @changed;
}

sub coalesce {
  while (@_) {
    if (defined $_[0]) {
      return $_[0];
    }
    shift;
  }
  return undef;
}

my @boxes = ("/var/spool/mail/flux", "/home/flux/mail/vv");
my %boxes;
# ("/var/spool/mail/flux" => {name=>"INBOX", time=>0} );

for (my $c = 0; $c < @boxes; ++$c) {
  $boxes{$boxes[$c]}->{time} = 0;
  if ($c == 0) {
    $boxes{$boxes[$c]}->{name} = "INBOX";
  } else {
    my @f = $boxes[$c] =~ /([^\/]*)$/;
    $boxes{$boxes[$c]}->{name} = $f[0];
  }
}

sub check {
  my @newMail = checkMail(\%boxes);
  foreach my $mail (@newMail) {
    my $row = $mail->{BOX}->{name} . " ::: " . $mail->{From} . ": " . coalesce($mail->{Subject}, "(no subject)");
    Irssi::print($row);
#    active_server()->print($row);
  }
}

Irssi::timeout_add(10000, "check", "");

check();
