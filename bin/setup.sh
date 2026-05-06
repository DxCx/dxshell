#!/bin/sh
# dxshell bootstrap script — standalone or permanent install from a single curl.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- install
#   GIT_BRANCH=fix-standalone curl ... | sh -s -- standalone  # use a specific branch
set -eu

_HOME="${DXSHELL_REAL_HOME:-$HOME}"

REPO_URL="https://github.com/DxCx/dxshell.git"
GIT_BRANCH="${GIT_BRANCH:-master}"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CLEAN=0
MODE=""
POSITIONAL_IDX=0

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    *)
      POSITIONAL_IDX=$((POSITIONAL_IDX + 1))
      if [ "$POSITIONAL_IDX" = "1" ]; then
        MODE="$arg"
      elif [ "$POSITIONAL_IDX" = "2" ]; then
        DXSHELL_DIR="$arg"
      fi
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Usage: setup.sh <standalone|install> [--clean] [DXSHELL_DIR]" >&2
  exit 1
fi

case "$MODE" in
  standalone | install) ;;
  *)
    echo "error: unknown mode '$MODE' (expected 'standalone' or 'install')" >&2
    exit 1
    ;;
esac

# Directory: env > default (positional may have been set above)
if [ -z "${DXSHELL_DIR:-}" ]; then
  DXSHELL_DIR="$_HOME/.dxshell"
fi

# Ensure absolute path
case "$DXSHELL_DIR" in
  /*) ;; # already absolute
  *) DXSHELL_DIR="$PWD/$DXSHELL_DIR" ;;
esac

# Install mode always cleans to ensure a fresh activation
if [ "$MODE" = "install" ]; then
  CLEAN=1
fi

# ---------------------------------------------------------------------------
# 1. Clean previous state (if requested)
# ---------------------------------------------------------------------------
if [ "$CLEAN" = "1" ]; then
  echo "Cleaning previous dxshell state..."
  rm -rf "$_HOME/.dxshell-state" /tmp/dxshell-home
  rm -rf "$DXSHELL_DIR"
  rm -f "$_HOME/.local/bin/dxshell"
  echo "Done."
fi

# ---------------------------------------------------------------------------
# 2. Resolve the Nix runtime
# ---------------------------------------------------------------------------
# NIX_CMD holds the command we'll use everywhere below in place of bare `nix`.
# It's either:
#   "nix"                                    — a real Nix install
#   "/abs/path/to/nix-portable nix"          — nix-portable shim
# Word splitting happens at the call site; the variable is intentionally
# unquoted when used as a command head.
NIX_CMD=""

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    NIX_CMD="nix"
    return 0
  fi

  # Try sourcing common profile scripts (real Nix install)
  for f in "$_HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    if [ -f "$f" ]; then
      # shellcheck disable=SC1090
      . "$f"
      if command -v nix >/dev/null 2>&1; then
        NIX_CMD="nix"
        return 0
      fi
    fi
  done

  # Fall back to nix-portable (installed by `bootstrap.sh --user`).
  if command -v nix-portable >/dev/null 2>&1; then
    NIX_CMD="$(command -v nix-portable) nix"
    return 0
  fi
  if [ -x "$_HOME/.local/bin/nix-portable" ]; then
    NIX_CMD="$_HOME/.local/bin/nix-portable nix"
    return 0
  fi

  echo "error: Nix is not installed." >&2
  echo "" >&2
  echo "Easiest: use the bootstrap one-liner, which installs Nix for you." >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --user" >&2
  echo "" >&2
  echo "Or install Nix manually:" >&2
  echo "  Multi-user: sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon" >&2
  echo "  Single-user nix-portable: see https://github.com/DavHau/nix-portable" >&2
  exit 1
}

ensure_nix

# ---------------------------------------------------------------------------
# 3. Ensure nix-command and flakes are available
# ---------------------------------------------------------------------------
# NIX_CONFIG is the most reliable way to enable experimental features —
# detection via `nix run --help` or `nix flake --help` is unreliable because
# some Nix versions show help even when the feature is disabled.
# The variable is additive and harmless when the features are already enabled.
export NIX_CONFIG="experimental-features = nix-command flakes
${NIX_CONFIG:-}"

# ---------------------------------------------------------------------------
# 4. Ensure current user is trusted (multi-user daemon setups)
# ---------------------------------------------------------------------------
ensure_trusted_user() {
  # Only relevant when nix-daemon is running (multi-user install)
  if ! systemctl is-active --quiet nix-daemon 2>/dev/null; then
    return 0
  fi

  user="$(id -un)"

  # root is always trusted
  if [ "$user" = "root" ]; then
    return 0
  fi

  # Check if user (or wildcard) is already in trusted-users / extra-trusted-users
  if grep -qE "^(extra-)?trusted-users\b.*\b($user|\*)\b" /etc/nix/nix.conf 2>/dev/null; then
    return 0
  fi

  echo ""
  echo "Multi-user Nix detected but '$user' is not a trusted user."
  echo "This is needed so Nix can use the dxshell/dxvim binary caches."
  echo "Adding '$user' to extra-trusted-users in /etc/nix/nix.conf (requires sudo)."
  echo ""

  echo "extra-trusted-users = $user" | sudo tee -a /etc/nix/nix.conf >/dev/null
  sudo systemctl restart nix-daemon
  echo "Done — '$user' is now a trusted Nix user."
}

ensure_trusted_user

# ---------------------------------------------------------------------------
# 5. Clone or update the repository
# ---------------------------------------------------------------------------

run_git() {
  if command -v git >/dev/null 2>&1; then
    git "$@"
  else
    # shellcheck disable=SC2086
    $NIX_CMD run --accept-flake-config nixpkgs#git -- "$@"
  fi
}

if [ -d "$DXSHELL_DIR/.git" ]; then
  echo "Updating existing clone at $DXSHELL_DIR (branch: $GIT_BRANCH)..."
  run_git -C "$DXSHELL_DIR" fetch origin
  run_git -C "$DXSHELL_DIR" checkout "$GIT_BRANCH"
  run_git -C "$DXSHELL_DIR" pull --ff-only
elif [ -d "$DXSHELL_DIR" ]; then
  # Directory exists but is not a git repo
  echo "error: $DXSHELL_DIR exists but is not a git repository." >&2
  echo "Remove it or choose a different directory." >&2
  exit 1
else
  echo "Cloning dxshell to $DXSHELL_DIR (branch: $GIT_BRANCH)..."
  run_git clone -b "$GIT_BRANCH" "$REPO_URL" "$DXSHELL_DIR"
fi

export DXSHELL_DIR

# ---------------------------------------------------------------------------
# 6. Mode-specific steps
# ---------------------------------------------------------------------------
case "$MODE" in
  standalone)
    # Create a launcher script. We bake the resolved NIX_CMD into the launcher
    # so subsequent `dxshell` invocations don't depend on PATH ordering — this
    # matters especially for the nix-portable case where the binary is in
    # ~/.local/bin and may not be on every shell's PATH.
    mkdir -p "$_HOME/.local/bin"
    {
      echo '#!/bin/sh'
      echo "export DXSHELL_FLAKE='$DXSHELL_DIR'"
      echo "exec $NIX_CMD --extra-experimental-features 'nix-command flakes' run --accept-flake-config 'path:$DXSHELL_DIR'"
    } >"$_HOME/.local/bin/dxshell"
    chmod +x "$_HOME/.local/bin/dxshell"
    echo ""
    echo "Launcher created at ~/.local/bin/dxshell"

    # Warn if ~/.local/bin is not in PATH
    case ":$PATH:" in
      *":$_HOME/.local/bin:"*) ;;
      *)
        echo "WARNING: ~/.local/bin is not in your PATH."
        echo "Add it with: export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
    esac

    echo ""
    echo "Starting dxshell..."
    export DXSHELL_FLAKE="$DXSHELL_DIR"
    # shellcheck disable=SC2086
    exec $NIX_CMD run --accept-flake-config "path:$DXSHELL_DIR"
    ;;

  install)
    echo ""
    echo "Running permanent install..."
    # shellcheck disable=SC2086
    $NIX_CMD run --accept-flake-config "path:$DXSHELL_DIR#dxshell-install"
    ;;
esac
