#!/usr/bin/python

import sys, os, subprocess

env = os.getenv
norm = os.path.normpath

src_root = env("SOURCE_ROOT")
if src_root == None:
    # We've gotta figure it out ourselves
    script_path = norm(os.getcwd() + '/' + sys.argv[0])
    src_root = os.path.dirname(os.path.dirname(script_path))

config_path= norm(src_root + "/documentation_tools/hexfiend_doxyfile.config")
if not os.path.isfile(config_path):
    print "Doxygen config file does not exist at " + config_path
    sys.exit(1)

doxygen = norm(src_root + "/documentation_tools/doxygen")
if not os.path.isfile(doxygen):
    print "The doxygen binary does not exist at " + doxygen
    sys.exit(1)

headers = norm(env("BUILT_PRODUCTS_DIR") + "/HexFiend.framework/Headers")
if not os.path.isdir(headers):
    print "The HexFiend header directory does not exist at " + headers
    sys.exit(1)

output_dir = norm(env("BUILT_PRODUCTS_DIR") + "/HexFiend_Documentation")
try:
    os.mkdir(output_dir)
except:
    pass
if not os.path.isdir(output_dir):
    print "The documentation output directory does not exist at " + output_dir
    sys.exit(1)

print 'Documentation output: ' + output_dir
sys.stdout.flush()

new_wd = norm(src_root + "/documentation_tools/")

proc = subprocess.Popen([doxygen, '-'], shell=False, cwd=new_wd, stdin=subprocess.PIPE)

conf_file = open(config_path, 'r')
for line in conf_file:
	if line.startswith('INPUT '):
		line = 'INPUT = ' + headers
	elif line.startswith('OUTPUT_DIRECTORY '):
		line = 'OUTPUT_DIRECTORY = ' + output_dir
	proc.stdin.write(line)
proc.stdin.close()
proc.wait()

sys.exit(0)

