#!/usr/bin/env perl -w
#
# This is a simple irssi script to send out notifications over the network using
# mosquitto_pub. Currently, it sends notifications when e.g. your name/nick is
# highlighted, and when you receive private messages.
# Based on jabber-notify.pl script by Peter Krenesky, Thomas Ruecker.
# Based on growl-net.pl script by Alex Mason, Jason Adams.
#
# You can find the script on GitHub: https://github.com/dm8tbr/irssi-mqtt-notify/
# Please report bugs to https://github.com/dm8tbr/irssi-mqtt-notify/issues
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
use vars qw($VERSION %IRSSI $AppName $MQTTUser $MQTTPass $MQTTServ $MQTTClient $MQTTTopic $MQTTTLS $MQTTPort $MQTTKeepalive $MQTTRetain $MQTTQoS @args  $j);

use Irssi;
use utf8;
use POSIX;
 
$VERSION = '1.0';
%IRSSI = (
  authors      =>   'Thomas B. Ruecker',
  contact      =>   'thomas@ruecker.fi, tbr on irc.freenode.net',
  name         =>   'MQTT-notify',
  description  =>   'Sends out notifications via MQTT',
  license      =>   'BSD-3-Clause',
  url          =>   'http://github.com/dm8tbr/irssi-mqtt-notify/',

);

sub cmd_mqtt_notify {
  Irssi::print('%G>>%n MQTT-notify can be configured with these settings:');
  Irssi::print('%G>>%n mqtt_show_privmsg : Notify about private messages.');
  Irssi::print('%G>>%n mqtt_reveal_privmsg : Include content of private messages in notifications.');
  Irssi::print('%G>>%n mqtt_show_hilight : Notify when your name is hilighted.');
  Irssi::print('%G>>%n mqtt_show_notify : Notify when someone on your away list joins or leaves.');
  Irssi::print('%G>>%n mqtt_show_topic : Notify about topic changes.');
  Irssi::print('%G>>%n mqtt_notify_user : Set to mqtt account to send from.');
  Irssi::print('%G>>%n mqtt_notify_topic : Set to mqtt topic to publish message to.');;
  Irssi::print('%G>>%n mqtt_notify_server : Set to the mqtt server host name.');
  Irssi::print('%G>>%n mqtt_notify_pass : Set to the sending accounts jabber password.');
  Irssi::print('%G>>%n mqtt_notify_tls : Set to enable TLS connection to mqtt server. [not implemented]');
  Irssi::print('%G>>%n mqtt_notify_port : Set to the mqtt server port number.');
  Irssi::print('%G>>%n mqtt_notify_qos : Set to the desired mqtt QoS level.');
  Irssi::print('%G>>%n mqtt_notify_retain : Set to turn the retain flag on/off.');
}

sub cmd_mqtt_notify_test {
  my $body = "Test:\nmoo!";
  my @message_args = @args;
  push(@message_args, "-m", $body);
  mosquitto_pub(@message_args);
}

Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_show_privmsg',     1);
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_reveal_privmsg',   1);
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_show_hilight',     1);
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_show_notify',      1);
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_show_topic',       1);
Irssi::settings_add_str($IRSSI{'name'},  'mqtt_notify_pass',      'password');
Irssi::settings_add_str($IRSSI{'name'},  'mqtt_notify_server',    'localhost');
Irssi::settings_add_str($IRSSI{'name'},  'mqtt_notify_user',      'irssi');
Irssi::settings_add_str($IRSSI{'name'},  'mqtt_notify_topic',     'test');
Irssi::settings_add_str($IRSSI{'name'},  'mqtt_notify_client',    'irssi_');
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_notify_tls',       0);
Irssi::settings_add_int($IRSSI{'name'},  'mqtt_notify_port',      1883);
Irssi::settings_add_int($IRSSI{'name'},  'mqtt_notify_keepalive', 120);
Irssi::settings_add_int($IRSSI{'name'},  'mqtt_notify_qos',       0);
Irssi::settings_add_bool($IRSSI{'name'}, 'mqtt_notify_retain',    0);

$MQTTUser      = Irssi::settings_get_str('mqtt_notify_user');
$MQTTPass      = Irssi::settings_get_str('mqtt_notify_pass');
$MQTTServ      = Irssi::settings_get_str('mqtt_notify_server');
$MQTTTopic     = Irssi::settings_get_str('mqtt_notify_topic');
$MQTTClient    = Irssi::settings_get_str('mqtt_notify_client');
$MQTTTLS       = Irssi::settings_get_bool('mqtt_notify_tls');
$MQTTPort      = Irssi::settings_get_int('mqtt_notify_port');
$MQTTKeepalive = Irssi::settings_get_int('mqtt_notify_keepalive');
$MQTTQoS       = Irssi::settings_get_int('mqtt_notify_qos');
$MQTTRetain    = Irssi::settings_get_bool('mqtt_notify_retain');
$AppName       = "irssi $MQTTServ";

@args = ("mosquitto_pub", "-h", $MQTTServ, "-p", $MQTTPort, "-q", $MQTTQoS, "-I", $MQTTClient, "-u", $MQTTUser, "-P", $MQTTPass, "-t", $MQTTTopic,);
if (Irssi::settings_get_bool('mqtt_notify_retain')) {
  push(@args, "-r");
}


sub sig_message_private ($$$$) {
  return unless Irssi::settings_get_bool('mqtt_show_privmsg');

  my ($server, $data, $nick, $address) = @_;

  my $body = '(Private message from: '.$nick.')';
  if ((Irssi::settings_get_bool('mqtt_reveal_privmsg'))) {
    $body = '(PM: '.$nick.")\n".$data;
  }
  $body = Irssi::strip_codes($body);
  utf8::decode($body);
  my @message_args = @args;
  push(@message_args, "-m", $body);
  mosquitto_pub(@message_args);
}

sub sig_print_text ($$$) {
  return unless Irssi::settings_get_bool('mqtt_show_hilight');

  my ($dest, $text, $stripped) = @_;

  if ($dest->{level} & MSGLEVEL_HILIGHT) {
    my $body = '['.$dest->{target}."]\n".$stripped;
    $body = Irssi::strip_codes($body);
    utf8::decode($body);
    my @message_args = @args;
    push(@message_args, "-m", $body);
    mosquitto_pub(@message_args);
  }
}

sub sig_notify_joined ($$$$$$) {
  return unless Irssi::settings_get_bool('mqtt_show_notify');

  my ($server, $nick, $user, $host, $realname, $away) = @_;

  my $body = "<$nick!$user\@$host>\nHas joined $server->{chatnet}";
  my @message_args = @args;
  push(@message_args, "-m", $body);
  mosquitto_pub(@message_args);
}

sub sig_notify_left ($$$$$$) {
  return unless Irssi::settings_get_bool('mqtt_show_notify');

  my ($server, $nick, $user, $host, $realname, $away) = @_;

  my $body = "<$nick!$user\@$host>\nHas left $server->{chatnet}";
  my @message_args = @args;
  push(@message_args, "-m", $body);
  mosquitto_pub(@message_args);
}

sub sig_message_topic {
  return unless Irssi::settings_get_bool('mqtt_show_topic');
  my($server, $channel, $topic, $nick, $address) = @_;

  my $body = 'Topic for '.$channel."\n".$topic;
  $body = Irssi::strip_codes($body);
  utf8::decode($body);
  my @message_args = @args;
  push(@message_args, "-m", $body);
  mosquitto_pub(@message_args);
}

sub mosquitto_pub {
  my @message_args = @_;
  my $pid = fork();
  if ($pid) { #This is the irssi main process we forked from
    Irssi::pidwait_add($pid);
    return;
  } elsif (defined $pid) { #This is our fork
    system(@message_args);
    POSIX::_exit($?);
  } else { #Uh, oh, bail!
    Irssi::print("Couldn't fork for mosquitto_pub!");
  }

}

Irssi::command_bind('mqtt-notify', 'cmd_mqtt_notify');
Irssi::command_bind('mqtt-test', 'cmd_mqtt_notify_test');

Irssi::signal_add_last('message private', \&sig_message_private);
Irssi::signal_add_last('print text', \&sig_print_text);
Irssi::signal_add_last('notifylist joined', \&sig_notify_joined);
Irssi::signal_add_last('notifylist left', \&sig_notify_left);
Irssi::signal_add_last('message topic', \&sig_message_topic);


Irssi::print('%G>>%n '.$IRSSI{name}.' '.$VERSION.' loaded (/mqtt-notify for help. /mqtt-test to test.)');
