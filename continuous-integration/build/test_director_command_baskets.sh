#!/usr/bin/env bash
set -euo pipefail

command_file="nep/nep-monitoring-asset/baskets/import/nep-monitoring-asset-02-command.json"

python3 - "$command_file" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)

commands = data["Command"]
target = commands["nx-c-check-glpi-notification-queue"]
expected = "PluginContribDir + /check_glpi_notification_queue"
actual = target["command"]

assert actual == expected, f"unexpected command: {actual!r}"
assert '\"' not in actual, f"quoted path detected: {actual!r}"

matches = [name for name in commands if name == "nx-c-check-glpi-notification-queue"]
assert len(matches) == 1, "duplicate target command definition detected"

print("Director command regression: OK")
PY
