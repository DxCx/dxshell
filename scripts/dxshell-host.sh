# shellcheck shell=bash
#
# dxshell-host — run a command on the host, outside dxshell's sandbox.
#
# Without a system Nix, nix-portable has to make /nix/store paths resolve for an
# unprivileged user, and both of its backends do that by confining the shell:
# proot ptraces every process, bwrap puts it in a user namespace. Neither can
# honour a setuid binary, and that is by kernel design, not a bug:
#
#   proot  execve(2) ignores the set-user-ID bit when the process is traced.
#   bwrap  the file's root owner is unmapped in the userns, so sudo reports
#          "/usr/bin/sudo must be owned by uid 0 and have the setuid bit set".
#
# So privileged host tools can never work *inside* the sandbox, under any
# backend. They have to run *outside* it. This is the portal pattern that
# flatpak-spawn --host and distrobox-host-exec use.
#
# It grants no new privilege: the command runs as the same uid, in the same
# login session, subject to the same sudoers policy the user already has from a
# plain shell. The sandbox is a packaging mechanism, not a security boundary.
#
# Invoked as `sudo` or `sudoedit` (symlinks installed alongside), it forwards to
# the matching host tool, so those keep working unchanged in scripts and
# Makefiles, not just at an interactive prompt.
set -eu

self=${0##*/}
case "$self" in
  sudo | sudoedit) set -- "$self" "$@" ;;
esac

if [ $# -eq 0 ]; then
  echo "usage: dxshell-host COMMAND [ARG...]" >&2
  echo "       run COMMAND on the host, outside dxshell's sandbox" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Host PATH.
#
# The in-shell PATH is mostly /nix/store/... which does not exist on the host.
# The launcher captures the real PATH before entering the sandbox; if that is
# missing (older launcher), derive one by dropping store and profile entries.
# Either way this must exclude our own profile, or resolving "sudo" below would
# find this very script and loop.
# ---------------------------------------------------------------------------
host_path=${DXSHELL_HOST_PATH:-}
if [ -z "$host_path" ]; then
  host_path=$(
    IFS=:
    set -f
    for d in $PATH; do
      case "$d" in
        "" | /nix/store/* | /nix/var/* | */.nix-profile/bin) ;;
        *) printf '%s:' "$d" ;;
      esac
    done
  )
  host_path=${host_path%:}
fi
[ -n "$host_path" ] || host_path=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin

# ---------------------------------------------------------------------------
# Resolve argv[0] against the host PATH ourselves.
#
# systemd-run resolves the command against the *caller's* PATH and bakes an
# absolute path into the transient unit. Left alone it picks the /nix/store
# build, which the host cannot see, and the unit dies with an opaque 203/EXEC.
# ---------------------------------------------------------------------------
cmd=$1
shift
case "$cmd" in
  */*) ;;
  *)
    resolved=$(PATH="$host_path" command -v "$cmd" 2>/dev/null || true)
    if [ -z "$resolved" ]; then
      echo "dxshell-host: $cmd: not found on host PATH" >&2
      exit 127
    fi
    cmd=$resolved
    ;;
esac
case "$cmd" in
  /nix/store/*)
    echo "dxshell-host: $cmd is a Nix store path; the host cannot see /nix." >&2
    echo "  Only host binaries can run outside the sandbox." >&2
    exit 127
    ;;
esac

# Outside the sandbox already — a system Nix install, or a plain host shell.
# Nothing to escape; run it directly. (cmd is a host path, so no loop.)
if [ -z "${NP_LOCATION:-}" ]; then
  exec "$cmd" "$@"
fi

# A /nix cwd has no host equivalent; fall back to the real home, then /.
dir=$PWD
case "$dir" in
  /nix/*) dir=${DXSHELL_REAL_HOME:-/} ;;
esac
[ -d "$dir" ] || dir=/

# sudo password prompts, sudoedit and visudo need a real terminal; pipelines
# need clean stdio. --pty and --pipe are mutually exclusive.
if [ -t 0 ] && [ -t 1 ]; then
  io=--pty
else
  io=--pipe
fi

# The systemd --user manager was started by logind, outside the sandbox, so the
# unit it forks for us is untraced and free of NO_NEW_PRIVS.
if command -v systemd-run >/dev/null 2>&1 &&
  [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
  exec systemd-run --user --quiet --wait --collect \
    "$io" \
    --working-directory="$dir" \
    --setenv="PATH=$host_path" \
    --setenv="TERM=${TERM:-xterm}" \
    -- "$cmd" "$@"
fi

# Fallback for hosts with no systemd user session: a loopback login also lands
# outside the sandbox.
if command -v ssh >/dev/null 2>&1 &&
  ssh -o BatchMode=yes -o ConnectTimeout=5 localhost true >/dev/null 2>&1; then
  quoted=
  for a in "$cmd" "$@"; do
    quoted="$quoted '$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'"
  done
  exec ssh -t localhost \
    "cd '$(printf '%s' "$dir" | sed "s/'/'\\\\''/g")' && PATH='$host_path' exec$quoted"
fi

echo "dxshell-host: no way out of the sandbox on this host." >&2
echo "  Needs a systemd --user session (systemd-run) or ssh to localhost." >&2
echo "  Run privileged commands from a plain shell instead." >&2
exit 127
