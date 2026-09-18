#!/usr/bin/env python3
import json
import os
import struct
import sys
import tempfile

STATE_DIR = os.path.expanduser("~/.local/state/omarchy")
STATE_PATH = os.path.join(STATE_DIR, "whatsapp-companion.json")
MAX_MESSAGE_BYTES = 64 * 1024

def write_state(unread):
    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix="whatsapp-companion.", dir=STATE_DIR)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump({"unread": max(0, int(unread))}, handle)
            handle.write("\n")
        os.chmod(temp_path, 0o600)
        os.replace(temp_path, STATE_PATH)
    finally:
        if os.path.exists(temp_path): os.unlink(temp_path)

while True:
    header = sys.stdin.buffer.read(4)
    if len(header) != 4: break
    length = struct.unpack("<I", header)[0]
    if length > MAX_MESSAGE_BYTES: break
    payload = sys.stdin.buffer.read(length)
    if len(payload) != length: break
    try:
        message = json.loads(payload.decode("utf-8"))
        if not isinstance(message, dict) or set(message) != {"unread"}:
            continue
        write_state(message["unread"])
    except (ValueError, TypeError, OSError, KeyError):
        continue
