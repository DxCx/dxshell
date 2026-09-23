{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  lspCfg = cfg.lsp;

  # Upstream's clang-tools binaries (clangd, clang-tidy, clang-format, ...)
  # all share one wrapper script that declares `#!/bin/sh` but relies on
  # bash-only syntax ([[ ]], (( )), local). Nix's patchShebangs deliberately
  # leaves `#!/bin/sh` alone (it's assumed POSIX-portable), so the wrappers
  # end up running under whatever /bin/sh happens to be at invocation time.
  # dxshell ships to arbitrary standalone hosts (dash on Debian/Ubuntu,
  # busybox ash on Alpine/embedded) and its own checks run inside the Nix
  # build sandbox (whose /bin/sh is set by the host's nix.conf sandbox-paths
  # and may not be bash either) - both silently break the wrappers, which
  # then run their tool with no header expansion or, on stricter shells,
  # emit nothing at all. Pin every wrapper's interpreter to the store's own
  # runtimeShell so behavior is deterministic regardless of host or sandbox.
  clangToolsFixed = pkgs.clang-tools.overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        for f in "$out"/bin/*; do
          if [ -f "$f" ] && [ "$(head -n1 "$f")" = "#!/bin/sh" ]; then
            sed -i "1s|.*|#!${pkgs.runtimeShell}|" "$f"
          fi
        done
      '';
  });
in {
  config = lib.mkIf (cfg.enable && lspCfg.enable) {
    home.packages =
      lib.optionals lspCfg.systems.enable [
        clangToolsFixed
        pkgs.rust-analyzer
      ]
      ++ lib.optionals lspCfg.scripting.enable [
        pkgs.pyright
        pkgs.ruff
        pkgs.bash-language-server
        pkgs.lua-language-server
      ]
      ++ lib.optionals lspCfg.web.enable [
        pkgs.typescript-language-server
        pkgs.typescript
        pkgs.nodejs
      ]
      ++ lib.optionals lspCfg.nix.enable [
        pkgs.nil
      ]
      ++ lib.optionals lspCfg.formats.enable [
        pkgs.yaml-language-server
        pkgs.taplo
        pkgs.marksman
      ];
  };
}
