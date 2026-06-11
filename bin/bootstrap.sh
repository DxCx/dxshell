#!/bin/sh
# dxshell single-curl bootstrap.
#
# Installs a Nix runtime (if missing), then delegates to bin/setup.sh to
# clone dxshell and launch the standalone session.
#
# Three flavors:
#   --user     (default) Install nix-portable into ~/.local/bin and store all
#              Nix state under ~/.nix-portable/. No sudo, no /nix, nothing
#              system-wide is touched. Note: a Nix store cannot live on NFS
#              (non-removable NFSv4 ACL xattrs abort every build) — if $HOME
#              is NFS-mounted, use --local-dir-install instead.
#   --system   Install upstream multi-user Nix (daemon at /nix, requires sudo).
#              The right choice when you have admin rights and want a
#              properly-shared system Nix.
#   --local-dir-install[=DIR]
#              Fully self-contained install under DIR/.dxshell ($PWD/.dxshell
#              when no value is given): nix-portable binary, Nix store, repo
#              clone, and Home Manager state all live inside that one tree,
#              and an entry symlink DIR/dxshell is created next to it. Forces
#              the proot backend (NP_RUNTIME=proot, overridable at runtime),
#              which works on hardened hosts where bwrap's nested mount
#              namespaces are blocked. Made for hosts with an NFS-mounted
#              $HOME and no root access — point it at a local disk.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --user
#   curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --system
#   cd /path/on/local/disk && \
#     curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh | sh -s -- --local-dir-install
#
# Other flags:
#   --clean       Wipe previous dxshell state before launching. Forwarded to setup.sh.
#   standalone    (default) Run dxshell standalone. Forwarded to setup.sh.
#   install       Permanent install. Forwarded to setup.sh.
#                 (Incompatible with --local-dir-install: install mode bakes
#                 /nix/store paths into the launcher and login shell, which
#                 only resolve inside nix-portable's namespace.)
#
# Idempotency: the very first thing we check is whether *any* Nix runtime is
# already available (`nix` on PATH, `nix-portable` at ~/.local/bin, or a
# previously-sourceable Nix profile). If yes, the install branch is skipped
# entirely — no curl, no sudo prompt — regardless of which flag was passed.
# Exception: --local-dir-install gates on its own in-tree nix-portable
# (DIR/.dxshell/.local/bin/nix-portable) instead — the local tree must be
# self-contained, so a system Nix or a home nix-portable does not satisfy it.
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
LOCAL_PARENT=""

for arg in "$@"; do
  case "$arg" in
    --user) NIX_FLAVOR="user" ;;
    --system) NIX_FLAVOR="system" ;;
    --local-dir-install) LOCAL_PARENT="$PWD" ;;
    --local-dir-install=*) LOCAL_PARENT="${arg#--local-dir-install=}" ;;
    --clean) CLEAN="--clean" ;;
    standalone | install) MODE="$arg" ;;
    -h | --help)
      cat <<'EOF'
Usage: bootstrap.sh [--user|--system|--local-dir-install[=DIR]] [standalone|install] [--clean]

  --user     install nix-portable into ~/.local/bin (default; no sudo, no /nix)
  --system   install multi-user Nix daemon (requires sudo)
  --local-dir-install[=DIR]
             self-contained install under DIR/.dxshell (default DIR: $PWD);
             for NFS-home / restricted hosts — no sudo, nothing in $HOME

Run via:
  curl -fsSL https://raw.githubusercontent.com/DxCx/dxshell/master/bin/bootstrap.sh \
    | sh -s -- --user
EOF
      exit 0
      ;;
    *)
      echo "bootstrap: unknown argument '$arg'" >&2
      echo "  expected: --user | --system | --local-dir-install[=DIR] | --clean | standalone | install | -h" >&2
      exit 2
      ;;
  esac
done

# ----------------------------------------------------------------------------
# Resolve and validate the local-dir install base (if requested).
# ----------------------------------------------------------------------------
DXSHELL_BASE=""
if [ -n "$LOCAL_PARENT" ]; then
  if [ "$MODE" = "install" ]; then
    echo "bootstrap: --local-dir-install cannot be combined with 'install' mode." >&2
    echo "  Permanent install bakes /nix/store paths into the launcher and login" >&2
    echo "  shell; those paths only resolve inside nix-portable's namespace." >&2
    echo "  Use the default standalone mode instead." >&2
    exit 2
  fi
  if [ "$NIX_FLAVOR" = "system" ]; then
    echo "bootstrap: --local-dir-install cannot be combined with --system." >&2
    echo "  The local tree uses its own in-tree nix-portable; with a system-wide" >&2
    echo "  Nix you don't need a local-dir install — drop one of the two flags." >&2
    exit 2
  fi
  if [ ! -d "$LOCAL_PARENT" ]; then
    echo "bootstrap: --local-dir-install target '$LOCAL_PARENT' is not a directory." >&2
    exit 2
  fi
  # Canonicalize so the launcher bakes a stable absolute path.
  LOCAL_PARENT="$(cd "$LOCAL_PARENT" && pwd)"
  DXSHELL_BASE="$LOCAL_PARENT/.dxshell"

  # Guard: the home-mode flow clones the repo itself to ~/.dxshell. Refuse to
  # turn an existing clone into a container directory.
  if [ -d "$DXSHELL_BASE/.git" ]; then
    echo "bootstrap: $DXSHELL_BASE is a git clone (home-mode install layout)." >&2
    echo "  Refusing to reuse it as a local-install container. Remove it first" >&2
    echo "  (see bin/uninstall.sh) or run from a different directory." >&2
    exit 2
  fi

  # A Nix store cannot live on NFS — warn early instead of failing mid-build.
  fstype="$(stat -f -c %T "$LOCAL_PARENT" 2>/dev/null || true)"
  case "$fstype" in
    nfs*)
      echo "bootstrap: WARNING: '$LOCAL_PARENT' is on NFS ($fstype)." >&2
      echo "  Nix builds fail on NFS (non-removable NFSv4 ACL xattrs)." >&2
      echo "  Point --local-dir-install at a local filesystem instead." >&2
      ;;
  esac

  export DXSHELL_BASE
fi

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
# Download the pinned nix-portable release (checksum-verified) to $1.
# ----------------------------------------------------------------------------
install_nix_portable() {
  np_dest="$1"
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
  mkdir -p "${np_dest%/*}"

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
}

# ----------------------------------------------------------------------------
# Step 1 — install Nix if missing, picking the flavor.
# ----------------------------------------------------------------------------
if [ -n "$DXSHELL_BASE" ]; then
  # Local-dir install: the tree must be self-contained, so gate on the
  # in-tree binary only — a system nix or home nix-portable does not count.
  if [ -x "$DXSHELL_BASE/.local/bin/nix-portable" ]; then
    echo "bootstrap: in-tree nix-portable already present, skipping download"
  else
    install_nix_portable "$DXSHELL_BASE/.local/bin/nix-portable"
    echo "bootstrap: nix-portable installed; everything stays under $DXSHELL_BASE"
  fi
elif have_nix_runtime; then
  echo "bootstrap: Nix runtime already present, skipping install"
else
  case "$NIX_FLAVOR" in
    user)
      install_nix_portable "$HOME/.local/bin/nix-portable"

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
