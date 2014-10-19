## mkshorterlink.pl -- Irssi interface for makeashorterlink.com
## (C) 2002 Gergely Nagy <algernon@bonehunter.rulez.org>
##
## Released under the GPLv2.
##
## ChangeLog:
## 0.1 -- Initial version
## 0.2 -- Added support for ignoring URLs matching certain regexps.
##        (Thanks to Ganneff for the idea)
## 0.3 -- Added help messages.

use Irssi qw();
use LWP::UserAgent;
use strict;
use vars qw($VERSION %IRSSI);

%IRSSI = (
	  'authors'	=> 'Gergely Nagy',
	  'contact'	=> 'algernon\@bonehunter.rulez.org',
	  'name'	=> 'makeashorterlink.com interface',
	  'description'	=> 'Automatically filters all http:// links through makeashorterlink.com',
	  'license'	=> 'GPL',
	  'url'		=> 'ftp://bonehunter.rulez.org/pub/irssi/mkshorterlink.pl',
	  'changed'	=> '2002-12-20'
	 );

my %noshort;
my %help = (
	    "mkshorterlink" =>
	      "mkshorterlink is an Irssi script that filters all " .
	      "http:// links through makeshorterlink.com. " .
	      "Available commands are: mkshorter, mkunshor, " .
	      "mkununshort, and mkunshortlist.",

	    "mkshort" => "MKSHORT <text>\n" .
	      "Filters the URLs in <text> through makeashorterlink.com.",
	    
	    "mkunshort" => "MKUNSHORT <regexps>\n" .
	      "All URLs matching any of the listed <regexps> will be " .
	      "ignored, and not filtered through makeashorterlink.com.",

	    "mkununshort" => "MKUNUNSHORT <regexp>\n" .
	      "Reverses the effect of MKUNSHORT.",

	    "mkunshortlist" => "MKUNSHORTLIST lists all the enabled regexps."
	   );

sub cmd_help {
	my ($args, $server, $win) = @_;

	my $topic = $args;
	$topic =~s/^\s*(.*)\s+?$/$1/;
	if (defined ($help{$topic}))
	{
		Irssi::signal_stop ();
		Irssi::print ($help{$topic});
		return;
	}
}

sub makeshorter {
	my $msg = $_[0];
	my $ua = LWP::UserAgent->new (env_proxy => 1,
				      keep_alive => 0,
				      timeout => 10,
				      agent => '');
	my $response = $ua->post ("http://makeashorterlink.com/index.php",
				  ['url' => "$msg"]);
	if ($response->content =~ /Your shorter link is: <a href=\"([^\"]+)\"/) {
		return $1;
	} else {
		return $msg;
	}
}

sub mkshorter {
	my $msg = $_[0];
	my $short = 1;

	foreach (keys %noshort)
	{
		$short = 0 if ($noshort{$_} && $msg =~ /$_/);
	}
	
	if ($msg =~ /(https?:\/\/[^ ]+)/ && $short)
	{
		my $t = $1;
		
		if ($t =~ /([\.\?\!,] ?)$/)
		{
			$t=~s/$1//;
		}
		$msg =~ s/$t/&makeshorter($t)/e;
	}
	return $msg;
}

sub cmd_mkshorter {
	my ($msg, undef, $channel) = @_;
	my $public = 0;
	
	if ($msg =~ /^-p */)
	{
		$public = 1;
		$msg =~ s/^-p *//;
	}
	
	if (defined ($channel) && $channel && $public)
	{
		$channel->command("msg $channel->{'name'} " .
				  mkshorter($msg));
	} else {
		Irssi::active_win()->printformat(MSGLEVEL_CLIENTCRAP,
						 'mkshorterlink_crap',
						 mkshorter ($msg));
	}
}

sub sig_mkshorter {
	my ($server, $msg, $nick, $address, $target) = @_;
	$target = $nick if $target eq "";
	$nick = $server->{'nick'} if $address eq "";
	my $newmsg = mkshorter ($msg);

	$server->window_item_find ($target)->print ("[mkshort] <$nick> " .
						    $newmsg, MSGLEVEL_CRAP)
	if ($newmsg ne $msg);
}

sub cmd_mkunshort {
	my @params = split (" ", $_[0]);

	foreach (@params)
	{
		$noshort{$_} = 1;
	}
}

sub cmd_mkununshort {
	my @params = split (" ", $_[0]);

	foreach (@params)
	{
		$noshort{$_} = 0;
	}
}

sub cmd_mkunshortlist {
	Irssi::active_win()->printformat (MSGLEVEL_CLIENTCRAP,
					  'mkshorterlink_crap',
					  "URLs matching these are ignored: ");
	foreach (keys %noshort)
	{
		Irssi::active_win()->printformat (MSGLEVEL_CLIENTCRAP,
						  'mkshorterlink_crap',
						  $_)
		  if ($noshort{$_});
	}
}

sub load_unshortlist {
	my $file = Irssi::get_irssi_dir."/unshortlist";
	my $count = 0;
	local *CONF;
	
	open CONF, "<", $file;
	while (<CONF>)
	{
		$noshort{$_} = 1;
		$count++;
	}
	close CONF;
	
	Irssi::printformat (MSGLEVEL_CLIENTCRAP, 'mkshorterlink_crap',
			    "Loaded $count ignore-regexps from $file.");
}

sub save_unshortlist {
	my $file = Irssi::get_irssi_dir."/unshortlist";
	local *CONF;

	open CONF, ">", $file;
	foreach (keys %noshort)
	{
		print CONF $_ if ($noshort{$_});
	}
	close CONF;

	Irssi::printformat (MSGLEVEL_CLIENTCRAP, 'mkshorterlink_crap',
			    "Saved ignore-regexps to $file.");
}

sub sig_setup_rered {
	load_unshortlist ();
}

sub sig_setup_save {
	save_unshortlist ();
}

Irssi::command_bind ('mkshorter', 'cmd_mkshorter');
Irssi::command_bind ('mkunshort', 'cmd_mkunshort');
Irssi::command_bind ('mkununshort', 'cmd_mkununshort');
Irssi::command_bind ('mkunshortlist', 'cmd_mkunshortlist');
Irssi::command_bind ('help', 'cmd_help');
Irssi::signal_add_last ('message own_public', 'sig_mkshorter');
Irssi::signal_add_last ('message public', 'sig_mkshorter');
Irssi::signal_add_last ('message own_private', 'sig_mkshorter');
Irssi::signal_add_last ('message private', 'sig_mkshorter');
Irssi::signal_add ('setup reread', 'sig_setup_reread');
Irssi::signal_add ('setup saved', 'sig_setup_save');

Irssi::theme_register(
		      [
		        'mkshorterlink_crap',
		        '{line_start}{hilight mkshorterlink:} $0'
		      ]);

load_unshortlist ();
