#!/usr/bin/env python

import os
import sys
from subprocess import *


classpath = set()


def getClassPackage(dirpath, filename):
    #print filename
    classname = filename.rsplit(".class")[0]
    cmd1 = ["strings", os.path.join(dirpath, filename)]
    p1 = Popen(cmd1, stdout=PIPE)
    cmd2 = ["grep", "L.*" + classname  + "[;]$"]
    p2 = Popen(cmd2, stdin=p1.stdout, stdout=PIPE)
    p1.stdout.close()  # Allow p1 to receive a SIGPIPE if p2 exits.
    #print ' '.join(cmd1) + " | " + ' '.join(cmd2)
    lines = p2.communicate()[0].strip().splitlines()
    if not lines:
        return None
    output = lines[0]
    #print output
    if '[L' in output:
        return output.split("[L")[1].rsplit(";", 1)[0].rsplit("/", 1)[0]
    if ')L' in output:
        return output.split(")L")[1].rsplit(";", 1)[0].rsplit("/", 1)[0]
    return output.split("L")[1].rsplit(";", 1)[0].rsplit("/", 1)[0]


for dirpath, dirnames, files in os.walk("."):

    for filename in files:
        if filename.endswith(".class"):
            cp = getClassPackage(dirpath, filename)
            if cp:
                cp = dirpath.rsplit(cp)[0]
                if cp not in classpath:
                    print cp
                    classpath.add(cp)

#for cpentry in classpath:
    #print cpentry
