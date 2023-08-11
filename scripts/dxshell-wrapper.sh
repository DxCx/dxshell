# shellcheck shell=bash
set -euo pipefail

REAL_HOME="${HOME}"
DXSHELL_CACHE="${HOME}/.cache/dxshell"
DXSHELL_HOME="${DXSHELL_CACHE}/home"
ACTIVATION_STORE_PATH="@ACTIVATION_PACKAGE@"
ACTIVATION_STAMP="${DXSHELL_CACHE}/current-generation"

# Create the isolated dxshell home
mkdir -p "${DXSHELL_HOME}"

# Check if we need to (re-)activate
NEEDS_ACTIVATE=0
if [ ! -f "${ACTIVATION_STAMP}" ]; then
  NEEDS_ACTIVATE=1
elif [ "$(cat "${ACTIVATION_STAMP}")" != "${ACTIVATION_STORE_PATH}" ]; then
  NEEDS_ACTIVATE=1
fi

if [ "${NEEDS_ACTIVATE}" = "1" ]; then
  echo "dxshell: activating home-manager configuration..."
  # HM activation uses $HOME to place symlinks
  HOME="${DXSHELL_HOME}" "${ACTIVATION_STORE_PATH}/activate" || true

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
  @GIT@/bin/git config --file "${DXSHELL_HOME}/.gitconfig" include.path "${DXSHELL_HOME}/.gitconfig-user"
fi

# Launch dxshell
export DXSHELL_REAL_HOME="${REAL_HOME}"
export HOME="${DXSHELL_HOME}"
exec @ZSH@/bin/zsh -l
