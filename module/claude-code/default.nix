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

  baseSettings = import ./settings.nix {
    inherit lib pkgs ccCfg statuslinePath;
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
      home.file.".claude/settings.json".source = settingsFile;
    })
  ]);
}
