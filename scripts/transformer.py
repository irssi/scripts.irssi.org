import irssi
import json
import urllib
from urllib import request

__version__ = "0.1.0"

IRSSI = {
    "authors": "terminaldweller",
    "contact": "https://terminaldweller.com",
    "name": "transformer",
    "description": "transforms incoming text in the channel",
    "license": "GPL3 or newer",
    "url": "https://github.com/irssi/scripts.irssi.org",
}


def do_post(url: str, content: bytes, target: bytes, nick: bytes) -> None:
    api_key = irssi.settings_get_str(b"transformer_api_key")
    api_key = api_key.decode("utf-8")
    model = irssi.settings_get_str(b"transformer_model")
    temp = irssi.settings_get_int(b"transformer_temperature")
    n = irssi.settings_get_int(b"transformer_n")
    prompt_system = irssi.settings_get_str(b"transformer_prompt_system")
    prompt_user = irssi.settings_get_str(b"transformer_prompt_user")

    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"}

    data = {
        "model": model.decode("utf-8"),
        "temperature": temp / 1000.0,
        "n": n,
        "messages": [
            {
                "role": "system",
                "content": prompt_system.decode("utf-8") + content.decode("utf-8"),
            },
            {
                "role": "user",
                "content": prompt_user.decode("utf-8") + content.decode("utf-8"),
            },
        ],
    }

    result = ""
    post_data = json.dumps(data).encode("utf-8")
    req = request.Request(url, post_data, headers, method="POST")
    try:
        resp = request.urlopen(req)
        json_response = json.load(resp)
        window = irssi.window_find_item(target)
        for choice in json_response["choices"]:
            result = choice["message"]["content"]
            if result != "":
                window.prnt(
                    bytes(nick.decode("utf-8") + " >>> " + result, encoding="utf-8")
                )
    except urllib.error.HTTPError as e:
        resp = e.read().decode("utf-8")
        json_response = json.load(resp)
        print(json_response)


def transformer_sig_handler(*args, **kwargs) -> None:
    URL = "https://api.openai.com/v1/chat/completions"
    server = args[0]
    msg = args[1]
    nick = args[2]
    target = args[4]
    channels = (
        irssi.settings_get_str(b"transformer_channel_list").decode("utf-8").split(" ")
    )
    source = server.tag + b"/" + target
    if any(source.decode("utf-8") in channel for channel in channels):
        do_post(URL, msg, target, nick)


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
        (
            b"if you can't translate parts of the provided text use the original"
            b" piece of text. the text will ocassionally inlcude URLs. if the original"
            b" text is in the target language, return an empty response."
            b" Do not ask for follow up question."
        ),
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

    irssi.signal_add(b"message public", transformer_sig_handler)


run_on_script_load()
