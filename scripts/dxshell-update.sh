# shellcheck shell=bash
set -euo pipefail

usage() {
  echo "Usage: dxshell-update [--check] [--branch <name>] [DIR]"
  echo ""
  echo "Update dxshell to the latest version from git and rebuild."
  echo ""
  echo "Options:"
  echo "  --check          Show available updates without applying them"
  echo "  --branch <name>  Switch to a different branch before updating"
  echo "  DIR              Path to the dxshell git clone (default: auto-detect)"
  exit "${1:-0}"
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CHECK_ONLY=0
DIR_OVERRIDE=""
BRANCH_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --branch)
      shift
      BRANCH_OVERRIDE="${1:-}"
      if [ -z "$BRANCH_OVERRIDE" ]; then
        echo "error: --branch requires a value" >&2
        usage 1
      fi
      ;;
    --help | -h) usage 0 ;;
    -*)
      echo "error: unknown option '$1'" >&2
      usage 1
      ;;
    *)
      if [ -n "$DIR_OVERRIDE" ]; then
        echo "error: unexpected argument '$1'" >&2
        usage 1
      fi
      DIR_OVERRIDE="$1"
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Resolve dxshell git directory
# ---------------------------------------------------------------------------
if [ -n "$DIR_OVERRIDE" ]; then
  DXSHELL_DIR="$DIR_OVERRIDE"
elif [ -n "${DXSHELL_FLAKE:-}" ]; then
  DXSHELL_DIR="$DXSHELL_FLAKE"
elif [ -d "${DXSHELL_REAL_HOME:-$HOME}/.dxshell" ]; then
  DXSHELL_DIR="${DXSHELL_REAL_HOME:-$HOME}/.dxshell"
elif [ -d "${HOME}/.dxshell" ]; then
  DXSHELL_DIR="${HOME}/.dxshell"
else
  echo "error: could not find dxshell git directory." >&2
  echo "Provide it as an argument: dxshell-update /path/to/dxshell" >&2
  exit 1
fi

if [ ! -d "${DXSHELL_DIR}/.git" ]; then
  echo "error: ${DXSHELL_DIR} is not a git repository." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch and compare
# ---------------------------------------------------------------------------
GIT="@GIT@/bin/git"

# Switch branch if requested
if [ -n "$BRANCH_OVERRIDE" ]; then
  echo "dxshell-update: switching to branch ${BRANCH_OVERRIDE}..."
  "$GIT" -C "$DXSHELL_DIR" fetch origin "$BRANCH_OVERRIDE"
  "$GIT" -C "$DXSHELL_DIR" checkout "$BRANCH_OVERRIDE"
fi

BRANCH=$("$GIT" -C "$DXSHELL_DIR" symbolic-ref --short HEAD 2>/dev/null) || {
  echo "error: detached HEAD in ${DXSHELL_DIR}." >&2
  echo "Check out a branch first: git -C '${DXSHELL_DIR}' checkout master" >&2
  exit 1
}

echo "dxshell-update: fetching origin/${BRANCH}..."
"$GIT" -C "$DXSHELL_DIR" fetch origin "$BRANCH"

LOCAL_HEAD=$("$GIT" -C "$DXSHELL_DIR" rev-parse HEAD)
REMOTE_HEAD=$("$GIT" -C "$DXSHELL_DIR" rev-parse "origin/${BRANCH}")

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  echo "dxshell is already up-to-date (${BRANCH} @ ${LOCAL_HEAD:0:8})."
  exit 0
fi

NEW_COMMITS=$("$GIT" -C "$DXSHELL_DIR" rev-list --count "HEAD..origin/${BRANCH}")

if [ "$CHECK_ONLY" = "1" ]; then
  echo "${NEW_COMMITS} new commit(s) available on ${BRANCH}."
  "$GIT" -C "$DXSHELL_DIR" log --oneline "HEAD..origin/${BRANCH}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Pull changes
# ---------------------------------------------------------------------------
echo "dxshell-update: pulling ${NEW_COMMITS} new commit(s)..."
if ! "$GIT" -C "$DXSHELL_DIR" pull --ff-only; then
  echo "" >&2
  echo "error: fast-forward merge failed. Your local branch has diverged." >&2
  echo "Resolve manually:" >&2
  echo "  cd '${DXSHELL_DIR}' && git rebase origin/${BRANCH}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Detect mode and rebuild
# ---------------------------------------------------------------------------
REAL_HOME="${DXSHELL_REAL_HOME:-$HOME}"
DXSHELL_BIN="${REAL_HOME}/.local/bin/dxshell"

# Ensure nix-command and flakes are available (same pattern as setup.sh)
export NIX_CONFIG="experimental-features = nix-command flakes
${NIX_CONFIG:-}"

if [ -L "$DXSHELL_BIN" ]; then
  LINK_TARGET=$(readlink "$DXSHELL_BIN")
  case "$LINK_TARGET" in
    /nix/store/*)
      # Install mode: the symlink points into the nix store
      echo "dxshell-update: install mode detected, rebuilding..."
      nix run --accept-flake-config "path:${DXSHELL_DIR}#dxshell-install"
      echo ""
      echo "dxshell updated successfully. Restart your shell to use the new version."
      exit 0
      ;;
  esac
fi

# Standalone mode: replace current shell with the updated one
echo "dxshell-update: standalone mode detected, rebuilding..."
exec nix run --accept-flake-config "path:${DXSHELL_DIR}"
