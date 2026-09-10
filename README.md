# Rabbit PowerShell Profile

A portable, cross-machine PowerShell 7 profile for Windows with a faster terminal workflow: fuzzy file search, smart directory jumping, Git shortcuts, terminal file management, a custom Oh My Posh prompt, and a one-shot installer that provisions the entire environment — CLI tools, desktop apps, PowerShell modules, bundled Nerd Fonts, Windows Terminal configuration, AutoHotkey `Win+...` hotkeys, and the app configs for atuin, git, Notepad++, Everything and opencode.

Everything resolves paths relative to its own folder (`$PSScriptRoot`) or `$HOME`, so the whole directory can be dropped onto any Windows 10/11 machine and work out of the box — including OneDrive-redirected Documents folders.

## Quick start

New Windows machine? Open **any** PowerShell window (Windows PowerShell 5.1 is fine) and run:

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/ADHD-exe/powershell/main/install.ps1 | iex
```

That installs the prerequisites, drops the profile into place, provisions every tool and app, and deploys the configs. No admin rights needed. Open a new `pwsh` window when it finishes.

## Repository Layout

```text
PowerShell/
├── install.ps1                        New-machine entrypoint: prerequisites, places the repo
│                                       in the profile folder, npm globals, runs the bootstrap
├── Microsoft.PowerShell_profile.ps1   Main profile: UTF-8, XDG vars, EDITOR, module self-install,
│                                       zoxide/atuin/oh-my-posh init, PSReadLine, key handlers
├── aliases-functions/
│   ├── aliases.ps1                    Aliases (oc/oco/ai, c/cls, vim/v, y, cat, grep, ...)
│   │                                   plus the screenshot commands (ss / ssw / ssr / ssc)
│   ├── aliases-git.ps1                168 Oh-My-Zsh-style Git functions (gs, ga, gc, gco, gb, ...)
│   ├── functions.ps1                  Core utilities, eza views, unzip, clipboard, command palette
│   └── mkcmd.ps1                      mkcmd / rmcmd: persist functions and aliases on the fly
├── completions/
│   └── tailscale-completions.ps1      Tab completions for Tailscale
├── keybinds-scripts/
│   ├── keybinds.ps1                   PSReadLine key chords (Ctrl+Shift+Z undo, Ctrl+Shift+X kill)
│   ├── notify.ps1                     Toast + bell when a long or failed command finishes
│   └── pwsh-icon.png                  Toast notification icon
├── settings/                          Everything the bootstrap deploys onto a machine
│   ├── oh-my-rabbit.omp.json          Oh My Posh theme
│   ├── settings.json                  Windows Terminal config
│   ├── fonts/                         FiraCode, EnvyCodeR and Monoid Nerd Fonts (+ licenses/)
│   ├── autohotkey/                    keybinds.ahk (Win+... hotkeys) and bandlab_ahk.ahk
│   ├── atuin/config.toml              Shell history search config
│   ├── git/gitconfig, ignore          Global git settings and global ignore file
│   ├── opencode/opencode.jsonc        opencode config
│   ├── notepad++/*.xml                Notepad++ config, shortcuts, stylers, langs, context menu
│   └── everything/Everything.ini      Everything search config
├── bootstrap-packages/
│   ├── bootstrap.ps1                  Packages, modules, fonts, Windows Terminal settings
│   └── deploy-configs.ps1             Deploys everything in settings/ to where each app reads it
├── powershell.config.json             Per-folder execution policy (RemoteSigned)
├── LICENSE                            MIT
├── .gitattributes                     Line-ending and binary rules
└── .gitignore
```

`Modules/` and `Scripts/` are git-ignored — they're provisioned at setup time, not committed.

## Installation

### 1. Quick install — one line

From any PowerShell window (Windows PowerShell 5.1 or PowerShell 7):

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/ADHD-exe/powershell/main/install.ps1 | iex
```

`install.ps1` is the new-machine entrypoint. It:

1. Checks for **winget**, then installs **git**, **PowerShell 7** and **Node.js LTS** if they're missing.
2. Works out the real PowerShell 7 profile folder (asking `pwsh` directly, so OneDrive redirection is handled) and places the repo there, backing up anything already present.
3. Sets the execution policy to `RemoteSigned` and writes `powershell.config.json`.
4. Installs the global npm packages the aliases point at (`openclaw`, `@anthropic-ai/claude-code`).
5. Hands off to `bootstrap-packages\bootstrap.ps1`.

No admin rights are required: every registry and font change is per-user (`HKCU`).

### 2. From an existing clone

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Useful switches:

| Switch | Effect |
| --- | --- |
| `-SkipBootstrap` | Place the files and prerequisites only; install no packages |
| `-Destination <path>` | Override the profile folder |
| `-Force` | Don't back up an existing profile folder before replacing it |
| `-RepoUrl` / `-Branch` | Clone from somewhere other than `main` |

### 3. Bootstrap only

If the profile is already in place and you just want packages and configs re-applied:

```powershell
pwsh -ExecutionPolicy Bypass -File .\bootstrap-packages\bootstrap.ps1
```

Every step is idempotent and safe to re-run. It installs anything missing:

- **CLI tools** (via `winget`, falling back to Chocolatey): `git`, `git-lfs`, `node`, `zoxide`, `oh-my-posh`, `atuin`, `fzf`, `fd`, `bat`, `eza`, `yazi`, `neovim`, `tailscale`, `opencode`
- **Desktop apps**: PowerShell 7, Windows Terminal, Notepad++, Firefox Developer Edition, paint.NET, Spotify, Everything, AutoHotkey, Winaero Tweaker, O&O ShutUp10, and Outlook for Windows (via the Microsoft Store)
- **PowerShell modules** from the PS Gallery: `Terminal-Icons`, `PSWriteColor`, `BurntToast`, `syntax-highlighting`, `PSEverything` (PSReadLine ships with PowerShell 7)
- **OpenCam**: clones [OpenCam](https://github.com/ADHD-exe/OpenCam) into `Documents\OpenCam`, builds it a private virtualenv, installs its Python requirements there, and adds a Start menu shortcut. Launch with `phonecam`, `Win+Alt+C`, or the shortcut
- **Modules from git**: `YouShouldUse` (not on the Gallery) is cloned into `Modules/YouShouldUse` and unblocked. The folder name has to match the `.psd1` basename or PowerShell can't discover it by name
- **Nerd Fonts**: installs everything in `settings\fonts` per-user (no admin needed) and registers it in the current-user font registry
- **Windows Terminal settings**: deploys `settings\settings.json` into the Terminal's `LocalState` folder, backing up any existing file
- **App configs**: hands off to `deploy-configs.ps1` (below)
- **Freyja** (optional, prompted): clones and wires the Freyja persona into the opencode config

### 4. Configs only

```powershell
pwsh -File .\bootstrap-packages\deploy-configs.ps1
```

Installing a program gives you a stock program. This step is what makes it *yours* — it deploys each vendored config to wherever that app reads it:

| Source in repo | Deployed to | Notes |
| --- | --- | --- |
| `settings\atuin\config.toml` | `~\.config\atuin\config.toml` | |
| `settings\git\gitconfig` | global git config | Merged setting by setting. No identity is vendored (public repo) - you're prompted for `user.name`/`user.email` only if the machine has none |
| `settings\git\ignore` | `~\.config\git\ignore` | Wired up as `core.excludesfile` |
| `settings\opencode\opencode.jsonc` | `~\.config\opencode\` | Skipped if an `opencode.json` already exists |
| `settings\notepad++\*.xml` | `%APPDATA%\Notepad++\` | `__USERPROFILE__` token swapped for the real path; skipped while Notepad++ is running |
| `settings\everything\Everything.ini` | `%APPDATA%\Everything\` | Skipped while Everything is running |
| `settings\autohotkey\*.ahk` | `~\Documents\AutoHotkey\` | `keybinds.ahk` gets a Startup shortcut and an Ahk2Exe syntax check |

It also sets the `DisabledHotkeys` registry value to free up the `Win+...` combos the AHK script binds, and puts Everything's CLI (`es.exe`) on the user PATH.

Anything it is about to replace is backed up alongside itself first (`<name>.bak-<timestamp>`), and identical files are left untouched. Pass `-Force` to deploy over a running Notepad++ or Everything.

> `bandlab_ahk.ahk` is deployed but deliberately **not** autostarted — it captures every alphanumeric key while running. Launch it by hand when you need it.

### 5. Restart PowerShell

Open a new `pwsh` window, or run `reload`.

> On first load the profile scans every `.ps1` file for `Import-Module` references and installs any referenced module that's missing, so the modules get installed even if you skip the bootstrap.

## Features

### Keybindings (PSReadLine)

| Shortcut | Action |
| --- | --- |
| `Ctrl+f` | Fuzzy file search with `fzf` + `bat` preview (git-aware: `git ls-files` inside repos, `fd` elsewhere) |
| `Alt+Space` | Smart directory jump with `zoxide` + `fzf` + `eza` preview |
| `Ctrl+y` | Open `yazi` and return to the selected directory |
| `Ctrl+Space` | Open the Rabbit command palette |
| `Tab` | Menu completion |
| `UpArrow` | atuin history search seeded with what you've typed (falls back to PSReadLine history when atuin isn't installed) |
| `Ctrl+r` | atuin full history search |
| `Ctrl+UpArrow` / `Ctrl+DownArrow` | PSReadLine prefix history search - the escape hatch from atuin |
| `Ctrl+Shift+Z` / `Ctrl+Shift+X` | Undo / Kill region |

Plus inline history prediction (`HistoryAndPlugin`) and a custom token color scheme.

> `UpArrow` and `Ctrl+r` are bound by `atuin init`. The profile checks whether the Atuin module actually loaded before binding the arrow keys itself, so it never overwrites them.

### AutoHotkey hotkeys (Win+...)

From `settings\autohotkey\keybinds.ahk`, deployed to `Documents\AutoHotkey\` and auto-started at login (AutoHotkey v2):

| Shortcut | Action | Shortcut | Action |
| --- | --- | --- | --- |
| `Win+Enter` | PowerShell 7 | `Win+z` / `Win+Alt+z` | Undo / Redo |
| `Win+b` | Firefox Developer Edition | `Win+x` / `Win+c` / `Win+v` | Cut / Copy / Paste |
| `Win+n` | Notepad++ | `Win+q` | Close active window (Alt+F4) |
| `Win+s` | Spotify | `Win+PgDn` / `Win+PgUp` | Minimize / Maximize |
| `Win+d` | Discord | `Win+Alt+n` | Available-networks flyout |
| `Win+f` | File Explorer | `Win+Alt+v` | Classic volume mixer |
| `Win+m` | Microsoft Store | `Win+y` | Windows Mobility Center |
| `Win+e` | eM Client | `Win+Alt+c` | **OpenCam** (phone as webcam) |

App paths use AutoHotkey's own `A_ProgramFiles` / `A_AppData` variables, so the script is portable across usernames.

### Git

A complete Oh-My-Zsh-style Git command set lives in `aliases-functions/aliases-git.ps1` (168 functions). Highlights:

| Command | Action | Command | Action |
| --- | --- | --- | --- |
| `gs` / `gst` | `git status` | `gb` / `gd` | `git branch` / `git diff` |
| `gl` / `gp` | `git pull` / `git push` | `gcl` | `git clone --recursive` |
| `ga` / `gaa` | `git add` / `git add -A` | `ggl` / `ggp` | Pull / push current branch |
| `gc` / `gcm` | `git commit` / commit and checkout main | `glog` / `glol` | Compact, colorful git log |
| `gco` / `gcb` | `git checkout` / `checkout -b` | `gpf` | `git push --force-with-lease` |

Fast one-liners from `aliases-functions/functions.ps1`: `gpull`, `gcom <msg>` (add + commit), `lazyg <msg>` (add + commit + push).

### Everyday commands

| Command | Action |
| --- | --- |
| `notepad` / `edit` | Open files in Notepad++ |
| `fn` / `al` / `theme` | Edit the functions file / aliases file / Oh My Posh theme |
| `profile` / `ep` | Edit the active profile in Neovim |
| `reload` / `rl` | Reload the PowerShell profile |
| `mkcmd <name> "<value>"` / `rmcmd <name>` | Create or remove a persisted function/alias |
| `ls` / `ll` / `la` / `lt` | `eza` views: grid / long / long incl. hidden / 2-level tree. All take a path and extra flags (`ls src`, `la -s size`) |
| `yy` / `y` | Open `yazi` and cd to the chosen directory |
| `ss` / `ssw` / `ssr` / `ssc` | Screenshot: full screen / active window / region snip / to clipboard |
| `notify <msg>` | Fire a toast notification |
| `Search-Everything <query>` | Instant filename search via Everything (PSEverything) |
| `cbcopy` / `cbpaste` | Clipboard text helpers (pipeline-friendly) |
| `Copy-Pwd` / `Copy-Path` / `copyfile` | Copy the current directory / a file's path / a file's contents |
| `head` / `tail` / `touch` / `which` | File and command basics |
| `unzip <file> [dest]` | `Expand-Archive` wrapper; extracts to the current folder by default, `-Force` to overwrite |
| `phonecam` | Launch OpenCam - use your phone as a wireless webcam |
| `web <url>` / `search` / `bing` / `ddg` / `so` / `gh-search` | Open a URL or search the web |
| `pgrep` / `pkill` / `k9` | Manage processes by name |
| `uptime` / `sysinfo` / `Port <n>` | System info and open ports |
| `Admin` / `rsex` / `reboot` | Elevated shell / restart Explorer / reboot |
| `man <cmd>` | `Get-Help <cmd> -Full` - the full article by default. `-Examples`, `-Detailed`, `-Online`, `-ShowWindow`, `-Parameter <n>` forward to the matching view |
| `forget <pattern>` | Remove matching lines from PSReadLine history |

Long-running or failed commands fire a toast and a terminal bell automatically — see `keybinds-scripts/notify.ps1` (threshold: 8 seconds).

### Aliases

| Alias | Target | Alias | Target |
| --- | --- | --- | --- |
| `oc` | `openclaw` | `y` | `yy` |
| `oco` / `ai` | `opencode` | `ws` / `wi` | `winget search` / `install` |
| `c` / `cls` | `clear` | `cat` | `bat` (if installed) |
| `vim` / `v` | `nvim` | `grep` | `Select-String` |
| `reload` / `rl` | `Reload-Profile` | `profile` / `ep` | `Edit-Profile` |
| `rsex` | `Restart-Explorer` | `reboot` | `Restart-System` |

### Navigation helpers

`..` / `...` / `....` up one, two or three levels · `home` · `dl` · `desk` · `docs` (OneDrive-aware) · `mkcd <dir>`

## Requirements

- Windows 10/11
- PowerShell 7+ (the profile uses PS7-only syntax such as `??=` and `?.`)
- `winget` (App Installer) — `install.ps1` requires it for the prerequisites; the bootstrap falls back to Chocolatey for individual packages
- Node.js — only for the `openclaw` and `claude-code` npm globals
- Python 3.9+ — only for OpenCam, which gets its own virtualenv so its dependencies stay out of your system Python

## Notes

- Everything is path-relative (`$PSScriptRoot`) or `$HOME`-based — no hardcoded usernames — so it works regardless of the profile location or OneDrive redirection.
- `zoxide`, `atuin`, and `oh-my-posh` are only initialized if the tool is installed.
- The vendored `gitconfig` carries **no name or email** - this repo is public. `deploy-configs.ps1` prompts for them on a machine that has none, and never touches an existing identity. Behavioural settings (the `git@github.com:` URL rewrite, the global ignore file) are always applied.
- That URL rewrite means every HTTPS GitHub clone becomes SSH on any machine this config is deployed to, so `git pull` there needs working SSH keys.
- `.gitattributes` normalizes line endings to LF in the repo and CRLF in the working copy, which is what silences git's "LF will be replaced by CRLF" warnings.
- `ls`, `ll`, `la` and `lt` are functions, not aliases, so they can pass a path and extra flags through to `eza`. PowerShell's built-in `ls` alias is removed at load time - an alias would outrank the function and silently drop the view flags.
- Three things wrap the prompt: oh-my-posh, `notify.ps1` and `YouShouldUse`. `Reload-Profile` unwinds that chain before re-sourcing, because a dot-sourced reload runs in the function's scope and can't regenerate oh-my-posh's prompt - without unwinding, the wrappers wrap each other and overflow the call stack.
- `YouShouldUse` is imported at the *end* of the profile, not in the module list at the top, because it has to hook the prompt after oh-my-posh and `notify.ps1` have set theirs.
- `man` replaces PowerShell's built-in `man`->`help` alias so it can default to `-Full`. The stock summary view is still one keystroke away as `help <cmd>`.
- Full help articles only exist locally once `Update-Help -Scope CurrentUser` has run; it writes them to `Help/` in this folder, which is git-ignored.
- Clipboard helpers are `cbcopy` / `cbpaste`, not `copy` / `paste`: `copy` is a built-in alias for `Copy-Item`, and aliases beat functions, so a `copy` function could never run.
- `unzip` shadows the Info-ZIP `unzip.exe` that ships with Git for Windows. Call `& 'C:\Program Files\Git\usr\bin\unzip.exe'` if you need the original.
- Files are UTF-8. The command palette matches entries by emoji, so keep the files encoded as UTF-8 if you edit them.

## License

MIT
