# Builds a local Claude Code plugin (and a single-entry marketplace pointing at
# it) that registers LSP servers for the languages dxshell ships a server for
# but the official marketplace has no plugin for: Nix, Bash, YAML, TOML,
# Markdown. Commands use absolute /nix/store paths so they resolve regardless of
# the runtime PATH. Returns { servers; path } where `path` is the marketplace
# directory in the store (or null when no backing bundle is enabled).
{
  lib,
  pkgs,
  lspCfg,
}: let
  servers =
    lib.optionalAttrs lspCfg.nix.enable {
      nix = {
        command = "${pkgs.nil}/bin/nil";
        extensionToLanguage = {".nix" = "nix";};
      };
    }
    // lib.optionalAttrs lspCfg.scripting.enable {
      bash = {
        command = "${pkgs.bash-language-server}/bin/bash-language-server";
        args = ["start"];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
    }
    // lib.optionalAttrs lspCfg.formats.enable {
      yaml = {
        command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".yml" = "yaml";
          ".yaml" = "yaml";
        };
      };
      toml = {
        command = "${pkgs.taplo}/bin/taplo";
        args = ["lsp" "stdio"];
        extensionToLanguage = {".toml" = "toml";};
      };
      markdown = {
        command = "${pkgs.marksman}/bin/marksman";
        args = ["server"];
        extensionToLanguage = {
          ".md" = "markdown";
          ".markdown" = "markdown";
        };
      };
    };

  pluginJson = (pkgs.formats.json {}).generate "plugin.json" {
    name = "dxshell-lsp";
    description = "dxshell LSP servers for languages without an official Claude Code plugin (Nix, Bash, YAML, TOML, Markdown).";
    version = "0.1.0";
    lspServers = servers;
  };

  marketplaceJson = (pkgs.formats.json {}).generate "marketplace.json" {
    name = "dxshell";
    owner.name = "dxshell";
    plugins = [
      {
        name = "dxshell-lsp";
        source = "./dxshell-lsp";
        description = "LSP intelligence (post-edit diagnostics + navigation) for Nix/Bash/YAML/TOML/Markdown, backed by dxshell's language-server binaries.";
      }
    ];
  };

  marketplace = pkgs.runCommand "dxshell-claude-lsp-marketplace" {} ''
    mkdir -p "$out/.claude-plugin" "$out/dxshell-lsp/.claude-plugin"
    cp ${marketplaceJson} "$out/.claude-plugin/marketplace.json"
    cp ${pluginJson} "$out/dxshell-lsp/.claude-plugin/plugin.json"
  '';
in {
  inherit servers;
  path =
    if servers == {}
    then null
    else "${marketplace}";
}
