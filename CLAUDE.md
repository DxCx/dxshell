# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dxshell is a portable, reproducible development shell environment for Linux built with **Nix Flakes** and **Home Manager**. It provides a fully configured terminal environment (zsh, tmux, neovim via dxvim, modern CLI tools) deployable as a standalone isolated session or a permanent Home Manager installation.

## Build Commands

| Action | Command |
|--------|---------|
| Build | `nix build --show-trace` |
| Full check | `nix flake check --show-trace` |
| Format (Nix) | `nix run nixpkgs#alejandra -- .` |
| Lint (Nix) | `nix run nixpkgs#statix -- check .` |
| Shellcheck | `find . -name '*.sh' -type f \| xargs nix run nixpkgs#shellcheck --` |
| Run standalone | `nix run` |
| Run installer | `nix run .#dxshell-install` |

There are no unit tests. Validation is done via `nix flake check` which verifies the entire configuration builds.

## Architecture

### Nix Flake Structure

- **flake.nix** — Main entry point. Defines inputs (nixpkgs, home-manager, dxvim, dxnixinfra, utils) and outputs (packages, hmModule, checks).
- **packages/** — Two Nix derivations: `dxshell-wrapper.nix` (standalone, default package) and `dxshell-install.nix` (permanent install).
- **scripts/** — Shell scripts for standalone (`dxshell-wrapper.sh`) and install (`dxshell-install.sh`) modes. These use `@PLACEHOLDER@` substitution (e.g., `@ACTIVATION_PACKAGE@`, `@GIT@`, `@ZSH@`) replaced by Nix at build time.
- **module/** — Home Manager modules, one per feature.

### Home Manager Module System

Each feature is a separate `.nix` file under `module/` with:
- A boolean enable option declared in `module/default.nix` (e.g., `dxshell.neovim.enable`)
- A conditional config block using `lib.mkIf`
- All features default to enabled

Module options: `dxshell.enable`, `dxshell.neovim.enable`, `dxshell.git.enable`, `dxshell.zsh.enable`, `dxshell.tmux.enable`, `dxshell.cliTools.enable`, `dxshell.allowUnfree`, `dxshell.claudeCode.enable`.

The `module/extensions/default.nix` provides an extension point for custom modules.

### Standalone Mode

The standalone wrapper (`scripts/dxshell-wrapper.sh`) creates an isolated home at `~/.cache/dxshell/home`, runs Home Manager activation into it, symlinks `~/.ssh`, includes `~/.gitconfig`, and launches zsh with the isolated `HOME`.

### Key Dependencies

- **dxvim** (`github:DxCx/dxvim`) — Custom Neovim distribution, separate flake
- **dxnixinfra** (`github:DxCx/dxnixinfra`) — Shared CI/check infrastructure, provides `mkFlakeOutputs`

## Code Conventions

- **Nix formatter**: alejandra (not nixpkgs-fmt)
- **Nix linter**: statix
- **Shell scripts**: shellcheck, `set -euo pipefail`
- **Indentation**: 2 spaces for `.nix`, `.yml`, `.json`, `.sh`
- **Commit style**: Conventional commits — `type(scope): description` (e.g., `feat: ...`, `fix: ...`, `ci: ...`, `chore: ...`)
- **Unfree packages**: Explicitly allowed via `unfreePackages` list in flake.nix (currently only `claude-code`)
