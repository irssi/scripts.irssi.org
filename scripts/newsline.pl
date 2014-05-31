# by Stefan "tommie" Tomanek
# 
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '2003021101';
%IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'Newsline',
    description => 'brings various newstickers to Irssi (Slashdot, Freshmeat, Heise etc.)',
    license     => 'GPLv2',
    changed     => $VERSION,
    modules     => 'Data::Dumper XML::RSS LWP::UserAgent Unicode::String Text::Wrap',
    depends     => 'openurl',
    sbitems     => 'newsline_ticker',
    commands	=> 'newsline'
);  

use Irssi 20020324;
use Irssi::TextUI;

use Data::Dumper;
use XML::RSS;
use LWP::UserAgent;
use POSIX;
use Unicode::String qw(utf8 latin1);
use Text::Wrap;

use vars qw(@ticker $timestamp $slide $index $timer_cycle $timer_update %sites $forked);

$index = 0;
# Just to have some data for the first startup
%sites = ( Heise=>{page => 'http://www.heise.de/newsticker/heise.rdf', enable => 1, title=>'', description=>'', maxnews=>0},
           'Freshmeat'=>{'page' => 'http://freshmeat.net/backend/fm.rdf', 'enable' => 1, title=>'', description=>'', maxnews=>0}
);

sub show_help() {
    my $help = "newsline $VERSION
/newsline
    List the downloaded headlines
/newsline <number>
    Open the entry indicated by <number> via openurl.
    Openurl.pl is available at http://irssi.org/scripts/.
/newsline description <number>
    Display a brief summary of the article if available
/newsline paste <number>
    Write the headline and link to the current channel or query,
    add 'description' to a diplay the description as well
/newsline fetch
    Retrieve new data from all enabled sources
/newsline reload
    Reload configuration and sites
/newsline save
    Save configration to ~/.irssi/newsline_sites
/newsline list
    List all available sources
/newsline toggle <Source>
    Enable or disable the source
/newsline add <name> <url-to-rdf>
    Add a new source
"; 
    my $text='';
    foreach (split(/\n/, $help)) {
	$_ =~ s/^\/(.*)$/%9\/$1%9/;
	$text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("Newsline", $text, "newsline help", 1);
}

sub fork_get() {
    my ($rh, $wh);
    pipe($rh, $wh);
    return if $forked;
    $forked = 1;
    my $pid = fork();
    if ($pid > 0) {
	close $wh;
	Irssi::pidwait_add($pid);
	my $pipetag;
	my @args = ($rh, \$pipetag);
	$pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	my (%siteinfo, @items);
	eval {
	    foreach (sort keys %sites) {
		eval {
		my $site = $sites{$_};
		next unless $site->{'enable'};
		my $maxnews = -1;
		$maxnews = $site->{maxnews} if defined $site->{maxnews};
		my $url = $site->{'page'};
		my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
		my $request = HTTP::Request->new('GET', $url);
		#$request->if_modified_since($timestamp) if $timestamp;
		my $response = $ua->request($request);
		if ($response->is_success) {
		    my $data = $response->content();
		    ### FIXME I hate myself for this :)
		    $data =~ s/encoding="ISO-8859-15"/encoding="ISO-8859-1"/i;
		    my $rss = new XML::RSS();
		    $rss->parse($data);
		    my $title = $rss->{channel}->{title};
		    my $description = de_umlaut($rss->{channel}->{description});
		    my $link = de_umlaut($rss->{channel}->{link});
		    $siteinfo{$_} = {title=>$title, description=>$description, link=>$link};
		    foreach my $item (@{$rss->{items}}) {
			next unless defined($item->{title}) && defined($item->{'link'});
			my $title = de_umlaut($item->{title});
			$title =~ s/\n/ /g;
			my %story = ('title' => $title, 'link' => $item->{link}, 'source' => $_);
			$story{description} = de_umlaut($item->{description}) if $item->{description};
			push @items, \%story;
			$maxnews--;
			last if $maxnews == 0;
		    }
		};
		}
	    }
	    my %result = (news=>\@items, siteinfo=>\%siteinfo);
	    my $dumper = Data::Dumper->new([\%result]);
	    $dumper->Purity(1)->Deepcopy(1);
	    my $data = $dumper->Dump;
	    print($wh $data);
	};
	close($wh);
	POSIX::_exit(1);
    }
}

sub pipe_input {
    my ($rh, $pipetag) = @{$_[0]};
    my $text;
    $text .= $_ foreach (<$rh>);
    close($rh);
    Irssi::input_remove($$pipetag);
    return unless($text);
    no strict;
    my %result = %{ eval "$text" };
    my @items = @{$result{news}};
    my %siteinfo = %{$result{siteinfo}};
    @ticker = @items;
    foreach (sort keys %siteinfo) {
	$sites{$_}->{title} = $siteinfo{$_}->{title};
	$sites{$_}->{description} = $siteinfo{$_}->{description};
	$sites{$_}->{link} = $siteinfo{$_}->{link};
    }
    $forked = 0;
}

sub draw_box ($$$$) {
    my ($title, $text, $footer, $colour) = @_;
    my $box = ''; 
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
	$box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub cmd_newsline ($$$) {
    my ($args, $server, $witem) = @_;
    $args =~ s/^\ +//;
    my @arg = split(/\ +/, $args);
    if (scalar(@arg) == 0) {
	show_ticker(@ticker);
    } elsif ($arg[0] eq 'paste') {
	# paste tickernews
	shift(@arg);
	my $desc = 0;
	if (defined $arg[0] && $arg[0] eq 'description') {
	    $desc = 1;
	    shift(@arg);
	}
	foreach (@arg) {
	    if (defined $ticker[$_-1]) {
		my $message = $ticker[$_-1]->{'title'};
		my $text = '['.$ticker[$_-1]->{'source'}.'] "'.$message.'" -> '.$ticker[$_-1]->{'link'};
		$Text::Wrap::columns = 50;
		my $article = wrap("","",$ticker[$_-1]->{description}) if ($desc && defined $ticker[$_-1]->{description});
		my $text2 = draw_box($message, $article, $ticker[$_-1]->{source}, 0) if (defined $article);
		if (($witem) and (($witem->{type} eq "CHANNEL") or ($witem->{type} eq "QUERY"))) {
		    $witem->command("MSG ".$witem->{name}." ".$text);
		    if (defined $text2) {
			$witem->command("MSG ".$witem->{name}." ".$_) foreach (split /\n/, $text2);
		    }
		}
	    }
	}
    } elsif ($arg[0] eq 'description') {
	shift(@arg);
	foreach (@arg) {
	    next unless defined $ticker[$_-1] and defined $ticker[$_-1]->{description};
	    $Text::Wrap::columns = 50;
	    my $filter = $ticker[$_-1]->{description};
	    $filter =~ s/<.*?>//g;
	    my $article = wrap("", "", $filter);
	    my $text = '';
	    print CLIENTCRAP draw_box($ticker[$_-1]->{title}, $article, $ticker[$_-1]->{source}, 1);
	}
    } elsif ($arg[0] eq 'help') {
	show_help();
    } elsif ($arg[0] eq 'fetch') {
	fork_get()
    } elsif ($arg[0] eq 'reload') {
	reload_config();
    } elsif ($arg[0] eq 'save') {
	save_config();
    } elsif ($arg[0] eq 'add') {
	if (defined($arg[1]) && defined($arg[2])) {
	    my $source = $arg[1];
	    my $page = $arg[2];
	    $sites{$source} = {page => $page, enable => 1, maxnews=>0};
	    print CLIENTCRAP '%R>>%n Added new source "'.$arg[1].'"';
	    $timestamp = undef;
	}
    } elsif ($arg[0] eq 'delete') {
	if (defined $arg[1] && defined $sites{$arg[1]}) {
	    delete $sites{$arg[1]};
	    print CLIENTCRAP "%R>>%n ".$arg[1]." deleted";
	}
    } elsif ($arg[0] eq 'toggle') {
	# Toggle site
	if (defined $arg[1] && defined $sites{$arg[1]}) {
	    if ($sites{$arg[1]}{'enable'} == 0) {
		$sites{$arg[1]}{'enable'} = 1;
		print CLIENTCRAP "%R>>%n ".$arg[1]." enabled";
	    } else {
		$sites{$arg[1]}{'enable'} = 0;
		print CLIENTCRAP "%R>>%n ".$arg[1]." disabled";
	    }
	}
    } elsif ($arg[0] eq 'limit') {
        if (defined $arg[1] && defined $sites{$arg[1]}) {
	    if (defined $arg[2] && $arg[2] =~ /\d+/) {
                $sites{$arg[1]}{'maxnews'} = $arg[2];
                print CLIENTCRAP "%R>>%n ".$arg[1]." limited to ".$arg[2]." articles";
            }
        }
    } elsif ($arg[0] eq 'list') {
	my $text = "";
	foreach (sort keys %sites) {
	    my %site = %{$sites{$_}};
	    $text .= "%9[".$_.']%9'."\n";
	    $text .= " %9|-[page  ]->%9 ".$site{'page'}."\n";
	    #$text .= " %9|-[desc  ]->%9 ".$site{'description'}."\n" if defined $site{'description'};
	    $Text::Wrap::columns = 60;
	    my $filter = $site{'description'};
	    $filter =~ s/<.*?>//;
	    my $desc = wrap(" %9|-[desc  ]->%9 ",' %9|%9<tab>', $filter);
	    $desc =~ s/<tab>/            /g;
	    $text .= $desc."\n" if $site{'description'};
	    $text .= " %9|-[limit ]->%9 ".$site{'maxnews'}."\n";
	    $text .= " %9`-[enable]->%9 ".$site{'enable'}."\n";
	}
	print CLIENTCRAP draw_box("Newsline", $text, "newsline sources", 1);
	
    } else {
	foreach (@arg) {
	    if (defined $sites{$_}) {
		call_openurl($sites{$_}->{'link'}) if defined $sites{$_}->{'link'};
	    } elsif (/\d+/ && defined $ticker[$_-1]) {
		call_openurl($ticker[$_-1]->{'link'});
	    }
	}
    }
}

sub show_ticker (@) {
    my (@ticker) = @_;
    my $i = 1;
    my $text = '';
    foreach (@ticker) {
	my $space = ' 'x(length(scalar(@ticker))-length($i));
	my $newsitem = '%r'.$space.$i.'->%n['.$$_{source}.'] %9'.$$_{title}.'%9';
	$newsitem .= ' %9[*]%9' if defined($$_{description});
	$text .= $newsitem."\n";
	$text .= "  %B`->%n%U".$$_{link}."%U \n" if Irssi::settings_get_bool('newsline_show_url');
	$i++;
    }
    print CLIENTCRAP draw_box("Newsline", $text, "headlines", 1);
}

sub call_openurl ($) {
    my ($url) = @_;
    no strict "refs";
    # check for a loaded openurl
    if (defined %{ "Irssi::Script::openurl::" }) {
	&{ "Irssi::Script::openurl::launch_url" }($url);
    } else {
	print CLIENTCRAP "%R>>%n Please install openurl.pl";
    }
    use strict "refs";
}
sub newsline_ticker ($$) {
    my ($item, $get_size_only) = @_;
    if (Irssi::settings_get_bool('newsline_ticker_scroll')) {
	draw_tape($item, $get_size_only);
    } else {
	draw_ticker($item, $get_size_only);
    }
}
    
sub draw_ticker ($$) {
    my ($item, $get_size_only) = @_;
    if ($index >= scalar(@ticker)) {
	$index = 0
    }
    my $tape;
    $tape .= '%F%Y<Fetching>%n' if $forked;
    if (scalar(@ticker) > 0) {
	my $title = $ticker[$index]->{'title'};
	my $source = $ticker[$index]->{'source'};
	$tape .= '>'.($index+1).': ['.$source.'] '.$title;
	$tape .= ' [*]' if defined($ticker[$index]->{description});
	$tape .= '<';
    } else {
	$tape .= '>Enter "/newsline fetch" to retrieve tickerdata>' unless $forked;
    }
    $tape = substr($tape, 0, Irssi::settings_get_int('newsline_ticker_max_width'));
    my $format = "{sb ".$tape."}";
    $item->{min_size} = $item->{max_size} = length($tape)+2;
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub rotate ($$) {
    my ($text, $rot) = @_;
    return($text) if length($text) < 1;
    for (0..$rot) {
	my $letter = substr($text, 0, 1);
	$text = substr($text, 1);
	$text = $text.$letter;
    }
    return($text);
}

sub draw_tape ($$) {
    my ($item, $get_size_only) = @_;
    my $tape;
    if (scalar(@ticker) > 0) {
	my $i=1;
	foreach (@ticker) {
	    my $title = $_->{'title'};
	    my $source = $_->{'source'};
	    $tape .= '>'.($i).': ['.$source.'] '.$title.'|';
	    $i++;
	}
	$tape = $tape;
	$slide = 0 if $slide >= length($tape); 
	$tape = rotate($tape, $slide);
	$tape = substr($tape, 0, Irssi::settings_get_int('newsline_ticker_max_width'));
    } else {
	$tape .= 'Use "/newsline -f" to fetch tickerdata';
    }
    my $format = "{sb ".$tape."}";
    $item->{min_size} = $item->{max_size} = length($tape)+2;
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub cycle_ticker () {
    $index++;
    if ($index >= scalar(@ticker)) {
	$index = 0
    }
    $slide++;
    Irssi::statusbar_items_redraw('newsline_ticker');
}

sub update_ticker () {
    fork_get();
}

sub reload_config() {
    my $filename = Irssi::settings_get_str('newsline_sites_file');
    my $text;
    if (-e $filename) {
	local *F;
	open F, "<".$filename;
	$text .= $_ foreach (<F>);
	close F;
	if ($text) {
	    no strict;
	    my %pages = %{ eval "$text" };
	    if (%pages) {
		%sites = ();
		foreach (keys %pages) {
		    $sites{$_} = $pages{$_};
		}
	    }
	}
    }
    Irssi::timeout_remove($timer_cycle) if defined $timer_cycle;
    Irssi::timeout_remove($timer_update) if defined $timer_update;
    $timer_cycle = Irssi::timeout_add(Irssi::settings_get_int('newsline_ticker_cycle_delay'), 'cycle_ticker', undef) if Irssi::settings_get_int('newsline_ticker_cycle_delay') > 0;
    $timer_update = Irssi::timeout_add(Irssi::settings_get_int('newsline_fetch_interval')*1000, 'update_ticker', undef) if Irssi::settings_get_int('newsline_fetch_interval') > 0;
    Irssi::statusbar_items_redraw('newsline_ticker');
    print CLIENTCRAP '%R>>%n Newsline sites loaded from '.$filename;
}

sub save_config() {
    local *F;
    my $filename = Irssi::settings_get_str('newsline_sites_file');
    open(F, ">$filename");
    my $dumper = Data::Dumper->new([\%sites], ['sites']);
    $dumper->Purity(1)->Deepcopy(1);
    my $data = $dumper->Dump;
    print (F $data);
    close(F);
    print CLIENTCRAP '%R>>%n Newsline sites saved to '.$filename;
}

sub de_umlaut ($) {
    my ($data) = @_;
    Unicode::String->stringify_as('utf8');
    my $s = new Unicode::String($data);
    my $result = $s->latin1();
    return($result);
}

sub sig_complete_word ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.newsline (toggle|delete|add|limit)/;
    foreach (keys %sites) {
	push @$list, $_ if /^(\Q$word\E.*)?$/;
    }
    Irssi::signal_stop();
}

Irssi::signal_add_first('complete word', \&sig_complete_word);
Irssi::signal_add('setup saved', \&save_config);

Irssi::command_bind('newsline', \&cmd_newsline);
foreach my $cmd ('description', 'paste', 'paste description', 'fetch', 'reload', 'save', 'list', 'toggle', 'add', 'delete', 'help', 'limit') {
    Irssi::command_bind('newsline '.$cmd =>
	sub { cmd_newsline("$cmd ".$_[0], $_[1], $_[2]); } );
}

Irssi::settings_add_int($IRSSI{'name'}, 'newsline_fetch_interval', 600);

Irssi::settings_add_int($IRSSI{'name'}, 'newsline_ticker_max_width', 50);

Irssi::settings_add_int($IRSSI{'name'}, 'newsline_ticker_cycle_delay', 3000);
Irssi::settings_add_str($IRSSI{'name'}, 'newsline_sites_file', Irssi::get_irssi_dir()."/newsline_sites");
Irssi::settings_add_bool($IRSSI{'name'}, 'newsline_show_url', 1);
Irssi::settings_add_bool($IRSSI{'name'}, 'newsline_ticker_scroll', 0);

Irssi::statusbar_item_register('newsline_ticker', 0, 'newsline_ticker');

reload_config();
update_ticker();
print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /newsline help for help';
