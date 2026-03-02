{
  pkgs,
  dxshell_package,
  dxshell_install,
  dxshell_update,
}:
pkgs.runCommand "test-scripts" {
  nativeBuildInputs = [pkgs.gnugrep pkgs.coreutils];
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
  if [ "$errors" -gt 0 ]; then
    echo "$errors test(s) FAILED" >&2
    exit 1
  fi
  echo "All tests passed!"
  mkdir -p "$out"
  touch "$out/success"
''
