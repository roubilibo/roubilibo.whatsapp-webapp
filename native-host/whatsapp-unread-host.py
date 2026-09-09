#!/usr/bin/env python3
import json
import os
import struct
import subprocess
import sys
import tempfile
from urllib.parse import urlparse

STATE_DIR = os.path.expanduser("~/.local/state/omarchy")
STATE_PATH = os.path.join(STATE_DIR, "whatsapp-unread.json")
DEBUG_PATH = os.path.join(STATE_DIR, "whatsapp-unread-debug.log")

def debug_log(event, detail=""):
    try:
        os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
        with open(DEBUG_PATH, "a", encoding="utf-8") as handle:
            from datetime import datetime
            handle.write(f"{datetime.now().isoformat(timespec='seconds')} {event} {detail}\n")
        os.chmod(DEBUG_PATH, 0o600)
    except OSError: pass

def reply(message):
    payload = json.dumps(message).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("<I", len(payload)))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()

def write_state(unread):
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix="whatsapp-unread.", dir=STATE_DIR)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump({"unread": max(0, int(unread))}, handle)
            handle.write("\n")
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, STATE_PATH)
    finally:
        if os.path.exists(temp_path): os.unlink(temp_path)

def open_external(url):
    if not isinstance(url, str):
        debug_log("open-rejected", "not-string")
        return False
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        debug_log("open-rejected", "invalid-url")
        return False
    debug_log("xdg-open-start", url)
    try:
        process = subprocess.Popen(
            ["xdg-open", url], stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        debug_log("xdg-open-error", "os-error")
        return False
    debug_log("xdg-open-spawned", f"pid={process.pid}")
    return True

while True:
    header = sys.stdin.buffer.read(4)
    if len(header) != 4: break
    length = struct.unpack("<I", header)[0]
    payload = sys.stdin.buffer.read(length)
    if len(payload) != length: break
    try:
        message = json.loads(payload.decode("utf-8"))
        if message.get("type") == "debug":
            debug_log(f"debug-{message.get('stage', 'unknown')}", message.get("url", ""))
            reply({"ok": True})
            continue
        if message.get("type") == "open-external":
            debug_log("message-open-external", message.get("url", ""))
        if message.get("type") == "open-external":
            reply({"ok": open_external(message.get("url"))})
        else:
            write_state(message.get("unread", 0))
    except (ValueError, TypeError, OSError):
        continue
