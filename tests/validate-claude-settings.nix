# Validate the rendered ~/.claude/settings.json files against the official
# schemastore schema for Claude Code. Catches schema drift introduced either
# by us (typo in a key) or upstream (Claude Code rename / removal).
{
  pkgs,
  schema,
  activationPackage,
  activationPackageAlt,
}:
pkgs.runCommand "validate-claude-settings" {
  nativeBuildInputs = [pkgs.check-jsonschema];
} ''
  set -euo pipefail
  errors=0

  validate() {
    local label="$1"
    local file="$2"
    if check-jsonschema --schemafile "${schema}" "$file"; then
      echo "PASS: $label conforms to Claude Code settings schema"
    else
      echo "FAIL: $label does not conform" >&2
      errors=$((errors + 1))
    fi
  }

  validate "default settings.json" \
    "${activationPackage}/home-files/.claude/settings.json"
  validate "alt settings.json (notifyOnStop=false, extras)" \
    "${activationPackageAlt}/home-files/.claude/settings.json"

  if [ "$errors" -gt 0 ]; then
    echo "$errors settings file(s) failed schema validation" >&2
    exit 1
  fi
  mkdir -p "$out"
  touch "$out/success"
''
