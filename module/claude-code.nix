{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf (cfg.enable && cfg.allowUnfree && cfg.claudeCode.enable) {
    home.packages = [pkgs.claude-code];
  };
}
