import irssi
from urllib import request, parse

__version__ = "0.1.0"

IRSSI = {
    "authors": "terminaldweller",
    "contact": "https://terminaldweller.com",
    "name": "gotify",
    "description": "sends push notifications via gotify",
    "license": "GPL3 or newer",
    "url": "https://github.com/irssi/scripts.irssi.org",
}


def do_push(
    content: bytes, target: bytes, nick: bytes, server: irssi.IrcServer
) -> None:
    gotify_token = irssi.settings_get_str(b"gotify_token").decode("utf-8")
    gotify_url = irssi.settings_get_str(b"gotify_server_url").decode("utf-8")
    push_priosity = irssi.settings_get_int(b"gotify_push_priority")

    form_fields = {
        "title": "irssi",
        "message": f"received message on {server.tag.decode('utf-8')} from {nick.decode('utf-8')} : {content.decode('utf-8')}",
        "priority": push_priosity,
    }

    data = parse.urlencode(form_fields)
    data = data.encode("utf-8")
    url = gotify_url + f"/message?token={gotify_token}"

    req = request.Request(url, data=data, method="POST")
    request.urlopen(req)


def gotify_sig_handler(*args, **kwargs) -> None:
    server = args[0]
    msg = args[1]
    nick = args[2]
    target = args[4]
    do_push(msg, target, nick, server)


def run_on_script_load() -> None:
    irssi.settings_add_bool(
        b"misc",
        b"transformer_debug",
        False,
    )
    irssi.settings_add_str(
        b"misc",
        b"gotify_server_url",
        b"https://gotify.terminaldweller.com",
    )
    irssi.settings_add_int(
        b"misc",
        b"gotify_push_priority",
        10,
    )
    irssi.settings_add_str(
        b"misc",
        b"gotify_token",
        b"",
    )

    irssi.signal_add(b"message private", gotify_sig_handler)


run_on_script_load()
