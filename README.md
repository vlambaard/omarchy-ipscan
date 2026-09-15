# omarchy-ipscan

A terminal-native network scanner for [Omarchy](https://omarchy.org) — an Angry IP
Scanner replacement that never leaves the keyboard.

It sweeps a subnet with `nmap`, enriches the results with MAC addresses and hardware
vendors, and drops you into an `fzf` picker where you can ssh, copy, open, or
port-scan any host. No GUI, no root, no daemon.

```
╭─ 󰛳 omarchy-ipscan ───────────────────────────────────────────────╮
│ 192.168.10.0/24 · wlp11s0 · 6 up/256 · 2s                        │
│ ↵ ssh  ^y copy  ^o http  ^p ports  ^r rescan  ^e export  esc quit│
│                                     │                            │
│ ▸ 󰑩 192.168.10.1     _gateway   4ms │   󰑩 192.168.10.1           │
│   󰄜 192.168.10.149   (randomiz  69ms│   ────────────────────────  │
│   󰇄 192.168.10.170   -         120ms│   host    _gateway         │
│ ▌ 󰌢 192.168.10.173   workstation       <1ms │   mac     d4:01:c3:aa:bb:cc│
│   󰐪 192.168.10.178   Canon      22ms│   vendor  Routerboard.com  │
│   󰍹 192.168.10.223   Guangzhou  71ms│   type    router (inferred)│
│                                     │   rtt     4ms              │
│   6/6                               │   source  nmap+arp         │
│   filter ▸                          │   ports   ^p to probe      │
╰─────────────────────────────────────┴────────────────────────────╯
```

## Install

```bash
git clone <this-repo> ~/code/oma-ipscan
cd ~/code/oma-ipscan
./install.sh
```

`install.sh` symlinks the script into `~/.local/bin`, installs a desktop entry into
`~/.local/share/applications`, and reports which optional engines are present. It
touches nothing outside `$HOME` and never asks for root.

### Dependencies

| Package         | Required | Used for                                   |
|-----------------|----------|--------------------------------------------|
| `nmap`          | yes      | host discovery, and the OUI vendor database |
| `gum`           | yes      | prompt, spinner, export chooser             |
| `fzf`           | yes      | the result picker                           |
| `arp-scan`      | no       | MAC addresses; also finds hosts that ignore ICMP |
| `fping`         | no       | fallback sweep when `nmap` is absent        |
| `wl-clipboard`  | no       | `ctrl-y` copy                               |
| `jq`            | no       | prettier JSON export (falls back to awk)    |

```bash
sudo pacman -S nmap gum fzf arp-scan fping wl-clipboard jq
```

Every optional engine is detected at startup. A missing one removes a column or a
keybind — it never aborts the scan.

## Usage

```bash
omarchy-ipscan                          # auto-detect the subnet, confirm, browse
omarchy-ipscan 192.168.10.0/24          # CIDR
omarchy-ipscan 192.168.10.1-50          # hyphen range
omarchy-ipscan 192.168.10.1             # single host
omarchy-ipscan nas.local                # hostname (resolved first)
omarchy-ipscan --csv hosts.csv          # headless export
omarchy-ipscan -q | awk -F'\t' '$2!="-"'  # pipe-friendly
```

With no argument the subnet is taken from the **default route** and offered as a
prefilled prompt, so a bare invocation plus Enter does the right thing. Interfaces
that are not on the default route — docker and libvirt bridges in particular — are
deliberately ignored.

### Keybinds

| Key      | Action                                     |
|----------|--------------------------------------------|
| `enter`  | ssh to the highlighted host                |
| `ctrl-y` | copy selected IP(s) to the clipboard       |
| `ctrl-o` | open `http://<ip>` in the browser          |
| `ctrl-p` | port-scan the host (top 20 ports)          |
| `ctrl-r` | rescan the same target                     |
| `ctrl-e` | export to CSV or JSON                      |
| `tab`    | multi-select                               |
| `ctrl-a` | select all                                 |
| `?`      | toggle the detail pane                     |
| `esc`    | quit                                       |

### Flags

Run `omarchy-ipscan --help` for the full list, including `--iface`, `--ports`,
`--icons on|off|auto`, `--csv`, `--json` and `--quiet`.

## Hyprland keybind

**Omarchy 3.x and newer uses Lua config.** Add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + I", "IP Scanner", { tui = "omarchy-ipscan" })
```

`{ tui = ... }` routes through `omarchy-launch-tui`, which opens your default
terminal with Omarchy's styling and a floating `TUI.*` app-id. Use
`{ tui = "omarchy-ipscan", focus = true }` to focus an existing window instead of
opening a second one.

On **older Omarchy releases that still use `~/.config/hypr/bindings.conf`**, the
equivalent is:

```ini
bind = SUPER SHIFT, I, exec, uwsm app -- xdg-terminal-exec --app-id=TUI.float -e omarchy-ipscan
```

Reload with `hyprctl reload` (or just log out and back in).

## Design notes

**Vendors come from nmap, not arp-scan.** `arp-scan`'s bundled `ieee-oui.txt` is
stale and returns `(Unknown)` for most modern hardware; nmap ships a 52k-entry
`nmap-mac-prefixes` that resolves the same MACs correctly. So MACs are taken from
`arp-scan` and vendor names are looked up in nmap's database, in a single pass.

**Both discovery sources are unioned.** `arp-scan` regularly finds hosts that drop
ICMP and never appear in the nmap sweep. Results from either engine are merged and
then clipped to the requested range — `arp-scan` always sweeps the whole local
subnet, so a narrow target would otherwise return hosts outside it. The `sources`
column records which engine saw each host.

**Randomised MACs are labelled, not misattributed.** A MAC with the
locally-administered bit set has no real vendor; it is shown as `(randomized)`
rather than being matched against a meaningless OUI.

**Device types are inferred, and say so.** The class shown in the detail pane is a
guess derived from the vendor string and is marked `(inferred)`.

**Theme-aware by construction.** Only ANSI colours 0–15 and `gum`/`fzf` defaults are
used — no hardcoded hex. Omarchy themes recolour the terminal, and hardcoded values
would clash with every theme but the one they were picked for. `NO_COLOR` is
honoured, and output is plain when stdout is not a TTY.

**Icons degrade.** Device glyphs are drawn from a single Nerd Font range (`nf-md`)
so every glyph has the same display width and columns stay aligned. If no Nerd Font
is detected they are dropped automatically; `--no-icons` forces that.

**No root, ever.** `nmap -sn` runs unprivileged and `arp-scan` relies on its
`cap_net_raw` file capability. If that capability is missing, the MAC and vendor
columns are skipped and the scan continues.

## Notes

Scratch files live in a single `mktemp -d` removed by an `EXIT` trap; `INT`/`TERM`
reap child scanners so Ctrl-C mid-sweep leaves no stray `nmap` processes and
restores the cursor. Set `OIPS_KEEP=1` to keep the scratch directory for debugging.

Shellcheck clean at `-S style`.
