{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf (cfg.enable && cfg.hostExec.enable) {
    home.packages = [
      (import ../packages/dxshell-host.nix {
        inherit pkgs;
        inherit (cfg.hostExec) shimSudo;
      })
    ];
  };
}
