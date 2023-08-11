{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
in {
  config = lib.mkIf (cfg.enable && cfg.git.enable) {
    programs.git = {
      enable = true;
      package = pkgs.gitFull;

      settings = {
        color.ui = "auto";
        column.ui = "auto";
        branch = {
          autosetuprebase = "always";
          sort = "--committerdate";
        };
        core = {
          fsmonitor = true;
          untrackedcache = true;
        };
        log = {
          date = "relative";
          decorate = true;
        };
        rebase = {
          instructionFormat = "(%an <%ae>) %s";
          updateRefs = true;
        };
        commit.verbose = true;
        alias = {
          l = ''log --pretty=format:"%C(auto,yellow)%h %C(auto,green)%<(10,trunc)%aN %C(auto,reset)%<(80,trunc)%s %C(auto,blue)[%>(12)%ad]%C(auto,red)%d" --graph --'';
        };
      };
    };
  };
}
