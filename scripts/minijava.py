#!/usr/bin/python

import sys
import os

d = os.path.dirname(sys.argv[0])
sys.path.insert(0, os.path.join(d, "plyj"))

import plyj.parser
import plyj.model as m
import ipdb
import traceback
import json
import subprocess
import threading

JQ_LOG = False
#JQ_LOG = True


def runjq(data, query):
    query = str.join(" ", query.splitlines())

    if JQ_LOG:
        p = subprocess.Popen(["sh", "-c", "jq \'" + query + "\' | tee /tmp/jq.log" ], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    else:
        p = subprocess.Popen(["jq", query], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    stdin, stdout = p.stdin, p.stdout

    def dump():
        json.dump(data, stdin)
        stdin.close()

    threading.Thread(target=dump).start()

    return json.load(stdout)


def find_class(data, klass):

    find_class_q = """
    .. 
    | select(.p_type? == "ClassDeclaration" and 
            .p_fields.name == "{0}")
    """.format(klass)

    return runjq(data, find_class_q)


def extract_refs(klass_data, method_name):

    find_invokes_and_names_q = """ [
    ..
    | select(.p_type? == "MethodDeclaration") 
    | select(.p_fields.name == "{0}")
    | .p_fields.body
    | ..
    | select(.p_type? == "Name" or .p_type? == "MethodInvocation") ]
    """.format(method_name)

    return runjq(klass_data, find_invokes_and_names_q)


def find_methods(data, klass):

    find_methods_q = """ [
    .. 
    | select(.p_type? == "ClassDeclaration" and 
             .p_fields.name == "{0}")
    | ..
    | select(.p_type? == "MethodDeclaration") ]
    """.format(klass)

    return runjq(data, find_methods_q)


def select_if_contains_name(data, names):

    name_q = str.join(" or ", 
        (" (.p_fields.name == \"{0}\" or .p_fields.value == \"{0}\" ) ".format(N) for N in names))
 
    query = """ [
    ..
    | select(.p_type? == "MethodDeclaration") 
    | .p_fields.body
    | ..
    | select( (.p_type? == "Name" or .p_type? == "MethodInvocation") and ( {0} ) ) ]
    """.format(name_q)

    results = runjq(data, query)
   
    return len(results) > 0


def parse_java_to_json(filename):

    p = plyj.parser.Parser()
    return p.parse_file(filename).toJson()


def find_refs_to_method(data, klass, method):

    klass_data = find_class(data, klass)
    refs = extract_refs(klass_data, method)

    print refs

    methods = find_methods(klass_data, klass)
    for method in methods:
        
        method_name = method["p_fields"]["name"]
        names = [ N["p_fields"]["value"] for N in refs ]

        if select_if_contains_name(method, names):
            print method_name


class CleanupImports(object):

    @staticmethod
    def extract_names(data):

        q = """ 
        [
        .p_fields.type_declarations
        | ..
        | select ( .p_type? == "Name" )
        ]
        """

        return runjq(data, q)


    @staticmethod
    def extract_imports(data):

        q = """ 
        [
        .p_fields.import_declarations
        | ..
        | select ( .p_type? == "Name" )
        ]
        """

        return runjq(data, q)


def find_unused_imports(data):

    refs = CleanupImports.extract_names(data)
    names = [ N["p_fields"]["value"] for N in refs ]

    imports = CleanupImports.extract_imports(data)
    import_names = [ N["p_fields"]["value"] for N in imports ]

    used_imports = set()

    for name in names:
        for import_name in import_names:
            if import_name.endswith(name):
                used_imports.add(import_name)

    used_imports = sorted(used_imports)

    print( '>>> New import list:' )
    print( '' )

    for import_name in used_imports:
        print( "import %s;" % (import_name,) )

    print( '' )
    print( "Import count delta: %d" % (len(used_imports) - len(import_names),))


if __name__ == '__main__':

    d = parse_java_to_json(sys.argv[1])

    if sys.argv[2] == "cleanup_imports":
        find_unused_imports(d)

    elif sys.argv[2] == "minify_code":
        find_refs_to_method(d, sys.argv[3], sys.argv[4])
