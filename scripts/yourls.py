"""yourls url shortener for irssi"""
import asyncio
import cProfile
import json
import re
import threading
from urllib import request, parse

import irssi

DEBUG = False

__version__ = "1.0.0"

IRSSI = {
    "authors": "terminaldweller",
    "contact": "https://terminaldweller.com",
    "name": "yourls",
    "description": "uses yourls to shorten urls",
    "license": "GPL3 or newer",
    "url": "https://github.com/irssi/scripts.irssi.org",
}


def yourls_request(req, target: bytes, content: str) -> None:
    """async wrapper for urllib.request.urlopen"""
    timeout = irssi.settings_get_int(b"yourls_timeout")

    with request.urlopen(req, timeout=timeout) as resp:
        json_response = json.load(resp)
        if DEBUG:
            print(json_response)
        short_url = json_response["shorturl"]
        if DEBUG:
            print(short_url)
        url_pattern = r"(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'\".,<>?«»“”‘’]))"
        new_content = re.sub(url_pattern, short_url, content)
        window = irssi.window_find_item(target)
        window.prnt(new_content.encode("utf-8"))


def yourls_command_handler(content: bytes, target: bytes) -> None:
    """handle the command"""
    yourls_url = irssi.settings_get_str(b"yourls_server_url").decode("utf-8")
    yourls_token = irssi.settings_get_str(b"yourls_secret_sig_token").decode("utf-8")
    yourls_min_length = irssi.settings_get_int(b"yourls_min_length")
    yourls_format = irssi.settings_get_str(b"yourls_format").decode("utf-8")
    yourls_action = irssi.settings_get_str(b"yourls_action").decode("utf-8")

    url_pattern = r"(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'\".,<>?«»“”‘’]))"

    result = re.findall(url_pattern, content.decode("utf-8"))

    if len(result) == 0:
        return
    if len(result[0][0]) < yourls_min_length:
        return
    form_fields = {
        "url": result[0][0],
    }

    data = parse.urlencode(form_fields).encode("utf-8")
    params = {
        "signature": yourls_token,
        "action": yourls_action,
        "format": yourls_format,
        "url": result[0][0],
    }
    url = yourls_url + "?" + parse.urlencode(params, doseq=True, safe=":/?&=")
    if DEBUG:
        print(url)

    req = request.Request(url, method="POST")
    # yourls_request(req, target, content.decode("utf-8"))
    threading.Thread(
        target=yourls_request(req, target, content.decode("utf-8"))
    ).start()


def yourls_signal_handler(*args, **kwargs) -> None:
    """handle the message signal"""

    server = args[0]
    msg = args[1]
    _ = args[2]
    address = args[3]
    target = args[4]

    yourls_url = irssi.settings_get_str(b"yourls_server_url").decode("utf-8")
    yourls_operation_mode = irssi.settings_get_str(b"yourls_operation_mode").decode(
        "utf-8"
    )
    yourls_names = irssi.settings_get_str(b"yourls_name_list").decode("utf-8")
    yourls_name_list = yourls_names.split(" ")
    current = server.tag.decode("utf-8") + "/" + target.decode("utf-8")

    if yourls_url == "":
        return

    for name in yourls_name_list:
        if re.match(name, current):
            if yourls_operation_mode == "whitelist":
                break
            elif yourls_operation_mode == "blacklist":
                return
            else:
                print("invalid operation mode: must be whitelist or blacklist")
            return

    if DEBUG:
        profiler = cProfile.Profile()
        profiler.runctx("yourls_command_handler(msg, target)", globals(), locals())
        profiler.print_stats()
    else:
        threading.Thread(target=yourls_command_handler(msg, target)).start()
        yourls_command_handler(msg, target)


def run_on_script_load() -> None:
    """setup the script"""
    irssi.settings_add_str(
        b"misc",
        b"yourls_server_url",
        b"",
    )
    irssi.settings_add_str(
        b"misc",
        b"yourls_secret_sig_token",
        b"",
    )
    irssi.settings_add_str(
        b"misc",
        b"yourls_format",
        b"json",
    )
    irssi.settings_add_str(
        b"misc",
        b"yourls_action",
        b"shorturl",
    )
    irssi.settings_add_str(
        b"misc",
        b"yourls_operation_mode",
        b"whitelist",
    )
    irssi.settings_add_str(
        b"misc",
        b"yourls_name_list",
        b"",
    )
    irssi.settings_add_int(
        b"misc",
        b"yourls_min_length",
        30,
    )
    irssi.settings_add_int(
        b"misc",
        b"yourls_timeout",
        15,
    )

    irssi.signal_add(b"message public", yourls_signal_handler)
    irssi.signal_add(b"message private", yourls_signal_handler)


run_on_script_load()
