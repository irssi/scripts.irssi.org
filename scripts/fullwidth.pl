# Copyright 2016 prussian <genunrest@gmail.com>
# Author: prussian <genunrest@gmail.com>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use Irssi qw(command_bind active_win signal_stop);
our $VERSION = '1.2.0';
our %IRSSI = (
    authors     => 'prussian',
    contact     => 'genunrest@gmail.com',
    name        => 'fullwidth',
    url         => 'http://github.com/GeneralUnRest/',
    description => 'talk like some vaporwave cool kid',
    license     => 'Apache 2.0',
);

my $help = '/fullwidth your cool text here
-> ｙｏｕｒ ｃｏｏｌ ｔｅｘｔ ｈｅｒｅ

you can also use stars to only fullwidth text between them

/fullwidth do *you* know *the* way *to* San *Jose*
-> do ｙｏｕ know ｔｈｅ way ｔｏ San Ｊｏｓｅ';

sub fullwidth {
    my $msg = $_[0];
    my $say = "";
    foreach my $char (split //, $msg) {
        if ($char =~ /\s/) {
            $say = "$say" . " ";
        }
        else {
            my $nchar = ord($char);
            if ($nchar >= 32 && $nchar <= 126) {
                $say = "$say" . chr($nchar+65248);
            }
        }
    }
    return $say;
}

command_bind(fullwidth => sub {
    my $arg = $_[0];
    my $say = '';
    if ($arg =~ /\*[^*]*\*/) {
        $say = $_[0] =~ s/\*([^*]*)\*/fullwidth($1)/reg;
    }
    else {
        $say = fullwidth($arg);
    }
    active_win->command("say $say");
});

command_bind(help => sub {
    if ($_[0] eq $IRSSI{name}) {
        Irssi::print($help, MSGLEVEL_CLIENTCRAP);
        signal_stop();
    }
});
