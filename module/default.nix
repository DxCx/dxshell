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

    claudeCode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Claude Code (Anthropic CLI).";
      };
      manageSettings = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Deploy an opinionated ~/.claude/settings.json. Disable to keep your
          existing file untouched (Home Manager will not overwrite a
          pre-existing non-symlink at that path either way).
        '';
      };
      notifyOnStop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Send a desktop notification (libnotify) when Claude finishes a turn.";
      };
      extraAllow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Additional permissions.allow entries appended to the defaults.
          Use this (rather than extraSettings.permissions.allow) to keep the
          baseline allowlist intact — extraSettings replaces lists wholesale.
        '';
      };
      extraDeny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional permissions.deny entries appended to the defaults.";
      };
      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = ''
          Attrset merged on top of the base settings via lib.recursiveUpdate.
          Note: list values (e.g., permissions.allow) are *replaced* wholesale,
          not concatenated. Use extraAllow / extraDeny for additive permissions.
        '';
      };
    };
  };

  imports = [
    ./neovim.nix
    ./git.nix
    ./core.nix
    ./cli-tools.nix
    ./lsp.nix
    ./claude-code
    ./zsh
    ./tmux
    ./extensions
  ];
}
