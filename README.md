# dxshell

A portable, reproducible dev shell that gives you a consistent terminal environment on any Linux machine. One command, zero config.

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
```

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

## Prerequisites

Your terminal emulator must use a [Nerd Font](https://www.nerdfonts.com/) for icons and the powerlevel10k prompt to render correctly. Recommended: **MesloLGS NF**.

## Step 1: Install Nix

If you don't have Nix yet, pick one of the two options below.

### Option A: Multi-user install (recommended if you have sudo)

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

- Runs the Nix daemon as a system service
- Better build isolation and security
- Shared `/nix` store between all users
- Requires sudo

### Option B: Single-user install (no sudo needed after /nix creation)

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
```

- Installs to your user only, no daemon
- Good for personal machines or environments without systemd
- Needs sudo only once (to create `/nix`); after that, runs unprivileged

After either install, open a new shell or `source` the profile script as instructed by the installer.

## Step 2: Quick Start (Standalone)

No permanent changes to your system. Everything lives under `~/.cache/dxshell`.

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
```

This clones the repo to `~/.dxshell`, creates a launcher at `~/.local/bin/dxshell`, and drops you into a fully configured zsh session. Your real `~/.ssh` and `~/.gitconfig` are carried over automatically.

Subsequent runs:

```bash
dxshell
```

To update, pull the latest changes first:

```bash
cd ~/.dxshell && git pull
dxshell
```

Cleanup — remove everything:

```bash
rm -rf ~/.dxshell ~/.cache/dxshell ~/.local/bin/dxshell
```

## Step 3: Permanent Install

Install dxshell as your default shell environment via Home Manager. This integrates all tools directly into your user profile.

```bash
curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- install
```

This clones the repo, generates `~/.config/home-manager/flake.nix`, runs `home-manager switch`, and sets zsh as your login shell.

### Update

```bash
cd ~/.config/home-manager && nix flake update && home-manager switch --flake .
```

If installed from a local clone (via `$DXSHELL_DIR`):

```bash
cd "$DXSHELL_DIR" && git pull && cd ~/.config/home-manager && home-manager switch --flake .
```

### Uninstall

```bash
home-manager uninstall
rm -rf ~/.config/home-manager ~/.dxshell
```

## Advanced Usage

### Custom clone directory

```bash
# Standalone with custom dir
curl -fsSL .../setup.sh | sh -s -- standalone ~/projects/dxshell

# Install with custom dir
DXSHELL_DIR=~/projects/dxshell curl -fsSL .../setup.sh | sh -s -- install
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
