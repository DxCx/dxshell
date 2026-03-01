# shellcheck shell=bash
set -euo pipefail

DXSHELL_BIN="${HOME}/.local/bin/dxshell"
DXSHELL_GCROOT_DIR="${HOME}/.local/share/dxshell"
DXSHELL_STORE_PATH="@DXSHELL_PACKAGE@"

echo "dxshell: installing standalone shell for ${USER}"
echo ""

# 1. Create ~/.local/bin/dxshell symlink to the nix store binary
mkdir -p "$(dirname "${DXSHELL_BIN}")"
ln -sfn "${DXSHELL_STORE_PATH}/bin/dxshell" "${DXSHELL_BIN}"
echo "Installed: ${DXSHELL_BIN} -> ${DXSHELL_STORE_PATH}/bin/dxshell"

# 2. Add a nix GC root to prevent garbage collection
mkdir -p "${DXSHELL_GCROOT_DIR}"
ln -sfn "${DXSHELL_STORE_PATH}" "${DXSHELL_GCROOT_DIR}/gcroot"
echo "GC root: ${DXSHELL_GCROOT_DIR}/gcroot"

# 3. Add to /etc/shells if not already present
if ! grep -qxF "${DXSHELL_BIN}" /etc/shells 2>/dev/null; then
  echo "Adding ${DXSHELL_BIN} to /etc/shells (requires sudo)..."
  if echo "${DXSHELL_BIN}" | sudo tee -a /etc/shells >/dev/null 2>&1; then
    echo "Added to /etc/shells"
  else
    echo "Could not add to /etc/shells automatically."
    echo "Run manually: echo \"${DXSHELL_BIN}\" | sudo tee -a /etc/shells"
  fi
fi

# 4. Change login shell
echo "Changing login shell to ${DXSHELL_BIN}..."
if command -v chsh >/dev/null 2>&1 && sudo chsh -s "${DXSHELL_BIN}" "${USER}" 2>/dev/null; then
  echo "Login shell changed to dxshell"
elif command -v usermod >/dev/null 2>&1 && sudo usermod -s "${DXSHELL_BIN}" "${USER}" 2>/dev/null; then
  echo "Login shell changed to dxshell"
else
  echo "Could not change login shell automatically."
  echo "Run manually: sudo usermod -s \"${DXSHELL_BIN}\" \"${USER}\""
fi

echo ""
echo "dxshell installed successfully!"
echo "Log out and back in to use dxshell as your login shell."
