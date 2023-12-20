test -d $HOME/dev/scripts 
and set PATH $HOME/dev/scripts $PATH

test -d $HOME/dev/dotfiles/scripts 
and set PATH $HOME/dev/dotfiles/scripts $PATH

test -d /ansible/$USER/git/sysmods/scripts
and set PATH /ansible/$USER/git/sysmods/scripts $PATH

test -d $HOME/.local/bin
and set PATH $HOME/.local/bin $PATH

test -d $HOME/.cargo/bin
and set PATH $HOME/.cargo/bin $PATH

test -d $HOME/.krew/bin
and set -gx PATH $PATH $HOME/.krew/bin

test -d /snap/bin
and set PATH /snap/bin $PATH

set -e pure_color_mute
set -U pure_color_mute (set_color normal)

if functions --query bass

  #test -f ~/.nix-profile/etc/profile.d/nix.sh
  #and bass source ~/.nix-profile/etc/profile.d/nix.sh

  test -s /usr/local/rvm/scripts/rvm
  and bass source /usr/local/rvm/scripts/rvm

  test -f $HOME/.cargo/env
  and bass source $HOME/.cargo/env
end

function has_cmd
  if command -v $argv >/dev/null ^/dev/null
    return 0
  else
    return 1
  end
end

if test -z "$BACKGROUND"
#  if has_cmd iterm-exists and has_cmd iterm-profile
#    if iterm-exists
#      set BACKGROUND (iterm-profile)
#    end
#  else
    set BACKGROUND dark
#  end
end

set -U FZF_DEFAULT_OPTS "--color $BACKGROUND"

function kp --description "Kill processes"
  set -l __kp__pid ''
  if contains -- '--tcp' $argv
    set __kp__pid (lsof -Pwni tcp | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:tcp]'" | awk '{print $2}')
  else
    set __kp__pid (ps -ef | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:process]'" | awk '{print $2}')
  end
  if test "x$__kp__pid" != "x"
    if test "x$argv[1]" != "x"
      echo $__kp__pid | xargs kill $argv[1]
    else
      echo $__kp__pid | xargs kill -9
    end
    kp
  end
end

function docker_stop
  docker ps --format '{{.ID}}\tNAME={{.Names}}\tIMAGE={{.Image}}\tCOMMAND={{.Command}}' | table \t 15 40 30 '*' \
    | eval "fzf $FZF_DEFAULT_OPTS -m --header='[docker:stop]'" \
    | field 0 \
    | xargs docker stop 
end

function docker_rmi
  docker images --format='{{.ID}}\tSIZE={{.Size}}\tAGE={{.CreatedSince}}\t{{.Repository}}:{{.Tag}}' | table \t 15 15 20 '*' \
    | sort -n -k 2 -t = \
    | eval "fzf $FZF_DEFAULT_OPTS -m --header='[docker:remove]'" \
    | field 0 \
    | xargs docker rmi
end

function docker_rm
  docker ps -a --format '{{.ID}}\tNAME={{.Names}}\tIMAGE={{.Image}}\tSTATUS={{.Status}}\tCOMMAND={{.Command}}' | table \t 15 40 30 30 '*' \
    | eval "fzf $FZF_DEFAULT_OPTS -m --header='[docker:remove]'" \
    | field 0 \
    | xargs docker rm
end

function _aws_cfg_field -a field profile
  ini_flatten ~/.aws/credentials | grep "$profile"'[.]'"$field" |cut -d= -f2 | sed 's@^ *@@'
end

function aws_google_auth_env -a profile
  test -n "$profile"; or set profile default
  export AWS_ACCESS_KEY_ID=(_aws_cfg_field aws_access_key_id $profile)
  export AWS_SECRET_ACCESS_KEY=(_aws_cfg_field aws_secret_access_key $profile)
  export AWS_SESSION_TOKEN=(_aws_cfg_field aws_session_token $profile)
  export AWS_DEFAULT_REGION=us-west-2
  export AWS_REGION=us-west-2
end

export HELM_HOME=$HOME/helm
export EDITOR=nvim

has_cmd exa; and alias ls=exa

if has_cmd just
  alias j=just
end

if has_cmd bat
  alias less=bat
  alias cat=bat
  alias cats "bat -p"
end

if not has_cmd ag; and has_cmd rg
  alias ag=rg
end

if has_cmd nvim
  alias vi=nvim
  alias vim=nvim
end

#if has_cmd pyenv
##  set -Ux PYENV_VIRTUALENV_DISABLE_PROMPT 1
#  set -Ux PYENV_ROOT "$HOME/.pyenv"
#
#  pyenv init - | source
##  pyenv virtualenv-init - | source
#end

if has_cmd fdfind
  alias fd fdfind
end

alias bork="echo bork"

alias k kubectl

alias f1='fg %1'
alias f2='fg %2'
alias f3='fg %3'
alias f4='fg %4'
alias f5='fg %5'
alias f6='fg %6'
alias f7='fg %7'
alias f8='fg %8'
alias f9='fg %9'

alias p=prevd

set SOURCE_DIR (dirname (status -f))

alias vifish="nvim $SOURCE_DIR/config.fish"
alias refish="echo sourcing: $SOURCE_DIR/config.fish; source $SOURCE_DIR/config.fish"

alias refresh-bg='export BACKGROUND=(tmux run-shell \'echo $BACKGROUND\')'

set fish_greeting

fish_default_key_bindings
