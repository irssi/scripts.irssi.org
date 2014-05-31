# Quizmaster.pl de Stefan "tommie" Tomanek (stefan@pico.ruhr.de)
# Traduit par Pec (monsieur.pec@gmail.fr) en français
use strict;

use vars qw($VERSION %IRSSI);
$VERSION = '20030208+fr';
%IRSSI = (
	   authors     => 'Stefan \'tommie\' Tomanek',
	   contact     => 'stefan@pico.ruhr.de',
	   name        => 'quizmaster',
	   description => 'Un script de quiz pour irssi',
	   license     => 'GPLv2',
	   url         => 'http://irssi.org/scripts/ http://pierre.carlot.free.fr/tux/',
	   changed     =>  $VERSION,
	   modules     => 'Data::Dumper',
	   commands    => "quizmaster",
	   traduction  => 'pec'
);

use Irssi;
use Data::Dumper;

use vars qw(%sessions %questions);

sub show_help() {
    my $help = "quizmaster $VERSION
/quizmaster
    Liste les sessions en cours
/quizmaster import <nom> <fichier>
    Importe une base de données (au formatmoxxquiz)
/quizmaster save
    Sauvegarde les questions importées dans la base de données
/quizmaster start <db1> <db2>...
    Commence une nouvelle partie dans le salon courrant avec la base de donnnées nommée. Si vous ne mentionnez pas de db, elles seront toutes prises par défaut.
/quizmaster score
    Affiche la table des scores de la partie en cours
/quizmaster hint <nombre>
   Donne le nombre d'indice
";
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("Quizmaster", $text, "quizmaster help", 1);
}

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

sub save_quizfile {
    local *F;
    my $filename = Irssi::settings_get_str("quizmaster_questions_file");
    open(F, ">".$filename);
    my $dumper = Data::Dumper->new([\%questions], ['quest']);
    $dumper->Purity(1)->Deepcopy(1);
    my $data = $dumper->Dump;
    print (F $data);
    close(F);
    print CLIENTCRAP '%R>>%n Quizmaster, questions sauvegardées dans '.$filename;
}

sub load_quizfile ($) {
    my ($file) = @_;
    no strict 'vars';
    return unless -e $file;
    my $text;
    local *F;
    open F, $file;
    $text .= $_ foreach (<F>);
    close F;
    return unless "$text";
    %questions = %{ eval "$text" };
}

sub import_quizfile ($$) {
    my ($name, $file) = @_;
    local *F;
    open(F, $file);
    my @data = <F>;
    my @questions;
    my $quest = {};
    foreach (@data) {
	if (/^(.*?): (.*?)$/) {
	    my $item = $1;
	    my $desc = $2;
	    if ($item eq 'Question') {
		$quest->{question} = $desc;
	    } elsif ($item eq 'Category') {
		$quest->{category} = $desc;
	    } elsif ($item eq 'Answer') {
		my $answer = $desc;
		if ($answer =~ /(.*?)#(.*?)#(.*?)$/) {
		    $answer = '';
		    $answer .= '('.$1.')?' if ($1);
		    $answer .= $2;
		    $answer .= '('.$3.')?' if ($3);
		}
		push @{$quest->{answers}}, $answer;
	    } elsif ($item eq 'Regexp') {
		push @{$quest->{answers}}, $desc;
	    }
	} elsif (/^$/) {
	    if (defined $quest->{question} && defined $quest->{answers}) {
		push @questions, $quest;
		$quest = {};
	    }
	}
    }
    $questions{$name} = \@questions;
    print CLIENTCRAP "%R>>>%n ".scalar(@questions)." Les questions ont étées importées depuis ".$file;
}

sub add_questions ($$) {
    my ($target, $name) = @_;
    push @{$sessions{$target}{questions}}, $name;
}

sub ask_question ($) {
    my ($target) = @_;
    my ($database, $current) = @{$sessions{$target}{current}};
    my $question = $questions{$database}->[$current]{question};
    my $category = '';
    $category = '['.$questions{$database}->[$current]{category}.']' if defined $questions{$database}->[$current]{category};
    line2target($target, '>>> '.$category.' '.$question);
}

sub start_quiz ($) {
    my ($channel) = @_;
    line2target($channel, '>>>> Un nouveau quiz vient de débuter. <<<<');
    new_question($channel);
}

sub stop_quiz ($) {
    my ($target) = @_;
    show_scores($target);
    line2target($target, '>>>> Le quiz est arrêté. <<<<');
    delete $sessions{$target};
}

sub event_public_message ($$$$) {
    my ($server, $text, $nick, $address, $target) = @_;
    check_answer($nick, $text, $target) if defined $sessions{$target} and $sessions{$target}{asking};
}

sub event_message_own_public ($$$) {
    my ($server, $msg, $target, $otarget) = @_;
    check_answer($server->{nick}, $msg, $target) if defined $sessions{$target} and $sessions{$target}{asking};
}

sub check_answer ($$$) {
    my ($nick, $text, $target) = @_;
    my ($database, $answer) = @{$sessions{$target}{current}};
    my @answers = @{$questions{$database}->[$answer]{answers}};
    foreach (@answers) {
	my $regexp = $_;
	if ($text =~ /$regexp/i) {
	    $sessions{$target}{asking} = 0;
	    solved_question($nick, $target);
	    last;
	}
    }
}

sub solved_question ($$) {
    my ($nick, $target) = @_;
    line2target($target, '<<< '.$nick.' a correctement répondu(e) à la question');
    my $witem = Irssi::window_item_find($target);
    $sessions{$target}{score}{$nick}++;
    my $max_points = Irssi::settings_get_int('quizmaster_points_to_win');
    if ($sessions{$target}{score}{$nick} >= $max_points) {
	line2target($target, '>>> '.$nick.' a '.$sessions{$target}{score}{$nick}.' points et gagne la partie.');
	stop_quiz($target);
    } else {
	$sessions{$target}{solved} = 1;
	$sessions{$target}{next} = time();
    }
}

sub new_question ($) {
    my ($target) = @_;
    $sessions{$target}{solved} = 0;
    my $d_num = int( (scalar(@{$sessions{$target}{questions}})-1)*rand() );
    my $database = $sessions{$target}{questions}->[$d_num];
    my $new_question = int(scalar(@{$questions{$database}})*rand());
    $sessions{$target}{current} = [$database, $new_question];
    $sessions{$target}{timestamp} = time();
    ask_question($target);
    $sessions{$target}{asking} = 1;
}

sub expire_questions {
    foreach my $target (keys %sessions) {
	my $expire = Irssi::settings_get_int('quizmaster_timeout');
	my $pause = Irssi::settings_get_int('quizmaster_pause');
	if ($sessions{$target}{timestamp}+$expire <= time()) {
	    line2target($target, '>>> Pas de bonne réponse durant les '.$expire.' secondes imparties.');
	    new_question($target);
	} else {
	    my $left = ($sessions{$target}{timestamp}+$expire)-time();
	    #line2target($target, ' >>>> '.$left.' seconds left');
	}
	if ($sessions{$target}{solved} && $sessions{$target}{next}+$pause <= time()) {
	    new_question($target);
	}
    }
}

sub give_hint ($$) {
    my ($target, $level) = @_;
    my $database = $sessions{$target}{current}->[0];
    my $current = $sessions{$target}{current}->[1];
    my $answer = $questions{$database}->[$current]{answers}->[0];
    my $tip;
    # remove RegExp stuff
    $answer =~ s/\(//g;
    $answer =~ s/\)//g;
    $answer =~ s/\?//g;
    foreach (0..length($answer)-1) {
	if (substr($answer, $_, 1) eq ' ') {
	    $tip .= ' ';
	} else {
	    $tip .= '_';
	}
    }
    foreach (0..$level) {
	my $pos = int( rand()*(length($answer)-1) );
	my $char = substr($answer, $pos, 1);
	my $pre = substr($tip, 0, $pos);
	my $post = substr($tip, $pos+1);
	$tip = $pre.$char.$post;
    }
    return $tip;
}

sub line2target ($$) {
    my ($target, $line) = @_;
    my $witem = Irssi::window_item_find($target);
    $witem->{server}->command('MSG '.$target.' '.$line);
    #$witem->print('MSG '.$target.' '.$line);
}

sub show_scores ($) {
    my ($target) = @_;
    my $table;
    foreach (sort {$sessions{$target}{score}{$b} <=> $sessions{$target}{score}{$a}} keys(%{$sessions{$target}{score}})) {
	 $table .= "$_ a ".$sessions{$target}{score}{$_}." points.\n";
    }
    my $box = draw_box('Quizmaster pour Irssi', $table, 'score', 0);
    line2target($target, $_) foreach (split(/\n/, $box));
}

sub list_databases {
    my $msg;
    my $sum = 0;
    foreach (sort keys %questions) {
	$msg .= '%U'.$_.'%U '."\n";
	$msg .= ' '.scalar(@{$questions{$_}}).' questions disponibles'."\n";
	$sum += scalar(@{$questions{$_}});
    }
    $msg .= '|'."\n";
    $msg .= '`===> '.$sum.' questions au total'."\n";
    print CLIENTCRAP &draw_box("Quizmaster", $msg, "databases", 1);
}

sub list_sessions {
    my $msg;
    foreach (sort keys %sessions) {
        $msg .= '`->%U'.$_.'%U '."\n";
        $msg .= '     '.scalar(keys %{$sessions{$_}{score}}).' users scored.'."\n";
    }
    print CLIENTCRAP &draw_box("Quizmaster", $msg, "sessions", 1);
}

sub event_nicklist_changed ($$$) {
    my ($channel, $nick, $oldnick) = @_;
    my $target = $channel->{name};
    return unless (defined $sessions{$target} && $sessions{$target}{score}{$oldnick});
    my $points = $sessions{$target}{score}{$oldnick};
    $sessions{$target}{score}{$nick->{nick}} = $points;
    delete $sessions{$target}{score}{$oldnick};
}

sub init {
    my $filename = Irssi::settings_get_str('quizmaster_questions_file');
    load_quizfile($filename);
}

sub cmd_quizmaster ($$$) {
    my ($args, $server, $witem) = @_;
    my @arg = split(/ /, $args);
    if (scalar(@arg) == 0) {
	list_sessions();
    } elsif ($arg[0] eq 'import') {
	import_quizfile($arg[1], $arg[2]);
    } elsif ($arg[0] eq 'save') {
	save_quizfile();
    } elsif ($arg[0] eq 'load') {
	init();
    } elsif ($arg[0] eq 'start') {
	shift(@arg);
	if (scalar @arg == 0) {
	    add_questions($witem->{name}, $_) foreach (keys %questions);
	} else {
	    foreach (@arg) {
		add_questions($witem->{name}, $_) if defined $questions{$_};
	    }
	}
	start_quiz($witem->{name});
    } elsif ($arg[0] eq 'stop') {
	stop_quiz($witem->{name});
    } elsif ($arg[0] eq 'score') {
	show_scores($witem->{name}) if defined $sessions{$witem->{name}};
    } elsif ($arg[0] eq 'next') {
	new_question($witem->{name}) if defined $sessions{$witem->{name}};
    } elsif ($arg[0] eq 'hint') {
	line2target($witem->{name}, give_hint($witem->{name}, $arg[1]));
    } elsif ($arg[0] eq 'list') {
	list_databases;
    } elsif ($arg[0] eq 'help') {
	show_help();
    }
}

Irssi::command_bind($IRSSI{'name'}, \&cmd_quizmaster);
foreach my $cmd ('import', 'load', 'save', 'list', 'help', 'next', 'hint', 'score', 'stop', 'start') {
Irssi::command_bind('quizmaster '.$cmd => sub {
                    cmd_quizmaster("$cmd ".$_[0], $_[1], $_[2]); });
}


Irssi::settings_add_int($IRSSI{'name'}, 'quizmaster_points_to_win', 20);
Irssi::settings_add_int($IRSSI{'name'}, 'quizmaster_timeout', 60);
Irssi::settings_add_int($IRSSI{'name'}, 'quizmaster_pause', 10);
Irssi::settings_add_str($IRSSI{'name'}, 'quizmaster_questions_file', "$ENV{HOME}/.irssi/quizmaster_questions");

Irssi::signal_add('message public', 'event_public_message');
Irssi::signal_add('message own_public', 'event_message_own_public');
Irssi::signal_add('nicklist changed', 'event_nicklist_changed');


Irssi::timeout_add(5000, 'expire_questions', undef);

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /quizmaster help pour obtenir une aide';

init();
