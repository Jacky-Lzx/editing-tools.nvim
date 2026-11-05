#!/usr/bin/env python3
"""Validate terminal input and intermediate screen contents through a real PTY."""
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

root = Path(__file__).resolve().parents[1]
script = sys.argv[1] if len(sys.argv) > 1 else "tui.lua"
assert script in ("tui.lua", "multiedit_tui.lua")
with tempfile.TemporaryDirectory(prefix="editing-tools-", dir="/tmp") as directory:
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 110, 0, 0))
    env = dict(os.environ, TERM="xterm-256color", EDITING_TOOLS_TEST_DIR=directory,
               NVIM_LOG_FILE=directory + "/nvim.log",
               XDG_STATE_HOME=directory + "/state", XDG_CACHE_HOME=directory + "/cache")
    process = subprocess.Popen([os.environ.get("NVIM_BIN") or shutil.which("nvim"),
                                "-u", "NONE", "--noplugin", "-n", "-i", "NONE",
                                "-c", "lua dofile('tests/" + script + "')"], cwd=root, env=env,
                               stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)
    handled, output, sentinel_at = set(), bytearray(), None
    deadline = time.monotonic() + 30
    try:
        while process.poll() is None and time.monotonic() < deadline:
            if sentinel_at is not None and time.monotonic() >= sentinel_at:
                os.write(master, b"\x1b[24~")
                sentinel_at = None
            if select.select([master], [], [], 0.01)[0]:
                try:
                    output.extend(os.read(master, 65536))
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
            file = Path(directory, "stage")
            stage = file.read_text().splitlines() if file.exists() else []
            if len(stage) >= 2 and stage[0] not in handled:
                os.write(master, json.loads(stage[1]).encode())
                sentinel_at = time.monotonic() + 0.1
                handled.add(stage[0])
        if process.poll() is None:
            process.kill()
        process.wait()
        result_file = Path(directory, "result")
        result = result_file.read_text() if result_file.exists() else "No result; " + repr(handled)
        assert process.returncode == 0 and result.startswith("PASS"), result + "\n" + output.decode(errors="replace")[-5000:]
        print(result.strip())
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        os.close(master)
