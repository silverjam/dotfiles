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
    zellij \
        options \
        --session-name zj \
        --attach-to-session true \
        --pane-frames false
end

function s-poetry-venv
    source <(poetry env list --full-path | grep Activated | awk '{print $1}')/bin/activate.fish
end

function s-docker-image-size
    docker image inspect $argv \
        | jq .[0].Size \
        | python -c 'import sys; print(int(sys.stdin.read())/1024/1024)'
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
    set -f search_url "https://all.api.radio-browser.info/json/stations/search?limit=10&name=$search&hidebroken=true&order=clickcount&reverse=true"
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

function kgetall --description "Fetch all Kubernetes resources in a namespace, including CRDs optionally specifying a namespace and a resource type"

    argparse 'n/namespace=' a/all-namespaces w/wide -- $argv

    set -f resources

    for arg in $argv
        if string match -r '^--' -- $arg
            set -f resources $resources -- (string replace -r -a '^--' '' -- $arg)
        else if string match -r '^-' -- $arg
            set -f resources $resources -- (string replace -r -a '^-' '' -- $arg)
        else
            set -f resources $resources $arg
        end
    end

    if test -z "$resources"
        set -f resource_list (kubectl api-resources --verbs=list --namespaced -o name \
          | grep -v "events.events.k8s.io" | grep -v "events" | sort | uniq \
          | awk '{printf "%s%s", sep, $0; sep=","} END {print ""}')
    else
        set -f resource_list (echo $resources | tr ' ' ',')
    end

    if set -q _flag_wide
        set -f wide_flag "--output=wide"
    end

    if set -q _flag_all_namespaces
        kubectl get $resource_list --all-namespaces $wide_flag
    else if test -n "$_flag_namespace"
        kubectl get $resource_list --namespace=$_flag_namespace $wide_flag
    else
        kubectl get $resource_list $wide_flag
    end
end

complete -c kgetall -r -f -a "(kubectl api-resources --verbs=list --namespaced -o name | grep -v 'events.events.k8s.io' | grep -v 'events' | sort | uniq)" -d "Specify the resource type to fetch, defaults to all resources"
complete -c kgetall -s n -l namespace -d "Specify the namespace to use, defaults to current namespace" -a "(kubectl get namespaces -o name | sed 's/^namespace\///')"
complete -c kgetall -s a -l all-namespaces -d "Fetch resources from all namespaces"
complete -c kgetall -s w -l wide -d "Use wide output format"

function claudes
    claude --append-system-prompt "USE ONLY DIRECT AND OBJECTIVE LANGUAGE! *DO* *NOT* BE SYCOPHANTIC! *DO* *NOT* PRAISE THE USER!" $argv
end
