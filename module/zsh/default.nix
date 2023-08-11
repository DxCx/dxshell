{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  #has ~/.zshrc, ZDOTDIR= to set.
  pluginsP10k = with pkgs; [
    {
      # A prompt will appear the first time to configure it properly
      # make sure to select MesloLGS NF as the font in Console
      name = "powerlevel10k";
      src = zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }
    {
      name = "powerlevel10k-config";
      src = lib.cleanSource ./p10k-config;
      file = "p10k.zsh";
    }
  ];
in {
  config = lib.mkIf (cfg.enable && cfg.zsh.enable) {
    # Just to make sure it will be also configured in paralllel as fallback to zsh
    programs = {
      bash.enable = true;

      zsh = {
        enable = true;
        autocd = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
        history.size = 20000;
        historySubstringSearch.enable = true;
        autosuggestion.enable = true;

        plugins = with pkgs;
          pluginsP10k
          ++ [
            {
              name = "zsh-abbrev-alias";
              file = "abbrev-alias.plugin.zsh";
              src = fetchFromGitHub {
                owner = "momo-lab";
                repo = "zsh-abbrev-alias";
                rev = "33fe094da0a70e279e1cc5376a3d7cb7a5343df5";
                sha256 = "1cvgvb1q0bwwnnvkd7yjc7sq9fgghbby1iffzid61gi9j895iblf";
              };
            }
            {
              name = "zsh-autopair";
              file = "autopair.zsh";
              src = fetchFromGitHub {
                owner = "hlissner";
                repo = "zsh-autopair";
                rev = "449a7c3d095bc8f3d78cf37b9549f8bb4c383f3d";
                sha256 = "1x16y24hbwcaxfhqabw4x26jmpxzz2zzmlvs9nnbzaxyi20cwfyz";
              };
            }
            {
              name = "zsh-nix-shell";
              file = "nix-shell.plugin.zsh";
              src = fetchFromGitHub {
                owner = "chisui";
                repo = "zsh-nix-shell";
                rev = "82ca15e638cc208e6d8368e34a1625ed75e08f90";
                sha256 = "1l99ayc9j9ns450blf4rs8511lygc2xvbhkg1xp791abcn8krn26";
              };
            }
          ];
      };

      fzf = {
        enable = true;
        enableZshIntegration = true;
      };
    };

    home.packages = with pkgs; [nix-zsh-completions];
  };
}
