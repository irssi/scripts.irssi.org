use Irssi;
use LWP::UserAgent;
use JSON::PP;
use strict;
use warnings;

our $VERSION = "1.0.0";
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
Irssi::settings_add_str('misc','wormtongue_openai_api_key', '');
Irssi::settings_add_str('misc','wormtongue_model', 'gpt-3.5-turbo');
Irssi::settings_add_str('misc','wormtongue_role', 'user');
Irssi::settings_add_int('misc','wormtongue_temperature', 700);
Irssi::settings_add_bool('misc','wormtongue_debug', 0);
Irssi::settings_add_str('misc', 'wormtongue_request', 'rephrase this: ');
Irssi::settings_add_str('misc', 'wormtongue_provider', 'ollama');
Irssi::settings_add_str('misc', 'wormtongue_server_endpoint', '');
Irssi::settings_add_int('misc', 'wormtongue_timeout', 5000);
Irssi::settings_add_str('misc', 'wormtongue_system_prompt', 'you are good at rephrasing sentences');

sub wormtongue {
    my $debug = Irssi::settings_get_bool('wormtongue_debug');
    my $timeout = Irssi::settings_get_int('wormtongue_timeout')/1000;
    my $ua = LWP::UserAgent->new(timeout => $timeout);
    my $server_endpoint = Irssi::settings_get_str('wormtongue_server_endpoint');
    my $req = HTTP::Request->new(POST => $server_endpoint);
    $req->header('Content-Type'=>'application/json');
    my $openai_api_key = Irssi::settings_get_str('wormtongue_openai_api_key');
    $req->header('Authorization'=>"Bearer $openai_api_key");
    my $ai_model = Irssi::settings_get_str('wormtongue_model');
    my $ai_role = Irssi::settings_get_str('wormtongue_role');
    my $ai_temp = Irssi::settings_get_int('wormtongue_temperature')/1000;
    my $provider = Irssi::settings_get_str('wormtongue_provider');
    my $question = Irssi::settings_get_str('wormtongue_request');
    my $content = $question.Irssi::parse_special('$L', 0, 0);
    my $system_prompt = Irssi::settings_get_str('wormtongue_system_prompt');
    my $post_data = "";

    if ($provider eq "chatgpt") {
        $post_data = '{"model" : "'.$ai_model.'", "temperature" : '.$ai_temp.', "messages" : [{"role" : "'.$ai_role.'","content" : "'.$content.'"}]}';
        Irssi::print($post_data) if ($debug == 1);
    } elsif ($provider eq "ollama") {
        $post_data = '{"model" : "'.$ai_model.'", "format" : "json", "prompt" : "'.$content.'" , "system" : "'.$system_prompt.'", "stream": false, "options" : {"temperature" : '.$ai_temp.'}}';
        Irssi::print($post_data) if ($debug == 1);
    }

    $req->content($post_data);
    my $resp = $ua->request($req);
    my $result = "";
    Irssi::print($resp) if ($debug == 1);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        Irssi::print("Received reply: $message") if ($debug == 1);
        my $json_parser = JSON::PP->new;
        my $data = $json_parser->decode($message);
        if ($provider eq "chatgpt"){
            $result = $data->{choices}[0]{message}{content};
        }elsif ($provider eq "ollama") {
            $result = $data->{response};
        }
        Irssi::print($result) if ($debug == 1);
        Irssi::gui_input_set($result);
    }
    else {
        Irssi::print("HTTP POST error code: ".$resp->code);
        Irssi::print("HTTP POST error message: ".$resp->message);
    }
}

Irssi::command_bind('tongueworm', \&wormtongue);
