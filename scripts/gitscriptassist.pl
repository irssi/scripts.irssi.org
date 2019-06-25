use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use IPC::Open3;
use CPAN::Meta::YAML;
use Text::ParseWords;
use Text::Wrap;
use Time::HiRes;
use File::Glob qw/:bsd_glob/;

$VERSION = '0.1';
%IRSSI = (
    authors	=> 'bw1',
    contact	=> 'bw1@aol.at',
    name	=> 'gitscriptassist',
    description	=> 'script management with git',
    license	=> 'Public Domain',
    url		=> 'https://scripts.irssi.org/',
    changed	=> '2019-06-03',
    modules => 'IPC::Open3 CPAN::Meta::YAML Text::ParseWords '.
					'Text::Wrap Time::HiRes',
    commands=> "gitscriptassist"
);

my $help= << "END";
%9Name%9
  /gitscriptassist -  $IRSSI{description}

%9Version%9
  $VERSION

%9Description%9
  \$ mkdir ~/foo
  \$ cd ~/foo
  \$ git clone https://github.com/irssi/scripts.irssi.org.git
  \$ irssi
  [(status)] /script load ~/foo/scripts.irssi.org/scripts/gitscriptassist.pl
  [(status)] /set gitscriptassist_repo ~/foo/scripts.irssi.org
  [(status)] /gitscriptassist search script
  [(status)] /quit
  \$ echo "/script load ~/foo/scripts.irssi.org/scripts/gitscriptassist.pl" >> \
  > ~/.irssi/startup
  \$ irssi

%9Settings%9
  %Ugitscriptassist_repo%U
    path to the git workingdir
  %Ugitscriptassist_path%U
    path for the tempory files of /gitscriptassist
  %Ugitscriptassist_startup%U
    load the scripts on startup
  %Ugitscriptassist_integrate%U
    integrate in the script command

%9Commands%9
END

my %scmds=(
	'fetch'=>{
		'short'=>"git fetch -all",
	},
	'gitload'=>{
		'short'=>"load a script from the repository",
		'usage'=>"/gitscriptassist gitload {filename[.pl]|hash:filename[.pl]}",
		'file'=>1,
	},
	'info'=>{
		'short'=>"view script info",
		'usage'=>"/gitscriptassist info <filename[.pl]>",
		'file'=>1,
	},
	'log'=>{
		'short'=>"git log",
		'usage'=>"/gitscriptassist log [filename[.pl]]",
		'file'=>1,
	},
	'pull'=>{
		'short'=>"git pull",
	},
	'search'=>{
		'short'=>"search for word in scripts.yaml",
		'usage'=>"/gitscriptassist search <word>",
	},
	'status'=>{
		'short'=>"git status",
	},
	'help'=>{
		'short'=>"show help",
	},
	'autoload'=>{
		'short'=>"manage autoload",
		'usage'=>"/gitscriptassist autoload <command>",
		'sub' => {
			'list' => {
				'short'=>"show the list for startup",
			},
			'add' => {
				'short'=>"add a list entry for /script load",
				'file'=>1,
			},
			'gitadd' => {
				'short'=>"add a list entry for /script load via git",
				'file'=>1,
			},
			'write' => {
				'short'=>"write list to file",
			},
			'load' => {
				'short'=>"load the list from file",
			},
			'startup' => {
				'short'=>"trigger the startup",
			},
			'remove' => {
				'short'=>"remove a list entry",
			},
			'move' => {
				'short'=>"move a list entry",
			},
		},
	},
	'new'=>{
		'short'=>"show last modified scripts",
		'usage'=>"/gitscriptassist new [max]",
	},
);

my ($repo, $path, $startup, $integrate);

my $subproc;
my @nproc;

my %scripts;
my %time_scr;
my @comp_start;
my @autoload;

my ($fh_in, $fh_out, $fh_err);

sub load_autoload {
	my $fh;
	my $fn = $path.'/autoload.yaml';
	if (-e $fn) {
		open $fh, "<:utf8", $fn;
		my $yt = do { local $/; <$fh> };
		my $yml= CPAN::Meta::YAML->read_string($yt);
		if (defined $yml->[0]) {
			@autoload =@{$yml->[0]};
		}
		close $fh;
		if ($startup) {
			ascmd_startup();
		}
	}
}

sub write_autoload {
	my $fh;
	my $fn = $path.'/autoload.yaml';
	if (scalar(@autoload) >0) {
		open $fh, ">:utf8", $fn;
		my $yml =CPAN::Meta::YAML->new(\@autoload);
		print $fh $yml->write_string;
		close $fh;
	}
}

sub load_scripts {
	my $fh;
	my $f  =$repo.'/_data/scripts.yaml';
	my $fn = bsd_glob $f, GLOB_TILDE;
	if (-e $fn) {
		open $fh, "<:utf8", $fn;
		my $yt = do { local $/; <$fh> };
		my $yml= CPAN::Meta::YAML->read_string($yt);
		my @l =@{$yml->[0]};
		foreach my $s (@l) {
			$scripts{$s->{filename}}=$s;
		}
		foreach my $s (@l) {
			if (!exists $time_scr{$s->{modified}}) {
				$time_scr{$s->{modified}} =[];
			}
			push @{$time_scr{$s->{modified}}}, $s;
		}
		close $fh;
	}
}

sub run {
	my (%arg) =@_;
	if (!defined $subproc) {
		$subproc={%arg};
		use Symbol 'gensym'; $fh_err = gensym;
		my $pid = open3 ($fh_in, $fh_out, $fh_err, $subproc->{cmd});
		if (defined $pid) {
			$subproc->{pid}=$pid;
			Irssi::pidwait_add($pid);
		}
	} else {
		push @nproc, {%arg}
	}
}

sub sig_run_end {
	my ($pid, $status) = @_;

	if (defined $subproc) {
		my $old = select $fh_out;
		local $/;
		$subproc->{out} = <$fh_out>;
		$subproc->{out} =~ s/\n$//;
		select $old;

		select $fh_err;
		local $/;
		$subproc->{err} = <$fh_err>;
		$subproc->{err} =~ s/\n$//;
		select $old;

		if (exists $subproc->{next}) {
			if (ref ($subproc->{next}) eq 'CODE') {
				&{$subproc->{next}}();
			} elsif (ref ($subproc->{next}) eq 'ARRAY') {
				foreach my $p (@{$subproc->{next}}) {
					if (ref ($p) eq 'CODE') {
						&{$p}();
					}
				}
			}
		}
		$subproc = undef;
		if (scalar(@nproc) >0 ){
			my %arg = %{shift @nproc};
			run(%arg);
		}
	}
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
    return $box;
}

sub print_msg {
	my ( @te );
	if ($subproc->{out} ne '') {
		push @te, $subproc->{out};
	}
	if ($subproc->{err} ne '') {
		push @te,'E:'.$subproc->{cmd};
		push @te,'E:'.$subproc->{err};
	}
	if (defined $subproc->{label} &&
			($subproc->{out} ne '' ||
				$subproc->{err} ne '' )) {
		Irssi::print(
			draw_box($IRSSI{name}, join( "\n",@te) ,$subproc->{label}, 1),
				, MSGLEVEL_CLIENTCRAP);
	}
}

sub next_gitload {
	if ($subproc->{err} eq '') {
		Irssi::command("script load $path/$subproc->{filename}");
	}
}

sub scmd_script_info {
	my ($server, $witem, @args) =@_;
	my @te;
	my $s = $scripts{$args[0]};
	if (!defined $s) {
		$s = $scripts{$args[0].'.pl'};
	}
	if (defined $s) {
		push @te, "name:        $s->{name}";
		push @te, "authors:     $s->{authors}";
		push @te, "description:";
		my $d;
		{
			local $Text::Wrap::columns = 60;
			local $Text::Wrap::unexpand= 0;
			$d =wrap('   ','   ',$s->{description});
		}
		push @te, $d;
		push @te, "filename:    $s->{filename}";
		push @te, "version:     $s->{version}";
		Irssi::print(
			draw_box($IRSSI{name}, join( "\n",@te) ,'info' , 1),
				, MSGLEVEL_CLIENTCRAP);
	}
}

sub scmd_script_search {
	my ($server, $witem, @args) =@_;
	my @te;
	my @scrs;
	my $ml=0;
	my $w=$args[0];
	foreach my $fn (sort keys %scripts) {
		my $s=$scripts{$fn};
		if (
				$s->{name} =~ m/$w/i ||
				$s->{authors} =~ m/$w/i ||
				$s->{description} =~ m/$w/i ||
				$s->{filename} =~ m/$w/i ) {
			push @scrs, $s;
			my $l=length($s->{filename});
			$ml=$l if ( $ml < $l);
		}
	}

	foreach my $s (@scrs) {
		my $i = sprintf "%-*s ", $ml, $s->{filename};
		my $dt=$s->{description};
		$dt=~ s/\n/ /g;
		$dt=~ s/\s+/ /g;
		my $d;
		{
			local $Text::Wrap::columns = 60;
			local $Text::Wrap::unexpand= 0;
			$d =wrap($i, ' 'x($ml+1), $dt);
		}
		push @te, $d;
	}
	Irssi::print(
		draw_box($IRSSI{name}, join( "\n",@te) ,'search' , 1),
			, MSGLEVEL_CLIENTCRAP);
}

sub scmd_gitload {
	my ($server, $witem, @args) =@_;
	my ($po, $fn);
	if ($args[0] =~ m/^(.*):(.*)$/) {
		$po=$1;
		$fn=$2;
	} else {
		$po='master';
		$fn=$args[0];
	}
	$fn .= '.pl' if ($fn !~ m/\.pl$/);
	run(
		'cmd' => "git -C $repo show $po:scripts/$fn >$path/$fn",
		'label'=> 'gitload',
		'filename'=>$fn,
		'point'=>$po,
		'next' => [\&next_gitload,\&print_msg]);
}

sub scmd_help {
	my ($server, $witem, @args) =@_;
	my @te;
	if (scalar(@args) ==0 ) {
		chomp $help;
		push @te, $help;
		foreach my $c (sort keys %scmds) {
			if (exists $scmds{$c}->{short}) {
				push @te, sprintf("  %%9%-10s%%9 %s", $c, $scmds{$c}->{short});
			}
			if (scalar(keys %{$scmds{$c}->{sub}}) ) {
				push @te, '    '.join ' ',sort keys %{$scmds{$c}->{sub}};
			}
		}
		Irssi::print(
			draw_box($IRSSI{name}, join( "\n",@te) ,'help' , 1),
				, MSGLEVEL_CLIENTCRAP);
	} elsif ( exists $scmds{$args[0]} ) {
		my $sa = $args[0];
		push @te, "%9/$IRSSI{name} $sa%9";
		if (exists $scmds{$sa}->{short}) {
			push @te, "  $scmds{$sa}->{short}";
		}
		if (exists $scmds{$sa}->{usage}) {
			push @te, "%9Usage:%9";
			push @te, "  $scmds{$sa}->{usage}";
		}
		if (scalar(keys %{$scmds{$sa}->{sub}}) >0) {
			push @te, "%9Commands:%9";
			foreach my $su (sort keys %{$scmds{$sa}->{sub}}) {
				if (exists $scmds{$sa}->{sub}->{$su}->{short}) {
					push @te, sprintf("  %-10s %s", $su, $scmds{$sa}->{sub}->{$su}->{short});
				}
			}
		}
		Irssi::print(
			draw_box($IRSSI{name}, join( "\n",@te) ,'help' , 1),
				, MSGLEVEL_CLIENTCRAP);
	}
}

sub ascmd_startup {
	my ($server, $witem, @args) =@_;
	foreach my $s (@autoload) {
		if (exists $s->{load}) {
			Irssi::command("script load $s->{load}");
		} elsif (exists $s->{gitload}) {
			scmd_gitload($server, $witem, $s->{gitload});
		}
	}
}

sub ascmd_list {
	my ($server, $witem, @args) =@_;
	my @te;
	my $co=0;
	foreach (@autoload){
		my ($k, $f);
		($k) = keys %$_;
		$f   = $_->{$k};
		push @te,sprintf("%4d %-10s %s", $co, $k, $f);
		$co++;
	}
	Irssi::print(
		draw_box($IRSSI{name}, join( "\n",@te) ,'autoload list' , 1),
			, MSGLEVEL_CLIENTCRAP);
}

sub scmd_autoload {
	my ($server, $witem, @args) =@_;
	my $c = shift @args;
	if ($c eq 'list') {
		ascmd_list($server, $witem, @args);
	} elsif ( $c eq 'add') {
		push @autoload, { load=>$args[0]};
	} elsif ( $c eq 'gitadd') {
		push @autoload, { gitload=>$args[0]};
	} elsif ( $c eq 'remove') {
		splice @autoload,$args[0],1;
	} elsif ( $c eq 'move') {
		my $b =splice @autoload,$args[0],1;
		my @ab =splice @autoload,$args[1];
		push @autoload, $b;
		push @autoload, @ab;
	} elsif ( $c eq 'write') {
		write_autoload();
	} elsif ( $c eq 'load') {
		load_autoload();
	} elsif ( $c eq 'startup') {
		ascmd_startup($server, $witem, @args);
	}
}

sub scmd_new {
	my ($server, $witem, @args) =@_;
	my @te;
	my $co=1;
	my $max=5;
	if (defined $args[0]) {
		$max= $args[0];
	}
	foreach my $t (sort { $b cmp $a } keys %time_scr) {
		foreach my $s ( @{$time_scr{$t}}) {
			push @te,"$t  $s->{filename}";
			$co++;
		}
		last if ($co > $max);
	}
	Irssi::print(
		draw_box($IRSSI{name}, join( "\n",@te) ,'new' , 1),
			, MSGLEVEL_CLIENTCRAP);
}

sub cmd {
	my ($args, $server, $witem)=@_;
	my @args = grep { $_ ne ''}  quotewords('\s+', 0, $args);
	my $c =shift @args;

	if ($c eq 'gitload') {
		scmd_gitload($server, $witem, @args);

	} elsif ($c eq 'status') {
		run(
			'cmd' => "git -C $repo status -sbuno",
			'label'=> 'status',
			'next' => \&print_msg);

	} elsif ($c eq 'pull') {
		run(
			'cmd' => "git -C $repo pull",
			'label'=> 'pull',
			'next' => \&print_msg);

	} elsif ($c eq 'fetch') {
		run(
			'cmd' => "git -C $repo fetch --all",
			'label'=> 'fetch',
			'next' => \&print_msg);

	} elsif ($c eq 'log') {
		my $s;
		if (defined $args[0]) {
			$s = "scripts/$args[0]";
			if ($s !~ m/\.pl$/) {
				$s .=".pl";
			}
		}
		run(
			'cmd' => "git -C $repo log master -n 10 ".
							"--invert-grep --grep='automatic scripts database update' ".
							"--no-decorate --no-merges ".
							"--date=short ".
							"--pretty='format:%cd %h %s' ".
							"$s",
			'label'=> 'log',
			'next' => \&print_msg);

	} elsif ($c eq 'info') {
		scmd_script_info($server, $witem, @args);

	} elsif ($c eq 'search') {
		scmd_script_search($server, $witem, @args);

	} elsif ($c eq 'help') {
		scmd_help($server, $witem, @args);

	} elsif ($c eq 'new') {
		scmd_new($server, $witem, @args);

	} elsif ($c eq 'autoload') {
		scmd_autoload($server, $witem, @args);
	}
}

sub sig_setup_changed {
	my $r = Irssi::settings_get_str('gitscriptassist_repo');
	if ($r ne $repo ) {
		$r =~ s#/$##;
		$repo= $r;
		%scripts=();
		load_scripts();
	}
	my $p = Irssi::settings_get_str('gitscriptassist_path');
	$p =~ s#/$##;
	if ($p !~ m#^[~/]#) {
		$path = Irssi::get_irssi_dir().'/'.$p;
	}
	if (! -e $path ) {
		Irssi::print('gitscriptassist: make working dir "'.$path.'"', MSGLEVEL_CLIENTCRAP);
		mkdir $path;
	}
	$startup  = Irssi::settings_get_bool('gitscriptassist_startup');
	my $bi= Irssi::settings_get_bool('gitscriptassist_integrate');
	if ($bi==1 && $integrate != $bi) {
		$integrate=$bi;
		bind_cmd('script');
	}
}

sub do_complete {
	my ($strings, $window, $word, $linestart, $want_space) = @_;
	my $ok;
	foreach (@comp_start) {
		$ok=1 if ($linestart =~ m/^$_/);
	}
	return unless $ok;

	if ($word =~ m/^(.*:)/) {
		@$strings = grep { m/^$word/} map {$1.$_} keys %scripts;
	} else {
		@$strings = grep { m/^$word/} keys %scripts;
	}
	$$want_space = 1;
	Irssi::signal_stop;
}

sub bind_cmd {
	my ($cm)=@_;
	Irssi::command_bind($cm ,\&cmd);
	foreach my $c (keys %scmds) {
		Irssi::command_bind($cm .' '.$c,\&cmd);
		foreach my $s (keys %{$scmds{$c}->{sub}}) {
			Irssi::command_bind($cm .' '.$c.' '.$s,\&cmd);
		}
	}
	foreach my $sc (keys %scmds) {
		if (exists $scmds{$sc}->{file}) {
			push @comp_start, "/$cm $sc";
		}
		foreach my $s (keys %{$scmds{$sc}->{sub}}) {
			if (exists $scmds{$sc}->{sub}->{$s}->{file}) {
				push @comp_start, "/$cm $sc $s";
			}
		}
	}
}

sub UNLOAD {
	write_autoload();
}

Irssi::command_bind('help', sub {
		my @args = grep { $_ ne '' } quotewords('\s+', 0, $_[0]);
		my $s = shift @args;
		if ($s eq $IRSSI{name} ) {
			scmd_help(undef, undef, @args);
			Irssi::signal_stop;
		}
	}
);


Irssi::signal_add_first('complete word',  \&do_complete);
Irssi::signal_add('pidwait', 'sig_run_end');
Irssi::signal_add('setup changed', 'sig_setup_changed');

Irssi::settings_add_str($IRSSI{name}, 'gitscriptassist_repo', '~/foo/script-irssi');
Irssi::settings_add_str($IRSSI{name}, 'gitscriptassist_path', 'gitscriptassist');
Irssi::settings_add_bool($IRSSI{name}, 'gitscriptassist_startup', 0);
Irssi::settings_add_bool($IRSSI{name}, 'gitscriptassist_integrate', 0);

bind_cmd($IRSSI{name});

sig_setup_changed();
load_autoload();

