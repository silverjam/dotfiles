{ config, pkgs, ... }:

let 

  devenv = with pkgs; [
    cachix
    (import (fetchTarball https://install.devenv.sh/latest)).default # devenv
  ];

  tools = with pkgs; [
    awscli2
    delta
    fzf
    gh
    git
    jq
    screen
    xz
  ];

  languages = with pkgs; [
    conda
    nodejs
    nodejs.pkgs.pnpm
    rustup
    pyenv
    python3
  ];

  cloud = with pkgs; [
    docker
    docker-compose
    helm
    kubectl
    kubectx
    postgresql
  ];

  editors = with pkgs; [
    vscode
    neovim
  ];

  shell = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.bass
  ];

  # Not currently used
  libs = with pkgs; [
      rabbitmq-c
      nix-ld
      autoconf
      automake
      cmake
      bzip2.dev
      libedit.dev
      libtool
      lzma.dev
      ncurses.dev
      openssl.dev
      pkg-config
      readline.dev
      tk.dev
      zlib.dev
  ];

in

{
  home.username = "jmob";
  home.homeDirectory = "/home/jmob";

  home.stateVersion = "23.05"; # Warning: read docs before changing

  home.packages =
    devenv
    ++ cloud
    ++ editors
    ++ shell
    ++ languages
    ++ tools
    ++ (with pkgs; [
    ])
  ;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

    ".config/fish/functions/functions.fish".text = ''
      if test -f $HOME/dev/dotfiles/scripts/functions.fish
        source $HOME/dev/dotfiles/scripts/functions.fish
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

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.bat.enable = true;

  programs.fish = {
    enable = true;
    shellInit = ''
      source $HOME/dev/dotfiles/dotfiles/config.fish
    '';
    plugins = [
      { 
      	name = "";
	src = pkgs.fetchFromGitHub {
	  owner = "jorgebucaran";
	  repo = "nvm.fish";
	  rev = "c69e5d1017b21bcfca8f42c93c7e89fff6141a8a";
	  sha256 = "LV5NiHfg4JOrcjW7hAasUSukT43UBNXGPi1oZWPbnCA=";
	};
      }
    ];
  };

  programs.fzf.enable = true;
  programs.home-manager.enable = true;
  programs.starship.enable = true;
}

#    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig:${pkgs.bzip2.dev}/lib/pkgconfig:${pkgs.ncurses.dev}/lib/pkgconfig:${pkgs.libedit.dev}/lib/pkgconfig:${pkgs.readline.dev}/lib/pkgconfig:${pkgs.lzma.dev}/lib/pkgconfig:${pkgs.tk.dev}/lib/pkgconfig:${pkgs.rabbitmq-c}/lib/pkgconfig";
#    LD_LIBRARY_PATH = "${pkgs.openssl}/lib:${pkgs.zlib}/lib:${pkgs.bzip2}/lib:${pkgs.ncurses}/lib:${pkgs.libedit}/lib:${pkgs.readline}/lib:${pkgs.lzma}/lib:${pkgs.tk}/lib:${pkgs.rabbitmq-c}/lib";

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

