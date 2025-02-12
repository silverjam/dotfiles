{ config, pkgs, lib, ... }:

let

  # Downgrade screen to version 4 because of this bug: https://savannah.gnu.org/bugs/?66209
  pkgs_screen4 = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    # See https://github.com/NixOS/nixpkgs/blob/4f0dadbf38ee4cf4cc38cbc232b7708fddf965bc/pkgs/tools/misc/screen/default.nix
    rev = "4f0dadbf38ee4cf4cc38cbc232b7708fddf965bc";
    sha256 = "sha256-jQNGd1Kmey15jq5U36m8pG+lVsxSJlDj1bJ167BjHQ4=";
  }) {
    inherit (pkgs) system;
  };

  tools = with pkgs; [
    age
    awscli2
#    atuin
    bfg-repo-cleaner
    delta
    fzf
    gh
    ghostunnel
    glab
    git
    git-lfs
    go
    hadolint
    htop
    jose
    just
    jq
    nomachine-client
    pandoc
    ripgrep
    pkgs_screen4.screen
    shfmt
    socat
    smem
    swappy
    topgrade
    tmux
    tree
    watchexec
    watchman
    xz
  ];

  languages = with pkgs; [
    deno
    nodejs
    nodejs.pkgs.pnpm
    pyenv
    rustup
    zig
  ];

  cloud = with pkgs; [
    dex-oidc
#    docker
#    docker-compose
    fluxcd
    helmfile
    k3d
    k9s
    kubernetes-helm
    kustomize
    kubectl
    kubectx
    nginx
    postgrest
#    postgresql
    redis
    terraform
    istioctl
    pgcli
    vouch-proxy
  ];

  shell = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.bass
#    rio
    nushell
  ];

in

{
  home.username = "jmob";
  home.homeDirectory = "/home/jmob";

  home.stateVersion = "23.05"; # Warning: read docs before changing

  home.packages =
       cloud
    ++ languages
    ++ shell
    ++ tools
    ++ (with pkgs; [
    ])
  ;

  home.file = {
    ".config/fish/functions/functions.fish".text = "";
 
    ".config/fish/completions/aws.fish".text = ''

      function __fish_complete_aws
        env COMP_LINE=(commandline -pc) aws_completer | tr -d ' '
      end

      complete -c aws -f -a "(__fish_complete_aws)"
    '';
  };

  home.activation = {
    linkDotfiles = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ln -sf $VERBOSE_ARG \
          ${builtins.toPath ./dotfiles/vscode-settings.json} $HOME/.config/Code/User/settings.json
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.bat.enable = true;

  programs.fish = {
    enable = true;
    shellInit = ''
      export EDITOR=nvim

      set -p PATH /nix/var/nix/profiles/default/bin
      set -p PATH $HOME/.nix-profile/bin

      if test -d /opt/python
        set -p PATH /opt/python/bin $PATH
      end

      source $HOME/dev/dotfiles/dotfiles/config.fish
    '';
    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "bass";
        src = pkgs.fishPlugins.bass.src;
      }
      {
        name = "nvm";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "nvm.fish";
          rev = "c69e5d1017b21bcfca8f42c93c7e89fff6141a8a";
          sha256 = "LV5NiHfg4JOrcjW7hAasUSukT43UBNXGPi1oZWPbnCA=";
        };
      }
      {
        name = "zellij.fish";
        src = pkgs.fetchFromGitHub {
          owner = "kpbaks";
          repo = "zellij.fish";
          rev = "4ccafc9f3433ef75defa98c5e17d52342943d6a6";
          sha256 = "miiwxKW5XJpO3G9XerJIZkmfSyuyzvx2IG6rMdk7qxA=";
        };
      }
    ];
  };

  programs.eza.enable = true;
  programs.fzf.enable = true;
  programs.home-manager.enable = true;
  programs.starship.enable = true;
}
