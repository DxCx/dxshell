#!/bin/sh
# dxshell single-curl bootstrap.
#
# Installs a Nix runtime (if missing), then delegates to bin/setup.sh to
# clone dxshell and launch the standalone session.
#
# Two flavors:
#   --user     (default) Install nix-portable into ~/.local/bin and store all
#              Nix state under ~/.nix-portable/. No sudo, no /nix, nothing
#              system-wide is touched. Works perfectly on shared HOME mounts
#              across servers of the same CPU architecture.
#   --system   Install upstream multi-user Nix (daemon at /nix, requires sudo).
#              The right choice when you have admin rights and want a
#              properly-shared system Nix.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --user
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --system
#
# Other flags:
#   --clean       Wipe previous dxshell state before launching. Forwarded to setup.sh.
#   standalone    (default) Run dxshell standalone. Forwarded to setup.sh.
#   install       Permanent install. Forwarded to setup.sh.
#
# Idempotency: the very first thing we check is whether *any* Nix runtime is
# already available (`nix` on PATH, `nix-portable` at ~/.local/bin, or a
# previously-sourceable Nix profile). If yes, the install branch is skipped
# entirely — no curl, no sudo prompt — regardless of which flag was passed.
set -eu

# Pinned nix-portable release. Refresh by:
#   curl -fsSL https://api.github.com/repos/DavHau/nix-portable/releases/latest
#   curl -fsSL <asset-url> | sha256sum
NP_VERSION="v012"
NP_SHA_X86_64="b409c55904c909ac3aeda3fb1253319f86a89ddd1ba31a5dec33d4a06414c72a"
NP_SHA_AARCH64="af41d8defdb9fa17ee361220ee05a0c758d3e6231384a3f969a314f9133744ea"

NIX_FLAVOR="user"
MODE="standalone"
CLEAN=""

for arg in "$@"; do
  case "$arg" in
    --user) NIX_FLAVOR="user" ;;
    --system) NIX_FLAVOR="system" ;;
    --clean) CLEAN="--clean" ;;
    standalone | install) MODE="$arg" ;;
    -h | --help)
      cat <<'EOF'
Usage: bootstrap.sh [--user|--system] [standalone|install] [--clean]

  --user     install nix-portable into ~/.local/bin (default; no sudo, no /nix)
  --system   install multi-user Nix daemon (requires sudo)

Run via:
  curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh \
    | sh -s -- --user
EOF
      exit 0
      ;;
    *)
      echo "bootstrap: unknown argument '$arg'" >&2
      echo "  expected: --user | --system | --clean | standalone | install | -h" >&2
      exit 2
      ;;
  esac
done

# ----------------------------------------------------------------------------
# Detect whether any Nix runtime is already available.
# ----------------------------------------------------------------------------
have_nix_runtime() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi
  if command -v nix-portable >/dev/null 2>&1; then
    return 0
  fi
  if [ -x "$HOME/.local/bin/nix-portable" ]; then
    return 0
  fi
  return 1
}

# ----------------------------------------------------------------------------
# Step 1 — install Nix if missing, picking the flavor.
# ----------------------------------------------------------------------------
if have_nix_runtime; then
  echo "bootstrap: Nix runtime already present, skipping install"
else
  case "$NIX_FLAVOR" in
    user)
      arch="$(uname -m)"
      case "$arch" in
        x86_64) np_sha="$NP_SHA_X86_64" ;;
        aarch64 | arm64) np_sha="$NP_SHA_AARCH64" ;;
        *)
          echo "bootstrap: nix-portable not published for arch '$arch'." >&2
          echo "  Use --system or install Nix manually." >&2
          exit 1
          ;;
      esac
      np_url="https://github.com/DavHau/nix-portable/releases/download/${NP_VERSION}/nix-portable-${arch}"
      np_dest="$HOME/.local/bin/nix-portable"
      mkdir -p "$HOME/.local/bin"

      echo "bootstrap: downloading nix-portable ${NP_VERSION} (${arch}) to ${np_dest}..."
      curl --proto '=https' --tlsv1.2 -fsSL "$np_url" -o "$np_dest.tmp"
      actual_sha="$(sha256sum "$np_dest.tmp" | awk '{print $1}')"
      if [ "$actual_sha" != "$np_sha" ]; then
        echo "bootstrap: nix-portable checksum mismatch (got $actual_sha, expected $np_sha)" >&2
        rm -f "$np_dest.tmp"
        exit 1
      fi
      mv "$np_dest.tmp" "$np_dest"
      chmod +x "$np_dest"

      # Make ~/.local/bin discoverable for the rest of this script (setup.sh).
      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
      esac
      export PATH

      echo "bootstrap: nix-portable installed; everything stays under ~/.local/bin and ~/.nix-portable"
      ;;
    system)
      echo "bootstrap: installing Nix (multi-user, requires sudo)..."
      curl --proto '=https' --tlsv1.2 -fsSL https://nixos.org/nix/install |
        sh -s -- --daemon
      # Multi-user installs the daemon profile script; fall back to the
      # user profile script if /etc/profile.d isn't on this host's path.
      if [ -f /etc/profile.d/nix-daemon.sh ]; then
        # shellcheck disable=SC1091
        . /etc/profile.d/nix-daemon.sh
      elif [ -f /etc/profile.d/nix.sh ]; then
        # shellcheck disable=SC1091
        . /etc/profile.d/nix.sh
      elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      ;;
  esac

  if ! have_nix_runtime; then
    echo "bootstrap: install completed but no Nix runtime is on PATH." >&2
    echo "  Open a new shell and re-run this command." >&2
    exit 1
  fi
fi

# ----------------------------------------------------------------------------
# Step 2 — delegate to setup.sh.
# ----------------------------------------------------------------------------
echo "bootstrap: launching setup.sh in $MODE mode..."
SETUP_URL="https://raw.githubusercontent.com/DxCx/dxshell/master/bin/setup.sh"
if [ -n "$CLEAN" ]; then
  curl -fsSL "$SETUP_URL" | sh -s -- "$MODE" "$CLEAN"
else
  curl -fsSL "$SETUP_URL" | sh -s -- "$MODE"
fi
