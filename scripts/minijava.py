#!/usr/bin/python

import sys
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


p = plyj.parser.Parser()
data = p.parse_file(sys.argv[1]).toJson()

klass_data = find_class(data, "HashCodeBuilder")
refs = extract_refs(klass_data, "toHashCode")

print refs

methods = find_methods(klass_data, "HashCodeBuilder")
for method in methods:
    
    method_name = method["p_fields"]["name"]
    names = [ N["p_fields"]["value"] for N in refs ]

    if select_if_contains_name(method, names):
        print method_name
