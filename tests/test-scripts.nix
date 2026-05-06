{
  pkgs,
  dxshell_package,
  dxshell_install,
  dxshell_update,
  activationPackage,
  activationPackageAlt,
  activationPackageNoSettings,
}:
pkgs.runCommand "test-scripts" {
  nativeBuildInputs = [pkgs.gnugrep pkgs.coreutils pkgs.jq pkgs.bash pkgs.git];
} ''
  set -euo pipefail
  errors=0

  check() {
    local desc="$1"
    shift
    if "$@"; then
      echo "PASS: $desc"
    else
      echo "FAIL: $desc" >&2
      errors=$((errors + 1))
    fi
  }

  check_not() {
    local desc="$1"
    shift
    if ! "$@"; then
      echo "PASS: $desc"
    else
      echo "FAIL: $desc" >&2
      errors=$((errors + 1))
    fi
  }

  wrapper="${dxshell_package}/bin/dxshell"
  installer="${dxshell_install}/bin/dxshell-install"
  updater="${dxshell_update}/bin/dxshell-update"
  claude_settings="${activationPackage}/home-files/.claude/settings.json"
  claude_settings_alt="${activationPackageAlt}/home-files/.claude/settings.json"
  no_settings_dir="${activationPackageNoSettings}/home-files/.claude"

  echo "=== Script executability ==="
  check "wrapper is executable" test -x "$wrapper"
  check "installer is executable" test -x "$installer"
  check "updater is executable" test -x "$updater"

  echo ""
  echo "=== Valid shebangs ==="
  check "wrapper has nix store shebang" grep -q '^#!/nix/store/.*bash' "$wrapper"
  check "installer has nix store shebang" grep -q '^#!/nix/store/.*bash' "$installer"
  check "updater has nix store shebang" grep -q '^#!/nix/store/.*bash' "$updater"

  echo ""
  echo "=== No leftover @PLACEHOLDER@ tokens ==="
  check_not "wrapper has no placeholders" grep -qE '@[A-Z_]+@' "$wrapper"
  check_not "installer has no placeholders" grep -qE '@[A-Z_]+@' "$installer"
  check_not "updater has no placeholders" grep -qE '@[A-Z_]+@' "$updater"

  echo ""
  echo "=== Critical strings present ==="
  check "wrapper contains DXSHELL_STATE" grep -q 'DXSHELL_STATE' "$wrapper"
  check "wrapper contains claude settings backup logic" grep -q 'dxshell-backup-' "$wrapper"
  check "installer contains DXSHELL_BIN" grep -q 'DXSHELL_BIN' "$installer"
  check "updater contains fetch origin" grep -q 'fetch origin' "$updater"

  echo ""
  echo "=== Nix store paths are valid ==="
  for script in "$wrapper" "$installer" "$updater"; do
    name="$(basename "$script")"
    # Extract /nix/store paths and verify they exist
    grep -oE '/nix/store/[a-z0-9]{32}-[a-zA-Z0-9._+-]+' "$script" | sort -u | while read -r storepath; do
      check "$name: store path $storepath exists" test -e "$storepath"
    done
  done

  echo ""
  echo "=== Default Claude settings.json ==="
  check "settings.json exists" test -e "$claude_settings"
  check "settings.json is valid JSON" jq -e . "$claude_settings"
  check "settings.json has statusLine.command" jq -e '.statusLine.command' "$claude_settings"
  check "settings.json has permissions.allow array" jq -e '.permissions.allow | type == "array"' "$claude_settings"
  check "settings.json has Stop hook" jq -e '.hooks.Stop[0].hooks[0].command' "$claude_settings"
  check "Stop hook entry has matcher field" jq -e '.hooks.Stop[0] | has("matcher")' "$claude_settings"
  check "Stop hook command guards on DBUS_SESSION_BUS_ADDRESS" \
    jq -e '.hooks.Stop[0].hooks[0].command | contains("DBUS_SESSION_BUS_ADDRESS")' "$claude_settings"
  check_not "permissions.allow does NOT contain Bash(env:*)" \
    jq -e '.permissions.allow | index("Bash(env:*)")' "$claude_settings"

  echo ""
  echo "=== Alt Claude settings.json (notifyOnStop=false, extras applied) ==="
  check "alt settings.json exists" test -e "$claude_settings_alt"
  check_not "alt settings.json has NO Stop hook" jq -e '.hooks.Stop' "$claude_settings_alt"
  check "alt settings.json env.FOO == bar" \
    jq -e '.env.FOO == "bar"' "$claude_settings_alt"
  check "alt settings.json keeps default EDITOR=nvim" \
    jq -e '.env.EDITOR == "nvim"' "$claude_settings_alt"
  check "alt settings.json includes user extraAllow entry" \
    jq -e '.permissions.allow | index("Bash(npm:*)")' "$claude_settings_alt"
  check "alt settings.json still includes default allow entry" \
    jq -e '.permissions.allow | index("Bash(git status:*)")' "$claude_settings_alt"

  echo ""
  echo "=== manageSettings=false disables deployment ==="
  check_not "no_settings home-files lacks .claude/settings.json" \
    test -e "$no_settings_dir/settings.json"

  echo ""
  echo "=== Statusline binary ==="
  statusline="$(jq -r '.statusLine.command' "$claude_settings")"
  check "statusline binary exists" test -x "$statusline"
  check "statusline produces output for valid JSON" \
    sh -c "echo '{\"cwd\":\"/tmp\"}' | '$statusline' | grep -q ."
  check "statusline survives malformed stdin" \
    sh -c "printf 'not json at all' | '$statusline' >/dev/null"
  check "statusline produces output for malformed stdin" \
    sh -c "printf 'not json at all' | '$statusline' | grep -q ."

  echo ""
  echo "=== Statusline inside a real git repo ==="
  repo="$TMPDIR/sample-repo"
  mkdir -p "$repo"
  ( cd "$repo" \
    && git -c init.defaultBranch=trunk init -q \
    && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init )
  statusline_input='{"model":{"display_name":"Claude Test"},"cwd":"'"$repo"'"}'
  statusline_output=$(echo "$statusline_input" | "$statusline" || true)
  echo "statusline output: $statusline_output"
  check "statusline emits model name" \
    sh -c "echo '$statusline_output' | grep -q 'Claude Test'"
  check "statusline emits git branch suffix" \
    sh -c "echo '$statusline_output' | grep -q 'trunk'"

  echo ""
  echo "=== Stop hook command (DBus-guard correctness) ==="
  hook_cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$claude_settings")"
  check "Stop hook command parses as bash" \
    bash -n -c "$hook_cmd"
  # DBus-absent path: the guard should make it a silent no-op (exit 0).
  check "Stop hook is a no-op when DBUS_SESSION_BUS_ADDRESS is unset" \
    env -u DBUS_SESSION_BUS_ADDRESS bash -c "$hook_cmd"
  # Verify the libnotify path embedded in the command exists.
  notify_path="$(printf '%s' "$hook_cmd" | grep -oE '/nix/store/[a-z0-9]{32}-libnotify-[^/]+/bin/notify-send' | head -1)"
  if [ -n "$notify_path" ]; then
    check "libnotify binary referenced by Stop hook exists" test -x "$notify_path"
  else
    echo "FAIL: could not extract libnotify path from Stop hook" >&2
    errors=$((errors + 1))
  fi

  echo ""
  if [ "$errors" -gt 0 ]; then
    echo "$errors test(s) FAILED" >&2
    exit 1
  fi
  echo "All tests passed!"
  mkdir -p "$out"
  touch "$out/success"
''
