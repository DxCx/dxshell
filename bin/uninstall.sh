#!/bin/sh
# dxshell uninstaller — removes every file a dxshell install may have created.
#
# Safety model: collect first, never delete without confirmation. The script
# builds the full list of existing dxshell artifacts, prints it, and deletes
# only after the user types exactly "confirm". Any other input aborts with no
# changes.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/uninstall.sh | sh
#
#   # Also remove a local-directory install (see bootstrap.sh --local-dir-install):
#   curl -fsSL .../bin/uninstall.sh | sh -s -- --local-dir-install        # tree under $PWD
#   curl -fsSL .../bin/uninstall.sh | sh -s -- --local-dir-install=DIR    # tree under DIR
set -eu

_HOME="${DXSHELL_REAL_HOME:-$HOME}"

usage() {
  cat <<'EOF'
Usage: uninstall.sh [--local-dir-install[=DIR]]

Removes files installed by dxshell (home install and/or local-directory
install). Collects all candidates, prints them, and deletes only after you
type "confirm".

  --local-dir-install        also remove the local install tree under $PWD
  --local-dir-install=DIR    also remove the local install tree under DIR
EOF
}

LOCAL_PARENT=""
for arg in "$@"; do
  case "$arg" in
    --local-dir-install) LOCAL_PARENT="$PWD" ;;
    --local-dir-install=*) LOCAL_PARENT="${arg#--local-dir-install=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "uninstall: unknown argument '$arg'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Collect candidates (existing paths only; never delete anything here)
# ---------------------------------------------------------------------------
nl='
'
CANDIDATES=""

add() {
  # Track the path only if it actually exists (or is a dangling symlink).
  if [ -e "$1" ] || [ -L "$1" ]; then
    CANDIDATES="${CANDIDATES}${1}${nl}"
  fi
}

# Home-install artifacts (bootstrap.sh --user / setup.sh defaults)
add "$_HOME/.dxshell"
add "$_HOME/.dxshell-state"
add "$_HOME/.nix-portable"
add "$_HOME/.local/bin/dxshell"
add "$_HOME/.local/bin/nix-portable"
add "$_HOME/.local/share/dxshell"
add /tmp/dxshell-home

# Claude settings backups created by the dxshell wrapper. These contain the
# user's pre-dxshell settings — they are listed (and flagged below) so the
# user makes an informed call before confirming.
for f in "$_HOME/.claude/settings.json.dxshell-backup-"*; do
  add "$f"
done

# A dangling HM-managed settings symlink (points into a dxshell state dir
# that is about to be removed). Only the symlink is removed, never a real file.
if [ -L "$_HOME/.claude/settings.json" ] && command -v readlink >/dev/null 2>&1; then
  case "$(readlink "$_HOME/.claude/settings.json")" in
    *dxshell*) add "$_HOME/.claude/settings.json" ;;
  esac
fi

# Local-directory install tree (bootstrap.sh --local-dir-install)
if [ -n "$LOCAL_PARENT" ]; then
  if [ -d "$LOCAL_PARENT" ]; then
    LOCAL_PARENT="$(cd "$LOCAL_PARENT" && pwd)"
  else
    echo "uninstall: '$LOCAL_PARENT' is not a directory" >&2
    exit 2
  fi
  add "$LOCAL_PARENT/.dxshell"
  # The entry symlink is removed only if it is ours (points into .dxshell/),
  # never a user's own file that happens to be named "dxshell".
  if [ -L "$LOCAL_PARENT/dxshell" ] && command -v readlink >/dev/null 2>&1; then
    case "$(readlink "$LOCAL_PARENT/dxshell")" in
      *.dxshell/*) add "$LOCAL_PARENT/dxshell" ;;
    esac
  fi
fi

# Deduplicate (e.g. --local-dir-install=$HOME overlaps with home artifacts)
CANDIDATES="$(printf '%s' "$CANDIDATES" | sort -u)"

if [ -z "$CANDIDATES" ]; then
  echo "uninstall: no dxshell files found — nothing to remove."
  exit 0
fi

# ---------------------------------------------------------------------------
# Print the list and ask for confirmation
# ---------------------------------------------------------------------------
echo "The following files/directories will be PERMANENTLY deleted:"
echo ""
printf '%s\n' "$CANDIDATES" | while IFS= read -r p; do
  case "$p" in
    *settings.json.dxshell-backup-*)
      echo "  $p   <-- backup of your pre-dxshell Claude settings"
      ;;
    *)
      echo "  $p"
      ;;
  esac
done
echo ""

# Login-shell warning (permanent install mode). Never run sudo ourselves.
if command -v getent >/dev/null 2>&1; then
  login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  case "$login_shell" in
    *dxshell*)
      echo "WARNING: your login shell is '$login_shell' and will break after removal."
      echo "Restore it first, e.g.:  sudo chsh -s /bin/bash \"\$USER\""
      echo "Also remove the dxshell line from /etc/shells if present."
      echo ""
      ;;
  esac
fi

# Read the confirmation from the controlling terminal so this also works when
# piped via `curl | sh` (stdin is the pipe, not the keyboard).
printf 'Type "confirm" to delete the files above (anything else aborts): '
if [ -t 0 ]; then
  read -r reply
elif [ -r /dev/tty ]; then
  read -r reply </dev/tty
else
  echo ""
  echo "uninstall: no terminal available to confirm — aborting, nothing deleted." >&2
  exit 1
fi

if [ "$reply" != "confirm" ]; then
  echo "Aborted — nothing was deleted."
  exit 0
fi

# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------
printf '%s\n' "$CANDIDATES" | while IFS= read -r p; do
  rm -rf -- "$p"
  echo "removed: $p"
done

echo ""
echo "dxshell uninstalled."
