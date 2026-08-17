#!/usr/bin/env bash
set -euo pipefail

# The manifest is the contract with the shell: the id, the entry point, and the
# widget metadata all have to agree with what Panel.qml declares.
python3 - <<'PY'
import json
import sys

manifest = json.load(open("manifest.json"))

assert manifest["schemaVersion"] == 1, manifest["schemaVersion"]
assert manifest["id"] == "mihoro.omarchy", manifest["id"]
assert manifest["kinds"] == ["bar-widget"], manifest["kinds"]
assert manifest["entryPoints"]["barWidget"] == "Panel.qml"
assert manifest["barWidget"]["allowMultiple"] is False
assert manifest["barWidget"]["category"] == "Network"

schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}
assert "refreshIntervalSec" in schema
assert schema["refreshIntervalSec"]["type"] == "integer"
assert schema["refreshIntervalSec"]["defaultValue"] == manifest["barWidget"]["defaults"]["refreshIntervalSec"]
# Service.qml clamps to the same window; a schema that allowed more would let
# the settings UI offer a value the panel silently overrides.
assert schema["refreshIntervalSec"]["min"] == 5
assert schema["refreshIntervalSec"]["max"] == 3600

panel = open("Panel.qml").read()
assert 'moduleName: "%s"' % manifest["id"] in panel
assert 'ipcTarget: "%s"' % manifest["id"] in panel
print("manifest ok")
PY

# The plugin schedules the CLI the user installed. It must never install,
# upgrade, or remove it, and must never ask for root.
for file in Model.js Service.qml Panel.qml install.sh components/*.qml; do
  ! grep -Eq 'mihoro[[:space:]]+(uninstall|upgrade)' "$file" \
    || { echo "$file invokes a destructive mihoro subcommand" >&2; exit 1; }
  ! grep -Eq '\b(sudo|pkexec)\b' "$file" \
    || { echo "$file escalates privileges" >&2; exit 1; }
done

# install.sh links a checkout into place; it never fetches or runs an installer.
! grep -Eq 'curl .*\| *(sh|bash)' install.sh
grep -Fq 'omarchy plugin validate' install.sh
grep -Fq 'plugin-backups' install.sh
[[ -x install.sh ]]

# A missing CLI is a soft condition: the panel explains it, so installing the
# plugin must not fail because of it.
! grep -Eq "command -v mihoro .*\{\s*$" install.sh || {
  echo "install.sh hard-fails on a missing mihoro" >&2
  exit 1
}

echo "install tests passed"
