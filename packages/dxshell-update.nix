{pkgs}: let
  script =
    builtins.replaceStrings
    ["@GIT@"]
    ["${pkgs.git}"]
    (builtins.readFile ../scripts/dxshell-update.sh);
in
  pkgs.writeShellScriptBin "dxshell-update" script
