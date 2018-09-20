# duckduckgo.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use strict;
use POSIX;
use vars qw($VERSION %IRSSI);

use Irssi;
use LWP::UserAgent;
use HTML::Entities;
use URI::Escape;

$VERSION = '0.01';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'duckduckgo',
    description	=> 'search by https://duckduckgo.com/html/',
    license	=> 'lgplv3',
    url		=> 'http://scripts.irssi.org',
    changed	=> '2018-09-18',
);

my $url="https://duckduckgo.com/html?q={}";
#my $url="https://duckduckgo.com/html?q=irssi";
my $view_count=5;
my $browser="firefox '{}'";

my @res;
my $res_next;

# fork
my $read_handle;
my $write_handle;
my $forkcount=0;
my $pipe_tag;

sub www_get {
	(my $url) =@_;
	# Initialize LWP
	my $ua = new LWP::UserAgent;
	$ua->agent("duckduckgo.pl/0.1 " . $ua->agent);
	# get 
	my $req = new HTTP::Request GET =>$url; 
	my $res = $ua->request($req);
	return $res->content;
}

sub content2res {
	(my $content) = @_;
	my @content =split /\n/,$content;
	my @res;
	my $index=1;
	foreach (@content) {
		if ($_ =~ m/class="result__a"/) {
			my %r;
			$r{index}=$index;
			# url
			$_ =~ m/href="(.*?)"/;
			$1 =~ m/uddg=(.*)$/;
			my $u=uri_unescape($1);
			$r{url}=$u;
			# txt
			$_ =~ m#">(.*?)</a>#;
			my $s =$1;
			$r{txt_raw}=$s;
			$s=~s/<b>/%U/g;
			$s=~s#</b>#%U#g;
			$r{txt}=$s;
			# out
			push @res,{%r};
			$index++;
		}
	}
	return @res;
}

sub backgroundf {
	(my $url, my $write_handle) =@_;
	print "child start";
	my $res = www_get($url);
	print "child fertig";
	print $write_handle $res;
	print $write_handle "\n";
	close $write_handle;
}

sub view_results {
	my ($start) =@_;
	print "duckduckgo: results ";
	for (my $c=$start; $c < $view_count+$start && $c <= $#res; $c ++) {
		print $c,". ",$res[$c]->{txt};
		if (length($res[$c]->{url}) <50) {
			print "  ",$res[$c]->{url};
		} else {
			print "  ",substr($res[$c]->{url},0,20),"=>>";
		}
	}
}

sub sig_result {
	print "sig_result";
	my $r;	
	my $o_fh;
	# input
	$o_fh=select($read_handle);
	local $/;
	select($o_fh);
	$r=readline($read_handle);
	close($read_handle);
	Irssi::input_remove($pipe_tag);
	# filter
	@res= content2res($r);
	$res_next=0;
	$forkcount--;
	view_results($res_next);
}

sub sig_config {
	$url = Irssi::settings_get_str('ddg_url');
	$view_count = Irssi::settings_get_int('ddg_view_count');
}

sub cmd_ddg {
	my ($args, $server, $witem) = @_;

	my @alist =split / /,$args;
	if ($alist[0] !~ m/^-/) {
		cmd_searchf($args);
	} else {
		if ($alist[0] eq '-browser') {
			cmd_browser($alist[1]);
		} elsif ($alist[0] eq '-next') {
			cmd_next();
		} elsif ($alist[0] eq '-help') {
			cmd_help('ddg');
		} elsif ($alist[0] eq '-drop') {
			cmd_drop($alist[1],$witem);
		}
	}
}

sub cmd_drop {
	my ($args, $witem) =@_;
    if ($witem) {
        $witem->command("/say $res[$args*1]->{url}");
    }
}

sub cmd_next {
	$res_next+=$view_count;
	view_results($res_next);
}

sub cmd_searchf {
	my ($args) = @_;
	my $url2=$url;
	$args=~s/ /+/g;
	$url2=~s/{}/$args/;
	# fork
	if ($forkcount==0) {
		print "ddg:",$url2;
		$forkcount++;
		pipe($read_handle, $write_handle);
		my $o_fh=select($write_handle);
		local $|=1;
		select($o_fh);
		my $pid =fork();
		if (not defined $pid) {
			_error("Can't fork: Aborting");
			close($read_handle);
			close($write_handle);
			return;
		}
		if ($pid == 0) {
			# child
			backgroundf($url2,$write_handle);
			POSIX::_exit(1);
		} else {
			# parent
			close ($write_handle);
			Irssi::pidwait_add($pid);
			$pipe_tag = Irssi::input_add(fileno($read_handle),
							  Irssi::INPUT_READ, \&sig_result, "");
		}
	}
}

sub cmd_browser {
	my ($args) = @_;
	my $b=$browser;
	$b =~ s/{}/$res[$args*1]->{url}/;
	system($b);
}

sub cmd_help {
	if ($_[0] eq 'ddg' || $_[0] eq 'duckduckgo') {

my $help = <<'END';
/ddg <keywords>     search for the keywords
/ddg -next          display the next results
/ddg -browser <num> give the url to firefox
/ddg -drop <num>    drop the url in a channel

settings:
  ddg_view_count, 
  ddg_url, ddg_browser (placeholder {} )
END
		Irssi::print($help, MSGLEVEL_CLIENTCRAP);
		Irssi::signal_stop;
	}
}

Irssi::settings_add_str("duckduckgo", "ddg_url", $url);
Irssi::settings_add_str("duckduckgo", "ddg_browser", $browser);
Irssi::settings_add_int("duckduckgo", "ddg_view_count", $view_count);

Irssi::signal_add('setup changed', "sig_config");

Irssi::command_bind('help',\&cmd_help); 
Irssi::command_bind("ddg", \&cmd_ddg);
Irssi::command_set_options('ddg','help browser next drop');

sig_config();
