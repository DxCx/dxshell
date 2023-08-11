{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  inherit (builtins) readFile;
  plugins = (import ./plugins.nix) {inherit pkgs;};
in {
  config = lib.mkIf (cfg.enable && cfg.tmux.enable) {
    # TODO: has ~/.config - can be loaded manually with -f on alias.
    programs.tmux = {
      inherit plugins;

      enable = true;

      # I like my panes to go from 1-9 like keyboard order.
      baseIndex = 1;

      # Keys like vim
      keyMode = "vi";
      # My prefix is C-a
      prefix = "C-a";

      # Try to take always max pane size.
      aggressiveResize = true;

      # Assume modern terminal
      terminal = "tmux-256color";
      clock24 = true;

      # Fix Vim escape delay.
      escapeTime = 0;

      # Long history
      historyLimit = 100000;

      extraConfig = readFile ./tmux.conf;
    };
  };
}
