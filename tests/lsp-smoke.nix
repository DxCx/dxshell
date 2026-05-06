# Smoke-test every language server we install: each binary should at least
# answer --version (or --help, where --version isn't supported) with exit 0
# and non-empty output. Catches closure breakage and missing runtime deps
# (e.g., the typescript-language-server / nodejs / typescript trio).
{
  pkgs,
  activationPackage,
}:
pkgs.runCommand "lsp-smoke" {
  nativeBuildInputs = [pkgs.gnugrep pkgs.coreutils];
} ''
  set -euo pipefail
  errors=0
  bin="${activationPackage}/home-path/bin"

  smoke() {
    local name="$1"
    shift
    if [ ! -x "$bin/$name" ]; then
      echo "FAIL: $name binary not found in home-path/bin" >&2
      errors=$((errors + 1))
      return
    fi
    if "$bin/$name" "$@" 2>&1 | grep -q .; then
      echo "PASS: $name responds to ''${*}"
    else
      echo "FAIL: $name produced no output for ''${*}" >&2
      errors=$((errors + 1))
    fi
  }

  smoke clangd                     --version
  smoke rust-analyzer              --version
  smoke pyright                    --version
  smoke ruff                       --version
  smoke bash-language-server       --version
  smoke lua-language-server        --version
  smoke typescript-language-server --version
  smoke nil                        --version
  smoke yaml-language-server       --version
  smoke taplo                      --version
  smoke marksman                   --version

  if [ "$errors" -gt 0 ]; then
    echo "$errors LSP smoke test(s) failed" >&2
    exit 1
  fi
  mkdir -p "$out"
  touch "$out/success"
''
