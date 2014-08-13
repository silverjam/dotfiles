#!/usr/bin/env python2

import os
import sys

newin = os.fdopen(sys.stdin.fileno(), 'r', 1)

d = ''
while True:
    nd = newin.read(1)
    if not nd:
        print( d )
        break
    d += nd
    if '\n' in d:
        print( d[:d.find('\n')] )
        break
