#!/usr/bin/env python


import sys
import datetime
import itertools
import multiprocessing as MP
import tempfile


def genr_lines(fp):
    for line in fp:
        if not get_time(line):
            continue # skip invalid lines
        while True:
            #advance = yield line.strip() + '; FILENAME:' + fp.name + '\n'
            advance = yield line
            if advance:
                break


get_time_cache = {}

def get_time(line):
    if not line:
        return None
    s = line[:18]
    if s in get_time_cache:
        return get_time_cache[s]
    try:
        dt = datetime.datetime.strptime(s, "%m-%d %H:%M:%S.%f")
        if dt.month > 6:
            dt = dt.replace(year = 2014)
        else:
            dt = dt.replace(year = 2015)
    except ValueError:
        get_time_cache[s] = None
        return None
    if s not in get_time_cache:
        get_time_cache[s] = dt
    return dt


def get_line(g):
    try:
        return g.send(False)
    except StopIteration:
        return None


def advance_line(g):
    try:
        return g.send(True)
    except StopIteration:
        return None


def line_cmp(x, y):
    if x is None and y is None: return 0
    if x is None: return 1
    if y is None: return -1
    r = cmp(x, y)
    return r


def all_done(genrs):
    return all( get_line(G) is None for G in genrs )


def open_all_as_genr(ls):

    def open_or_fp(f):
        if hasattr(f, 'read') and hasattr(f, 'seek'):
            return f
        return open(f)

    fps = [genr_lines(open_or_fp(F)) for F in ls]

    for fp in fps:
        fp.next() # init generators

    return fps


def merge_2_files(left, right, output_fp):

    leftg, rightg = open_all_as_genr([left, right])

    while True:

        l = get_time(get_line(leftg))
        r = get_time(get_line(rightg))

        if line_cmp(l, r) < 0:
            line = get_line(leftg)
            advance_line(leftg)
        else:
            line = get_line(rightg)
            advance_line(rightg)

        if line is not None:
            output_fp.write(line)

        if all_done([leftg, rightg]):
            break

    return hasattr(output_fp, 'name') and output_fp.name or ''


def merge_2_files_mp(args):

    left_fn = args[0]
    right_fn = args[1]
    temp_fn = args[2]

    #print "merge_2_files_mp(%r,%r,%r)" % (left_fn, right_fn, temp_fn)

    with open(temp_fn, 'w') as fp:
        return merge_2_files(left_fn, right_fn, fp)


global_pool = None

def main(files):

    global global_pool

    if len(files) > 2:

        if global_pool is None:
            global_pool = MP.Pool(8)

        fpairs = zip(files, files[1:])[::2]
        fpairs = [(F[0], F[1], tempfile.mktemp()) for F in fpairs]

        sys.stderr.write("Merging %d/%d in parallel\n" % ((len(files)/2)*2, len(files)))
        output_files = global_pool.map_async(merge_2_files_mp, fpairs).get(sys.maxint)

        if len(files) % 2 != 0:
            main(output_files + [files[-1]])
        else:
            main(output_files)

    else:
        merge_2_files(files[0], files[1], sys.stdout)


def test_line_compare():

    l1 = "01-08 21:26:02.005  2900  2988 I foobar"
    l2 = "01-08 21:26:01.345  4059  5527 I bazquux"

    assert get_time(l1) > get_time(l2)


def test_advance_line():

    from StringIO import StringIO

    d1 = "01-08 21:26:02.005  Line1\n01-08 21:26:02.005  Line2\n01-08 21:26:02.005  Line3\n"
    fp = StringIO()

    fp.write(d1)
    fp.seek(0)

    g = open_all_as_genr([fp])[0]

    assert get_line(g) == "01-08 21:26:02.005  Line1\n"

    assert advance_line(g) == "01-08 21:26:02.005  Line2\n"
    assert get_line(g) == "01-08 21:26:02.005  Line2\n"


def test_line_interleave():

    d1 = """01-08 21:26:01.345  4059  5527 I abc
01-08 21:26:03.355  3042  5410 E abc
01-08 21:26:03.355  3042  5410 E abc
"""

    d2 = """01-08 21:26:02.005  2900  2988 I abc
01-08 21:26:03.025  1266  5150 I abc
01-08 21:26:03.365  2885  5361 I abc
01-08 21:26:03.365  2885  5361 E abc
"""

    merged = """01-08 21:26:01.345  4059  5527 I abc
01-08 21:26:02.005  2900  2988 I abc
01-08 21:26:03.025  1266  5150 I abc
01-08 21:26:03.355  3042  5410 E abc
01-08 21:26:03.355  3042  5410 E abc
01-08 21:26:03.365  2885  5361 I abc
01-08 21:26:03.365  2885  5361 E abc
"""

    from StringIO import StringIO

    fp1 = StringIO(d1)
    fp2 = StringIO(d2)
    fpo = StringIO()

    merge_2_files(fp1, fp2, fpo)

    assert fpo.getvalue() == merged, fpo.getvalue()


def tests():
    test_line_compare()
    test_advance_line()
    test_line_interleave()


if __name__ == '__main__':

    if len(sys.argv) > 1 and sys.argv[1] == "test":
        tests()
    else:
        files = sys.argv[1:]
        main(files)
