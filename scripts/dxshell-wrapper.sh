# shellcheck shell=bash
set -euo pipefail

REAL_HOME="${HOME}"
DXSHELL_STATE="${DXSHELL_STATE_DIR:-${HOME}/.dxshell-state}"
DXSHELL_HOME="${DXSHELL_STATE}/home"
ACTIVATION_STORE_PATH="@ACTIVATION_PACKAGE@"
ACTIVATION_STAMP="${DXSHELL_STATE}/current-generation"
HM_HOME_DIR="@HM_HOME_DIR@"

mkdir -p "${DXSHELL_HOME}"

# HM bakes homeDirectory into generated configs (XDG paths, bat cache,
# profile scripts).  Symlink it to the real home so those paths resolve
# at runtime.
# Remove stale dir/symlink before recreating (ln -sfn won't replace a directory)
rm -rf "${HM_HOME_DIR}"
ln -sfn "${DXSHELL_HOME}" "${HM_HOME_DIR}"

# Ensure nix tools are on PATH — when running as a login shell,
# nix profile scripts haven't been sourced yet.
if ! command -v nix-env >/dev/null 2>&1; then
  for _nix_profile_script in \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
    "${REAL_HOME}/.nix-profile/etc/profile.d/nix.sh"; do
    if [ -f "${_nix_profile_script}" ]; then
      # shellcheck disable=SC1090
      . "${_nix_profile_script}"
      break
    fi
  done
  unset _nix_profile_script
fi

# Home Manager activation invokes Nix's legacy CLIs (nix-build, nix-env) by bare
# name, assuming they are on PATH. Under nix-portable they are not — `nix run`
# does not inject them — which aborts activation with "nix-build: command not
# found". Prepend the active Nix profile's bin dir (falling back to the nix
# package in the store) so activation succeeds. No-op when nix-build already
# resolves (e.g. real multi-user / single-user Nix installs), and uses globbing
# only — no readlink/dirname, so it can never emit "missing operand".
if ! command -v nix-build >/dev/null 2>&1; then
  for _nix_bindir in \
    /nix/var/nix/profiles/default/bin \
    /nix/store/*-nix-[0-9]*/bin; do
    if [ -x "${_nix_bindir}/nix-build" ]; then
      PATH="${_nix_bindir}:${PATH}"
      export PATH
      break
    fi
  done
  unset _nix_bindir
fi

# Back up any pre-existing ~/.claude/settings.json so HM activation does not
# abort with "Existing file is in the way". Symlinks (already-managed by a
# previous activation) and missing files are left alone.
CLAUDE_SETTINGS="${REAL_HOME}/.claude/settings.json"
if [ -e "${CLAUDE_SETTINGS}" ] && [ ! -L "${CLAUDE_SETTINGS}" ]; then
  CLAUDE_BACKUP="${CLAUDE_SETTINGS}.dxshell-backup-$(@COREUTILS@/bin/date +%Y%m%d-%H%M%S)"
  @COREUTILS@/bin/mv "${CLAUDE_SETTINGS}" "${CLAUDE_BACKUP}"
  echo "dxshell: backed up existing ${CLAUDE_SETTINGS} to ${CLAUDE_BACKUP}" >&2
  echo "dxshell: migrate any custom fields into 'dxshell.claudeCode.extraSettings'" >&2
fi

# Check if we need to (re-)activate
NEEDS_ACTIVATE=0
if [ ! -f "${ACTIVATION_STAMP}" ]; then
  NEEDS_ACTIVATE=1
elif [ "$(cat "${ACTIVATION_STAMP}")" != "${ACTIVATION_STORE_PATH}" ]; then
  NEEDS_ACTIVATE=1
elif [ ! -f "${DXSHELL_HOME}/.zshrc" ]; then
  NEEDS_ACTIVATE=1
fi

if [ "${NEEDS_ACTIVATE}" = "1" ]; then
  echo "dxshell: activating home-manager configuration..."
  # SKIP_SANITY_CHECKS: HM checks $HOME/$USER against build-time values;
  # skip these since we intentionally activate into a different directory.
  SKIP_SANITY_CHECKS=1 HOME="${DXSHELL_HOME}" "${ACTIVATION_STORE_PATH}/activate" || true

  # Sanity check
  if [ ! -f "${DXSHELL_HOME}/.zshrc" ]; then
    echo "dxshell: error: activation failed (.zshrc not found)" >&2
    echo "dxshell: falling back to basic shell" >&2
    exec /bin/bash -l
  fi

  # Record the current generation for cache invalidation
  echo "${ACTIVATION_STORE_PATH}" >"${ACTIVATION_STAMP}"
  echo "dxshell: activation complete"
fi

# Symlink real ~/.ssh into dxshell home (SSH keys + agent forwarding)
if [ -d "${REAL_HOME}/.ssh" ] && [ ! -e "${DXSHELL_HOME}/.ssh" ]; then
  ln -sf "${REAL_HOME}/.ssh" "${DXSHELL_HOME}/.ssh"
fi

# Include real git identity via git's include.path mechanism
if [ -f "${REAL_HOME}/.gitconfig" ] && [ ! -f "${DXSHELL_HOME}/.gitconfig-user" ]; then
  cp "${REAL_HOME}/.gitconfig" "${DXSHELL_HOME}/.gitconfig-user"
  # Remove HM-managed .gitconfig symlink (points to read-only nix store)
  # so we can create a writable config that includes the user's identity.
  rm -f "${DXSHELL_HOME}/.gitconfig"
  @GIT@/bin/git config --file "${DXSHELL_HOME}/.gitconfig" include.path "${DXSHELL_HOME}/.gitconfig-user"
fi

# Launch dxshell
export DXSHELL_REAL_HOME="${REAL_HOME}"
# Keep HOME pointing to the real home so ~ resolves correctly for the user.
# Tools find their dxshell-managed configs via explicit XDG/ZDOTDIR variables.
export HOME="${REAL_HOME}"
export ZDOTDIR="${DXSHELL_HOME}"
export XDG_CONFIG_HOME="${DXSHELL_HOME}/.config"
export XDG_DATA_HOME="${DXSHELL_HOME}/.local/share"
export XDG_STATE_HOME="${DXSHELL_HOME}/.local/state"
export XDG_CACHE_HOME="${DXSHELL_HOME}/.cache"
# Ensure HM-installed packages are on PATH — the profile is installed
# at DXSHELL_HOME by activation, and this is more reliable than depending
# on HM's session vars resolving through the /tmp symlink chain.
export PATH="${DXSHELL_HOME}/.nix-profile/bin${PATH:+:$PATH}"
# Point SHELL at the dxshell zsh. Programs that spawn shells via $SHELL —
# tmux's default-shell, vim's :terminal, etc. — would otherwise launch the
# user's login shell (e.g. bash) without any dxshell configuration.
export SHELL="@ZSH@/bin/zsh"

# Directory-managed logins (LDAP / SSSD / NIS): gitFull's compiled-in ssh is a
# Nix-glibc openssh, which cannot load the host's NSS modules and so fails
# getpwuid for any uid not in the static /etc/passwd ("No user exists for uid
# …"), breaking git-over-ssh. Nix glibc resolves a uid only via the built-in
# 'files' source, so "uid absent from /etc/passwd" is exactly the set it can't
# handle. For those users, steer git at the host ssh (host glibc + NSS, plus
# the user's own ssh config/agent). Skipped when the uid is local, when no host
# ssh is found, or when the user already set GIT_SSH_COMMAND.
if [ -z "${GIT_SSH_COMMAND:-}" ]; then
  _dxshell_uid="$(@COREUTILS@/bin/id -u 2>/dev/null || true)"
  _dxshell_uid_local=0
  if [ -n "${_dxshell_uid}" ] && [ -r /etc/passwd ]; then
    while IFS=: read -r _ _ _pw_uid _; do
      if [ "${_pw_uid}" = "${_dxshell_uid}" ]; then
        _dxshell_uid_local=1
        break
      fi
    done </etc/passwd
  fi
  if [ "${_dxshell_uid_local}" = "0" ]; then
    _dxshell_host_ssh=""
    for _ssh_cand in /usr/bin/ssh /bin/ssh; do
      if [ -x "${_ssh_cand}" ]; then
        _dxshell_host_ssh="${_ssh_cand}"
        break
      fi
    done
    # Fall back to any ssh on PATH that is not the (broken) Nix one.
    if [ -z "${_dxshell_host_ssh}" ]; then
      _ssh_cand="$(command -v ssh 2>/dev/null || true)"
      case "${_ssh_cand}" in
        /nix/store/*) ;;
        ?*) _dxshell_host_ssh="${_ssh_cand}" ;;
      esac
    fi
    if [ -n "${_dxshell_host_ssh}" ]; then
      export GIT_SSH_COMMAND="${_dxshell_host_ssh}"
    fi
  fi
  unset _dxshell_uid _dxshell_uid_local _pw_uid _dxshell_host_ssh _ssh_cand
fi

# When invoked with arguments (e.g., "dxshell -c 'command'"), forward them
# to zsh.  This is required because $SHELL is set to the dxshell wrapper
# when used as a login shell, and programs like SSH use "$SHELL -c ..."
# to evaluate commands.  Without this, those invocations would spawn an
# unwanted interactive shell instead of running the command.
if [ $# -gt 0 ]; then
  exec @ZSH@/bin/zsh "$@"
fi

# Reconnect stdin to the real terminal — when invoked via `curl | sh`,
# stdin is the pipe (at EOF), which causes zsh to exit immediately.
# When used as a login shell, stdin is already a tty.
if [ -t 0 ]; then
  exec @ZSH@/bin/zsh -l
fi

# Prefer the concrete pty stderr points at (e.g. /dev/pts/3) over the
# /dev/tty alias: tmux refuses clients whose stdin resolves to "/dev/tty"
# ("open terminal failed: can't use /dev/tty").
if [ -t 2 ]; then
  _real_tty="$(readlink "/proc/self/fd/2" 2>/dev/null || true)"
  if [ -n "${_real_tty}" ] && [ -c "${_real_tty}" ] && [ -r "${_real_tty}" ]; then
    exec @ZSH@/bin/zsh -l <"${_real_tty}"
  fi
  unset _real_tty
fi
exec @ZSH@/bin/zsh -l </dev/tty
