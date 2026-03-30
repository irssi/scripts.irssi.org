# mention_report.pl - Caches nick mentions while away and reports on return.
#
# Copyright (c) 2026 Exaga - SAIRPi Project : https://sairpi.penthux.net/
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


use strict;
use Irssi;
use POSIX qw(strftime);

our $VERSION = '1.0';
our %IRSSI = (
    authors     => 'Exaga',
    contact     => 'sairpiproject@gmail.com',	
    name        => 'mention_report',
    description => 'Caches nick mentions while away and reports on return',
	license     => 'MIT'
);

my @mentions;
my $is_away = 0;

sub catch_mention {
    my ($dest, $text, $stripped) = @_;
    # Only cache if away and the message is a Hilight or a Private Message
    if ($is_away && ($dest->{level} & (MSGLEVEL_HILIGHT | MSGLEVEL_MSGS))) {
        my $time = strftime("%H:%M", localtime);
        my $target = $dest->{target} || "PM";
        push @mentions, "[$time] $target: $stripped";
    }
}

sub toggle_away {
    my $server = Irssi::active_server();
    if ($server && $server->{usermode_away}) {
        $is_away = 1;
    } else {
        $is_away = 0;
        report_mentions();
    }
}

sub report_mentions {
    if (@mentions) {
        Irssi::print("--- MENTION REPORT ---", MSGLEVEL_CLIENTCRAP);
        foreach my $line (@mentions) {
            Irssi::print($line, MSGLEVEL_CLIENTCRAP);
        }
        Irssi::print("--- END OF REPORT ---", MSGLEVEL_CLIENTCRAP);
        @mentions = (); # Clear cache
    }
}

Irssi::signal_add('print text', 'catch_mention');
Irssi::signal_add('gui away enabled', sub { $is_away = 1; });
Irssi::signal_add('gui away disabled', 'report_mentions');

sub sig_unload {
    Irssi::print("mention_report: Unloaded (cache cleared)");
}

Irssi::signal_add_first('gui unload', 'sig_unload');

Irssi::print("mention_report $VERSION loaded - use /away to start caching mentions.");

# EOF<*>
