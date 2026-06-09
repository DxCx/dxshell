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

  # Map enabled dxshell.lsp.* bundles to the official LSP plugins whose
  # language-server binary that bundle already provides (see the binary table
  # in the Claude Code plugin docs). Enabling the plugin turns on Claude Code's
  # built-in LSP tool against the binary dxshell ships.
  lspCfg = cfg.lsp;
  ccp = ccCfg.plugins;
  lspPlugins = lib.optionals (lspCfg.enable && ccp.lsp) (
    lib.optionals lspCfg.systems.enable ["clangd-lsp" "rust-analyzer-lsp"]
    ++ lib.optionals lspCfg.scripting.enable ["pyright-lsp" "lua-lsp"]
    ++ lib.optionals lspCfg.web.enable ["typescript-lsp"]
  );
  officialPlugins =
    lspPlugins
    ++ lib.optionals ccp.codeReview ["code-review" "pr-review-toolkit"]
    ++ lib.optionals ccp.security ["security-guidance"];
  enabledPlugins =
    lib.listToAttrs
    (map (p: lib.nameValuePair "${p}@claude-plugins-official" true) officialPlugins)
    // ccp.extra;

  baseSettings = import ./settings.nix {
    inherit lib pkgs ccCfg statuslinePath formatPath enabledPlugins;
    inherit (ccCfg) marketplaces;
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
  ]);
}
