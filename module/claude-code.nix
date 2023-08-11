{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf (cfg.enable && cfg.allowUnfree && cfg.claudeCode.enable) {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) ["claude-code"];

    home.packages = [pkgs.claude-code];
  };
}
