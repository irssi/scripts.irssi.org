use Irssi;
use LWP::UserAgent;
use JSON::PP;
use strict;
use warnings;

our $VERSION = "0.1";
our %IRSSI = (
  authors     => 'terminaldweller',
  contact     => 'https://terminaldweller.com',
  name        => 'tongueworm',
  description => 'rewrites the input line using openai chatgpt',
  license     => 'GPL3 or newer',
  url         => 'https://github.com/irssi/scripts.irssi.org',
);

# adds the tongueworm command. the default question will just rephrase your input line
# while keeping the language the same. technically you can ask it to even translate it.
# you can bind the function like so:
# /bind ^R command tongueworm
# the above bind the command to ctrl-r. please note that if you're using vim_mode,
# then the command will only bind in INSERT mode. if you want in NORMAL mode use
# the facilities vim_mode provides to bind the function.
# settings settable by the user:
# /set wormtongue_openai_api_key XXXXXXXXXXXX
# /set wormtongue_model gpt-3.5-turbo
# /set wormtongue_role user
# /set wormtongue_temperature 700
# the temperature value is divided by 1000, so a value of 700 would become 700/1000, i.e. 0.7
# /set wormtongue_debug 0
# /set wormtongue_request my_awesome_request
# NOTE: if we get a good FOSS and or self-hosted option in the future, we can switch to that.
# if you find one let me know.
Irssi::settings_add_str('misc','wormtongue_openai_api_key', '');
Irssi::settings_add_str('misc','wormtongue_model', 'gpt-3.5-turbo');
Irssi::settings_add_str('misc','wormtongue_role', 'user');
Irssi::settings_add_int('misc','wormtongue_temperature', 700);
Irssi::settings_add_bool('misc','wormtongue_debug', 0);
Irssi::settings_add_str('misc', 'wormtongue_request', 'rephrase the sentence that comes after the question mark and dont change its language?');

sub wormtongue {
    my $debug = Irssi::settings_get_bool('wormtongue_debug');
    my $ua = LWP::UserAgent->new;
    my $server_endpoint = "https://api.openai.com/v1/chat/completions";
    my $req = HTTP::Request->new(POST => $server_endpoint);
    $req->header('Content-Type'=>'application/json');
    my $openai_api_key = Irssi::settings_get_str('wormtongue_openai_api_key');
    $req->header('Authorization'=>"Bearer $openai_api_key");
    my $ai_model = Irssi::settings_get_str('wormtongue_model');
    my $ai_role = Irssi::settings_get_str('wormtongue_role');
    my $ai_temp = Irssi::settings_get_int('wormtongue_temperature')/1000;
    my $question = Irssi::settings_get_str('wormtongue_request');
    my $content = $question.Irssi::parse_special('$L', 0, 0);
    my $post_data = '{"model" : "'.$ai_model.'", "temperature" : '.$ai_temp.', "messages" : [{"role" : "'.$ai_role.'","content" : "'.$content.'"}]}';
    Irssi::print($post_data) if ($debug == 1);

    $req->content($post_data);
    my $resp = $ua->request($req);
    Irssi::print($resp) if ($debug == 1);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        Irssi::print("Received reply: $message") if ($debug == 1);
        my $json_parser = JSON::PP->new;
        my $data = $json_parser->decode($message);
        my $result = $data->{choices}[0]{message}{content};
        Irssi::print($result) if ($debug == 1);
        Irssi::gui_input_set($result);
    }
    else {
        Irssi::print("HTTP POST error code: ".$resp->code);
        Irssi::print("HTTP POST error message: ".$resp->message);
    }
}

Irssi::command_bind('tongueworm', \&wormtongue);
