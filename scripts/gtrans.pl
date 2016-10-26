#!/usr/bin/env perl -w
# vim: set sw=2 ts=2 sta et:

# GTrans: Automatic translation in Irssi using the Google Language API
# by Sven Ulland <svensven@gmail.com>. License: GPLv2
#
# DOCUMENTATION
# -------------
# Introduction:
#   This script brings the power of the Google Language API to Irssi.
#   In short, it provides a quick way to translate incoming and
#   outgoing IRC messages with minimal effort. While the result is
#   far from professional quality, it is vastly superior to most other
#   automatic translation engines.
#
# Prerequisites:
#   Better results are achieved if you write properly.
#
#   Only UTF-8 text is supported. Make sure your terminal handles it.
#
#   The WebService::Google::Language Perl module is required for the
#   script to work. It is unlikely that your system provides binary
#   packages for this module, so you probably have to install it
#   manually or through the CPAN shell:
#
#     $ perl -MCPAN -e "install WebService::Google::Language"
#
# Quick testing:
#   To quickly test the script to see what it can do, you can run the
#   following command after starting Irssi and loading the script. It
#   will translate the text and display the result in the current
#   window. No text will be sent to IRC.
#
#     /gtrans --test fi:this is a small test
#
#   Another example to translate text and send it to the target
#   (channel or query) in the currently active window:
#
#     /gtrans fi:hello! this is a small test
#
# Normal operation:
#   When loaded with default settings, the script does nothing. The
#   reason for this is to maintain privacy: It is not a good idea to
#   submit potentially sensitive information directly to Google.
#
#   Automatic translation requires that the channel or nick that sends
#   or receives the message, is in a whitelist. The following scenario
#   will enable automatic translation for the channel #mychan and nick
#   'james':
#
#     /set gtrans_my_lang en
#     /set gtrans_input_auto ON
#     /set gtrans_output_auto 2
#     /set gtrans_output_auto_lang fi
#     /set gtrans_whitelist #mychan james
#
#   Incoming or outgoing messages on the #mychan channel and queries
#   from/to james will now be automatically translated: Incoming
#   messages will be translated from any language to English; outgoing
#   messages will be translated from any language to Finnish.
#
# Settings:
#   The available settings are described below. The default value is
#   shown in parentheses.
#
#   gtrans_input_auto (ON)
#     ON:  Translate incoming messages that match gtrans_whitelist.
#          Translate to the language specified by gtrans_my_lang.
#     OFF: Don't translate incoming messages.
#
#   gtrans_show_orig (ON)
#     ON:  Show the original, untranslated message, and display the
#          translation on the next line. Applies to both incoming and
#          outgoing messages.
#     OFF: Translate messages transparently, hide original text.
#
#   gtrans_output_auto (1)
#     0:   Don't translate outgoing messages.
#     1:   Translate outgoing messages only when the text is prefixed
#          by "<lang>:". Example:  fi:this is a small test. This will
#          override the whitelist.
#     2:   Translate outgoing messages automatically to the language
#          specified by gtrans_output_auto_lang. Target has to match
#          the whitelist.
#
#   gtrans_output_auto_lang ("fi")
#     xx:  Set automatic output language to "xx". This applies to
#          automatically translated outgoing messages when
#          gtrans_output_auto is set to 2.
#
#   gtrans_my_lang ("en")
#     xx:  Space-separated list of languages that should not be
#          translated. Incoming messages will be translated to the
#          first language in this list. Note: The language will be
#          detected by sending the message to the Google API.
#
#   gtrans_debug (0)
#     0:   No debugging.
#     1:   Light debugging. Useful to see what's going on.
#     2:   Normal debugging. Slightly more verbose.
#     3:   Medium debugging. Useful for troubleshooting.
#     4:   Verbose debugging. Significant output.
#     5:   Very verbose debugging. Lots of output.
#
#   gtrans_whitelist ("")
#     xx:  Space-separated list of channels and nicks that can be
#          translated. This applies to both incoming and outgoing
#          messages. Specify "*" to whitelist everything.
#
# Links / more info:
#   List of supported languages in the Google Language API:
#     <URL:http://code.google.com/apis/ajaxlanguage/documentation/reference.html#LangNameArray>
#
#   WebService::Google::Language Perl module at CPAN:
#     <URL:http://search.cpan.org/~hma/WebService-Google-Language-0.02/lib/WebService/Google/Language.pm>
#
# TODO list:
#   * What determines the value of isreliable? The API doesn't say.
#   * Translate incoming/outgoing notices.
#   * Translate incoming/outgoing topics.
#     + Keep un-/translated topic in topic bar with a toggle.
#   * Make debugging levels and messages more consistent.
#   * Make whitelist work with servers/connections too.
#   * Interact better with logging.
#   * Better code reuse. Lots of duplication now.
#   * Verify compatibility with other scripts/themes/configurations.
#

use strict;

use vars qw($VERSION %IRSSI);
use Irssi;
$VERSION = "0.0.1";
%IRSSI = (
    authors     => "Sven Ulland",
    contact     => "svensven\@gmail.com",
    name        => "GTrans",
    description => "Translation via the Google Language API",
    license     => "GPLv2",
    url         => "http://scripts.irssi.org/",
    changed     => $VERSION,
    modules     => "WebService::Google::Language",
    commands    => "gtrans"
);

use Data::Dumper qw(Dumper);
use WebService::Google::Language;

my $service = WebService::Google::Language->new(
  "referer" => "http://scripts.irssi.org/",
  "agent"   => "$IRSSI{name} $VERSION for Irssi",
  "timeout" => 5,
  "src"     => "",
  "dest"    => "",
);

# Urgh. $glob_cmdpass is set to 1 when using gtrans_cmd() and later
# checked in event_output_msg(). The reason is that event_output_msg()
# is called twice: first by cmd_gtrans(), then by the event "send
# text".
my $glob_cmdpass = 0;

sub dbg {
  my ($level, $msg) = @_;
  return unless ($level <= Irssi::settings_get_int("gtrans_debug"));

  my %dbgcol = (
    1 => "%G",
    2 => "%Y",
    3 => "%C",
    4 => "%M",
    5 => "%R",
  );

  print CLIENTCRAP "%W$IRSSI{name} " .
                   "%Bdebug%W($dbgcol{$level}$level%W)>%n $msg";
}

sub err {
  my $msg = shift;
  print CLIENTCRAP "%W$IRSSI{name} %Rerror%W>%n $msg";
}

sub inf {
  my $msg = shift;
  print CLIENTCRAP "%W$IRSSI{name} %Ginfo%W>%n $msg";
}

sub usage {
  print CLIENTCRAP "%W$IRSSI{name} %Yusage%W>%n " .
                   "/$IRSSI{commands} [-t|--test] <lang>:<message>";
  print CLIENTCRAP "%W$IRSSI{name} %Yusage%W>%n " .
                   "Example: %W/$IRSSI{commands} fr:this message " .
                   "will be translated to french and sent to the " .
                   "currently active window.%n";
  print CLIENTCRAP "%W$IRSSI{name} %Yusage%W>%n " .
                   "Example: %W/$IRSSI{commands} -t fi:this " .
                   "message will be translated to finnish, but " .
                   "*won't* be sent out. use this to test " .
                   "translations.%n";
  print CLIENTCRAP "%W$IRSSI{name} %Yusage%W>%n " .
                   "There are several settings to modify " .
                   "translation behaviour. Type %W/set gtrans%n to " .
                   "see the available settings. See the script " .
                   "source for documentation.";
}

sub dehtml {
  # FIXME: The only HTML entity seen so far is &#39;
  $_[0] =~ s/&#39;/'/g;
}

sub wgl_process {
  my %args = @_;
  dbg(5, "wgl_process(): input %args: " . Dumper(\%args));

  my $result = $args{func}(%args);
  dbg(4, "wgl_process() wgl_func() output: " . Dumper(\$result));

  my $ok = 1;
  if ($result->error) {
    err(sprintf "wgl_process() wgl_func() code %s: %s",
        $result->code,
        $result->message);
    $ok = 0;
  }

  return $result;
}

sub event_input_msg {
  my $subname = "event_input_msg";
  my ($server, $msg, $nick, $address, $target) = @_;

  return unless Irssi::settings_get_bool("gtrans_input_auto");

  my $sig = Irssi::signal_get_emitted();
  my $witem;

  dbg(5, "$subname() args: " . Dumper(\@_));

  my $do_translation = 0;

  if ($sig eq "message private") {
    # Private message.
    $witem = Irssi::window_item_find($nick);

    # Check whether the source $nick is in the whitelist.
    dbg(3, "$subname() Looking for nick \"$nick\" in whitelist");
    foreach (split(/ /,
        Irssi::settings_get_str("gtrans_whitelist"))) {
      $do_translation = 1 if ($nick eq $_ or $_ eq "*");
    }
  } else { # $sig eq "message public"
    # Public message.
    $witem = Irssi::window_item_find($target);

    # Check whether $target is in the whitelist.
    dbg(3, "$subname() Looking for channel \"$target\" " .
           "in whitelist");
    foreach (split(/ /,
        Irssi::settings_get_str("gtrans_whitelist"))) {
      $do_translation = 1 if ($target eq $_ or $_ eq "*");
    }
  }

  unless ($do_translation) {
    dbg(1, sprintf "Channel (\"$target\") or nick (\"$nick\") is " .
                   "not whitelisted");
    return;
  }

  dbg(2, sprintf "$subname() Channel (\"$target\") or nick " .
                 "(\"$nick\") is whitelisted");

  # Prepare arguments for language detection.
  utf8::decode($msg);
  my %args = (
    "func" => sub { $service->detect(@_) },
    "text" => $msg,
  );

  # Run language detection.
  my $result = wgl_process(%args);

  dbg(4, "$subname() wgl_process() detect returned: " .
         Dumper(\$result));

  if ($result->error) {
    dbg(1, "$subname(): Language detection failed");
    err(sprintf "Language detection failed with code %s: %s",
        $result->code, $result->message);
    return;
  }

  # Don't translate my languages.
  foreach (split(/ /, Irssi::settings_get_str("gtrans_my_lang"))) {
    $do_translation = 0 if($result->language eq $_);
  }

  unless ($do_translation) {
    dbg(2, "$subname() Incoming language " .
           "\"$result->language\" matches my lang(s). " .
           "Not translating.");
    return;
  }

  dbg(1, sprintf "Detected language \"%s\", confidence %.3f",
                 $result->language, $result->confidence);

  my $confidence = $result->confidence;
  my $reliable = $result->is_reliable;

  # Prepare arguments for translation.
  my %args = (
    "func" => sub { $service->translate(@_) },
    "text" => $msg,
    "dest" => (split(/ /,
        Irssi::settings_get_str("gtrans_my_lang")))[0]
  );

  # Run translation.
  my $result = wgl_process(%args);

  dbg(4, "$subname() wgl_process() translate returned: " .
         Dumper(\$result));

  if ($result->error) {
    dbg(1, "Translation failed");
    err(sprintf "Translation failed with code %s: %s",
        $result->code, $result->message);
    return;
  }

  if (Irssi::settings_get_bool("gtrans_show_orig")) {
    my $trmsg = sprintf "[%%B%s%%n:%s%.2f%%n] %s",
        $result->language,
        $reliable ? "%g" : "%r",
        $confidence,
        $result->translation;
    utf8::decode($trmsg);
    dehtml($trmsg);

    Irssi::signal_continue($server, $msg, $nick, $address, $target);
    $witem->print($trmsg, MSGLEVEL_CLIENTCRAP);
  }
  else {
    $msg = sprintf "[%s:%.2f] %s",
        $result->language,
        $confidence,
        $result->translation;
    utf8::decode($msg);
    dehtml($msg);

    Irssi::signal_continue($server, $msg, $nick, $address, $target);
  }

  dbg(1, "Incoming translation successful");
}

sub event_output_msg {
  my $subname = "event_output_msg";
  my ($msg, $server, $witem, $force_lang) = @_;

  dbg(5, "$subname() args: " . Dumper(\@_));

  # Safeguard to stop double translations when using /gtrans.
  if ($glob_cmdpass) {
    $glob_cmdpass = 0;
    Irssi::signal_continue($msg, $server, $witem);
    return;
  }

  return unless (
      (Irssi::settings_get_int("gtrans_output_auto") > 0 and
       Irssi::settings_get_int("gtrans_output_auto") <= 2)
         or $force_lang);

  # Determine destination language before doing translation.
  my $dest_lang;
  if($force_lang) {
    $dest_lang = $force_lang;
  }
  elsif (Irssi::settings_get_int("gtrans_output_auto") eq 1) {
    # Semiauto translation. Here we preprocess the msg to determine
    # destination language. The WGL API cannot fetch the list of valid
    # languages, so we simply try to see if the language is valid.
    if ( $msg =~ /^([a-z]{2}(-[a-z]{2})?):(.*)/i) {
      dbg(2, "$subname() dest_lang \"$1\", msg \"$3\"");
      $dest_lang = $1;
      $msg = $3;
    }
  }
  elsif (Irssi::settings_get_int("gtrans_output_auto") eq 2) {
    # Fully automated translation.
    # To avoid accidents, verify that $witem->{name} is whitelisted.
    dbg(3, "$subname() Looking for target \"" .
           $witem->{name} . "\" in whitelist");

    my $do_translation = 0;
    foreach (split(/ /,
        Irssi::settings_get_str("gtrans_whitelist"))) {
      $do_translation = 1 if ($witem->{name} eq $_);
      $do_translation = 1 if ($_ eq "*");
    }

    unless ($do_translation) {
      dbg(1, sprintf "Target \"" . $witem->{name} . "\" is " .
                     "not whitelisted");
      return;
    }

    dbg(2, sprintf "$subname() Target \"" . $witem->{name} .
                   "\" is whitelisted");
    $dest_lang = Irssi::settings_get_str("gtrans_output_auto_lang");
  }

  unless ($dest_lang and $msg) {
    dbg(1, "Empty destination language or message");
    return;
  }

  # Prepare arguments for translation.
  utf8::decode($msg);
  my %args = (
    "func" => sub { $service->translate(@_) },
    "text" => $msg,
    "dest" => $dest_lang
  );

  # Run translation.
  my $result = wgl_process(%args);

  dbg(4, "$subname() wgl_process() output: " .
         Dumper(\$result));

  if ($result->error) {
    dbg(1, "$subname() Translation failed");
    err(sprintf "Translation failed with code %s: %s",
        $result->code, $result->message);
    return;
  }

  my $trmsg;
  if ($result->language ne $dest_lang) {
    $trmsg = $result->translation;
    utf8::decode($trmsg);
    dehtml($trmsg);
  }

  if($force_lang) {
    # Emit new signal, since we came from cmd_gtrans().
    $glob_cmdpass = 1; # Don't translate in event_output_msg()
    dbg(3, "$subname():" . __LINE__ .
           " Emitting \"send text\" signal");
    Irssi::signal_emit("send text", $trmsg, $server, $witem);
    return;
  }

  Irssi::signal_continue($trmsg, $server, $witem);

  if (Irssi::settings_get_bool("gtrans_show_orig")) {
    my $origmsg = sprintf "[orig:%%B%s%%n] %s",
        $result->language,
        $msg;
    $witem->print($origmsg, MSGLEVEL_CLIENTCRAP);
  }

  dbg(1, "Outbound auto-translation successful");
}

# FIXME: While topic translation is implemented, it needs more work to
# be useful. Until it is, the code is not active.
#sub event_topic {
#  # signal "message own_public" parameters:
#  # my ($server, $channel, $topic, $nick, $target) = @_;
#
#  return unless Irssi::settings_get_bool("gtrans_topic_auto");
#
#  dbg(5, "event_topic() args: " . Dumper(\@_));
#
#  my ($server, $channel, $msg, $nick, $target) = @_;
#
#  my $do_translation = 0;
#
#  # Check whether $channel is in the whitelist.
#  dbg(3, "event_topic() Looking for channel \"$channel\" in " .
#         "whitelist");
#  foreach (split(/ /,
#      Irssi::settings_get_str("gtrans_whitelist"))) {
#    $do_translation = 1 if ($channel eq $_);
#    $do_translation = 1 if ($_ eq "*");
#  }
#
#  unless ($do_translation) {
#    dbg(1, sprintf "Channel $channel is not whitelisted. " .
#                   "Not translating topic");
#    return;
#  }
#
#  dbg(2, sprintf "event_topic() Channel $channel is whitelisted");
#
#  # Prepare arguments for language detection.
#  utf8::decode($msg);
#  my %args = (
#    "func" => sub { $service->detect(@_) },
#    "text" => $msg,
#  );
#
#  # Run language detection.
#  my $result = wgl_process(%args);
#
#  dbg(4, "event_topic() wgl_process() detect returned: " .
#         Dumper(\$result));
#
#  if ($result->error) {
#    dbg(1, "event_topic(): Language detection failed");
#    err(sprintf "Language detection failed with code %s: %s",
#        $result->code, $result->message);
#    return;
#  }
#
#  # Don't translate my languages.
#  foreach (split(/ /, Irssi::settings_get_str("gtrans_my_lang"))) {
#    $do_translation = 0 if($result->language eq $_);
#  }
#
#  unless ($do_translation) {
#    dbg(2, "event_topic() Incoming language " .
#           "\"$result->language\" matches my lang(s). " .
#           "Not translating.");
#    return;
#  }
#
#  dbg(1, sprintf "Detected language \"%s\", confidence %.3f",
#                 $result->language, $result->confidence);
#
#  my $confidence = $result->confidence;
#
#  # Prepare arguments for translation.
#  my %args = (
#    "func" => sub { $service->translate(@_) },
#    "text" => $msg,
#    "dest" => (split(/ /,
#        Irssi::settings_get_str("gtrans_my_lang")))[0]
#  );
#
#  # Run translation.
#  my $result = wgl_process(%args);
#
#  dbg(4, "event_topic() wgl_process() translate returned: " .
#         Dumper(\$result));
#
#  if ($result->error) {
#    dbg(1, "Topic translation failed");
#    err(sprintf "Topic translation failed with code %s: %s",
#        $result->code, $result->message);
#    return;
#  }
#
#  # FIXME: Don't alter messages!
#  $msg = sprintf "[%s:%.2f] %s",
#      $result->language, $confidence, $result->translation;
#
#  utf8::decode($msg);
#  dehtml($msg);
#
#  # FIXME: More info about result?
#  dbg(1, "Incoming topic translation successful");
#
#  Irssi::signal_continue($server, $channel, $msg, $nick, $target);
#}

sub cmd_gtrans {
  my $subname = "cmd_gtrans";
  my ($msg, $server, $witem) = @_;

  dbg(5, "$subname() input: " . Dumper(\@_));

  if ($msg =~ /^(|help|-h|--help|-t|--test)$/) {
    usage();
    return;
  }

  my $testing_mode = 0;
  if ($msg =~ /^(-t|--test) /) {
    $testing_mode = 1;
    $msg =~ s/^(-t|--test) //;
  }

  return unless ($testing_mode or
                    ($witem and
                        ($witem->{type} eq "CHANNEL" or
                         $witem->{type} eq "QUERY")));

  # Determine destination language before doing translation.
  my $dest_lang;

  # FIXME: What about languages on the form "xx-yy"?
  if ( $msg =~ /^([a-z]{2}):(.*)/i) {
    dbg(2, "$subname() dest_lang \"$1\", msg \"$2\"");
    $dest_lang = $1;
    $msg = $2;
  } else {
    dbg(2, "$subname() syntax error");
  }

  unless ($dest_lang and $msg) {
    err("Empty destination language or message");
    usage();
    return;
  }

  if ($testing_mode) {
    # Prepare arguments for translation.
    utf8::decode($msg);
    my %args = (
      "func" => sub { $service->translate(@_) },
      "text" => $msg,
      "dest" => $dest_lang
    );

    # Run translation.
    my $result = wgl_process(%args);

    dbg(4, "$subname() wgl_process() output: " . Dumper(\$result));

    if ($result->error) {
      dbg(1, "$subname(): Translation failed");
      err(sprintf "Translation failed with code %s: %s",
          $result->code, $result->message);
      return;
    }

    $msg = $result->translation;
    utf8::decode($msg);
    dehtml($msg);

    dbg(1, "Outbound translation successful");

    $witem = Irssi::active_win();
    $witem->print(sprintf
        ("%%GGTrans test (%%B%s%%n->%%B%s%%G):%%n %s",
        $result->language,
        $dest_lang,
        $msg), MSGLEVEL_CLIENTCRAP);
  }
  else {
    event_output_msg($msg, $server, $witem, $dest_lang);
  }
}

print CLIENTCRAP "%W$IRSSI{name} loaded. " .
                 "Hints: %n/$IRSSI{commands} help";

# Register gtrans settings.
Irssi::settings_add_bool("gtrans", "gtrans_input_auto",          1);
#Irssi::settings_add_bool("gtrans", "gtrans_topic_auto",          0);
Irssi::settings_add_bool("gtrans", "gtrans_show_orig",           1);
Irssi::settings_add_int ("gtrans", "gtrans_output_auto",         1);
Irssi::settings_add_str ("gtrans", "gtrans_output_auto_lang", "fi");
Irssi::settings_add_str ("gtrans", "gtrans_my_lang",          "en");
Irssi::settings_add_int ("gtrans", "gtrans_debug",               0);
Irssi::settings_add_str ("gtrans", "gtrans_whitelist",          "");

# Register /gtrans command.
Irssi::command_bind("gtrans",                         "cmd_gtrans");

# Register events for incoming messages/actions.
Irssi::signal_add_last("message public",         "event_input_msg");
Irssi::signal_add_last("message private",        "event_input_msg");

# Register events for outgoing messages/actions.
Irssi::signal_add("send text",                  "event_output_msg");

#TODO: Register events that need special handling.
#Irssi::signal_add("message irc action",          "event_input_msg");
#Irssi::signal_add("message irc notice",          "event_input_msg");
#Irssi::signal_add("message irc own_action",     "event_output_msg");
#Irssi::signal_add("message irc own_notice",     "event_output_msg");
#Irssi::signal_add("event topic",                     "event_topic");
