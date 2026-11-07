# tmux-pi-hatch

A small tmux plugin for [Pi](https://pi.dev): run Pi in a popup for each project folder,
hand it work, close the popup, and carry on. Closing never stops Pi. A picker lists
every Pi running on your tmux server, shows which one needs you, and jumps to it. A bell
tells you when a Pi finishes or blocks on a prompt.

Inspired by [tmux-claude-hatch](https://github.com/craftzdog/tmux-claude-hatch), but Pi-only.
A few shell scripts plus one small Pi extension.

## How it works

- `prefix` + `y` opens (or re-attaches to) a Pi for the current pane's folder in a popup. Each
  exact folder path gets its own tmux session (`pi-<hash>`), so every git worktree gets its own Pi.
- Press `prefix` + `y` again inside the popup (or `prefix` + `d`) to close it. Pi keeps running.
- `prefix` + `u` opens the picker (fzf-lua style: list on the left, live preview on the right, below it on a narrow screen): every live Pi on this tmux server, with status, age,
  location, project path and a live preview. Enter on a hatch-launched Pi reopens its popup;
  Enter on a Pi you started by hand focuses its pane.
- A **Pi extension** (below) reports each Pi's status. Without it the picker is empty.

| Status | Colour | Meaning |
| --- | --- | --- |
| `prompt` | red | an extension dialog (`select`/`confirm`/`input`/`editor`/`custom`) is waiting for you |
| `stopped` | red | the run was interrupted |
| `ready` | green | idle, or the run settled normally |
| `working` | yellow | Pi is running |

Order: red, green, yellow; newest first within each. A normal assistant reply that asks a
question is `ready`; Pi has no event for that, and the text is never parsed.

## Requirements

Linux, tmux >= 3.2, [fzf](https://github.com/junegunn/fzf), [jq](https://jqlang.org/), Pi.
Only the current tmux server is covered; other tmux sockets are not listed.

## Installation

### 1. The tmux plugin

With [tpm](https://github.com/tmux-plugins/tpm), in `tmux.conf`, then `prefix` + `I`:

```tmux
set -g @plugin 'William9923/tmux-pi-hatch'
```

Or clone it and load it by hand. Put this **after** any bindings of your own for `y`/`u`:

```tmux
run-shell /path/to/tmux-pi-hatch/pi_hatch.tmux
```

### 2. The Pi extension

The tmux plugin does not touch `~/.pi`; copy the extension yourself. Set `PLUGIN` to where the
plugin lives (tpm: `~/.tmux/plugins/tmux-pi-hatch` or `~/.config/tmux/plugins/tmux-pi-hatch`):

<!-- test:extension-install -->
```sh
mkdir -p ~/.pi/agent/extensions
cp "$PLUGIN/extension/pi-hatch.ts" ~/.pi/agent/extensions/pi-hatch.ts   # or: ln -sf, to follow updates
```

Restart Pi, or run `/reload` in a running one. The extension tracks only interactive Pi
inside tmux. `pi -p`, RPC mode, and Pi outside tmux are not tracked. It runs with your user
permissions, so read it first: `extension/pi-hatch.ts` is about 100 lines.

What it writes: one file per Pi process, `$XDG_RUNTIME_DIR/tmux-pi-hatch/<pid>.json`, holding
only `pid`, process start time, tmux pane id and socket, working directory, status and time.
No prompts or transcript text. It rings the terminal bell when a prompt starts and when Pi
settles. Any failure in it is swallowed; it cannot break Pi.

## Keys

| Key | Action |
| --- | --- |
| `prefix` + `y` | open / re-attach the popup for this folder; inside the popup, close it |
| `prefix` + `d` | close the popup (tmux's usual detach) |
| `prefix` + `u` | open the picker (from inside a popup it closes the popup first) |
| picker: `enter` | jump to the Pi; `↑`/`↓`, type to filter, `esc` to close |

There is deliberately no kill key: `ready` can mean "done" or "waiting for your reply".

## Options

Set before the plugin loads (defaults shown):

```tmux
set -g @pi_hatch_launch_key   'y'    # prefix key: open/toggle the popup
set -g @pi_hatch_list_key     'u'    # prefix key: open the picker
set -g @pi_hatch_command      'pi'   # run in new sessions, e.g. 'fish -lic pi' or 'pi --model x'
set -g @pi_hatch_popup_width  '95%'
set -g @pi_hatch_popup_height '95%'
set -g @pi_hatch_fzf_options  ''     # extra fzf options for the picker
set -g @pi_hatch_forward_bell 'on'   # highlight the launch window on a bell
```

A new hatch session always starts a fresh Pi (no `--continue`); use `/resume` inside Pi.

## Bell

Pi rings a real bell (`\a`) in its pane on a prompt and when it settles. For a hatch session
the plugin forwards it to the window you launched from, so tmux highlights that window.
For this it sets `bell-action any` on the hatch sessions only; it works even if your global
`bell-action` is `none`. Pi started by hand just rings in its own pane. Whether you also *hear* it
depends on tmux's `bell-action`/`visual-bell` for the window you are looking at and on your terminal.
No desktop notifications are sent.
`alert-bell` is a single global hook; the plugin sets it, replacing any other one at index 0.

## Limitations

- A completed answer and a question look the same (`ready`).
- A Pi killed abruptly leaves a record behind; the picker checks pid and start time and removes it.
- One hatch Pi per exact folder path.

## Tests

`bash tests/run.sh` runs everything on throwaway tmux servers and never touches yours.
