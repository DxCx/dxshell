# Pinned copy of the official Claude Code settings.json schema from
# https://json.schemastore.org/claude-code-settings.json
# (referenced from https://code.claude.com/docs/en/settings).
#
# When upstream evolves, this build fails with a hash mismatch — eyeball the
# upstream diff, then refresh via:
#   nix-prefetch-url https://json.schemastore.org/claude-code-settings.json
{pkgs}:
pkgs.fetchurl {
  url = "https://json.schemastore.org/claude-code-settings.json";
  sha256 = "1y5q74a2jvsjhis608xzqp86w2csi2pz97gxzpzbjh1v073xzzr2";
}
