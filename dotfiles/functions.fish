function s-ts-domain
    tailscale status --json | jq -r '.CertDomains[0]'
end

function s-pwr-battery
    system76-power profile battery
end

function s-pwr-balanced
    system76-power profile balanced
end

function s-klog
    argparse 'n/namespace=' -- $argv
    if set -q _flag_namespace
        kail --ns=$_flag_namespace --output=raw --deploy=$args[1] | fblog
    else
        kail --output=raw --deploy=$args[1] | fblog
    end
end

function z
    zellij --layout compact \
        options \
        --theme gruvbox-dark \
        --session-name shell \
        --attach-to-session true \
        --pane-frames false
end

#function zellij_tab_name_update --on-variable PWD
#    if set -q ZELLIJ
#        set tab_name ''
#        if git rev-parse --is-inside-work-tree >/dev/null 2>&1
#            set git_root (basename (git rev-parse --show-toplevel))
#            set git_prefix (git rev-parse --show-prefix)
#            set tab_name "$git_root/$git_prefix"
#            set tab_name (string trim -c / "$tab_name") # Remove trailing slash
#        else
#            set tab_name $PWD
#            if test "$tab_name" = "$HOME"
#                set tab_name "~"
#            else
#                set tab_name (basename "$tab_name")
#            end
#        end
#        command nohup zellij action rename-tab $tab_name >/dev/null 2>&1 &
#    end
#end

function s-poetry-venv
    source <(poetry env list --full-path | grep Activated | awk '{print $1}')/bin/activate.fish
end

function s-docker-image-size
    docker image inspect $argv | jq .[0].Size | python -c 'import sys; print(int(sys.stdin.read())/1024/1024)'
end

function s-klog-dev
    AWS_PROFILE=pow kail --context=dev --ns=$argv[1] --deploy=$argv[1]
end

function s-toggle-starship
    starship toggle directory \
        && starship toggle python \
        && starship toggle git_branch \
        && starship toggle git_status \
        && starship toggle kubernetes
end
