use strict;
use warnings;
use Irssi;
use File::Basename;
use vars qw($VERSION %IRSSI);

$VERSION = '0.2';
%IRSSI = (
  authors     => 'lasers',
  contact     => 'lasers on freenode',
  name        => 'scriptsave',
  description => 'Loads scripts from file instead of autorun directory',
  license     => 'WTFPL',
);

# ──── USAGE ────
# Outside irssi:
#   Remove ~/.irssi/scripts/autorun
#   Add "script load scriptsave" to ~/.irssi/startup
#
# Inside irssi:
#   /help script
#   /script save
#
# ──── NOTE ────
# Scripts will be saved to ~/.irssi/config.scriptsave
#
# ──── LIMITATION #1 ────
# This script will not work with scripts with a dash
# in their filenames. Remember to omit them or replace
# them with an underscore when adding new scripts.
#   ✖ Script-name.pl
#   ✔ Script_name.pl
#   ✔ Scriptname.pl
#
# ──── LIMITATION #2 ────
# This script will not work with /script exec -permanent

my $name = basename(__FILE__);
$name =~ s/\.[^.]+$//;
my $lst = Irssi::get_irssi_dir()."/config.scriptsave";

sub cmd_load_scripts(){
  if (open(my $f, '<:encoding(UTF-8)', $lst)){
    while (my $line = <$f>) {
      chomp $line;
      if ($line ne $name){
        Irssi::command('script load '.$line);
      }
    }
  }
}

sub cmd_save_scripts {
  unlink $lst;
  foreach (sort grep(s/::$//, keys %Irssi::Script::)){
    open(my $fh, ">>", $lst);
      if (($_ ne $name) && ($_ !~ m/data+(\d)/)){
        print $fh "$_\n";
      }
    close $fh;
  }
  Irssi::print ("Scripts saved to $lst");
}

sub cmd_print_help() {
  my ($args) = @_;
  if ($args =~ /^script( load)? *$/i){
    my $help = "\n/SCRIPT SAVE saves the list of currently loaded scripts to the file.";
    Irssi::print($help, MSGLEVEL_CLIENTCRAP);
  }
}
cmd_load_scripts;
Irssi::command_bind('script save', 'cmd_save_scripts');
Irssi::command_bind_last('help', 'cmd_print_help');
