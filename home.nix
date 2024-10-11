{ config, pkgs, lib, ... }:

let 
  tools = with pkgs; [
    awscli2
    bfg-repo-cleaner
    delta
    fzf
    gh
    ghostunnel
    git
    git-lfs
    go
    hadolint
    htop
    just
    jq
    pandoc
    ripgrep
    screen
    shfmt
    socat
    smem
    swappy
    tmux
    tree
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
    docker
    docker-compose
    helmfile
    k3d
    k9s
    kubernetes-helm
    kustomize
    kubectl
    kubectx
    nginx
    postgrest
    postgresql
    terraform
    istioctl
    pgcli
    vouch-proxy
  ];

  shell = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.bass
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
#      {
#        name = "fzf-fish";
#        src = pkgs.fishPlugins.fzf-fish.src;
#      }
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
