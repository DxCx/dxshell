# dxshell

A portable, reproducible dev shell that gives you a consistent terminal environment on any Linux machine. One command, zero config.

## Quick Start

A single curl-pipeable command that installs Nix (if missing) and drops you into a fully configured dxshell session. If Nix is already on PATH, the install step is skipped — re-runs are idempotent.

### Local user — no sudo

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --user
```

Installs [`nix-portable`](https://github.com/DavHau/nix-portable) into `~/.local/bin` and stores all Nix state in `~/.nix-portable/`. **Nothing outside your `$HOME` is touched** — no sudo, no `/nix`. Works on shared `$HOME` mounts (e.g., NFS) across multiple servers, as long as they share the same CPU architecture.

### Server — with sudo

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --system
```

Installs Nix in multi-user mode (daemon at `/nix`, shared by all users). Prompts for sudo once during the Nix install.

For permanent install (sets dxshell as your login shell), append `install`:

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --system install
```

If you'd rather install Nix yourself or wire things up by hand, see [Manual setup](#manual-setup) below.

## What's Included

### Shell

| Tool | Replaces | Description |
|------|----------|-------------|
| zsh + powerlevel10k | bash | Feature-rich shell with a customizable powerline prompt |

Enabled out of the box: autocd, syntax highlighting, autosuggestions, history substring search (20k entries), abbreviations, bracket autopair, nix-shell integration, tab completions.

### Terminal Multiplexer

| Tool | Replaces | Description |
|------|----------|-------------|
| tmux | screen | Terminal multiplexer with `Ctrl-a` prefix, vi keys, Nord theme |

Plugins: session save/restore (resurrect + continuum), regex search (copycat), clipboard sharing (yank), open files from tmux (open), URL picker (fzf-tmux-url), vim-style pane control (pain-control), session logging, better mouse mode.

### Editor

| Tool | Replaces | Description |
|------|----------|-------------|
| dxvim (neovim) | vim / nano | Preconfigured Neovim distribution, set as `$EDITOR` and git merge tool |

### Modern CLI Replacements

| Tool | Replaces | Description |
|------|----------|-------------|
| bat | cat | Syntax-highlighted file viewer (base16 theme) |
| eza | ls | File listing with git status, icons, and directory grouping |
| bottom (btm) | top | Modern system monitor with CPU averaging and temp display |
| dust | du | Disk usage visualizer with a bar-chart interface |

### Dev Tools

| Tool | Replaces | Description |
|------|----------|-------------|
| fzf | — | Fuzzy finder with zsh integration (`Ctrl-R` history, `Ctrl-T` files) |
| direnv | manual export | Auto-loads `.envrc` per directory |
| moreutils | — | errno, sponge, ts, vidir, chronic |

### Git

| Tool | Replaces | Description |
|------|----------|-------------|
| gitFull | git | Full git with auto-rebase, fsmonitor, untracked cache, verbose commits |

Preconfigured: branches sorted by commit date, relative dates in log, `updateRefs` on rebase, and a `git l` alias for a compact colored graph log.

### Language Servers

Installed in PATH so both Neovim and Claude Code can invoke them. Each bundle is independently toggleable.

| Bundle | Option | Packages |
|--------|--------|----------|
| Systems | `dxshell.lsp.systems.enable` | `clang-tools` (clangd, clang-format, clang-tidy), `rust-analyzer` |
| Scripting | `dxshell.lsp.scripting.enable` | `pyright`, `ruff`, `bash-language-server`, `lua-language-server` |
| Web | `dxshell.lsp.web.enable` | `typescript-language-server`, `nodejs` |
| Nix | `dxshell.lsp.nix.enable` | `nil` |
| Config | `dxshell.lsp.config.enable` | `yaml-language-server`, `taplo` (TOML), `marksman` (Markdown) |

All default to enabled. Set `dxshell.lsp.enable = false` to drop the whole group.

### Claude Code

| Tool | Description |
|------|-------------|
| claude-code | Anthropic CLI (unfree, gated by `dxshell.allowUnfree`) |

dxshell deploys an opinionated `~/.claude/settings.json`:

- **Status line** showing model · cwd basename · git branch.
- **Permission allowlist** for read-only Bash commands (`ls`, `cat`, `git status`, `nix flake show`, …) so Claude doesn't ask permission for safe inspection.
- **Stop hook** that fires `notify-send` when Claude finishes a turn.

Options:

| Option | Default | Purpose |
|--------|---------|---------|
| `dxshell.claudeCode.enable` | `true` | Install the package and (optionally) settings. |
| `dxshell.claudeCode.manageSettings` | `true` | Deploy the opinionated `settings.json`. Disable to keep your own. |
| `dxshell.claudeCode.notifyOnStop` | `true` | Desktop notification on Stop. No-ops on headless / SSH sessions (DBus-guarded). |
| `dxshell.claudeCode.extraAllow` | `[]` | Permission entries appended to `permissions.allow`. Use this for additive overrides — list values in `extraSettings` are *replaced wholesale*. |
| `dxshell.claudeCode.extraDeny` | `[]` | Permission entries appended to `permissions.deny`. |
| `dxshell.claudeCode.extraSettings` | `{}` | Free-form overrides, recursively merged on top of the defaults via `lib.recursiveUpdate`. Note: list values are replaced, not concatenated — that's why `extraAllow` / `extraDeny` exist. |

**Migrating an existing `~/.claude/settings.json`:** On first launch the dxshell wrapper auto-renames any pre-existing `~/.claude/settings.json` (real `$HOME`, not the standalone state dir) to `~/.claude/settings.json.dxshell-backup-<timestamp>` so Home Manager activation succeeds. Migrate any fields you want to keep into `dxshell.claudeCode.extraSettings` (or `extraAllow`/`extraDeny` for permission lists). To opt out entirely, set `dxshell.claudeCode.manageSettings = false`.

## Prerequisites

Your terminal emulator must use a [Nerd Font](https://www.nerdfonts.com/) for icons and the powerlevel10k prompt to render correctly. Recommended: **MesloLGS NF**.

## Manual setup

If the [Quick Start](#quick-start) one-liner is too magical for your taste, the same flow split into discrete steps:

### 1. Install a Nix runtime

Pick one of the three options below.

#### Multi-user upstream Nix (with sudo)

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

- Runs the Nix daemon as a system service
- Better build isolation and security
- Shared `/nix` store between all users
- Requires sudo
- *Equivalent to `bootstrap.sh --system`.*

#### nix-portable (no sudo, everything in HOME)

Download the latest binary from the [DavHau/nix-portable releases page](https://github.com/DavHau/nix-portable/releases) and drop it on your PATH (typically `~/.local/bin`):

```bash
curl -fsSL -o ~/.local/bin/nix-portable \
  https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-$(uname -m)
chmod +x ~/.local/bin/nix-portable
```

- All Nix state lives in `~/.nix-portable/`
- No `/nix`, no sudo, no system modifications
- Ideal for shared `$HOME` across servers of the same architecture
- *Equivalent to `bootstrap.sh --user`.*

#### Single-user upstream Nix (one-time sudo to create /nix)

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
```

- Installs to your user only, no daemon
- Needs sudo only once (to create `/nix`); after that, runs unprivileged
- Note: this is *not* what `bootstrap.sh --user` uses — it still touches `/nix`. Pick this one only if you specifically want the official single-user install.

After installing, open a new shell or `source` the profile script as instructed by the installer.

### 2. Run dxshell standalone

No permanent changes to your system. Everything lives under `~/.dxshell-state`.

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
```

This clones the repo to `~/.dxshell`, creates a launcher at `~/.local/bin/dxshell`, and drops you into a fully configured zsh session. Your real `~/.ssh` and `~/.gitconfig` are carried over automatically.

Subsequent runs:

```bash
dxshell
```

To update to the latest version:

```bash
dxshell-update
```

Check for available updates without applying:

```bash
dxshell-update --check
```

Switch to a different branch and update:

```bash
dxshell-update --branch <name>
```

Subsequent `dxshell-update` calls (without `--branch`) will continue tracking that branch.

Clean reinstall (wipes all previous state and starts fresh):

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone --clean
```

Manual cleanup — remove everything:

```bash
rm -rf ~/.dxshell ~/.dxshell-state ~/.local/bin/dxshell
```

### 3. Permanent install (optional)

Set dxshell as your default login shell. This creates a symlink at `~/.local/bin/dxshell` pointing to the Nix store binary and sets it as your login shell.

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- install
```

This clones the repo, builds the dxshell package, symlinks the binary, adds it to `/etc/shells`, and changes your login shell.

### Update

```bash
dxshell-update
```

### Uninstall

```bash
sudo chsh -s /bin/bash "$USER"
rm -rf ~/.dxshell ~/.dxshell-state ~/.local/bin/dxshell ~/.local/share/dxshell
```

## Advanced Usage

### Custom clone directory

```bash
# Standalone with custom dir
curl -fsSL .../setup.sh | sh -s -- standalone ~/projects/dxshell

# Install with custom dir
DXSHELL_DIR=~/projects/dxshell curl -fsSL .../setup.sh | sh -s -- install
```

### Testing a specific branch

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/<branch>/bin/setup.sh | GIT_BRANCH=<branch> sh -s -- standalone
```

### Direct nix run (no setup.sh)

```bash
# Temporary session (no clone needed)
nix run github:DxCx/dxshell

# Permanent install (no clone needed)
nix run github:DxCx/dxshell#dxshell-install
```

## Tmux Cheat Sheet

Prefix is `Ctrl-a`. Press the prefix, release, then press the key.

### Panes

| Key | Action |
|-----|--------|
| `Ctrl-a \|` | Split pane horizontally (side by side) |
| `Ctrl-a -` | Split pane vertically (top/bottom) |
| `Ctrl-a h` / `j` / `k` / `l` | Navigate panes (vim-style) |
| `Ctrl-a M-h` / `M-j` / `M-k` / `M-l` | Resize panes |

### Sessions & Windows

| Key | Action |
|-----|--------|
| `Ctrl-a c` | New window |
| `Ctrl-a 1`..`9` | Switch to window N (base index 1) |
| `Ctrl-a d` | Detach session |
| `Ctrl-a s` | Save session (resurrect) |
| `Ctrl-a R` | Restore session (resurrect) |

### Utilities

| Key | Action |
|-----|--------|
| `Ctrl-a u` | List URLs in current pane (fzf picker) |
| `Ctrl-a C-s` | Toggle synchronized panes (type in all panes) |
| `Ctrl-a C-l` | Clear screen and scrollback history |
| `Ctrl-a C-a` | Send literal `Ctrl-a` to the terminal |

### Copy Mode (vi)

| Key | Action |
|-----|--------|
| `Ctrl-a [` | Enter copy mode |
| `v` | Begin selection |
| `y` | Copy selection |
| `/` | Search forward |

## Shell Aliases

These are set up automatically — just type the left column.

| You type | Runs | Description |
|----------|------|-------------|
| `cat` | `bat` | Syntax-highlighted file viewer |
| `ls` | `eza` | File listing with git status and icons |
| `top` | `btm` | Modern system monitor |
| `du` | `dust` | Disk usage visualizer |
| `vimdiff` | `nvim -d` | Neovim diff mode |
| `git l` | `git log --graph ...` | Compact colored commit graph with author and relative date |

## Git Identity

dxshell configures git behavior (aliases, rebase, fsmonitor) but **not** your identity. Set it globally:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

In temporary mode, dxshell automatically includes your existing `~/.gitconfig` via git's `include.path`, so your identity carries over.

## SSH Agent with tmux

SSH agent forwarding breaks when reattaching tmux sessions because the socket path changes. Fix it by adding this to `~/.ssh/rc` on remote hosts:

```bash
if test "$SSH_AUTH_SOCK"; then
    ln -sf $SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock
fi
```

Then add to your shell config:

```bash
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
```

dxshell's tmux config automatically picks up `~/.ssh/ssh_auth_sock` if it exists.

## NixOS Integration

When using dxshell as part of a NixOS flake configuration:

```nix
# In your flake inputs:
dxshell = {
  url = "github:DxCx/dxshell";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};

# In your Home Manager config:
imports = [ dxshell.hmModule ];
```

## Supported Architectures

- `x86_64-linux`
- `aarch64-linux`
