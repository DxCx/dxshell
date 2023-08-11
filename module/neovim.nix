{
  config,
  lib,
  pkgs,
  dxvim,
  ...
}: let
  cfg = config.dxshell;
  inherit (pkgs.stdenv.hostPlatform) system;

  dxvim_package = dxvim.packages.${system}.default;
  diffAlias = {
    vimdiff = "nvim -d";
  };
in {
  config = lib.mkIf (cfg.enable && cfg.neovim.enable) {
    home.packages = [dxvim_package];
    home.sessionVariables = {
      EDITOR = "nvim";
    };
    programs = {
      git.settings = {
        core.editor = "nvim";
        merge.tool = "vimdiff";
      };
      zsh.shellAliases = diffAlias;
      bash.shellAliases = diffAlias;
    };

    # TODO: Should export my inner object in order to make this work.
    # programs.neovim = {
    #   enable = true;
    #   package = dxvim_package;
    #   defaultEditor = true;
    #   viAlias = true;
    #   vimAlias = true;
    #   vimdiffAlias = true;
    # };
  };
}
