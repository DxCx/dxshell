{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf (cfg.enable && cfg.cliTools.enable) {
    programs = {
      # Enable direnv
      direnv.enable = true;

      # cat replacement
      zsh.shellAliases = {
        cat = "bat";
        top = "btm"; # top replacement (bottom)
        du = "dust"; # du replacement
      };
      bat = {
        enable = true;
        config.theme = "base16";
      };

      # ls replacement
      eza = {
        enable = true;
        enableZshIntegration = true;
        extraOptions = [
          "--group-directories-first"
          "--header"
        ];
        icons = "auto";
        git = true;
      };

      # top replacement (bottom)
      bottom = {
        enable = true;
        settings = {
          flags = {
            avg_cpu = true;
            temperature_type = "c";
          };
          colors.low_battery_color = "red";
        };
      };
    };

    home.packages = with pkgs; [
      # du replacement
      dust
    ];
  };
}
