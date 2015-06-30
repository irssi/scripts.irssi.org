#!/usr/bin/env perl -w
#
# This is a simple irssi script to send out notifications over the network using
# Net::Jabber. Currently, it sends notifications when e.g. your name/nick is
# highlighted, and when you receive private messages.
# Based on growl-net.pl script by Alex Mason, Jason Adams.
#
# You can find the script on GitHub: https://github.com/dm8tbr/irssi-xmpp-notify/
# Please report bugs to https://github.com/dm8tbr/irssi-xmpp-notify/issues
#
# Copyright (c) 2015, Thomas B. Ruecker
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived from this
# software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

use strict;
use vars qw($VERSION %IRSSI $AppName $XMPPUser $XMPPPass $XMPPDomain $XMPPServ $XMPPRes $XMPPRecv $XMPPTLS $XMPPCAPath $XMPPPort $XMPPDebugFile $testing $Connection $j);

use Irssi;
use Net::Jabber qw( Client );
use utf8;
 
$VERSION = '1.0';
%IRSSI = (
  authors      =>   'Thomas B. Ruecker',
  contact      =>   'thomas@ruecker.fi, tbr on irc.freenode.net',
  name         =>   'XMPP-notify',
  description  =>   'Sends out notifications via XMPP. Based on a script by Peter Krenesky.',
  license      =>   'BSD-3-Clause',
  url          =>   'http://github.com/dm8tbr/irssi-xmpp-notify/',

);

sub cmd_xmpp_notify {
  Irssi::print('%G>>%n XMPP-notify can be configured with these settings:');
  Irssi::print('%G>>%n xmpp_show_privmsg : Notify about private messages.');
  Irssi::print('%G>>%n xmpp_reveal_privmsg : Include content of private messages in notifications.');
  Irssi::print('%G>>%n xmpp_show_hilight : Notify when your name is hilighted.');
  Irssi::print('%G>>%n xmpp_show_notify : Notify when someone on your away list joins or leaves.');
  Irssi::print('%G>>%n xmpp_show_topic : Notify about topic changes.');
  Irssi::print('%G>>%n xmpp_notify_user : Set to xmpp account user name to send notifications from.');
  Irssi::print('%G>>%n xmpp_notify_recv : Set to xmpp JID to receive notification messages.');;
  Irssi::print('%G>>%n xmpp_notify_server : Set to the xmpp server host name');
  Irssi::print('%G>>%n xmpp_notify_pass : Set to the sending xmpp account password');
  Irssi::print('%G>>%n xmpp_notify_tls : Set to enable TLS connection to xmpp server');
  Irssi::print('%G>>%n xmpp_notify_ca_path : Set if you need a custom CA search path for TLS');
  Irssi::print('%G>>%n xmpp_notify_port : Set to the xmpp server port number');
  Irssi::print('%G>>%n xmpp_notify_domain : Set to the xmpp domain name if different from server name');
  Irssi::print('%G>>%n xmpp_notify_debug_file : If set, debug output from Net::Jabber will be written to this file. Needs reload.');
}

sub cmd_xmpp_notify_test {
  my $message = new Net::Jabber::Message();
  my $body = 'moo!';
  $message->SetMessage(to=>$XMPPRecv);
  $message->SetMessage(
    type=>"chat",
    body=> $body );
  $Connection->Send($message);

}

Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_show_privmsg',      1);
Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_reveal_privmsg',    1);
Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_show_hilight',      1);
Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_show_notify',       1);
Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_show_topic',        1);
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_pass',       'password');
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_server',     'localhost');
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_user',       'irssi');
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_domain',     undef);
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_recv',       'noone');
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_res',        '');
Irssi::settings_add_bool($IRSSI{'name'}, 'xmpp_notify_tls',        1);
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_ca_path',    '/etc/ssl/certs');
Irssi::settings_add_int($IRSSI{'name'},  'xmpp_notify_port',       5222);
Irssi::settings_add_str($IRSSI{'name'},  'xmpp_notify_debug_file', undef);

$XMPPUser       = Irssi::settings_get_str('xmpp_notify_user');
$XMPPPass       = Irssi::settings_get_str('xmpp_notify_pass');
$XMPPDomain     = Irssi::settings_get_str('xmpp_notify_domain');
$XMPPServ       = Irssi::settings_get_str('xmpp_notify_server');
$XMPPRecv       = Irssi::settings_get_str('xmpp_notify_recv');
$XMPPRes        = Irssi::settings_get_str('xmpp_notify_res');
$XMPPTLS        = Irssi::settings_get_bool('xmpp_notify_tls');
$XMPPCAPath     = Irssi::settings_get_str('xmpp_notify_ca_path');
$XMPPPort       = Irssi::settings_get_int('xmpp_notify_port');
$XMPPDebugFile  = Irssi::settings_get_str('xmpp_notify_debug_file');
$AppName        = "irssi $XMPPServ";

if (!$XMPPDomain)
{
  $XMPPDomain = $XMPPServ;
}

if (!$XMPPRecv)
{
  $XMPPRecv = $XMPPUser.'@'.$XMPPDomain;
}

if ($XMPPDebugFile)
{
  $Connection = Net::Jabber::Client->new(
    "debuglevel" => 2,
    "debugfile"  => $XMPPDebugFile,
    "debugtime"  => 1);
}
else
{
  $Connection = Net::Jabber::Client->new();
}

my $status = $Connection->Connect(
  "hostname" => $XMPPServ,
  "port" => $XMPPPort,
  "componentname" => $XMPPDomain,
  "tls" => $XMPPTLS,
  "ssl_ca_path" => $XMPPCAPath );



if (!(defined($status)))
{
  Irssi::print("ERROR:  XMPP server is down or connection was not allowed.");
  Irssi::print ("        ($!)");
  return;
}


my @result = $Connection->AuthSend(
  "username" => $XMPPUser,
  "password" => $XMPPPass,
  "resource" => $XMPPRes );



if ($result[0] ne "ok")
{
  Irssi::print("ERROR: Authorization failed ($XMPPUser".'@'."$XMPPDomain on server $XMPPServ) : $result[0] - $result[1]");
  return;
}
Irssi::print ("Logged into server $XMPPServ as $XMPPUser".'@'."$XMPPDomain. Sending notifications to $XMPPRecv.");

sub sig_message_private ($$$$) {
  return unless Irssi::settings_get_bool('xmpp_show_privmsg');

  my ($server, $data, $nick, $address) = @_;

  my $message = new Net::Jabber::Message();
  my $body = '(Private message from: '.$nick.')';
  if ((Irssi::settings_get_bool('xmpp_reveal_privmsg'))) {
    $body = '(PM: '.$nick.') '.$data;
  }
  $body = Irssi::strip_codes($body);
  utf8::decode($body);
  $message->SetMessage(to=>$XMPPRecv);
  $message->SetMessage(
    type=>"chat",
    body=> $body );
  $Connection->Send($message);

}

sub sig_print_text ($$$) {
  return unless Irssi::settings_get_bool('xmpp_show_hilight');

  my ($dest, $text, $stripped) = @_;

  if ($dest->{level} & MSGLEVEL_HILIGHT) {
    my $message = new Net::Jabber::Message();
    my $body = '['.$dest->{target}.'] '.$stripped;
    $body = Irssi::strip_codes($body);
    utf8::decode($body);
    $message->SetMessage(to=>$XMPPRecv);
    $message->SetMessage(
      type=>"chat",
      body=> $body );
    $Connection->Send($message);
  }
}

sub sig_notify_joined ($$$$$$) {
  return unless Irssi::settings_get_bool('xmpp_show_notify');

  my ($server, $nick, $user, $host, $realname, $away) = @_;

  my $message = new Net::Jabber::Message();
  my $body = "<$nick!$user\@$host>\nHas joined $server->{chatnet}";
  $message->SetMessage(to=>$XMPPRecv);
  $message->SetMessage(
    type=>"chat",
    body=> $body );
  $Connection->Send($message);

}

sub sig_notify_left ($$$$$$) {
  return unless Irssi::settings_get_bool('xmpp_show_notify');

  my ($server, $nick, $user, $host, $realname, $away) = @_;

  my $message = new Net::Jabber::Message();
  my $body = "<$nick!$user\@$host>\nHas left $server->{chatnet}";
  $message->SetMessage(to=>$XMPPRecv);
  $message->SetMessage(
    type=>"chat",
    body=> $body );
  $Connection->Send($message);
}

sub sig_message_topic {
  return unless Irssi::settings_get_bool('xmpp_show_topic');
  my($server, $channel, $topic, $nick, $address) = @_;

  my $message = new Net::Jabber::Message();
  my $body = 'Topic for '.$channel.': '.$topic;
  $body = Irssi::strip_codes($body);
  utf8::decode($body);
  $message->SetMessage(to=>$XMPPRecv);
  $message->SetMessage(
    type=>"chat",
    body=> $body );
  $Connection->Send($message);
}


Irssi::command_bind('xmpp-notify', 'cmd_xmpp_notify');
Irssi::command_bind('xmpp-test', 'cmd_xmpp_notify_test');

Irssi::signal_add_last('message private', \&sig_message_private);
Irssi::signal_add_last('print text', \&sig_print_text);
Irssi::signal_add_last('notifylist joined', \&sig_notify_joined);
Irssi::signal_add_last('notifylist left', \&sig_notify_left);
Irssi::signal_add_last('message topic', \&sig_message_topic);


Irssi::print('%G>>%n '.$IRSSI{name}.' '.$VERSION.' loaded (/xmpp-notify for help. /xmpp-test to test.)');

