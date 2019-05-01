# by Stefan "tommie" Tomanek
#
# scriptassist.pl
#
use strict;

our $VERSION = '2019042800';
our %IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'scriptassist',
    description => 'keeps your scripts on the cutting edge',
    license     => 'GPLv2',
    url         => 'http://irssi.org/scripts/',
    modules     => 'Data::Dumper CPAN::Meta::YAML Digest::SHA File::Fetch File::Basename POSIX',
    commands	=> "scriptassist"
);

=head1 TODO

 * check sign
 * rating

=cut

use Irssi 20020324;
use Data::Dumper;
use CPAN::Meta::YAML;
use Digest::SHA qw/sha1_hex/;
use File::Fetch;
use File::Basename;
use Encode;
use POSIX;

# old datas (sha, ...)
my %old_data;

# config cache
my $scriptassist_cache_sources;

#my ($forked, %remote_db, $have_gpg, @complist);
my ($forked, %remote_db, @complist);

sub show_help {
    my $help = "scriptassist $VERSION
/scriptassist check
    Check all loaded scripts for new available versions
/scriptassist update <script|all>
    Update the selected or all script to the newest version
/scriptassist search <query>
    Search the script database
/scriptassist info <scripts>
    Display information about <scripts>
".
"/scriptassist new <num>
    Display the newest <num> scripts
".
"/scriptassist contact <script>
    Write an email to the author of the script
    (Requires OpenURL)
/scriptassist cpan <module>
    Visit CPAN to look for missing Perl modules
    (Requires OpenURL)
/scriptassist install <script>
    Retrieve and load the script
/scriptassist autorun <script>
    Toggles automatic loading of <script>
";  
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("ScriptAssist", $text, "scriptassist help", 1);
}

sub draw_box {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    $box = encode(Irssi::settings_get_str('term_charset'),$box);
    return $box;
}

sub call_openurl {
    my ($url) = @_;
    # check for a loaded openurl
    if (my $code = Irssi::Script::openurl::->can('launch_url')) {
	$code->($url);
    } else {
        print CLIENTCRAP "%R>>%n Please install openurl.pl";
    }
}

sub bg_do {
    my ($func) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    if ($forked) {
	print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
	return;
    }
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	print CLIENTCRAP "%R>>%n Please wait...";
        close $wh;
        Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($rh, \$pipetag, $func);
        $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my @items = split(/ /, $func);
	    my %result;
	    my $ts1 = $remote_db{timestamp};
	    my $xml = get_scripts();
	    my $ts2 = $remote_db{timestamp};
	    if (not($ts1 eq $ts2) && Irssi::settings_get_bool('scriptassist_cache_sources')) {
		$result{db} = $remote_db{db};
		$result{timestamp} = $remote_db{timestamp};
	    }
	    if (exists $remote_db{info}) {
		$result{info} = $remote_db{info};
	    }
	    if ($items[0] eq 'check') {
		$result{data}{check} = check_scripts($xml);
	    } elsif ($items[0] eq 'update') {
		shift(@items);
		$result{data}{update} = update_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'search') {
		shift(@items);
		foreach (@items) {
		    $result{data}{search}{$_} = search_scripts($_, $xml);
		}
	    } elsif ($items[0] eq 'install') {
		shift(@items);
		$result{data}{install} = install_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'debug') {
		shift(@items);
		$result{data}{debug} = debug_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'info') {
		shift(@items);
		$result{data}{info} = script_info(\@items, $xml);
	    } elsif ($items[0] eq 'new') {
		my $new = get_new($items[1], $xml);
		$result{data}{new} = $new;
	    } elsif ($items[0] eq 'unknown') {
		my $cmd = $items[1];
		$result{data}{unknown}{$cmd} = get_unknown($cmd, $xml);
	    }
	    my $yaml= CPAN::Meta::YAML->new(\%result);
	    print($wh $yaml->write_string());
	};
	if ($@) {
	    my $yaml= CPAN::Meta::YAML->new({data=>{error=>$@}});
	    print($wh $yaml->write_string());
	}
	close($wh);
	POSIX::_exit(1);
    }
}

sub get_unknown {
    my ($cmd, $db) = @_;
    foreach (keys %$db) {
	next unless defined $db->{$_}{commands};
	foreach my $item (split / /, $db->{$_}{commands}) {
	    return { $_ => $db->{$_} } if ($item =~ /^$cmd$/i);
	}
    }
    return undef;
}

sub get_names {
    my ($sname, $db) = shift;
    $sname =~ s/\s+$//;
    $sname =~ s/\.pl$//;
    my $plname = "$sname.pl";
    $sname =~ s/^.*\///;
    my $xname = $sname;
    $xname =~ s/\W/_/g;
    my $pname = "${xname}::";
    if ($xname ne $sname || $sname =~ /_/) {
	my $dir = Irssi::get_irssi_dir()."/scripts/";
	if ($db && exists $db->{"$sname.pl"}) {
	    # $found = 1;
	} elsif (-e $dir.$plname || -e $dir."$sname.pl" || -e $dir."autorun/$sname.pl") {
	    # $found = 1;
	} else {
	    # not found
	    my $pat = $xname; $pat =~ y/_/?/;
	    my $re = "\Q$xname"; $re =~ s/\Q_/./g;
	    if ($db) {
		my ($cand) = grep /^$re\.pl$/, sort keys %$db;
		if ($cand) {
		    return get_names($cand, $db);
		}
	    }
	    my ($cand) = glob "'$dir$pat.pl' '${dir}autorun/$pat.pl'";
	    if ($cand) {
		$cand =~ s/^.*\///;
		return get_names($cand, $db);
	    }
	}
    }
    ($sname, $plname, $pname, $xname)
}

sub script_info {
    my ($scripts, $xml) = @_;
    my %result;
    foreach (@{$scripts}) {
	my ($sname, $plname, $pname) = get_names($_, $xml);
	next unless (defined $xml->{$plname} || ( exists $Irssi::Script::{$pname} 
		&& exists $Irssi::Script::{$pname}{IRSSI} ));
	$result{$sname}{version} = get_remote_version($sname, $xml);
	my @headers = ('authors', 'contact', 'description', 'license', 'source');
	foreach my $entry (@headers) {
	    $result{$sname}{$entry} = $Irssi::Script::{$pname}{IRSSI}{$entry};
	    if (defined $xml->{$plname}{$entry}) {
		$result{$sname}{$entry} = $xml->{$plname}{$entry};
	    }
	}
	if ($xml->{$plname}{signature_available}) {
	    $result{$sname}{signature_available} = 1;
	}
	if (defined $xml->{$plname}{modules}) {
	    my $modules = $xml->{$plname}{modules};
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$result{$sname}{modules}{$mod}{optional} = $opt;
		$result{$sname}{modules}{$mod}{installed} = module_exist($mod);
	    }
	} elsif (defined $Irssi::Script::{$pname}{IRSSI}{modules}) {
	    my $modules = $Irssi::Script::{$pname}{IRSSI}{modules};
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$result{$sname}{modules}{$mod}{optional} = $opt;
		$result{$sname}{modules}{$mod}{installed} = module_exist($mod);
	    }
	}
	if (defined $xml->{$plname}{depends}) {
	    my $depends = $xml->{$plname}{depends};
	    foreach my $dep (split(/ /, $depends)) {
		$result{$sname}{depends}{$dep}{installed} = 1;
	    }
	}
    }
    return \%result;
}

sub get_new {
    my ($num, $xml) = @_;
    my $result;
    foreach (sort {$xml->{$b}{modified} cmp $xml->{$a}{modified}} keys %$xml) {
	my %entry = %{ $xml->{$_} };
	next if $entry{HIDDEN};
	$result->{$_} = \%entry;
	$num--;
	last unless $num;
    }
    return $result;
}

sub module_exist {
    my ($module) = @_;
    $module =~ s/::/\//g;
    foreach (@INC) {
	return 1 if (-e $_."/".$module.".pm");
    }
    return 0;
}

sub debug_scripts {
    my ($scripts, $xml) = @_;
    my %result;
    foreach (@{$scripts}) {
	my ($sname, $plname) = get_names($_, $xml);
	if (defined $xml->{$plname}{modules}) {
	    my $modules = $xml->{$plname}{modules};
	    foreach my $mod (split(/ /, $modules)) {
                my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
                $mod = $1 if $1;
                $result{$sname}{$mod}{optional} = $opt;
                $result{$sname}{$mod}{installed} = module_exist($mod);
	    }
	}
    }
    return(\%result);
}

sub install_scripts {
    my ($scripts, $xml) = @_;
    my %success;
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    foreach (@{$scripts}) {
	my ($sname, $plname, $pname) = get_names($_, $xml);
	if (get_local_version($sname) && (-e $dir.$plname)) {
	    $success{$sname}{installed} = -2;
	} else {
	    $success{$sname} = download_script($sname, $xml);
	}
    }
    return \%success;
}

sub update_scripts {
    my ($list, $database) = @_;
    $list = loaded_scripts() if ($list->[0] eq "all" || scalar(@$list) == 0);
    my %status;
    foreach (@{$list}) {
	my ($sname) = get_names($_, $database);
	my $local = get_local_version($sname);
	my $remote = get_remote_version($sname, $database);
	next if $local eq '' || $remote eq '';
	if (compare_versions($local, $remote) eq "older") {
	    $status{$sname} = download_script($sname, $database);
	} else {
	    $status{$sname}{installed} = -2;
	}
	$status{$sname}{remote} = $remote;
	$status{$sname}{local} = $local;
    }
    return \%status;
}

sub search_scripts {
    my ($query, $database) = @_;
    $query =~ s/\.pl\Z//;
    my %result;
    foreach (sort keys %{$database}) {
	my %entry = %{$database->{$_}};
	next if $entry{HIDDEN};
	my $string = $_." ";
	$string .= $entry{description} if defined $entry{description};
	if ($string =~ /$query/i) {
	    my $name = $_;
	    $name =~ s/\.pl$//;
	    if (defined $entry{description}) {
		$result{$name}{desc} = $entry{description};
	    } else {
		$result{$name}{desc} = "";
	    }
	    if (defined $entry{authors}) {
		$result{$name}{authors} = $entry{authors};
	    } else {
		$result{$name}{authors} = "";
	    }
	    if (get_local_version($name)) {
		$result{$name}{installed} = 1;
	    } else {
		$result{$name}{installed} = 0;
	    }
	}
    }
    return \%result;
}

sub pipe_input {
    my ($rh, $pipetag) = @{$_[0]};
    my $text = do { local $/; <$rh>; };
    close($rh);
    Irssi::input_remove($$pipetag);
    $forked = 0;
    unless ($text) {
	print CLIENTCRAP "%R<<%n Something weird happend (no text)";
	return();
    }
    utf8::decode($text);
    my $yaml= CPAN::Meta::YAML->read_string($text);
    my $incoming = $yaml->[0];
    if ($incoming->{db} && $incoming->{timestamp}) {
    	$remote_db{db} = $incoming->{db};
	$remote_db{info} = $incoming->{info};
    	$remote_db{timestamp} = $incoming->{timestamp};
	%old_data= %{$incoming};
    }
    if ($incoming->{info}->{error} >0 ) {
	$incoming->{info}->{error}= 0;
	foreach (@{$incoming->{info}->{error_texts}}) {
	    print_error($_);
	}
	$incoming->{info}->{error_texts}=[];
    }
    unless (defined $incoming->{data}) {
	print CLIENTCRAP "%R<<%n Something weird happend (no data)";
	return;
    }
    my %result = %{ $incoming->{data} };
    @complist = ();
    if (defined $result{new}) {
	print_new($result{new});
	push @complist, $_ foreach keys %{ $result{new} };
    }
    if (defined $result{check}) {
	print_check(%{$result{check}});
	push @complist, $_ foreach keys %{ $result{check} };
    }
    if (defined $result{update}) {
	print_update(%{ $result{update} });
	push @complist, $_ foreach keys %{ $result{update} };
    }
    if (defined $result{search}) {
	foreach (keys %{$result{search}}) {
	    print_search($_, %{$result{search}{$_}});
	    push @complist, keys(%{$result{search}{$_}});
	}
    }
    if (defined $result{install}) {
	print_install(%{ $result{install} });
	push @complist, $_ foreach keys %{ $result{install} };
    }
    if (defined $result{debug}) {
	print_debug(%{ $result{debug} });
    }
    if (defined $result{info}) {
	print_info(%{ $result{info} });
    }
    if ($result{unknown}) {
        print_unknown($result{unknown});
    }
    if (defined $result{error}) {
	print CLIENTCRAP "%R<<%n There was an error in background processing:"; chomp($result{error});
	print CLIENTERROR $result{error};
    }

}

sub print_unknown {
    my ($data) = @_;
    foreach my $cmd (keys %$data) {
	print CLIENTCRAP "%R<<%n No script provides '/$cmd'" unless $data->{$cmd};
	foreach (keys %{ $data->{$cmd} }) {
	    my $text .= "The command '/".$cmd."' is provided by the script '".$data->{$cmd}{$_}{name}."'.\n";
	    $text .= "This script is currently not installed on your system.\n";
	    $text .= "If you want to install the script, enter\n";
	    my ($name) = get_names($_);
	    $text .= "  %U/script install ".$name."%U ";
	    my $output = draw_box("ScriptAssist", $text, "'".$_."' missing", 1);
	    print CLIENTCRAP $output;
	}
    }
}

sub print_error {
    my ($error_txt) = @_;
    if ($error_txt =~ m/^(.*?:)(.*)$/) {
	Irssi::printformat(
	    MSGLEVEL_CLIENTCRAP, 'error_msg', $1, $2);
    } else {
	Irssi::printformat(
	    MSGLEVEL_CLIENTCRAP, 'error_msg', '', $error_txt);
    }
}

sub check_autorun {
    my ($script) = @_;
    my (undef, $plname) = get_names($script);
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    if (-e $dir."/autorun/".$plname) {
	if (readlink($dir."/autorun/".$plname) eq "../".$plname) {
	    return 1;
	}
    }
    return 0;
}

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $text .= $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1) unless ($_ == scalar(@$line)-1);
        }
        $text .= "\n";
    }
    return $text;
}


sub print_info {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys(%data)) {
	my ($local, $autorun);
	if (get_local_version($script)) {
	    $line .= "%go%n ";
	    $local = get_local_version($script);
	} else {
	    $line .= "%ro%n ";
	    $local = undef;
	}
	if (defined $local || check_autorun($script)) {
	    $autorun = "no";
	    $autorun = "yes" if check_autorun($script);
	} else {
	    $autorun = undef;
	}
	$line .= "%9".$script."%9\n";
	$line .= "  Version    : ".$data{$script}{version}."\n";
	$line .= "  Source     : ".$data{$script}{source}."\n";
	$line .= "  Installed  : ".$local."\n" if defined $local;
	$line .= "  Autorun    : ".$autorun."\n" if defined $autorun;
	$line .= "  Authors    : ".$data{$script}{authors};
	$line .= " %Go-m signed%n" if $data{$script}{signature_available};
	$line .= "\n";
	$line .= "  Contact    : ".$data{$script}{contact}."\n";
	$line .= "  Description: ".$data{$script}{description}."\n";
	$line .= "\n" if $data{$script}{modules};
	$line .= "  Needed Perl modules:\n" if $data{$script}{modules};

        foreach (sort keys %{$data{$script}{modules}}) {
            if ( $data{$script}{modules}{$_}{installed} == 1 ) {
                $line .= "  %g->%n ".$_." (found)";
            } else {
                $line .= "  %r->%n ".$_." (not found)";
            }
	    $line .= " <optional>" if $data{$script}{modules}{$_}{optional};
            $line .= "\n";
        }
	$line .= "  Needed Irssi Scripts:\n" if $data{$script}{depends};
	foreach (sort keys %{$data{$script}{depends}}) {
	    if ( $data{$script}{depends}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (loaded)";
	    } else {
		$line .= "  %r->%n ".$_." (not loaded)";
	    }
	    $line .= "\n";
	}
    }
    print CLIENTCRAP draw_box('ScriptAssist', $line, 'info', 1) ;
}

sub print_new {
    my ($list) = @_;
    my @table;
    foreach (sort {$list->{$b}{modified} cmp $list->{$a}{modified}} keys %$list) {
	my @line;
	my ($name) = get_names($_);
        if (get_local_version($name)) {
            push @line, "%go%n";
        } else {
            push @line, "%yo%n";
        }
	push @line, "%9".$name."%9";
	push @line, $list->{$_}{modified};
	push @table, \@line;
    }
    print CLIENTCRAP draw_box('ScriptAssist', array2table(@table), 'new scripts', 1) ;
}

sub print_debug {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys %data) {
	$line .= "%ro%n %9".$script."%9 failed to load\n";
	$line .= "  Make sure you have the following perl modules installed:\n";
	foreach (sort keys %{$data{$script}}) {
	    if ( $data{$script}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (found)";
	    } else {
		$line .= "  %r->%n ".$_." (not found)\n";
		$line .= "     [This module is optional]\n" if $data{$script}{$_}{optional};
		$line .= "     [Try /scriptassist cpan ".$_."]";
	    }
	    $line .= "\n";
	}
	print CLIENTCRAP draw_box('ScriptAssist', $line, 'debug', 1) ;
    }
}

sub load_script {
    my ($script) = @_;
    Irssi::command('script load '.$script);
}

sub print_install {
    my (%data) = @_;
    my $text;
    my ($crashed, @installed);
    foreach my $script (sort keys %data) {
	my $line;
	if ($data{$script}{installed} == 1) {
	    my $hacked;
	    load_script($script) unless (lc($script) eq lc($IRSSI{name}));
    	    if (get_local_version($script) && not lc($script) eq lc($IRSSI{name})) {
		$line .= "%go%n %9".$script."%9 installed\n";
		push @installed, $script;
	    } elsif (lc($script) eq lc($IRSSI{name})) {
		$line .= "%yo%n %9".$script."%9 installed, please reload manually\n";
	    } else {
    		$line .= "%Ro%n %9".$script."%9 fetched, but unable to load\n";
		$crashed .= $script." " unless $hacked;
	    }
	} elsif ($data{$script}{installed} == -2) {
	    $line .= "%ro%n %9".$script."%9 already loaded, please try \"update\"\n";
	} elsif ($data{$script}{installed} <= 0) {
	    $line .= "%ro%n %9".$script."%9 not installed\n";
	} else {
	    $line .= "%Ro%n %9".$script."%9 not found on server\n";
	}
	$text .= $line;
    }
    # Inspect crashed scripts
    bg_do("debug ".$crashed) if $crashed;
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'install', 1);
    list_sbitems(\@installed);
}

sub list_sbitems {
    my ($scripts) = @_;
    my $text;
    foreach (@$scripts) {
	next unless exists $Irssi::Script::{"${_}::"};
	next unless exists $Irssi::Script::{"${_}::"}{IRSSI};
	my $header = $Irssi::Script::{"${_}::"}{IRSSI};
	next unless $header->{sbitems};
	$text .= '%9"'.$_.'"%9 provides the following statusbar item(s):'."\n";
	$text .= '  ->'.$_."\n" foreach (split / /, $header->{sbitems});
    }
    return unless $text;
    $text .= "\n";
    $text .= "Enter '/statusbar window add <item>' to add an item.";
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'sbitems', 1);
}

sub print_search {
    my ($query, %data) = @_;
    my $text;
    foreach (sort keys %data) {
	my $line;
	$line .= "%go%n" if $data{$_}{installed};
	$line .= "%yo%n" if not $data{$_}{installed};
	$line .= " %9".$_."%9 ";
	$line .= $data{$_}{desc};
	$line =~ s/($query)/%U$1%U/gi;
	$line .= ' ('.$data{$_}{authors}.')';
	$text .= $line." \n";
    }
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'search: '.$query, 1) ;
}

sub print_update {
    my (%data) = @_;
    my $text;
    my @table;
    my $verbose = Irssi::settings_get_bool('scriptassist_update_verbose');
    foreach (sort keys %data) {
	my $signed = 0;
	if ($data{$_}{installed} == 1) {
	    my $local = $data{$_}{local};
	    my $remote = $data{$_}{remote};
	    push @table, ['%yo%n', '%9'.$_.'%9', 'upgraded ('.$local.'->'.$remote.')'];
	    if (lc($_) eq lc($IRSSI{name})) {
		push @table, ['', '', "%R%9Please reload manually%9%n"];
	    } else {
		load_script($_);
	    }
	} elsif ($data{$_}{installed} == 0 || $data{$_}{installed} == -1) {
	    push @table, ['%yo%n', '%9'.$_.'%9', 'not upgraded'];
	} elsif ($data{$_}{installed} == -2 && $verbose) {
	    my $local = $data{$_}{local};
	    push @table, ['%go%n', '%9'.$_.'%9', 'already at the latest version ('.$local.')'];
    	}
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'update', 1) ;
}

sub contact_author {
    my ($script) = @_;
    my ($sname, $plname, $pname) = get_names($script);
    return unless exists $Irssi::Script::{$pname};
    my $header = $Irssi::Script::{$pname}{IRSSI};
    if ($header && defined $header->{contact}) {
	my @ads = split(/ |,/, $header->{contact});
	my $address = $ads[0];
	$address .= '?subject='.$script;
	$address .= '_'.get_local_version($script) if defined get_local_version($script);
	call_openurl($address) if $address =~ /[\@:]/;
    }
}

# get file via url and return the content
sub get_file {
    my ($url) =@_;
    $File::Fetch::USER_AGENT='ScriptAssist/'.$VERSION;
    $File::Fetch::WARN=0;
    my $ff= File::Fetch->new(uri=> $url);
    my $cont;
    my $w = $ff->fetch(to=>\$cont);
    if (defined $w) {
	unlink $w;
	rmdir dirname($w);
    }
    return $cont;
}

# put the error strings in the remote_db
sub put_bg_error {
    my ($error) =@_;
    if (!exists $remote_db{info}->{error_texts} ) {
	$remote_db{info}->{error_texts} = [];
    }
    push @{$remote_db{info}->{error_texts}}, $error;
    $remote_db{info}->{error}++;
}

# get the script datas
sub get_scripts {
    my @mirrors = split(/ /, Irssi::settings_get_str('scriptassist_script_sources'));
    my %sites_db;
    my $not_modified = 1;
    my $fetched = 0;
    my @sources;
    my $error;
    foreach my $site (@mirrors) {
	my ($src, $type);
	if ($site =~ /(.*\/).+\.(.+)/) {
	    $src = $1;
	    $type = $2;
	}
	push @sources, $src;
	$site =~ m/^(.*)\..*?$/;
	my $site_sum= $1.'.sha';
	my $site_yaml= $1.'.yaml';
	my $old_sum;
	if (exists $remote_db{info}->{$src}) {
	    $old_sum=$remote_db{info}->{$src}->{sha};
	}
	my $new_sum= get_file($site_sum);
	if (!defined $new_sum) {
	    put_bg_error("Error: fetch file '$site_sum'");
	} else {
	    my $new_yaml;
	    if ( $new_sum ne $old_sum || !$scriptassist_cache_sources) {
		$new_yaml= get_file($site_yaml);
		if (!defined $new_yaml) {
		    put_bg_error("Error: fetch file '$site_yaml'");
		} else {
		    if (sha1_hex($new_yaml) ne $new_sum) {
			put_bg_error("Error: Checksum sha1_hex($site_yaml) ne $site_sum");
		    } else {
#my @header = ('name', 'contact', 'authors', 'description', 'version', 'modules', 'modified');
			$fetched = 1;
			$remote_db{info}->{$src}->{sha}=$new_sum;
			utf8::decode($new_yaml);
			my $new_ydb =CPAN::Meta::YAML->read_string($new_yaml)
			    or put_bg_error("Error: ".CPAN::Meta::YAML->errstr);
			# make index
			my $new_db;
			foreach (@{$new_ydb->[0]}) {
			    $new_db->{$_->{filename}}=$_;
			}
			#
			foreach (keys %$new_db) {
			    if (defined $sites_db{script}{$_}) {
				my $old = $sites_db{$_}{version};
				my $new = $new_db->{$_}{version};
				next if (compare_versions($old, $new) eq 'newer');
			    }
			    foreach my $key (keys %{ $new_db->{$_} }) {
				next unless defined $new_db->{$_}{$key};
				$sites_db{$_}{$key} = $new_db->{$_}{$key};
			    }
			    $sites_db{$_}{source} = $src;
			}
		    }
		}
	    }
	}
    }
    if ($fetched) {
	# Clean database
	foreach (keys %{$remote_db{db}}) {
	    foreach my $site (@sources) {
		if ($remote_db{db}{$_}{source} eq $site) {
		    delete $remote_db{db}{$_};
		    last;
		}
	    }
	}
	$remote_db{db}{$_} = $sites_db{$_} foreach (keys %sites_db);
	$remote_db{timestamp} = time();
    }
    return $remote_db{db};
}

sub get_remote_version {
    my ($script, $database) = @_;
    my $plname = (get_names($script, $database))[1];
    return $database->{$plname}{version};
}

sub get_local_version {
    my ($script) = @_;
    my $pname = (get_names($script))[2];
    return unless exists $Irssi::Script::{$pname};
    my $vref = $Irssi::Script::{$pname}{VERSION};
    return $vref ? $$vref : undef;
}

sub compare_versions {
    my ($ver1, $ver2) = @_;
    for ($ver1, $ver2) {
	$_ = "0:$_" unless /:/;
    }
    my @ver1 = split /[.:]/, $ver1;
    my @ver2 = split /[.:]/, $ver2;
    my $cmp = 0;
    ### Special thanks to Clemens Heidinger
    no warnings 'uninitialized';
    $cmp ||= $ver1[$_] <=> $ver2[$_] || $ver1[$_] cmp $ver2[$_] for 0..scalar(@ver2);
    return 'newer' if $cmp == 1;
    return 'older' if $cmp == -1;
    return 'equal';
}

sub loaded_scripts {
    my @modules;
    foreach (sort grep(s/::$//, keys %Irssi::Script::)) {
	push @modules, $_;
    }
    return \@modules;
}

sub check_scripts {
    my ($data) = @_;
    my %versions;
    foreach (@{loaded_scripts()}) {
	my ($sname) = get_names($_, $data);
	my $remote = get_remote_version($sname, $data);
	my $local = get_local_version($sname);
	my $state;
	if ($local && $remote) {
	    $state = compare_versions($local, $remote);
	} elsif ($local) {
	    $state = 'noversion';
	    $remote = '/';
	} else {
	    $state = 'noheader';
	    $local = '/';
	    $remote = '/';
	}
	if ($state) {
	    $versions{$sname}{state} = $state;
	    $versions{$sname}{remote} = $remote;
	    $versions{$sname}{local} = $local;
	}
    }
    return \%versions;
}

sub download_script {
    my ($script, $xml) = @_;
    my ($sname, $plname) = get_names($script, $xml);
    my %result;
    my $site = $xml->{$plname}{source};
    $result{installed} = 0;
    $result{signed} = 0;
    my $dir = Irssi::get_irssi_dir();
    my $file= get_file($site.'/scripts/'.$script.'.pl');
    if (!defined $file) {
	put_bg_error("Error: can't download the script '$script'");
    } else {
	my $size= length($file);
	my $sha= sha1_hex($file);
	if ($size != $remote_db{db}->{$plname}->{size}) {
	    put_bg_error("Error: script '$script' has not the same size (".
		$size." != ".$remote_db{db}->{$plname}->{size}.")");
	    $file= undef;
	}
	if ($sha ne $remote_db{db}->{$plname}->{sha}) {
	    put_bg_error("Error: script '$script' sha not correct");
	    $file= undef;
	}
    }
    if (defined $file) {
	mkdir $dir.'/scripts/' unless (-e $dir.'/scripts/');
	open(my $F, '>', $dir.'/scripts/'.$plname.'.new');
	print $F $file;
	close($F);
	$result{signed} = 0;
	$result{installed} = 1;
    }
    if ($result{installed}) {
	my $old_dir = "$dir/scripts/old/";
	mkdir $old_dir unless (-e $old_dir);
	rename "$dir/scripts/$plname", "$old_dir/$plname.old" if -e "$dir/scripts/$plname";
	rename "$dir/scripts/$plname.new", "$dir/scripts/$plname";
    }
    return \%result;
}

sub print_check {
    my (%data) = @_;
    my $text;
    my @table;
    foreach (sort keys %data) {
	my $state = $data{$_}{state};
	my $remote = $data{$_}{remote};
	my $local = $data{$_}{local};
	if (Irssi::settings_get_bool('scriptassist_check_verbose')) {
	    push @table, ['%go%n', '%9'.$_.'%9', 'Up to date. ('.$local.')'] if $state eq 'equal';
	}
	push @table, ['%mo%n', '%9'.$_.'%9', "No version information available on network."] if $state eq "noversion";
	push @table, ['%mo%n', '%9'.$_.'%9', 'No header in script.'] if $state eq "noheader";
	push @table, ['%bo%n', '%9'.$_.'%9', "Your version is newer (".$local."->".$remote.")"] if $state eq "newer";
	push @table, ['%ro%n', '%9'.$_.'%9', "A new version is available (".$local."->".$remote.")"] if $state eq "older";;
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'check', 1) ;
}

sub toggle_autorun {
    my ($script) = @_;
    my ($sname, $plname) = get_names($script);
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    mkdir $dir."autorun/" unless (-e $dir."autorun/");
    return unless (-e $dir.$plname);
    if (-e $dir."/autorun/".$plname) {
	if (readlink($dir."/autorun/".$plname) eq "../".$plname) {
	    if (unlink($dir."/autorun/".$plname)) {
		print CLIENTCRAP "%R>>%n Autorun of ".$sname." disabled";
	    } else {
		print CLIENTCRAP "%R>>%n Unable to delete link";
	    }
	} else {
	    print CLIENTCRAP "%R>>%n ".$dir."/autorun/".$plname." is not a correct link";
	}
    } else {
	if (symlink("../".$plname, $dir."/autorun/".$plname)) {
    	    print CLIENTCRAP "%R>>%n Autorun of ".$sname." enabled";
	} else {
	    print CLIENTCRAP "%R>>%n Unable to create autorun link";
	}
    }
}

sub sig_script_error {
    my ($script, $msg) = @_;
    return unless Irssi::settings_get_bool('scriptassist_catch_script_errors');
    if ($msg =~ /Can't locate (.*?)\.pm in \@INC \(\@INC contains:(.*?) at/) {
        my $module = $1;
        $module =~ s/\//::/g;
	missing_module($module);
    }
}

sub missing_module {
    my ($module) = @_;
    my $text;
    $text .= "The perl module %9".$module."%9 is missing on your system.\n";
    $text .= "Please ask your administrator about it.\n";
    $text .= "You can also check CPAN via '/scriptassist cpan ".$module."'.\n";
    print CLIENTCRAP &draw_box('ScriptAssist', $text, $module, 1);
}

sub cmd_scripassist {
    my ($arg, $server, $witem) = @_;
    my @args = split(/ /, $arg);
    if ($args[0] eq 'help') {
	show_help();
    } elsif ($args[0] eq 'check') {
	bg_do("check");
    } elsif ($args[0] eq 'update') {
	shift @args;
	bg_do("update ".join(' ', @args));
    } elsif ($args[0] eq 'search' && defined $args[1]) {
	shift @args;
	bg_do("search ".join(" ", @args));
    } elsif ($args[0] eq 'install' && defined $args[1]) {
	shift @args;
	bg_do("install ".join(' ', @args));
    } elsif ($args[0] eq 'contact' && defined $args[1]) {
	contact_author($args[1]);
    } elsif ($args[0] eq 'info' && defined $args[1]) {
	shift @args;
	bg_do("info ".join(' ', @args));
    } elsif ($args[0] eq 'cpan' && defined $args[1]) {
	call_openurl('http://search.cpan.org/search?mode=module&query='.$args[1]);
    } elsif ($args[0] eq 'autorun' && defined $args[1]) {
	toggle_autorun($args[1]);
    } elsif ($args[0] eq 'new') {
	my $number = defined $args[1] ? $args[1] : 5;
	bg_do("new ".$number);
    }
}

sub cmd_help {
    my ($arg, $server, $witem) = @_;
    $arg =~ s/\s+$//;
    if ($arg =~ /^scriptassist/i) {
	show_help();
    }
}

sub sig_command_script_load {
    my ($script, $server, $witem) = @_;
    my ($sname, $plname, $pname, $xname) = get_names($script);
    if ( exists $Irssi::Script::{$pname} ) {
	if (my $code = "Irssi::Script::${pname}"->can('pre_unload')) {
	    print CLIENTCRAP "%R>>%n Triggering pre_unload function of $script...";
	    $code->();
	}
    }
}

sub sig_default_command {
    my ($cmd, $server) = @_;
    return unless Irssi::settings_get_bool("scriptassist_check_unknown_commands");
    bg_do('unknown '.$cmd);
}

sub sig_complete {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.script(assist)? (install|update|check|contact|info|autorun)/i;
    my @newlist;
    my $str = $word;
    foreach (@complist) {
	if ($_ =~ /^(\Q$str\E.*)?$/) {
	    push @newlist, $_;
	}
    }
    foreach (@{loaded_scripts()}) {
	push @newlist, $_ if /^(\Q$str\E.*)?$/;
    }
    push @$list, $_ foreach @newlist;
    Irssi::signal_stop();
}

sub sig_setup_changed {
    $scriptassist_cache_sources=Irssi::settings_get_bool('scriptassist_cache_sources');
}

sub get_old_data {
    if ($scriptassist_cache_sources) {
	my $fn= Irssi::get_irssi_dir()."/scriptassist.yaml";
	if ( -e $fn ) {
	    my $yaml= CPAN::Meta::YAML->read($fn);
	    %old_data= %{$yaml->[0]};
	    $remote_db{db}=$old_data{db};
	    $remote_db{info}=$old_data{info};
	}
    }
}

sub write_old_data {
    if ($scriptassist_cache_sources) {
	my $fn= Irssi::get_irssi_dir()."/scriptassist.yaml";
	my $fh;
	delete $old_data{data};
	my $yaml = CPAN::Meta::YAML->new(\%old_data);
	#open( $fh, '> :utf8', $fn);
	#print $fh $yaml->write_string();
	#close( $fh );
	$yaml->write($fn);
    }
}

sub UNLOAD {
    write_old_data();
}

Irssi::theme_register([
	'error_msg', '{error << }{hilight $0}$1',
]);

Irssi::settings_add_str($IRSSI{name}, 'scriptassist_script_sources', 'https://scripts.irssi.org/scripts.dmp');
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_cache_sources', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_update_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_catch_script_errors', 1);

Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_integrate', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_unknown_commands', 1);

Irssi::signal_add_first("default command", 'sig_default_command');
Irssi::signal_add_first('complete word', 'sig_complete');
Irssi::signal_add_first('command script load', 'sig_command_script_load');
Irssi::signal_add_first('command script unload', 'sig_command_script_load');
Irssi::signal_add_first('setup changed', 'sig_setup_changed');

Irssi::signal_register({ 'script error' => [ 'Irssi::Script', 'string' ] });
Irssi::signal_add_last('script error', 'sig_script_error');

Irssi::command_bind('scriptassist', 'cmd_scripassist');
Irssi::command_bind('help', 'cmd_help');

Irssi::theme_register(['box_header', '%R,--[%n$*%R]%n',
'box_inside', '%R|%n $*',
'box_footer', '%R`--<%n$*%R>->%n',
]);

foreach my $cmd ( ( 'check',
		    'install',
		    'update',
		    'contact',
		    'search',
		    'help',
		    'info',
		    'cpan',
		    'autorun',
		    'new' ) ) {
    Irssi::command_bind('scriptassist '.$cmd => sub {
			cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    if (Irssi::settings_get_bool('scriptassist_integrate')) {
	Irssi::command_bind('script '.$cmd => sub {
    			    cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    }
}

sig_setup_changed();
get_old_data();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /scriptassist help for help';

# vim:set ts=8 sw=4:
