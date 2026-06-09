{
  nixConfig = {
    extra-substituters = [
      "https://dxvim.cachix.org"
      "https://dxshell.cachix.org"
    ];
    extra-trusted-public-keys = [
      "dxvim.cachix.org-1:bEdE17MPsQMGnnbsH8v3Xw/A3VneDtmwtDI8qb5h+/k="
      "dxshell.cachix.org-1:762do0J9EGCay3Pt1x+sRWOivhxsixwlkV469hCvVu0="
    ];
  };

  inputs = {
    dxnixinfra.url = "github:DxCx/dxnixinfra";
    nixpkgs.follows = "dxnixinfra/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dxvim = {
      url = "github:DxCx/dxvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";

    # Official Claude Code settings.json schema, used by the
    # validate-claude-settings check. Tracked as a flake input (not a
    # hand-pinned fetchurl) so its hash lives in flake.lock and renovate's
    # lockFileMaintenance refreshes it automatically — no manual hash bumps.
    claude-code-schema = {
      url = "file+https://json.schemastore.org/claude-code-settings.json";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    utils,
    dxnixinfra,
    ...
  }: let
    hmModule = {lib, ...}: {
      _module.args.dxvim = inputs.dxvim;
      imports = [./module];
      dxshell.enable = lib.mkDefault true;
    };

    flake-base-outputs = utils.lib.mkFlake {
      inherit self inputs;

      supportedSystems = ["x86_64-linux" "aarch64-linux"];
      outputsBuilder = channels: let
        pkgs = channels.nixpkgs;

        # Build-time HM config with placeholder user/home.
        # At runtime, HOME is overridden to the cache directory, so
        # HM activation creates symlinks relative to the real $HOME.
        username = "dxshell";
        homeDirectory = "/tmp/dxshell-home";

        mkHmConfig = extraModule:
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              (_: {
                home = {
                  inherit username homeDirectory;
                  stateVersion = "24.05";
                  packages = [dxshell_update];
                };
                nixpkgs.config.allowUnfreePredicate = pkg:
                  builtins.elem (inputs.nixpkgs.lib.getName pkg) self.unfreePackages;
              })
              hmModule
              extraModule
            ];
          };

        hmConfig = mkHmConfig (_: {});
        # Test fixture: notifyOnStop=false, extraSettings/Allow exercised, manageSettings still on.
        hmConfigAlt = mkHmConfig (_: {
          dxshell.claudeCode = {
            notifyOnStop = false;
            extraSettings = {env = {FOO = "bar";};};
            extraAllow = ["Bash(npm:*)"];
          };
        });
        # Test fixture: manageSettings off — settings.json should not be deployed.
        hmConfigNoSettings = mkHmConfig (_: {
          dxshell.claudeCode.manageSettings = false;
        });
        # Test fixture: NixOS-style import path. We can't easily build a real
        # nixosSystem here, but we can drive the same module composition that
        # home-manager.nixosModules.home-manager would assemble — same module
        # tree, evaluated under the same option-merging rules.
        hmConfigNixos = mkHmConfig (_: {});

        inherit (hmConfig) activationPackage;

        dxshell_package = import ./packages/dxshell-wrapper.nix {inherit pkgs activationPackage homeDirectory;};
        dxshell_install = import ./packages/dxshell-install.nix {inherit pkgs dxshell_package;};
        dxshell_update = import ./packages/dxshell-update.nix {inherit pkgs;};

        claudeCodeSchema = inputs.claude-code-schema;

        infraOutputs = dxnixinfra.lib.mkFlakeOutputs {
          src = self;
          inherit pkgs;
          extraChecks = {
            build-dxshell = dxshell_package;
            build-dxshell-install = dxshell_install;
            build-dxshell-update = dxshell_update;
            test-scripts = import ./tests/test-scripts.nix {
              inherit pkgs dxshell_package dxshell_install dxshell_update;
              inherit (hmConfig) activationPackage;
              activationPackageAlt = hmConfigAlt.activationPackage;
              activationPackageNoSettings = hmConfigNoSettings.activationPackage;
            };
            validate-claude-settings = import ./tests/validate-claude-settings.nix {
              inherit pkgs;
              schema = claudeCodeSchema;
              inherit (hmConfig) activationPackage;
              activationPackageAlt = hmConfigAlt.activationPackage;
            };
            lsp-smoke = import ./tests/lsp-smoke.nix {
              inherit pkgs;
              inherit (hmConfig) activationPackage;
            };
            nixos-import = import ./tests/nixos-import.nix {
              inherit pkgs hmConfigNixos;
            };
          };
        };
      in
        {
          packages = {
            dxshell = dxshell_package;
            dxshell-install = dxshell_install;
            dxshell-update = dxshell_update;
          };
          defaultPackage = dxshell_package;
        }
        // infraOutputs;
    };
  in
    flake-base-outputs
    // {
      inherit hmModule;
      unfreePackages = ["claude-code"];
    };
}
