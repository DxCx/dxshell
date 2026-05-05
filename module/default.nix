{lib, ...}: {
  options.dxshell = {
    enable = lib.mkEnableOption "dxshell development shell environment";

    neovim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable dxvim (Neovim) configuration.";
    };

    git.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable opinionated git configuration.";
    };

    zsh.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zsh with Powerlevel10k and plugins.";
    };

    tmux.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable tmux with plugins and keybindings.";
    };

    cliTools.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable CLI tools (bat, eza, bottom, dust, direnv).";
    };

    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow installation of unfree packages (e.g., claude-code).";
    };

    lsp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable language servers (gates the per-bundle toggles below).";
      };
      systems.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Systems LSPs: clang-tools (clangd), rust-analyzer.";
      };
      scripting.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Scripting LSPs: pyright, ruff, bash-language-server, lua-language-server.";
      };
      web.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Web LSPs: typescript-language-server (and nodejs as runtime).";
      };
      nix.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Nix LSP: nil.";
      };
      formats.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Config/markup-format LSPs: yaml-language-server, taplo (TOML), marksman (Markdown).";
      };
    };

    claudeCode.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Claude Code (Anthropic CLI).";
    };
  };

  imports = [
    ./neovim.nix
    ./git.nix
    ./core.nix
    ./cli-tools.nix
    ./lsp.nix
    ./claude-code.nix
    ./zsh
    ./tmux
    ./extensions
  ];
}
