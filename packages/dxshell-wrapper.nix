{
  pkgs,
  activationPackage,
  homeDirectory,
}: let
  script =
    builtins.replaceStrings
    ["@ACTIVATION_PACKAGE@" "@GIT@" "@ZSH@" "@HM_HOME_DIR@"]
    ["${activationPackage}" "${pkgs.git}" "${pkgs.zsh}" homeDirectory]
    (builtins.readFile ../scripts/dxshell-wrapper.sh);
in
  pkgs.writeShellScriptBin "dxshell" script
