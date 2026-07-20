{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  ccCfg = cfg.claudeCode;

  statuslineScript = pkgs.writeShellApplication {
    name = "dxshell-claude-statusline";
    runtimeInputs = [pkgs.jq pkgs.git];
    text = builtins.readFile ./statusline.sh;
  };
  statuslinePath = "${statuslineScript}/bin/dxshell-claude-statusline";

  formatScript = pkgs.writeShellApplication {
    name = "dxshell-claude-format";
    runtimeInputs = [pkgs.jq pkgs.alejandra pkgs.statix pkgs.shfmt];
    text = builtins.readFile ./format.sh;
  };
  formatPath = "${formatScript}/bin/dxshell-claude-format";

  lspCfg = cfg.lsp;
  ccp = ccCfg.plugins;

  # Official-marketplace plugins (trusted by default; no registration needed).
  # The LSP set maps enabled dxshell.lsp.* bundles to the official LSP plugin
  # whose language-server binary that bundle already provides, turning on Claude
  # Code's built-in LSP tool (post-edit diagnostics + navigation).
  officialLspPlugins = lib.optionals (lspCfg.enable && ccp.lsp) (
    lib.optionals lspCfg.systems.enable ["clangd-lsp" "rust-analyzer-lsp"]
    ++ lib.optionals lspCfg.scripting.enable ["pyright-lsp" "lua-lsp"]
    ++ lib.optionals lspCfg.web.enable ["typescript-lsp"]
  );
  officialPlugins =
    officialLspPlugins
    ++ lib.optionals ccp.codeReview ["code-review" "pr-review-toolkit"]
    ++ lib.optionals ccp.security ["security-guidance"]
    ++ lib.optionals ccp.featureDev ["feature-dev"]
    ++ lib.optionals ccp.hookify ["hookify"]
    ++ lib.optionals ccp.claudeMd ["claude-md-management"];
  officialEnabled =
    lib.listToAttrs
    (map (p: lib.nameValuePair "${p}@claude-plugins-official" true) officialPlugins);

  # Community marketplaces fetched from GitHub. Each contributes a marketplace
  # registration plus its enabled plugin. These run third-party code; Claude
  # Code prompts to trust the marketplace on first use.
  community = [
    {
      enable = ccp.superpowers;
      market = "superpowers-marketplace";
      repo = "obra/superpowers-marketplace";
      plugin = "superpowers";
    }
    {
      enable = ccp.compoundEngineering;
      market = "compound-engineering-plugin";
      repo = "EveryInc/compound-engineering-plugin";
      plugin = "compound-engineering";
    }
    {
      enable = ccp.codspeed;
      market = "codspeed-plugin-marketplace";
      repo = "CodSpeedHQ/codspeed";
      plugin = "codspeed";
    }
    {
      enable = ccp.tddGuard;
      market = "tdd-guard";
      repo = "nizos/tdd-guard";
      plugin = "tdd-guard";
    }
    {
      enable = ccp.pythonQuality;
      market = "python-library-dev";
      repo = "wdm0006/python-skills";
      plugin = "python-library-quality";
    }
  ];
  activeCommunity = lib.filter (c: c.enable) community;
  communityMarkets = lib.listToAttrs (map (c:
    lib.nameValuePair c.market {
      source = {
        source = "github";
        inherit (c) repo;
      };
    })
  activeCommunity);
  communityEnabled = lib.listToAttrs (map (c:
    lib.nameValuePair "${c.plugin}@${c.market}" true)
  activeCommunity);

  # Local dxshell LSP plugin for languages without an official plugin.
  localLsp = import ./lsp-plugin.nix {inherit lib pkgs lspCfg;};
  localLspActive = ccp.localLsp && lspCfg.enable && localLsp.path != null;
  localMarkets = lib.optionalAttrs localLspActive {
    dxshell.source = {
      source = "directory";
      inherit (localLsp) path;
    };
  };
  localEnabled = lib.optionalAttrs localLspActive {"dxshell-lsp@dxshell" = true;};

  enabledPlugins = officialEnabled // communityEnabled // localEnabled // ccp.extra;
  marketplaces = communityMarkets // localMarkets // ccCfg.marketplaces;

  # User-level memory (~/.claude/CLAUDE.md): baseline working rules Claude Code
  # reads in every repo, with an optional user-supplied appendix.
  rulesText =
    builtins.readFile ./rules.md
    + lib.optionalString (ccCfg.extraRules != "") ("\n" + ccCfg.extraRules + "\n");
  memoryFile = pkgs.writeText "claude-CLAUDE.md" rulesText;

  baseSettings = import ./settings.nix {
    inherit lib pkgs ccCfg statuslinePath formatPath enabledPlugins marketplaces;
  };
  # recursiveUpdate replaces list values wholesale; that's why permissions.allow
  # and permissions.deny are extended via the dedicated extraAllow / extraDeny
  # options inside settings.nix rather than through extraSettings.
  mergedSettings = lib.recursiveUpdate baseSettings ccCfg.extraSettings;

  settingsFile =
    (pkgs.formats.json {}).generate "claude-settings.json" mergedSettings;
in {
  # cfg.allowUnfree is enforced by nixpkgs.config.allowUnfreePredicate in
  # flake.nix, so we don't gate on it here.
  config = lib.mkIf (cfg.enable && ccCfg.enable) (lib.mkMerge [
    {
      home.packages = [pkgs.claude-code];
    }
    (lib.mkIf ccCfg.manageSettings {
      # force = true so HM clobbers any pre-existing file at this path
      # instead of failing activation or trying to back it up. Claude Code
      # rewrites ~/.claude/settings.json out-of-band whenever it runs
      # without the HM symlink in place (after a system rollback, on a
      # fresh checkout, etc), and without force=true that rewritten file
      # collides with HM on the next switch — or, with backupFileExtension
      # set, fills the backup slot and then the next cycle collides on the
      # backup itself. The file is fully Nix-generated, so just clobber.
      home.file.".claude/settings.json" = {
        source = settingsFile;
        force = true;
      };
    })
    (lib.mkIf ccCfg.manageMemory {
      # force = true so HM clobbers a pre-existing CLAUDE.md rather than failing
      # activation. This file is fully Nix-generated policy (edit it through
      # claudeCode.extraRules, not by hand); Claude Code's `#` memory shortcut
      # can't write to the read-only store symlink, which is intentional here.
      home.file.".claude/CLAUDE.md" = {
        source = memoryFile;
        force = true;
      };
    })
    (lib.mkIf ccCfg.manageSkills {
      # recursive = true symlinks each skill file individually, so bundled
      # skills coexist with any the user drops into ~/.claude/skills by hand.
      home.file.".claude/skills" = {
        source = ./skills;
        recursive = true;
      };
    })
  ]);
}
