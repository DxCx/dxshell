#!/bin/sh
# dxshell bootstrap script — standalone or permanent install from a single curl.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- install
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh | sh -s -- standalone --local-dir-install
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
LOCAL_PARENT=""

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --local-dir-install) LOCAL_PARENT="$PWD" ;;
    --local-dir-install=*) LOCAL_PARENT="${arg#--local-dir-install=}" ;;
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
  echo "Usage: setup.sh <standalone|install> [--clean] [--local-dir-install[=DIR]] [DXSHELL_DIR]" >&2
  exit 1
fi

case "$MODE" in
  standalone | install) ;;
  *)
    echo "error: unknown mode '$MODE' (expected 'standalone' or 'install')" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Local-dir install: resolve the self-contained base directory.
# Either the flag was passed directly, or bootstrap.sh already resolved it
# and exported DXSHELL_BASE.
# ---------------------------------------------------------------------------
if [ -n "$LOCAL_PARENT" ] && [ -z "${DXSHELL_BASE:-}" ]; then
  if [ ! -d "$LOCAL_PARENT" ]; then
    echo "error: --local-dir-install target '$LOCAL_PARENT' is not a directory" >&2
    exit 1
  fi
  LOCAL_PARENT="$(cd "$LOCAL_PARENT" && pwd)"
  DXSHELL_BASE="$LOCAL_PARENT/.dxshell"
fi
DXSHELL_BASE="${DXSHELL_BASE:-}"

if [ -n "$DXSHELL_BASE" ]; then
  if [ "$MODE" = "install" ]; then
    echo "error: --local-dir-install cannot be combined with 'install' mode." >&2
    echo "Permanent install bakes /nix/store paths that only resolve inside" >&2
    echo "nix-portable's namespace. Use standalone mode instead." >&2
    exit 1
  fi
  if [ -d "$DXSHELL_BASE/.git" ]; then
    echo "error: $DXSHELL_BASE is a git clone (home-mode install layout)." >&2
    echo "Refusing to reuse it as a local-install container. Remove it first" >&2
    echo "(see bin/uninstall.sh) or use a different directory." >&2
    exit 1
  fi
  LOCAL_PARENT="${DXSHELL_BASE%/*}"
  export DXSHELL_BASE
  mkdir -p "$DXSHELL_BASE"
  # The whole tree (store, state, clone) lives under the base, and the proot
  # backend avoids bwrap's nested mount namespaces, which hardened hosts
  # block. NP_RUNTIME stays overridable for hosts where bwrap works.
  export NP_LOCATION="$DXSHELL_BASE"
  NP_RUNTIME="${NP_RUNTIME:-proot}"
  export NP_RUNTIME
fi

# Directory: env > local base > default (positional may have been set above)
if [ -z "${DXSHELL_DIR:-}" ]; then
  if [ -n "$DXSHELL_BASE" ]; then
    DXSHELL_DIR="$DXSHELL_BASE/src"
  else
    DXSHELL_DIR="$_HOME/.dxshell"
  fi
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
  if [ -n "$DXSHELL_BASE" ]; then
    # Local mode: wipe clone, state, and launcher, but keep the in-tree
    # nix-portable binary and its store — mirrors home mode, which also
    # preserves ~/.nix-portable, and avoids re-downloading everything.
    rm -rf "$DXSHELL_BASE/state" /tmp/dxshell-home
    rm -rf "$DXSHELL_DIR"
    rm -f "$DXSHELL_BASE/.local/bin/dxshell" "$LOCAL_PARENT/dxshell"
  else
    rm -rf "$_HOME/.dxshell-state" /tmp/dxshell-home
    rm -rf "$DXSHELL_DIR"
    rm -f "$_HOME/.local/bin/dxshell"
  fi
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
  # Local-dir install: the tree is self-contained, so only its own in-tree
  # nix-portable counts — a system nix would build into the wrong store.
  if [ -n "$DXSHELL_BASE" ]; then
    if [ -x "$DXSHELL_BASE/.local/bin/nix-portable" ]; then
      NIX_CMD="$DXSHELL_BASE/.local/bin/nix-portable nix"
      return 0
    fi
    echo "error: in-tree nix-portable not found at $DXSHELL_BASE/.local/bin/nix-portable" >&2
    echo "" >&2
    echo "Run the bootstrap one-liner, which downloads it for you:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --local-dir-install" >&2
    exit 1
  fi

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
  # Local-dir installs never talk to a system daemon — nothing to trust.
  if [ -n "$DXSHELL_BASE" ]; then
    return 0
  fi

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

# Flake reference for the checkout. This must be git+file: and never path:.
# path: copies the whole directory into the store, .git included, and Nix cannot
# serialise non-regular files. Git's fsmonitor daemon — which dxshell's own git
# config enables — leaves a unix socket at .git/fsmonitor--daemon.ipc, so every
# path: build fails with "has an unsupported type". git+file: reads the work tree
# through git, so .git is never copied, and the store path is keyed on the commit
# instead of churning on every fetch.
DXSHELL_FLAKE_REF="git+file://$DXSHELL_DIR"

# ---------------------------------------------------------------------------
# 6. Mode-specific steps
# ---------------------------------------------------------------------------
case "$MODE" in
  standalone)
    if [ -n "$DXSHELL_BASE" ]; then
      # Local-dir install: launcher lives inside the tree and bakes the full
      # environment, so every later invocation is self-contained regardless of
      # PATH or cwd. NP_RUNTIME stays overridable (e.g. NP_RUNTIME=bwrap dxshell).
      mkdir -p "$DXSHELL_BASE/.local/bin"
      {
        echo '#!/bin/sh'
        echo "export DXSHELL_FLAKE='$DXSHELL_DIR'"
        echo "export NP_LOCATION='$DXSHELL_BASE'"
        # shellcheck disable=SC2016 # expands at launch time, inside the launcher
        echo 'export NP_RUNTIME="${NP_RUNTIME:-proot}"'
        echo "export DXSHELL_STATE_DIR='$DXSHELL_BASE/state'"
        echo "exec '$DXSHELL_BASE/.local/bin/nix-portable' nix --extra-experimental-features 'nix-command flakes' run --accept-flake-config '$DXSHELL_FLAKE_REF'"
      } >"$DXSHELL_BASE/.local/bin/dxshell"
      chmod +x "$DXSHELL_BASE/.local/bin/dxshell"

      # Entry symlink next to the tree. Never clobber a real user file that
      # happens to be named "dxshell" — only (re)place a symlink.
      if [ -e "$LOCAL_PARENT/dxshell" ] && [ ! -L "$LOCAL_PARENT/dxshell" ]; then
        echo "WARNING: $LOCAL_PARENT/dxshell exists and is not a symlink — leaving it alone."
        echo "Launch via: $DXSHELL_BASE/.local/bin/dxshell"
      else
        ln -sfn ".dxshell/.local/bin/dxshell" "$LOCAL_PARENT/dxshell"
        echo ""
        echo "Launcher created at $LOCAL_PARENT/dxshell"
        echo "Run it with: $LOCAL_PARENT/dxshell"
      fi

      # Pre-build the closure so the first launch is instant, but do NOT
      # start a session: a launch from inside the installer pipe gets a
      # degraded terminal, and a local-dir install does not change the login
      # shell — it is always launched manually anyway.
      echo ""
      echo "Building dxshell (the first build may take a while)..."
      # shellcheck disable=SC2086
      $NIX_CMD build --no-link --accept-flake-config "$DXSHELL_FLAKE_REF"
      echo ""
      echo "dxshell installed. Launch it with:"
      echo "  $LOCAL_PARENT/dxshell"
      exit 0
    fi

    # Create a launcher script. We bake the resolved NIX_CMD into the launcher
    # so subsequent `dxshell` invocations don't depend on PATH ordering — this
    # matters especially for the nix-portable case where the binary is in
    # ~/.local/bin and may not be on every shell's PATH.
    mkdir -p "$_HOME/.local/bin"
    {
      echo '#!/bin/sh'
      echo "export DXSHELL_FLAKE='$DXSHELL_DIR'"
      echo "exec $NIX_CMD --extra-experimental-features 'nix-command flakes' run --accept-flake-config '$DXSHELL_FLAKE_REF'"
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
    exec $NIX_CMD run --accept-flake-config "$DXSHELL_FLAKE_REF"
    ;;

  install)
    echo ""
    echo "Running permanent install..."
    # shellcheck disable=SC2086
    $NIX_CMD run --accept-flake-config "$DXSHELL_FLAKE_REF#dxshell-install"
    ;;
esac
