test -d $HOME/dev/scripts
and set PATH $HOME/dev/scripts $PATH

test -d $HOME/dev/dotfiles/scripts
and set PATH $HOME/dev/dotfiles/scripts $PATH

test -d $HOME/.local/bin
and set PATH $HOME/.local/bin $PATH

test -d $HOME/.cargo/bin
and set PATH $HOME/.cargo/bin $PATH

test -d $HOME/.deno/bin
and set PATH $HOME/.deno/bin $PATH

test -d $HOME/.krew/bin
and set -gx PATH $PATH $HOME/.krew/bin

test -d /snap/bin
and set PATH /snap/bin $PATH

test -d /home/linuxbrew/.linuxbrew/bin
and set PATH /home/linuxbrew/.linuxbrew/bin $PATH

if functions --query bass
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
    set BACKGROUND dark
end

set -U FZF_DEFAULT_OPTS "--color=$BACKGROUND"
set -U fzf_git_log_opts "--bind=ctrl-f:preview-page-down,ctrl-b:preview-page-up"

function kp --description "Kill processes"
    set -l __kp__pid ''
    if contains -- --tcp $argv
        set __kp__pid (lsof -Pwni tcp | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:tcp]'" | awk '{print $2}')
    else
        set __kp__pid (ps -ef | sed 1d | eval "fzf $FZF_DEFAULT_OPTS -m --header='[kill:process]'" | awk '{print $2}')
    end
    if test "x$__kp__pid" != x
        if test "x$argv[1]" != x
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
    ini_flatten ~/.aws/credentials | grep "$profile"'[.]'"$field" | cut -d= -f2 | sed 's@^ *@@'
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
alias refish="source $SOURCE_DIR/config.fish"

alias refresh-bg='export BACKGROUND=(tmux run-shell \'echo $BACKGROUND\')'

alias vifuncs='nvim ~/dev/dotfiles/dotfiles/functions.fish; source ~/dev/dotfiles/dotfiles/functions.fish'
alias vifuncs-local='nvim ~/dev/scripts/functions.fish; source ~/dev/scripts/functions.fish'

alias vi-home-manager='nvim ~/dev/dotfiles/home.nix'

set fish_greeting

fish_default_key_bindings

if test -f $HOME/dev/dotfiles/dotfiles/functions.fish
    source $HOME/dev/dotfiles/dotfiles/functions.fish
end

if test -f $HOME/dev/scripts/functions.fish
    source $HOME/dev/scripts/functions.fish
end

if has_cmd nvim
    alias vi=nvim
    alias vim=nvim
else
    echo "no nvim found, cannot configure aliases"
end

#if has_cmd atuin
#atuin init fish | source
#end

if has_cmd starship
    starship init fish | source
end

if has_cmd eza
    alias ls 'eza -F --color=auto'
end

# vim: sw=4:sts=4:ts=4:et:
