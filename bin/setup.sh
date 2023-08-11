#!/bin/sh
# dxshell bootstrap script — standalone or permanent install from a single curl.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- install
set -eu

REPO_URL="https://github.com/DxCx/dxshell.git"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE="${1:-}"
if [ -z "$MODE" ]; then
  echo "Usage: setup.sh <standalone|install> [DXSHELL_DIR]" >&2
  exit 1
fi

case "$MODE" in
  standalone | install) ;;
  *)
    echo "error: unknown mode '$MODE' (expected 'standalone' or 'install')" >&2
    exit 1
    ;;
esac

# Directory: $2 > $DXSHELL_DIR env > default
if [ -n "${2:-}" ]; then
  DXSHELL_DIR="$2"
elif [ -z "${DXSHELL_DIR:-}" ]; then
  DXSHELL_DIR="$HOME/.dxshell"
fi

# Ensure absolute path
case "$DXSHELL_DIR" in
  /*) ;; # already absolute
  *) DXSHELL_DIR="$PWD/$DXSHELL_DIR" ;;
esac

# ---------------------------------------------------------------------------
# 1. Check Nix is installed
# ---------------------------------------------------------------------------
ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  # Try sourcing common profile scripts
  for f in "$HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    if [ -f "$f" ]; then
      # shellcheck disable=SC1090
      . "$f"
      if command -v nix >/dev/null 2>&1; then
        return 0
      fi
    fi
  done

  echo "error: Nix is not installed." >&2
  echo "" >&2
  echo "Install Nix (multi-user, recommended):" >&2
  echo "  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon" >&2
  echo "" >&2
  echo "Or single-user (no daemon):" >&2
  echo "  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon" >&2
  exit 1
}

ensure_nix

# ---------------------------------------------------------------------------
# 2. Enable flakes if needed
# ---------------------------------------------------------------------------
if ! nix flake --help >/dev/null 2>&1; then
  echo "Enabling Nix flakes..."
  mkdir -p "$HOME/.config/nix"
  if ! grep -q "experimental-features.*flakes" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
    echo "experimental-features = nix-command flakes" >>"$HOME/.config/nix/nix.conf"
  fi
  echo "Flakes enabled in ~/.config/nix/nix.conf"
fi

# ---------------------------------------------------------------------------
# 3. Clone or update the repository
# ---------------------------------------------------------------------------
run_git() {
  if command -v git >/dev/null 2>&1; then
    git "$@"
  else
    nix run nixpkgs#git -- "$@"
  fi
}

if [ -d "$DXSHELL_DIR/.git" ]; then
  echo "Updating existing clone at $DXSHELL_DIR..."
  run_git -C "$DXSHELL_DIR" pull --ff-only
elif [ -d "$DXSHELL_DIR" ]; then
  # Directory exists but is not a git repo
  echo "error: $DXSHELL_DIR exists but is not a git repository." >&2
  echo "Remove it or choose a different directory." >&2
  exit 1
else
  echo "Cloning dxshell to $DXSHELL_DIR..."
  run_git clone "$REPO_URL" "$DXSHELL_DIR"
fi

export DXSHELL_DIR

# ---------------------------------------------------------------------------
# 4. Mode-specific steps
# ---------------------------------------------------------------------------
case "$MODE" in
  standalone)
    # Create a launcher script
    mkdir -p "$HOME/.local/bin"
    {
      echo '#!/bin/sh'
      echo "export DXSHELL_FLAKE='$DXSHELL_DIR'"
      echo "exec nix run 'path:$DXSHELL_DIR'"
    } >"$HOME/.local/bin/dxshell"
    chmod +x "$HOME/.local/bin/dxshell"
    echo ""
    echo "Launcher created at ~/.local/bin/dxshell"

    # Warn if ~/.local/bin is not in PATH
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *)
        echo "WARNING: ~/.local/bin is not in your PATH."
        echo "Add it with: export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
    esac

    echo ""
    echo "Starting dxshell..."
    export DXSHELL_FLAKE="$DXSHELL_DIR"
    exec nix run "path:$DXSHELL_DIR"
    ;;

  install)
    echo ""
    echo "Running permanent install..."
    nix run "path:$DXSHELL_DIR#dxshell-install"
    ;;
esac
