const assert = require("assert")
const { load } = require("./load")

const api = load("ClashApi.js")

// ------------------------------------------------- controller normalisation
//
// These mirror mihoro's own `parse_controller_address` / `is_wildcard_host`,
// including the cases its tests cover, so the panel and the dashboard URL
// mihoro prints always point at the same place.

assert.strictEqual(api.baseUrl("0.0.0.0:9090"), "http://127.0.0.1:9090")
assert.strictEqual(api.baseUrl("127.0.0.1:9090"), "http://127.0.0.1:9090")
assert.strictEqual(api.baseUrl("[::]:19090"), "http://127.0.0.1:19090")
assert.strictEqual(api.baseUrl("[::1]:9090"), "http://[::1]:9090")
assert.strictEqual(api.baseUrl("10.108.25.191:19090"), "http://10.108.25.191:19090")
assert.strictEqual(api.baseUrl("  0.0.0.0:9090  "), "http://127.0.0.1:9090")
assert.strictEqual(api.baseUrl("http://127.0.0.1:9090/"), "http://127.0.0.1:9090")
assert.strictEqual(api.baseUrl("https://box.example:9090"), "http://box.example:9090")
assert.strictEqual(api.baseUrl(":9090"), "http://127.0.0.1:9090")

// No port means no address; a unix socket is not something curl reaches this
// way. Both must yield "" so the panel says the API is unconfigured rather
// than firing requests at a nonsense URL.
assert.strictEqual(api.baseUrl("127.0.0.1"), "")
assert.strictEqual(api.baseUrl(""), "")
assert.strictEqual(api.baseUrl(null), "")
assert.strictEqual(api.baseUrl(undefined), "")
assert.strictEqual(api.baseUrl("unix:///run/mihomo.sock"), "")
assert.strictEqual(api.baseUrl("[::1"), "")

// ---------------------------------------------------------------- commands

const version = api.versionCommand("http://127.0.0.1:9090", "")
assert.strictEqual(version[0], "curl")
assert.ok(version.includes("--max-time"))
assert.strictEqual(version[version.length - 1], "http://127.0.0.1:9090/version")
assert.ok(!version.some(arg => /Authorization/.test(arg)), "no auth header without a secret")

const authed = api.configsCommand("http://127.0.0.1:9090", "s3cret")
assert.ok(authed.includes("Authorization: Bearer s3cret"))
assert.strictEqual(authed[authed.length - 1], "http://127.0.0.1:9090/configs")

const connections = api.connectionsCommand("http://127.0.0.1:9090", "")
assert.strictEqual(connections[connections.length - 1], "http://127.0.0.1:9090/connections")

const setMode = api.setModeCommand("http://127.0.0.1:9090", "s3cret", "Global")
assert.ok(setMode.includes("PATCH"))
assert.ok(setMode.includes('{"mode":"global"}'), "mode is normalised before it is sent")
assert.ok(setMode.includes("Authorization: Bearer s3cret"))
assert.strictEqual(setMode[setMode.length - 1], "http://127.0.0.1:9090/configs")

// An unknown mode never reaches the core as-is.
assert.ok(api.setModeCommand("http://x:9090", "", "sideways").includes('{"mode":"rule"}'))

const traffic = api.trafficCommand("http://127.0.0.1:9090", "")
assert.ok(traffic.includes("-N"), "the traffic stream must not be buffered")
assert.ok(traffic.includes("--no-buffer"))
assert.ok(!traffic.includes("--max-time"), "a stream that is meant to stay open has no deadline")
assert.strictEqual(traffic[traffic.length - 1], "http://127.0.0.1:9090/traffic")

assert.strictEqual(api.normalizeMode("RULE"), "rule")
assert.strictEqual(api.normalizeMode(" Direct "), "direct")
assert.strictEqual(api.normalizeMode("nope"), "")

// ---------------------------------------------------------------- responses

// Objects cross the vm boundary, so their prototypes differ from this realm's;
// fields are compared directly rather than with deepStrictEqual.
const split = api.splitResponse('{"mode":"rule"}\n200')
assert.strictEqual(split.status, 200)
assert.strictEqual(split.body, '{"mode":"rule"}')
assert.strictEqual(api.splitResponse("\n401").status, 401)
assert.strictEqual(api.splitResponse("\n401").body, "")
assert.strictEqual(api.splitResponse("").status, 0)
assert.strictEqual(api.splitResponse("").body, "")

// A body that itself contains newlines still gives up only its last line.
assert.strictEqual(api.splitResponse("{\n  \"a\": 1\n}\n200").body, "{\n  \"a\": 1\n}")

// classify keeps "not listening", "wrong secret", and "server said no" apart,
// because each one needs a different thing said to the user.
assert.strictEqual(api.classify(7, "", "connection refused").code, "unreachable")
assert.strictEqual(api.classify(0, "", "").code, "unreachable")
assert.strictEqual(api.classify(0, '{"message":"unauthorized"}\n401', "").code, "unauthorized")
assert.strictEqual(api.classify(0, "nope\n403", "").code, "unauthorized")
assert.strictEqual(api.classify(0, "boom\n500", "").code, "http_error")

const ok = api.classify(0, '{"mode":"global"}\n200', "")
assert.strictEqual(ok.ok, true)
assert.strictEqual(ok.body, '{"mode":"global"}')

// ------------------------------------------------------------------ parsers

const parsedVersion = api.parseVersion('{"version":"1.19.2","meta":true}')
assert.strictEqual(parsedVersion.version, "1.19.2")
assert.strictEqual(parsedVersion.meta, true)
assert.strictEqual(api.parseVersion("not json").version, "")
assert.strictEqual(api.parseVersion("not json").meta, false)

const configs = api.parseConfigs(JSON.stringify({
  port: 7891,
  "socks-port": 7892,
  "mixed-port": 7890,
  "allow-lan": true,
  mode: "Global",
  "log-level": "info"
}))
assert.strictEqual(configs.mode, "global")
assert.strictEqual(configs.mixedPort, 7890)
assert.strictEqual(configs.port, 7891)
assert.strictEqual(configs.socksPort, 7892)
assert.strictEqual(configs.allowLan, true)
assert.strictEqual(api.parseConfigs("["), null)

const conns = api.parseConnections(JSON.stringify({
  downloadTotal: 1024,
  uploadTotal: 512,
  connections: [{ id: "a" }, { id: "b" }, { id: "c" }],
  memory: 4096
}))
assert.strictEqual(conns.count, 3)
assert.strictEqual(conns.downloadTotal, 1024)
assert.strictEqual(conns.uploadTotal, 512)
assert.strictEqual(conns.memory, 4096)

// mihomo sends `connections: null` when there are none.
assert.strictEqual(api.parseConnections('{"downloadTotal":1,"uploadTotal":2,"connections":null}').count, 0)
assert.strictEqual(api.parseConnections("nope"), null)

const sample = api.parseTrafficLine('{"up":120,"down":4096}')
assert.strictEqual(sample.up, 120)
assert.strictEqual(sample.down, 4096)
assert.strictEqual(api.parseTrafficLine(""), null)
assert.strictEqual(api.parseTrafficLine("{}"), null)

console.log("clash API tests passed")
