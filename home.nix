{ config, pkgs, lib, ... }:

let
  nodejsNoInstallMan = pkgs.nodejs.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      rm -f $out/share/man/man5/install.5 $out/share/man/man5/install.5.gz
    '';
  });

  tools = with pkgs; [
    age
    awscli2
    bash
    bfg-repo-cleaner
    btop
    delta
    dust
    dua
    fnm
    fzf
    gh
    ghostunnel
    glab
    glow
    git
    git-lfs
    go
    grpcurl
    hadolint
    htop
    imagemagick
    just
    jq
    lazydocker
    mkcert
    pandoc
    retry
    ripgrep
    ruff
    rsync
    screen
    sd
    shellcheck
    shfmt
    socat
    smem
    sqlite
    swappy
    topgrade
    tmux
    tree
    uutils-coreutils-noprefix
    uutils-diffutils
    uutils-findutils
    uv
    wasmtime
    watchexec
    watchman
    xz
    yq-go
    zellij
  ];

  languages = with pkgs; [
    bun
    deno
    jdk25_headless
    maven
    nodejsNoInstallMan
    nodejsNoInstallMan.pkgs.pnpm
    pyenv
    rustup
    zig
  ];

  cloud = with pkgs; [
    buildah
    devspace
    dex-oidc
    fluxcd
    helm-docs
    k3d
    k9s
    kubernetes-helm
    kustomize
    kubectl
    kubectx
    minikube
    nginx
    postgrest
#    postgresql
    redis
#    terraform
    pgcli
    vcluster
  ];

  shell = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.bass
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
      # Here for misc stuff not in a list
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
      $DRY_RUN_CMD mkdir -p $HOME/.config/Code/User
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

      source $HOME/dev/dotfiles/dotfiles/config.fish

      # Not sure why but this needs to happen here for starship to work
      starship init fish | source
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
#      {
#        name = "nvm";
#        src = pkgs.fetchFromGitHub {
#          owner = "jorgebucaran";
#          repo = "nvm.fish";
#          rev = "846f1f20b2d1d0a99e344f250493c41a450f9448";
#          sha256 = "u3qhoYBDZ0zBHbD+arDxLMM8XoLQlNI+S84wnM3nDzg=";
#        };
#      }
      {
        name = "zellij.fish";
        src = pkgs.fetchFromGitHub {
          owner = "kpbaks";
          repo = "zellij.fish";
          rev = "0b2393b48b55a7f3b200b5a12ac0cf26444b7172";
          sha256 = "Nxo6usCI5tqLJ/CZ1YXtCFJ+piy1DGlzFIi9/HSgDIk=";
        };
      }
    ];
  };

  programs.eza.enable = true;
  programs.fzf.enable = true;
  programs.home-manager.enable = true;
  programs.starship.enable = true;
}
