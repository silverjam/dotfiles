{ config, pkgs, lib, ... }:

let 

  tools = with pkgs; [
    awscli2
    delta
    fzf
    gh
    git
    jq
    pandoc
    ripgrep
    screen
    socat
    swappy
    tree
    xz
  ];

  languages = with pkgs; [
    conda
    deno
    nodejs
    nodejs.pkgs.pnpm
    pyenv
    python3
    python3Packages.pyyaml
    rustup
  ];

  cloud = with pkgs; [
    docker
    docker-compose
    k3d
    kubernetes-helm
    kustomize
    kubectl
    kubectx
    postgresql
    terraform
    istioctl
    pgcli
  ];

  apps = with pkgs; [
    neovim
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
       apps
    ++ cloud
    ++ languages
    ++ shell
    ++ tools
    ++ (with pkgs; [
    ])
  ;

  home.file = {
    ".config/fish/functions/functions.fish".text = ''

      if test -f $HOME/dev/dotfiles/dotfiles/functions.fish
        source $HOME/dev/dotfiles/dotfiles/functions.fish
      end

      if test -f $HOME/dev/scripts/functions.fish
        source $HOME/dev/scripts/functions.fish
      end
    '';
 
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
    PYTHONPATH = "$HOME/.nix-profile/lib/python3.11/site-packages/";
  };

  programs.bat.enable = true;

  programs.fish = {
    enable = true;
    shellInit = ''
      source $HOME/dev/dotfiles/dotfiles/config.fish

      export EDITOR=nvim
      export PYTHONPATH=$HOME/.nix-profile/lib/python3.11/site-packages
    '';
    plugins = [
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
        name = "pyenv";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-pyenv";
          rev = "df70a415aba3680a1670dfcfeedf04177ef3273d";
          sha256 = "qIPe1q3rrR7QdZ2Mr+KuSMxGgZ76QfmV2Q87ZEj4n0U=";
        };
      }
    ];
  };

  programs.eza.enable = true;
  programs.fzf.enable = true;
  programs.home-manager.enable = true;
  programs.starship.enable = true;
}
