#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for suite in command_ownership key_ownership queries core operators align regression integration; do
  if [ -f "tests/$suite.lua" ]; then
    "${NVIM_BIN:-nvim}" --headless -u NONE -i NONE -n "+set rtp^=." "+lua local ok, err = xpcall(function() dofile('tests/$suite.lua') end, debug.traceback); if not ok then print(err); vim.cmd('cquit 1') end" +qa!
  fi
done

python3 tests/tui.py
python3 tests/tui.py multiedit_tui.lua
