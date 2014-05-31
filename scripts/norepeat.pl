use strict;
use Digest::MD5 'md5_hex';

use Irssi qw(settings_add_bool settings_get_bool signal_add signal_add_first signal_stop );

use vars qw($VERSION %IRSSI);
$VERSION = '0.5';
%IRSSI = (
   authors => 'Marcin Rozycki',
   contact => 'derwan@irssi.pl',
   url => 'http://derwan.irssi.pl',
   name => 'norepeat',
   description => 'stops public repeating',
   license => 'GNU GPL v2',
   modules => 'Digest::MD5',
   changed => 'Tue Sep  9 16:34:44 CEST 2003',
);

our $norepeat_enabled = 1;
settings_add_bool('misc', 'norepeat_enabled', $norepeat_enabled);

signal_add('setup changed' => sub {
   $norepeat_enabled = settings_get_bool('norepeat_enabled');
} );

our %last_message = ();
our $last_timeout = 300;

sub check_last_message ($$$$$) {
  my ($server, $data, $nick, $address, $target) = @_;
  my ($time, $nick, $target, $md5) = (time, lc $nick, lc $target, md5_hex($data));
  if ( $norepeat_enabled and my $ref = $last_message{$server->{tag}}{$target}{$nick} ) {
    signal_stop(), return if ( $ref->[0] eq $md5 and $time - $ref->[1] <= $last_timeout  );
  }
  remove_last_message($server, $target, $nick); 
  $last_message{$server->{tag}}{$target}{$nick} = [ $md5, $time ];
}

sub remove_last_message ($$$) {
  my ($server, $target, $nick) = @_;  
  if ( my $ref = delete $last_message{$server->{tag}}{$target}{$nick} ) {
    @{$ref} = (); 
  }
}

sub last_message_clear ($;$) {
  my $chanrec = shift;
  my $target = lc $chanrec->{name};
  foreach my $nick ( keys %{$last_message{$chanrec->{server}->{tag}}{$target}} ) {
     remove_last_message($chanrec->{server}, $target, $nick);
  }
  %{$last_message{$chanrec->{server}->{tag}}{$target}} = ();
}

signal_add_first('message public', \&check_last_message); 
signal_add_first('message irc action', \&check_last_message);
signal_add_first('message irc notice', \&check_last_message);

signal_add('nicklist remove' => sub {
  my ($chanrec, $nickrec) = @_;
  remove_last_message($chanrec->{server}, lc $chanrec->{name}, lc $nickrec->{nick});
});

signal_add('nicklist new' => sub {
  my ($chanrec, $nickrec) = @_;
  remove_last_message($chanrec->{server}, lc $chanrec->{name}, lc $nickrec->{nick});
});

signal_add('nicklist changed' => sub {
  my ($chanrec, $nickrec, $oldnick) = @_;
  $last_message{$chanrec->{server}->{tag}}{lc $chanrec->{name}}{lc $nickrec->{nick}} =
     delete $last_message{$chanrec->{server}->{tag}}{lc $chanrec->{name}}{lc $oldnick};
} );

signal_add('channel created', \&last_message_clear);
signal_add('channel destroyed', \&last_message_clear);
