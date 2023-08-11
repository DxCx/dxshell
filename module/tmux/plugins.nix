{pkgs, ...}: let
  plugins = with pkgs.tmuxPlugins; [
    # Plugins:
    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/misc/tmux-plugins/default.nix#L269

    # Save & Restore sessions
    resurrect
    continuum

    # Super searching
    copycat

    # Shared clipboard
    yank

    # Open from TMUX
    open
    # List all links in fzf-like
    fzf-tmux-url

    # Vim Key bindings for panes
    pain-control

    # tmux logger
    logging

    # Mouse helpers for better terminal app copy
    better-mouse-mode

    # Theme
    nord
  ];
in
  plugins
