use strict;
use Irssi 20011210.0000 ();
use Storable;

use vars qw/$VERSION %IRSSI/;

$VERSION = "1.13";
%IRSSI = (
    authors     => 'David Leadbeater',
    contact     => 'dgl@dgl.cx',
    name        => 'on.pl',
    description => '/on command - this is very simple and not really designed to be the same as ircII - it tries to fit into Irssi\'s usage style more than emulating ircII.',
    license     => 'GNU GPLv2 or later',
    url         => 'http://irssi.dgl.cx/',
);

my %on;

=head1 on.pl

/on command - this is very simple and not really designed to 
be the same as ircII - it tries to fit into Irssi's usage style 
more than emulating ircII.

=head1 Features

This script allow you to bind Irssi commands or a piece of perl 
code to s particular signal with some forms of filtering.

A command can be set to run in a particular channel (nearly) 
and on a particular chatnet. The commands that you add are 
automatically saved into a file (usually ~/.irssi/on.save).


=head1 Usage

 /on list
 /on add [-global] [-perl] [-server] [-channel #channel]  [-stop] 'signal name' command
 /on remove signal name
 /on reload

=head2 ON ADD

 -global: run the command with Irssi::command
 -perl: Interpret command as perl instead of the default Irssi
 -server: Only trigger for events from this chat network
 -channel #channel: only trigger for events in #channel 
   (only works where $channel->{name} is present (message signals mostly)
 -stop: Call Irssi::signal_stop() (probably not a good idea to use this)

If you supply a signal name then it must be quoted so it is 
interpeted as one, if you wish to bind to a numeric then just 
entering it will work.

Currently if you specify a Irssi command $0 and $$0 are escaped, 
$0 $1 and so on are the parameters sent to the signal (except the first 
REC), $$0 and so on are the results of spliting $0 on a space so if 
the signal is an event then $$0 will usually be your nickname, $$1 
will be the channel or nickname the numeric is targeting and so on..

=head2 ON REMOVE

This removes *all* events from the signal specified (if you 
want to remove a numeric you must add event eg: 
 /on remove event 401

=head2 ON RELOAD 

Reloads the saved list from ~/.irssi/on.save into memory, 
useful if you have to edit it manually (and very useful during debugging :)
(perl -MStorable -MData::Dumper -e "print Dumper(retrieve('on.save'));")

=head1 Examples

These are pretty generic examples, there are many more 
specific uses for the commands.

To automatically run a /whowas when the no such nick/channel 
event is recieved:	
 /on add 401 /whowas $$0

To automatically run a command when you become an irc operator 
on this chatnet:
 /on add -server 381 /whatever

To automatically move to a window with activtiy in it on a hilight:
 /on add -global 'window hilight' /window goto active

Obviously perl commands could be used here or many different 
signals (see docs/signals.text in the irssi sources for a list 
of all the signals)

=head2 more test items

 /on add -perl 'channel topic changed' print "topic changed";
 /on add -channel #test 'channel topic changed' /echo topic changed
 /on add -stop 332 /echo event 332

=cut

Irssi::command_bind('on','cmd_on');
Irssi::command_bind('on add','cmd_on');
Irssi::command_bind('on remove','cmd_on');
Irssi::command_bind('on reload','cmd_on');
Irssi::command_bind('on list','cmd_on');
# This makes tab completion work :)
Irssi::command_set_options('on','global stop server perl +channel');
load();
add_signals();

# Loads the saved on settings from the saved file
sub load {
   my $file = Irssi::get_irssi_dir . '/on.save';
   return 0 unless -f $file;
   %on = %{retrieve($file)};
}

# Saves the settings currently in the %on hash into the save file
sub save {
   my $file = Irssi::get_irssi_dir . '/on.save';
   store(\%on, $file);
}

# Adds signals from the hash to irssi (only needs to be called once)
sub add_signals {
   for(keys %on) {
      Irssi::signal_add($_, 'signal_handler');
   }
}

# Irssi calls this and it figures out what to do with the event
sub signal_handler {
   my($item, @stuff) = @_;
   my $signal = Irssi::signal_get_emitted();


   if(exists $on{$signal}) {
      for(@{$on{$signal}}) {
		 next if $_->{chatnet} ne 'all' and $_->{chatnet} ne $item->{chatnet};
		 next if $_->{channel} and $item->{name} ne $_->{channel};
	     event_handle(@$_{'settings','cmd'},$item,@stuff);
	  }
   }else{
      Irssi::signal_remove($signal,'signal_handler');
   }
}

# Called with the params needed to handle an event from signal_handler
sub event_handle {
   my($settings,$cmd,$item,@stuff) = @_;
   my %settings = %{$settings};

   if($settings{type} == 1) {
	  local @_;
	  @_ = ($item,@stuff);
      eval('no strict;' . $cmd);
   }else{
	  $cmd =~ s!\$\$(\d)!(split / /,$stuff[0])[$1]!ge;
	  $cmd =~ s/\$(\d)/$stuff[$1]/g;
      if (defined $settings{global}) {
         Irssi::command($cmd);
      } else {
         $item->command($cmd);
      }
   }

   Irssi::signal_stop() if $settings{stop};
}

# Called by the /on command
sub cmd_on {
   my $text = shift;
   
   if($text =~ s/^add //) {
      my($cmd,%options) = option_parse($text);
	  if(!$options{event} || !$cmd) {
		 Irssi::print('No '.($cmd ? 'command' : 'event'). ' supplied');
	  }else{
	      my($chatnet,%settings,$channel,$event);
		  $chatnet = ($options{server} ? Irssi::active_server()->{chatnet} : 'all');
		  $event = $options{event};
		  $channel = $options{channel};
		  $settings{type} = $options{perl};
		  $settings{stop} = $options{stop};
		  $settings{global} = $options{global};
	      add_on($event,$cmd,$chatnet,$channel,%settings);
		  save();
	  }
   }elsif($text =~ s/^remove //) {
      if(del_on($text)) {
		 Irssi::print("Event $text deleted",MSGLEVEL_CLIENTCRAP);
	  }else{
		 Irssi::print("Event not found",MSGLEVEL_CLIENTCRAP);
	  }
	  save();
   }elsif($text =~ /^reload/) {
	  %on = ();
	  load();
   }elsif($text eq "help") {
	  Irssi::print( <<EOF
Usage:
/on list
/on add [-global] [-perl] [-server] [-channel #channel] [-stop] 'signal name' command
/on remove signal name
/on reload
EOF
   );
   }else{
	 Irssi::print("/on help for usage information");
     on_list();
   }
}

# Output a list of the current contents of %on
sub on_list {
   if(!keys %on) {
	  Irssi::print("On list is empty", MSGLEVEL_CLIENTCRAP);
	  return;
   }
   for my $event(keys %on) {
	   for(@{$on{$event}}) {
		  Irssi::print("$event: " . 
		      ($_->{chatnet} ne 'all' ? $_->{chatnet} : '') .
		      ' ' . $_->{cmd},
			  MSGLEVEL_CLIENTCRAP
		  );
       }
    }
}

# Adds into %on and adds a signal if needed.
sub add_on {
   my($event,$cmd,$chatnet,$channel,%settings) = @_;
   
   Irssi::signal_add($event, 'signal_handler') unless $on{$event};
   
   push(@{$on{$event}},
	  {
	     'chatnet' => $chatnet || 'all',
	     'settings' => {%settings},
		 'channel' => $channel,
	     'cmd' => $cmd,
	  }
   );						  
}

# Deletes all ons under the event
sub del_on {
   my $on = shift;
   Irssi::signal_remove($on, 'signal_handler');
   return delete($on{$on});
}

# This is nasty.
# It would be nice if perl scripts could use Irssi's internal stuff for option
# parsing
sub option_parse {
   my $text = shift;
   my($last,%options,$cmd);
   for(split(' ',$text)) {
      if($cmd) {
	     $cmd .= " $_";
      }elsif(/^-(.+)$/) {
	     $last = 'channel' if $1 eq 'channel';
		 $options{$1}++;
	  }elsif(/^["'0-9]/) {
	     if(/^\d+$/) {
		    $options{event} = "event $_" if /^\d+$/;
		 }else{
		    $last = 'event';
			s/^['"]//;
			$options{event} = $_;
		 }
	  }elsif($last eq 'event'){
		 $last = "" if s/['"]$//;
	     $options{event} .= " $_";
	  }elsif($last) {
	     $options{$last} = $_;
		 $last = "";
	  }else{
	     $cmd = $_;
	  }
   }
   return ($cmd,%options);
}

# vim:set ts=4 sw=3 expandtab:
