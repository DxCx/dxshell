{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # General tools
      htop
      killall
      wget

      # Converting errors (errno) + useful tools (sponge, ts, vidir, chronic)
      moreutils
    ];
  };
}
