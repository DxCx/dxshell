{
  pkgs,
  activationPackage,
  homeDirectory,
}: let
  script =
    builtins.replaceStrings
    ["@ACTIVATION_PACKAGE@" "@GIT@" "@ZSH@" "@HM_HOME_DIR@" "@COREUTILS@"]
    ["${activationPackage}" "${pkgs.git}" "${pkgs.zsh}" homeDirectory "${pkgs.coreutils}"]
    (builtins.readFile ../scripts/dxshell-wrapper.sh);
in
  pkgs.writeShellScriptBin "dxshell" script
