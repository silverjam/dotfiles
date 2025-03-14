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
    #    zellij --layout compact \
    zellij \
        options \
        --session-name zj \
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
        && starship toggle kubernetes \
        && starship toggle deno \
        && starship toggle nodejs
end

function s-toggle-starship-essentials
    starship toggle python \
        && starship toggle kubernetes \
        && starship toggle deno \
        && starship toggle nodejs
end

function hb
    OPENSSL_LIB_DIR=/home/linuxbrew/.linuxbrew/lib LD_LIBRARY_PATH=/home/linuxbrew/.linuxbrew/lib $argv
end

function nld
    LD_LIBRARY_PATH= $argv
end

function s-ymd
    date "+%Y-%m-%d"
end

function lookup-radio-stream
    set -f search (printf $argv | jq -sRr '@uri')
    set -f search_url "https://nl1.api.radio-browser.info/json/stations/search?limit=10&name=$search&hidebroken=true&order=clickcount&reverse=true"
    set -f stream_url (curl -sL $search_url | jq -r '.[0].url')
    echo $stream_url
end

function stream-radio
    set -f stream_url (lookup-radio-stream $argv)
    screen -dmS radio -- fish -c "curl -sL $stream_url | mpv --cache=no -"
end

function stop-radio
    screen -S radio -X quit
end

function mute-radio-toggle
    screen -S radio -X stuff m
end
