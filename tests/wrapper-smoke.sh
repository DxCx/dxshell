#!/usr/bin/env bash
# End-to-end smoke for the standalone wrapper. Drives the full first-run
# experience from the perspective of a fresh user: synthetic HOME, synthetic
# pre-existing ~/.claude/settings.json, then `dxshell -c '...'` so the
# wrapper hits its `$# > 0` branch and exec's `zsh -c` after activating
# Home Manager.
#
# Runs OUTSIDE Nix's build sandbox (CI runner or developer machine) because
# HM activation needs `nix-build` on PATH, which sandboxed builds can't have.
#
# Usage: tests/wrapper-smoke.sh [path-to-dxshell-binary]
#   default: ./result/bin/dxshell  (i.e., run after `nix build`)
set -euo pipefail

DXSHELL="${1:-./result/bin/dxshell}"
if [ ! -x "$DXSHELL" ]; then
  echo "wrapper-smoke: $DXSHELL is not executable" >&2
  echo "Run 'nix build' first, or pass an explicit path." >&2
  exit 2
fi

errors=0
fail() {
  echo "FAIL: $*" >&2
  errors=$((errors + 1))
}
pass() { echo "PASS: $*"; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# ---- Variant 1: pre-existing settings.json is a regular file ----
realhome1="$WORK/realhome1"
mkdir -p "$realhome1/.claude"
marker="dxshell-marker-$(date +%s%N)"
printf '{"effortLevel":"high","_marker":"%s"}\n' "$marker" \
  >"$realhome1/.claude/settings.json"

state1="$WORK/state1"
output1=$(HOME="$realhome1" DXSHELL_STATE_DIR="$state1" \
  "$DXSHELL" -c 'echo dxshell-ok && command -v clangd && command -v claude' 2>&1) || true

echo "--- variant 1 output ---"
echo "$output1"
echo "------------------------"

if echo "$output1" | grep -q '^dxshell-ok$'; then
  pass "wrapper executed user command"
else
  fail "dxshell-ok marker missing from output"
fi
if echo "$output1" | grep -q 'clangd$'; then
  pass "clangd resolvable inside dxshell"
else
  fail "clangd not resolvable"
fi
if echo "$output1" | grep -q 'claude$'; then
  pass "claude resolvable inside dxshell"
else
  fail "claude not resolvable"
fi

# Backup verification: original moved aside, file still grep-able for marker.
if find "$realhome1/.claude/" -maxdepth 1 -name 'settings.json.dxshell-backup-*' -print | grep -q .; then
  pass "pre-existing settings.json was backed up"
  if grep -q "$marker" "$realhome1"/.claude/settings.json.dxshell-backup-*; then
    pass "backup file contains original marker contents"
  else
    fail "backup file missing original marker"
  fi
else
  fail "no .dxshell-backup-* file found"
  ls -la "$realhome1/.claude/" >&2
fi

# ---- Variant 2: pre-existing settings.json is a symlink ----
# The wrapper's `[ ! -L ]` guard should leave it alone (no backup).
realhome2="$WORK/realhome2"
mkdir -p "$realhome2/.claude"
ln -s /dev/null "$realhome2/.claude/settings.json"

state2="$WORK/state2"
HOME="$realhome2" DXSHELL_STATE_DIR="$state2" \
  "$DXSHELL" -c 'echo variant2-ok' >/dev/null 2>&1 || true

if find "$realhome2/.claude/" -maxdepth 1 -name '*dxshell-backup-*' -print | grep -q .; then
  fail "symlink should not have been backed up"
  ls -la "$realhome2/.claude/" >&2
else
  pass "pre-existing symlink was left alone (no backup created)"
fi

if [ "$errors" -gt 0 ]; then
  echo "$errors wrapper-smoke check(s) failed" >&2
  exit 1
fi
echo "All wrapper-smoke checks passed."
