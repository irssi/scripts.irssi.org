import irssi
import json
import typing
import urllib
from urllib import request, parse

__version__ = "1.0.0"

IRSSI = {
    "authors": "terminaldweller",
    "contact": "https://terminaldweller.com",
    "name": "transformer",
    "description": "transforms incoming text in the channel",
    "license": "GPL3 or newer",
    "url": "https://github.com/irssi/scripts.irssi.org",
}


def do_post(content: bytes, target: bytes, nick: bytes) -> None:
    model = irssi.settings_get_str(b"transformer_model")
    temp = irssi.settings_get_int(b"transformer_temperature")
    n = irssi.settings_get_int(b"transformer_n")
    debug = irssi.settings_get_bool(b"transformer_debug")
    prompt_system = irssi.settings_get_str(b"transformer_prompt_system")
    prompt_user = irssi.settings_get_str(b"transformer_prompt_user")
    provider = irssi.settings_get_str(b"transformer_provider")
    provider = provider.decode("utf-8")
    server_url = irssi.settings_get_str(b"transformer_server_address")
    server_url = server_url.decode("utf-8")
    timeout = irssi.settings_get_int(b"transformer_timeout")

    data = {}
    headers = {}
    if provider == "chatgpt":
        api_key = irssi.settings_get_str(b"transformer_api_key")
        api_key = api_key.decode("utf-8")
        headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}
        role = irssi.settings_get_str(b"transformer_role")
        data = {
            "model": model.decode("utf-8"),
            "temperature": temp / 1000.0,
            "n": n,
            "messages": [
                {
                    "role": "system",
                    "content": prompt_system.decode("utf-8")
                },
                {
                    "role": "user",
                    "content": prompt_user.decode("utf-8") + content.decode("utf-8"),
                },
            ],
        }
    elif provider == "ollama":
        headers = {"Content-Type": "application/json"}
        data = {
            "model": model.decode("utf-8"),
            "system": prompt_system.decode("utf-8"),
            "prompt": prompt_user.decode("utf-8") + content.decode("utf-8"),
            "stream": False,
            "format": "json",
            "options": {
                "temperature": temp / 1000.0,
            },
        }
    else:
        pass

    result = ""
    post_data = json.dumps(data).encode("utf-8")
    req = request.Request(server_url, post_data, headers, method="POST")
    try:
        resp = request.urlopen(req, timeout=timeout)
        json_response = json.load(resp)
        window = irssi.window_find_item(target)
        trans_header = irssi.settings_get_str(b"transformer_header")
        trans_header = trans_header.decode("utf-8")
        if trans_header:
            window.prnt(bytes(trans_header, encoding="utf-8"))
            # window.prnt(
            #     bytes("%N%z005faf%k %9Transformed %N%Z005faf%0%N", encoding="utf-8")
            # )
        if provider == "chatgpt":
            for choice in json_response["choices"]:
                result = choice["message"]["content"]
                if result != "":
                    window.prnt(
                        bytes(nick.decode("utf-8") + " >>> " + result, encoding="utf-8")
                    )
        elif provider == "ollama":
            result = json_response["response"]
            if result != "":
                window.prnt(
                    bytes(nick.decode("utf-8") + " >>> " + result, encoding="utf-8")
                )
    except urllib.error.HTTPError as e:
        resp = e.read().decode("utf-8")
        json_response = json.load(resp)
        print(json_response)


def transformer_sig_handler(*args, **kwargs) -> None:
    server = args[0]
    msg = args[1]
    nick = args[2]
    address = args[3]
    target = args[4]
    channels = (
        irssi.settings_get_str(b"transformer_channel_list").decode("utf-8").split(" ")
    )
    source = server.tag + b"/" + target
    if any(source.decode("utf-8") in channel for channel in channels):
        do_post(msg, target, nick)


def run_on_script_load() -> None:
    irssi.settings_add_bool(
        b"misc",
        b"transformer_debug",
        False,
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_api_key",
        b"",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_model",
        b"gpt-3.5-turbo",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_role",
        b"user",
    )
    irssi.settings_add_int(
        b"misc",
        b"transformer_temperature",
        700,
    )
    irssi.settings_add_int(
        b"misc",
        b"transformer_n",
        1,
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_prompt_system",
        b"if you can't translate parts of the provided text use the original piece of text. the text will ocassionally include URLs. if the original text is in the target language, return an empty response. Do not ask for follow up question.",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_prompt_user",
        b"translate this into english: ",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_channel_list",
        b"",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_provider",
        b"ollama",
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_server_address",
        b"https://api.openai.com/v1/chat/completions",
    )
    irssi.settings_add_int(
        b"misc",
        b"transformer_timeout",
        5,
    )
    irssi.settings_add_str(
        b"misc",
        b"transformer_header",
        b"",
    )

    irssi.signal_add(b"message public", transformer_sig_handler)


run_on_script_load()
