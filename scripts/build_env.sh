
unset DISTCC_VERBOSE

#export DISTCC_VERBOSE=1
export DISTCC_TCP_CORK=0

#export DISTCC_SSH="$HOME/distcc_ssh"
export DISTCC_HOSTS="localhost/16"
#export DISTCC_HOSTS="localhost/16 bluto.local/128"

export GYP_DEFINES="remove_webcore_debug_symbols=1"
export GYP_DEFINES="$GYP_DEFINES component=shared_library"
export GYP_DEFINES="$GYP_DEFINES enable_svg=0"
export GYP_DEFINES="$GYP_DEFINES werror="
export GYP_DEFINES="$GYP_DEFINES chromeos=1"

export GYP_GENERATORS="ninja"

#export CPP="pump cpp"

if [[ -n "$NODISTCC" && "$NODISTCC" -eq "1" ]]; then
    export CXX="ccache g++-4.6"
    export CC="ccache gcc-4.6"
else
    export CXX="ccache distcc g++-4.6"
    export CC="ccache distcc gcc-4.6"
fi
