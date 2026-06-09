# shellcheck shell=bash
# Note: shebang and `set -euo pipefail` are added by writeShellApplication.
#
# PostToolUse formatter: reformat the file Claude just edited so its output
# always matches the repo's enforced style (alejandra + statix for Nix, shfmt
# for shell). Receives the PostToolUse hook event as JSON on stdin; we only
# need the edited file path. Failures are swallowed so a formatter that chokes
# on a half-written file never blocks the edit.

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

case "$file" in
  *.nix)
    alejandra --quiet "$file" >/dev/null 2>&1 || true
    statix fix "$file" >/dev/null 2>&1 || true
    ;;
  *.sh)
    shfmt -w -i 2 "$file" >/dev/null 2>&1 || true
    ;;
esac
