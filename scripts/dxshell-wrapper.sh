# shellcheck shell=bash
set -euo pipefail

REAL_HOME="${HOME}"
DXSHELL_CACHE="${HOME}/.cache/dxshell"
DXSHELL_HOME="${HOME}/.dxshell-home"
ACTIVATION_STORE_PATH="@ACTIVATION_PACKAGE@"
ACTIVATION_STAMP="${DXSHELL_CACHE}/current-generation"

mkdir -p "${DXSHELL_HOME}" "${DXSHELL_CACHE}"

# HM bakes homeDirectory ("/tmp/dxshell-home") into generated configs
# (XDG paths, bat cache, profile scripts).  Symlink it to the real home
# so those paths resolve at runtime.
# Remove stale dir/symlink before recreating (ln -sfn won't replace a directory)
rm -rf "/tmp/dxshell-home"
ln -sfn "${DXSHELL_HOME}" "/tmp/dxshell-home"

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
    exit 1
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
export HOME="${DXSHELL_HOME}"
# Ensure HM-installed packages are on PATH — the profile is installed
# at DXSHELL_HOME by activation, and this is more reliable than depending
# on HM's session vars resolving through the /tmp symlink chain.
export PATH="${DXSHELL_HOME}/.nix-profile/bin${PATH:+:$PATH}"
# Reconnect stdin to the real terminal — when invoked via `curl | sh`,
# stdin is the pipe (at EOF), which causes zsh to exit immediately.
exec @ZSH@/bin/zsh -l </dev/tty
