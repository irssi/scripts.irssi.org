# mailcount.pl v 1.4.5 by Marcin Rozycki (derwan@irssi.pl)
#                 changed at Sat Oct 18 14:43:27 CEST 2003
#
# Script adds statusbar item mailcount and displays info about new mails
# in your mailbox ( not support for maildir)
#
# Run command '/statusbar window add mailcount' after loading mailcount.pl.
#
# Modules:
#
#    Mail::MboxParser 
#         http://search.cpan.org/CPAN/authors/id/V/VP/VPARSEVAL/Mail-MboxParser-0.41.tar.gz
#         http://derwan.irssi.pl/perl-modules/Mail-MboxParser-0.41.tar.gz
#
#    Digest::MD5
#         http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/Digest-MD5-2.27.tar.gz
#         http://derwan.irssi.pl/perl-modules/Digest-MD5-2.27.tar.gz
#
# Settings:
#
#    Mailcount_mailbox [ list separated with spaces ] 
#         - ex. /set mailcount_mailbox /var/mail/derwan /home/derwan/inbox
#
#    Mailcount_ofset [ sconds ]
#         - 60 by default
#
#    Mailcount_show_headers [ list separated with spaces ]
#         - ex. /set mailcount_show_headers from to cc subject date sender
#
#    Mailcount_show_max [ count ]
#         - 30 by default
#         - shows all mails if value set to 0
#         - info disabled if set to -1
#
#    Mailcount_sbitem [ format ]
#         - %n - new messages
#         - %o - old messages
#         - %t - total
#

use strict;
use vars qw($VERSION %IRSSI);

use Irssi 20021117 qw( settings_add_str settings_get_str settings_add_int settings_get_int
   settings_add_bool settings_get_bool get_irssi_dir timeout_add_once theme_register active_win );

$VERSION = '1.4.5';
%IRSSI = (
  authors      => 'Marcin Rozycki',
  contact      => 'derwan@irssi.pl',
  name         => 'mailcount',
  description  => 'Adds statusbar item mailcount and displays info about new mails',
  modules      => 'Mail::MboxParser Digest::MD5',
  license      => 'GNU GPL v2',
  url          => 'http://derwan.irssi.pl',
  changed      => 'Sat Oct 18 14:43:27 CEST 2003'
);

use Irssi::TextUI;
use IO::File;
use POSIX '_exit';
use Mail::MboxParser;
use Digest::MD5 'md5_hex';

theme_register([
   'mailcount_notify', 'You have new mail in %C$0%n',
   'mailcount_sender', '%R> %CFrom:%n %_$0%_',
   'mailcount_header', '  %c$0:%n $1',
   'mailcount_more', '  ( and $0 more... )' 
]);

our ($u, $r, $active_pid, $input_tag) = (0, 0, undef, undef);
our (%register, %ctime, %cache, @buf);

sub mailcount {
   return if ( $active_pid or $input_tag );
   my $reader = IO::File->new() or return;
   my $writer = IO::File->new() or return;
   my ($n, $o) = (0, 0);
   pipe($reader, $writer);
   $active_pid = fork();
   return unless ( defined $active_pid );
   if ( $active_pid ) {
      close($writer);
      Irssi::pidwait_add($active_pid);
      $input_tag = Irssi::input_add(fileno($reader), INPUT_READ, \&input_read, $reader);
   } else {
      close($reader);
      my $headers = 'from to subject '. lc( settings_get_str('mailcount_show_headers') );
      my ($count, $max) = (0, settings_get_int('mailcount_show_max'));
      $max = 10 if ( $max > 0 and $max < 10 );
      foreach my $box ( split /[: ]+/, settings_get_str('mailcount_mailbox') ) {
         push(@buf,"ctime 0 $box", "stat n=0 o=0 $box"), next if ( not -r $box );
         my ($mn, $mo, $info, $ctime) = (0, 0, 0, (stat($box))[9]);
         if ( $ctime eq $ctime{ $box } ) {
             $mn = $cache{ $box }->{ n };
             $mo = $cache{ $box }->{ o };
         } else {
             push @buf, "ctime $ctime $box";
             my $mb = Mail::MboxParser->new( $box,
                   decode     => 'ALL',
                   parseropts => { enable_cache    => 1,
                      enable_grep     => 1,
                      cache_file_name => sprintf('%s/.mailcount-cache', get_irssi_dir) }
            );
             while ( my $msg = $mb->next_message ) {
                next if ( $msg->header->{ subject } =~ m/.*\bfolder internal data/i );
                ( $msg->header->{ status } and $msg->header->{ status } =~ m/[OR]+/i ) and ++$mo, next or ++$mn;
                unless ( is_register($msg) ) {
                   push @buf, "info $box" unless $info++;
                   next if ( ++$count > $max and $max );
                   my %header;
                   foreach my $header ( split / +/, $headers ) {
                      next if ( $header{ $header }++);
                      my $data = $msg->header->{ $header };
                      push @buf,"header $header $data" if ( defined $data );
                   }
                }
             }
             push @buf, "stat n=$mn o=$mo $box";
             push @buf, sprintf('more %d'. ($count - $max)) if ( $max > 0 and $count > $max );
          }
          $n += $mn; $o += $mo;
      }
      push(@buf,"total n=$n o=$o");
      foreach my $data ( @buf ) { print($writer "$data\n"); }
      close($writer);
      POSIX::_exit(1);
   }
}

sub is_register ($$) {
   my $msg = shift;
   my $hex = md5_hex($msg->header->{ from } . $msg->header->{ to } . 
        $msg->header->{ subject } . $msg->header->{ 'message-id' });
   return 1 if ( $register{ $hex } );
   push(@buf,"register $hex");
   return 0;
}

sub input_read {
   my $reader = shift;
   while (<$reader>) {
      chomp;
      /^ctime (\d+) (.*)/ and $ctime{ $2 } = $1, next;
      /^stat n=(\d+) o=(\d+) (.*)/ and $cache{ $3 }->{ n } = $1, $cache{ $3 }->{ o } = $2, next; 
      /^info (.*)/ and active_win->printformat(MSGLEVEL_CLIENTCRAP, 'mailcount_notify', $1), next;
      /^register (.*)/ and $register{ $1 } = 1, next;
      /^more (\d+)/ and active_win->printformat(MSGLEVEL_CLIENTCRAP, 'mailcount_more', $1), next;
      /^total n=(\d+) o=(\d+)/ and $u = $1, $r = $2, last;
      /^header ([^\s]+) (.*)/ and mailcount_show_header($1, $2);
   }
   Irssi::input_remove($input_tag);
   close($reader);
   $input_tag = $active_pid = undef;
   Irssi::statusbar_items_redraw('mailcount');
   my $timeout = settings_get_int('mailcount_ofset'); $timeout = 15 if ( $timeout <= 15 );
   timeout_add_once($timeout*1000, 'mailcount', undef);
}

sub mailcount_show_header ($$) {
   my ($header, $data) = @_;
   $data =~ s/\s+/ /g;
   active_win->printformat(MSGLEVEL_CLIENTCRAP, 'mailcount_sender', $data), return 
      if ( $header eq 'from' );
   active_win->printformat(MSGLEVEL_CLIENTCRAP, 'mailcount_header', ucfirst($header), $data);
}

sub mailcount_sbitem {
  my ($sbitem, $get_size_only) = @_;
  $sbitem->{min_size} = $sbitem->{max_size} = 0 if ($get_size_only);
  my $sbitem_format = settings_get_str('mailcount_sbitem');
  $sbitem_format = 'n/%n o/%o t/%t' unless ( $sbitem_format );
  $sbitem_format =~ s/%n/$u/e;
  $sbitem_format =~ s/%o/$r/e;
  $sbitem_format =~ s/%t/($u + $r)/e;
  $sbitem->default_handler($get_size_only, undef, $sbitem_format, 1);
}

settings_add_str('mailcount', 'mailcount_mailbox', $ENV{'MAIL'});
settings_add_int('mailcount', 'mailcount_ofset', 60);
settings_add_str('mailcount', 'mailcount_show_headers', 'from to cc subject date sender');
settings_add_int('mailcount', 'mailcount_show_max', 30);
settings_add_str('mailcount', 'mailcount_sbitem', 'n/%n o/%o t/%t');

Irssi::statusbar_item_register('mailcount', '{sb Mail: $0-}', 'mailcount_sbitem');
mailcount();
