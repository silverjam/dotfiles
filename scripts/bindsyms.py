#!/usr/bin/python

"""
Turn directory symlinks into bind mounts.
Turn file symlinks into hard links.
"""

import os
import re
import subprocess
import sys

FUSE_CONF = '/etc/fuse.conf'
#DRY_RUN = True
DRY_RUN = False

try:
    with open(FUSE_CONF) as fp:
        d = fp.read()
        if not re.search('^ *user_allow_other *$', d, re.MULTILINE):
            print "!!! Failed to find 'user_allow_other' option in '%s'" % (FUSE_CONF,)
            sys.exit(1)
except IOError:
    print "!!! Failed to open '%s'" % (FUSE_CONF,)
    sys.exit(1)

for dirpath, dirnames, filenames in os.walk('.'):
    for dirname in dirnames:
        path = os.path.join(dirpath, dirname)
        if os.path.islink(path):
            target = os.readlink(path)
            print ">>> Removing '%s' -> '%s'" % (dirname, target)
            if not DRY_RUN:
                os.remove(path)
            print '>>> Replacing with bindfs'
            cmd = ['bindfs', target, path]
            print ' '.join(cmd)
            if not DRY_RUN:
                ret = subprocess.call(["mkdir", path])
                if ret != 0:
                    print "!!! Failed to call 'mkdir'"
                    sys.exit(1)
                ret = subprocess.call(cmd)
                if ret != 0:
                    print "!!! Failed to call 'bindfs'"
                    sys.exit(1)
    for filename in filenames:
        path = os.path.join(dirpath, filename)
        if os.path.islink(path):
            target = os.readlink(path)
            print ">>> Removing '%s' -> '%s'" % (filename, target)
            if not DRY_RUN:
                os.remove(path)
            print '>>> Replacing with hard link'
            cmd = ['ln', target, path]
            print ' '.join(cmd)
            if not DRY_RUN:
                ret = subprocess.call(cmd)
                if ret != 0:
                    print "!!! Failed to call 'ln'"
                    sys.exit(1)
