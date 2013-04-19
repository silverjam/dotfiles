sudo bash -c "cat >/etc/schroot/schroot.conf" <<'EOF'
[quantal]
description=Quantal
directory=$CHROOT
users=$USER
groups=sudo,sbuild
root-groups=root
EOF
