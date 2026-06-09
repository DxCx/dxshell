{
  lib,
  pkgs,
  ccCfg,
  statuslinePath,
  formatPath,
  enabledPlugins,
  marketplaces,
}: let
  defaultAllow = [
    # Read-only inspection — never needs a prompt
    "Bash(ls:*)"
    "Bash(cat:*)"
    "Bash(head:*)"
    "Bash(tail:*)"
    "Bash(wc:*)"
    "Bash(file:*)"
    "Bash(stat:*)"
    "Bash(which:*)"
    "Bash(type:*)"
    # Git inspection
    "Bash(git status:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git remote:*)"
    "Bash(git blame:*)"
    # Nix inspection (this IS a Nix repo)
    "Bash(nix flake metadata:*)"
    "Bash(nix flake show:*)"
    "Bash(nix eval:*)"
    "Bash(nix store:*)"
    "Bash(nix path-info:*)"
  ];

  base = {
    statusLine = {
      type = "command";
      command = statuslinePath;
    };

    permissions = {
      allow = defaultAllow ++ ccCfg.extraAllow;
      deny = ccCfg.extraDeny;
    };

    env = {
      EDITOR = "nvim";
    };

    # Retain sessions, orphaned worktrees, tasks and backups longer than the
    # 30-day default so octorus rally state and review sessions stick around.
    inherit (ccCfg) cleanupPeriodDays;
  };

  # Deeper reasoning by default — Claude is the reviewing AI here (locally and
  # as octorus's headless reviewer), so favour thoroughness over latency.
  reasoning = lib.optionalAttrs ccCfg.deepReasoning {
    effortLevel = "high";
    alwaysThinkingEnabled = true;
  };

  # Stop hook fires notify-send. The DBus guard makes it a no-op on
  # headless / SSH sessions where no session bus exists.
  notifyCmd = ''[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && ${pkgs.libnotify}/bin/notify-send -a "Claude Code" "Claude finished" "$(basename "$PWD")" || true'';

  stopHooks = lib.optionals ccCfg.notifyOnStop [
    {
      matcher = "";
      hooks = [
        {
          type = "command";
          command = notifyCmd;
        }
      ];
    }
  ];

  # PostToolUse formatter keeps Claude's edits compliant with the formatters
  # that `nix flake check` enforces (alejandra, statix, shfmt).
  postToolUseHooks = lib.optionals ccCfg.formatOnEdit [
    {
      matcher = "Edit|Write|MultiEdit";
      hooks = [
        {
          type = "command";
          command = formatPath;
        }
      ];
    }
  ];

  hooks =
    (lib.optionalAttrs (stopHooks != []) {Stop = stopHooks;})
    // (lib.optionalAttrs (postToolUseHooks != []) {PostToolUse = postToolUseHooks;});

  hookAttr = lib.optionalAttrs (hooks != {}) {inherit hooks;};

  # enabledPlugins entries are "plugin@marketplace" => bool; the official
  # marketplace is trusted by default, so its plugins need no marketplace
  # registration. marketplaces feeds extraKnownMarketplaces for any others.
  pluginAttr =
    (lib.optionalAttrs (enabledPlugins != {}) {inherit enabledPlugins;})
    // (lib.optionalAttrs (marketplaces != {}) {extraKnownMarketplaces = marketplaces;});
in
  base // reasoning // hookAttr // pluginAttr
