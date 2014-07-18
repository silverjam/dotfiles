#!/usr/bin/python

"""
Look for java packages, and create symlinks that look like java packages (e.g.
a directory with '.' that points to the last dir/node of package.
"""

import re
import os
import sys

starting_cwd = os.getcwd()
package_decl = re.compile("^ *package +(.*)[;] *$", re.MULTILINE)

for dirpath, dirnames, filenames in os.walk('.'):
    for filename in filenames:
        path = os.path.join(dirpath, filename)
        if path.endswith(".java"):
            print ">>> Searching: '%s'" % (path,)
            with open(path) as fp:
                m = package_decl.search(fp.read())
                if m:
                    package_name = m.group(1)
                    package_components = package_name.split('.')
                    dp_components = dirpath.lstrip("./").split(os.path.sep)
                    pkg_start_dir = dp_components[:-len(package_components)]
                    sym_dir = os.path.join(*([starting_cwd] + pkg_start_dir))
                    dst_dir = os.path.join(*package_components)
                    src = os.path.join(sym_dir, dst_dir)
                    dst = os.path.join(sym_dir, package_name)
                    if not os.path.exists(dst):
                        print "Creating symlink: '%s' -> '%s'" % (src, dst)
                        os.symlink(src, dst)
