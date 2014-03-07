#!/bin/bash

FIFO_STDINP="/tmp/do_over_there.stdinp.fifo"
FIFO_STDOUT="/tmp/do_over_there.stdout.fifo"
FIFO_STDERR="/tmp/do_over_there.stderr.fifo"

do_stuff_here() {
    rm -vf $FIFO_STDINP
    rm -vf $FIFO_STDOUT
    rm -vf $FIFO_STDERR

    mkfifo $FIFO_STDINP
    mkfifo $FIFO_STDOUT
    mkfifo $FIFO_STDERR

    while read line <$FIFO_STDINP ; do
        echo "Running: $line"
        eval $line >$FIFO_STDOUT 2>$FIFO_STDERR
    done
}
