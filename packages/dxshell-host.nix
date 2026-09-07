{
  pkgs,
  shimSudo ? true,
}: let
  host = pkgs.writeShellScriptBin "dxshell-host" (builtins.readFile ../scripts/dxshell-host.sh);
in
  pkgs.runCommand "dxshell-host" {
    meta = {
      description = "Run a command on the host, outside dxshell's nix-portable sandbox";
      mainProgram = "dxshell-host";
    };
  } ''
    mkdir -p "$out/bin"
    cp ${host}/bin/dxshell-host "$out/bin/dxshell-host"
    ${pkgs.lib.optionalString shimSudo ''
      # Multi-call: the script dispatches on argv[0], so these forward to the
      # host sudo/sudoedit. Shims rather than aliases, so scripts and Makefiles
      # that shell out to `sudo` work too.
      ln -s dxshell-host "$out/bin/sudo"
      ln -s dxshell-host "$out/bin/sudoedit"
    ''}
  ''
