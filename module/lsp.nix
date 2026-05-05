{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dxshell;
  lspCfg = cfg.lsp;
in {
  config = lib.mkIf (cfg.enable && lspCfg.enable) {
    home.packages =
      lib.optionals lspCfg.systems.enable [
        pkgs.clang-tools
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
