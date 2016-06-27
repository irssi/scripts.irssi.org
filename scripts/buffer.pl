use strict;
use warnings;

{ package Irssi::Nick }

use Irssi qw(command_bind command_bind_first command_runsub 
settings_add_str settings_add_int command_set_options 
command_parse_options server_find_tag signal_stop signal_continue 
timeout_add timeout_remove signal_add_first signal_add_last 
current_theme);
use Irssi::TextUI;

use Scalar::Util 'looks_like_number';
use List::Util qw(min max);
use POSIX 'strftime';

our $VERSION = '1.1';
our %IRSSI = (
	authors     => 'Pablo Martín Báez Echevarría',
	contact     => 'pab_24n@outlook.com',
	name        => 'buffer',
	description => 'pastes a buffer into a channel or query window line by line with a specific delay between lines',
	url         => 'http://reirssi.wordpress.com',
	license     => 'Public Domain',
	changed     => 'vie jun 17 15:04:25 UYT 2016',
);
 
my $buffer = [];
my $pastings = {};
my $regex = '^';

my $theme = Irssi::settings_get_str('theme');
my $timestamp_format = current_theme->get_format('fe-common/core', 'timestamp'); 
my $timestamp_setting = Irssi::settings_get_str('timestamp_format');

{ # copied from Nei's adv_windowlist.pl
	my %strip_table = (
		# fe-common::core::formats.c:format_expand_styles
		#      delete                format_backs  format_fores bold_fores   other stuff
		(map { $_ => '' } (split //, '04261537' .  'kbgcrmyw' . 'KBGCRMYW' . 'U9_8I:|FnN>#[' . 'pP')),
		#      escape
		(map { $_ => $_ } (split //, '{}%')),
	);
	sub ir_strip_codes { # strip %codes
		my $o = shift;
		$o =~ s/(%(%|Z.{6}|z.{6}|X..|x..|.))/exists $strip_table{$2} ? $strip_table{$2} :
		$2 =~ m{x(?:0[a-f]|[1-6][0-9a-z]|7[a-x])|z[0-9a-f]{6}}i ? '' : $1/gex;
		$o
	}
}
sub get_expanded_timestamp {
	my $theme = current_theme;
	my $timestamp_format = $theme->get_format('fe-common/core', 'timestamp'); 
	(my $timestamp_setting = Irssi::settings_get_str('timestamp_format')) =~ s/%/%%/g;
	$timestamp_format =~ s/\$Z/$timestamp_setting/g;
	ir_strip_codes( $theme->format_expand($timestamp_format) ); 
}
push my @expanded_timestamps, { 
	unix_time          => time, 
	expanded_timestamp => get_expanded_timestamp 
};


sub cmd_buffer_help {
	print CLIENTCRAP <<HELP

%9Syntax%9:
   
BUFFER SEARCH [-file <filename>] [-regexp] [-case] [-word] [<pattern>]
BUFFER LOAD [-file <filename>] [-striptime] [-begin <first line>] [-end <last line>]
BUFFER CLEAR
BUFFER PRINT
BUFFER PLAY [-delay <seconds>] [-continue [<id>]]
BUFFER STOP [<id>]
BUFFER REMOVE [<id>]
BUFFER RESUME


%9Description%9:

    Pastes a buffer into a channel or query window line by line with a
    specific delay between lines. It is inspired by the mIRC /play
    command. 

%9Parameters%9:

    SEARCH:   Searches the active window (or a file) for a pattern and
              displays the matching lines with its corresponding line
              number, in order to make easy to load the desired text.

              -file       Name of the file where to look at. If omitted,
                          searchs the scrollback buffer of the current 
                          window.
              -regexp     The given pattern is a regexp.
              -case       Performs case sensitive matching.
              -word       The text must match full words.
              -pattern    If omitted, it will be the pattern of the
                          previous search (and if there is no previous
                          search, the command displays everything). 

    LOAD:     Loads the buffer and gets it ready to be pasted into a
              location.

              -file       Name of the file whose lines will be loaded. If
                          omitted, loads lines from the current window.
              -striptime  Tries to strip the timestamp when loading lines
                          from a window. If it is used together with 
                          -file, it has no effect.
              -begin      Number of the first line to be loaded. If
                          omitted, it will be 1.
              -end        Number of the last line to be loaded. If
                          omitted, it will be the total number of lines
                          in the current window/file.

    CLEAR:    Clears the buffer.
    PRINT:    Displays the content of the buffer in the status window.
    PLAY:     Pastes the buffer into the current channel or query window
              or wakes up an already existing paste.
              
              -delay      Delay (in seconds) between each message.
              -continue   Continues the paste identified by <id> (run
                          /BUFFER RESUME to find out the correct
                          identifier). If this parameter is omitted, it
                          will paste the entire buffer previously loaded
                          into the current channel or query window. If 
                          -continue is used not followed by an id, it
                          wakes up all the paused pastes.

    STOP:     Stops an active paste.
              
              -id         Identifier of the paste that you would like
                          to stop. If ommitted, it will stop all the
                          active pastes.

    REMOVE:   Removes an existing paste.
              
              -id         Identifier of the paste that you would like to
                          remove. If omitted, it will remove all the
                          existing pastes.

    RESUME:   Lists the existings pastes and shows information about each
              one.

   
%9Settings%9:

    -buffer_delay:          Default delay between messages.
    
    -buffer_context_lines   If this is set to n, then /BUFFER RESUME will
                            print n lines before and after the next line
                            to be pasted.
HELP
;
	signal_stop; # To avoid 'No help for buffer' at the end
}

sub open_file {
	my $filename = shift;
	$filename =~ s/^~/$ENV{HOME}/;
	open my $fh, '<', $filename or die "Could not open file '$filename': $!\n";
	die "File '$filename' does not look like a text file\n" unless -T $filename;
	return $fh;    
}

sub send_line {
	my ( $timeout_tag, $buff, $index, $server, $target ) = @_;
	
	# Get line
	my $line = $buff->[$$index];
	$line .= ' ' if $line eq '';
	
	# Send line to target	
	$server->command("MSG $target $line");
	
	# Increment pointer which stores the next line to be sent
	$$index++;
	
	# Remove the paste if it's the last line in the buffer
	if ( $$index == @$buff ) {
		timeout_remove( $timeout_tag );
		delete $pastings->{$timeout_tag};
	}
}

sub timeout_function {
	my ( $ref ) = @_;
	my $timeout_tag = $$ref;
	
	my ( $buff, $servtag, $targ, $pointer ) = 
	@{$pastings->{$timeout_tag}}{qw/buffer network target counter/};
	
	# Check server and target
	my $server = server_find_tag( $servtag );
	unless ( $server && $server->{'connected'} ) {
		printf CLIENTERROR "Not connected to server '%s'. Paste <%d> will be paused", $servtag, $timeout_tag;
		timeout_remove( $timeout_tag );
		$pastings->{$timeout_tag}{'status'} = 'paused';
		return;
	};
	my $witem = $server->window_find_item($targ);
	unless ( $witem ) {
		printf CLIENTERROR "No window named '%s'. Paste <%d> will be paused", $targ, $timeout_tag;
		timeout_remove( $timeout_tag );
		$pastings->{$timeout_tag}{'status'} = 'paused';
		return;
	}
	
	# Send line
	send_line($timeout_tag, $buff, $pointer, $server, $targ);
}

sub buffer_context_range {
	my ( $index, $context_lines, $total ) = @_;
	my $first = max( 0, $index - $context_lines );
	my $last  = min( $total-1, $index + $context_lines );
	$first..$last;
}

sub get_timestamp_regexp { 
	my $unix_time = shift;
	my $last = 0;
        foreach my $i (0..$#expanded_timestamps) {
		$last = $i if ($expanded_timestamps[$i]->{'unix_time'} <= $unix_time) or last;
	}
	my $frm1 = $expanded_timestamps[$last]->{'expanded_timestamp'};
	my $frm2 = $expanded_timestamps[$last-1]->{'expanded_timestamp'} if $last >= 1;
	my $timestamp1 = strftime($frm1, localtime($unix_time));
	my $timestamp2 = (defined $frm2) ? strftime($frm2, localtime($unix_time)) : '';
	qr/\Q$timestamp1\E|\Q$timestamp2\E/;
}

sub cmd_buffer_search {
	my ( $args, $server, $witem ) = @_;
	my ($options, $pattern) = command_parse_options('buffer search', $args);
	
	if ($pattern) {
		my $flags = defined($options->{'case'}) ? '' : '(?i)';
		my $b = defined($options->{'word'}) ? '\b' : '';
		if (defined $options->{'regexp'} ) {
			local $@;
			eval {
				$regex = qr/$flags$b$pattern$b/;
			};
			if ($@) {
				my ($err) = $@ =~ /^(.*) at .* line \d+\.$/;
				print CLIENTERROR "Pattern \/$pattern\/ did not compile: $err";
				return;
			}
		} else {
			$regex = qr/$flags$b\Q$pattern\E$b/;
		}
	}
	my @results;
	if ( defined $options->{'file'} ) {
		my $filename = $options->{'file'};
		my $fh;
		eval { $fh = open_file($filename) };
		if ($@) {
			chomp(my $err = $@);
			print CLIENTERROR $err;
			return;
		}
		my $num = 1;
		while( defined (my $line = <$fh>) ) {
			chomp($line);
			$line =~ s/\t/' 'x4/ge;
			push @results, [$num, $`, $&, $'] if $line =~ $regex;
			$num++;
		}
		close $fh;
	} else {
		my $current_win = ref $witem ? $witem->window : Irssi::active_win;
		my $view = $current_win->view;
		my $line = $view->{'buffer'}->{'first_line'};
		my $num = 1;
		while ( defined $line ) {
			push @results, [$num, $`, $&, $'] if $line->get_text(0) =~ $regex;
			$line = $line->next;
			$num++;
		}
	}
	if (@results) { 
		my $greatest_line_number = $results[-1][0];
		my $digits = length $greatest_line_number;
		printf CLIENTCRAP join("\n", ("%%9%${digits}d.%%n%s%%9%%R%s%%n%s")x@results), 
		map { @$_[0..3] } @results;
	}
}

sub cmd_buffer_load {
	my ( $args, $server, $witem ) = @_;
	my ($options) = command_parse_options('buffer load', $args);
	my $start = $options->{'begin'} // 1;
	my $end;
	my @new_buffer;
	if ( defined $options->{'file'} ) {
		my $filename = $options->{'file'};
		my $fh;
		eval { $fh = open_file($filename) };
		if ($@) {
			chomp(my $err = $@);
			print CLIENTERROR $err;
			return;
		}
		my @dump = <$fh>;
		close $fh;
		my $lines_count = @dump;
		$end = $options->{'end'} // $lines_count; 
		
		if ($start<1 || $end>$lines_count || $start>$end) {
			print CLIENTERROR 'Wrong -start or -end parameters (out of range)';
			return;
		};
		@new_buffer = map{ chomp; s/\t/' 'x4/ge; $_ } @dump[$start-1..$end-1]
	} else {
		my $current_win = ref $witem ? $witem->window : Irssi::active_win;
		my $view = $current_win->view;
		my $line = $view->{'buffer'}->{'first_line'};
		my $lines_count = $view->{'buffer'}->{'lines_count'};
		$end = $options->{'end'} // $lines_count;
		
		if ($start<1 || $end>$lines_count || $start>$end) {
			print CLIENTERROR 'Wrong -start or -end parameters (out of range)';
			return;
		};
		my $num = 1;
		while ( defined $line ) {
			if ( $start<=$num && $num<=$end ) {
				chomp(my $line_text = $line->get_text(0));
				if ( defined $options->{'striptime'} ) {
					my $timestamp_regex = get_timestamp_regexp($line->{'info'}{'time'});
					$line_text =~ s/^$timestamp_regex//;
				}
				push @new_buffer, $line_text;
				last if $num == $end;
			}
			$line = $line->next;
			$num++;
		}
	}
	$buffer = \@new_buffer;
	print CLIENTCRAP 'Buffer successfully loaded';
}

sub cmd_buffer_clear {
	$buffer = [];
	print CLIENTCRAP 'Buffer is now empty';
}

sub cmd_buffer_print {
	print CLIENTCRAP $_ for @$buffer;
	printf CLIENTCRAP "%d lines", scalar @$buffer;
}

sub cmd_buffer_play {
	my ( $args, $server, $witem ) = @_;
	
	my ($options) = command_parse_options('buffer play', $args);
	my $delay = $options->{'delay'} // Irssi::settings_get_str('buffer_delay');
	unless (looks_like_number($delay)) {
		print CLIENTERROR 'Delay must be a number';
		return;
	}
	unless ( $delay >= 10e-3 ) {
		print CLIENTERROR 'Delay cannot be less than 0.010 seconds (10 milliseconds)';
		return;
	}
	if ( defined $options->{'continue'} ) {
		my $id = $options->{'continue'};
		if ( $id =~ /^\s*$/ ) { # Empty id. Wake up every paused paste
			foreach my $inner_id (keys %$pastings) {
				if ( $pastings->{$inner_id}{'status'} eq 'paused' ) {
					wake_sleeping_paste( $inner_id, $options->{'delay'} );
				}
			}
		} else { # Not empty id
			unless ( defined $pastings->{$id} ) {
				print CLIENTERROR 'Not recognized id. See /BUFFER RESUME';
				return;
			}
			wake_sleeping_paste( $id, $options->{'delay'} );
		}
	} else {
		unless ( $server && $server->{'connected'} ) {
			print CLIENTERROR 'Not connected to server';
			return;
		}
		unless ( $witem && ($witem->{'type'} eq 'CHANNEL' || $witem->{'type'} eq 'QUERY') ) {
			print CLIENTERROR 'No active channel/query in window';
			return;
		}
		unless ( @$buffer ) {
			print CLIENTERROR 'Buffer is empty. Nothing to paste';
			return;
		}
		my $servtag = $server->{'tag'};
		my $target = $witem->{'name'};
		my $counter = 0;
		
		my $timeout_tag;
		$timeout_tag = timeout_add( $delay*1000 , 'timeout_function', \$timeout_tag );
		$pastings->{$timeout_tag} = {
			buffer    => $buffer,
			status    => 'active',
			network   => $servtag,
			target    => $target,
			counter   => \$counter,
			delay     => $delay,
			timestamp => time,
		};
		send_line($timeout_tag, $buffer, \$counter, $server, $target);
	}
}

sub wake_sleeping_paste {
	my ( $id, $delay ) = @_;
	unless ( $pastings->{$id}{'status'} eq 'paused' ) {
		printf CLIENTERROR 'Paste <%d> is already active', $id;
		return;
	}
	
	my ( $buff, $servtag, $targ, $pointer ) = 
	@{$pastings->{$id}}{qw/buffer network target counter/};
	
	# Check server and target
	my $server = server_find_tag( $servtag );
	unless ( $server && $server->{'connected'} ) {
		printf CLIENTERROR "Not connected to server '%s'. Paste <%d> will continue to be paused", $servtag, $id;
		return;
	};
	my $witem = $server->window_find_item($targ);
	unless ( $witem ) {
		printf CLIENTERROR "No window named '%s'. Paste <%d> will continue to be paused", $targ, $id;
		return;
	}
	my $temp = $pastings->{$id};
	delete $pastings->{$id};
	$temp->{'status'} = 'active';
	$temp->{'delay'} = $delay if defined $delay;
	$temp->{'timestamp'} = time;
	
	my $timeout_tag;
	$timeout_tag = timeout_add( $temp->{'delay'} * 1000 , 'timeout_function', \$timeout_tag );
	$pastings->{$timeout_tag} = $temp;
	send_line($timeout_tag, $buff, $pointer, $server, $targ);
}

sub cmd_buffer_stop {
	my ( $args, $server, $witem ) = @_;
	my $id = $args;
	if ( $id =~ /^\s*$/ ) { # Empty id. Stop every active paste
		foreach my $inner_id (keys %$pastings) {
			if ( $pastings->{$inner_id}{'status'} eq 'active' ) {
				timeout_remove( $inner_id );
				$pastings->{$inner_id}{'status'} = 'paused';
			}
		}
	} else { # Not empty id
		unless ( defined $pastings->{$id} ) {
			print CLIENTERROR 'Not recognized id. See /BUFFER RESUME';
			return;
		}
		if ( $pastings->{$id}{'status'} eq 'active' ) {
			timeout_remove( $id );
			$pastings->{$id}{'status'} = 'paused';
		}
	}
}

sub cmd_buffer_remove {
	my ( $args, $server, $witem ) = @_;
	my $id = $args;
	if ( $id =~ /^\s*$/ ) { # Empty id. Remove every existing paste
		foreach my $inner_id (keys %$pastings) {
			timeout_remove( $inner_id );
			delete $pastings->{$inner_id};
		}
	} else { # Not empty id
		unless ( defined $pastings->{$id} ) {
			print CLIENTERROR 'Not recognized id. See /BUFFER RESUME';
			return;
		}
		timeout_remove( $id );
		delete $pastings->{$id};
	}
}

sub cmd_buffer_resume {
	if ( keys %$pastings ) {
		
		my $context_lines = Irssi::settings_get_int('buffer_context_lines');
		if ($context_lines < 0) {
			print CLIENTERROR 'The number of context lines (surrounding the next line to be sent) must be a positive integer';
			return;
		}
		
		my $id_string = 'ID';
		my $id_colwidth = max( 
			length($id_string), 
			max( map{length($_)} keys %$pastings ) 
		);
		
		my $time_string = 'TIMESTAMP';
		my $time_colwidth = max( 
			length($time_string), 
			max( map{length( strftime('%c', localtime($pastings->{$_}->{'timestamp'})) )} keys %$pastings )
		);
		
		my $status_string = 'STATUS';
		my $status_colwidth =  max( 
			length($status_string), 
			max( map{length($pastings->{$_}->{'status'})} keys %$pastings ) 
		);
		
		my $network_string = 'NETWORK';
		my $network_colwidth = max( 
			length($network_string), 
			max( map{length($pastings->{$_}->{'network'})} keys %$pastings ) 
		);
		
		my $channel_string = 'TARGET';
		my $channel_colwidth = max( 
			length($channel_string), 
			max( map{length($pastings->{$_}->{'target'})} keys %$pastings ) 
		);
		
		my $delay_string = 'DELAY';
		my $delay_colwidth = max( 
			length($delay_string), 
			max( map{length($pastings->{$_}->{'delay'})} keys %$pastings ) 
		);
		
		my $pasted_string = 'PASTED LINES';
		my $pasted_colwidth = max( 
			length($pasted_string), 
			max( map{length( ${$pastings->{$_}->{'counter'}} )} keys %$pastings ) 
		);
		
		my $pending_string = 'PENDING LINES';
		my $pending_colwidth = max( 
			length($pending_string), 
			max( map{length( @{$pastings->{$_}->{'buffer'}} - ${$pastings->{$_}->{'counter'}} )} keys %$pastings ) 
		);
		
		my $str_format = join ( 
		" "x4, 
		map { "\%${_}s" }
			($id_colwidth,
			$time_colwidth, 
			$status_colwidth, 
			$network_colwidth, 
			$channel_colwidth, 
			$delay_colwidth, 
			$pasted_colwidth, 
			$pending_colwidth
			)
		);
		foreach my $id ( sort{$pastings->{$a}->{'timestamp'}<=>$pastings->{$b}->{'timestamp'}} keys %$pastings ) {
			printf CLIENTCRAP "%%9" . $str_format,
			($id_string, 
			$time_string,
			$status_string, 
			$network_string, 
			$channel_string, 
			$delay_string, 
			$pasted_string, 
			$pending_string
			);
			printf CLIENTCRAP $str_format . "\n", 
			($id, 
			strftime('%c', localtime($pastings->{$id}->{'timestamp'})),
			$pastings->{$id}->{'status'}, 
			$pastings->{$id}->{'network'}, 
			$pastings->{$id}->{'target'}, 
			$pastings->{$id}->{'delay'}, 
			${$pastings->{$id}->{'counter'}}, 
			@{$pastings->{$id}->{'buffer'}} - ${$pastings->{$id}->{'counter'}}
			);
			print CLIENTCRAP '%9NEXT LINE TO BE PASTED:';
			my $buffref = $pastings->{$id}->{'buffer'};
			my $index = ${ $pastings->{$id}->{'counter'} };
			my $total = @$buffref;
			my @range = buffer_context_range($index, $context_lines, $total);
			my $digits = length( max( map{$_ + 1} @range ) );
			foreach my $i ( @range ) {
				printf CLIENTCRAP "%%9%${digits}d.%%n%10s%s", 
				$i+1, (($i == $index) ? '===>' : ''), @$buffref[$i];
			};
			printf CLIENTCRAP "---- End paste <%s>", $id;
		}
	} else {
		print CLIENTCRAP "There aren't any pastes";
		return;
	}
}

signal_add_first 'send command' => sub {
	signal_continue(@_);
	my $command = shift;
	my $cmdchars = Irssi::settings_get_str('cmdchars');
	if ( $command =~ /^\Q$cmdchars\Eformat\s+timestamp/i ) {
		my $current_timestamp_format = current_theme->get_format('fe-common/core', 'timestamp');
		if ( $current_timestamp_format ne $timestamp_format ) {
			push @expanded_timestamps, {
				unix_time          => time, 
				expanded_timestamp => get_expanded_timestamp 
			};
			$timestamp_format = $current_timestamp_format; 
		}
	}
};

signal_add_last 'setup changed' => sub { 
	my $current_theme = Irssi::settings_get_str('theme');
	my $current_timestamp_setting = Irssi::settings_get_str('timestamp_format');
	if ( $current_theme ne $theme || $current_timestamp_setting ne $timestamp_setting ) {
		push @expanded_timestamps, {
			unix_time          => time, 
			expanded_timestamp => get_expanded_timestamp 
		};
		$theme = $current_theme;
		$timestamp_setting = $current_timestamp_setting;
	}
};

command_bind 'buffer' => sub {
	my ( $data, $server, $item ) = @_;
	$data =~ s/\s+$//g;
	command_runsub('buffer', $data, $server, $item);
};
command_bind_first help => sub { &cmd_buffer_help if $_[0] =~ /^buffer\s*$/i };
command_bind 'buffer search' => 'cmd_buffer_search';
command_set_options 'buffer search' => '-file regexp case word';
command_bind 'buffer load' => 'cmd_buffer_load';
command_set_options 'buffer load' => '-file striptime @begin @end';
command_bind 'buffer clear' => 'cmd_buffer_clear';
command_bind 'buffer print' => 'cmd_buffer_print';
command_bind 'buffer play' => 'cmd_buffer_play';
command_set_options 'buffer play' => '-delay -continue';
command_bind 'buffer stop' => 'cmd_buffer_stop';
command_bind 'buffer remove' => 'cmd_buffer_remove';
command_bind 'buffer resume' => 'cmd_buffer_resume';
settings_add_str 'buffer', 'buffer_delay', '1';
settings_add_int 'buffer', 'buffer_context_lines', '2';
