# Save window layout to an arbitrary file and load layouts upon demand
# Useful for being able to temporarily reorder your windows and then reverting to your "normal" layout
# Also useful as an easy way to reorder your windows
#
# A special thanks to billnye, Zed` and Bazerka for their help
#
# Usage:
#  /layout_save filename
#    Saves the layout to the textfile "filename.layout"
#  /layout_load filename
#    Loads the layout from the textfile "filename.layout"
#  /set layout_savepath path
#    Use to set a default path for layouts
#
# TODO:
#   Check the layout file for a number used twice
#

use strict;
use Irssi;
use Data::Dumper;
use vars qw($VERSION %IRSSI);

%IRSSI = (
	authors     => "Isaac G",
	contact     => "irssi\@isaac.otherinbox.com",
	name        => "reorder",
	description => "Reordering windows based on a textfile.",
	license     => "GPL",
);

sub doFilenameFixing
{
	my ($filename) = @_;
	unless ($filename)
	{
		print "No filename specified!";
		return;
	}

	$filename = glob($filename);

	if ($filename =~ /\//)
	{
		unless ($filename =~ /^\//)
		{
			print "I don't like /'s in filenames. Unless you want to specify an absolute path.";
			return;
		}
		# Let it go?
	}

	$filename .= '.layout' unless ($filename =~ /.layout$/);

	my $path = Irssi::settings_get_str('layout_savepath');
	$path .= '/' unless ($path =~ /\/$/);
	$filename = $path . $filename unless ($filename =~ /\//);

	return $filename;
}

sub canReadFile
{
	my ($filename) = @_;
	unless (-f $filename)
	{
		print "No such file $filename";
		return;
	}
	unless (-r $filename)
	{
		print "Can not read file $filename";
		return;
	}
	return 1;
}

# Save a list of refnum and window info to file
sub cmd_layout_save
{
	my ($filename, $data, $more) = @_;
	my $FH;

	$filename = doFilenameFixing($filename);
	return unless ($filename);

	unless(open $FH, ">", $filename)
	{
		print "Can not open $filename";
		return;
	}

	# Order by ref. Print ref and an id tag
	for my $win (sort {$a->{'refnum'} <=> $b->{'refnum'}} Irssi::windows())
	{
		my $id = $win->{'name'} ? $win->{'name'} : $win->{'active'}->{'name'} . ":" . $win->{'active'}->{'server'}->{'tag'};
		printf $FH "%d\t%s\n", $win->{'refnum'}, $id;
	}
	close $FH;
	print "Layout saved to $filename";
}

# Load a list and use it to reorder
sub cmd_layout_load
{
	# Check filename supplied, exists and readable
	my ($filename, $data, $more) = @_;
	$filename = doFilenameFixing($filename);
	return unless ($filename);

	return unless canReadFile($filename);

	my @layout;
	my ($ref, $id, $FH);

	# Pull the refnum and id
	unless(open $FH, "<", $filename)
	{
		print "Can not open file $filename.";
		return;
	}
	while (my $line = <$FH>)
	{
		chomp $line;
		my ($ref, $id) = split(/\t/, $line, 2);
		next unless ($ref and $id);

		push @layout, {refnum => $ref, id => $id};
	}
	close $FH;

	# For each layout item from the file, find the window and set it's ref to that number
	for my $position (sort {$a->{'refnum'} <=> $b->{'refnum'}} @layout)
	{
		for my $win (Irssi::windows())
		{
			$id = $win->{'name'} ? $win->{'name'} : $win->{'active'}->{'name'} . ":" . $win->{'active'}->{'server'}->{'tag'};
			if ($id eq $position->{'id'})
			{
				$win->set_refnum($position->{'refnum'});
				last;
			}
		}
	}
}

Irssi::settings_add_str('misc', 'layout_savepath', Irssi::get_irssi_dir());

Irssi::command_bind( 'layout_save', 'cmd_layout_save' );
Irssi::command_bind( 'layout_load', 'cmd_layout_load' );