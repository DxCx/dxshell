# Verify dxshell.hmModule evaluates cleanly when imported from a NixOS-style
# context (i.e., as a submodule of home-manager.nixosModules.home-manager).
# We don't actually build a nixosSystem — we replicate the relevant code path
# by constructing a homeManagerConfiguration with the same module composition
# a NixOS user would write.
#
# This catches regressions where dxshell starts depending on a HM feature
# only available in standalone mode, or where the module's option types
# break under NixOS's strict module evaluation.
{
  pkgs,
  hmConfigNixos,
}:
pkgs.runCommand "nixos-import" {} ''
  set -euo pipefail

  # The activationPackage is a derivation; if the module evaluated, this
  # path resolves. If the module had a type error or a missing option, the
  # flake evaluation upstream would have already failed.
  test -e "${hmConfigNixos.activationPackage}"
  test -d "${hmConfigNixos.activationPackage}/home-files/.claude"
  echo "PASS: hmModule evaluates under NixOS-style submodule composition"
  mkdir -p "$out"
  touch "$out/success"
''
