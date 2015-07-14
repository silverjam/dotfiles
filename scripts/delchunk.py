#!/usr/bin/env python

import os
import re
import sys

import shutil
import tempfile

start_regex = re.compile(sys.argv[1])
stop_regex = re.compile(sys.argv[2])

in_delete = False
check_next_is_blank = False

DEBUG = False

for filename in sys.argv[3:]:

    fp_src = open(filename)
    fp_temp = tempfile.NamedTemporaryFile()

    if DEBUG:
        fpout = sys.stdout
    else:
        fpout = fp_temp

    for line in fp_src:

        if start_regex.search(line) > 0:
            in_delete = True

        if check_next_is_blank and not line.strip():
            check_next_is_blank = False
            continue

        if not in_delete:
            fpout.write(line)
            fpout.flush()

        if stop_regex.search(line) > 0:
            in_delete = False
            check_next_is_blank = True

    if not DEBUG:
        shutil.copy(fp_temp.name, filename)
        fp_src.close()
        fp_temp.close()
