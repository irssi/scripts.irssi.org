#######################################################################
# myimdb.pl
#
# Author: Tim Van Wassenhove <timvw@users.sourceforge.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#######################################################################

use strict;
use Irssi;
use LWP::UserAgent;
use vars qw($VERSION %IRSSI);

$VERSION = '1.01';
%IRSSI = (
	authors      => 'Tim Van Wassenhove',
	contact     => 'timvw@users.sourceforge.net',
	name        => 'myimdb',
  description => 'Query imdb',
	license     => 'BSD',
	url         => 'http://home.mysth.be/~timvw',
	changed     => '13-03-04 01:43',
);

# Perform the query and return the results
sub imdb_query {

	my $query = shift;

	my $ua = LWP::UserAgent->new;
	$ua->agent("irssi/0.1 ");

  # Request the page
	my $request = HTTP::Request->new(GET => "http://us.imdb.com/Title?=$query");
	my $result = $ua->request($request);
	my $content = $result->content;
	
	# Parse the returned page
	my @lines = split("<LI>",$content);
	my @results = ();
	push(@results,"Results for $query on imdb:");
	my $counter = 1;
	foreach(@lines) {
		if ($counter < 4 && $_ =~ /^\<A HREF=\"\/title\/tt(\d+)\/\"\>(.*?)\<\/A\>\<\/LI\>$/) {
			push(@results,"http://us.imdb.com/title/tt$1 $2");
			++$counter;
		}
	}
	push(@results,"--");

	return @results;
}

# Output the results
sub results_write {
  my ($server,$target,@lines) = @_;
  foreach(@lines) {
		$server->command("MSG $target $_");
	}
}

# Handle what others say in public
sub message_public {
	my ($server,$msg,$nick,$address,$target) = @_;
	if ($msg =~ /^\!imdb\s+(.+)$/) {
		my @lines = imdb_query($1);
		results_write($server,$target,@lines);
	}
}

# Handle what we say in public
sub message_own_public {
	my ($server,$msg,$target) = @_;
	message_public($server,$msg,$server->{nick},0,$target);
}

# Handle what others say in private
sub message_private {
	my ($server,$msg,$nick,$address) = @_;
	message_public($server,$msg,$nick,$address,$nick);
}

# Handle what we say in private
sub message_own_private {
	my ($server,$msg,$target,$otarget) = @_;
	message_public($server,$msg,$server->{nick},0,$target);
}

# Connect the signals with the functions
Irssi::signal_add('message public','message_public');
Irssi::signal_add('message own_public','message_own_public');
Irssi::signal_add('message private','message_private');
Irssi::signal_add('message own_private','message_own_private');
