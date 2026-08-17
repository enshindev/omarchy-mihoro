# Mihoro for Omarchy

An Omarchy bar panel for [mihoro](https://github.com/spencerwooo/mihoro), the
Mihomo CLI client for Linux.

<img width="621" height="720" alt="Mihoro panel" src="https://github.com/user-attachments/assets/ca5a27d9-a05e-4134-8cae-360ddef861d8" />

It does three things: shows what the proxy is actually doing, manages the
subscription URL, and switches between Rule, Global, and Direct.

## Requirements

- Omarchy
- The [mihoro CLI](https://github.com/spencerwooo/mihoro#installation) on `PATH`

**The plugin does not install mihoro.** The CLI is yours: it owns the mihomo
binary, the systemd unit, and the subscription download, and this panel only
schedules it. When mihoro is missing the panel says so and links to the
official instructions; it never downloads or runs an installer, and it never
asks for root.

## Getting Started

Install mihoro:

```bash
curl -fsSL https://raw.githubusercontent.com/spencerwooo/mihoro/main/install.sh | sh
```

Initialize mihoro and enter your subscription URL when prompted:

```bash
mihoro init
```

Set the capabilities required for TUN mode, confirm them, and restart mihomo:

```bash
sudo setcap cap_net_admin,cap_net_raw,cap_net_bind_service=+ep ~/.local/bin/mihomo
getcap ~/.local/bin/mihomo
systemctl --user restart mihomo.service
```

Verify that the service started successfully:

```bash
journalctl --user -u mihomo.service -n 30 --no-pager
```

## Install the Plugin

```bash
omarchy plugin add https://github.com/huacnlee/omarchy-mihoro.git --enable
```

For development, symlink this checkout into Omarchy:

```bash
./install.sh          # or ./install.sh --no-restart
```

## Where the data comes from

The panel talks to two things, and the split is the same one mihoro itself
makes.

**The CLI** owns everything that touches the filesystem and systemd. It is the
only way to do these, and each maps to exactly one command:

| Panel action        | Command                  |
|---------------------|--------------------------|
| First-time setup    | `mihoro init -y`         |
| Update subscription | `mihoro update --config` |
| Start / stop        | `mihoro start` / `mihoro stop` |
| Restart             | `mihoro restart`         |
| Apply mode (fallback) | `mihoro apply`         |

**Mihomo's control API** owns everything live. `mihoro init` configures it as
`external_controller` and prints its address at the end of setup — it is the
same API the metacubexd dashboard mihoro installs talks to. The panel reads
`/version`, `/configs`, and `/connections` from it, streams `/traffic`, and
switches the mode with `PATCH /configs`.

Requests go out through `curl`, which is how the shell's other plugins reach
the network, and `-w '\n%{http_code}'` keeps the status code attached to the
body — so a 401 from a wrong `secret` stays distinguishable from a core that
is not listening at all. Those two need different things said to you.

Everything else comes from one shell probe per refresh: `command -v mihoro`,
`systemctl --user show mihomo.service`, and the mtime of mihomo's
`config.yaml`. One process rather than five.

## Connection status

The panel opens on what the proxy is doing right now:

- **Live throughput**, up and down, from the `/traffic` stream. That endpoint
  holds a socket open and pushes a sample a second, so speeds cost one `curl`
  for as long as the panel is on screen instead of a poll loop. It is torn
  down the moment the panel closes.
- **Open connections** and **cumulative transfer**, polled from
  `/connections` every five seconds while the panel is open. Only the totals
  and the count are kept — that payload carries a metadata object per
  connection and can run to hundreds of them.
- **Service** — what systemd reports, active and enabled state both, because
  a proxy that is running but will not survive a reboot is worth knowing about.
- **Uptime**, since `ActiveEnterTimestamp`.
- **Core** — the mihomo version actually serving, from `/version`.
- **API** — where the control API is, or why it cannot be reached.
- **Ports** and **LAN access** — live values from `/configs` where available,
  falling back to `mihoro.toml`, which is what the next restart will use.

Nothing polls while the panel is closed. The bar icon refreshes on its own
interval (30s by default, configurable in the widget settings) and shows a
bolt: struck through when the proxy is down, ringed when the mode is Global.

## Subscription

mihoro subscribes to one remote config URL, so that is the only kind of
subscription here. The panel reads and writes `remote_config_url` in
`~/.config/mihoro.toml` — mihoro hardcodes that path and does not consult
`XDG_CONFIG_HOME`, so neither does the panel; they have to agree on one file.

Saving a URL and fetching it are one action. A URL saved but never downloaded
would show a subscription the proxy is not actually using. On a machine that
has never been set up, saving runs `mihoro init -y` instead, which downloads
the core, the config, and installs the service.

The URL is masked by default and revealed with a button. It is a bearer
credential — whoever has it has the subscription — and a bar panel gets read
over shoulders, so the token is hidden whole rather than partially. Half a
token is still half a token.

Writes are line-level replacements, not a parse-and-reserialize round trip.
Everything else in `mihoro.toml` is yours: key order, blank lines, comments,
and the fields the panel has no opinion about. Re-emitting the file from a
partial model would silently drop all of it. The new file is written to a
temporary file in the same directory and renamed into place, keeping the
original's permissions, so an interrupted write cannot leave mihoro with a
half-file it then refuses to parse.

## Proxy mode

Rule, Global, and Direct, as one row of chips.

A switch goes to the running core first, with `PATCH /configs`, which takes
effect immediately and without dropping the service. The same value is then
written into `mihoro.toml`, because `mihoro apply` and `mihoro update` both
regenerate `config.yaml` from that file and would otherwise revert the mode at
the next update.

If the API is unreachable — `external_controller` unset, or a secret the core
rejects — the file has already been written, so the panel falls back to
`mihoro apply`, which restarts mihomo onto the new mode. The chips say so
before you click.

**The switch requires a running core.** With mihomo stopped there is nothing
to switch, and writing the file alone would show a mode that is not in effect
anywhere; the control goes quiet and says to start mihomo instead.

## Keyboard

- `j` / `k` or arrows: move the cursor; `h` / `l` walk the mode chips
- `enter`: activate
- `t`: start or stop mihomo
- `1` / `2` / `3`: Rule / Global / Direct, `m` to cycle
- `s`: open subscription management
- `u`: update the subscription (subscription page)
- `e`: edit the subscription URL (subscription page)
- `r`: refresh
- `esc`: leave URL editing, return to the main page, then close

While the URL editor is open every key belongs to it — a URL contains `r` and
`u`.

## IPC

```bash
omarchy-shell mihoro.omarchy toggle
omarchy-shell mihoro.omarchy mode global
omarchy-shell mihoro.omarchy update
omarchy-shell mihoro.omarchy status     # JSON
```

`open`, `close`, `show`, `hide`, `refresh`, `start`, `stop`, and `restart` are
there too. `status` returns the connection state, mode, service state, API
state, core version, connection count, and when the subscription was last
fetched.

## Privacy

The panel writes nothing to disk except `remote_config_url` and
`mihomo_config.mode`, back into `mihoro.toml`. There is no cache. The
subscription URL and the API secret are never logged, never copied to the
clipboard, and never sent anywhere but to mihoro and to mihomo's own API on
loopback.

The resource menu has no uninstall and no upgrade. The only action there that
changes this machine is restarting the service the panel already starts and
stops.

## Development

```bash
make test        # runs anywhere node and bash do
make validate    # adds qmllint and `omarchy plugin validate`, needs Omarchy
```

Parsing, formatting, and command building live in plain JS (`MihoroConfig.js`,
`ClashApi.js`, `Model.js`) precisely so they can be tested without a
compositor; `tests/load.js` strips the `.pragma library` directive and runs the
real files in a vm context, so the tests exercise what the shell loads rather
than a copy.

The QML gets two checks that do not need Qt. `tests/test_qml_names.py` catches
declarations that collide with a base type's own — `property var state` on an
`Item` is a hard error, and `property bool enabled` would stop the object
receiving input as well as greying it out; both were real bugs here, and
nothing surfaces them until the shell tries to load the plugin.
`tests/test_panel_source.sh` pins the decisions that cannot be unit tested —
that a mode switch writes the file as well as calling the API, that the traffic
stream is panel-scoped, that the URL is masked by default, and that nothing
inside a `Component` refers to a bare `root` (both `BarIconButton` and
`PanelHero` name their own root object `root`, so it would be ambiguous).

Neither replaces `qmllint`, which needs a Qt toolchain and the shell's import
path; run it with `make qml-check` on a machine that has Omarchy. Quickshell's
`Process` and the `qs.Ui` kit only exist inside a running shell, so the data
path itself has to be exercised by running the panel.

## Limitations

- One subscription URL, which is all mihoro supports.
- No proxy or proxy-group selection, no rule editing, no logs. The dashboard
  mihoro installs covers those; the resource menu links to it.
- Mode switching needs mihomo running.
- `mihoro cron` (scheduled auto-updates) is not surfaced.

## License

MIT. mihoro and mihomo are distributed separately under their own licenses.
