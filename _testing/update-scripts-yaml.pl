use strict; use warnings;
use YAML::Tiny 1.59;

my $config = YAML::Tiny::LoadFile('_testing/config.yml');
my @yaml_keys;
if ($config) {
    @yaml_keys = @{ $config->{scripts_yaml_keys}//[] };
}
die "no keys defined in config.yaml\n" unless @yaml_keys;

my @docs;
{ open my $ef, '<:utf8', '_data/scripts.yaml' or die $!;
  @docs = Load(do { local $/; <$ef> });
}

my %oldmeta;
for (@{$docs[0]//[]}) {
    $oldmeta{$_->{filename}} = $_;
}

my %newmeta;
for my $file (<scripts/*.pl>) {
    my ($filename, $base) =
	$file =~ m,^scripts/((.*)\.pl)$,;
    my $info_file = "Test/$base/info.yml";
    my @cdoc;
    if (-f $info_file && open my $ef, '<:utf8', $info_file) {
	local $@;
	@cdoc = eval { Load(do { local $/; <$ef> }); };
	if ($@) {
	    print "ERROR $base: $@\n";
	    @cdoc=();
	}
    }
    if (@cdoc) {
	$newmeta{$filename} = $cdoc[0][0];
	for my $copykey (qw(modified version)) {
	    unless (defined $newmeta{$filename}{$copykey}) {
		$newmeta{$filename}{$copykey}
		    = $oldmeta{$filename}{$copykey}
			if defined $oldmeta{$filename}{$copykey};
	    }
	}
	$newmeta{$filename}{filename} = $filename;
	my $modules = delete $newmeta{$filename}{modules};
	$newmeta{$filename}{modules}
	    = join ' ', @$modules
		if 'ARRAY' eq ref $modules;
	my $commands = delete $newmeta{$filename}{commands};
	my @commands = grep { !/ / } @$commands
		if 'ARRAY' eq ref $commands;
	$newmeta{$filename}{commands} = "@commands"
	    if @commands;
    }
    elsif (exists $oldmeta{$filename}) {
	print "META-INF FOR $base NOT FOUND\n";
	system "ls 'Test/$base/'*";
	$newmeta{$filename} = $oldmeta{$filename};
    }
    else {
	print "MISSING META FOR $base\n";
    }
}
my @newdoc = map {
    my $v = $newmeta{$_};
    +{
        map {
            exists $v->{$_}
                ? ($_ => $v->{$_})
                : ()
        } sort @yaml_keys
    }
} sort keys %newmeta;
YAML::Tiny::DumpFile('_data/scripts.yaml', \@newdoc);

if ($config && @{$config->{whitelist}//[]}) {
    my $changed;
    my @wl;
    for my $sf (@{$config->{whitelist}}) {
	if (-s "Test/$sf:passed") {
	    $changed = 1;
	}
	else {
	    push @wl, $sf;
	}
    }
    if ($changed) {
	$config->{whitelist} = \@wl;
	YAML::Tiny::DumpFile('_testing/config.yml', $config);
    }
}
