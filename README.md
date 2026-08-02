# Rabbit PowerShell Profile

A portable, cross-machine PowerShell 7 profile for Windows with a faster terminal workflow: fuzzy file search, smart directory jumping, Git shortcuts, terminal file management, a custom Oh My Posh prompt, and a one-shot bootstrap that provisions the entire environment — CLI tools, PowerShell modules, bundled Nerd Fonts, Windows Terminal configuration, and AutoHotkey `Win+...` app hotkeys.

Everything resolves paths relative to its own folder (`$PSScriptRoot`) or `$HOME`, so the whole directory can be dropped onto any Windows 10/11 machine and work out of the box — including OneDrive-redirected Documents folders.

## Repository Layout

```text
PowerShell/
├── Microsoft.PowerShell_profile.ps1   Main entrypoint: UTF-8, XDG vars, EDITOR, module self-install,
│                                       zoxide/atuin/oh-my-posh init, PSReadLine, key handlers, sources .ps1
├── aliases-keybinds/
│   ├── aliases.ps1                    Aliases (oc/ai, c/cls, vim/v, y, ls/cat, grep, reload, profile, ep, rsex, ...)
│   ├── aliases-git.ps1                168 Oh-My-Zsh-style Git functions (gs, ga, gc, gco, gb, gl, gp, glog, ...)
│   └── keybinds.ps1                   PSReadLine key chords (Ctrl+Shift+Z undo, Ctrl+Shift+X kill region)
├── completions/
│   └── tailscale-completions.ps1      Tab completions for Tailscale (harmless if not installed)
├── scripts-functions/
│   ├── functions.ps1                  Core utilities, Notepad++ launcher, clipboard, system, command palette
│   └── mkcmd.ps1                      mkcmd / rmcmd: create and remove persisted functions/aliases on the fly
├── color.schemes-fonts/
│   ├── oh-my-rabbit.omp.json          Oh My Posh theme ("RabbitsHabits" color scheme)
│   ├── settings.json                  Windows Terminal template (deployed by bootstrap, path-tokenized)
│   └── FiraCode/                      Bundled FiraCode Nerd Font (regular, Mono, Propo) — installed by bootstrap
├── bootstrap-packages/
│   ├── bootstrap.ps1                  One-time setup: packages, modules, fonts, terminal settings, keybinds
│   └── registry-tweaks.ps1            Standalone Winaero registry tweaks (prompted by the bootstrap)
├── LICENSE                            MIT
├── README.md
└── .gitignore
```

`Modules/` (installed PowerShell modules), `Scripts/`, and the machine-specific `bootstrap-packages/wingit-list.txt` / `pwshpack.ps1` snapshots are git-ignored — they're provisioned at setup time, not committed.

## Installation

### 1. Quick install — copy, paste, run

Run this block from any PowerShell window (Windows PowerShell 5.1 or PowerShell 7). It downloads the repo, places it in your profile folder, and runs the bootstrap:

```powershell
# Requires git (install it first with: winget install -e --id Git.Git)
$tmp  = Join-Path $env:TEMP "rabbit-profile"
$dst  = Join-Path $HOME "Documents\PowerShell"
git clone --depth 1 https://github.com/ADHD-exe/powershell.git $tmp
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item -Path "$tmp\*" -Destination $dst -Recurse -Force
Remove-Item -Path $tmp -Recurse -Force
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $shell -NoProfile -ExecutionPolicy Bypass -File "$dst\bootstrap-packages\bootstrap.ps1"
```

If you ran it from Windows PowerShell, the bootstrap will install PowerShell 7 as part of its package list — open a new `pwsh` window afterwards to start using the profile.

> Notes:
> - The repo is self-contained and path-relative, so it works from any location; placing it at `$HOME\Documents\PowerShell` just makes it load automatically as your profile.
> - If your Documents folder is redirected to OneDrive, the profile will live under `$HOME\OneDrive\Documents\PowerShell` instead — move the files there (or see the manual steps below).
> - No admin rights are required: every registry and font change the bootstrap makes is per-user (`HKCU`).

### 2. Manual install

Copy this entire folder (keep the subfolders intact) into your PowerShell 7 profile directory:

```text
$PROFILE        → C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
profile folder  → C:\Users\<you>\Documents\PowerShell\
```

Use `$PROFILE` to find the exact location on your machine. If your Documents folder is redirected to OneDrive, the profile lives under `$HOME\OneDrive\Documents\PowerShell` — that's fine, everything is resolved relative to the profile folder.

Then run the bootstrap script:

```powershell
pwsh -ExecutionPolicy Bypass -File .\bootstrap-packages\bootstrap.ps1
```

The bootstrap installs anything that's missing and is safe to re-run (every step is idempotent):

- **CLI tools** (with `winget`, falling back to Chocolatey): `zoxide`, `oh-my-posh`, `atuin`, `fzf`, `fd`, `bat`, `eza`, `yazi`, `neovim`, `notepad++`, `everything`, `autohotkey`
- **Desktop apps**: `powershell 7`, `firefox developer edition`, `paint.net`, `windows terminal`, `spotify`, and `outlook for windows` (via the Microsoft Store)
- **PowerShell modules** from the PS Gallery: `Terminal-Icons`, `PSWriteColor`, `alias-tips` (PSReadLine ships with PowerShell 7)
- **FiraCode Nerd Fonts**: installs the bundled fonts from `color.schemes-fonts\FiraCode` per-user (no admin needed) and registers them in the current-user font registry
- **Windows Terminal settings**: deploys `color.schemes-fonts\settings.json` into the Terminal's `LocalState` folder (backing up any existing file), token-replacing the username so it's portable — all profiles use **FiraCode Nerd Font** and minimize to the notification area (tray) instead of the taskbar
- **AutoHotkey keybinds**: writes `Documents\AutoHotkey\keybinds.ahk` with detected app paths, validates it via Ahk2Exe, registers a startup shortcut, sets the `DisabledHotkeys` registry value to free up the `Win+...` combos, and adds Everything's CLI (`es.exe`) to the user PATH
- **Registry tweaks (optional)**: the bootstrap prompts whether to run `bootstrap-packages\registry-tweaks.ps1`, which applies the Winaero privacy / context-menu / icon-cache tweaks from `Winaero-Tweaker-Settings.ini` — per-user (`HKCU`), no admin required, and idempotent (each value is read before it is written)

### 3. Restart PowerShell

Open a new session, or run `reload`.

> On first load the profile scans every `.ps1` file for `Import-Module` references and installs any referenced module that's missing, so `Terminal-Icons`/`PSWriteColor`/`alias-tips` get installed automatically even if you skip the bootstrap.

## Features

### Keybindings (PSReadLine)

| Shortcut | Action |
| --- | --- |
| `Ctrl+f` | Fuzzy file search with `fzf` + `bat` preview (git-aware: `git ls-files` inside repos, `fd` elsewhere) |
| `Alt+Space` | Smart directory jump with `zoxide` + `fzf` + `eza` preview |
| `Ctrl+y` | Open `yazi` and return to the selected directory |
| `Ctrl+Space` | Open the Rabbit command palette |
| `Tab` | Menu completion |
| `Ctrl+UpArrow` / `Ctrl+DownArrow` | History search backward / forward |
| `Ctrl+Shift+Z` / `Ctrl+Shift+X` | Undo / Kill region |

Plus inline history prediction (`HistoryAndPlugin`), a custom token color scheme, and `Ctrl+Shift+Space` for the command palette.

### AutoHotkey app hotkeys (Win+...)

Set up by the bootstrap via `Documents\AutoHotkey\keybinds.ahk` (AutoHotkey v2, auto-starts at login):

| Shortcut | Action |
| --- | --- |
| `Win+Enter` | PowerShell 7 |
| `Win+B` | Firefox Developer Edition |
| `Win+F` | File Explorer |
| `Win+N` | Notepad++ |
| `Win+P` | paint.NET |
| `Win+T` | Windows Terminal |
| `Win+M` | Outlook for Windows |
| `Win+S` | Spotify |
| `Win+Alt+S` | System Settings |
| `Win+/` | PhoenixOS Search (if installed) |
| `Win+Z` / `Win+X` / `Win+C` / `Win+V` | Undo / Cut / Copy / Paste |
| `Win+A` | Redo |
| `Win+Q` | Close active window |

The bootstrap disables the conflicting built-in Windows shortcuts via the `DisabledHotkeys` user registry value (`A, B, C, F, M, N, P, Q, S, T, V, X, Z`).

### Git

A complete Oh-My-Zsh-style Git command set lives in `aliases-git.ps1` (168 functions). Highlights:

| Command | Action |
| --- | --- |
| `gs` / `gst` | `git status` |
| `gl` / `gp` | `git pull` / `git push` |
| `ga` / `gaa` | `git add` / `git add -A` |
| `gc` / `gcm` | `git commit` / commit and checkout main (auto-detected) |
| `gco` / `gcb` | `git checkout` / checkout -b |
| `gb` / `gd` | `git branch` / `git diff` |
| `gcl` | `git clone --recursive` |
| `ggl` / `ggp` | Pull / push current branch to origin |
| `glog` / `glol` | Compact, colorful git log |
| `gpf` | `git push --force-with-lease` |
| `gsta` / `grh` | Stash / reset --hard |

Fast one-liners (defined in `functions.ps1`):

| Command | Action |
| --- | --- |
| `gpull` | `git pull` |
| `gcom <msg>` | `git add .` + `git commit -m <msg>` |
| `lazyg <msg>` | `git add .` + `git commit -m <msg>` + `git push` |

### Everyday commands

| Command | Action |
| --- | --- |
| `notepad` / `edit` | Open files in Notepad++ (auto-detected in `Program Files` / `Program Files (x86)`) |
| `fn` / `al` / `theme` | Edit the functions file / aliases file / Oh My Posh theme in Notepad++ |
| `profile` | Edit the active profile in Neovim |
| `reload` | Reload the PowerShell profile |
| `mkcmd <name> "<value>"` | Create a function or alias and persist it to `functions.ps1` |
| `rmcmd <name>` | Remove a persisted function/alias |
| `ll` / `lt` | `eza` detailed listing / 2-level tree view |
| `yy` | Open `yazi` and cd to the chosen directory |
| `copy` / `paste` | Clipboard text helpers (pipeline-friendly) |
| `Copy-Pwd` / `Copy-Path` | Copy the current directory / a file's full path |
| `head` / `tail` | View the first / last lines of a file |
| `touch` | Create a file or bump its timestamp |
| `which` | Show the full path of a command |
| `web <url>` | Open a URL in the default browser |
| `search <query>` | Google search from the shell |
| `pgrep` / `pkill` / `k9` | Manage processes by name |
| `uptime` / `sysinfo` | System uptime / OS + CPU info |
| `Admin` | New elevated PowerShell window |
| `Port <n>` | Show connections on a port |
| `rsex` | Restart Explorer (stops and relaunches it) |
| `forget <pattern>` | Remove matching lines from PSReadLine history |
| `help! <cmd>` | `Get-Help` for a command |
| `burn` | History wipe routine (placeholder) |

### Aliases

| Alias | Target | Alias | Target |
| --- | --- | --- | --- |
| `oc` / `ai` | `opencode` | `y` | `yy` |
| `c` / `cls` | `clear` | `ls` | `ll` (or `eza`) |
| `vim` / `v` | `nvim` | `cat` | `bat` (if installed) |
| `grep` | `Select-String` | `reload` | `Reload-Profile` |
| `profile` | `Edit-Profile` | `ep` | `Edit-Profile` |
| `rsex` | `Restart-Explorer` | `burn` / `help!` | functions |

### Navigation helpers

| Command | Action |
| --- | --- |
| `..` / `...` / `....` | Up one / two / three directories |
| `home` | Go to the home directory |
| `dl` / `desk` | Go to `~/Downloads` / `~/Desktop` |
| `docs` | Go to the real Documents folder (OneDrive-aware) |
| `mkcd <dir>` | Create a directory and move into it |

## Requirements

- Windows 10/11
- PowerShell 7+ (the profile uses PS7-only syntax such as `??=` and the null-conditional operator)
- `winget` or Chocolatey recommended for the bootstrap installs
- FiraCode Nerd Font — bundled in `color.schemes-fonts\FiraCode` and installed by the bootstrap (best prompt/icon rendering; also set as the Windows Terminal default font)

## Notes

- Everything is path-relative (`$PSScriptRoot`) or `$HOME`-based — no hardcoded usernames — so it works regardless of the profile location or OneDrive redirection.
- `zoxide`, `atuin`, and `oh-my-posh` are only initialized if the tool is installed.
- File search prefers `git ls-files` inside Git repositories and falls back to `fd` elsewhere.
- The Windows Terminal template (`settings.json`) is username-tokenized at deploy time; a copy of the current live config is always backed up before overwriting.
- Files are UTF-8. The command palette matches entries by emoji, so keep the files encoded as UTF-8 if you edit them.

## License

MIT
