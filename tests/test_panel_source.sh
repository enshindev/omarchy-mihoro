#!/usr/bin/env bash
set -euo pipefail

# Quickshell's Process, Panel, and the qs.Ui kit only exist inside a running
# Omarchy shell, so the QML behaviour that matters is pinned here at the source
# level. Each check stands for a decision that is easy to undo by accident.

# ---- mode switching -------------------------------------------------------

# The API changes the running core in place; the file is what survives a
# restart. A switch must do both, in that order, or the two disagree.
grep -Fq 'writeConfig({ mode: wanted }' Service.qml
grep -Fq 'ClashApi.setModeCommand' Service.qml
grep -Fq 'Model.applyCommand()' Service.qml
# A rejected PATCH falls back to a restart rather than leaving the click on the
# floor.
grep -Fq 'root.runAction("apply"' Service.qml

# With nothing running there is nothing to switch. (`switchable`, not
# `enabled`: the latter is Item's own property.)
grep -Fq 'switchable: mihoro.canSwitchMode' Panel.qml
grep -Fq 'if (wanted === "" || !canSwitchMode || modeProcess.running) return' Service.qml

# All three modes, and no more.
grep -Fq '{ value: "rule"' Model.js
grep -Fq '{ value: "global"' Model.js
grep -Fq '{ value: "direct"' Model.js
[[ "$(grep -c 'value: "' Model.js)" -eq 3 ]]

# ---- connection status ----------------------------------------------------

# Live speeds come from the streaming endpoint, not a poll loop, and the stream
# is torn down with the panel.
grep -Fq 'ClashApi.trafficCommand' Service.qml
grep -Fq 'var wanted = panelOpen && apiBase !== "" && serviceActive && apiState === "ok"' Service.qml
grep -Fq 'SplitParser' Service.qml
# The connections poll is panel-scoped too — nothing polls a closed panel.
grep -Fq 'running: root.panelOpen' Service.qml

# One source of truth for what the panel is looking at. It is `connection`, not
# `state`: QQuickItem owns that name, so `mihoro.state` silently resolves to the
# item's own state string and every field off it reads as undefined.
grep -Fq 'Model.connectionState(probe, apiState)' Service.qml
grep -Fq 'mihoro.connection.label' Panel.qml
! grep -rFq 'mihoro.state' Panel.qml
! grep -rEq '\broot\.state\b' Service.qml

# ---- subscriptions --------------------------------------------------------

# URL subscriptions only: one remote config URL, fetched by the CLI.
grep -Fq 'Model.updateConfigCommand()' Service.qml
grep -Fq 'remote_config_url' MihoroConfig.js
# Saving a URL fetches it; a saved-but-unfetched URL would describe a
# subscription the proxy is not using.
grep -Fq 'writeConfig({ remoteConfigUrl: text }' Service.qml

# Masked by default, with an explicit reveal.
grep -Fq 'property bool revealed: false' components/SubscriptionSection.qml
grep -Fq 'Model.displayUrl(root.url, root.revealed)' components/SubscriptionSection.qml

# The write is atomic and keeps the file's permissions — it holds a credential.
grep -Fq 'mktemp' MihoroConfig.js
grep -Fq 'chmod --reference' MihoroConfig.js

# stdin is opened per write and closed in onStarted to give `cat` its EOF. A
# declarative `stdinEnabled: true` would be replaced by that close, and the
# second write of the session would find stdin shut.
grep -Fq 'configWriteProcess.stdinEnabled = true' Service.qml
grep -Fq 'stdinEnabled: false' Service.qml

# ---- panel wiring ---------------------------------------------------------

grep -Fq 'ModeSection {' Panel.qml
grep -Fq 'ConnectionSection {' Panel.qml
grep -Fq 'SubscriptionSection {' Panel.qml
grep -Fq 'SetupCard {' Panel.qml
grep -Fq 'blocked: subscription.editing' Panel.qml

# Keyboard: toggle, refresh, update, edit, and the three modes by number.
grep -Fq 'key === "t"' Panel.qml
grep -Fq 'key === "r"' Panel.qml
grep -Fq 'key === "u"' Panel.qml
grep -Fq 'key === "e"' Panel.qml
grep -Fq 'mihoro.setMode("global")' Panel.qml

# IPC is how the rest of Omarchy drives the panel.
grep -Fq 'function mode(value: string): string' Panel.qml
grep -Fq 'function status(): string' Panel.qml

# ---- QML scoping ----------------------------------------------------------
#
# Both BarIconButton and PanelHero name their own root object `root`, so a
# `root.` inside a Component declared in Panel.qml is ambiguous about which one
# it means. Everything inside a Component reaches panel state through an id
# that exists only here.
python3 - <<'PY'
import re
import sys

source = open("Panel.qml").read()
problems = []
for match in re.finditer(r"Component\s*\{", source):
    start = match.end() - 1
    depth = 0
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                body = source[start:index + 1]
                if re.search(r"\broot\.", body):
                    problems.append(body.strip()[:80])
                break

if problems:
    print("Component blocks reference an ambiguous `root.`:", file=sys.stderr)
    for problem in problems:
        print("  " + problem, file=sys.stderr)
    sys.exit(1)
print("component scoping ok")
PY

# ---- privacy --------------------------------------------------------------

# The subscription URL and the API secret are credentials. Neither is written
# anywhere but back into mihoro.toml.
! grep -rEq 'console\.(log|warn|error).*(secret|remoteConfigUrl|remote_config_url)' \
  Panel.qml Service.qml components/*.qml Model.js ClashApi.js MihoroConfig.js
! grep -rFq 'wl-copy' Panel.qml Service.qml components/*.qml

echo "panel source tests passed"
