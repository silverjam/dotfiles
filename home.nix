{ config, pkgs, ... }:

{
  home.username = "jmob";
  home.homeDirectory = "/home/jmob";

  home.stateVersion = "23.05"; # Warning: read docs before changing

  home.packages = with pkgs; [
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

    vscode
    neovim

    git
    screen
    fzf
    delta
    jq
    xz

    autoconf
    automake
    conda
    libtool
    pkg-config
    rustup
    pyenv
    python3

    awscli2

    docker
    kubectl
    kubectx
    postgresql
    pyenv

    fishPlugins.fzf-fish
    fishPlugins.bass
  ];

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
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

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

  programs.starship.enable = true;

  programs.bat.enable = true;
  programs.fzf.enable = true;
}
