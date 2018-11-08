use strict;
use warnings;
use LWP::Simple qw();
use Irssi;

our $VERSION = '1.2'; # # a3f78214eed2faa
our %IRSSI = (
    authors     => 'Rocco Caputo (dngor), Nei',
    contact     => 'rcaputo@cpan.org, Nei @ anti@conference.jabber.teamidiot.de',
    name        => 'settingshelp',
    description => "Irssi $VERSION settings notes and documentation",
    license     => 'CC BY-SA 2.5, http://creativecommons.org/licenses/by-sa/2.5/',
   );

# Usage
# =====
# Now you can do:
#
#   /help set setting_here
#
# to print out its documentation (as far as it was documented on the
# Irssi website)

# NOTE
# ====
# This script will download the settings documentation from the
# github every time it is loaded

my %help;

{
    print STDERR " .. downloading settings documentation .. ";
    local $LWP::Simple::ua->{timeout} = 2;
    my $res = LWP::Simple::get("https://github.com/irssi/irssi.github.io/raw/master/documentation/settings.markdown");
    Irssi::command('redraw');
    my @res = split "\n", $res if defined $res;
    die "Error downloading settings" unless @res && $res[0] eq '---';
    while (@res) {
	my @info;
	my $soon = 0;
	my $setting;
	my $val;
	my $old_setting;
	my $old_val;
	while (defined(my $line = shift @res)) {
	    if ($line =~ /^\{:#(\w+)\}/i) {
		$soon = 1;
		$old_setting = $setting;
		$setting = $1;
	    }
	    elsif ($soon == 1 && $line =~ /^(?:` (.*) `|` (.*)` \*\*`(.*)`\*\*)$/) {
		$old_val = $val;
		$val = defined $1 ? $1 : "$2 = $3";
		$soon++;
	    }
	    elsif ($soon && $line =~ /^>+(?:\s|$)/) {
		next if $line =~ /^>>+$/;
		next if $line =~ /^>+\s+!/;
		next if $line =~ /^>+\s+```/;
		next if $line =~ /^>+\s+\{:.*?\}$/;
		$line =~ s/^>+//;
		push @info, $line;
	    }
	    elsif (@info) {
		unshift @res, $line;
		last;
	    }
	}
	unshift @info, $val if defined $val;
	s/`//g for @info;
	s/\\\\/\\/g for @info;
	if (@info) {
	    if ($old_val && $old_setting) {
		my $sep =($old_val =~ s/^\Q$old_setting\E\s+=(\s+|\s*$)//i) ? '' : ':';
		my $clr = !$sep && !$old_val ? '-clear ' : '';
		my @info2 = ("/set $clr\cB\L$old_setting\E\cB$sep ".($old_val),'',
			     "    see /help set \cB\L$setting\E\cB",'');
		s/%/%%/g for @info2;
		s/^(\s+)/$1%|/gm for @info2;
		push @{$help{"settings/$old_setting"}}, @info2;
	    }
	    my $sep =($info[0] =~ s/^\Q$setting\E\s+=(\s+|\s*$)//i) ? '' : ':';
	    my $clr = !$sep && !$info[0] ? '-clear ' : '';
	    my @info2 = ("/set $clr\cB\L$setting\E\cB$sep ".(shift @info),'',(map {"    $_"} @info),'');
	    s/%/%%/g for @info2;
	    s/^(\s+)/$1%|/gm for @info2;
	    for (@info2) {
		if (s/%\|\| (.*) \|$/$1/) {
		    s/ \| / | %|/g;
		    s/\s+$//;
		}
	    }
	    push @{$help{"settings/$setting"}}, @info2;
	}
    }
}

print CLIENTCRAP '%U%_Irssi Settings documentation licence%: ' . $IRSSI{license};
print CLIENTCRAP '%:You can now read help for settings with %_/HELP SET settingname%_';

Irssi::signal_add_first(
	'command help' => sub {
		if ($_[0] =~ s|^set\s+|settings/|i && $_[0] ne 'settings/' && ($_[0]="\L$_[0]")
		   && $_[0] =~ /^(.*?)(?:\s+|$)/ && exists $help{$1}) {
			print CLIENTCRAP join "\n", '', '%_Setting:%_%:', @{$help{$1}};
			Irssi::signal_stop;
		}
	}
       );
Irssi::signal_register({'complete command ' => [qw[glistptr_char* Irssi::UI::Window string string intptr]]});
Irssi::signal_add_last(
	"complete command help" => sub {
		my ($cl, $win, $word, $start, $ws) = @_;
		if (lc $start eq 'set') {
			&Irssi::signal_continue;
			Irssi::signal_emit('complete command set', $cl, $win, $word, '', $ws);
		}
	}
       );
