
CHROOT=/home/jam/Chroot

case $1 in

1)
    sudo debootstrap --variant=buildd --arch i386 quantal $CHROOT http://ubuntu.osuosl.org/ubuntu/
;;

1|2)
    sudo mount -o bind /proc $CHROOT/proc
;;

1|2|3)
    sudo cp -v /etc/resolv.conf $CHROOT/etc/resolv.conf
;;

1|2|3|4)
    sudo cp -v /etc/passwd* $CHROOT/etc
    sudo cp -v /etc/group* $CHROOT/etc
    sudo mkdir $CHROOT/home/jam
    sudo chown jam:jam $CHROOT/home/jam
;;

1|2|3|4|5)
    sudo cp -v /etc/sudoers $CHROOT/etc
;;

esac
