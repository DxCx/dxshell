#!/bin/sh
# dxshell single-curl bootstrap.
#
# Installs Nix (if missing), then delegates to bin/setup.sh to clone dxshell
# and launch the standalone session.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --user
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --system
#
# Flags:
#   --user        (default) Install Nix as single-user (no daemon, no sudo).
#                 Only consulted when Nix is missing.
#   --system      Install Nix as multi-user (daemon, requires sudo).
#                 Only consulted when Nix is missing.
#   --clean       Wipe previous dxshell state before launching. Forwarded to setup.sh.
#   standalone    (default) Run dxshell standalone. Forwarded to setup.sh.
#   install       Permanent install. Forwarded to setup.sh.
#
# If Nix is already installed (`command -v nix` succeeds), the install branch is
# skipped entirely — no curl, no sudo prompt — regardless of which Nix flag was
# passed. The bootstrap re-runs are idempotent.
set -eu

NIX_FLAVOR="user"
MODE="standalone"
CLEAN=""

for arg in "$@"; do
  case "$arg" in
    --user) NIX_FLAVOR="user" ;;
    --system) NIX_FLAVOR="system" ;;
    --clean) CLEAN="--clean" ;;
    standalone | install) MODE="$arg" ;;
    -h | --help)
      sed -n 's/^# \{0,1\}//; 2,21p' "$0" 2>/dev/null || cat <<'EOF'
Usage: bootstrap.sh [--user|--system] [standalone|install] [--clean]
Run via:
  curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh \
    | sh -s -- --user
EOF
      exit 0
      ;;
    *)
      echo "bootstrap: unknown argument '$arg'" >&2
      echo "  expected: --user | --system | --clean | standalone | install | -h" >&2
      exit 2
      ;;
  esac
done

# ----------------------------------------------------------------------------
# Step 1 — Nix.  If it's already installed, skip the entire install branch.
# ----------------------------------------------------------------------------
if command -v nix >/dev/null 2>&1; then
  echo "bootstrap: nix already installed at $(command -v nix), skipping install"
else
  case "$NIX_FLAVOR" in
    user)
      echo "bootstrap: installing Nix (single-user, no sudo)..."
      curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install |
        sh -s -- --no-daemon
      # shellcheck disable=SC1091
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      ;;
    system)
      echo "bootstrap: installing Nix (multi-user, requires sudo)..."
      curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install |
        sh -s -- --daemon
      # Multi-user installs the daemon profile script; fall back to the
      # user profile script if /etc/profile.d isn't on this host's path.
      if [ -f /etc/profile.d/nix-daemon.sh ]; then
        # shellcheck disable=SC1091
        . /etc/profile.d/nix-daemon.sh
      elif [ -f /etc/profile.d/nix.sh ]; then
        # shellcheck disable=SC1091
        . /etc/profile.d/nix.sh
      elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      ;;
  esac

  if ! command -v nix >/dev/null 2>&1; then
    echo "bootstrap: Nix installed but 'nix' is still not on PATH." >&2
    echo "  Open a new shell and re-run this command." >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# Step 2 — delegate to setup.sh.
# ----------------------------------------------------------------------------
echo "bootstrap: launching setup.sh in $MODE mode..."
SETUP_URL="https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh"
if [ -n "$CLEAN" ]; then
  curl -fsSL "$SETUP_URL" | sh -s -- "$MODE" "$CLEAN"
else
  curl -fsSL "$SETUP_URL" | sh -s -- "$MODE"
fi
