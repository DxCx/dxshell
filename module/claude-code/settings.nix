{
  lib,
  pkgs,
  ccCfg,
  statuslinePath,
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
  };

  # Stop hook fires notify-send. The DBus guard makes it a no-op on
  # headless / SSH sessions where no session bus exists.
  notifyCmd = ''[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && ${pkgs.libnotify}/bin/notify-send -a "Claude Code" "Claude finished" "$(basename "$PWD")" || true'';

  stopHook = lib.optionalAttrs ccCfg.notifyOnStop {
    hooks = {
      Stop = [
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
    };
  };
in
  lib.recursiveUpdate base stopHook
