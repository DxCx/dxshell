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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dxvim = {
      url = "github:DxCx/dxvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dxnixinfra.url = "github:DxCx/dxnixinfra";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
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
        hmConfig = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            (_: {
              home = {
                inherit username homeDirectory;
                stateVersion = "24.05";
              };
              nixpkgs.config.allowUnfreePredicate = pkg:
                builtins.elem (inputs.nixpkgs.lib.getName pkg) self.unfreePackages;
            })
            hmModule
          ];
        };

        inherit (hmConfig) activationPackage;

        dxshell_package = import ./packages/dxshell-wrapper.nix {inherit pkgs activationPackage;};
        dxshell_install = import ./packages/dxshell-install.nix {inherit pkgs dxshell_package;};

        infraOutputs = dxnixinfra.lib.mkFlakeOutputs {
          src = self;
          inherit pkgs;
          extraChecks = {
            build-dxshell = dxshell_package;
            build-dxshell-install = dxshell_install;
          };
        };
      in
        {
          packages = {
            dxshell = dxshell_package;
            dxshell-install = dxshell_install;
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
