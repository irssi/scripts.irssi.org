#!/usr/bin/perl
#
#  ein paar versuche
#

#use strict;
use YAML qw/LoadFile DumpFile/;

my $script_path="scripts/";
my @key_list= 
	qw/authors contact description filename changed license name version/;

# 0	Normal
# 1 Verbose
# 2 File
my $debug=1;

my @hl;

if ($debug<2) {
	opendir di,$script_path;
	my @li  = readdir di;
	closedir di;

	@li = grep {m/\.pl$/} @li;

	foreach (@li) {
		my %h;
		%h=read_file($_);
		push @hl,\%h;
	}
} else { 
	#read_file("loadedrot13.pl");
	#read_file("frm_outgmsgs.pl");
	#read_file("file.pl");
	#read_file("email_privmsgs.pl");
	#read_file("shorturl.pl");
	#read_file("doc.pl");
	#read_file("uptime.pl");
	#read_file("trackbar.pl");
	#read_file("opnotice.pl");
	#read_file("gsi.pl");
	read_file("keepnick.pl");

}

#sort
my %fl;
for(my $c=0;$c <= $#hl; $c++) {
	$fl{$hl[$c]->{filename}}=$c;
}

my @hln;
foreach (sort keys %fl) {
	push @hln,$hl[$fl{$_}];
}


DumpFile("_data/new_scripts.yml",\@hln);

#-----------------

sub read_file($) {
	(my $filename) =@_;
	my $fi;
	open $fi,$script_path.$filename;
	my $sc='';
	my $l=0;

	while (my $z = <$fi>){
		#chomp $z;
		if ($l) {
			$sc .= $z;
		}
		if ($z =~ m/^\s*\$VERSION/ ||
				$z =~ m/^\s*\(\$VERSION/ ||
				$z =~ m/^\s*our\s*\$VERSION/) {
			$sc .= $z;
			$l =1;
		}
		if ($z =~ m/^\s*%IRSSI/ ||
				$z =~ m/^\s*our\s*%IRSSI/) {
			$sc .= $z;
			$l =1;
		}

		if ($z =~ m/;/) {
			if ($z !~ m/".*;.*"/ && $z !~ m/'.*;.*'/) {
				$l =0;
			}
		}
	}
	close $fi;

	$sc .= '$IRSSI{version}=$VERSION;'."\n";
	$sc .= 'return %IRSSI;'."\n";

	if ($debug>1) {
		print $sc;
	}

	my %IRSSI=();

	my %h= eval( $sc);

	$h{filename}=$filename;

	my $ee=$@;

	if ($debug>1) {
		foreach (keys %h) {
			print "$_ =>\t",$h{$_},"\n"
		}
		print "-------\n";
	}
	
	#check
	my $co=0;
	foreach (@key_list) {
		if ( exists $h{$_}) {
			$co++;
		} else {
			if ($debug>0) {
				print "missing field: $_ \n";
			}
		}
	}

	#output
	print $filename;
	print " "x(30-length($filename));
	if ($co == $#key_list+1) {
		print "Ok  ";
	} else {
		print "Fail";
	}
	print "\n";
	print "$ee";

	# modified <= changed
	if (exists $h{changed}) {
		$h{modified}=$h{changed};
		delete $h{changed};
	}

	return %h;
}


