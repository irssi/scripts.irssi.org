#!/usr/bin/perl
#
# by Stefan "tommie" Tomanek
#
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = "2003231101";
%IRSSI = (
    authors     => "Stefan 'tommie' Tomanek",
    contact     => "stefan\@pico.ruhr.de",
    name        => "IrssiQ",
    description => "integrates ICQ instant-messaging into irssi",
    license     => "GPLv2",
    changed     => "$VERSION",
    modules     => "Net::vICQ Data::Dumper",
    sbitems     => "irssiq",
    commands	=> "irssiq"
);

use Irssi 20020324;
use Irssi::TextUI;
use Net::vICQ;
use Data::Dumper;
use vars qw($icq $timer $old_status %contacts @requested $want_connect);

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

sub show_help() {
    my $help="IrssiQ $VERSION
/irssiq
    List contact list
/irssiq connect
    Connect to the ICQ network
/irssiq disconnect
    Disconnect from ICQ network
/irssiq add <uin>
    Add uin to contact list
/irssiq del <uin>
    Delete uin from contact list
/irssiq auth <uin>
    Authorize user to add your UIN to his contact list
/irssiq info <uin1> <uin2>....
    Retrieve information about the uins
/irssiq invisible <uin>
    Add or remove the UIN from your invisible list
/irssiq visible <uin>
    Add or remove the UIN from your visible list
/irssiq hidden <uin>
    Hide (or show) a uin in the statusbar
/irssiq msg <uin>
    Send a message to uin
/irssiq query <uin>
    Create a new query window with uin
/irssiq email
    Send an email to uin
/irssiq status (away|online|na|occupied|dnd|invisible)
    Change to the selected status
/irssiq save
    Save contact list to file
/irssiq load
    (Re-)Load contact list (reconnect afterwards)
";      
    my $text = '';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP draw_box($IRSSI{name}, $text, "help", 1);
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
}

sub store_openurl ($$$) {
    my ($uin, $text, $url) = @_;
    $url =~ s/\n/ /g;
    $text =~ s/\n/ /g;
    no strict "refs";
    if (defined %{ "Irssi::Script::openurl::" }) {
	&{ "Irssi::Script::openurl::new_url" }(undef, "IrssiQ", $uin, $text, $url);
    } else {
	print CLIENTCRAP "%R>>%n Please install openurl.pl";
    }
}

sub output ($) {
    print CLIENTCRAP $_ foreach split(/\n/, $_[0]);
}

sub icq_connect {
    my $uin = Irssi::settings_get_int('irssiq_uin');
    my $password = Irssi::settings_get_str('irssiq_password');
    $icq = Net::vICQ->new($uin, $password, 0);
    #$icq->{_Hide_IP} = 0;
    $icq->Add_Hook("Srv_Mes_Received", \&MessageHandler);
    $icq->Add_Hook("Srv_Srv_Message", \&MessageHandler);
    $icq->Add_Hook("Srv_BLM_Contact_Online", \&MessageHandler);
    $icq->Add_Hook("Srv_BLM_Contact_Offline", \&MessageHandler);
    $icq->{_Status} = 'Online';
    my $err;
    output "%R>>%n Trying to connect to ICQ server...";
    {
	$icq->{_Auto_Login} = 1;
	open FOO, '>>/dev/null';
	my $oldfh = select(FOO);
	$icq->Connect();
	if(!($err = $icq->GetError())) {
	    while(!$icq->{_LoggedIn} && !($err = $icq->GetError())) {
	    	$icq->Execute_Once();
	    }
    	}
	select($oldfh);
    }
    if(!$err) {
        output "%R<<%n ..connected!";
	#my ($details);
	#$details->{Status} = 'Online';
	#$icq->Send_Command("Cmd_GSC_Set_Status", $details);
	add_uin($uin) unless $contacts{$uin};
	send_contacts();
	$timer = Irssi::timeout_add(2000, 'icq_cycle', undef);
        return 1;
    } else {
        output "%R<<%n ..failed!";
	$want_connect = 0;
        my $s = $err;
        chomp($s);
        print("%R>>%n ".$s);
        return 0;
    }
}

sub write_to_log ($$$$) {
    my ($who, $direction, $type, $text) = @_;
    my $dir = Irssi::get_irssi_dir();
    mkdir $dir."/irssiq/" unless (-e $dir."/irssiq/");
    
    my $data = $type." ".$direction." ".$who.":\n";
    $data .= scalar(localtime())."\n";
    $data .= $text."\n\n";

    local *F;
    open(F, '>>'.$dir."/irssiq/".$who);
    print F $data;
    close(F);
}

sub MessageHandler ($$) {
    my ($icq, $details) = @_;
    if (Irssi::settings_get_bool('irssiq_debug')) {
	my $text;
	foreach (keys %$details) {
	    my $content = $details->{$_};
	    no warnings;
	    #$content =~ s/\c.//g;
	    #$content =~ s/\pC//g;
	    $content =~ s/(?:(\n)|\pC)/$1/g;
	    $content =~ s/%/%%/g;
	    $text .=  $_." -> <".$content.">\n";
	}
	#print CLIENTCRAP $_." -> <".$details->{$_}.">" foreach keys %$details;
	print CLIENTCRAP &draw_box('IrssiQ', $text, 'debug', 1);
    }
    my $type = $details->{MessageType};
    if ($type eq 'text_message' || $type eq 'offline_text_message' ) {
	my $text = $details->{text};
	# FIXME unicode stuff?!
	no warnings;
	#$text =~ s/\c.//g;
	#$text =~ s/\pC//g;
	$text =~ s/(?:(\n)|\pC)/$1/g;
	write_to_log($details->{Sender}, 'from', 'msg', $text);
	$text =~ s/%/%%/g;
	my $output = draw_box("IrssiQ", $text, "msg from ".get_nick($details->{Sender}), 1);
	# autocancels if there is already a window
	start_query($details->{Sender}) if Irssi::settings_get_bool('irssiq_auto_open_query');
    	my $win = Irssi::window_find_name('<IrssiQ-'.$details->{Sender}.'>');
 	if (ref $win) {
	    if (Irssi::settings_get_bool('irssiq_msg_border_in_query')) {
		$win->print($output, MSGLEVEL_MSGS);
	    } else {
	     	$win->print("<".get_nick($details->{Sender})."> ".$text, MSGLEVEL_MSGS);
	    }
	} else {
	    print MSGS $_ foreach split(/\n/, $output);
	}
    } elsif ($type eq 'URL') {
	write_to_log($details->{Sender}, 'from', 'URL', $details->{URL});
	my $output = draw_box("IrssiQ", "%U".$details->{URL}."%U", "URL from ".get_nick($details->{Sender}), 1);
	my $win = Irssi::window_find_name('<IrssiQ-'.$details->{Sender}.'>');
	unless (ref $win) {
	    print MSGS $_ foreach split(/\n/, $output);
	} else {
	    $win->print("<".get_nick($details->{Sender})."> ".$details->{URL}, MSGLEVEL_MSGS);
	}
	store_openurl($details->{Sender}, $details->{URL}, $details->{URL});
    } elsif ($type eq 'status_change') {
	if ($details->{Sender} == Irssi::settings_get_int('irssiq_uin')) {
	    unless ($contacts{$details->{Sender}}{status} eq $details->{Status}) {
		output "%R<<%n Changed own status to '".$details->{Status}."'.";
	    }
	}
	$contacts{$details->{Sender}}{status} = $details->{Status};
	Irssi::statusbar_items_redraw('irssiq');
    } elsif ($type eq 'user_info_main') {
	my $uin = shift(@requested);
	if ($contacts{$uin}) {
	    foreach (keys %$details) {
		next if (/Ref|Our_UIN|MessageType|SubMessageType/);
		$contacts{$uin}{user_info_main}{$_} = $details->{$_};
		$contacts{$uin}{user_info_main}{$_} =~ s/ /_/g if $_ eq 'Nickname';
	    }
	}
	show_short_info($uin, $details);
	Irssi::statusbar_items_redraw('irssiq');
	next_info();
    } elsif ($type eq 'user_info_not_found') {
	my $uin = shift(@requested);
	output "%R>>%n Information about UIN ".$uin." not found";
	next_info();
    } elsif ($type eq 'add_message') {
	output draw_box("IrssiQ", $details->{Sender}." added you to his/her contact list", "added by ".$details->{Sender}, 1);
    } elsif ($type eq 'auth_request') {
	get_userinfo($details->{Sender});
	output draw_box("IrssiQ", $details->{reason}, "auth-request from ".$details->{Sender}, 1);
    } elsif ($type eq 'Invalid tagged message') {
	# Webmessage
	my $string = $details->{TaggedDataString};
	$string =~ s/\pC//g;
	$string =~ /\d+\.\d+\.\d+\.\d+(.*)/;
	write_to_log("Webmessage", 'from', 'msg', $1);
	print CLIENTCRAP &draw_box("IrssiQ", $1, "WebMessage", 1);
    }
}

sub next_info {
    return unless defined $requested[0];
    my $uin = $requested[0];
    output "%B>>%n Requesting user information for UIN #$uin";
    my %details = (
        MessageType => "Get_WP_Info",
        TargetUIN => $uin,
    );
    $icq->Send_Command("Cmd_Srv_Message", \%details);
}

sub get_userinfo ($) {
    my ($uin) = @_;
    push @requested, $uin;
    next_info if (scalar(@requested) == 1);
}

sub icq_cycle {
    return unless ($icq);
    $icq->Send_Keep_Alive();
    $icq->Execute_Once();
    unless ($icq->{_Connected}) {
        Irssi::timeout_remove($timer);
	output "%R>>%n IrssiQ disconnected";
	$contacts{$_}{status} = 'Offline' foreach keys %contacts;
	if (Irssi::settings_get_bool('irssiq_auto_reconnect') && $want_connect) {
	    icq_connect();
	}
    }
}

sub send_message ($$$) {
    my ($icq, $uin, $text) = @_;
    my $details = { uin => $uin,
                    MessageType => 'text',
                    text =>  $text
    };
    write_to_log($uin, 'to', 'msg', $text);
    $icq->Send_Command("Cmd_Send_Message", $details);
    my $win = Irssi::window_find_name('<IrssiQ-'.$uin.'>');
    my $output = draw_box("IrssiQ", $text, "msg to ".get_nick($uin), 1);
    unless (ref $win) {
	print CLIENTCRAP $_ foreach split(/\n/, $output);
    } else {
	my $my_uin = Irssi::settings_get_int('irssiq_uin');
	$win->print("<".get_nick($my_uin)."> ".$text, MSGLEVEL_CLIENTCRAP);
    }
}

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)) {
            my $l = $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }   
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)) {
            my $l = $line->[$_];
            $text .= $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1);
        }
        $text .= "\n";
    }
    return $text;
}


sub list_contacts {
    my $text;
    my @array;
    my $my_uin = Irssi::settings_get_int('irssiq_uin');
    foreach (sort {$contacts{$a}{status} cmp $contacts{$b}{status}} keys %contacts) {
	my @line;
	next if $_ eq $my_uin;
	my $status = $contacts{$_}{status};
	next if ($status eq 'Offline' && not Irssi::settings_get_bool('irssiq_list_show_offline'));
	if ($status eq "Online") {
	    push @line, "%go%n";
	} else {
	    push @line, "%ro%n";
	}
	push @line, $status;
	if ($contacts{$_}{user_info_main} && $contacts{$_}{user_info_main}{Nickname}) {
	    push @line, '['.$contacts{$_}{user_info_main}{Nickname}.']';
	} else {
	    push @line, '';
	}
	push @line, $_;
	if ($contacts{$_}{invisible}) {
	    push @line, '%B<Inv>%n';
	} else {
	    push @line, "";
	}
	if ($contacts{$_}{visible}) {
            push @line, '%G<Vis>%n';
        } else {
            push @line, "";
        }
	if ($contacts{$_}{hide_in_sb}) {
	    push @line, '%B<Hidden>%n';
	} else {
	    push @line, "";
	}
	push @array, \@line;
    }
    my %table = (Online           => '%G==Online==%n',
		 Away             => '%R===Away===%n',
		 'Do Not Disturb' => '%B===DnD====%n',
		 Occupied         => '%Y=Occupied=%n',
		 Invisible        => '%C===Inv====%n',
		 'N/A'            => '%Y===N/A====%n',
		 Offline          => '%R=Offline==%n'
		 );
    $text = array2table(@array);
    $text .= $table{$contacts{$my_uin}{status}}."\n";
    output draw_box('IrssiQ', $text, 'contacts', 1);
}

sub add_uin ($) {
    my ($uin) = @_;
    $contacts{$uin} = { status => 'Offline' } unless defined $contacts{$uin};
    Irssi::statusbar_items_redraw('irssiq');
    get_userinfo($uin) if ($icq && $icq->{_Connected});
}

sub del_uin ($) {
    my ($uin) = @_;
    return unless defined $contacts{$uin};
    delete $contacts{$uin};
}

sub send_contacts {
    my ($details, $details2, $details3);
    my @uins;
    my @inv;
    my @vis;
    foreach (keys(%contacts)) {
	push @uins, $_;
	push @inv, $_ if $contacts{$_}{invisible}; 
	push @vis, $_ if $contacts{$_}{visible}; 
    }
    $details->{ContactList} = \@uins;
    $icq->Send_Command("Cmd_Add_ContactList", $details);
    $icq->Send_Command("Cmd_CTL_UploadList", $details);
    $details2->{InVisibleList} = \@inv;
    $details3->{VisibleList} = \@vis;
    $icq->Send_Command("Cmd_BOS_Add_InVisibleList", $details2) if @inv;
    $icq->Send_Command("Cmd_BOS_Add_VisibleList", $details3) if @vis;
}

sub save_contacts {
    my $dir = Irssi::get_irssi_dir();
    my $dumper = Data::Dumper->new([\%contacts], ['contacts']);
    $dumper->Purity(1)->Deepcopy(1);
    my $data = $dumper->Dump;
    local *F;
    open(F, '>'.$dir.'/irssiq_contacts');
    print F $data;
    close(F);
    output "%R>>%n IrssiQ contacts saved";
}

sub load_contacts {
    my $text;
    my $dir = Irssi::get_irssi_dir();
    return unless (-e $dir.'/irssiq_contacts');
    local *F;
    open F, "<".$dir.'/irssiq_contacts';
    $text .= $_ foreach (<F>);
    close(F);
    if ($text) {
	no strict;
	my %friends = %{ eval "$text" };
	foreach (keys %friends) {
	    next if defined $contacts{$_};
	    $contacts{$_} = $friends{$_};
	    $contacts{$_}{status} = 'Offline';
	}
    }
}

sub show_short_info ($$) {
    my ($uin, $details) = @_;
    my $text = "== ".$details->{Nickname}." ==\n";
    $text .= "Name : ".$details->{Firstname}." ".$details->{Lastname}."\n";
    $text .= "eMail: ".$details->{Email}."\n";
    output draw_box('IrssiQ', $text, $uin, 1);
}

sub set_status ($) {
    my ($status) = @_;
    $status =~ s/ /_/g;
    my %table = (online    => 'Online',
                 away      => 'Away',
		 na        => 'Not_Available',
		 occupied  => 'Occupied',
		 dnd       => 'Do_Not_Disturb',
		 invisible => 'Invisible',
		 ffc       => 'Free_For_Chat'
		 );
    my %options = %table;
    $options{'N/A'} = 'Not_Available';
    $options{ $table{$_}  } = $table{$_} foreach keys %table;
    unless (defined $options{$status}) {
	output "%R>>%n '".$status."' is an invalid status";
	output "%R>>%n Valid options are: ".join(" ", keys(%table));
	return;
    }
    my ($details);
    $details->{Status} = $options{$status};
    $icq->Send_Command("Cmd_GSC_Set_Status", $details);
}

sub sig_away ($) {
    my ($server) = @_;
    return unless ($icq && $icq->{_Connected});
    my $away_status = Irssi::settings_get_str('irssiq_away_status');
    if ($server->{usermode_away}) {
        my $uin = Irssi::settings_get_str('irssiq_uin');
        $old_status = $contacts{$uin}{status};
	set_status($away_status);
    } else {
	set_status($old_status);
    }
}

sub sb_show ($$) {
    my ($item, $get_size_only) = @_;
    my $line = "";
    my %users;
    my $more = 0;
    foreach my $uin (sort {$contacts{$a}{status} cmp $contacts{$b}{status}} keys %contacts) {
	next if $uin eq Irssi::settings_get_str('irssiq_uin');
	my $status = $contacts{$uin}{status};
	next if $status eq '';
	next if ($status eq 'Online' && not Irssi::settings_get_bool('irssiq_statusbar_show_online'));
	next if ($status eq 'Offline' && not Irssi::settings_get_bool('irssiq_statusbar_show_offline'));
	next if ($status eq 'Away' && not Irssi::settings_get_bool('irssiq_statusbar_show_away'));
	next if ($status eq 'Do Not Disturb' && not Irssi::settings_get_bool('irssiq_statusbar_show_dnd'));
	next if ($status eq 'Occupied' && not Irssi::settings_get_bool('irssiq_statusbar_show_occupied'));
	next if ($status eq 'Invisible' && not Irssi::settings_get_bool('irssiq_statusbar_show_invisible'));
	next if ($status eq 'N/A' && not Irssi::settings_get_bool('irssiq_statusbar_show_not_available'));
	if ($contacts{$uin}{hide_in_sb}) { $more = 1; next; }
	# FIXME Irssi bug?!
	my %table = (Online           => '%gO%n',
		    Away             => '%rA%n',
		    'Do Not Disturb' => '%bD%n',
		    Occupied         => '%yOc%n',
		    Invisible        => '%cI%n',
		    'N/A'            => '%yN%n',
		    'Offline'        => '%RO%n'
		    );
	unless (Irssi::settings_get_bool('irssiq_statusbar_compact')) {
	    $line .= '<';
	    if (defined $table{$status}) {
		$line .= $table{$status};
	    } else {
		$line .= substr($status, 0, 1);
	    }
	    $line .= '%bI%n' if $contacts{$uin}{invisible};
	    $line .= '%gV%n' if $contacts{$uin}{visible};
	    $line .= '>';
	    if ($contacts{$uin}{user_info_main} && $contacts{$uin}{user_info_main}{Nickname}) {
		$line .= $contacts{$uin}{user_info_main}{Nickname}." ";
	    } else {
		$line .= $uin." ";
	    }
	} else {
	    push @{ $users{$table{$status}} }, $uin;
	}
    }
    if (Irssi::settings_get_bool('irssiq_statusbar_compact')) {
	foreach (keys %users) {
	    $line .= '<'.$_;
	    foreach my $uin (@{ $users{$_} }) {
		$line .= ' '.get_nick($uin);
	    }
	    $line .= '>';
	}
    }
    my %table = (Online           => '%G==Online==%n',
                 Away             => '%R===Away===%n',
                 'Do Not Disturb' => '%B===DnD====%n',
                 Occupied         => '%Y=Occupied=%n',
                 Invisible        => '%C===Inv====%n',
                 'N/A'            => '%Y===N/A====%n',
		 Offline          => '%R=Offline==%n'
                 );
    if (Irssi::settings_get_bool('irssiq_statusbar_short_status')) {
	%table = (Online           => '%G(On)%n',
		  Away             => '%R(Aw)%n',
		  'Do Not Disturb' => '%B(DnD)%n',
		  Occupied         => '%Y(Inv)%n',
		  'N/A'            => '%Y(NA)%n',
		  Offline          => '%R(Off)%n'
		 );
    }
    my $my_uin = Irssi::settings_get_int('irssiq_uin');
    $line .= '...' if $more;
    $line .= $table{$contacts{$my_uin}{status}};

    my $format = "{sb ".$line."}";
    $item->{min_size} = $item->{max_size} = length($line);
    $item->default_handler($get_size_only, $format, 0, 1);
}

sub get_uin ($) {
    my ($input) = @_;
    return $input if $input =~ /^[0-9]+$/;
    
    foreach (keys %contacts) {
	if ($contacts{$_}{user_info_main} && $contacts{$_}{user_info_main}{Nickname}) {
	    return $_ if lc($contacts{$_}{user_info_main}{Nickname}) eq lc($input);
	}
    }
    return undef;
}

sub get_nick ($) {
    my ($uin) = @_;
    if ($contacts{$uin} && $contacts{$uin}{user_info_main}) {
	return $contacts{$uin}{user_info_main}{Nickname};
    }
    # Fallback
    return $uin;
}

sub send_auth ($) {
    my ($uin) = @_;
    return unless $uin =~ /^[0-9]+$/;
    my ($details);
    $details->{uin} = $uin;
    $icq->Send_Command("Cmd_Authorize", $details);
    output "%R>>%n Authorization sent to ".$uin;
}

sub start_query ($) {
    my ($uin) = @_;
    return if ref Irssi::window_find_name('<IrssiQ-'.$uin.'>');
    Irssi::command("window new hide");
    my $win = Irssi::active_win;
    $win->set_name('<IrssiQ-'.$uin.'>');
    $win->set_history('<IrssiQ-'.$uin.'>');
    $win->print('Starting IrssiQ query with '.get_nick($uin).' ('.$uin.')');
}

sub sig_send_text ($) {
    my ($text, $foo1, $foo2) = @_;
    my $win = Irssi::active_win;
    return unless (ref $win && $win->{name} =~ /<IrssiQ-(\d+)>/);
    my $uin = $1;
    if ($icq && $icq->{_Connected}) {
	send_message($icq, $uin, $text);
    } else {
	$win->print("%R>>%n You are not connected to ICQ", MSGLEVEL_CLIENTCRAP);
    }
}

sub send_url ($$$) {
    my ($uin, $url, $description) = @_;
    return unless ($icq && $icq->{_Connected});
    my %details = ( uin => $uin,
		    MessageType => 'url',
		    URL =>  $url,
		    Description => $description
	    	    );
    write_to_log($uin, 'to', 'url', $url."\n".$description);
    $icq->Send_Command("Cmd_Send_Message", \%details);
    my $win = Irssi::window_find_name('<IrssiQ-'.$uin.'>');
    my $output = draw_box("IrssiQ", $url, "url to ".get_nick($uin), 1);
    unless (ref $win) {
        output $output;
    } else {
	my $my_uin = Irssi::settings_get_int('irssiq_uin');
	$win->print("<".get_nick($my_uin)."> ".$url, MSGLEVEL_CRAP);
    }

}
# calles by scriptassist on reload
sub pre_unload {
    save_contacts();
    return unless $icq->{_Connected};
    $icq->Disconnect() if ($icq && $icq->{_Connected});
    while ($icq->{_Connected}) {
	$icq->Execute_Once();
    }
    $contacts{$_}{status} = 'Offline' foreach keys %contacts;
    output "%R>>%n IrssiQ disconnected";
}

sub sig_complete_word ($$$$$) {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.irssiq (\w+)/;
    my @newlist;
    if ($1 eq 'status') {
	foreach (('online', 'away', 'na', 'occupied', 'dnd', 'invisible', 'ffc')) {
	    push @newlist, $_ if /^(\Q$word\E.*)?$/i;
	}
    } else {
	foreach (keys %contacts) {
	    push @newlist, $_ if /^(\Q$word\E.*)?$/;
	    if ($contacts{$_}{user_info_main} && $contacts{$_}{user_info_main}{Nickname}) {
		push @newlist, $contacts{$_}{user_info_main}{Nickname} if $contacts{$_}{user_info_main}{Nickname} =~ /^(\Q$word\E.*)?$/i;
	    }
	}
    }
    $want_space = 0;
    push @$list, $_ foreach @newlist;

}

sub toggle_inv_list ($) {
    my ($uin) = @_;
    return unless defined $contacts{$uin};
    $contacts{$uin}{invisible} = not $contacts{$uin}{invisible};
    my ($details);
    $details->{InVisibleList} = [$uin];
    if ($contacts{$uin}{invisible}) {
	$icq->Send_Command("Cmd_BOS_Add_InVisibleList", $details) if $icq->{_Connected};
	output "%B>>%n You are now invisible for ".get_nick($uin)." (".$uin.")";
    } else {
	$icq->Send_Command("Cmd_BOS_Remove_InVisibleList", $details) if $icq->{_Connected};
	output "%B>>%n You are no longer invisible for ".get_nick($uin)." (".$uin.")";
    }
}

sub toggle_vis_list ($) {
    my ($uin) = @_;
    return unless defined $contacts{$uin};
    $contacts{$uin}{visible} = not $contacts{$uin}{visible};
    my ($details);
    $details->{VisibleList} = [$uin];
    if ($contacts{$uin}{visible}) {
        $icq->Send_Command("Cmd_BOS_Add_VisibleList", $details) if $icq->{_Connected};
        output "%B>>%n You are now visible for ".get_nick($uin)." (".$uin.")";
    } else {
        $icq->Send_Command("Cmd_BOS_Remove_VisibleList", $details) if $icq->{_Connected};
        output "%B>>%n You are no longer visible for ".get_nick($uin)." (".$uin.")";
    }
}

sub toggle_hidden ($) {
    my ($uin) = @_;
    return unless defined $contacts{$uin};
    $contacts{$uin}{hide_in_sb} = not $contacts{$uin}{hide_in_sb};
    if ($contacts{$uin}{hide_in_sb}) {
        output "%B>>%n ".get_nick($uin)." (".$uin.") is now hidden";
    } else {
        output "%B>>%n ".get_nick($uin)." (".$uin.") is no longer hidden";
    }
    Irssi::statusbar_items_redraw('irssiq');
}       

sub cmd_irssiq ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split / +/, $args;
    if (scalar(@arg) == 0) {
	list_contacts();
    } elsif ($arg[0] eq 'connect') {
	$want_connect = 1;
	icq_connect();
    } elsif ($arg[0] eq 'disconnect') {
	$want_connect = 0;
	$icq->Disconnect() if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'msg' && defined $arg[1] && defined $arg[2]) {
	my $uin = get_uin($arg[1]);
	return unless $uin;
	shift @arg;
	shift @arg;
	send_message($icq, $uin, join(" ", @arg));
    } elsif ($arg[0] eq 'url' && defined $arg[1] && defined $arg[2]) {
	my $uin = get_uin($arg[1]);
	return unless $uin;
	my $url = $arg[2];
	shift @arg;
	shift @arg;
	send_url($uin, $url, join(" ", @arg));
    } elsif ($arg[0] eq 'auth' && defined $arg[1]) {
	send_auth($arg[1]) if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'email' && defined $arg[1]) {
	my $uin = get_uin($arg[1]);
	return unless $uin;
	if ($contacts{$uin} && $contacts{$uin}{user_info_main}) {
	    call_openurl($contacts{$uin}{user_info_main}{Email}) if $contacts{$uin}{user_info_main}{Email};
	}
    } elsif ($arg[0] eq 'add' && defined $arg[1]) {
	shift @arg;
	foreach (@arg) {
	    next unless $_ =~ /^[0-9]+$/;
	    add_uin($_);
	    output "%B>>%n Added UIN ".$_." to contact list";
	}
	send_contacts() if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'del' && defined $arg[1]) {
	shift @arg;
	foreach (@arg) {
	    next unless $_ =~ /^[0-9]+$/;
	    del_uin($_);
	    output "%B>>%n Removed UIN ".$_." from contact list";
	}
	send_contacts() if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'save') {
	save_contacts();
    } elsif ($arg[0] eq 'load') {
	load_contacts();
	send_contacts if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'info') {
	shift @arg;
	foreach (@arg) {
	    my $uin = get_uin($_);
	    get_userinfo($uin) if $uin;
	}
    } elsif ($arg[0] eq 'status' && defined $arg[1]) {
	set_status($arg[1]) if ($icq && $icq->{_Connected});
    } elsif ($arg[0] eq 'query' && defined $arg[1]) {
	my $uin = get_uin($arg[1]);
	start_query($uin) if $uin;
    } elsif ($arg[0] eq 'invisible') {
	my $uin = get_uin($arg[1]);
	toggle_inv_list($uin);
    } elsif ($arg[0] eq 'visible') {
        my $uin = get_uin($arg[1]);
        toggle_vis_list($uin);
    } elsif ($arg[0] eq 'hidden') {
	my $uin = get_uin($arg[1]);
	toggle_hidden($uin);
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

Irssi::settings_add_int($IRSSI{name}, 'irssiq_uin', '');
Irssi::settings_add_str($IRSSI{name}, 'irssiq_password', '');
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_debug', 0);

Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_online', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_offline', 0);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_away', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_dnd', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_occupied', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_invisible', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_show_not_available', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_short_status', 0);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_list_show_offline', 1);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_statusbar_compact', 0);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_auto_open_query', 0);

Irssi::settings_add_str($IRSSI{name}, 'irssiq_away_status', 'away');

Irssi::settings_add_bool($IRSSI{name}, 'irssiq_msg_border_in_query', 0);
Irssi::settings_add_bool($IRSSI{name}, 'irssiq_auto_reconnect', 1);

Irssi::signal_add_first('complete word', \&sig_complete_word);
Irssi::signal_add('setup saved', \&save_contacts);
Irssi::signal_add('away mode changed', \&sig_away);
Irssi::signal_add('send text', \&sig_send_text);

Irssi::statusbar_item_register('irssiq', 0, 'sb_show');

Irssi::command_bind('irssiq', \&cmd_irssiq);

foreach my $cmd ('help', 'connect', 'disconnect', 'msg', 'auth', 'email', 'save', 'load', 'add', 'del', 'info', 'status', 'query', 'url', 'invisible', 'visible', 'hidden' ) {
Irssi::command_bind('irssiq '.$cmd => sub {
		    cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
}

load_contacts();

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /irssiq help for help';
