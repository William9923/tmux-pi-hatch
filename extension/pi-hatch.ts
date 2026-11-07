// tmux-pi-hatch Pi extension: publishes this Pi's status for the tmux picker.
//
// Copy or symlink to ~/.pi/agent/extensions/pi-hatch.ts (see the README). It only
// tracks interactive Pi running inside tmux, and writes one small JSON file per
// process. It never records prompts or transcript text, and any failure is
// swallowed so Pi and the conversation are never affected.

import { execFileSync } from "node:child_process"
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

type Status = "working" | "ready" | "prompt" | "aborted"

// Field 22 of /proc/<pid>/stat (process start time). Strip greedily past ") " first:
// field 2 is the command name and may itself contain ") ". Field 22 is then the 20th.
function procStart(): string {
  const rest = readFileSync("/proc/self/stat", "utf8").trim().replace(/^.*\) /, "")
  return rest.split(" ")[19] ?? ""
}

export default function (pi: ExtensionAPI) {
  const pane = process.env.TMUX_PANE
  if (!pane) return // outside tmux: not tracked

  let enabled = false
  let status: Status = "ready"
  let cwd = process.cwd()
  const file = () =>
    join(process.env.PI_HATCH_DIR || join(process.env.XDG_RUNTIME_DIR || "/tmp", "tmux-pi-hatch"), `${process.pid}.json`)

  function publish() {
    const path = file()
    mkdirSync(join(path, ".."), { recursive: true, mode: 0o700 })
    // Explicit fields only: nothing from events (prompts, titles, messages) is stored.
    const record = {
      pid: process.pid,
      procStart: procStart(),
      paneId: pane,
      socket: (process.env.TMUX ?? "").split(",")[0],
      cwd,
      status,
      updatedAt: Math.floor(Date.now() / 1000),
    }
    writeFileSync(`${path}.tmp`, JSON.stringify(record))
    renameSync(`${path}.tmp`, path) // atomic: the picker never sees a half-written file
  }

  const set = (next: Status, ctx?: { cwd?: string }) => {
    if (!enabled) return
    if (ctx?.cwd) cwd = ctx.cwd
    status = next
    publish()
  }
  // A real BEL on the pane's pty, which tmux turns into a bell alert. /dev/tty is the
  // pane itself; if Pi has no controlling terminal, ask tmux for the pane's tty.
  // PI_HATCH_TTY overrides /dev/tty (tests).
  function ring() {
    if (!enabled) return
    try {
      writeFileSync(process.env.PI_HATCH_TTY || "/dev/tty", "\x07", { flag: "a" })
    } catch {
      try {
        const tty = execFileSync("tmux", ["display-message", "-p", "-t", pane!, "#{pane_tty}"], {
          encoding: "utf8",
          timeout: 1000,
        }).trim()
        if (tty) writeFileSync(tty, "\x07", { flag: "a" })
      } catch {} // a missed bell must never break Pi
    }
  }
  // Every handler is wrapped so a registry failure can never break Pi.
  const on = (event: string, fn: (e: any, ctx: any) => void) =>
    (pi as any).on(event, async (e: any, ctx: any) => {
      try {
        fn(e, ctx)
      } catch {}
    })

  on("session_start", (_e, ctx) => {
    enabled = !!ctx.hasUI // pi -p / RPC runs are not tracked
    set("ready", ctx)
  })
  on("agent_start", (_e, ctx) => set("working", ctx))
  on("agent_settled", (e, ctx) => {
    set(e.aborted ? "aborted" : "ready", ctx)
    ring()
  })
  on("ui_prompt_start", (_e, ctx) => {
    set("prompt", ctx)
    ring()
  })
  on("ui_prompt_end", (_e, ctx) => set(ctx.isIdle() ? "ready" : "working", ctx))
  on("session_shutdown", () => {
    enabled = false
    rmSync(file(), { force: true })
  })
}
