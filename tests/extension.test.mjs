// Chunk 3: registry + status mapping, against a mocked Pi API.
// Run: node --experimental-strip-types --test tests/extension.test.mjs
import { test, beforeEach } from "node:test"
import assert from "node:assert/strict"
import { mkdtempSync, readdirSync, readFileSync, chmodSync, existsSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import ext from "../extension/pi-hatch.ts"

let dir
beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "pihatch-ext-"))
  process.env.PI_HATCH_DIR = dir
  process.env.TMUX_PANE = "%7"
  process.env.TMUX = "/tmp/tmux-1000/default,123,0"
})

// Load the extension against a fake Pi; returns fire(event, payload, ctxOverrides).
function load() {
  const handlers = {}
  ext({ on: (name, fn) => (handlers[name] = fn) })
  let idle = true
  const ctx = { hasUI: true, cwd: "/work/proj", isIdle: () => idle }
  return {
    handlers,
    setIdle: (v) => (idle = v),
    fire: (name, payload = {}, over = {}) => handlers[name]?.(payload, { ...ctx, ...over }),
  }
}
const rec = () => JSON.parse(readFileSync(join(dir, `${process.pid}.json`), "utf8"))

test("session_start publishes ready with exactly the agreed fields", async () => {
  const p = load()
  await p.fire("session_start")
  const r = rec()
  assert.deepEqual(Object.keys(r).sort(), ["cwd", "paneId", "pid", "procStart", "socket", "status", "updatedAt"])
  assert.equal(r.status, "ready")
  assert.equal(r.pid, process.pid)
  assert.equal(r.paneId, "%7")
  assert.equal(r.socket, "/tmp/tmux-1000/default")
  assert.equal(r.cwd, "/work/proj")
  assert.match(r.procStart, /^\d+$/)
  assert.ok(Math.abs(r.updatedAt - Date.now() / 1000) < 5)
})

test("status mapping follows lifecycle events", async () => {
  const p = load()
  await p.fire("session_start")
  await p.fire("agent_start")
  assert.equal(rec().status, "working")
  await p.fire("agent_settled", { aborted: false })
  assert.equal(rec().status, "ready")
  await p.fire("agent_start")
  await p.fire("agent_settled", { aborted: true })
  assert.equal(rec().status, "aborted")
  await p.fire("agent_start") // aborted stays until the next run starts
  assert.equal(rec().status, "working")
  await p.fire("ui_prompt_start", { kind: "confirm", title: "x" })
  assert.equal(rec().status, "prompt")
  p.setIdle(false)
  await p.fire("ui_prompt_end")
  assert.equal(rec().status, "working")
  await p.fire("ui_prompt_start")
  p.setIdle(true)
  await p.fire("ui_prompt_end")
  assert.equal(rec().status, "ready")
})

test("no prompt or transcript text is ever stored", async () => {
  const p = load()
  await p.fire("session_start")
  await p.fire("ui_prompt_start", { kind: "input", title: "SECRET-TITLE", reason: "ui_prompt" })
  await p.fire("agent_end", { messages: [{ content: "SECRET-MSG" }] })
  await p.fire("agent_settled", { aborted: false, messages: "SECRET-MSG" })
  const raw = readFileSync(join(dir, `${process.pid}.json`), "utf8")
  assert.ok(!raw.includes("SECRET"))
})

test("session_shutdown removes the record and stops publishing", async () => {
  const p = load()
  await p.fire("session_start")
  await p.fire("session_shutdown", { reason: "quit" })
  assert.equal(existsSync(join(dir, `${process.pid}.json`)), false)
  await p.fire("agent_start")
  assert.deepEqual(readdirSync(dir), [])
})

test("no tmux pane: nothing registered or written", async () => {
  delete process.env.TMUX_PANE
  const p = load()
  assert.deepEqual(Object.keys(p.handlers), [])
  assert.deepEqual(readdirSync(dir), [])
})

test("no UI (pi -p / RPC): nothing written", async () => {
  const p = load()
  await p.fire("session_start", {}, { hasUI: false })
  await p.fire("agent_start", {}, { hasUI: false })
  assert.deepEqual(readdirSync(dir), [])
})

test("an unwritable registry never throws", async () => {
  chmodSync(dir, 0o500)
  process.env.PI_HATCH_DIR = join(dir, "sub") // cannot be created inside a read-only dir
  const p = load()
  await p.fire("session_start")
  await p.fire("agent_start")
  await p.fire("session_shutdown")
  chmodSync(dir, 0o700)
})

test("no temp files are left behind", async () => {
  const p = load()
  await p.fire("session_start")
  await p.fire("agent_start")
  assert.deepEqual(readdirSync(dir), [`${process.pid}.json`])
})
