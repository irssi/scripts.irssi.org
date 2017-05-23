# TODO: people I care about first
#       multiline
#       away toggle is slow: why
#       on terminal resize, window width returns old size.  sleeping doesn't help
#       does anyone know how to find space available to a statusbar instead of for the whole window?
#       remember tickercount separately for each channel and don't reset it
#       skip command to jump forward in the ticker
#       only reset on dr_who setup changes, not everything else

# How to use:
#  /script load dr_who
#  /statusbar dr_who enable
#  /statusbar dr_who add dr_who
# dr_who has to use the entire statusbar currently.  Maybe this will change in the future

use strict;
use Irssi::TextUI;

use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
	authors     => 'Bitt Faulk',
	contact     => 'lxsfx3h02@sneakemail.com',
	name        => 'dr_who',
	description => 'Put a nick list in a statusbar',
	sbitems => 'dr_who',
	license => 'BSD',
	url     => 'http://beaglebros.com',
	changed => '1-17-2005'
);

my ($dr_who_line, $timeout);
my $tickercount = 0;
my $direction = 1;

# Stolen from autoop.pl: http://xkr47.outerspace.dyndns.org/configs/irssi/autoop.pl
sub get_cur_channel() {
	my $server_o = Irssi::active_server();
	my $window_o = Irssi::active_win();
	my @items = $window_o->items();
	my $item_o;
	foreach $item_o (@items) {
		next unless($item_o->is_active());
	
		my $channel = $item_o->{name};
		my $channel_o = $server_o->channel_find($channel);

		return $channel_o if($channel_o);
	}

	return ();
}

sub dr_who_refresh {
	my $channel = get_cur_channel();
	my %channicks;
	my $nick;
	my $text_count = 0;
	my @nicks;
	my $continue = 0;
	my $displaytype = Irssi::settings_get_str('dr_who_longdisplay');
	my $atend;
	my $buffer;

	if ( $channel ) {
		my $window_width = Irssi::active_win()->{width};
		foreach $nick (get_cur_channel()->nicks()) {
			$channicks{$nick->{nick}} = $nick;
		}
		$dr_who_line = "{sb ";
		$text_count += 4; #for bracket/space borders
		$atend = scalar(keys %channicks);
		foreach $nick (sort {uc($a) cmp uc($b)} keys %channicks) {
			my ( $new_nick, $new_nick_width );

			$atend--;
			if ( $channicks{$nick}->{gone} ) {
				$new_nick .= "{nohilight ";
			} else {
				$new_nick .= "{hilight ";
			}
			if ( Irssi::settings_get_bool('dr_who_nickflags') ) {
				if ( $channicks{$nick}->{serverop} ) {
					$new_nick .= "*";
					$new_nick_width += 1;
				}
				if ( $channicks{$nick}->{op} ) {
					$new_nick .= "@";
					$new_nick_width += 1;
				} elsif ( $channicks{$nick}->{voice} ) {
					$new_nick .= "+";
					$new_nick_width += 1;
				}
			}
			$new_nick .= "$nick}";
			$new_nick_width += length($nick);
			if ( $displaytype eq "ticker" ) {
				if ( $tickercount > 0 ) {
					$buffer = 6;
				} else {
					$buffer = 0;
				}
				if ( (($text_count+$new_nick_width+$#nicks+1) > $window_width+$tickercount-$buffer) ) { # already written nicks and other text, plus new nick, plus spaces to separate them all (+1 because $#nicks is the last index, not the number in the array)
					$continue = 1;
					if ( (($window_width+$tickercount) - ($text_count+$#nicks+1)) > 5 ) { # there's at least six characters left available
						my $extra = ($text_count+$new_nick_width+$#nicks+1) - ($window_width+$tickercount); # How far over?
						$new_nick = substr($new_nick, 0, length($new_nick) - ($extra + 7));
						$new_nick .= "}";
						$new_nick_width -= ($extra + 7);
						$text_count += $new_nick_width;
						push(@nicks, { nick => $new_nick, len => $new_nick_width });
					} else {
						my $extra = ($text_count+$#nicks) - ($window_width+$tickercount) + 6; # How far over?
						while ( $extra > 0 ) {
							if ( $extra >= $nicks[$#nicks]{len} ) {
								$extra -= $nicks[$#nicks]{len};
								$text_count -= $nicks[$#nicks]{len};
								pop(@nicks);
								$nicks[$#nicks]{nick} .= " ";
							} else {
								$nicks[$#nicks]{nick} = substr($nicks[$#nicks]{nick}, 0, (length($nicks[$#nicks]{nick}) - $extra - 1));
								$nicks[$#nicks]{nick} .= "}";
								$nicks[$#nicks]{len} -= $extra;
								$text_count -= $extra;
								$extra = 0;
							}
						}
					}
					last;
				} else {
					if ( $tickercount > 0 ) {
						$continue = 1;
					}
					push(@nicks, { nick => $new_nick, len => $new_nick_width });
					$text_count += $new_nick_width;
					if ( ($atend == 0) && ($tickercount > 0) ) {
						$direction = -1;
					}
				}
			} else {
				if ( ($text_count+$new_nick_width+$#nicks+1) > $window_width ) { # length of already-written nicks and other text, plus length of the current nick, plus spaces to put between them all (the 1 is because $#nicks is the last index, not the number of items in the array)
					$continue = 1;
					if ( ($window_width - ($text_count+$#nicks+1)) > 2 ) {
						my $extra = (($text_count+$#nicks+1)+$new_nick_width)-$window_width;
						$new_nick = substr($new_nick, 0, length($new_nick) - ($extra + 4));
						$new_nick .= "}";
						push(@nicks, { nick => $new_nick, len => $new_nick_width });
					} else {
						my $extra = ($text_count+$#nicks) - $window_width + 3;
						while ( $extra > 0 ) {
							if ( $extra >= $nicks[$#nicks]{len} ) {
								$extra -= $nicks[$#nicks]{len};
								pop(@nicks);
								$nicks[$#nicks]{nick} .= " ";
							} else {
								$nicks[$#nicks]{nick} = substr($nicks[$#nicks]{nick}, 0, (length($nicks[$#nicks]{nick}) - $extra - 1));
								$nicks[$#nicks]{nick} .= "}";
								$extra = 0;
							}
						}
					}
					last;
				} else {
					push(@nicks, { nick => $new_nick, len => $new_nick_width });
					$text_count += $new_nick_width;
				}
			}
		}
		if ($continue && ($displaytype eq "ticker")) {
			$dr_who_line .= "<--";
			my $i = $tickercount;
			my $tempspace;
			foreach my $nickhash ( @nicks ) {
				if ( $i > 0 ) {
					if ( $$nickhash{len} == $i ) {
						$i -= $$nickhash{len};
						$dr_who_line .= " ";
					} elsif ( $$nickhash{len} < $i ) {
						$i -= $$nickhash{len} + 1;
					} else {
						$$nickhash{nick} =~ s/ (.*)}$//;
						my $cut = $1;
						$cut = substr($cut, $i);
						$dr_who_line .= "$$nickhash{nick} $cut} ";
						$i = 0;
					}
				} else {
					$dr_who_line .= $$nickhash{nick} . " ";
				}
			}
			$tickercount += $direction;
			if ( $tickercount == 0 ) {
				$direction = 1;
			}
			#if ( $tickercount < 0 ) {
				#$tickercount = 0;
				#$direction = 1;
			#} elsif ( $atend == 0 ) {
				#$atend = 0;
				#$tickercount = -1;
			#}
			Irssi::timeout_remove($timeout);
			$timeout = Irssi::timeout_add_once(Irssi::settings_get_int('dr_who_tickerspeed'), 'dr_who_refresh', undef);
		} else {
			$tickercount = 0;
			$direction = 1;
			foreach my $nickhash ( @nicks ) {
				$dr_who_line .= $$nickhash{nick} . " ";
			}
		}
		chop($dr_who_line);
		$dr_who_line .= "-->" if ($continue);
		$dr_who_line .= "}";
	} else {
		$dr_who_line = "";
	}

	Irssi::statusbar_items_redraw('dr_who');
}

sub dr_who_reset {
	$tickercount = 0;
	$direction = 1;
	if (Irssi::settings_get_int('dr_who_tickerspeed') < 10 ) {
		Irssi::print("dr_who: tickerspeed must be at least 10 milliseconds");
		Irssi::settings_set_int('dr_who_tickerspeed', 10);
	}
	dr_who_refresh();
}

sub dr_who {
	my ($item, $get_size_only) = @_;
	$item->default_handler($get_size_only, $dr_who_line, undef, 1);
}

sub dr_who_start {
	Irssi::statusbar_item_register('dr_who', undef, 'dr_who');
	Irssi::command_bind('dr_who_refresh', 'dr_who_refresh');
	Irssi::settings_add_bool('dr_who', 'dr_who_nickflags', 1);
	Irssi::settings_add_str('dr_who', 'dr_who_longdisplay', 'static');
	Irssi::settings_add_int('dr_who', 'dr_who_tickerspeed', 500);
	&dr_who_refresh();
	Irssi::signal_add('window changed', 'dr_who_reset');
	Irssi::signal_add('nicklist new', 'dr_who_refresh');
	Irssi::signal_add('nicklist remove', 'dr_who_refresh');
	Irssi::signal_add('nicklist changed', 'dr_who_refresh');
	Irssi::signal_add('channel joined', 'dr_who_refresh');
	Irssi::signal_add('nick mode changed', 'dr_who_refresh');
	Irssi::signal_add('user mode changed', 'dr_who_refresh');
	Irssi::signal_add('away mode changed', 'dr_who_refresh');
	Irssi::signal_add('terminal resized', 'dr_who_reset');
	Irssi::signal_add('setup changed', 'dr_who_reset');
}

&dr_who_start();

# vim: set shiftwidth=2 tabstop=2:
