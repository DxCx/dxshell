# shellcheck shell=bash
# Note: shebang and `set -euo pipefail` are added by writeShellApplication.
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"' 2>/dev/null) || model="claude"
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null) || cwd=""
dir=$(basename "${cwd:-$PWD}")

branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
fi

if [ -n "$branch" ]; then
  printf '%s | %s | %s' "$model" "$dir" "$branch"
else
  printf '%s | %s' "$model" "$dir"
fi
