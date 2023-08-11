# shellcheck shell=bash
set -euo pipefail

DXSHELL_USER="${USER}"
DXSHELL_USER_HOME="${HOME}"
HM_CONFIG_DIR="${HOME}/.config/home-manager"

echo "dxshell: permanent install for ${DXSHELL_USER} (${DXSHELL_USER_HOME})"
echo ""

# Detect architecture
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) SYSTEM="x86_64-linux" ;;
  aarch64) SYSTEM="aarch64-linux" ;;
  *)
    echo "error: unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac
echo "Detected system: ${SYSTEM}"

# Determine flake URL: local clone (via DXSHELL_DIR) or GitHub
if [ -n "${DXSHELL_DIR:-}" ] && [ -d "${DXSHELL_DIR}/.git" ]; then
  DXSHELL_FLAKE_URL="path:${DXSHELL_DIR}"
  SESSION_VARS_BLOCK="home.sessionVariables.DXSHELL_FLAKE = \"${DXSHELL_DIR}\";"
  echo "Using local clone: ${DXSHELL_DIR}"
else
  DXSHELL_FLAKE_URL="github:DxCx/dxshell"
  SESSION_VARS_BLOCK=""
fi

# Create HM config directory
mkdir -p "${HM_CONFIG_DIR}"

# Generate flake.nix
cat >"${HM_CONFIG_DIR}/flake.nix" <<FLAKE_EOF
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dxshell = {
      url = "${DXSHELL_FLAKE_URL}";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs = {nixpkgs, home-manager, dxshell, ...}: {
    homeConfigurations."${DXSHELL_USER}" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${SYSTEM};
      modules = [
        dxshell.hmModule
        {
          home = {
            username = "${DXSHELL_USER}";
            homeDirectory = "${DXSHELL_USER_HOME}";
            stateVersion = "24.05";
          };
          ${SESSION_VARS_BLOCK}
        }
      ];
    };
  };
}
FLAKE_EOF

echo ""
echo "Generated ${HM_CONFIG_DIR}/flake.nix"
echo ""

# Run home-manager switch
echo "Running home-manager switch..."
@HOME_MANAGER@/bin/home-manager switch --flake "${HM_CONFIG_DIR}"

echo ""
echo "dxshell installed successfully!"
echo ""

# Auto-change login shell
ZSH_PATH="$(command -v zsh 2>/dev/null || echo "")"
if [ -z "${ZSH_PATH}" ]; then
  ZSH_PATH="${HOME}/.nix-profile/bin/zsh"
fi

if [ -x "${ZSH_PATH}" ]; then
  # Add to /etc/shells if not already present
  if ! grep -qxF "${ZSH_PATH}" /etc/shells 2>/dev/null; then
    echo "Adding ${ZSH_PATH} to /etc/shells (requires sudo)..."
    if echo "${ZSH_PATH}" | sudo tee -a /etc/shells >/dev/null 2>&1; then
      echo "Added to /etc/shells"
    else
      echo "Could not add to /etc/shells automatically."
      echo "Run manually: echo \"${ZSH_PATH}\" | sudo tee -a /etc/shells"
    fi
  fi

  # Change login shell
  echo "Changing login shell to ${ZSH_PATH}..."
  if chsh -s "${ZSH_PATH}" 2>/dev/null; then
    echo "Login shell changed to zsh"
  else
    echo "Could not change login shell automatically."
    echo "Run manually: chsh -s \"${ZSH_PATH}\""
  fi
else
  echo "To make zsh your login shell, run:"
  echo "  sudo sh -c 'echo \"${ZSH_PATH}\" >> /etc/shells' && chsh -s \"${ZSH_PATH}\""
fi
