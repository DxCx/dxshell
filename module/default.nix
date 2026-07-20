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
      manageMemory = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Deploy an opinionated ~/.claude/CLAUDE.md (user-level memory) holding
          baseline working rules Claude Code applies in every repo — notably git
          commit discipline (back up continuously, never amend, use fixup
          commits, stamp the exact model, no Claude-Session trailer). Disable to
          hand-manage that file yourself.
        '';
      };
      extraRules = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra Markdown appended to the managed ~/.claude/CLAUDE.md. Use this to
          add your own user-level rules without dropping the baseline ones.
        '';
      };
      manageSkills = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Deploy dxshell's bundled personal skills into ~/.claude/skills
          (/align-commits — walk an interactive rebase commit by commit,
          self-reviewing and re-messaging each; /solve-conflicts — resolve rebase
          conflicts honouring both sides). Each is a per-file symlink, so your
          own skills in that directory are left untouched.
        '';
      };
      notifyOnStop = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Send a desktop notification (libnotify) when Claude finishes a turn.";
      };
      formatOnEdit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install a PostToolUse hook that reformats files Claude edits
          (alejandra + statix for .nix, shfmt for .sh) so its output matches
          the style `nix flake check` enforces.
        '';
      };
      deepReasoning = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Default to high reasoning effort and always-on extended thinking,
          trading latency for more thorough analysis (useful when Claude is the
          reviewing AI, including octorus's headless reviewer).
        '';
      };
      cleanupPeriodDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = ''
          Days to retain sessions, orphaned subagent worktrees, tasks and
          backups (Claude Code's cleanupPeriodDays; default upstream is 30).
        '';
      };
      plugins = {
        lsp = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Auto-enable the official Claude Code LSP plugins matching the
            enabled dxshell.lsp.* bundles (clangd-lsp, rust-analyzer-lsp,
            pyright-lsp, typescript-lsp, lua-lsp). Those bundles already ship
            the language-server binaries, so this just turns on Claude Code's
            built-in LSP tool (post-edit diagnostics + code navigation) and
            stops the per-language "install language server" prompts.
          '';
        };
        codeReview = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable the official code-review and pr-review-toolkit plugins for
            local diff and GitHub PR reviews.
          '';
        };
        security = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the official security-guidance plugin.";
        };
        featureDev = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable the official feature-dev plugin (/feature-dev): a
            code-explorer + code-architect + code-reviewer agent loop that bakes
            design and review steps into feature work.
          '';
        };
        hookify = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable the official hookify plugin: generate deterministic
            PreToolUse/PostToolUse guardrails (enforce build/lint/test gates,
            block edits to generated files) that Claude cannot bypass.
          '';
        };
        claudeMd = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Enable the official claude-md-management plugin: audit CLAUDE.md
            quality and capture session learnings so project conventions stay
            current.
          '';
        };
        localLsp = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Ship a local dxshell plugin that gives Claude Code LSP intelligence
            for the languages it has no official plugin for but dxshell already
            provides a server for: Nix (nil), Bash, YAML, TOML, Markdown. Each
            server is gated on the matching dxshell.lsp.* bundle.
          '';
        };
        superpowers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register the obra/superpowers-marketplace and enable the superpowers
            plugin (agentic workflow skills: /brainstorm, /write-plan, etc.).
            Third-party code from GitHub — Claude Code prompts to trust the
            marketplace on first use, and it adds per-turn context cost.
          '';
        };
        compoundEngineering = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register the EveryInc/compound-engineering-plugin marketplace and
            enable the compound-engineering plugin (/ce-* ideate/plan/work/
            review workflow). Third-party code from GitHub — same trust prompt
            and context-cost caveats as superpowers.
          '';
        };
        codspeed = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register CodSpeedHQ/codspeed and enable the codspeed plugin:
            performance-regression analysis with explicit C/C++ and Python
            support. Third-party marketplace.
          '';
        };
        tddGuard = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register nizos/tdd-guard and enable the tdd-guard plugin: mechanically
            enforce test-first discipline on agent output. Third-party marketplace.
          '';
        };
        pythonQuality = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Register wdm0006/python-skills and enable python-library-quality:
            strict typing (mypy), ruff, and Hypothesis property-based testing
            patterns for Python. Third-party marketplace.
          '';
        };
        extra = lib.mkOption {
          type = lib.types.attrsOf lib.types.bool;
          default = {};
          example = {"github@claude-plugins-official" = true;};
          description = ''
            Additional "plugin@marketplace" => enabled entries merged into
            enabledPlugins (e.g. official external-integration plugins, or
            plugins from a marketplace registered via claudeCode.marketplaces).
          '';
        };
      };
      marketplaces = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = ''
          extraKnownMarketplaces entries registering non-official plugin
          marketplaces. See the Claude Code plugin-settings documentation for
          the per-entry schema (source.source = "github" | "url" | ...).
        '';
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

    octorus = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable octorus, a terminal UI for reviewing GitHub PRs and local
          diffs with AI-driven review/fix cycles (binary: `or`).
        '';
      };
      manageConfig = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Deploy an opinionated ~/.config/octorus/config.toml. Disable to manage
          the file yourself (e.g. via `or init`).
        '';
      };
      provider = lib.mkOption {
        type = lib.types.enum ["claude" "codex"];
        default = "claude";
        description = ''
          AI backend used for both the reviewer and reviewee roles. octorus
          launches the matching CLI headless, so "claude" requires
          dxshell.claudeCode.enable.
        '';
      };
      reviewOnly = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Single review pass with no fix phase (the reviewer comments but the
          reviewee never edits). Leave false for the full review<->fix rally.
        '';
      };
      autoPost = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Post AI proposals to the PR without a confirmation prompt. Defaults to
          false so remote reviews always confirm before any outward-facing post.
        '';
      };
      maxIterations = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 10;
        description = "Maximum review/fix cycles before the rally stops.";
      };
      theme = lib.mkOption {
        type = lib.types.str;
        default = "base16-ocean.dark";
        description = "syntect theme for the diff viewer (e.g. Dracula, Solarized).";
      };
      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = ''
          Attrset merged on top of the generated config.toml via
          lib.recursiveUpdate. List values (e.g.
          ai.reviewee_additional_tools) are replaced wholesale, not merged.
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
    ./octorus.nix
    ./zsh
    ./tmux
    ./extensions
  ];
}
