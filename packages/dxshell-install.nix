{
  pkgs,
  dxshell_package,
}: let
  script =
    builtins.replaceStrings
    ["@DXSHELL_PACKAGE@"]
    ["${dxshell_package}"]
    (builtins.readFile ../scripts/dxshell-install.sh);
in
  pkgs.writeShellScriptBin "dxshell-install" script
