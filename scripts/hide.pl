use strict;
use vars  qw ($VERSION %IRSSI);
use Irssi qw (settings_add_str settings_get_str settings_set_str command_bind command_runsub signal_emit );

$VERSION = '0.0.7';
%IRSSI = (
    authors     => 'Marcus Rueckert',
    contact     => 'darix@irssi.de',
    name        => 'hide tools',
    description => 'a little interface to irssi\'s activity_hide_* settings',
    license     => 'Public Domain',
    url         => 'http://scripts.irssi.de/',
    changed     => '2002-07-21 06:53:21+0200'
);


#
# functions
#

sub add_item {
    my ($target_type, $data) = @_;
    my $target = target_check ($target_type);
    return 0 unless $target;
    if ($data =~ /^\s*$/ ) {
        print (CRAP "\cBNo target specified!\cB");
        print (CRAP "\cBUsage:\cB hide $target_type add [$target_type]+");
    }
    else {
        my $set = settings_get_str($target);
        for my $item ( split (/\s+/, $data) ) {
            if ($set =~ m/^\Q$item\E$/i) {
                print (CRAP "\cBWarning:\cB $item is already in in $target_type hide list.")
            }
            else {
                print (CRAP "$item added to $target_type hide list.");
                $set = join (' ', $set, $item);
            }
        };
        settings_set_str ($target, $set);
        signal_emit('setup changed');
    }
    return 1;
}

sub remove_item {
    my ($target_type, $data) = @_;
    my $target = target_check ($target_type);
    if ( not ( $target )) { return 0 };
    if ($data =~ /^\s*$/ ) {
        print (CRAP "\cBNo target specified!\cB");
        print (CRAP "\cBUsage:\cB hide $target_type remove [$target_type]+");
    }
    else {
        my $set = settings_get_str($target);
        for my $item ( split (/\s+/, $data) ) {
            if ($set =~ s/$item//i) {
                print (CRAP "$item removed from $target_type hide list.")
            }
            else {
                print (CRAP "\cBWarning:\cB $item was not in $target_type hide list.")
            }
        };
        settings_set_str ($target, $set);
        signal_emit('setup changed');
    }
    return 1;
}

sub target_check {
    my ($target_type) = @_;
    my $target = '';
    if ($target_type eq 'level') {
        $target = 'activity_hide_level';
    }
    elsif ($target_type eq 'target') {
        $target = 'activity_hide_targets';
    }
    else {
        print (CLIENTERROR "\cBadd_item: no such target_type $target_type\cB");
    }
    return $target;
}

sub print_usage {
    print (CRAP "\cBUsage:\cB");
    print (CRAP "  hide target [add|remove] [targets]+");
    print (CRAP "  hide level [add|remove] [levels]+");
    print (CRAP "  hide usage");
    print (CRAP "  hide print");
    print (CRAP "See also: levels");
};

sub print_items {
    my ($target_type) = @_;
    my $delimiter = settings_get_str('hide_print_delimiter');
    my $target = target_check ($target_type);
    if ( not ( $target )) { return 0 };
    print ( CRAP "\cB$target_type hide list:\cB$delimiter", join ( $delimiter, sort ( split ( " ", settings_get_str($target) ) ) ) );
    return 1;
}

#
# targets
#

command_bind 'hide target' => sub {
    my ($data, $server, $item) = @_;
    if ($data =~ m/^[(add)|(remove)]/i ) {
        command_runsub ('hide target', $data, $server, $item);
    }
    else {
        print (CRAP "\cBUsage:\cB hide target [add|remove] [targets]+");
    }
};

command_bind 'hide target add' => sub {
    my ($data, $server, $item) = @_;
    add_item ('target', $data);
};

command_bind 'hide target remove' => sub {
    my ($data, $server, $item) = @_;
    remove_item ('target', $data);
};

#
# levels
#
command_bind 'hide level' => sub {
    my ($data, $server, $item) = @_;
    if ($data =~ m/^[(add)|(remove)]/i ) {
        command_runsub ('hide level', $data, $server, $item);
    }
    else {
        print (CRAP "\cBUsage:\cB hide level [add|remove] [levels]+");
        print (CRAP "See also: levels");
    }
};

command_bind 'hide level add' => sub {
    my ($data, $server, $item) = @_;
    add_item ('level', $data);
};

command_bind 'hide level remove' => sub {
    my ($data, $server, $item) = @_;
    remove_item ('level', $data);
};

#
# general
#

command_bind 'hide' => sub {
    my ($data, $server, $item) = @_;
    if ($data =~ m/^[(target)|(level)|(help)|(usage)|(print)]/i ) {
        command_runsub ('hide', $data, $server, $item);
    }
    else {
        print_usage();
    }
};

command_bind 'hide print' => sub {
    print_items ('level');
    print_items ('target');
};

command_bind  'hide usage' => sub {  print_usage (); };
command_bind  'hide help' => sub {  print_usage (); };

#
# settings
#

settings_add_str ( 'script', 'hide_print_delimiter',  "\n - ");
