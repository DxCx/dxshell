{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  oct = cfg.octorus;

  # octorus reads/writes TOML at ~/.config/octorus/config.toml. Field names and
  # the `[ai] [diff] [layout]` sections track src/config/schema.rs upstream;
  # every section is #[serde(default)], so a partial config is valid.
  baseConfig = {
    ai = {
      # reviewer/reviewee drive the AI-Rally review<->fix loop. Both point at the
      # same provider so a single CLI (claude, already shipped by dxshell) backs
      # both roles. octorus launches it headless, so the provider's CLI must be
      # on PATH.
      reviewer = oct.provider;
      reviewee = oct.provider;
      max_iterations = oct.maxIterations;
      timeout_secs = 600;
      # review_only = single review pass, no fix phase. auto_post = false keeps a
      # confirmation prompt before anything is posted/pushed to a PR — both are
      # the safe defaults for outward-facing remote reviews; flip via the options.
      review_only = oct.reviewOnly;
      auto_post = oct.autoPost;
    };
    diff = {
      inherit (oct) theme;
      tab_width = 2; # match dxshell's 2-space convention
      bg_color = true;
    };
    layout = {
      left_panel_width = 35;
      zen_mode = false;
    };
  };

  # recursiveUpdate replaces list values wholesale (same caveat as claude-code's
  # extraSettings): set list fields like ai.reviewee_additional_tools in full.
  mergedConfig = lib.recursiveUpdate baseConfig oct.extraSettings;

  configFile =
    (pkgs.formats.toml {}).generate "octorus-config.toml" mergedConfig;
in {
  config = lib.mkIf (cfg.enable && oct.enable) (lib.mkMerge [
    {
      home.packages = [pkgs.octorus];

      # The binary is `or`; expose a discoverable `octorus` alias alongside it.
      programs.zsh.shellAliases.octorus = "or";

      assertions = [
        {
          assertion = oct.provider != "claude" || cfg.claudeCode.enable;
          message = ''
            dxshell.octorus.provider = "claude" requires
            dxshell.claudeCode.enable = true — octorus launches the claude CLI
            in headless mode, so it must be installed.
          '';
        }
      ];
    }
    (lib.mkIf oct.manageConfig {
      home.file.".config/octorus/config.toml".source = configFile;
    })
  ]);
}
