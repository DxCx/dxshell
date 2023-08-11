{pkgs}: let
  script =
    builtins.replaceStrings
    ["@HOME_MANAGER@"]
    ["${pkgs.home-manager}"]
    (builtins.readFile ../scripts/dxshell-install.sh);
in
  pkgs.writeShellScriptBin "dxshell-install" script
