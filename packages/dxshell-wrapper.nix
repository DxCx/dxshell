{
  pkgs,
  activationPackage,
}: let
  script =
    builtins.replaceStrings
    ["@ACTIVATION_PACKAGE@" "@GIT@" "@ZSH@"]
    ["${activationPackage}" "${pkgs.git}" "${pkgs.zsh}"]
    (builtins.readFile ../scripts/dxshell-wrapper.sh);
in
  pkgs.writeShellScriptBin "dxshell" script
